#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($html);

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
  MSG01  => {
              NAME  => 'messages/1.html',
            },
);

my $in= q{foo<table><tr><td>hello</td><td>there</td></tr></table>}
      . q{picture: <img src="http://foo.foo/foo.png" /><br /><hr />}
      . q{<a href="mailto:foo@foo.foo">mailto link</a>}
      . q{<a href="http://foo.foo/cgi-bin/foo.pl?adsfdf%34asdfs">http link</a>}
      . q{<p><font color="red">red</font></p>};

$html = $in;

# wwwboard puts <p> </p> around the message, and the filter will close
# the p early when it hits the table.
$html =~ s#^foo#<p>foo</p>#;

# The filter will escape some of these characters
$html =~ s/\%/&#37;/g;
$html =~ s/\?/&#63;/g;
$html =~ s/\@/&#64;/g;

NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'wwwboard/wwwboard.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
   CGI_ARGS    => ["body=$in", 'name=Name', 'subject=yoda'],
   CHECKS      => 'xhtml xhtml-MAIN xhtml-MSG01 nodie allow_html',
   CHECKER     => 'LocalChecks', 
   TEST_ID     => "allow complex html",
)->run_test;

sub LocalChecks::check_allow_html
{
   my ($self) = @_;

   $self->{PAGES}{OUT}   =~ m#\Q$html# or die "html mangled";
   $self->{PAGES}{MSG01} =~ m#\Q$html# or die "html mangled";
}

sub rw_setup
{
   my $basedir = $files{DATA}{PATH};
   $basedir =~ s#/[^/]+$##;

   s{(\s*\$basedir\s*=).*}   {$1 '$basedir';} or die;
   s{(\s*\$allow_html\s*=).*}{$1 1;}          or die;
}


