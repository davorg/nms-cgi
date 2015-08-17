#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  TEST_ID      => "square brackets on REMOTE_ADDR",
  CHECKS       => 'nodie xhtml somemail',
  HTTP_REFERER => 'http://foo.domain/x.htm',
  REMOTE_ADDR  => '[1.2.3.4]',
);

$t->run_test( 
  TEST_ID      => "square brackets on REMOTE_ADDR",
  REMOTE_ADDR  => '[1.2.3.4]',
);

$t->run_test( 
  TEST_ID      => "ipv6 compat REMOTE_ADDR",
  REMOTE_ADDR  => '::ffff:10.102.104.150',
);

sub rw_setup
{
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s|\s+\@referers\s*=.*?;| \@referers = qw(foo.domain);| or die;
}

