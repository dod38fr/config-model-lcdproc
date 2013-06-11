
use Module::Build;

use warnings FATAL => qw(all);
use strict;

require 5.010001 ;

# check that pod docs are up-to-date this is redundant with work done by
# dzil. But this enable to re-build the docs downstream.
# Use $^X in there as requested in 
# https://rt.cpan.org/Public/Bug/Display.html?id=74891
my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code => <<'SUBCLASS' );

sub ACTION_build {
    my $self = shift;
    # below requires Config::Model 2.026
    system ($^X, qw!cme gen-class-pod!) ;
    $self->SUPER::ACTION_build;
}
SUBCLASS

my @version_info = @ARGV ? ( dist_version => $ARGV[0] ) : ();

my %appli_files = map { ( $_, $_ ) } glob("lib/Config/Model/*.d/*");

my $build = $class->new(
    module_name => 'Config::Model::LcdProc',
    @version_info,
    license       => 'lgpl',
    dist_abstract => 'configuration editor for lcdproc',
    dist_author   => 'Dominique Dumont (ddumont at cpan dot org)',

    # Build.PL runs gen_class_pod.pl which loads Config::Model from lib,
    # hence most of the runtime dependencies are in fact 
    # configure_requires. This should improve Perl smoke tests.

##{ $plugin->get_prereqs ##}

    # cleanup required by t/auto_read.t
    # PreGrammar.pm is created by t/value_computer.t
    add_to_cleanup => [ qw/PreGrammar.pm wr_root r_root/ ],
);

$build->add_build_element('pl');

$build->create_build_script;
