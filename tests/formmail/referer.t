#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my @tests = (
  # TESTNAME       REFERER                      SECURE  ALLOW_EMTPY  OK
  [ 'missing',     '',                             0,    1,            1 ],
  [ 'missing',     '',                             1,    1,            1 ],
  [ 'missing',     '',                             1,    0,            0 ],
  [ 'invalid',     'foo://bar',                    0,    1,            0 ],
  [ 'invalid',     'foo://bar',                    1,    1,            0 ],
  [ 'invalid',     'foo://bar',                    1,    0,            0 ],
  [ 'wrong',       'http://x/x.htm',               0,    1,            0 ],
  [ 'wrong',       'http://x/x.htm',               1,    1,            0 ],
  [ 'username',    'http://foo.domain@x.x/x.htm',  0,    1,            0 ],
  [ 'username',    'http://foo.domain@x.x/x.htm',  1,    1,            0 ],
  [ 'query',       'http://x/x.htm?foo.domain',    0,    1,            0 ],
  [ 'query',       'http://x/x.htm?foo.domain',    1,    1,            0 ],
  [ 'vpath',       'http://x/x.htm/foo.domain',    0,    1,            0 ],
  [ 'vpath'   ,    'http://x/x.htm/foo.domain',    1,    1,            0 ],
  [ 'query by IP', 'http://x/x.htm?127.0.0.1',     0,    1,            0 ],
  [ 'query by IP', 'http://x/x.htm?127.0.0.1',     1,    1,            0 ],
  [ 'vpath by IP', 'http://x/x.htm/127.0.0.1',     0,    1,            0 ],
  [ 'vpath by IP', 'http://x/x.htm/127.0.0.1',     1,    1,            0 ],
  [ 'user by IP',  'http://127.0.0.1@x.x/x.htm',   0,    1,            0 ],
  [ 'user by IP',  'http://127.0.0.1@x.x/x.htm',   1,    1,            0 ],
  [ 'host by IP',  'http://127.0.0.1.x.domain/',   0,    1,            0 ],
  [ 'host by IP',  'http://127.0.0.1.x.domain/',   1,    1,            0 ],
  [ 'host',        'http://foo.domain.x.domain/',  0,    1,            0 ],
  [ 'host',        'http://foo.domain.x.domain/',  1,    1,            0 ],
  [ 'http good',   'http://foo.domain/foo.htm',    0,    1,            1 ],
  [ 'http good',   'http://foo.domain/foo.htm',    1,    1,            1 ],
  [ 'http good 99','http://foo.domain:99/foo.htm', 0,    1,            1 ],
  [ 'http good 99','http://foo.domain:99/foo.htm', 1,    1,            1 ],
  [ 'https good',  'https://foo.domain/foo.htm',   0,    1,            1 ],
  [ 'https good',  'https://foo.domain/foo.htm',   1,    1,            1 ],
  [ 'good by IP',  'http://localhost/foo.htm',     0,    1,            0 ],
  [ 'good by IP',  'http://localhost/foo.htm',     1,    1,            1 ],
  [ 'badchar',     'http://x.x/asdf<asdf',         0,    1,            0 ],
);

my $t;

use vars qw($secure $allow_empty_ref);

$allow_empty_ref = 1;
$secure = 1;
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup ],
  CGI_ARGS  => [qw(foo=foo)],
);
run_tests($t);

$secure = 0;
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup ],
  CGI_ARGS  => [qw(foo=foo)],
);
run_tests($t);

$allow_empty_ref = 0;
$secure = 1;
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup ],
  CGI_ARGS  => [qw(foo=foo)],
);
run_tests($t);

sub run_tests
{
   my ($t) = @_;

   foreach my $test (grep {$_->[2] == $secure and $_->[3] == $allow_empty_ref} @tests)
   {
      $t->run_test(
        TEST_ID      => "secure=$secure mtref=$allow_empty_ref referer $test->[0]",
	HTTP_REFERER => $test->[1],
	CHECKS       => 'xhtml nodie ' . ($test->[4] ? 'somemail' : 'nomail'),
      );
   }
}

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain 127.0.0.1)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(test\@test.domain);|;
   s|\s+\$secure\s*=.*?;| \$secure = $secure;|;
   s|\s+\$allow_empty_ref\s*=.*?;| \$allow_empty_ref = $allow_empty_ref;|;
}

