#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my @args = (
  'email=foo@foo.domain',
  'foo=foo',
  'realname=Larry Foo (not) another ))))foo'.('x'x200),
);

use vars qw($secure);

foreach $secure (0, 1)
{
   NMSTest::ScriptUnderTest->new(
     SCRIPT          => 'formmail/FormMail.pl',
     REWRITERS       => [ \&rw_setup ],
     TEST_ID         => "realname filter, secure=$secure",
     CGI_ARGS        => \@args,
     HTTP_REFERER    => 'http://foo.domain/',
     CHECKER         => 'LocalChecks',
     CHECKS          => 'xhtml nodie somemail realname',
   )->run_test;
}

sub LocalChecks::check_realname
{
   my ($self) = @_;

   foreach my $mail ('main', 'conf')
   {
      my $pagename = ( $mail eq 'main' ? 'MAIL1' : 'MAIL2' );
      my $prefix   = ( $mail eq 'main' ? 'From'  : 'To' );
      $self->{PAGES}{$pagename} =~ /^$prefix: .*?\((.*)\)\n/m or
         die "can't find the realname in the $mail email";
      my $realname = $1;

      $realname =~ /([\(\)])/ and die "'$1' in realname in $mail";
      $realname =~ /^Larry Foo/ or die "realname munged too much in $mail";

      length $realname > 150 and die "realname too long in $mail";
   }
}

sub rw_setup
{
   s|\s+\$secure\s*=.*?;| \$secure = $secure;|;
   s|\s+\$send_confirmation_mail\s*=.*?;| \$send_confirmation_mail = 1;|;
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

