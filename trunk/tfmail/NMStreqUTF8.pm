package NMStreqUTF8;
use strict;

use base qw(NMStreq);

=head1 NAME

NMStreqUTF8 - NMStreq object using the utf-8 charset

=head1 DESCRIPTION

The C<NMStreqUTF8> class is derived from the C<NMStreq> class.  It
changes the character encoding scheme from C<iso-8859-1> to C<utf-8>.

See L<NMStreq>.

Use this module instead of C<NMStreq> if you want to use the C<utf-8>
character encoding.  You will need to set the charset to C<utf-8> in
all output document templates that set a charset, and ensure that
browsers use the C<utf-8> encoding when submitting data to your
application.

Some browsers will submit in C<utf-8> if the document that contains
the HTML form uses the C<utf-8> encoding.  Some browsers honour the
C<accept-charset> form attribute, and some have to be tricked into
using C<utf-8> by giving them a unicode character to submit.

This combination works in a lot of browsers:

  <form accept-charset="utf-8" ...
  <input type="hidden" name="_utf8" value="&#x1EEE;" />

=cut

=head1 METHODS

These method implementations override their equivalents in the
C<NMStreq> class.

=over

=item strip_nonprintable ( STRING )

Returns a copy of STRING with everything but printable C<us-ascii>
characters and valid C<utf-8> multibyte sequences replaced with
space characters.

=cut

sub strip_nonprintable
{
   my ($self, $string) = @_;

   return '' unless defined $string;

   $string =~
   s%
    ( [\t\n\040-\176]               # printable us-ascii
    | [\xC2-\xDF][\x80-\xBF]        # U+00000080 to U+000007FF
    | \xE0[\xA0-\xBF][\x80-\xBF]    # U+00000800 to U+00000FFF
    | [\xE1-\xEF][\x80-\xBF]{2}     # U+00001000 to U+0000FFFF
    | \xF0[\x90-\xBF][\x80-\xBF]{2} # U+00010000 to U+0003FFFF
    | [\xF1-\xF7][\x80-\xBF]{3}     # U+00040000 to U+001FFFFF
    | \xF8[\x88-\xBF][\x80-\xBF]{3} # U+00200000 to U+00FFFFFF
    | [\xF9-\xFB][\x80-\xBF]{4}     # U+01000000 to U+03FFFFFF
    | \xFC[\x84-\xBF][\x80-\xBF]{4} # U+04000000 to U+3FFFFFFF
    | \xFD[\x80-\xBF]{5}            # U+40000000 to U+7FFFFFFF
    ) | .
   %
    defined $1 ? $1 : ' '
   %gexs;

   #
   # U+FFFE, U+FFFF and U+D800 to U+DFFF are dangerous and
   # should be treated as invalid combinations, according to
   # http://www.cl.cam.ac.uk/~mgk25/unicode.html
   #
   $string =~ s%\xEF\xBF[\xBE-\xBF]% %g;
   $string =~ s%\xED[\xA0-\xBF][\x80-\xBF]% %g;

   return $string;
}

=item escape_html ( STRING )

Returns a copy of STRING with any HTML metacharacters
escaped.  Escapes all but the most commonly occurring C<us-ascii>
characters and valid C<utf-8> multibyte sequences.

=cut

sub escape_html
{
   my ($self, $string) = @_;

   $string =~
   s%
    ( [\w \t\r\n\-\.\,]             # common characters
    | [\xC2-\xDF][\x80-\xBF]        # U+00000080 to U+000007FF
    | \xE0[\xA0-\xBF][\x80-\xBF]    # U+00000800 to U+00000FFF
    | [\xE1-\xEF][\x80-\xBF]{2}     # U+00001000 to U+0000FFFF
    | \xF0[\x90-\xBF][\x80-\xBF]{2} # U+00010000 to U+0003FFFF
    | [\xF1-\xF7][\x80-\xBF]{3}     # U+00040000 to U+001FFFFF
    | \xF8[\x88-\xBF][\x80-\xBF]{3} # U+00200000 to U+00FFFFFF
    | [\xF9-\xFB][\x80-\xBF]{4}     # U+01000000 to U+03FFFFFF
    | \xFC[\x84-\xBF][\x80-\xBF]{4} # U+04000000 to U+3FFFFFFF
    | \xFD[\x80-\xBF]{5}            # U+40000000 to U+7FFFFFFF
    ) | (.)
   %
    defined $1 ? $1 : $NMStreq::eschtml_map{$2}
   %gexs;

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

