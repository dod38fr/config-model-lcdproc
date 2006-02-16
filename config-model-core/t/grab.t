# -*- cperl -*-
# $Author: ddumont $
# $Date: 2006-02-16 13:09:43 $
# $Name: not supported by cvs2svn $
# $Revision: 1.2 $

use ExtUtils::testlib;
use Test::More tests => 27;
use Config::Model;

use warnings;
no warnings qw(once);

use strict;

use Data::Dumper;
# use Config::Model::ObjTreeScanner;

use vars qw/$model/;

$model = Config::Model -> new ;

my $file = 't/big_model.pm';

my $return ;
unless ($return = do $file) {
    warn "couldn't parse $file: $@" if $@;
    warn "couldn't do $file: $!"    unless defined $return;
    warn "couldn't run $file"       unless $return;
}



my $trace = shift || '';
$::verbose          = 1 if $trace =~ /v/;
$::debug            = 1 if $trace =~ /d/;

ok(1,"compiled");

my $inst = $model->instance (root_class_name => 'Master', 
				 instance_name => 'test1');
ok($inst,"created dummy instance") ;

my $root = $inst -> config_root ;

Config::Model::Exception::Any->Trace(1) if $trace =~ /e/;

my $step = 'std_id:ab X=Bv - std_id:bc X=Av - a_string="titi , toto" ';
ok( $root->load( step => $step, permission => 'intermediate' ),
  "load '$step'");

is($root->grab('olist:0' )->index_value,0,'test grab olist:0') ;

my $wp = 'olist:0';
eval {$root->grab(\$wp )->index_value; };
ok($@,"Test grab with wrong parameter") ;
print "normal error:\n", $@, "\n" if $trace;

eval {$root->grab('std_xid:toto')->index_value; };
ok($@,"Test grab with wrong element") ;
print "normal error:\n", $@, "\n" if $trace;


like($root->grab('olist' )->name,qr/olist/,'test grab olist') ;

is( $root->location(), '','location test' );

foreach my $wstep ( 
		   'std_id:ab', 'olist:0', 'olist:1', 
		   'warp',
		   'warp std_id:toto'
		  )
{
    my $obj = $root->grab( $wstep );
    ok($obj,"grab $wstep...");
    is( $obj->location, $wstep,"... and test its location" );
}

print $root->dump_tree( ) if $trace =~ /t/;

my $leaf = $root->grab('warp std_id:toto DX');

my @tests = ( [ '?warp' ,      'warp',           'WarpedNode'],
	      [ '?std_id:ab' , 'warp std_id:ab', 'Node'],
	      [ '?hash_a:ab' , 'hash_a:ab'   , 'Value'],
	      [ '?std_id' ,     'warp std_id', 'HashId'],
	    ) ;

foreach my $unit_test (@tests) {
    my $obj = $leaf->grab($unit_test->[0]) ;
    is($obj->location, 
       $unit_test->[1],
       "test grab with '$unit_test->[0]'") ;
    isa_ok ($obj, 'Config::Model::'.$unit_test->[2]) ;
}

eval { $leaf->grab('?argh' ); };
ok($@,"test grab with wrong step: '?argh'");
print "normal error:\n", $@, "\n" if $trace;


