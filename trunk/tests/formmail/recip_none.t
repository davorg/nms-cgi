#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($tests);
{
   local $/;
   $tests = <DATA>;
}

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup, \&install_tests ],
  TEST_ID      => "check_recipient, none configured",
  CHECKS       => 'nodie subtests',

)->run_test;

sub install_tests
{
   s#^check_url\(\);#unitTest\(\);#m;
   s#(__END__|\z)#$tests$1#;
}

sub rw_setup
{
   s|my\s+\@allow_mail_to\s*=.*?;|my \@allow_mail_to = ();|;
   s|my\s+\@referers\s*=.*?;|my \@referers = qw(foo.domain bar\@foo.domain);|;
   s|my\s+\@recipients\s*=.*?;|my \@recipients = ();|;
}

__END__

sub unitTest
{
    my @recipients = (
       '',
       ' ',
       '0',
       '0@0',
       'foo@foo.domain',
       'bar@foo.domain',
       'postmaster',
       'you@your.domain',
    );

    foreach my $r (@recipients)
    {
        unitTestTryall($r);
    }

    print "All subtests ran\n";
    exit 0;
}

sub unitTestTryall
{
  my ($r) = @_;

  foreach my $s (0,1)
  {
    $secure = $s;
    foreach my $d (0,1)
    {
      $DEBUGGING = $d;
      foreach my $e (0,1)
      {
        $emulate_matts_code = $e;
        if ( check_recipient($r) )
	{
	  warn "Recipient <$r> accepted in error (s=$s, D=$d, e=$e)\n";
        }
      }
    }
  }
}

