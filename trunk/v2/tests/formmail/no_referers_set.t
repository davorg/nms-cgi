#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;


use vars qw($secure $allow_empty_ref);

foreach $secure (0, 1)
{
   foreach $allow_empty_ref (0, 1)
   {
      my $t = NMSTest::ScriptUnderTest->new(
         SCRIPT    => 'formmail/FormMail.pl',
         REWRITERS => [ \&rw_setup ],
         CGI_ARGS  => [qw(foo=foo)],
         CHECKS    => 'xhtml nodie somemail',
      );

      $t->run_test(
         HTTP_REFERER => 'http://www.foo.foo/foo.html',
         TEST_ID      => "any ref s=$secure e=$allow_empty_ref normal",
      );

      $t->run_test(
         TEST_ID      => "any ref s=$secure e=$allow_empty_ref empty",
      );
   }
}

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = ()|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(test\@test.domain);|;
   s|\s+\$secure\s*=.*?;| \$secure = $secure;|;
   s|\s+\$allow_empty_ref\s*=.*?;| \$allow_empty_ref = $allow_empty_ref;|;
}

