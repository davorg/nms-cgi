#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my @tests = (

  # TESTNAME               ADDRESS                 SECURE  OK
  [ 'normal',         'foo@foo.domain',               1,    1 ],
  [ 'normal',         'foo@foo.domain',               0,    1 ],
  [ '@ in userid',    'f@f@foo.domain',               1,    0 ],
  [ '@ in userid',    'f@f@foo.domain',               0,    0 ],
  [ '< in userid',    'f<f@foo.domain',               1,    0 ],
  [ '< in userid',    'f<f@foo.domain',               0,    0 ],
  [ '( in userid',    'f(f@foo.domain',               1,    0 ],
  [ '( in userid',    'f(f@foo.domain',               0,    0 ],
  [ '" in userid',    'f"f@foo.domain',               1,    0 ],
  [ '" in userid',    'f"f@foo.domain',               0,    0 ],
  [ '% in userid',    'f%f@foo.domain',               1,    0 ],
  [ '% in userid',    'f%f@foo.domain',               0,    0 ],
  [ 'strange userid', '-_**eN.3@foo.domain',          1,    1 ],
  [ 'strange userid', '-_**eN.3@foo.domain',          0,    1 ],
  [ 'nutty userid',   "\?`^=.\xFF{\$}/\@s.domain",    1,    0 ],
  [ 'nutty userid',   "\?`^=.\xFF{\$}/\@s.domain",    0,    1 ],
  [ '_ in domain',    'foo@foo_bar.domain',           1,    0 ],
  [ '_ in domain',    'foo@foo_bar.domain',           0,    1 ],
  [ '- in domain',    'foo@foo-bar.domain',           1,    1 ],
  [ '- in domain',    'foo@foo-bar.domain',           0,    1 ],
  [ '.. in domain',   'foo@foo..bar.domain',          1,    0 ],
  [ '.. in domain',   'foo@foo..bar.domain',          0,    0 ],
  [ 'leading .',      'foo@.foo.bar.domain',          1,    0 ],
  [ 'leading .',      'foo@.foo.bar.domain',          0,    0 ],
  [ 'trailing .',     'foo@foo.bar.domain.',          1,    0 ],
  [ 'trailing .',     'foo@foo.bar.domain.',          0,    0 ],
  [ 'long domain',    'foo@x'.('x'x500),              1,    0 ],
  [ 'long domain',    'foo@x'.('x'x500),              0,    1 ],
  [ 'long userid',    (('x'x500).'@foo.domain'),      1,    0 ],
  [ 'long userid',    (('x'x500).'@foo.domain'),      0,    1 ],
);

my $t;

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup, \&rw_secure1 ],
);
run_tests($t, 1);

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'formmail/FormMail.pl',
  REWRITERS => [ \&rw_setup, \&rw_secure0 ],
);
run_tests($t, 0);

sub run_tests
{
   my ($t, $secure) = @_;

   foreach my $test (grep {$_->[2] == $secure} @tests)
   {
      $t->run_test(
        TEST_ID      => "secure=$secure emvalid $test->[0]",
	HTTP_REFERER => 'http://foo.domain/x.html',
	CHECKS       => 'xhtml nodie ' . ($test->[3] ? 'somemail' : 'nomail'),
	CGI_ARGS     => [ "recipient=$test->[1]" ],
      );
   }
}

sub rw_setup
{
   s|my\s+\@recipients\s*=.*?;|my \@recipients = ('.*');|;
   s|my\s+\@referers\s*=.*?;|my \@referers = ('foo.domain');|;
}

sub rw_secure0
{
   s|my\s+\$secure\s*=.*?;|my \$secure = 0;|;
   s|my\s+\$emulate_matts_code\s*=.*?;|my \$emulate_matts_code = 1;|;
}

sub rw_secure1
{
   s|my\s+\$secure\s*=.*?;|my \$secure = 1;|;
}

