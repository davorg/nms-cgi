#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG1  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain foo1\@test.domain
           foo2\@test.domain
email_input:     email
realname_input:  realname
recipient: foo3\@test.domain,foo4\@test.domain
END
             NAME => 'default.trc',
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


NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
   CHECKER     => 'LocalChecks',
   CHECKS      => 'xhtml nodie somemail allfoo',
   CGI_ARGS    => ['foo=foo'],
   TEST_ID     => "multiple recipients",
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


