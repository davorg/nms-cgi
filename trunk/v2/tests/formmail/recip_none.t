#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($tests);
{
   local $/;
   $tests = <DATA>;
}

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup, \&install_tests ],
  TEST_ID      => "check_recipient, none configured",
  CHECKS       => 'nodie subtests',

)->run_test;

sub install_tests
{
   s#^check_url\(\);#unitTest\(\);#m;
   s#(__END__|\z)#$tests$1#;
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = ();|;
   s|\s+\@referers\s*=.*?;| \@referers = qw(foo.domain bar\@foo.domain);|;
   s|\s+\@recipients\s*=.*?;| \@recipients = ();|;
}

__END__

sub handle_request
{
    my ($self) = @_;

    my @recipients = (
       '',
       ' ',
       '0',
       '0@0',
       'foo@foo.domain',
       'bar@foo.domain',
       'postmaster',
       'you@your.domain',
    );

    foreach my $r (@recipients)
    {
        $self->unitTestTryall($r);
    }

    print "All subtests ran\n";
    exit 0;
}

sub unitTestTryall
{
  my ($self, $r) = @_;

  foreach my $s (0,1)
  {
    $self->{CFG}{secure} = $s;
    foreach my $d (0,1)
    {
      $self->{CFG}{DEBUGGING} = $d;
      foreach my $e (0,1)
      {
        $self->{CFG}{emulate_matts_code} = $e;
        if ( $self->recipient_is_ok($r) )
	{
	  warn "Recipient <$r> accepted in error (s=$s, D=$d, e=$e)\n";
        }
      }
    }
  }
}

