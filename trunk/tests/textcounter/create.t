#!/usr/bin/perl -w
# $Id: create.t,v 1.1 2002-02-26 20:57:01 gellyfish Exp $

use strict;

use NMSTest::ScriptUnderTest;

# this is a place holder

my $data_dir = '/tmp';

my @tests = (
  # METHOD  URI     
  [ 'GET',         '/foo.shtml' ],
  [ 'POST',         '/foo.shtml' ],
  [ 'POST',        '/bar%20foo' ],
  [ 'GET',        '/bar%20foo' ],
  [ 'POST',        '/bar foo' ],
  [ 'GET',        '/bar foo' ],
);

my $t;

$t = NMSTest::ScriptUnderTest->new(
  SCRIPT    => 'textcounter/counter.pl',
  REWRITERS => [ \&rw_data ],
);

run_tests($t, 1);

sub run_tests
{
   my ($t, $secure) = @_;

   foreach my $test (@tests)
   {
      $t->run_test(
        TEST_ID        => "method $test->[0] -file $test->[1]",
	HTTP_REFERER   => 'http://foo.domain/',
	REQUEST_METHOD => $test->[0],
        CHECKS         => 'nodie',
        DOCUMENT_URI   => $test->[1],
      );
   }
}

sub rw_data
{
   s|my\s+\$data_dir\s*=.*?;|my \$data_dir = '$data_dir';|;
}
