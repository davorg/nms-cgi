#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($t);
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  HTTP_REFERER => 'http://foo.domain/',
);

my @tests = (
  # TEST            OK  ARGS             
  [ 'foo missing',      0,  ['bar=barbar','realname=foo'] ],
  [ 'realname missing', 0,  ['bar=barbar','foo=foo'] ],
  [ 'foo emtpy',        0,  ['foo=','bar=barbar','realname=foo'] ],
  [ 'realname emtpy',   0,  ['realname=','bar=barbar','foo=foo'] ],
  [ 'foo zero',         1,  ['foo=0','bar=barbar','realname=foo'] ],
  [ 'realname zero',    1,  ['realname=0','bar=barbar','foo=foo'] ],
  [ 'both ok',          1,  ['foo=foofoo','bar=barbar','realname=foo'] ],
);

foreach my $test (@tests)
{
   $t->run_test(
     TEST_ID     => "missing fields $test->[0]",
     CGI_ARGS    => [ 'required=foo,bar,realname', @{ $test->[2] } ],
     CHECKS      => ($test->[1] ? 'some' : 'no') . 'mail xhtml nodie',
   );
}

sub rw_setup
{
   #
   # The very old CGI.pm that comes with Perl 5.00404 generates
   # a warning on empty parameter values.  There's nothing we
   # can reasonably do about that, so we discard those warnings
   # to avoid failing the test.
   #
   my $no_cgi_warn = <<'END';

$SIG{__WARN__} = sub {
   my $warn = shift;
   warn $warn unless $warn =~ /CGI\.pm line /;
};

END
   s|^(.*?\n)|$1$no_cgi_warn|;


   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

