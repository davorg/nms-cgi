package NMStreqWeak;
use strict;

use base qw(NMStreq);

=head1 NAME

NMStreqWeak - NMStreq object usable with any charset

=head1 DESCRIPTION

The C<NMStreqWeak> class is derived from the C<NMStreq> class.  It
weakens the HTML metacharacter escaping and non-printable character
striping methods to the point where they will work in most character
sets.

See L<NMStreq>.

Use this module instead of C<NMStreq> if you can't use C<utf-8> or
any of the C<iso-8859-*> charsets.

This module offers less security than the alternatives, since it
needs to allow almost all bytes through unaltered.  Think about
using C<utf-8> and C<NMStreqUTF8> instead.

=cut

=head1 METHODS

These method implementations override their equivalents in the
C<NMStreq> class.

=over

=item strip_nonprintable ( STRING )

Returns a copy of STRING with sequences of NULL characters replaced
with space characters.

=cut

sub strip_nonprintable
{
   my ($self, $string) = @_;

   return '' unless defined $string;
   $string =~ s/\0+/ /g;
   return $string;
}
   
=item escape_html ( STRING )

Returns a copy of STRING with any HTML metacharacters escaped.
In order to work in any charset, escapes only E<lt>, E<gt>, C<">
and C<&> characters.

=cut

sub escape_html
{
   my ($self, $string) = @_;

   $string =~ s/[<>"&]/$NMStreq::eschtml_map{$1}/eg;
   return $string;
}

=back

=head1 SEE ALSO

L<NMStreq>

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

