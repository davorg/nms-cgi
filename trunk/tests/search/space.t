#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files = (
  _1 => {
         START => \"this is file one. moggie foo.\n",
         NAME  => 'basedir/one two/three four.html',
        },
);

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'search/search.pl',
  REWRITERS    => [ \&rw_setup ],
  CHECKS       => 'xhtml nodie nomail expect_text',
  FILES        => \%files,
  CHECKER      => 'LocalChecks',
  CGI_ARGS     => ["terms=moggie"],
  TEST_ID      => 'space in filename',
)->run_test;


sub LocalChecks::check_expect_text
{
   my ($self) = @_;

   die "no moggie" if $self->{PAGES}{OUT} !~ /moggie/;

   die "no href" if $self->{PAGES}{OUT} !~ m#"http://localhost/one two/three four\.html"#;
}

sub rw_setup
{
   my $basedir = $files{_1}{PATH};
   $basedir =~ s#/one two/.*$## or die;

   s#(\s\$basedir\s*=).*;#$1 '$basedir';# or die;
   s#(\s\@files\s*=).*;#$1 qw(*.html */*.html);# or die;
}

