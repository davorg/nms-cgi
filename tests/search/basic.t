#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw(@yes @no);

my %files = (
  _1 => {
         START => \"this is file one. moggie.\n",
         NAME  => 'basedir/one.txt',
        },
  _2 => {
         START => \"this is file two (foo), maggie. candles\n",
         NAME  => 'basedir/two.html',
        },
);

my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'search/search.pl',
  REWRITERS    => [ \&rw_setup ],
  CHECKS       => 'xhtml nodie nomail expect_text',
  FILES        => \%files,
  CHECKER      => 'LocalChecks',
);

@yes=();
@no=qw(one two);
$t->run_test(
  TEST_ID      => "no args",
  CGI_ARGS     => [],
);

@yes=qw(two);
@no=qw(one);
$t->run_test(
  TEST_ID      => "search for candles",
  CGI_ARGS     => ["terms=candles"],
);

@yes=();
@no=qw(one two);
$t->run_test(
  TEST_ID      => "ignore .txt file",
  CGI_ARGS     => ["terms=moggie"],
);


sub LocalChecks::check_expect_text
{
   my ($self) = @_;

   foreach my $yes (@yes)
   {
      die "no text [$yes]" if $self->{PAGES}{OUT} !~ /\Q$yes/;
   }
   foreach my $no (@no)
   {
      die "got text [$no]" if $self->{PAGES}{OUT} =~ /\Q$no/;
   }
}

sub rw_setup
{
   my $basedir = $files{_1}{PATH};
   $basedir =~ s#/one.txt$## or die;

   s#(\s\$basedir\s*=).*;#$1 '$basedir';# or die;
}

