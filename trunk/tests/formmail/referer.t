#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my @tests = (
  # TESTNAME        REFERER                     SECURE  OK
  [ 'missing',     '',                            0,    1 ],
  [ 'missing',     '',                            1,    0 ],
  [ 'invalid',     'foo://bar',                   0,    1 ],
  [ 'invalid',     'foo://bar',                   1,    0 ],
  [ 'wrong',       'http://x/x.htm',              0,    0 ],
  [ 'wrong',       'http://x/x.htm',              1,    0 ],
  [ 'username',    'http://foo.domain@x.x/x.htm', 0,    0 ],
  [ 'username',    'http://foo.domain@x.x/x.htm', 1,    0 ],
  [ 'query',       'http://x/x.htm?foo.domain',   0,    0 ],
  [ 'query',       'http://x/x.htm?foo.domain',   1,    0 ],
  [ 'vpath',       'http://x/x.htm/foo.domain',   0,    0 ],
  [ 'vpath'   ,    'http://x/x.htm/foo.domain',   1,    0 ],
  [ 'query by IP', 'http://x/x.htm?127.0.0.1',    0,    0 ],
  [ 'query by IP', 'http://x/x.htm?127.0.0.1',    1,    0 ],
  [ 'vpath by IP', 'http://x/x.htm/127.0.0.1',    0,    0 ],
  [ 'vpath by IP', 'http://x/x.htm/127.0.0.1',    1,    0 ],
  [ 'user by IP',  'http://127.0.0.1@x.x/x.htm',  0,    0 ],
  [ 'user by IP',  'http://127.0.0.1@x.x/x.htm',  1,    0 ],
  [ 'host by IP',  'http://127.0.0.1.x.domain/',  0,    0 ],
  [ 'host by IP',  'http://127.0.0.1.x.domain/',  1,    0 ],
  [ 'host',        'http://foo.domain.x.domain/', 0,    0 ],
  [ 'host',        'http://foo.domain.x.domain/', 1,    0 ],
  [ 'http good',   'http://foo.domain/foo.htm',   0,    1 ],
  [ 'http good',   'http://foo.domain/foo.htm',   1,    1 ],
  [ 'https good',  'https://foo.domain/foo.htm',  0,    1 ],
  [ 'https good',  'https://foo.domain/foo.htm',  1,    1 ],
  [ 'good by IP',  'http://localhost/foo.htm',    0,    0 ],
  [ 'good by IP',  'http://localhost/foo.htm',    1,    1 ],
  [ 'badchar',     'http://x.x/asdf<asdf',        0,    0 ],
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

0;

sub run_tests
{
   my ($t, $secure) = @_;

   foreach my $test (grep {$_->[2] == $secure} @tests)
   {
      $t->run_test(
        TEST_ID      => "secure=$secure referer $test->[0]",
	HTTP_REFERER => $test->[1],
	CHECKS       => 'xhtml nodie ' . ($test->[3] ? 'somemail' : 'nomail'),
      );
   }
}

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain 127.0.0.1)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(test\@test.domain);|;
}

sub rw_secure0
{
   s|\s+\$secure\s*=.*?;| \$secure = 0;|;
}

sub rw_secure1
{
   s|\s+\$secure\s*=.*?;| \$secure = 1;|;
}

