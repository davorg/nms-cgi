#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  _FOO   => {
              START => \"<<<pretent this is a jpg, tnx>>>",
              NAME  => 'foo.jpg',
            },
  _BAH   => {
              START => \"<<<pretent this is a png, tnx>>>",
              NAME  => 'bah.png',
            },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'rand_image/rand_image.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => ['foo=foo', 'bar=bar'],
   CHECKS      => 'nodie',
   TEST_ID     => "compiles and runs",
)->run_test;


sub rw_setup
{
   my $basedir = $files{_FOO}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}{$1 '$basedir';} or die;
}

