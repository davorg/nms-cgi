#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw(@goodutf @badutf);

# Some test sequences from http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt

@goodutf = ( "\x41\xE2\x89\xA2\xCE\x91\x2E",
             "\xED\x95\x9C\xEA\xB5\xAD\xEC\x96\xB4",
             "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E",
             "\xC2\xA9",
             "\xE2\x89\xA0",
             "\xED\x9F\xBF",
             "\xEE\x80\x80",
             "\xEF\xBF\xBD",
             "\xF4\x8F\xBF\xBF",
             "\xF4\x90\x80\x80",
           );

@badutf = ( (split //, pack 'C*', 127..255),
            "\x2F\xC0\xAE\x2E\x2F",
            "\xA3\xA3",
            "\xC0\xAF",
            "\xE0\x80\xAF",
            "\xF0\x80\x80\xAF",
            "\xF8\x80\x80\x80\xAF",
            "\xFC\x80\x80\x80\x80\xAF",
            "\xC1\xBF",
            "\xE0\x9F\xBF",
            "\xF0\x8F\xBF\xBF",
            "\xF8\x87\xBF\xBF\xBF",
            "\xFC\x83\xBF\xBF\xBF\xBF",
            "\xC0\x80",
            "\xE0\x80\x80",
            "\xF0\x80\x80\x80",
            "\xF8\x80\x80\x80\x80",
            "\xFC\x80\x80\x80\x80\x80",
            "\xED\xAD\xBF",
            "\xED\xAE\x80",
            "\xED\xAF\xBF",
            "\xED\xB0\x80",
            "\xED\xBE\x80",
            "\xED\xBF\xBF",
	    "\xED\xA0\x80\xED\xB0\x80",
	    "\xED\xA0\x80\xED\xBF\xBF",
	    "\xED\xAD\xBF\xED\xB0\x80",
	    "\xED\xAD\xBF\xED\xBF\xBF",
	    "\xED\xAE\x80\xED\xB0\x80",
	    "\xED\xAE\x80\xED\xBF\xBF",
	    "\xED\xAF\xBF\xED\xB0\x80",
	    "\xED\xAF\xBF\xED\xBF\xBF",
	    "\xEF\xBF\xBE",
	    "\xEF\xBF\xBF",
          );

my $string = join "\n", map {"-$_-"} (@goodutf, @badutf);

NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   CHECKER     => 'LocalChecks',
   TEST_ID     => "utf-8",
   CGI_ARGS    => [ 'foo=<foo>', "string=$string" ],
   CHECKS      => 'xhtml nodie utf8',
)->run_test;

sub LocalChecks::check_utf8
{
   my ($self) = @_;

   foreach my $page (qw(OUT MAIL1))
   {
      local $_ = $self->{PAGES}{$page};
      
      if (  /\x7F|\xFE|\xFF/
         or /[\x00-\x7F][\x80-\xFF][\x00-\x7F]/
         )
      {
         die "invalid utf-8 in page $page\n";
      }

      foreach my $badutf (@badutf)
      {
         /-\Q$badutf\E-/ and die "bad utf-8 sequence in page $page\n";
      }

      foreach my $goodutf (@goodutf)
      {
         /-\Q$goodutf\E-/ or die "good utf-8 sequence missing from page $page\n";
      }
   }
}

sub rw_setup
{
   s{(POSTMASTER\s*=>).*}    {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}        {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*}   {$1 '$ENV{NMS_WORKING_COPY}/tests/tfmail';};
   s{(CHARSET\s*=>).*}       {$1 'utf-8';};
   s{(USE_MIME_LITE\s*=>).*} {$1 0;};
}


