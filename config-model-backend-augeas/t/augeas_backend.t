# -*- cperl -*-
# $Author: ddumont $
# $Date: 2008-07-04 16:14:06 +0200 (Fri, 04 Jul 2008) $
# $Revision$

# test augeas backend 

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
    plan tests => 15;
}

ok(1,"compiled");

# pseudo root were input config file are read
my $r_root = 'augeas-box/';

# pseudo root where config files are written by config-model
my $wr_root = 'wr_root/';

# cleanup before tests
rmtree($wr_root);
mkpath($wr_root.'etc/ssh/', { mode => 0755 }) ;
copy($r_root.'etc/hosts',$wr_root.'etc/') ;
copy($r_root.'etc/ssh/sshd_config',$wr_root.'etc/ssh/') ;

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
		       config_dir => '/etc',
		       config_file => 'hosts',
		       set_in => 'record',
		       save   => 'backup',
		       #sequential_lens => ['record'],
		     },
		   ],

   element => [
	       record => { type => 'list',
			   cargo => { type => 'node',
				      config_class_name => 'Host',
				    } ,
			 },
	      ]
   );

$model->create_config_class 
  (
   name => 'Sshd',

   'read_config'
   => [ { backend => 'augeas', 
	  config_dir => '/etc/ssh',
	  config_file => 'sshd_config',
	  save   => 'backup',
	  sequential_lens => [qw/HostKey Subsystem Match/],
	},
      ],

   element => [
	       'AcceptEnv',
	       {
		'cargo' => {
			    'value_type' => 'uniline',
			    'type' => 'leaf'
			   },
		'type' => 'list',
	       },
	       'AllowUsers',
	       {
		'cargo' => {
			    'value_type' => 'uniline',
			    'type' => 'leaf'
			   },
		'type' => 'list',
	       },
	       'HostbasedAuthentication',
	       {
		'value_type' => 'enum',
		choice => [qw/no yes/],
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
	       'Match',
	       {
		'cargo' => {
			    'type' => 'node',
			    'config_class_name' => 'Sshd::MatchBlock'
			   },
		'type' => 'list',
	       },
 	      ]
   );

$model->create_config_class 
  (
   'name' => 'Sshd::MatchBlock',
   'element' => [
		 'Condition',
		 {
		  'type' => 'node',
		  'config_class_name' => 'Sshd::MatchCondition'
		 },
		 'Settings',
		 {
		  'type' => 'node',
		  'config_class_name' => 'Sshd::MatchElement'
		 }
		]
  );

$model->create_config_class 
  (
   'name' => 'Sshd::MatchCondition',
   'element' => [
		 'User',
		 {
		  'value_type' => 'uniline',
		  'type' => 'leaf',
		 },
		 'Group',
		 {
		  'value_type' => 'uniline',
		  'type' => 'leaf',
		 },
		 'Host',
		 {
		  'value_type' => 'uniline',
		  'type' => 'leaf',
		 },
		 'Address',
		 {
		  'value_type' => 'uniline',
		  'type' => 'leaf',
		 }
		]
  );


$model->create_config_class 
  (
   'name' => 'Sshd::MatchElement',
   'element' => [
		 'AllowTcpForwarding',
		 {
		  'value_type' => 'enum',
		  'type' => 'leaf',
		  'choice' => ['no', 'yes']
		 },
		 'Banner',
		 {
		  'value_type' => 'uniline',
		  'type' => 'leaf',
		 },
		 ]
  );


my $i_hosts = $model->instance(instance_name    => 'hosts_inst',
			       root_class_name  => 'Hosts',
			       read_root_dir    => $wr_root ,
			      );

ok( $i_hosts, "Created instance for /etc/hosts" );

my $i_root = $i_hosts->config_root ;

my $expect = "record:0
  ipaddr=127.0.0.1
  canonical=localhost
  alias=localhost -
record:1
  ipaddr=192.168.0.1
  canonical=bilbo - -
" ;

my $dump = $i_root->dump_tree ;
print $dump if $trace ;
is( $dump , $expect,"check dump of augeas data");

# change data content, '~' is like a splice, 'record~0' like a "shift"
$i_root->load("record~0 record:0 canonical=buildbot - 
               record:1 canonical=komarr ipaddr=192.168.0.10 -
               record:2 canonical=repoman ipaddr=192.168.0.11 -
               record:3 canonical=goner   ipaddr=192.168.0.111") ;

$dump = $i_root->dump_tree ;
print $dump if $trace ;

$i_hosts->write_back ;
ok(1,"/etc/hosts write back done") ;

my $aug_file      = $wr_root.'etc/hosts';
my $aug_save_file = $aug_file.'.augsave' ;
ok(-e $aug_save_file, "check that backup config file $aug_save_file was written");

my @expect = ("192.168.0.1 buildbot\n",
	      "192.168.0.10\tkomarr\n",
	      "192.168.0.11\trepoman\n",
	      "192.168.0.111\tgoner\n"
	     );

open(AUG,$aug_file) || die "Can't open $aug_file:$!"; 
is_deeply([<AUG>],\@expect,"check content of $aug_file") ;
close AUG;

# check directly the content of augeas
my $augeas_obj = $i_root->{backend}{augeas}->_augeas_object ;

my $nb = $augeas_obj -> count_match("/files/etc/hosts/*") ;
is($nb,4,"Check nb of hosts in Augeas") ;

# delete last entry
$i_root->load("record~3");
$i_hosts->write_back ;
ok(1,"/etc/hosts write back after deletion of record~3 (goner) done") ;

$nb = $augeas_obj -> count_match("/files/etc/hosts/*") ;
is($nb,3,"Check nb of hosts in Augeas after deletion") ;

pop @expect; # remove goner entry
open(AUG,$aug_file) || die "Can't open $aug_file:$!"; 
is_deeply([<AUG>],\@expect,"check content of $aug_file after deletion of goner") ;
close AUG;



$augeas_obj->print('/') if $trace;

my $have_pkg_config = `pkg-config --version` || '';
chomp $have_pkg_config ;

my $aug_version = $have_pkg_config ? `pkg-config --modversion augeas` : '' ;
chomp $aug_version ;

my $skip =  (not $have_pkg_config)  ? 'pkgconfig is not installed'
         :  $aug_version le '0.3.1' ? 'Need Augeas library > 0.3.1'
         :                            '';

SKIP: {
    skip $skip , 5 if $skip ;

my $i_sshd = $model->instance(instance_name    => 'sshd_inst',
			      root_class_name  => 'Sshd',
			      read_root_dir    => $wr_root ,
			     );

ok( $i_sshd, "Created instance for sshd" );

ok( $i_sshd, "Created instance for /etc/ssh/sshd_config" );

open(SSHD,"$wr_root/etc/ssh/sshd_config")
  || die "can't open file: $!";

my @sshd_orig = <SSHD> ;
close SSHD ;

my $sshd_root = $i_sshd->config_root ;

my $ssh_augeas_obj = $sshd_root->{backend}{augeas}->_augeas_object ;

$ssh_augeas_obj->print('/files/etc/ssh/sshd_config/*') if $trace;
#my @aug_content = $ssh_augeas_obj->match("/files/etc/ssh/sshd_config/*") ;
#print join("\n",@aug_content) ;

$expect = "AcceptEnv=LC_PAPER,LC_NAME,LC_ADDRESS,LC_TELEPHONE,LC_MEASUREMENT,LC_IDENTIFICATION,LC_ALL
AllowUsers=foo,bar\@192.168.0.*
HostbasedAuthentication=no
HostKey=/etc/ssh/ssh_host_key,/etc/ssh/ssh_host_rsa_key,/etc/ssh/ssh_host_dsa_key
Subsystem:rftp=/usr/lib/openssh/rftp-server
Subsystem:sftp=/usr/lib/openssh/sftp-server
Subsystem:tftp=/usr/lib/openssh/tftp-server
Match:0
  Condition
    User=domi -
  Settings
    AllowTcpForwarding=yes - -
Match:1
  Condition
    User=sarko
    Group=pres.* -
  Settings
    Banner=/etc/bienvenue.txt - -
Match:2
  Condition
    User=bush
    Group=pres.*
    Host=white.house.* -
  Settings
    Banner=/etc/welcome.txt - - -
";

$dump = $sshd_root->dump_tree ;
print $dump if $trace ;
is( $dump , $expect,"check dump of augeas data");

# change data content, '~' is like a splice, 'record~0' like a "shift"
$sshd_root->load("HostbasedAuthentication=yes 
                  Subsystem:ddftp=/home/dd/bin/ddftp
                  Subsystem~rftp
                  ") ;

$dump = $sshd_root->dump_tree ;
print $dump if $trace ;

$i_sshd->write_back ;

my $aug_sshd_file      = $wr_root.'etc/ssh/sshd_config';
my $aug_save_sshd_file = $aug_sshd_file.'.augsave' ;
ok(-e $aug_save_sshd_file, 
   "check that backup config file $aug_save_sshd_file was written");

my @mod = @sshd_orig;
$mod[2] = "HostbasedAuthentication yes\n";

$mod[14] = "Subsystem            ddftp /home/dd/bin/ddftp\n";

open(AUG,$aug_sshd_file) || die "Can't open $aug_sshd_file:$!"; 
is_deeply([<AUG>],\@mod,"check content of $aug_sshd_file") ;
close AUG;

} # end SKIP section