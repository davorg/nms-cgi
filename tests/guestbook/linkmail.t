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

use vars qw($linkmail);
foreach my $lm (0,1)
{
   $linkmail = $lm;
   
   my $t = NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'guestbook/guestbook.pl',
     REWRITERS    => [ \&rw_setup ],
     FILES        => \%files,
     CHECKS       => 'xhtml xhtml-GB xhtml-GL nodie nomail',
   );

   $t->run_test(
     TEST_ID      => "linkmail manyinputs lm=$lm",
     CGI_ARGS     => [ 'username=mr-big-shot.dude@big-shot.dudes.domain',
                       'realname=Biiiiiiiiiiiiiiiiig Shot!!!!',
		       'city=Bigville',
		       'state=Giant Province',
		       'country=Large Peoples Big Republic of Hugeland',
		       'url=http://www.big-shot.dudes.domain/~mrbig/',
                       'comments=I am a big shot',
                     ],
   );

   $t->run_test(
     TEST_ID      => "linkmail fewinputs lm=$lm",
     CGI_ARGS     => [ 'realname=Biiiiiiiiiiiiiiiiig Shot!!!!',
                       'comments=I am a big shot',
		       'username=foo@foo.foo',
                     ],
   );
}

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
   s#(\s\$linkmail\s*=).*;#$1 $linkmail;#;
}

