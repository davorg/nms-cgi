#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($allow_html);

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
);

foreach $allow_html (0, 1)
{
   
   NMSTest::ScriptUnderTest->new(
      SCRIPT      => 'wwwboard/wwwboard.pl',
      REWRITERS   => [ \&rw_setup ],
      FILES       => \%files,
      CGI_ARGS    => ['body=<i>italic</i>', 'name=Name', 'subject=yoda'],
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 nodie allow_html',
      CHECKER     => 'LocalChecks', 
      TEST_ID     => "allow_html $allow_html",
   )->run_test;
}

sub LocalChecks::check_allow_html
{
   my ($self) = @_;

   if ( $allow_html )
   {
      $self->{PAGES}{OUT}   =~ m#<i>italic</i># or die "html wrongly blocked";
      $self->{PAGES}{MSG01} =~ m#<i>italic</i># or die "html wrongly blocked";
   }
   else
   {
      $self->{PAGES}{OUT}   =~ m#<i>italic</i># and die "html wrongly allowed";
      $self->{PAGES}{MSG01} =~ m#<i>italic</i># and die "html wrongly allowed";
   }
}

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}   {$1 '$basedir';} or die;
   s{(\s*\$allow_html\s*=).*}{$1 $allow_html;} or die;
}


