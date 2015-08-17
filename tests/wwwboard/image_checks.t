#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($allow_html);

my %files =
(
  DATA   => {
              START => \"0",
              NAME  => 'data.txt',
            },
  MAIN   => {
              START => 'wwwboard/wwwboard.html',
              NAME  => 'wwwboard.html',
            },
);

my @tests = (
# name, ok, okstrict, url
  [ 'https gif', 1, 1, 'https://foo.domain/img/foo.gif' ],
  [ 'https exe', 1, 0, 'https://foo.domain/img/foo.exe' ],
  [ 'http gif',  1, 1, 'https://foo.domain/img/foo.gif' ],
  [ 'http exe',  1, 0, 'https://foo.domain/img/foo.exe' ],
  [ 'bare gif',  1, 1, 'foo.domain/img/foo.gif'         ],
  [ 'bare exe',  1, 0, 'foo.domain/img/foo.exe'         ],
  [ 'case gif',  1, 1, 'http://foo.DOMAIN/Img/fOo.GIF'  ],
  [ 'case exe',  1, 0, 'http://foo.DOMAIN/Img/fOo.EXE'  ],
  [ 'foo',       0, 0, 'foo://foo.foo/foo.gif'          ],
);

use vars qw($strict_img  $ok  $url);
foreach $strict_img (0, 1)
{
   
   my $t = NMSTest::ScriptUnderTest->new(
      SCRIPT      => 'wwwboard/wwwboard.pl',
      REWRITERS   => [ \&rw_setup ],
      FILES       => \%files,
      CHECKS      => 'xhtml xhtml-MAIN nodie img',
      CHECKER     => 'LocalChecks', 
   );
   foreach my $test (@tests)
   {
      my ($name, $okstrict);
      ($name, $ok, $okstrict, $url) = @$test;
      $ok = $okstrict if $strict_img;
      $t->run_test(
         CGI_ARGS    => ['body=foo', 'name=Name', 'subject=yoda', "img=$url"],
         TEST_ID     => "img $name strict=$strict_img",
      )
   }
}

sub LocalChecks::check_img
{
   my ($self) = @_;

   if ( $ok )
   {
      $self->{PAGES}{OUT} =~ m#<img\s*src=.*\Q$url#i or die "URL wrongly blocked";
   }
   else
   {
      $self->{PAGES}{OUT} =~ m#<img\s*src=.*\Q$url#i and die "URL wrongly allowed";
   }
}

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}   {$1 '$basedir';} or die;
   s{(\s*\$strict_image\s*=).*}{$1 $strict_img;} or die;
}


