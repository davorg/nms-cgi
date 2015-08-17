#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($secure $return_link_url $ok);

my @tests = (

  # NAME       RETURN_LINK_URL                          SECURE   OK
  [ 'goodurl', 'http://www.home.domain/foo/foo.htm',    0,       1  ],
  [ 'goodurl', 'http://www.home.domain/foo/foo.htm',    1,       1  ],
  [ 'badurl',  'javascript:alert(document.cookie)',     0,       1  ],
  [ 'badurl',  'javascript:alert(document.cookie)',     1,       0  ],

);

@LocalChecks::ISA = qw(NMSTest::OutputChecker);
sub LocalChecks::check_return_link
{
   my ($self) = @_;

   local $_ = $self->{PAGES}{OUT};

   if ($ok)
   {
      m#<a href="\Q$return_link_url\E">back to &lt;home&gt;</a>#
      or die "can't find expected return_link_url in output\n";
   }
   else
   {
      /back to/ and die "traces of return_link_url in output\n";
   }
} 

foreach $secure (1, 0)
{
   my $nmst = NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     HTTP_REFERER => 'http://foo.domain/',
     CHECKER      => 'LocalChecks',
     CHECKS       => 'xhtml nodie somemail return_link',
   );

   foreach my $t (grep {$_->[2] == $secure} @tests)
   {
      local $return_link_url = $t->[1];
      local $ok              = $t->[3];
      $nmst->run_test(
         TEST_ID      => "return_link_url secure=$secure $t->[0]",
         CGI_ARGS     => [
                          "return_link_url=$return_link_url",
                          "return_link_title=back to <home>",
                         ],
      );
   }
}

sub rw_setup
{
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\$secure\s*=.*?;| \$secure = $secure;| or die;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

