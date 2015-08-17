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
         START => \"PRIVATE gonk FILE\n",
         NAME  => 'basedir/nqblog/pgfile.html',
        },
  _4 => {
         START => \"PRIVATE gonk FILE\n",
         NAME  => 'basedir/_private/foo/pgfile.html',
        },
  _5 => {
         START => \"PRIVATE gonk FILE\n",
         NAME  => 'basedir/_private/pgfile.html',
        },
  _6 => {
         START => \"this is a PRIVATE gonk FILE\n",
         NAME  => 'basedir/.status/pgfile.html',
        },
  _7 => {
         START => \"this too is a PRIVATE gonk FILE\n",
         NAME  => 'basedir/.status/old/pgfile.html',
        },
  _8 => {
         START => \"this is a PRIVATE gonk FILE\n",
         NAME  => 'basedir/ib-bin/pgfile.html',
        },
  _9 => {
         START => \"this too is a PRIVATE gonk FILE\n",
         NAME  => 'basedir/ib-bin/old/pgfile.html',
        },
);

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'search/search.pl',
  REWRITERS    => [ \&rw_setup ],
  CHECKS       => 'xhtml nodie nomail expect_text',
  FILES        => \%files,
  CHECKER      => 'LocalChecks',
  TEST_ID      => "blocked .dir with emulate 0",
  CGI_ARGS     => ["terms=gonk"],
)->run_test;


sub LocalChecks::check_expect_text
{
   my ($self) = @_;

   $self->{PAGES}{OUT} =~ /two\.html/ or die "public text missing from output";
   $self->{PAGES}{OUT} =~ /private/i and die "private text in output";
}


sub rw_setup
{
   my $basedir = $files{_1}{PATH};
   $basedir =~ s#/one.txt$## or die;


   s#(\s\$basedir\s*=).*;#$1 '$basedir';# or die;
   s#(\s\@blocked\s*=).*;#$1 ('_private','nqblog','.status','chat','ib-bin','iB_html','resources');# or die;
   s#(\s\$emulate_matts_code\s*=).*;#$1 0;# or die;
   s#(\s\@files\s*=).*;#$1 ('*.html','*/*.html','*.shtml');# or die;

}

