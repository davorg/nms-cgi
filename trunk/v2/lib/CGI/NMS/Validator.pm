package CGI::NMS::Validator;
use strict;

=head1 NAME

CGI::NMS::Validator - validation methods

=head1 SYNOPSYS

  use base qw(CGI::NMS::Validator);

  ...
 
  my $validurl = $self->validate_abs_url($url);

=head1 DESCRIPTION

This module provides methods to validate some of the types of
data the occur in CGI scripts, such as URLs and email addresses.

=head1 METHODS

These C<validate_*> methods all return undef if the item passed
in is invalid, otherwise they return the valid item.

Some of these methods attempt to tranform invalid input into valid
input (for example, validate_abs_url() will prepend http:// if missing)
so the returned valid item may not be the same as that passed in.

The returned value is always detainted.

=over

=item validate_abs_url ( URL )

Validates an absolute URL.

=cut

sub validate_abs_url {
  my ($self, $url) = @_;

  $url = "http://$url" unless $url =~ /:/;
  $url =~ s#^(\w+://)# lc $1 #e;

  $url =~ m< ^ ( (?:ftp|http|https):// [\w\-\.]{1,100} (?:\:\d{1,5})? ) (.*) $ >mx
    or return '';

  my ($prefix, $path) = ($1, $2);
  return $prefix unless length $path;

  $path = $self->validate_local_abs_uri_frag($path);
  return '' unless $path;
  
  return "$prefix$path";
}

=item validate_local_abs_uri_frag ( URIFRAG )

Validates a local absolute URI fragment, such as C</img/foo.png>.  Allows
a query string.  The empty string is considered to be a valid URI fragment.

=cut

sub validate_local_abs_uri_frag {
  my ($self, $frag) = @_;

  $frag =~ m< ^ ( (?: /  [\w\-.!~*'(|);/\@+\$,%#&=]* )?
                  (?: \? [\w\-.!~*'(|);/\@+\$,%#&=]* )?
                )
              $
           >x ? $1 : '';
}

=item validate_url ( URL )

Validates a URL, which can be either an absolute URL or a local absolute
URI fragment.

=cut

sub validate_url {
  my ($self, $url) = @_;

  if ($url =~ m#://#) {
    $self->validate_abs_url($url);
  }
  else {
    $self->validate_local_abs_uri_frag($url);
  }
}

=item validate_email ( EMAIL )

Validates an email address.

=cut

sub validate_email {
  my ($self, $email) = @_;

  $email =~ /^([a-z0-9_\-\.\*\+\=]{1,100})\@([^@]{2,100})$/i or return 0;
  my ($user, $host) = ($1, $2);

  return 0 if $host =~ m#^\.|\.$|\.\.#;

  if ($host =~ m#^\[\d+\.\d+\.\d+\.\d+\]$# or $host =~ /^[a-z0-9\-\.]+$/i ) {
     return "$user\@$host";
   }
   else {
     return 0;
  }
}

=item validate_realname ( REALNAME )

Validates a real name, i.e. an email address comment field.

=cut

sub validate_realname {
  my ($self, $realname) = @_;

  $realname =~ tr# a-zA-Z0-9_\-,./'\200-\377# #cs;
  $realname = substr $realname, 0, 128;

  $realname =~ m#^([ a-zA-Z0-9_\-,./'\200-\377]*)$# or die "failed on [$realname]";
  return $1;
}

=item validate_html_color ( COLOR )

Validates an HTML color, either as a named color or as RGB values in hex.

=cut

sub validate_html_color {
  my ($self, $color) = @_;

  $color =~ /^(#[0-9a-z]{6}|[\w\-]{2,50})$/i ? $1 : '';
}

=back

=head1 SEE ALSO

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

