#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => 'customised bad recipient page',
  CGI_ARGS     => [qw(foo=foo recipient=foo@bad.domain)],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie nomail hamster',
)->run_test;

sub LocalChecks::check_hamster
{
   my ($self) = @_;

   unless ( $self->{PAGES}{OUT} =~ /\bhamster\b/i )
   {
      die "custom error page not found\n";
   }
} 

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo.domain);|;

   my $custom = <<'END';

sub bad_recipient_error_page {
  my ($self) = @_;

  $self->error_page('arf arf', 'hamster time' );
}

END

   s|^(# USER CUSTOM.*\n)|$1$custom|m or die;
}

