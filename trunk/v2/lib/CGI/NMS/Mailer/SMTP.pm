package CGI::NMS::Mailer::SMTP;
use strict;

use IO::Socket;
use CGI::NMS::Mailer;
use base qw(CGI::NMS::Mailer);

=head1 NAME

CGI::NMS::Mailer::SMTP - mail sender using SMTP

=head1 SYNOPSYS

  my $mailer = CGI::NMS::Mailer::SMTP->new('mailhost.bigisp.net');

  $mailer->newmail($from, $to);
  $mailer->print($email_header_and_body);
  $mailer->endmail;

=head1 DESCRIPTION

This implementation of the mailer object defined in L<CGI::NMS::Mailer>
uses an SMTP connection to a mail relay to send the email.

=head1 CONSTRUCTORS

=over

=item new ( MAILHOST )

MAILHOST must be the name or dotted decimal IP address of an SMTP
server that will relay mail for the web server.

=cut

sub new {
  my ($pkg, $mailhost) = @_;

  $mailhost .= ':25' unless $mailhost =~ /:/;
  return bless { Mailhost => $mailhost }, $pkg;
}

=back

=head1 METHODS

See L<CGI::NMS::Mailer> for the user interface to these methods.

=over

=item newmail ( SCRIPTNAME, SENDER, @RECIPIENTS )

Opens the SMTP connection and sends trace headers.

=cut

sub newmail {
  my ($self, $scriptname, $sender, @recipients) = @_;

  $self->{Sock} = IO::Socket::INET->new($self->{Mailhost});
  defined $self->{Sock} or die "connect to [$self->{Mailhost}]: $!";

  my $banner = $self->_smtp_getline;
  $banner =~ /^2/ or die "bad SMTP banner [$banner] from [$self->{Mailhost}]";

  my $helohost = ($ENV{SERVER_NAME} =~ /^([\w\-\.]+)$/ ? $1 : '.');
  $self->_smtp_command("HELO $helohost");
  $self->_smtp_command("MAIL FROM: <$sender>");
  foreach my $r (@recipients) {
    $self->_smtp_command("RCPT TO: <$r>");
  }
  $self->_smtp_command("DATA", '3');

  $self->output_trace_headers($scriptname);
}

=item print ( @ARGS )

Writes some email body to the SMTP socket.

=cut

sub print {
  my ($self, @args) = @_;

  my $text = join '', @args;
  $text =~ s#\n#\015\012#g;
  $text =~ s#^\.#..#mg;

  $self->{Sock}->print($text) or die "write to SMTP socket: $!";
}

=item endmail ()

Finishes sending the mail and closes the SMTP connection.

=cut

sub endmail {
  my ($self) = @_;

  $self->_smtp_command(".");
  $self->_smtp_command("QUIT");
  delete $self->{Sock};
}

=back

=head1 PRIVATE METHODS

These methods should be called from within this module only.

=over

=item _smtp_getline ()

Reads a line from the SMTP socket, and returns it without the
newline sequence.

=cut

sub _smtp_getline {
  my ($self) = @_;

  my $sock = $self->{Sock};
  my $line = <$sock>;
  defined $line or die "read from SMTP server: $!";
  $line =~ tr#\012\015##d;

  return $line;
}

=item _smtp_command ( COMMAND [,EXPECT] )

Sends the SMTP command COMMAND to the SMTP server, and reads a line
in response.  Dies unless the first character of the response is
the character EXPECT, which defaults to '2'.

=cut

sub _smtp_command {
  my ($self, $command, $expect) = @_;
  defined $expect or $expect = '2';

  $self->{Sock}->print("$command\015\012") or die
    "write [$command] to SMTP server: $!";
  
  my $resp = $self->_smtp_getline();
  unless (substr($resp, 0, 1) eq $expect) {
    die "SMTP command [$command] gave response [$resp]";
  }
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
  
