package NMSTest::CheckerXHTML;
use strict;

=head1 NAME

NMSTest::CheckerXHTML - XHTML test output checker

=head1 DESCRIPTION

This module defines the "xhtml" check method for the
output checking engine described in
L<NMSTest::OutputChecker>.

=head1 METHODS

=over 4

=item check_xhtml ()

Ensures that the script output looks something like valid XHTML.

=cut

sub check_xhtml
{
   my ($self, $page) = @_;
   $page = 'OUT' unless defined $page;

   local $_ = $self->{PAGES}{$page};

   defined $_ or die "no $page output, expecting some XHTML\n";

   if ($page eq 'OUT')
   {
      s%^Content-type:[ \t]+text/html(; charset=(iso-8859-1|utf-8))?\r?\n\r?\n\s*%%i or die
         "can't find text/html content-type\n";
   }

   s|^<\?xml version="1.0" encoding="iso-8859-1"\?>\r?\n||i;

   s|^<!DOCTYPE \s+ html \s+ PUBLIC \s+
     "-//W3C//DTD \s+ XHTML \s+ 1\.0 \s+ Transitional//EN" \s*
     "http://www\.w3\.org/TR/xhtml1/DTD/xhtml1-transitional\.dtd"\s*>
     \s*
   ||x or die "can't find DOCTYPE header in <$_>\n";

   s#^<html xmlns="http://www\.w3\.org/1999/xhtml">\s*## or die
      "can't find correct <html> tag\n";

   s#</html>\s*\z## or die "can't find </html> in <<$_>>\n";


   my $opts = q[\s*(?:[a-z][a-z0-9]*\s*=\s*"[^"<>']*"\s*)*];

   # remove HTML comments
   s#(<!--.*?-->)#$self->_demeta($1)#ges;

   # remove self-closing tags
   s#<([a-z][a-z0-9]*$opts\s*/)>#$self->_dequote("($1)")#geo;

   # remove matching pairs
   1 while s|<(([a-z][a-z0-9]*)$opts)>(.*?)</\2>|$self->_dequote("($1)")."${3}(/$2)"|seo;

   if ( /(.*?<.*?>.*)/ )
   {
      die "unmatched tag: [$1]\n";
   }
   if ( /(.*?([<>"]).*)/ )
   {
      die "found '$2' after tag removal: [$1]\n";
   }
}

=back

=head1 PRIVATE METHODS

=over 4

=item _dequote ( STRING )

Returns a copy of STRING with " characters replaced with '
characters.

=cut

sub _dequote
{
   my ($self, $str) = @_;

   $str =~ tr/"/'/;
   return $str;
}

=item _demeta ( STRING )

Returns a copy of STRING with ", < and > characters replaced
with ', ( and ).

=cut

sub _demeta
{
   my ($self, $str) = @_;

   $str =~ tr/<>"/()'/;
   return $str;
}

=back

=head1 SEE ALSO

L<NMSTest::OutputChecker>

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

