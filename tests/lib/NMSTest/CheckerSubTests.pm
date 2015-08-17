package NMSTest::CheckerSubTests;
use strict;

=head1 NAME

NMSTest::CheckerSubTests - checker for subtests

=head1 DESCRIPTION

This module defines the "subtests" check method for the
output checking engine described in
L<NMSTest::OutputChecker>.

=head1 METHODS

=over 4

=item check_subtests ()

Ensures that the script ran the subtest set that was installed
in it, by checking for the text

   "All subtests ran\n"

in the script's STDOUT.

=cut

sub check_subtests
{
   my ($self) = @_;

   unless ( $self->{PAGES}{OUT} =~ /^All subtests ran\n/m )
   {
      die "Failed to find any indication that the subtests ran\n";
   }
}

=back

=head1 SEE ALSO

L<NMSTest::OutputChecker>

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

