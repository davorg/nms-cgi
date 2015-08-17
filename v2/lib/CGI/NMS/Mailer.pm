package CGI::NMS::Mailer;
use strict;

use POSIX qw(strftime);

=head1 NAME

CGI::NMS::Mailer - email sender base class

=head1 SYNOPSYS

  use base qw(CGI::NMS::Mailer);

  ...

=head1 DESCRIPTION

This is a base class for classes implementing low-level email
sending objects for use within CGI scripts.

=head1 METHODS

=over

=item output_trace_headers ( TRACEINFO )

Uses the print() virtual method to output email abuse tracing headers
including whatever useful information can be gleaned from the CGI
environment variables.

The TRACEINFO parameter should be a short string giving the name and
version of the CGI script.

=cut

sub output_trace_headers {
  my ($self, $traceinfo) = @_;

  $ENV{REMOTE_ADDR} =~ /^\[?([\d\.\:a-f]{7,100})\]?$/i or die
     "failed to get remote address from [$ENV{REMOTE_ADDR}], so can't send traceable email";
  $self->print("Received: from [$1]\n");

  my $me = ($ENV{SERVER_NAME} =~ /^([\w\-\.]{1,100})$/ ? $1 : 'unknown');
  $self->print("\tby $me ($traceinfo)\n");

  my $date = strftime '%a, %e %b %Y %H:%M:%S GMT', gmtime;
  $self->print("\twith HTTP; $date\n");

  if ($ENV{SCRIPT_NAME} =~ /^([\w\-\.\/]{1,100})$/) {
    $self->print("\t(script-name $1)\n");
  }

  if (defined $ENV{HTTP_HOST} and $ENV{HTTP_HOST} =~ /^([\w\-\.]{1,100})$/) {
    $self->print("\t(http-host $1)\n");
  }

  my $ff = $ENV{HTTP_X_FORWARDED_FOR};
  if (defined $ff) {
    $ff =~ /^\s*([\w\-\.\[\] ,]{1,200})\s*/ or die
      "malformed X-Forwarded-For [$ff], suspect attack, aborting";

    $self->print("\t(http-x-forwarded-for $1)\n");
  }

  my $ref = $ENV{HTTP_REFERER};
  if (defined $ref and $ref =~ /^([\w\-\.\/\:\;\%\@\#\~\=\+\?]{1,100})$/) {
    $self->print("\t(http-referer $1)\n");
  }
}

=back

=head1 VIRTUAL METHODS

Subclasses must implement the following methods:

=over

=item newmail ( TRACEINFO, SENDER, @RECIPIENTS )

Starts a new email.  TRACEINFO is the script name and version, SENDER is
the email address to use as the envelope sender and @RECIPIENTS is a list
of recipients.  Dies on error.

=item print ( @ARGS )

Concatenates the arguments and appends them to the email.  Both the
header and the body should be sent in this way, separated by a single
blank line.  Dies on error.

=item endmail ()

Finishes the email, flushing buffers and sending it.  Dies on error.

=back

=head1 SEE ALSO

L<CGI::NMS::Mailer::Sendmail>, L<CGI::NMS::Mailer::SMTP>,
L<CGI::NMS::Script>

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2003 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

