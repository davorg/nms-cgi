package CGI::NMS::Mailer::ByScheme;
use strict;

=head1 NAME

CGI::NMS::Mailer::ByScheme - mail sending engine switch

=head1 SYNOPSYS

  my $mailer = CGI::NMS::Mailer::ByScheme->new('/usr/lib/sendmail -oi -t');

  my $mailer = CGI::NMS::Mailer::ByScheme->new('SMTP:mailhost.bigisp.net');

=head1 DESCRIPTION

This implementation of the mailer object defined in L<CGI::NMS::Mailer>
chooses between L<CGI::NMS::Mailer::SMTP> and L<CGI::NMS::Mailer::Sendmail>
based on the string passed to new().

=head1 CONSTRUCTORS

=over

=item new ( ARGUMENT )

ARGUMENT must either be the string C<SMTP:> followed by the name or
dotted decimal IP address of an SMTP server that will relay mail
for the web server, or the path to a sendmail compatible binary,
including switches.

=cut

sub new {
  my ($pkg, $argument) = @_;

  if ($argument =~ /^SMTP:([\w\-\.]+(:\d+)?)/i) {
    my $mailhost = $1;
    require CGI::NMS::Mailer::SMTP;
    return CGI::NMS::Mailer::SMTP->new($mailhost);
  }
  else {
    require CGI::NMS::Mailer::Sendmail;
    return CGI::NMS::Mailer::Sendmail->new($argument);
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
  
