#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my @tests = (
  # METHOD  SECURE  OK
  [ 'GET',     0,    1 ],
  [ 'GET',     1,    0 ],
  [ 'POST',    0,    1 ],
  [ 'POST',    1,    1 ],
);

my $t;

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup, \&rw_secure1 ],
  CGI_ARGS  => [qw(foo=foo)],
);
run_tests($t, 1);

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup, \&rw_secure0 ],
  CGI_ARGS  => [qw(foo=foo)],
);
run_tests($t, 0);

sub run_tests
{
   my ($t, $secure) = @_;

   foreach my $test (grep {$_->[1] == $secure} @tests)
   {
      $t->run_test(
        TEST_ID        => "secure=$secure method $test->[0]",
	HTTP_REFERER   => 'http://foo.domain/',
	CHECKS         => 'xhtml nodie ' . ($test->[2] ? 'somemail' : 'nomail'),
	REQUEST_METHOD => $test->[0],
      );
   }
}

sub rw_setup
{
   s|my\s+\@referers\s*=\s*qw\(.*?\)|my \@referers = qw(foo.domain)|;
   s|my\s+\@allow_mail_to\s*=.*?;|my \@allow_mail_to = qw(test\@test.domain);|;
}

sub rw_secure0
{
   s|my\s+\$secure\s*=.*?;|my \$secure = 0;|;
}

sub rw_secure1
{
   s|my\s+\$secure\s*=.*?;|my \$secure = 1;|;
}

