#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my %files =
(
  _CFG1  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain
email_input:     email
realname_input:  realname
END
             NAME => 'yes.trc',
            },
  _CFG2  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain
email_input:     email
realname_input:  realname
no_email: 1
END
             NAME => 'no.trc',
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
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
);

use vars qw($g $e $r);

foreach my $mail ('yes', 'no')
{
   my @args = ('x=y','realname=larry', 'email=larry@larry.larry');
   push @args, "_config=$mail";
   $t->run_test(
      CGI_ARGS => \@args,
      TEST_ID  => "no_email, mail $mail",
      CHECKS   => 'xhtml nodie '.($mail eq 'no' ? 'no' : 'some').'mail',
   );
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


