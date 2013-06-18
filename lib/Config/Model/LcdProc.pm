package Config::Model::LcdProc;

1;

=pod

=head1 NAME

Config::Model::LcdProc - Edit and validate LcdProc configuration file

=head1 SYNOPSIS

=head2 invoke editor

The following command will load C</etc/LCDd.conf> and launch a
graphical editor:

 cme edit lcdproc

=head2 Just check lcdproc configuration

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

=head1 AUTHOR

Dominique Dumont, (dod at debian dot org)

=head1 SEE ALSO

=over

=item *

http://lcdproc.omnipotent.net/

=item *

L<cme>

=item *

L<Config::Model>

=item *

http://github.com/dod38fr/config-model/wiki/Using-config-model

=back

