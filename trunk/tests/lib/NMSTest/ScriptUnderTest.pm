package NMSTest::ScriptUnderTest;
use strict;

=head1 NAME

NMSTest::ScriptUnderTest - A test harness for a single script

=head1 DESCRIPTION

An C<NMSTest::ScriptUnderTest> object represents a copy of a
single NMS script, re-written in a particular way and
undergoing some set of tests.

=cut

use Carp;
use NMSTest::TestRun;
use NMSTest::OptionParser;

use vars qw(@ISA);
@ISA = qw(NMSTest::OptionParser);

=head1 CONSTRUCTOR

new ( OPTIONS )

Copies a particular NMS script into a test directory,
re-rewriting it to facilitate a particular set of tests.
OPTIONS is a set of key/value pairs.  See
L<NMSTest::OptionParser> for option parsing semantics.

The following options are recognised:

=over 4

=item DIR

The name of the base directory for the test set.

=item SRCDIR

The path to a copy of the NMS source tree.

=item BINDIR

The path to the directory that holds binaries related to the
NMS test set.

=item CGIBIN

The path to the directory in which the re-written CGI script
will be placed.

=item SENDMAIL

The path to a fake sendmail binary.  The script will be
re-written to use this rather than F</usr/sbin/sendmail>.
See F<tests/bin/fake_sendmail> in the nms-cgi source tree.

=item REWRITERS

A reference to an array of coderefs.  Each will be called in
turn with the script in C<$_> before it's written to its
temporary location.  These re-writers allow test code to
try different values of configuration variables in the script.

=item SCRIPT

The relative path to the script from the C<SRCDIR>.

=back

=cut

sub new
{
   my ($pkg, %opts) = @_;

   my $self = bless { Opts => \%opts }, $pkg;
   $self->parse_options({
      DIR       => '/var/nmstest',
      SRCDIR    => '[[DIR]]/src',
      BINDIR    => '[[DIR]]/bin',
      CGIBIN    => '[[DIR]]/cgi-bin',
      SENDMAIL  => '[[BINDIR]]/fake_sendmail',
      REWRITERS => [],
      SCRIPT    => undef,
   });

   $self->_rewrite_script;

   return $self;
}

=head1 METHODS

=over 4

=item run_test ( OPTIONS )

Run a single test on the script.  OPTIONS is a set of key/value
pairs.  See L<NMSTest::TestRun> for details.

=cut

sub run_test
{
   my ($self, %opts) = @_;

   NMSTest::TestRun->new( %{ $self->{Opts} }, %opts )->run;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _rewrite_script ()

Performs the rewrite, plumbing in the fake sendmail and invoking
all the user defined re-writer functions.

=cut

sub _rewrite_script
{
   my ($self) = @_;

   open IN, "<$self->{SRCDIR}/$self->{SCRIPT}" or die
                 "open $self->{SRCDIR}/$self->{SCRIPT}: $!";
   local $/;
   local $_ = <IN>;

   s#/usr/lib/sendmail\b#$self->{SENDMAIL}#e;

   my $stop_at_int = '$SIG{INT} = sub {local $SIG{__DIE__} ; die "***STOP***\\n" };';
   s|^(#!.*\n)|$1 BEGIN {$stop_at_int} \n|;

   foreach my $rewriter (@{ $self->{REWRITERS} })
   {
      &{ $rewriter }();
   }

   $self->{SCRIPT} =~ m|([^/]+)$| or croak "bad: <$self->{SCRIPT}>";
   my $file = "$self->{CGIBIN}/$1";
   $self->{Opts}{SCRIPT_FILENAME} = $file;

   open OUT, ">$file" or die "open >$file: $!";
   print OUT $_;
   close OUT;

   chmod 0755, $file or die "chmod $file: $!";
}

=back

=head1 SEE ALSO

L<NMSTest::TestRun>, L<NMSTest::OptionParser>

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

