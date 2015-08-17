#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my @tests = (
  # TEST NAME               REQUIRED              ARGS                                OK
  [ 'foo missing',         'foo',                 'bar=foo',                          0  ],
  [ 'foo OK',              'foo',                 'foo=bar',                          1  ],
  [ 'foo zero',            'foo',                 'foo=0',                            1  ],

  [ 'R missing',           'realname',            'bar=foo',                          0  ],
  [ 'R OK',                'realname',            'realname=bar',                     1  ],
  [ 'R zero',              'realname',            'realname=0',                       1  ],

  [ 'E missing',           'email',               'bar=foo',                          0  ],
  [ 'E OK',                'email',               'email=bar@foo.com',                1  ],
  [ 'E bad',               'email',               'email=foo',                        0  ],

  [ 'ER both missing',     'email,realname',      'foo=bar',                          0  ],
  [ 'ER R missing',        'email,realname',      'email=b@b.com',                    0  ],
  [ 'ER E missing',        'email,realname',      'realname=bar',                     0  ],
  [ 'ER E bad',            'email,realname',      'realname=bar,email=foo',           0  ],
  [ 'ER both OK',          'email,realname',      'realname=bar,email=f@f.c',         1  ],
);

use vars qw($emulate);
foreach $emulate (0, 1)
{
   my $t = NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     HTTP_REFERER => 'http://foo.domain/',
   );

   foreach my $test (@tests)
   {
      my ($name, $req, $args, $ok) = @$test;
      my @args = split /,/, $args;
   
      $t->run_test(
        TEST_ID     => "required e=$emulate $name",
        CGI_ARGS    => [@args, "required=$req", 'recipient=foo@foo.domain'],
        CHECKS      => 'xhtml nodie ' . ($ok ? 'somemail' : 'nomail'),
      );
   }

}

sub rw_setup
{
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s| +\$emulate_matts_code\s*=.*?;| \$emulate_matts_code = $emulate;| or die;
}

