#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  DATA   => {
              START => \"0",
              NAME  => 'data.txt',
            },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'wwwboard/wwwboard.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => ['foo=foo', 'bar=bar'],
   CHECKS      => 'xhtml nodie',
   TEST_ID     => "wwwboard.pl runs",
)->run_test;

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(my\s*\$basedir\s*=).*}{$1 '$basedir';};
}


