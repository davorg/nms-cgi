package NMSTest::CheckerNoDie;
use strict;

=head1 NAME

NMSTest::CheckerNoDie - didn't die test output checker

=head1 DESCRIPTION

This module defines the "nodie" check method for the
output checking engine described in
L<NMSTest::OutputChecker>.

=head1 METHODS

=over 4

=item check_nodie ()

Ensures that the script didn't exit with non-zero status or
produce any STDERR output.

=cut

sub check_nodie
{
   my ($self) = @_;

   if (exists $self->{PAGES}{ERR})
   {
      die "unexpected STDERR output: $self->{PAGES}{ERR}\n";
   }

   $self->{LINES}[1] =~ /\bstatus:\s*(\d+)/i or die
      "can't parse status line <$self->{LINES}[1]>";
   unless ($1 == 0)
   {
      die "script exited with status $1, expected 0\n";
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

