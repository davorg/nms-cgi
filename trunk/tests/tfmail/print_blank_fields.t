#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($t);
$t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'tfmail/TFmail.pl',
  REWRITERS    => [ \&rw_setup ],
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

   my $moggie = (length $val ? "moggie=$val" : "moggie");
   my @args = ('foo=foo', $moggie );
   if ( $print_blank )
   {
      push @args, '_config=pbf';
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

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$ENV{NMS_WORKING_COPY}/tests/tfmail';};

}

