package CGI::NMS::Mailer::Sendmail;
use strict;

use IO::File;
use CGI::NMS::Mailer;
use base qw(CGI::NMS::Mailer);

=head1 NAME

CGI::NMS::Mailer::Sendmail - mail sender using sendmail

=head1 SYNOPSYS

  my $mailer = CGI::NMS::Mailer::Sendmail->new('/usr/lib/sendmail -oi -t');

  $mailer->newmail($from, $to);
  $mailer->print($email_header_and_body);
  $mailer->endmail;

=head1 DESCRIPTION

This implementation of the mailer object defined in L<CGI::NMS::Mailer>
uses a piped open to the UNIX sendmail program to send the email.

=head1 CONSTRUCTORS

=over

=item new ( MAILPROG )

MAILPROG msut be the shell command to which a pipe is opened, including
all nessessary switches to cause the sendmail program to read the email
recipients from the header of the email.

=cut

sub new {
  my ($pkg, $mailprog) = @_;

  return bless { Mailprog => $mailprog }, $pkg;
}

=back

=head1 METHODS

See L<CGI::NMS::Mailer> for the user interface to these methods.

=over

=item newmail ( SCRIPTNAME, POSTMASTER, @RECIPIENTS )

Opens the sendmail pipe and outputs trace headers.

=cut

sub newmail {
  my ($self, $scriptname, $postmaster, @recipients) = @_;

  my $command = $self->{Mailprog};
  $command .= qq{ -f "$postmaster"} if $postmaster;
  my $pipe;
  eval { local $SIG{__DIE__};
         $pipe = IO::File->new("| $command");
       };
  if ($@) {
    die $@ unless $@ =~ /Insecure directory/;
    delete $ENV{PATH};
    $pipe = IO::File->new("| $command");
  }

  die "Can't open mailprog [$command]\n" unless $pipe;
  $self->{Pipe} = $pipe;

  $self->output_trace_headers($scriptname);
}

=item print ( @ARGS )

Writes some email body to the sendmail pipe.

=cut

sub print {
  my ($self, @args) = @_;

  $self->{Pipe}->print(@args) or die "write to sendmail pipe: $!";
}

=item endmail ()

Closes the sendmail pipe.

=cut

sub endmail {
  my ($self) = @_;

  $self->{Pipe}->close or die "close sendmail pipe failed, mailprog=[$self->{Mailprog}]";
  delete $self->{Pipe};
}

=back

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
  
