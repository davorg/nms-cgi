#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my @a = qw(subject=hic foo=hic recipient=foo@foo.domain);

use vars qw($emulate @expect);
foreach $emulate (0, 1)
{
   my $t = NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     HTTP_REFERER => 'http://foo.domain/',
     CHECKER      => 'LocalChecks',
     CHECKS       => 'xhtml nodie config_include',
   );

   @expect = qw(foo);
   $t->run_test(
     TEST_ID      => "config_include e=$emulate none",
     CGI_ARGS     => \@a,
   );

   @expect = qw(foo);
   $t->run_test(
     TEST_ID      => "config_include e=$emulate foo",
     CGI_ARGS     => [@a, 'sort=order:foo'],
   );

   @expect = ($emulate ? () : qw(subject));
   $t->run_test(
     TEST_ID      => "config_include e=$emulate subject",
     CGI_ARGS     => [@a, 'sort=order:subject'],
   );

   @expect = ($emulate ? qw(foo) : qw(subject foo));
   $t->run_test(
     TEST_ID      => "config_include e=$emulate both",
     CGI_ARGS     => [@a, 'sort=order:subject,foo'],
   );
}
   
sub LocalChecks::check_config_include
{
   my ($self) = @_;

   $self->{PAGES}{OUT}   =~ m#sort:.*order# and die "sort value shown\n";
   $self->{PAGES}{MAIL1} =~ m#sort:.*order# and die "sort value mailed\n";
   $self->{PAGES}{OUT}   =~ m#recipient#    and die "rcpt value shown\n";
   $self->{PAGES}{MAIL1} =~ m#recipient#    and die "rcpt value mailed\n";
  
   my @out = $self->{PAGES}{OUT} =~ m#<p><b>([^<]+):</b>\s*(?:hic)?</p>#g;
   foreach (@out) { s/&#39;/'/g }
   array_comp("wrong fields on output HTML page", \@out, \@expect);

   my @mail = $self->{PAGES}{MAIL1} =~ /^\s+([^:,]+)\s*: (?:hic)?\n/mg;
   array_comp("wrong fields in email body", \@mail, \@expect);
}

sub array_comp
{
   my ($msg, $got, $want) = @_;

   if (scalar @$got == scalar @$want)
   {
      my $bad = 0;
      for my $i (0..$#$got)
      {
         $bad = 1 unless $got->[$i] eq $want->[$i];
      }
      return unless $bad;
   }

   die "$msg: got <" . join(':',@$got) . ">, wanted <" . join(':',@$want) . ">\n";
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s| +\$emulate_matts_code\s*=.*?;| \$emulate_matts_code = $emulate;| or die;
}

