#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG1  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain
email_input:     email
realname_input:  realname
END
             NAME => 'default.trc',
            },
  _CFG2  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain
email_input:     email
realname_input:  realname
by_submitter_by: gerk
END
             NAME => 'bygerk.trc',
            },
  _SPAGE => {
             START => 'tfmail/spage.trt',
	     NAME  => 'spage.trt',
            },
  _EMAIL => {
             START => 'tfmail/email.trt',
	     NAME  => 'email.trt',
            },
);


my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'tfmail/TFmail.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CHECKS      => 'xhtml nodie somemail',
);

use vars qw($g $e $r);

foreach my $bygerk (0, 1)
{
   $g = $bygerk;
   foreach my $email ('', 'x%y@z.zzzzzz', 'foo@foo.domain')
   {
      $e = $email;
      foreach my $realname ('', "\n\n", "Mr \377 dude")
      {
         $r = $realname;
         my @args = ('x=y',"realname=$realname", "email=$email");
         $bygerk and push @args, "_config=bygerk";
         $t->run_test(
           CGI_ARGS => \@args,
           TEST_ID  => "by_submitter gerk=$bygerk",
         );
      }
   }
}

sub LocalChecks::check_bysub
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /It was submitted\n(.*?)on/ 
      or die "can't find expected output in MAIL\n";
   my $bit = $1;

   if ($e =~ /foo/ and not length $bit)
   {
      die "empty by_submitter with good email address\n";
   }
   return unless length $bit;

   $bit =~ s#(by|gerk) ## or die
      "unexpected prefix\n";
   if ($g and $1 ne 'gerk' or !$g and $1 ne 'by')
   {
      die "gerk=$g but prefix was $1\n";
   }

   $bit =~ /\(\)/ and die "empty () in by_submitter directive\n";
}

sub rw_setup
{
   #
   # The very old CGI.pm that comes with Perl 5.00404 generates
   # a warning on empty parameter values.  There's nothing we
   # can reasonably do about that, so we discard those warnings
   # to avoid failing the test.
   #
   my $no_cgi_warn = <<'END';

$SIG{__WARN__} = sub {
   my $warn = shift;
   warn $warn unless $warn =~ /CGI\.pm line /;
};

END
   s|^(.*?\n)|$1$no_cgi_warn|;

   my $cfg_root = $files{_CFG1}{PATH};
   $cfg_root =~ s#/[^/]+$##;

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$cfg_root';};
}


