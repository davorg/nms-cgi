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
   s#(\s\$allow_empty_ref).*?;#$1 = 0;#;
   s#(\s\@referers).*?;#$1 = qw(dave.org.uk localhost 209.207.222.64);#;
   s#(\s\@allow_mail_to).*?;#$1 = qw(you\@your.domain some.one.else\@your.domain localhost);#;
   s#(__END__|\z)#$tests$1#;
}

__END__

sub handle_request
{
    my ($self) = @_;

    $self->recipientTests();
    $self->refererTests();
    print "All subtests ran\n";
    exit(0);
}

sub recipientTests()
{
    my ($self) = @_;

    $self->recipCheck('you@your.domain', 1, 1);
    $self->recipCheck('you@your.domain', 1, 0);
    $self->recipCheck('some.one.else@your.domain', 1, 1);
    $self->recipCheck('some.one.else@your.domain', 1, 0);
    $self->recipCheck('anyone@localhost', 1, 1);
    $self->recipCheck('anyone@localhost', 1, 0);
    $self->recipCheck('localhost', 0, 1);
    $self->recipCheck('localhost', 0, 0);
    $self->recipCheck('user%elsewhere.com@localhost', 0, 1);
    $self->recipCheck('user%elsewhere.com@localhost', 0, 0);

    $self->recipCheck('YOU@your.domain', 0, 1);
    $self->recipCheck('YOU@your.domain', 0, 0);
    $self->recipCheck('some.one.else@YOUR.domain', 1, 1);
    $self->recipCheck('some.one.else@YOUR.domain', 1, 0);
    $self->recipCheck('anyone@Localhost', 1, 1);
    $self->recipCheck('anyone@Localhost', 1, 0);

    $self->recipCheck('<user@elsewhere.com>your.domain', 0, 0);
    $self->recipCheck('user@elsewhere.com(your.domain', 0, 0);
}

sub recipCheck
{
   my ($self, $recip, $shouldBeGood, $emulate) = @_;
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
       if (! $self->recipient_is_ok($recip) )
       {
      warn "$recip should be good ($secureMsg)";
       }
   }
   else
   {
       if ( $self->recipient_is_ok($recip) )
       {
        warn "$recip should be bad ($secureMsg)";
       }
   }
}

sub refererTests
{
   my ($self) = @_;

   $self->refCheck('xxx.xxx.xxx', 0);
   $self->refCheck('http://dave.org.uk', 1);
   $self->refCheck('http://dave.org.uk/', 1);
   $self->refCheck('http://dave.org.uk/more', 1);
   $self->refCheck('https://dave.org.uk/', 1);
   $self->refCheck(undef, 0, 0);
   $self->refCheck(undef, 0, 1);
   $self->refCheck('https://dave.org.uk@someplace.else.domain', 0);
   $self->refCheck('https://dave.org.uk@someplace.else.domain', 0, 1);
   $self->refCheck('https://someguy@dave.org.uk', 1, 1);
   $self->refCheck('https://someguy@dave.org.uk', 1, 0);
   $self->refCheck('https://someguy@dave.org.uk/more', 1, 0);
   $self->refCheck('http://209.207.222.64', 1);
   $self->refCheck('http://localhost/', 1);
}

sub refCheck
{
   my ($self, $referer, $shouldBeGood, $emulate) = @_;
   my $secureMsg;

   $emulate = 0 if ! defined( $emulate );

   if ($emulate)
   {
     $self->{CFG}{secure} = 0;
     $secureMsg = 'insecure';
   }
   else
   {
     $self->{CFG}{secure} = 1;
     $secureMsg = 'secure';
   }

   if ($shouldBeGood)
   {
     warn "$referer should be good ($secureMsg)" if ! $self->referer_is_ok($referer);
   }
   else
   {
     warn "$referer should be bad ($secureMsg)" if $self->referer_is_ok($referer);
   }
}

