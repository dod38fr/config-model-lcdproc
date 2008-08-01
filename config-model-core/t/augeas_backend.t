# -*- cperl -*-
# $Author: ddumont $
# $Date: 2008-07-04 16:14:06 +0200 (Fri, 04 Jul 2008) $
# $Revision: 707 $

# test augeas backend if Config::Augeas is installed

use ExtUtils::testlib;
use Test::More ;
use Config::Model;
use File::Path;
use File::Copy ;
use Data::Dumper ;

use warnings;
no warnings qw(once);

use strict;

use vars qw/$model/;

$model = Config::Model -> new (legacy => 'ignore',) ;

my $trace = shift || 0;
$::verbose          = 1 if $trace =~ /v/;
$::debug            = 1 if $trace =~ /d/;
Config::Model::Exception::Any->Trace(1) if $trace =~ /e/;

eval { require Config::Augeas ;} ;
if ( $@ ) {
    plan skip_all => 'Config::Augeas is not installed';
}
else {
    plan tests => 12;
}

ok(1,"compiled");

# pseudo root were input config file are read
my $r_root = 'augeas-box/';

# pseudo root where config files are written by config-model
my $wr_root = 'wr_root/';

# cleanup before tests
rmtree($wr_root);
mkpath($wr_root.'etc/ssh/', { mode => 0755 }) ;
copy($r_root.'etc/hosts',$wr_root.'/etc/') ;
copy($r_root.'etc/ssh/sshd_config',$wr_root.'/etc/ssh/') ;

# set_up data


$model->create_config_class 
  (
   name => 'Host',

   element => [
	       [qw/ipaddr canonical alias/] 
	       => { type => 'leaf',
		    value_type => 'uniline',
		  } 
	      ]
   );


$model->create_config_class 
  (
   name => 'Hosts',

   read_config  => [ { backend => 'augeas', 
		       config_file => '/etc/hosts',
		       set_in => 'top',
		       save   => 'backup',
		     },
		   ],

   element => [
	       top => { type => 'list',
			cargo => { type => 'node',
				   config_class_name => 'Host',
				 } ,
		      },
	      ]
   );

$model->create_config_class 
  (
   name => 'Sshd',

   read_config  => [ { backend => 'augeas', 
		       config_file => '/etc/ssh/sshd_config',
		       save   => 'backup',
		     },
		   ],

   element => [
	       'HostbasedAuthentication',
	       {
		'value_type' => 'boolean',
		'type' => 'leaf',
	       },
	       'HostKey',
	       {
		'cargo' => {
			    'value_type' => 'uniline',
			    'type' => 'leaf'
			   },
		'type' => 'list',
	       },
	       'Subsystem',
	       {
		'cargo' => {
			    'value_type' => 'uniline',
			    'mandatory' => '1',
			    'type' => 'leaf'
			   },
		'type' => 'hash',
		'index_type' => 'string'
	       },
	      ]
   );


my $i_hosts = $model->instance(instance_name    => 'hosts_inst',
			       root_class_name  => 'Hosts',
			       read_root_dir    => $wr_root ,
			      );

ok( $i_hosts, "Created instance for /etc/hosts" );

my $i_root = $i_hosts->config_root ;

my $expect = "top:0
  ipaddr=127.0.0.1
  canonical=localhost
  alias=localhost -
top:1
  ipaddr=192.168.0.1
  canonical=bilbo - -
" ;

my $dump = $i_root->dump_tree ;
print $dump if $trace ;
is( $dump , $expect,"check dump of augeas data");

# change data content, '~' is like a splice, 'top~0' like a "shift"
$i_root->load("top~0 top:0 canonical=buildbot - 
               top:1 canonical=komarr ipaddr=192.168.0.10 -
               top:2 canonical=repoman ipaddr=192.168.0.11 -
               top:3 canonical=goner   ipaddr=192.168.0.111") ;

$dump = $i_root->dump_tree ;
print $dump if $trace ;

my %h = $i_root->dump_as_path('top') ;
print Dumper \%h if $trace ;
my $expect_h = {
		'/1/canonical' => 'buildbot',
		'/1/ipaddr' => '192.168.0.1',
		'/2/canonical' => 'komarr',
		'/2/ipaddr' => '192.168.0.10',
		'/3/canonical' => 'repoman',
		'/3/ipaddr' => '192.168.0.11',
		'/4/canonical' => 'goner',
		'/4/ipaddr' => '192.168.0.111',
	       };
is_deeply(\%h,$expect_h,"Check dump_as_path") ;

$i_hosts->write_back ;
ok(-e $wr_root.'/etc/hosts.augsave',
   "check that backup config file was written");

# check directly the content of augeas
my $augeas_obj = $i_root->_augeas_object ;

my $nb = $augeas_obj -> count_match("/files/etc/hosts/*") ;
is($nb,4,"Check nb of hosts in Augeas") ;

# delete last entry
$i_root->load("top~3");
$i_hosts->write_back ;

$nb = $augeas_obj -> count_match("/files/etc/hosts/*") ;
is($nb,3,"Check nb of hosts in Augeas after deletion") ;

$augeas_obj->print(*STDOUT, '') if $trace;

my $i_sshd = $model->instance(instance_name    => 'sshd_inst',
			      root_class_name  => 'Sshd',
			      read_root_dir    => $wr_root ,
			     );

ok( $i_sshd, "Created instance for sshd" );

ok( $i_sshd, "Created instance for /etc/ssh/sshd_config" );

my $sshd_root = $i_sshd->config_root ;

$expect = "HostbasedAuthentication=0
HostKey=/etc/ssh/ssh_host_key,/etc/ssh/ssh_host_rsa_key,/etc/ssh/ssh_host_dsa_key -
";

TODO: {

local $TODO="Need to cater for Angea view of list and sequence (different notations). Pb: config-model does not make any difference";

$dump = $sshd_root->dump_tree ;
print $dump if $trace ;
is( $dump , $expect,"check dump of augeas data");

# change data content, '~' is like a splice, 'top~0' like a "shift"
$sshd_root->load("HostbasedAuthentication=1") ;

$dump = $sshd_root->dump_tree ;
print $dump if $trace ;

my %h = $sshd_root->dump_as_path() ;
print Dumper \%h if $trace ;
my $expect_h = { 
		'/HostKey/1' => '/etc/ssh/ssh_host_key',
		'/HostKey/2' => '/etc/ssh/ssh_host_rsa_key',
		'/HostKey/3' => '/etc/ssh/ssh_host_dsa_key',
		'/HostbasedAuthentication' => '1',
	       };
is_deeply(\%h,$expect_h,"Check dump_as_path") ;

#$i_sshd->write_back ;
ok(-e $wr_root.'/etc/sshd.augsave',
   "check that backup config file was written");

}