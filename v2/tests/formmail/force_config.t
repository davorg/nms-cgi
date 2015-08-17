#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);
sub LocalChecks::check_subject_foo
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /^Subject: foo$/m or die "subject not foo";
} 

NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'formmail/FormMail.pl',
   REWRITERS    => [ \&rw_setup ],
   HTTP_REFERER => 'http://foo.domain/',
   CHECKER      => 'LocalChecks',
   CHECKS       => 'xhtml nodie somemail subject_foo',
   TEST_ID      => "force config subject",
   CGI_ARGS     => [ 'subject=bar', 'wee=wee' ],
)->run_test;


sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;

   s#(\n\s+DEBUGGING\s+=>\s+\$DEBUGGING,\s*\n)#$1 'force_config_subject' => 'foo',\n#;
}

