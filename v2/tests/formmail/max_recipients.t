#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($max_recipients);


my @tests = 
(
  # ID           MAX_RECIP  RECIPIENT                        OK
  [ '1 direct',  '1',       'foo@foo.domain',                1  ],
  [ '1 alias',   '1',       '0',                             1  ],
  [ '1+ direct', '1',       'foo@foo.domain,bar@foo.domain', 0  ],
  [ '1+ alias',  '1',       '1',                             0  ],
  [ '0 direct',  '0',       'foo@foo.domain,bar@foo.domain', 1  ],
  [ '0 alias',   '0',       '1',                             1  ],
  [ '5 direct',  '5',       'foo@foo.domain,bar@foo.domain', 1  ],
  [ '5 alias',   '5',       '1',                             1  ],
);

foreach my $test (@tests)
{
   $max_recipients = $test->[1];

   NMSTest::ScriptUnderTest->new(
     TEST_ID      => "max_recipients $test->[0]",
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     CGI_ARGS     => ['foo=foo', "recipient=$test->[2]"],
     HTTP_REFERER => 'http://foo.domain/',
     CHECKS       => 'xhtml nodie ' . ($test->[3] ? 'somemail' : 'nomail'),
   )->run_test;
}

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo.domain);|;
   s|\s+\$max_recipients\s*=.*?;| \$max_recipients = $max_recipients;|;
   s{\s+\%recipient_alias\s*=.*?;}
    {
      \%recipient_alias = (
         '0'=>'zero\@foo.domain',
         '1'=>'one-a\@foo.domain,one-b\@foo.domain',
         '2'=>'two\@foo.domain'
      );
    }x;
}

