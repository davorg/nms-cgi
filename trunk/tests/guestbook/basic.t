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
        },
);

use vars qw($entry_order);
foreach my $eo (0,1)
{
   $entry_order = $eo;
   
   foreach my $badlog (0, 1)
   {
      $files{GL}{START} = ( $badlog 
                          ? 'tests/guestbook/guestlog_noclose.html'
	                  : 'guestbook/guestlog.html'
	                  );

      my $t = NMSTest::ScriptUnderTest->new(
        SCRIPT       => 'guestbook/guestbook.pl',
        REWRITERS    => [ \&rw_setup ],
        FILES        => \%files,
        CHECKS      => 'xhtml xhtml-GB xhtml-GL nodie nomail',
      );
   
      $t->run_test(
         TEST_ID     => "first post eo=$eo badlog=$badlog",
         CGI_ARGS    => [ 'realname=mr foo',
                          'username=foo@foo.foo',
                          'comments=foo',
                        ],
      );
      
      $t->run_test(
         TEST_ID     => "second post eo=$eo badlog=$badlog",
         CGI_ARGS    => [ 'realname=The other mr foo',
                          'username=other-foo@foo.foo',
                          'comments=more foo',
                        ],
      );
   }
}

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
   s#(\s\$entry_order\s*=).*;#$1 $entry_order;#;
}

