#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  GB => {
          START => 'guestbook/guestbook.html',
          NAME  => 'guestbook.html',
        },
  GL => {
          NAME  => 'guestlog.html',
          START => 'guestbook/guestlog.html',
        },
);

my $comments = <<END_OF_COMMENT;
<b>foo</b><foo>foo</foo>

   &amp;amp;amp;amp;
   &

\240&nbsp;

    &nbsp;   => "\240", &iexcl;  => "\241",
    &cent;   => "\242", &pound;  => "\243",
    &curren; => "\244", &yen;    => "\245",
    &brvbar; => "\246", &sect;   => "\247",
    &uml;    => "\250", &copy;   => "\251",
    &ordf;   => "\252", &laquo;  => "\253",
    &not;    => "\254", &shy;    => "\255",
    &reg;    => "\256", &macr;   => "\257",
    &deg;    => "\260", &plusmn; => "\261",
    &sup2;   => "\262", &sup3;   => "\263",
    &acute;  => "\264", &micro;  => "\265",
    &para;   => "\266", &middot; => "\267",
    &cedil;  => "\270", &supl;   => "\271",
    &ordm;   => "\272", &raquo;  => "\273",
    &frac14; => "\274", &frac12; => "\275",
    &frac34; => "\276", &iquest; => "\277",

    &Agrave; => "\300", &Aacute; => "\301",
    &Acirc;  => "\302", &Atilde; => "\303",
    &Auml;   => "\304", &Aring;  => "\305",
    &AElig;  => "\306", &Ccedil; => "\307",
    &Egrave; => "\310", &Eacute; => "\311",
    &Ecirc;  => "\312", &Euml;   => "\313",
    &Igrave; => "\314", &Iacute; => "\315",
    &Icirc;  => "\316", &Iuml;   => "\317",
    &ETH;    => "\320", &Ntilde; => "\321",
    &Ograve; => "\322", &Oacute; => "\323",
    &Ocirc;  => "\324", &Otilde; => "\325",
    &Ouml;   => "\326", &times;  => "\327",
    &Oslash; => "\330", &Ugrave; => "\331",
    &Uacute; => "\332", &Ucirc;  => "\333",
    &Uuml;   => "\334", &Yacute; => "\335",
    &THORN;  => "\336", &szlig;  => "\337",

    &agrave; => "\340", &aacute; => "\341",
    &acirc;  => "\342", &atilde; => "\343",
    &auml;   => "\344", &aring;  => "\345",
    &aelig;  => "\346", &ccedil; => "\347",
    &egrave; => "\350", &eacute; => "\351",
    &ecirc;  => "\352", &euml;   => "\353",
    &igrave; => "\354", &iacute; => "\355",
    &icirc;  => "\356", &iuml;   => "\357",
    &eth;    => "\360", &ntilde; => "\361",
    &ograve; => "\362", &oacute; => "\363",
    &ocirc;  => "\364", &otilde; => "\365",
    &ouml;   => "\366", &divide; => "\367",
    &oslash; => "\370", &ugrave; => "\371",
    &uacute; => "\372", &ucirc;  => "\373",
    &uuml;   => "\374", &yacute; => "\375",
    &thorn;  => "\376", &yuml;   => "\377",

<<<pah>>>
END_OF_COMMENT


use vars qw($allow_html $line_breaks);

foreach my $ah (0,1)
{
   $allow_html = $ah;
   
   foreach my $lb (0, 1)
   {
      $line_breaks = $lb;

      NMSTest::ScriptUnderTest->new(
        SCRIPT       => 'guestbook/guestbook.pl',
        REWRITERS    => [ \&rw_setup ],
        FILES        => \%files,
        CHECKS       => 'xhtml xhtml-GB xhtml-GL nodie nomail',
	TEST_ID      => "big comment ah=$ah lb=$lb",
	CGI_ARGS     => [ 'realname=Fred the Web User',
                          "comments=$comments",
			  'username=foo@foo.foo',
                        ],
      )->run_test;
   }
}

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
   s#(\s\$allow_html\s*=).*;#$1 $allow_html;#;
   s#(\s\$line_breaks\s*=).*;#$1 $line_breaks;#;
}

