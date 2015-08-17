#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;



NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'countdown/countdown.pl',
   REWRITERS    => [],
   FILES        => {},
   CGI_ARGS     => [],
   CHECKS      => 'nodie',
   TEST_ID     => "compiles and runs",
)->run_test;

