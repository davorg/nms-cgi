package NMSTest::TestRun;
use strict;

use Fcntl ':flock';
use NMSTest::OptionParser;
use NMSTest::OutputChecker;

use vars qw(@ISA);
@ISA = qw(NMSTest::OptionParser);

=head1 NAME

NMSTest::TestRun - a single run of a script under test

=head1 DESCRIPTION

This class represents a single test run of a CGI script
under test, see L<NMSTest::ScriptUnderTest>.

=head1 CONSTRUCTOR

new ( OPTIONS )

Sets up an object ready to perform a test.

OPTIONS is a set of key/value pairs.  See
L<NMSTest::OptionParser> for option parsing semantics.

The following options are recognised:

=over 4

=item TEST_ID

A string uniquely identifying the test.

=item SCRIPT_FILENAME

The full path to the re-written script.

=item OUTDIR

The directory in which files representing the output of the
script should be placed.

=item LOGFILE

The path to a log file for the test run.  The results
printed to STDOUT will also be appended to the log file.

=item CGI_ARGS

An array ref, specifying the CGI arguments for the request.
Each element of the array should be a string in name=value
format.

=item HTTP_REFERER

The value to be set for the HTTP_REFERER environment
variable seen by the script under test.

=item HTTP_USER_AGENT

The value to be set for the HTTP_USER_AGENT environment
variable seen by the script under test.

=item REQUEST_METHOD

The request method for the simulated request, "GET" or
"POST".

=item REMOTE_ADDR

The value to be set for the REMOTE_ADDR environment
variable seen by the script under test.

=item DOCUMENT_URI

The value to be set for the DOCUMENT_URI environment 
variable for the tested script - this is useful for the
SSI programs.

=item PERL

The path to the Perl interpreter to be used to run the
script under test.

=item CHECKS

A space separated list of the names of zero or more
correctness checks to be applied to the results of
the test run.  See L<NMSTest::OutputChecker> for
details of what can be set here.

=item CHECKER

The package name of the output ckecker class to be used
to apply the checks listed in CHECKS to the script
output.  Defaults to C<NMSTest::OutputChecker>, and should
only be changed to the name of a class that inherits
from C<NMSTest::OutputChecker>.

=item RESULTS_DIR

The directory into which a file describing the behavior
of the script under test should be placed.

=back

=cut

sub new
{
   my ($pkg, %opts) = @_;

   my $self = bless { Opts => \%opts }, $pkg;
   $self->parse_options({
     TEST_ID         => undef,
     SCRIPT_FILENAME => undef,
     OUTDIR          => '[[DIR]]/out',
     LOGFILE         => '',
     CGI_ARGS        => [],
     HTTP_REFERER    => 'http://localhost/foo.html',
     HTTP_USER_AGENT => 'Foo 0.001',
     REQUEST_METHOD  => 'POST',
     REMOTE_ADDR     => '3.254.17.8',
     PERL            => '[[BINDIR]]/perl',
     CHECKS          => '',
     CHECKER         => 'NMSTest::OutputChecker',
     RESULTS_DIR     => '[[DIR]]/results',
     DOCUMENT_URI    => '/zub.shtml',
   });

   return $self;
}

=head1 METHODS

=over 4

=item run ()

Runs the test, applying all defined correctness checks to the
results and recording the results in the appropriate places.

=cut

