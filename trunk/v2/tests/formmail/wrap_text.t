#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %values = (
   one => 'x'x300,
   two => 'foo ' x 25,
);

my %wrapped = (
  1 => {
    one => <<END,
one: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
     xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
END
    two => <<END,
two: foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo
     foo foo foo foo foo foo foo foo foo 
END
  },

  2 => {
    one => <<END,   
one: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxx
END
    two => <<END,
two: foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo foo
foo foo foo foo foo foo foo foo foo 
END
  },
); 
   
use vars qw($wrap_text $wrap_style);
my $test_perl = $ENV{NMSTEST_PERL};

foreach $wrap_style (1, 2)
{
   foreach $wrap_text (0, 1)
   {
      NMSTest::ScriptUnderTest->new(
         SCRIPT       => 'formmail/FormMail.pl',
         REWRITERS    => [ \&rw_setup ],
         TEST_ID      => "wrap_text wrap=$wrap_text style=$wrap_style",
         CGI_ARGS      => ["one=$values{one}", "two=$values{two}"],
         HTTP_REFERER => 'http://foo.domain/',
         CHECKER      => 'LocalChecks',
         CHECKS       => 'xhtml nodie somemail wrap',
      )->run_test;
   }
}

sub LocalChecks::check_wrap
{
   my ($self) = @_;

   my $should_wrap_one = $wrap_text;
   if ($test_perl =~ /5\.00404/)
   {
      # Text::Wrap this old can't deal with a word longer than the
      # line length, so we fall back to not wrapping if that happens.
      $should_wrap_one = 0;
   }

   my $should_wrap_two = $wrap_text;

   if ($should_wrap_one and $should_wrap_two)
   {
      my $body = $self->{PAGES}{MAIL1};
      $body =~ s#^.*?\n\n##s or die "no header";
      $body =~ s#^\-{70,80}\n##mg;
      if ($body =~ /([^\n]{73,})/)
      {
         die "long line [$1] should have been wrapped";
      }
   }

   if ($should_wrap_one)
   {
      $self->{PAGES}{MAIL1} =~ /\n\n\Q$wrapped{$wrap_style}{one}\E\n/ or die "miswrap one";
   }
   else
   {
      $self->{PAGES}{MAIL1} =~ /\n\none: \Q$values{one}\E\n\n/ or die "one wrapped";
   }

   if ($should_wrap_two)
   {
      $self->{PAGES}{MAIL1} =~ /\n\n\Q$wrapped{$wrap_style}{two}\E\n/ or die "miswrap two";
   }
   else
   {
      $self->{PAGES}{MAIL1} =~ /\n\ntwo: \Q$values{two}\E\n\n/ or die "two wraped";
   }
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
   s|\s+\$wrap_text\s*=.*?;| \$wrap_text = $wrap_text;|;
   s|\s+\$wrap_style\s*=.*?;| \$wrap_style = $wrap_style;|;
}

