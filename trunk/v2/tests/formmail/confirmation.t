#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);


my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'formmail/FormMail.pl',
   REWRITERS    => [ \&rw_setup ],
   HTTP_REFERER => 'http://foo.domain/',
   CHECKER      => 'LocalChecks',
   CHECKS       => 'nodie xhtml somemail conf',
);

use vars qw($conf);


$conf = 1;
$t->run_test(
   TEST_ID      => "confirmation good e no r",
   CGI_ARGS     => ['foo=foo', 'email=x@x.x'],
);

$t->run_test(
   TEST_ID      => "confirmation good e good r",
   CGI_ARGS     => ['foo=foo', 'email=x@x.x', 'realname=Fred Foo'],
);

$t->run_test(
   TEST_ID      => "confirmation good e bad r",
   CGI_ARGS     => ['foo=foo', 'email=x@x.x', "realname=<<\"x\001"],
);

$conf = 0;

$t->run_test(
   TEST_ID      => "confirmation no e good r",
   CGI_ARGS     => ['foo=foo', 'realname=Fred Foo'],
);

$t->run_test(
   TEST_ID      => "confirmation bad e good r",
   CGI_ARGS     => ['foo=foo', 'email=@', 'realname=Fred Foo'],
);

sub LocalChecks::check_conf
{
   my ($self) = @_;

   if ($conf)
   {
      exists $self->{PAGES}{MAIL2} or die "no conf";
   }
   else
   {
      exists $self->{PAGES}{MAIL2} and die "bad conf";
   }
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s| +\$send_confirmation_mail\s*=.*?;| \$send_confirmation_mail = 1;| or die;
}

