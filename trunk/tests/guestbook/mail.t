#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  GB => {
          START => 'guestbook/guestbook.html',
          NAME  => 'guestbook.html',
        },
  GL => {
          START => 'guestbook/guestlog.html',
          NAME  => 'guestlog.html',
        },
);

use vars qw($mail $remote_mail $should_send_m $should_send_rm);

sub LocalChecks::check_mailok
{
   my ($self) = @_;

   my $mails = 0;
   $mails++ if exists $self->{PAGES}{MAIL1};
   $mails++ if exists $self->{PAGES}{MAIL2};
   $mails++ if exists $self->{PAGES}{MAIL3};

   my $wanted = 0;
   $wanted++ if $should_send_m and $mail;
   $wanted++ if $should_send_rm and $remote_mail;

   if ($mails != $wanted)
   {
      die "got $mails mails, expected $wanted\n";
   }
}

my $bad_realname = "wooooooooooooooooooooooo <<${\( join '', map {chr} (0..255) )}>> ooooooooooooooow";

my @tests = (
  # NAME               USERNAME        REALNAME        SEND_M     SEND_RM
  [ 'missing',         undef,          undef,          0,         0       ],
  [ 'normal',          'foo@foo.foo',  'eric',         1,         1       ],
  [ 'munge realname',  'foo@foo.foo',  $bad_realname,  1,         1       ],
  [ 'bad username',    'd(%f@foo.foo', 'fred',         1,         0       ],
);

foreach my $m (0,1)
{
   $mail = $m;
   
   foreach my $rm (0, 1)
   {
      $remote_mail = $rm;

      my $t = NMSTest::ScriptUnderTest->new(
        SCRIPT      => 'guestbook/guestbook.pl',
        REWRITERS   => [ \&rw_setup ],
        FILES       => \%files,
        CHECKER     => 'LocalChecks',
        CHECKS      => 'xhtml xhtml-GB xhtml-GL nodie mailok',
      );

      foreach my $test (@tests)
      {
         my ($testid, $username, $realname, $send_m, $send_rm) = @$test;
         $should_send_m = $send_m;
         $should_send_rm = $send_rm;

         my @args = ( 'comments=cool guestbook man' );
         push @args, "username=$username" if defined $username;
         push @args, "realname=$realname" if defined $realname;

         $t->run_test(
	   TEST_ID     => "mail $testid m=$m rm=$rm",
	   CGI_ARGS    => \@args,
	 );
      } 
   }
}

sub rw_setup
{
   s#(\s\$guestbookreal\s*=).*;#$1 '$files{GB}{PATH}';#;
   s#(\s\$guestlog\s*=).*;#$1 '$files{GL}{PATH}';#;
   s#(\s\$mail\s*=).*;#$1 $mail;#;
   s#(\s\$remote_mail\s*=).*;#$1 $remote_mail;#;
}

