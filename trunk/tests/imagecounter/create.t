#!/usr/bin/perl -w
# $Id: create.t,v 1.1 2002-07-31 08:12:49 nickjc Exp $

use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

# this is a place holder

my $data_dir = $ENV{NMSTEST_DATDIR};

my @tests = (
  # METHOD     URI           COUNT
  [ 'GET',     '/foo.shtml', '1' ],
  [ 'POST',    '/foo.shtml', '2' ],
  [ 'POST',    '/bar%20foo', '1' ],
  [ 'GET',     '/bar%20foo', '2' ],
  [ 'POST',    '/bar foo',   '1' ],
  [ 'GET',     '/bar foo',   '2' ],
  [ 'POST',    '/bar foo',   '3' ],
  [ 'POST',    '/bar foo',   '4' ],
  [ 'POST',    '/bar foo',   '5' ],
  [ 'POST',    '/bar foo',   '6' ],
  [ 'POST',    '/bar foo',   '7' ],
  [ 'POST',    '/bar foo',   '8' ],
  [ 'POST',    '/bar foo',   '9' ],
  [ 'POST',    '/bar foo',   '10' ],
  [ 'POST',    '/bar foo',   '11' ],
);

my $t;

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'imagecounter/icounter.pl',
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

   my $page = $self->{PAGES}{OUT};
   my $countgot = '';
   while ($page =~ s#<img src="[^"]*?/(\d+)\.(?:png|gif)" alt="(\d+)" />\s*##)
   {
      die "used digit $1 with alt $2" unless $1 eq $2;
      $countgot .= $1;
   }

   unless ($countgot eq $count)
   {
      die "wrong count: got [$countgot], expected [$count]\n";
   }
}

sub rw_data
{
   s|my\s+\$data_dir\s*=.*?;|my \$data_dir = '$data_dir';|;
}
