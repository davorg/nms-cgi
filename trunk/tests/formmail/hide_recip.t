#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => 'secret email address hidden',
  CGIARGS      => [qw(foo=foo)],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie somemail hide_secret_email',
)->run_test;

sub LocalChecks::check_hide_secret_email
{
   my ($self) = @_;

   if ( $self->{PAGES}{OUT} =~ /secret/i )
   {
      die "secret email address leaked to output HTML\n";
   }
} 

sub rw_setup
{
   s|my\s+\@referers\s*=\s*qw\(.*?\)|my \@referers = qw(foo.domain)|;
   s|my\s+\@allow_mail_to\s*=.*?;|my \@allow_mail_to = qw(secret\@secret.domain);|;
}

