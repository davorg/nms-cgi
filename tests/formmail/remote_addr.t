#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => "square brackets on REMOTE_ADDR",
  CHECKS       => 'nodie xhtml somemail',
  HTTP_REFERER => 'http://foo.domain/x.htm',
  REMOTE_ADDR  => '[1.2.3.4]',
)->run_test;

sub rw_setup
{
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s|\s+\@referers\s*=.*?;| \@referers = qw(foo.domain);| or die;
}

