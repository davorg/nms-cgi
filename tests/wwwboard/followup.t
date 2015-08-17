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
  MSG02  => {
              NAME  => 'messages/2.html',
            },
);

my $t = NMSTest::ScriptUnderTest->new(
      SCRIPT      => 'wwwboard/wwwboard.pl',
      REWRITERS   => [ \&rw_setup ],
      FILES       => \%files,
   );

$t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 nodie',
      CGI_ARGS    => ['body=hello', 'name=Name', 'subject=yoda'],
      TEST_ID     => "first post",
);

$t->run_test(
      CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 xhtml-MSG02 nodie',
      CGI_ARGS    => ['body=hello',
                      'name=Name',
                      'subject=Re:yoda',
                      'followup=1',
                      'origname=Name',
                      'origsubject=yoda',
                      'origdate=08:05:00 31/08/02',
                     ],
      TEST_ID     => "first followup",
);

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}   {$1 '$basedir';} or die;
}


