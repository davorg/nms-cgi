#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw(@yes @no $block);

my %files = (
  _1 => {
         START => \"this is file one. moggie and gonk.\n",
         NAME  => 'basedir/one.txt',
        },
  _2 => {
         START => \"this is file two (foo), maggie. candles gonk\n",
         NAME  => 'basedir/two.html',
        },
  _3 => {
         START => \"yada yada yada gonk\n",
         NAME  => 'basedir/bar.html',
        },
  _4 => {
         START => \"moooooooooooooooooooooo gonk\n",
         NAME  => 'basedir/foo/four.html',
        },
  _5 => {
         START => \"wheeeeeeeeeeeeeeeeee gonk\n",
         NAME  => 'basedir/bar/five.html',
        },

);

$block = 0;
@yes=qw(two bar.html four five);
@no=qw(one);
NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'search/search.pl',
  REWRITERS    => [ \&rw_setup ],
  CHECKS       => 'xhtml nodie nomail expect_text',
  FILES        => \%files,
  CHECKER      => 'LocalChecks',
  TEST_ID      => "none blocked",
  CGI_ARGS     => ["terms=gonk"],
)->run_test;


$block = 1;
my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'search/search.pl',
  REWRITERS    => [ \&rw_setup ],
  CHECKS       => 'xhtml nodie nomail expect_text',
  FILES        => \%files,
  CHECKER      => 'LocalChecks',
  CGI_ARGS     => ["terms=gonk"],
);

@yes=qw(two five);
@no=qw(one bar.html four);
$t->run_test(
  TEST_ID      => "some blocked",
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
   if ($block)
   {
      s#(\s\@blocked\s*=).*;#$1 qw(foo bar.html);# or die;
   }
}

