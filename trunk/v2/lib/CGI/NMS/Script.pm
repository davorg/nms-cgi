package CGI::NMS::Script;
use strict;

use CGI;
use POSIX qw(locale_h strftime);
use CGI::NMS::Charset;

=head1 NAME

CGI::NMS::Script - base class for NMS script modules

=head1 SYNOPSYS

  use base qw(CGI::NMS::Script);

  ...
 
=head1 DESCRIPTION

This module is a base class for the C<CGI::NMS::Script::*> modules,
which implement plugin replacements for Matt Wright's Perl CGI
scripts.

=head1 CONSTRUCTORS

=over

=item new ( CONFIG )

Creates a new C<CGI::NMS::Script> object and performs compile time
initialisation.

CONFIG is a key,value,key,value list, which will be stored as a hash
within the object, under the name C<CFG>.

=cut

sub new {
  my ($pkg, @cfg) = @_;

  my $self = bless {}, $pkg;

  $self->{CFG} = {
    DEBUGGING           => 0,
    emulate_matts_code  => 0,
    secure              => 1,
    locale              => '',
    charset             => 'iso-8859-1',
    style               => '',
    cgi_post_max        => 1000000,
    cgi_disable_uploads => 1,

    $self->default_configuration,

    @cfg
  };

  $self->{Charset} = CGI::NMS::Charset->new( $self->{CFG}{charset} );

  $self->init;

  return $self;
}

=back

=item CONFIGURATION SETTINGS

Values for the following configuration settings can be passed to new().

Subclasses for different NMS scripts will define their own set of
configuration settings, but they all inherit these as well.

=over

=item C<DEBUGGING>

If this is set to a true value, then the error message will be displayed
in the browser if the script suffers a fatal error.  This should be set
to 0 once the script is in service, since error messages may contain
sensitive information such as file paths which could be useful to
attackers.

Default: 0

=item C<emulate_matts_code>

When this variable is set to a true value (e.g. 1) the script will work
in exactly the same way as its counterpart at Matt's Script Archive. If
it is set to a false value (e.g. 0) then more advanced features and
security checks are switched on. We do not recommend changing this 
ariable to 1, as the resulting drop in security may leave your script
open to abuse.

=item C<secure>

When this variable is set to a true value (e.g. 1) many additional
security features are turned on.  We do not recommend changing this
variable to 0, as the resulting drop in security may leave your script
open to abuse.

=item C<locale>

This determines the language that is used in the format_date() method -
by default this is blank and the language will probably be english.

Default: ''

=item C<charset>

The character set to use for output documents.

Default: 'iso-8859-1'

=item C<style>

This is the URL of a CSS stylesheet which will be used for script
generated messages.  This should probably be the same as the one that
you use for all the other pages.  This should be a local absolute URI
fragment.  Set C<style> to 0 or the emtpy string if you don't want to
use style sheets.

=item C<cgi_post_max>

The variable C<$CGI::POST_MAX> is gets set to this value before the
request is handled.

Default: 1000000

=item C<cgi_disable_uploads>

The varaible C<CGI::DISABLE_UPLOADS> gets set to this value before
the request is handled.

Default: 1

=item C<no_xml_doc_header>

If this is set to a true value then the output_cgi_html_header() method
will omit the XML document header that it would normally output.  This
means that the output document will not be strictly valid XHTML, but it
may work better in some older browsers.

Default: not set

=item C<no_doctype_doc_header>

If this is set to a true value then the output_cgi_html_header)() method
will omit the DOCTYPE document header that it would normally output.
This means that the output document will not be strictly valid XHTML, but
it may work better in some older browsers.

Default: not set

=item C<no_xmlns_doc_header>

If this is set to a true value then the output_cgi_html_header() method
will omit the C<xmlns> attribute from the opening C<html> tag that it
outputs.

=back

=head1 METHODS

=over

=item request ()

This is the method that the CGI script invokes once for each run of the
CGI.  This inplementation sets up some things that are common to all NMS
scripts and then invokes the virtual method handle_request() to do the
script specific processing.

=cut

