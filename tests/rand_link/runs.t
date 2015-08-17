#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  _FOO   => {
              START => \"http://www.testtest.com/",
              NAME  => 'foo.txt',
            },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'rand_link/rand_link.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => [],
   CHECKS      => 'nodie',
   TEST_ID     => "compiles and runs",
)->run_test;


sub rw_setup
{
   my $linkfile = $files{_FOO}{PATH};
   $linkfile =~ s#/[^/]+$##;

   s{(\s*\$linkfile\s*=).*}{$1 '$linkfile';} or die;
}

