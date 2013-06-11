package Config::Model::LcdProc;

our $VERSION='2.038';

1;

=pod

=head1 NAME

Config::Model::LcdProc - Edit and validate LcdProc configuration file

=head1 SYNOPSIS

=head2 invoke editor

The following command must be run in a package source directory. When
run, L<cme> will load C</etc/LCDd.conf> and launch a graphical editor:

 cme edit lcdproc

=head2 Just check lcdproc files

You can also use L<cme> to run sanity checks on the configuration file:

 cme check lcdproc

=head2 Fix warnings

When run, cme may issue several warnings regarding the content of your file. 
You can choose to  fix (most of) these warnings with the command:

 cme fix lcdproc

=head1 DESCRIPTION

This module provides a configuration editor (and models) for the 
configuration file of LcdProc, i.e. C</etc/LCDd.conf>.

This module can also be used to modify safely the content of this file
from a Perl programs.

=head1 user interfaces

As mentioned in L<cme>, several user interfaces are available:

=over

=item *

A graphical interface is proposed by default if L<Config::Model::TkUI>
is installed.

=item *

A L<Fuse> virtual file system with option C<< cme fusefs lcdproc -fuse_dir <mountpoint> >> 
if L<Fuse> is installed (Linux only)

=back

=head1 AUTHOR

Dominique Dumont, (dod at debian dot org)

=head1 SEE ALSO

=over

=item *

L<cme>

=item *

L<Config::Model>

=item *

http://github.com/dod38fr/config-model/wiki/Using-config-model

=back