sub request {
  my ($self) = @_;

  local ($CGI::POST_MAX, $CGI::DISABLE_UPLOADS);
  $CGI::POST_MAX        = $self->{CFG}{cgi_post_max};
  $CGI::DISABLE_UPLOADS = $self->{CFG}{cgi_disable_uploads};

  $ENV{PATH} =~ /(.*)/m or die;
  local $ENV{PATH} = $1;
  local $ENV{ENV}  = '';

  $self->{CGI} = CGI->new;
  $self->{Done_Headers} = 0;

  my $old_locale;
  if ($self->{CFG}{locale}) {
    $old_locale = POSIX::setlocale( LC_TIME );
    POSIX::setlocale( LC_TIME, $self->{CFG}{locale} );
  }

  eval { local $SIG{__DIE__} ; $self->handle_request };
  my $err = $@;

  if ($self->{CFG}{locale}) {
    POSIX::setlocale( LC_TIME, $old_locale );
  }

  if ($err) {
    my $message;
    if ($self->{CFG}{DEBUGGING}) {
      $message = $self->escape_html($err);
    }
    else {
      $message = "See the web server's error log for details";
    }

    $self->output_cgi_html_header;
    print <<END;
 <head>
  <title>Error</title>
 </head>
 <body>
  <h1>Application Error</h1>
  <p>
   An error has occurred in the program
  </p>
  <p>
   $message
  </p>
 </body>
</html>
END

    die $err;
  }
}

=item output_cgi_html_header ()

Prints the CGI content-type header and the standard header lines for
an XHTML document, unless the header has already been output.

=cut

sub output_cgi_html_header {
  my ($self) = @_;

  return if $self->{Done_Header};

  $self->output_cgi_header;

  unless ($self->{CFG}{no_xml_doc_header}) {
    print qq|<?xml version="1.0" encoding="$self->{CFG}{charset}"?>\n|;
  }

  unless ($self->{CFG}{no_doctype_doc_header}) {
    print <<END;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
END
  }

  if ($self->{CFG}{no_xmlns_doc_header}) {
    print "<html>\n";
  }
  else {
    print qq|<html xmlns="http://www.w3.org/1999/xhtml">\n|;
  }

  $self->{Done_Header} = 1;
}

=item output_cgi_header ()

Outputs the CGI header for an HTML docuement.

=cut

sub output_cgi_header {
  my ($self) = @_;

  my $charset = $self->{CFG}{charset};
  my $cgi = $self->cgi_object;

  if ($CGI::VERSION >= 2.57) {
    # This is the correct way to set the charset
    print $cgi->header('-type'=>'text/html', '-charset'=>$charset);
  }
  else {
    # However CGI.pm older than version 2.57 doesn't have the
    # -charset option so we cheat:
    print $cgi->header('-type' => "text/html; charset=$charset");
  }
}

=item output_style_element ()

Outputs the C<link rel=stylesheet> header line, if a style sheet URL is
configured.

=cut

sub output_style_element {
  my ($self) = @_;

  if ($self->{CFG}{style}) {
    print qq|<link rel="stylesheet" type="text/css" href="$self->{CFG}{style}" />\n|;
  }
}

=item cgi_object ()

Returns a reference to the C<CGI.pm> object for this request.

=cut

sub cgi_object {
  my ($self) = @_;

   return $self->{CGI};
}

=item escape_html ( INPUT )

Returns a copy of the string INPUT with all HTML metacharcters escaped.

=cut

sub escape_html {
  my ($self, $input) = @_;

  return $self->{Charset}->escape($input);
}

=item strip_nonprint ( INPUT )

Returns a copy of the string INPUT with runs of nonprintable characters
replaced by spaces.

=cut

sub strip_nonprint {
  my ($self, $input) = @_;

  &{ $self->{Charset}->strip_nonprint_coderef }($input);
}

=item format_date ( FORMAT_STRING [,GMT_OFFSET] )

Returns the current time and date formated by C<strftime> according
to the format string FORMAT_STRING.

If GMT_OFFSET is undefined or the empty string then local time is
used.  Otherwise GMT is used, with an offset of GMT_OFFSET hours.

=cut

sub format_date {
  my ($self, $format_string, $gmt_offset) = @_;

  if (defined $gmt_offset and length $gmt_offset) {
    return strftime $format_string, gmtime(time + 60*60*$gmt_offset);
  }
  else {
    return strftime $format_string, localtime;
  }
}

=back

=head1 VIRTUAL METHODS

Subclasses for individual NMS scripts must provide the following
methods:

=over

=item default_configuration ()

Invoked from new(), this method must return the default script
configuration as a key,value,key,value list.  Configuration options
passed to new() will override those set by this method.

=item init ()

Invoked from new(), this method can be used to do any script specific
object initialisation.  There is a default implementation, which does
nothing.

=cut

sub init {}

=item handle_request ()

Invoked from request(), this method is responsible for performing the
bulk of the CGI processing.  Any fatal errors raised here will be
traped and treated according to the C<DEBUGGING> configuration setting.

=back

=head1 SEE ALSO

L<CGI::NMS::Charset>, L<CGI::NMS::Script::FormMail>

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

