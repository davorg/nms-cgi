#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => 'forced email address hidden',
  CGI_ARGS     => [qw(foo=foo)],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie somemail hide_secret_email',
)->run_test;

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup_bad ],
  TEST_ID      => 'forced bad email address hidden',
  CGI_ARGS     => [qw(foo=foo)],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie nomail hide_secret_email',
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
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(secret.domain);|;

   s|^(# USER CUSTOM.*\n)|$1\$more_config{force_config_recipient}='secret\@secret.domain';\n|m or die;
}

sub rw_setup_bad
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(secret.other-domain);|;

   s|^(# USER CUSTOM.*\n)|$1\$more_config{force_config_recipient}='secret\@secret.domain';\n|m or die;
}