sub run
{
   my ($self) = @_;

   # delete any old output
   $self->_grab_and_delete_output;

   local %ENV = (
       PATH                 => '/bin:/usr/bin:/usr/local/bin',
       GATEWAY_INTERFACE    => 'CGI/1.1',
       SERVER_PROTOCOL      => 'HTTP/1.0',
       SERVER_SOFTWARE      => 'Apache/1.3.14 (Unix)',
       SERVER_NAME          => 'www.foo.domain',
       DOCUMENT_ROOT        => '/usr/local/apache/htdocs',
       HTTP_REFERER         => $self->{HTTP_REFERER},
       HTTP_USER_AGENT      => $self->{HTTP_USER_AGENT},
       FAKE_SENDMAIL_OUTPUT => $self->{OUTDIR},
       REMOTE_ADDR          => $self->{REMOTE_ADDR},
       DOCUMENT_URI         => $self->{DOCUMENT_URI},
   );

   my $q = $self->_build_query;
   $ENV{REQUEST_METHOD} = $self->{REQUEST_METHOD};
   if ($self->{REQUEST_METHOD} eq 'POST')
   {
      $ENV{CONTENT_LENGTH} = length($q);
   }
   else
   {
      $ENV{QUERY_STRING} = $q;
   }


   if ($self->{SCRIPT_FILENAME} =~ m#/(cgi\-bin/.*)$#)
   {
      $ENV{SCRIPT_NAME} = "/$1";
      $ENV{SCRIPT_FILENAME} = $self->{SCRIPT_FILENAME};
      $ENV{REQUEST_URI} = $ENV{SCRIPT_NAME};
      $ENV{QUERY_STRING} and $ENV{REQUEST_URI} .= "?$ENV{QUERY_STRING}";
   }

   open CGI, "| $self->{PERL} -wT $self->{SCRIPT_FILENAME} >$self->{OUTDIR}/OUT.out 2>$self->{OUTDIR}/ERR.out";
   if ($self->{REQUEST_METHOD} eq 'POST')
   {
      print CGI "$q\n";
   }
   close CGI;
   my $exit = $?;

   if ($exit)
   {
      die "script terminated with non-zero status, test set aborted\n";
   }

   my @results = ( "Test ID: $self->{TEST_ID}\n",
                   "Script exit status: $exit\n",
                    $self->_grab_and_delete_output
                 );

   if ( length $self->{RESULTS_DIR} )
   {
      $self->_substitute_dates(\@results);
      $self->_substitute_generated_header(\@results);

      my $id = $self->{TEST_ID};
      $id =~ tr/ =/_-/;
      $id =~ s#([^\w\-\.\,=])# sprintf '0x%.2X', unpack 'C', $1 #ge;
      my $file = "$self->{RESULTS_DIR}/$id";
      $file .= '_' while -r $file;
      open OUT, ">$file" or die "open >$file: $!";
      print OUT @results;
      close OUT;
   }

   {
      local $SIG{__DIE__};
      eval { $self->{CHECKER}->new(\@results)->checks($self->{CHECKS}) };
   }
   my $results = $self->{TEST_ID} .
                 ('.' x (40 - length $self->{TEST_ID})) . 
		 ".. ";
   if ($@)
   {
      $results .= qq(failed\n   $@\n);
   }
   else
   {
      $results .= "ok\n";
   }

   print $results;
   $self->_log($results);
}

=back

=head1 PRIVATE METHODS

=over 4

=item _log ( MESSAGE )

Writes a message to the log file set for this test, if any.

=cut

sub _log
{
   my ($self, $msg) = @_;

   if ( length $self->{LOGFILE} )
   {
      open LOG, ">>$self->{LOGFILE}" or die "open >>$self->{LOGFILE}: $!";
      flock LOG, LOCK_EX or die "flock $self->{LOGFILE}: $!";
      seek LOG, 0, 2 or die "seek to end $self->{LOGFILE}: $!";
      print LOG $msg;
      close LOG;
   }
}

=item _grab_and_delete_output ()

Reads and deletes the output files in the test's C<OUTDIR>, and
converts them to a single array of lines.

=cut

sub _grab_and_delete_output
{
   my ($self) = @_;

   opendir D, $self->{OUTDIR} or die "opendir $self->{OUTDIR}: $!";
   my @outputs = map { /^(\w+)\.out$/ ? ($1) : () } readdir D;
   closedir D;

   my @alloutput = ();
   foreach my $out (sort @outputs)
   {
      my $prefix = pack 'A6', $out;
      open IN, "<$self->{OUTDIR}/$out.out" or die "open $out.out: $!";
      push @alloutput, map {$prefix . $_} <IN>;
      push @alloutput, "\n";

      # leave symlinks in place, see _setup_data_files in NMSTest::ScriptUnderTest.
      next if -l "$self->{OUTDIR}/$out.out";
      unlink "$self->{OUTDIR}/$out.out" or die "unlink $self->{OUTDIR}/$out.out: $!";
   }

   return @alloutput;
}

=item _build_query ()

Builds an encoded query string from the C<CGI_ARGS> set for
the test.

=cut

sub _build_query
{
   my ($self) = @_;

   my $q = '';
   my @list = @{ $self->{CGI_ARGS} };
   while (scalar @list)
   {
      $q .= '&' if length $q;
      my $arg = shift @list;
      if ($arg =~ /^([^=]+)=(.+)/s)
      {
         my ($name, $val) = ($1, $2);
         $q .= $self->_query_encode($name) . '=' . $self->_query_encode($val);
      }
      else
      {
         $q .= $self->_query_encode($arg);
      }
   }

   return $q;
}

=item _query_encode ( TEXT )

Returns a URL encoded version of TEXT.

=cut

sub _query_encode
{
   my ($self, $txt) = @_;

   $txt =~ s/([^\w\-\. ])/ sprintf '%%%.2X', unpack 'C', $1 /ge;
   $txt =~ tr/ /+/;

   return $txt;
}

=item _substitute_dates

Replaces all date strings in the test output with date strings
in the same format, but changes the date to a fixed one.  This
prevents false differences appearing when attempting to perform
regression tests of scripts that include the current date in
their output.

=cut

sub _substitute_dates
{
   my ($self, $results) = @_;

   my @days = qw(Monday Tuesday Wednesday Thursday Friday Saturday Sunday);
   my @months = qw(January February March April May June July August
                   September October November December);

   my $daypat = join '|', @days;
   my $monpat = join '|', @months;

   foreach my $r (@$results)
   {
      $r =~ s[($daypat), ($monpat) \d\d?, \d{4} at \d\d:\d\d:\d\d]
             [Sunday, December 31, 2002 at 23:58:00]og;
      $r =~ s{\[\d\d/\d\d/\d\d \d\d:\d\d:\d\d [A-Z]{3}\]}
             {[31/12/02 23:58:00]}og;
   }
}

=item _substitute_generated_header

Replaces any script version numbers in X-Generated-By headers
in emails with a fixed version number.  This prevents false
differences appearing when attempting to perform regression
tests of scripts that send email with this header.

=cut

sub _substitute_generated_header
{
   my ($self, $results) = @_;

   foreach my $r (@$results)
   {
      $r =~ s[^(MAIL\d *X-Generated-By: NMS \w+\.pl) v\d+\.\d+]
             [$1 v1.01]g;
   }
}

=back

=head1 SEE ALSO

L<NMSTest::ScriptUnderTest>, L<NMSTest::OutputChecker>

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

