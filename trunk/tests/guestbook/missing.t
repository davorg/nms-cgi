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

my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'guestbook/guestbook.pl',
  REWRITERS    => [ \&rw_setup ],
  FILES        => \%files,
  CHECKS      => 'xhtml xhtml-GB xhtml-GL nodie nomail',
);

my $comments = "<foo>&amp;amp;hello\n";

$t->run_test(
  TEST_ID     => 'no comments',
  CGI_ARGS    => [ 'realname=mr foo',
                   'username=foo@foo.foo',
                 ],
);

$t->run_test(
  TEST_ID     => 'no realname',
  CGI_ARGS    => [ "comments=$comments",
                   'username=foo@foo.foo',
                 ],
);

$t->run_test(
  TEST_ID     => 'no realname, comments enc',
  CGI_ARGS    => [ "comments=$comments",
                   'username=foo@foo.foo',
		   'encoded_comments=1',
                 ],
);

$t->run_test(
  TEST_ID     => 'no realname no comments',
  CGI_ARGS    => [ 'username=foo@foo.foo',
                 ],
);

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
}

