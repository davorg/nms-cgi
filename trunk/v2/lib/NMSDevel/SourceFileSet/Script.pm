package NMSDevel::SourceFileSet::Script;
use strict;

use NMSDevel::SourceFileSet;
use base qw(NMSDevel::SourceFileSet);

=head1 NAME

NMSDevel::SourceFileSet::Script - source files for an NMS script

=head1 DESCRIPTION

This class encapsulates the set of NMS source files that contribute to
all packages of a particular NMS script.

=head1 CONSTRUCTORS

=over

=item new ( BASEPATH, NAME )

BASEPATH is the full filesystem path to the F</v2> directory in a working
copy against the NMS CVS tree, and NAME is the name of this script, e.g.
C<formmail>.

=back

=head1 METHODS

=over

=item version_string ()

Returns the script version (a string such as C<3.12>) as read from the
C<VERSION> file in the script directory.

=item source_files ()

Returns a list of the source files that contribute to the script, as read
from the C<SOURCES> file in the scirpt directory.

=item release ()

Ensures that all working files in the set are in date with respect to CVS,
and assigns a new minor version number and updates the script F<VERSION>
file if there have been changes since the last version increment.

=item is_package ()

Returns 0, indicating that objects of this class do not encapsulate a single
NMS package.

=cut

sub is_package { 0 }

=back

=cut

1;

