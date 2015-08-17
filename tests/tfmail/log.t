#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

my $cfg;

my %files =
(
  LOG    => {
              START => \"This is a log file\n",
              NAME  => 'tfmail.log',
            },
  _CFG   => {
             START => \&cfg,
             NAME  => 'default.trc',
            },
  _SPAGE => {
             START => 'tfmail/spage.trt',
	     NAME  => 'spage.trt',
            },
  _EMAIL => {
             START => 'tfmail/email.trt',
	     NAME  => 'email.trt',
            },
  _LTMP  => {
             START => \<<END,
%% NMS email template file %%
{= date =}|{= env.REMOTE_ADDR =}|{= config.recipient =}
END
	     NAME  => 'log.trt',
            },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'tfmail/TFmail.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CGI_ARGS     => ['foo=foo', 'bar=bar'],
   CHECKS      => 'xhtml nodie somemail',
   TEST_ID     => "log",
)->run_test;


sub cfg
{
   return <<END;
%% NMS configuration file %%
recipient: foo\@test.domain
logfile: tfmail
END
}

sub rw_setup
{
   my $cfg_root = $files{_CFG}{PATH};
   $cfg_root =~ s#/[^/]+$##;

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$cfg_root';};
   s{(LOGFILE_ROOT\s*=>).*} {$1 '$cfg_root';};
}


