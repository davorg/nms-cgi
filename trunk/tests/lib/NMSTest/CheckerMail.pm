package NMSTest::CheckerMail;
use strict;

=head1 NAME

NMSTest::CheckerMail - Mail test output checker

=head1 DESCRIPTION

This module defines EMail related check methods for the
output checking engine described in L<NMSTest::OutputChecker>.

=head1 METHODS

=over 4

=item check_nomail ()

Ensures that the script sent no EMail.

=cut

sub check_nomail
{
   my ($self) = @_;

   if (exists $self->{PAGES}{MAIL1})
   {
      die "script sent some mail, it shouldn't have\n";
   }
}

=item check_somemail ()

Ensures that the script sent some EMail.

=cut

sub check_somemail
{
   my ($self) = @_;

   unless (exists $self->{PAGES}{MAIL1})
   {
      die "script sent no mail, it should have sent some\n";
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

