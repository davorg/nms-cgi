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

=item FILES

A hash by output page name of information about the files
that the script modifies.  If the output page name starts
with a "_" character then the file will be assumed to be
read only and its final state will be omitted from the
output.  The values of the hash are hashrefs, with the
following keys set:

=over 4

=item NAME

The basename of the file, e.g. F<guestbook.html>.

=item START

The starting contents of the file, set up when the script
is rewritten and installed.  Can be a scalar, in which
case it gets interpreted as the path relative to the
root of the CVS working directory of a file who's contents
should be copied into the file.  Can be a scalar ref, in
which case the referenced string is used as the starting
contents of the file.  Can be a coderef, which will be
invoked without arguments to generate the file contents.

=back

This code adds a C<PATH> key to hash, recording the full
path of the copy of the file on which the script is to
operate.  This is done before the coderefs in the 
C<REWRITERS> array (above) are run, to allow the re-writer
functions to configure the locations of the files into
the script under test.

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
      DATDIR    => '[[DIR]]/data',
      OUTDIR    => '[[DIR]]/out',
      SENDMAIL  => '[[BINDIR]]/fake_sendmail',
      REWRITERS => [],
      FILES     => {},
      SCRIPT    => undef,
   });

   $self->_setup_data_files;

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

=item _setup_data_files ()

Copies initial versions of any data files defined in the C<FILES>
option into the data files directory, and adds symlinks in the
output directory so that the file contents after the script run
become part of the recorded output.

=cut

sub _setup_data_files
{
   my ($self) = @_;

   # ditch any old data and output files left over from the previous test
   system('rm','-r','--',$self->{DATDIR},$self->{OUTDIR}) and die "rm failed";
   mkdir $self->{DATDIR}, 0755 or die "mkdir: $!";
   mkdir $self->{OUTDIR}, 0755 or die "mkdir: $!";

   foreach my $page (keys %{$self->{FILES}})
   {
      my $pdat = $self->{FILES}{$page};
      my $fname = "$self->{DATDIR}/$pdat->{NAME}"; 
      $pdat->{PATH} = $fname;
   }

   foreach my $page (keys %{$self->{FILES}})
   {
      my $pdat = $self->{FILES}{$page};
      my $fname = "$self->{DATDIR}/$pdat->{NAME}"; 

      my $file_contents;
      if (not defined $pdat->{START})
      {
         undef $file_contents;
      }
      elsif (ref $pdat->{START} eq 'CODE')
      {
         $file_contents = &{ $pdat->{START} };
      }
      elsif (ref $pdat->{START} eq 'SCALAR')
      {
         $file_contents = ${ $pdat->{START} };
      }
      else
      {
         open IN, "<$self->{SRCDIR}/$pdat->{START}" or die "open <$pdat->{START}: $!";
         local $/;
         $file_contents = <IN>;
         close IN;
      }

      my @dirs = (split /\//, $fname);
      pop @dirs; # get rid of file basename
      my $path = '';
      foreach my $d (@dirs)
      {
         $path .= "/$d";
	 -d $path or mkdir $path, 0755 or die "mkdir $path: $!";
      }

      if (defined $file_contents)
      {
         open OUT, ">$fname" or die "open >$fname: $!";
         print OUT $file_contents;
         close OUT;
      }

      next if $page =~ /^_/;

      symlink $fname, "$self->{OUTDIR}/$page.out" or die 
         "symlink $fname -> $self->{OUTDIR}/$page.out: $!";
   }
}

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

