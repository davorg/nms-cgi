#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my @args = (
  'env_report=HTTP_USER_AGENT',
  'foolt=a<a',
  'foogt=b>b',
  'fooqt=c"c',
  'one>two=no',
  'one<two=yes',
  'one"two=foo',
  "ab\0\x01\x05=waa",
  "bar\x01\x05foo=waa",
  "bar=\x01x",
  "barbar=\0x",
  "lines=three\ndifferent\nones\n",
  "allchars=" . pack('C*', (0..255)),
);

NMSTest::ScriptUnderTest->new(
  SCRIPT          => 'formmail/FormMail.pl',
  REWRITERS       => [ \&rw_setup ],
  TEST_ID         => 'output charset',
  CGI_ARGS        => \@args,
  HTTP_REFERER    => 'http://foo.domain/',
  CHECKER         => 'LocalChecks',
  CHECKS          => 'xhtml nodie somemail transforms',
  HTTP_USER_AGENT => "\x01\cL version 0.01",
)->run_test;

sub LocalChecks::check_transforms
{
   my ($self) = @_;

   if ($self->{PAGES}{OUT} =~ /([^\t\r\n\040-\176\200-\377])/)
   {
      die sprintf "bad character 0x%.2X in output\n", ord $1;
   }
   if ($self->{PAGES}{MAIL1} =~ /([^\t\r\n\040-\176\200-\377])/)
   {
      die sprintf "bad character 0x%.2X in email\n", ord $1;
   }

   $self->{PAGES}{MAIL1} =~ /(&lt;|&gt;|&quot;)/ and die 
      "$1 escape in mail, error ?\n"; 
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

