#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my $subject = 'Ahhhh ' . 'gwan,'x20;

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => 'long subject',
  CGI_ARGS      => ['foo=foo', "subject=$subject"],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie somemail subject',
)->run_test;

sub LocalChecks::check_subject
{
   my ($self) = @_;

   unless ( $self->{PAGES}{MAIL1} =~ /^Subject: \Q$subject\E\n/m )
   {
      die "expected subject not found in email header\n";
   }
} 

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

