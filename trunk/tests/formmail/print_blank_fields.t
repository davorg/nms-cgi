#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($t);
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
);

my @tests = (

   # NAME       VALUE     PRINT BLANK   SHOULD APPEAR
   [ 'empty',   '',       0,            0             ],
   [ 'empty',   '',       1,            1             ],
   [ 'space',   ' ',      0,            0             ],
   [ 'space',   ' ',      1,            1             ],
   [ '0',       '0',      0,            1             ],
   [ '0',       '0',      1,            1             ],
   [ 'foo',     'foo',    0,            1             ],
   [ 'foo',     'foo',    1,            1             ],

);

foreach my $test (@tests)
{
   my ($name, $val, $print_blank, $should_show) = @$test;

   my @args = ('foo=foo', "moggie=$val" );
   if ( $print_blank )
   {
      push @args, 'print_blank_fields=1';
   }

   $t->run_test(
     TEST_ID     => "blank field $name pbf=$print_blank",
     CGI_ARGS    => \@args,
     CHECKS      => ($should_show ? 'yes_moggie' : 'no_moggie').' xhtml nodie',
   );
}

sub LocalChecks::check_no_moggie
{
   my ($self) = @_;

   if ( $self->{PAGES}{OUT} =~ /moggie/i )
   {
      die "'moggie' appeared in output, it shouldn't have.\n";
   }
   if ( $self->{PAGES}{MAIL1} =~ /moggie/i )
   {
      die "'moggie' appeared in email, it shouldn't have.\n";
   }
} 

sub LocalChecks::check_yes_moggie
{
   my ($self) = @_;

   if ( $self->{PAGES}{OUT} !~ /moggie/ )
   {
      die "'moggie' didn't appear in output, it should have.\n";
   }
   if ( $self->{PAGES}{MAIL1} !~ /moggie/ )
   {
      die "'moggie' didn't appear in email, it should have.\n";
   }
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


   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);|;
}

