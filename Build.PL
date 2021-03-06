
use Module::Build;

use warnings;
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
    # regenerate LCDd model (requires Config::Model 2.026)
    system ($^X, qw!script/lcdconf2model.pl!) == 0
                    or die "lcdconf2model failed: $?" ;
    # regenerate pod documentation for the model generated above
    system ($^X, '-MConfig::Model::Utils::GenClassPod', '-e','gen_class_pod();') == 0
                    or die "gen-class-pod failed: $?";
    $self->SUPER::ACTION_build;
}
SUBCLASS

my @version_info = @ARGV ? ( dist_version => $ARGV[0] ) : ();

my %appli_files = map { ( $_, $_ ) } glob("lib/Config/Model/*.d/*");

my $build = $class->new(
    module_name => 'Config::Model::LcdProc',
    @version_info,
    license       => 'lgpl',
    appli_files   => \%appli_files,
    dist_abstract => 'configuration editor for lcdproc',
    dist_author   => 'Dominique Dumont (ddumont at cpan dot org)',

##{ $plugin->get_prereqs ##}

    add_to_cleanup => [ qw/wr_root/ ],
);

$build->add_build_element('pl');
$build->add_build_element('appli');

$build->create_build_script;
