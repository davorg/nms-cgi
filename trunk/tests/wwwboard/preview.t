#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($preview $msgcount);

my %files =
(
  DATA   => {
              START => \"0",
              NAME  => 'data.txt',
            },
  MAIN   => {
              START => 'wwwboard/wwwboard.html',
              NAME  => 'wwwboard.html',
            },
  MSG01  => {
              NAME  => 'messages/1.html',
            },
  MSG02  => {
              NAME  => 'messages/2.html',
            },
);

foreach $preview (0, 1)
{
   my $t = NMSTest::ScriptUnderTest->new(
      SCRIPT      => 'wwwboard/wwwboard.pl',
      REWRITERS   => [ \&rw_setup ],
      FILES       => \%files,
      CHECKER     => 'LocalChecks',
   );

   $msgcount = 0;
   $t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN nodie preview',
      CGI_ARGS    => ['body=hello', 'name=Name', 'subject=yoda', 'preview=Preview'],
      TEST_ID     => "first post preview p=$preview",
   );

   $msgcount = 1;
   $t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 nodie preview',
      CGI_ARGS    => ['body=hello', 'name=Name', 'subject=yoda' ],
      TEST_ID     => "first post nonpreview p=$preview",
   );

   $msgcount = 1;
   $t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 nodie preview',
      CGI_ARGS    => ['body=hello',
                      'name=Name',
                      'subject=Re:yoda',
                      'followup=1',
                      'origname=Name',
                      'origsubject=yoda',
                      'origdate=08:05:00 31/08/02',
                      'preview=Preview',
                     ],
      TEST_ID     => "followup preview p=$preview",
   );

   $msgcount = 2;
   $t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 xhtml-MSG02 nodie preview',
      CGI_ARGS    => ['body=hello',
                      'name=Name',
                      'subject=Re:yoda',
                      'followup=1',
                      'origname=Name',
                      'origsubject=yoda',
                      'origdate=08:05:00 31/08/02',
                     ],
      TEST_ID     => "followup nonpreview p=$preview",
   );
}

sub LocalChecks::check_preview
{
   my ($self) = @_;

   if ($msgcount < 1)
   {
      $self->{PAGES}{MSG01} =~ /<<<FILE ABSENT>>>/ or die "MSG01 found";
   }
   if ($msgcount < 2)
   {
      $self->{PAGES}{MSG02} =~ /<<<FILE ABSENT>>>/ or die "MSG02 found";
   }
   
   if ($preview)
   {
      $self->{PAGES}{MSG01} =~ /name="preview"/ or die "preview input missing from MSG01" if $msgcount >= 1;
      $self->{PAGES}{MSG02} =~ /name="preview"/ or die "preview input missing from MSG02" if $msgcount >= 2;
   }
   else
   {
      $self->{PAGES}{MSG01} =~ /name="preview"/ and die "preview input found in MSG01" if $msgcount >= 1;
      $self->{PAGES}{MSG02} =~ /name="preview"/ and die "preview input found in MSG02" if $msgcount >= 2;
   }
}

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}       {$1 '$basedir';} or die;
   s{(\s*\$enable_preview\s*=).*}{$1 $preview;}          or die;
}


