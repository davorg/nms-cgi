package NMSTest::OutputChecker;
use strict;

=head1 NAME

NMSTest::OutputChecker - correctness check engine

=head1 DESCRIPTION

An C<NMSTest::OutputChecker> object initialised with details
of the results of a particular test run allows various
correctness checks to be applied to it.

=cut

use NMSTest::CheckerXHTML;
use NMSTest::CheckerNoDie;
use NMSTest::CheckerSubTests;
use NMSTest::CheckerMail;

use vars qw(@ISA);
@ISA = qw(NMSTest::CheckerXHTML
          NMSTest::CheckerNoDie
          NMSTest::CheckerSubTests
          NMSTest::CheckerMail
         );

=head1 CONSTRUCTOR

new ( LINES )

LINES must be a reference to an array containing the lines of
the results of the test, as defined in L<NMSTest::TestRun>.

Sets up the object, and processes LINES into a number of
different formats ready for use by the check_* methods.

=cut

sub new
{
   my ($pkg, $lines) = @_;

   my $self = bless { LINES => $lines }, $pkg;

   $self->{PAGES} = {};
   foreach my $line (@$lines)
   {
      if ($line =~ /^(.{6})(.*)\z/s)
      {
         my ($page, $line) = ($1, $2);
         $page =~ s/\s*$//;
         defined $self->{PAGES}{$page} or $self->{PAGES}{$page} = '';
         $self->{PAGES}{$page} .= $line;
      }
   }

   return $self;
}

=head1 METHODS

=over 4

=item checks ( SPEC )

Runs some correctness checks.  SPEC is a string listing the
names of the checks to be applied.

The checks themselves are defined in other modules, see
L<NMSTest::CheckerXHTML>, L<NMSTest::CheckerNoDie>
and L<NMSTest::CheckerMail>.

There is a method for each defined check, so a check named
"foo" would be implemented by a C<check_foo()> method.

An optional argument can be passed to each check method,
separated from the check name by a ':' character.

=cut

sub checks
{
   my ($self, $spec) = @_;

   my @checks = split /\s+/, $spec;
   foreach my $check (@checks)
   {
      my $checkbase = $check;
      my $arg = undef;
      $checkbase =~ s/-(.*)$// and $arg = $1;

      my $method = "check_$checkbase";
      die "unknown check <$check>" unless $self->can($method);

      local $SIG{__DIE__};
      eval { $self->$method($arg) };
      $self->failed("Check $check failed: $@") if $@;
   }
}

=item failed ( ERROR )

The method invoked when a check fails.  Currently it dies
and the die is caught in an eval in C<NMSTest::TestRun>.

=cut

sub failed
{
   my ($self, $err) = @_;

   die $err;
}

=back

=head1 SEE ALSO

L<NMSTest::TestRun>, L<NMSTest::CheckerXHTML>,
L<NMSTest::CheckerNoDie>, L<NMSTest::CheckerMail>

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

