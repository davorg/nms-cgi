#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG   => {
             START => \&cfg,
             NAME  => 'default.trc',
            },
  _SPAGE => {
             START => 'tfmail/spage.trt',
             NAME  => 'spage.trt',
            },
);

NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
   CHECKER     => 'LocalChecks',
   CHECKS      => 'nodie somemail realname',
   TEST_ID     => "multiple realname inputs",
   CGI_ARGS    => ['email=x@x.x', 'foo=Fred', 'bar=HumpHump'],
)->run_test;

sub cfg
{
   return <<END;
%% NMS configuration file %%
recipient: xxx\@xxx.xxx
email_input: email
realname_input: foo bar

email_template:
% hello

END
}

sub LocalChecks::check_realname
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /^From: (.+)$/m or die
      "can't find from header in email\n";
   my $from = $1;

   if ($from ne 'x@x.x (Fred HumpHump)')
   {
      die "from value [$from] unexpected\n";
   }
}

sub rw_setup
{
   my $cfg_root = $files{_CFG}{PATH};
   $cfg_root =~ s#/[^/]+$##;

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$cfg_root';};
}


