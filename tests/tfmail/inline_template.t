#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG1  => {
             START => \<<END_CFG1,
%% NMS configuration file %%
recipient: foo\@test.domain foo1\@test.domain
           foo2\@test.domain
email_input:     email
realname_input:  realname

email_template:
%Here are the results, via an inline template. It was submitted
%{= by_submitter =}on {= date =}.
%----------------------------------------------------------------------
%
%{= FOREACH input_field =}
%{= name =}: {= value =}
%
%{= END =}
%----------------------------------------------------------------------
%
% address: {= env.REMOTE_ADDR =}
%

recipient: foo3\@test.domain,foo4\@test.domain

success_page_template:
%<?xml version="1.0" encoding="iso-8859-1"?>
%<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
%    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
%<html xmlns="http://www.w3.org/1999/xhtml">
%  <head>
%    <title>Thank You</title>
%    <link rel="stylesheet" type="text/css" href="/css/nms.css" />
%    <style>
%       h1.title {
%                   text-align : center;
%                }
%    </style>
%  </head>
%  <body>
%    <h1 class="title">Thank You</h1>
%    <p>Below is what you submitted on {= date =}</p>
%    <hr size="1" width="75%" />
%{= FOREACH input_field =}
%    <p><b>{= name =}:</b> {= value =}</p>
%{= END =}
%    <hr size="1" width="75%" />
%    <p>That was an inline template by the way</p>
%    <p align="center">
%      <font size="-1">
%        <a href="http://nms-cgi.sourceforge.net/">TFmail</a>
%        &copy; 2001  London Perl Mongers
%      </font>
%    </p>
%  </body>
%</html>

END_CFG1
             NAME => 'default.trc',
            },
);


NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
   CHECKER     => 'LocalChecks',
   CHECKS      => 'xhtml nodie somemail allfoo',
   CGI_ARGS    => ['foo=foo'],
   TEST_ID     => "all templates inline",
)->run_test;

sub LocalChecks::check_allfoo
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /^To: (.+)/m
      or die "can't find To in EMAIL [$self->{PAGES}{MAIL1}]\n";
   my $to = $1;

   my $goodto = join ', ', map "$_\@test.domain", qw(foo foo1 foo2 foo3 foo4);
   $to eq $goodto or die "Got to [$to], wanted to [$goodto]";
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


