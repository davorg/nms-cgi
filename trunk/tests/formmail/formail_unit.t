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
  REWRITERS    => [ \&install_tests ],
  TEST_ID      => "formmail unit tests",
  CHECKS       => 'nodie subtests',

)->run_test;

sub install_tests
{
   s#^check_url\(\);#unitTest\(\);#m;
   s#(__END__|\z)#$tests$1#;
}

__END__

sub unitTest
{
    recipientTests();
    refererTests();
    print "All subtests ran\n";
    exit(0);
}

sub recipientTests()
{
    recipCheck('you@your.domain', 1, 1);
    recipCheck('you@your.domain', 1, 0);
    recipCheck('some.one.else@your.domain', 1, 1);
    recipCheck('some.one.else@your.domain', 1, 0);
    recipCheck('anyone@localhost', 1, 1);
    recipCheck('anyone@localhost', 1, 0);
    recipCheck('localhost', 0, 1);
    recipCheck('localhost', 0, 0);
    recipCheck('user%elsewhere.com@localhost', 0, 1);
    recipCheck('user%elsewhere.com@localhost', 0, 0);

    recipCheck('YOU@your.domain', 1, 1);
    recipCheck('YOU@your.domain', 0, 0);
    recipCheck('some.one.else@YOUR.domain', 1, 1);
    recipCheck('some.one.else@YOUR.domain', 0, 0);
    recipCheck('anyone@Localhost', 1, 1);
    recipCheck('anyone@Localhost', 0, 0);

    recipCheck('<user@elsewhere.com>your.domain', 0, 0);
    recipCheck('user@elsewhere.com(your.domain', 0, 0);
}

sub recipCheck
{
   my ($recip, $shouldBeGood, $emulate) = @_;
   my $secureMsg;

   $emulate = 0 if ! defined( $emulate );

   if ($emulate)
   {
     $secure = 0;
     $emulate_matts_code = 1;
     $secureMsg = 'insecure';
   }
   else
   {
     $secure = 1;
     $emulate_matts_code = 0;
     $secureMsg = 'secure';
   }

   if ($shouldBeGood)
   {
       if ((! check_email($recip)) or (! check_recipient($recip)))
       {
      warn "$recip should be good ($secureMsg)";
       }
   }
   else
   {
       if (check_email($recip) and check_recipient($recip))
       {
        warn "$recip should be bad ($secureMsg)";
       }
   }
}

sub refererTests
{
   refCheck('xxx.xxx.xxx', 0);
   refCheck('http://dave.org.uk', 1);
   refCheck('http://dave.org.uk/', 1);
   refCheck('http://dave.org.uk/more', 1);
   refCheck('https://dave.org.uk/', 1);
   refCheck(undef, 0, 0);
   refCheck(undef, 1, 1);
   refCheck('https://dave.org.uk@someplace.else.domain', 0);
   refCheck('https://dave.org.uk@someplace.else.domain', 0, 1);
   refCheck('https://someguy@dave.org.uk', 1, 1);
   refCheck('https://someguy@dave.org.uk', 1, 0);
   refCheck('https://someguy@dave.org.uk/more', 1, 0);
   refCheck('http://209.207.222.64', 1);
   refCheck('http://localhost/', 1);
}

sub refCheck
{
   my ($referer, $shouldBeGood, $emulate) = @_;
   my $secureMsg;

   $emulate = 0 if ! defined( $emulate );

   if ($emulate)
   {
     $secure = 0;
     $secureMsg = 'insecure';
   }
   else
   {
     $secure = 1;
     $secureMsg = 'secure';
   }

   if ($shouldBeGood)
   {
     warn "$referer should be good ($secureMsg)" if ! check_referer($referer);
   }
   else
   {
     warn "$referer should be bad ($secureMsg)" if check_referer($referer);
   }
}

