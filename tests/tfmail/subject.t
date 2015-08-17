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

use vars qw($subject_setting $expected_subject);

my @tests = (

  [ 'static',  'this is the subject',        ['foo=foo'],              'this is the subject' ],
  [ 'param',   'mail about {= param.foo =}', ['foo=bar'],              'mail about bar'      ],
  [ 'newline', 'foo {= param.foo =}',        ["foo=foo\nbcc: x\@x.x"], 'foo foo bcc: x@x\.x' ],
  [ 'maxlen',  'foo {= param.foo =}',        ["foo=" . ('A'x2000)],    'foo A{40,200}'       ],

);

foreach my $test (@tests)
{
   my ($name, $setting, $params, $expect) = @$test;
   $subject_setting = $setting;
   $expected_subject = $expect;

   NMSTest::ScriptUnderTest->new(
     SCRIPT      => 'tfmail/TFmail.pl',
     REWRITERS   => [ \&rw_setup ],
     FILES       => \%files,
     CHECKER     => 'LocalChecks',
     CHECKS      => 'nodie somemail subject',
     TEST_ID     => "subject $name",
     CGI_ARGS    => $params,
   )->run_test;
}

sub cfg
{
   return <<END;
%% NMS configuration file %%
recipient: xxx\@xxx.xxx
subject: $subject_setting

email_template:
% hello

END
}

sub LocalChecks::check_subject
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /^Subject: (.+)$/m or die
      "can't find subject header in email\n";
   my $subject = $1;

   if ($subject !~ /^$expected_subject$/)
   {
      die "got subject [$subject], wanted [$expected_subject]\n";
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


