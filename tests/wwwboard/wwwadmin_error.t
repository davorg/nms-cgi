#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($expect_error_message);

my %files =
(
  DATA   => {
              START => \"0",
              NAME  => 'data.txt',
            },
);


$expect_error_message = "Could Not Open Password File For Reading";
NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'wwwboard/wwwadmin.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => ['foo=foo', 'bar=bar'],
   CHECKS       => 'xhtml nodie errormsg',
   CHECKER      => 'LocalChecks',
   TEST_ID      => "wwwadmin missing pw file",
)->run_test;

%files =
(
  DATA   => {
              START => \"0",
              NAME  => 'data.txt',
            },
  PASS   => {
              START => 'wwwboard/passwd.txt',
              NAME  => 'passwd.txt',
            },
);

$expect_error_message = "Bad Username - Password Combination";

my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'wwwboard/wwwadmin.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CHECKS       => 'xhtml nodie errormsg',
   CHECKER      => 'LocalChecks',
);

$t->run_test(
   TEST_ID      => "wwwadmin incorrect username",
   CGI_ARGS     => ['username=foo', 'password=WebBoard'],
);

$t->run_test(
   TEST_ID      => "wwwadmin incorrect password",
   CGI_ARGS     => ['username=WebAdmin', 'password=foo'],
);


sub LocalChecks::check_errormsg
{
   my ($self) = @_;

   $self->{PAGES}{OUT} =~ /\Q$expect_error_message/ or die
      "did't find [$expect_error_message] in output page";
}

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}{$1 '$basedir';} or die;
}

