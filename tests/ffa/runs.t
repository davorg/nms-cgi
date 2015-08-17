#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  LINKS   => {
              START => 'ffa/links.html',
              NAME  => 'links.html',
             },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'ffa/ffa.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => ['foo=foo', 'bar=bar'],
   CHECKS      => 'nodie xhtml-LINKS',
   TEST_ID     => "compiles and runs",
)->run_test;


sub rw_setup
{
   my $basedir = $files{LINKS}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$directory\s*=).*}{$1 '$basedir';} or die;
}

