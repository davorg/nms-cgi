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
          START => 'guestbook/guestlog.html',
          NAME  => 'guestlog.html',
        },
);

my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'guestbook/guestbook.pl',
  REWRITERS    => [ \&rw_setup ],
  FILES        => \%files,
);

$t->run_test(
   TEST_ID     => "first post",
   CGI_ARGS    => [ 'realname=mr foo',
                    'username=foo@foo.foo',
		    'comments=foo',
		  ],
   CHECKS      => 'xhtml xhtml-GB xhtml-GL nodie',
);

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
}

