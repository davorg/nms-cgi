#!/usr/bin/perl -w
# $Id: create.t,v 1.2 2002-07-23 20:25:06 nickjc Exp $

use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

# this is a place holder

my $data_dir = $ENV{NMSTEST_DATDIR};

my @tests = (
  # METHOD     URI           COUNT
  [ 'GET',     '/foo.shtml', '00001' ],
  [ 'POST',    '/foo.shtml', '00002' ],
  [ 'POST',    '/bar%20foo', '00001' ],
  [ 'GET',     '/bar%20foo', '00002' ],
  [ 'POST',    '/bar foo',   '00001' ],
  [ 'GET',     '/bar foo',   '00002' ],
  [ 'POST',    '/bar foo',   '00003' ],
);

my $t;

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'textcounter/counter.pl',
  REWRITERS => [ \&rw_data ],
);

use vars qw($count);
run_tests($t, 1);

sub run_tests
{
   my ($t, $secure) = @_;

   foreach my $test (@tests)
   {
      $count = $test->[2];
      $t->run_test(
        TEST_ID        => "method $test->[0] -file $test->[1] $count",
	HTTP_REFERER   => 'http://foo.domain/',
	REQUEST_METHOD => $test->[0],
        CHECKER        => 'LocalChecks',
        CHECKS         => 'nodie expected_count',
        DOCUMENT_URI   => $test->[1],
      );
   }
}

sub LocalChecks::check_expected_count
{
   my ($self) = @_;

   unless ($self->{PAGES}{OUT} =~ m#<a href="http://nms-cgi.sourceforge.net/">(\d+)</a>#)
   {
      die "failed to find expected counter output\n";
   }

   unless ($1 eq $count)
   {
      die "wrong count: got [$1], expected [$count]\n";
   }
}

sub rw_data
{
   s|my\s+\$data_dir\s*=.*?;|my \$data_dir = '$data_dir';|;
}
