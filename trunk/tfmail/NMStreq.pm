package NMStreq;
use strict;

use CGI;
use Carp;
use IO::File;
use POSIX qw(strftime);

use vars qw($VERSION);
$VERSION = substr q$Revision: 1.2 $, 10, -1;

=head1 NAME

NMStreq - CGI request object with output templating

=head1 SYNOPSIS

  use IO::File;
  use NMStreq;

  my $treq = NMStreq->new( ConfigRoot => '/my/config/root' );

  ....

  my $sendmail = IO::File->new('| /usr/lib/sendmail -oi -t');
  defined $sendmail or die "open sendmail pipe: $!";
  $sendmail->print($mailheader, "\n");
  $treq->process_template(
      $treq->config('email_body_template', 'main_email'),
      'email',
      $sendmail
  );
  $sendmail->close or die "close sendmail pipe: $!";

  ....

  print "Content-type: text/html; charset=iso-8859-1\n\n";

  $treq->process_template(
      $treq->config('success_page_template', 'spage'),
      'html',
      \*STDOUT
  );

  ....

=head1 DESCRIPTION

An object of the C<NMStreq> class encapsulates a CGI
request who's handing depends on a configuration file
identified by the C<_config> CGI parameter.  A
simplistic templating mechanism is provided, to ease
end user customisation of the output HTML and the
bodies of any emails sent.

=head1 CONSTRUCTORS

=over

=item new ( [OPTIONS] )

Creates a new C<NMStreq> object and populates it with
data pertinent to the current CGI request.  The CGI
parameter C<_config> will be used to identify the
correct configuration file for this request.  The
OPTIONS must consist of matching name/value pairs,
and the following options are recognised:

=over

=item C<ConfigRoot>

The filesystem path to the directory that holds the
configuration files and templates.  Defaults to
F</usr/local/nmstreq/config>.

=item C<MaxDepth>

The depth to which configuration files and templates
can be placed in subdirectories of the C<ConfigRoot>.
Defaults to 0, meaning that all configuration files
must reside directly in the C<ConfigRoot> directory.

=item C<ConfigExt>

The extension that configuration files are expected to
have.  Defaults to C<.trc>.

=item C<TemplateExt>

The extension that template files are expected to have.
Defaults to C<.trt>.

=item C<DateFormat>

The default date format string that will be used to
resolve the C<date> template directive if no C<date_fmt>
configuration setting is found.  Defaults to
C<%A, %B %d, %Y at %H:%M:%S>.

=item C<EnableUploads>

Unless this is set true, file uploads will be disabled in
C<CGI.pm>.  Defaults to false.

=item C<CGIMaxPost>

The maximum total size of post data.  Defaults to 1000000
bytes.

=back

Any other options set will be ignored by this module,
but can be interpolated into templates via the C<opt>
template directive if desired.

=back

=cut

sub new
{
   my $pkg = shift;

   my $self = bless {}, ref $pkg || $pkg;

   $self->{r}{opt} = $self->{opt} = {
      ConfigRoot    => '/usr/local/nmstreq/config',
      MaxDepth      => 0,
      ConfigExt     => '.trc',
      TemplateExt   => '.trt',
      DateFormat    => '%A, %B %d, %Y at %H:%M:%S',
      EnableUploads => 0,
      CGIPostMAx    => 1000000,
      @_
   };

   $CGI::DISABLE_UPLOADS = ($self->{opt}{EnableUploads} ? 0 : 1);
   $CGI::POST_MAX        = $self->{opt}{CGIPostMax};

   my $cgi = CGI->new;
   $self->{cgi} = $cgi;

   my $cfg_name = $cgi->param('_config');
   defined $cfg_name or $cfg_name = 'default';
   $self->{r}{config} = $self->_read_config_file($cfg_name);

   $self->{r}{param} = {};
   my @field_order = ();
   foreach my $param ($cgi->param)
   {
      my $key = $self->strip_nonprintable($param);
      my $val = join ' ',
                map {$self->strip_nonprintable($_)}
                $cgi->param($param);
      $self->{r}{param}{$key} = $val;
      push @field_order, $key if $key =~ /^[a-zA-Z0-9]/;
   }
   $self->{field_order} = \@field_order;

   foreach my $envval (keys %ENV)
   {
      my $key = $self->strip_nonprintable($envval);
      my $val = $self->strip_nonprintable($ENV{$envval});
      $self->{r}{env}{$key} = $val;
   }

   $self->{r}{date}         = \&_interpolate_date;
   $self->{r}{param_values} = \&_interpolate_param_values;

   return $self;
}

=head1 METHODS

=over

=item process_template ( TEMPLATE, CONTEXT, DEST )

Reads in the template TEMPLATE, which must be the path to a
template file, relative to the configuration root and without
the file extension.  Data is substituted for any template
directives in the template file, and the resulting document
is passed out to DEST.

CONTEXT is a string describing the context of the output
document, and must be either C<html> or C<email>.  If CONTEXT
is C<html> then all HTML metacharacters in interpolated
values will be escaped.  If CONTEXT is C<email> then space
characters will be inserted at a couple of points to, reduce
the scope for malicious input values to make mail software do
bad things.

DEST can be a coderef, a file glob, an object with a
print() method, or undef.

On failure, invokes the non-returning error() method.

If DEST is undef, then all template output is accumulated
into a string, which becomes the return value.

=cut

sub process_template
{
   my ($self, $template, $context, $dest) = @_;

   my ($ret, $coderef);
   if (defined $dest)
   {
      $ret = 1;
      $coderef = $self->_dest_to_coderef($dest);
   }
   else
   {
      $ret = '';
      $coderef = sub { $ret .= $_[0] };
   }

   my $fh = $self->_open_file($template, "$context template");

   local $_;
   while(<$fh>)
   {
      while( s|^(.*?) \{\= \s* (\w+(?:\.\w+)?) \s* \=\} ||x )
      {
         my ($pre, $subst) = ($1, $2);
         &{ $coderef }($pre) if length $pre;
         $self->_interpolate($context, $subst, $coderef);
      }
      &{ $coderef }($_) if length;
   }

   $fh->close;
   return $ret;
}

=item install_directive ( NAME, VALUE )

Installs an extra directive into the data tree used for
interpolating values into templates.  NAME must be a
string consisting of word characters only.  VALUE can
be any of:

=over

=item C<a string>

If VALUE is a string then that string will be substituted
for the NAME template directive.

=item C<a coderef>

If VALUE is a coderef then it will be called to produce the
substitute text whenever the NAME directive is encountered.
It will be passed a reference to the C<NMStreq> object as
its first argument, the context string ("html" or "email")
as its second argument, and a destination coderef as its
third argument.  The VALUE coderef can pass output direct
to the destination coderef, and/or return some output as
a string.

=item C<a hashref>

In this case a new tree of two-part directives is defined,
with the sub-directives corresponding to the keys in the
hash.  The values in the hash must be strings, coderefs
or further hashrefs.

=back

=cut

sub install_directive
{
   my ($self, $name, $value) = @_;

   $self->{r}{$name} = $value;
}

=item uninstall_directive ( NAME )

Removes a directive previously installed with the
install_directive() method, or disables one of the builtin
directives.

Returns a value which will reinstall the directive if passed
to the install_directive() method.

=cut

sub uninstall_directive
{
   my ($self, $name) = @_;

   my $save = $self->{r}{$name};
   delete $self->{r}{$name};
   return $save;
}

=item config ( SETTING_NAME, DEFAULT )

Returns the value of the configuration setting SETTING_NAME
set in the configuration file for this request, or DEFAULT
if no value for SETTING_NAME has been set.

=cut

sub config
{
   my ($self, $setting_name, $default) = @_;

   my $val = $self->{r}{config}{$setting_name};
   defined $val ? $val : $default;
}

=item param ( PARAM_NAME )

Returns the value of the CGI parameter PARAM_NAME, with
runs of nonprintable characters replaced with spaces.
If the same CGI parameter appears several times then all
the values of that parameter are joined together, using
a single space character as a separator.

Returns the empty string if no such parameter is set.

=cut

sub param
{
   my ($self, $param_name) = @_;

   my $val = $self->{r}{param}{$param_name};
   defined $val ? $val : '';
}

=item param_list ()

Returns a list of the names of all CGI parameters who's
names start with a number or a letter.  The parameter
names are returned in the order in which each parameter
first occurs in the request.  There will be no
duplicates in the list returned.

Runs of nonprintable characters in parameter names are
replaced with spaces, both in the list returned by this
method and in the parameter names recognised by the
param() method.

=cut

sub param_list
{
   my ($self) = @_;

   return @{ $self->{field_order} };
}

=item cgi ()

Returns a reference to the C<CGI> object that this modules
uses to access the CGI parameter list.

=cut

sub cgi
{
   my ($self) = @_;

   return $self->{cgi};
}

=back

=head1 METHODS TO OVERRIDE

Subclasses may override any of the following methods in
order to alter the class's behavior.

=over

=item error ( MESSAGE )

A non-returning method used to handle fatal errors.  The
MESSAGE string may contain unsafe and potentially malicious
data and so must be handled with care.

This method must not return.

The default implementation calls croak().

=cut

sub error
{
   my ($self, $message) = @_;

   croak $message;
}

=item strip_nonprintable ( STRING )

Returns a copy of STRING with runs of non-printable
characters replaced with space.  The default implementation
allows all printable C<iso-8859-1> characters (including
some with the high bit set) and disallows control and
whitespace characters other than tab, newline, space and
nbsp (character 160, non-breaking space).

=cut

sub strip_nonprintable
{
   my ($self, $string) = @_;

   return '' unless defined $string;
   $string =~ tr#\t\n\040-\176\240-\377# #cs;
   return $string;
}

=item escape_html ( STRING )

Returns a copy of STRING with any HTML metacharacters
escaped.  The default implementation is paranoid in that
it escapes all but the most commonly occurring characters.

=cut

BEGIN
{
   use vars qw(%eschtml_map);
   %eschtml_map = ( ( map {chr($_) => "&#$_;"} (0..255) ),
                    '<' => '&lt;',
                    '>' => '&gt;',
                    '&' => '&amp;',
                    '"' => '&quot;',
                 );
}

sub escape_html
{
   my ($self, $string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,])| $eschtml_map{$1} |ge;
   return $string;
}

=back

=head1 INTERNAL METHODS

None of these methods should be accessed from outside this
module.

=over

=item _interpolate ( CONTEXT, DIRECTIVE, CODEREF )

Resolves a single template directive in context CONTEXT
and outputs the result via the coderef CODEREF.  DIRECTIVE
is the string found between the template directive
delimiters, with leading and trailing whitespace removed.

=cut

sub _interpolate
{
   my ($self, $context, $directive, $coderef) = @_;

   my $data_src = $self->{r};
   while ($directive =~ s#^(\w+)\.##)
   {
      $data_src = $data_src->{$1};
      defined $data_src or return;
      ref $data_src eq 'HASH' or return;
   }

   my $value = $data_src->{$directive};
   defined $value or return;

   if (ref $value eq 'CODE')
   {
      $value = &{ $value }($self, $context, $coderef);
   }
   elsif (ref $value)
   {
      return;
   }

   if ($context eq 'html')
   {
      $value = $self->escape_html($value);
   }
   elsif ($context eq 'email')
   {
      # Disable HTML tags with minimum impact
      $value =~ s#<([a-z])#< $1#gi;

      # Don't allow multiline inputs to control the first
      # character of the line.
      $value =~ s#(\r|\n)(\S)#$1 $2#g;

      # Could be trying to fake a MIME boundry.
      $value =~ s/------/ ------/g;
   }
   else
   {
      $self->error("unknown template context [$context]");
   }

   &{ $coderef }($value) if length $value;
}

=item _interpolate_date ( CONTEXT, CODEREF )

Resolves a C<date> template directive.

=cut

sub _interpolate_date
{
   my ($self, $context, $coderef) = @_;

   my $date_fmt = $self->{r}{'config'}{date_fmt};
   defined $date_fmt or $date_fmt = $self->{opt}{DateFormat};

   return strftime $date_fmt, localtime;
}

=item _interpolate_param_values ( CONTEXT, CODEREF )

Resolves a C<param_values> template directive.

=cut

sub _interpolate_param_values
{
   my ($self, $context, $coderef) = @_;

   my $template = $self->{r}{'config'}{"param_values_${context}_template"};
   defined $template or $template = "pv_$context";

   my $field_order = $self->{field_order};
   my $sort = $self->{r}{'config'}{'sort'} || '';
   if ($sort =~ /^alpha/i)
   {
      $field_order = [ sort @$field_order ];
   }
   elsif ($sort =~ s#^\s*order\s*:\s*##i)
   {
      $field_order = [ split /\s*,\s*/, $sort ];
   }

   foreach my $input (@$field_order)
   {
      my $value = $self->param($input);
      next unless $self->config('print_blank_fields', '') or $value !~ /^\s*$/;
      $self->{r}{name}  = $input;
      $self->{r}{value} = $value;
      $self->process_template($template, $context, $coderef);
   }
   delete $self->{r}{name};
   delete $self->{r}{value};

   return ''; # We've already done our output direct to $coderef
}

=item _dest_to_coderef ( DEST )

Converts a template output destination (which can be a
coderef, a file glob or an object reference) into a
coderef.

=cut

sub _dest_to_coderef
{
   my ($self, $dest) = @_;

   if (ref $dest eq 'CODE')
   {
      return $dest;
   }
   elsif (ref $dest eq 'GLOB')
   {
      return sub { print $dest $_[0] or $self->error("write failed: $!") };
   }
   else
   {
      return sub { $dest->print($_[0]) or $self->error("print failed: $!") };
   }
}

=item _read_config_file ( CONFIG_FILE )

Reads in and interprets the configuration file CONFIG_FILE,
which must be the path to a config file, relative to
the configuration root and without the file extension.

On success, returns a reference to a hash of configuration
settings.

On failure, invokes the non-returning error() method.

=cut

sub _read_config_file
{
   my ($self, $cfg_file) = @_;

   my $fh = $self->_open_file($cfg_file, 'configuration');

   my %config = ();
   my $key = '**NOKEY**';
   local $_;
   while(<$fh>)
   {
      next if m%^\s*(#|$)%;
      $key = $1 if s#^(\w+):##;
      s#^\s*##;
      s#\s*$##;
      next unless length;
      $config{$key} = (defined $config{$key} ? "$config{$key} $_" : $_);
   }
   delete $config{'**NOKEY**'};

   $fh->close;
   return \%config;
}

=item _open_file ( FILENAME, FILETYPE )

Checks that FILENAME is a valid relative file path without
file extension for a template or configuration file, opens
the file, checks that it has the correct header line and
returns an C<IO::File> object from which the remainder of
the file can be read.

The FILETYPE parameter should be one of the following
strings: "configuration", "S<html template>" or
"S<email template>".

Calls the non-returning error() method if anything goes
wrong.

=cut

sub _open_file
{
   my ($self, $filename, $filetype) = @_;


   unless ( $filename =~ m#^[a-zA-Z0-9]# and
            $filename =~ m#[a-zA-Z0-9]$# and
            $filename =~ m#^([/a-zA-Z0-9_]{1,100})$# )
   {
      $self->error("Invalid $filetype filename: [$filename]");
   }
   $filename = $1;

   $filename =~ s#/+#/#g;
   my $slashcount = $filename =~ tr#/##;

   if ($slashcount > $self->{opt}{MaxDepth})
   {
      $self->error("$filetype filename [$filename] contains too many '/' characters");
   }

   my $ext;
   if ( $filetype eq 'configuration' )
   {
      $ext = $self->{opt}{ConfigExt};
   }
   elsif ( $filetype =~ / template$/ )
   {
      $ext = $self->{opt}{TemplateExt};
   }
   else
   {
      error("bad file type [$filetype]");
   }

   my $path = "$self->{opt}{ConfigRoot}/$filename$ext";

   unless (-f $path)
   {
      $self->error("$filetype file not found: [$filename]");
   }

   my $fh = IO::File->new("<$path");
   unless (defined $fh)
   {
      $self->error("failed to open $filetype file [$filename] ($!)");
   }

   my $header = <$fh>;
   unless (defined $header and
           $header =~ m#^\%\% NMS \Q$filetype\E file \%\%$#)
   {
      $self->error("$filetype file [$filename] lacks a valid header line");
   }

   return $fh;
}

=back

=cut

1;

__END__

=head1 CONFIGURATION FILE SYNTAX

Each configuration file sets values for a set of named keys.

The key names can consist of word characters only.  The
values can contain any character, but whitespace sequences
at the start and end of each line will be discarded when
the configuration file is parsed.

The first line of the template file must be the exact text:

  %% NMS configuration file %%

Lines starting with '#' are ignored.  Whitespace can
precede the '#' character.

Any set of one or more word characters followed by a ':'
character at the start of a line introduces a new key.  All
text until another key is introduced becomes the value for
that key.

If a key appears more than once then the values will be
joined using a space character as a delimiter.

For example:

  %% NMS configuration file %%
  #
  # This is an example of a configuration file.  It assigns
  # the value "one two three four" to key 'foo' and the value
  # "1   2 3 4" to key 'bar'.
  #

  foo: one two
       # This is an indented comment
       three

  bar: 1   2
  bar:3 4

  foo:
       four

=head1 TEMPLATE FILE SYNTAX

The first line of any template file must be either:

  %% NMS html template file %%

or

  %% NMS email template file %%

depending on the context in which the template is to be used.

All other lines in the template will be copied to the output
with template directives replaced by the corresponding data
values.  Template directives consist of the string "{=",
optional whitespace, the directive name, optional whitespace,
and the string "=}".  The directive names can be simple words
such as "date" or constructs such as "param.foo".

Template directives may not be split over multiple lines.

Here is an example of an HTML template:

  %% NMS html template file %%
  <?xml version="1.0" encoding="iso-8859-1"?>
  <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
    <title>{= config.html_title =}</title>
   </head>
   <body>
    <h1>{= config.html_title =}</h1>
    <p>
     Hello, the date is {= date =} and your user agent is
     <i>{= env.HTTP_USER_AGENT =}</i>.
    </p>
    <p>
     You put <b>{= param.foo =}</b> in the <b>foo</b> input.
    </p>
  {= param_values =}
   </body>
  </html>

The directives that can be used are:

=over

=item C<config.*>

The C<config.html_title> directive draws the title for the
document from a value set in the configuration file, allowing
different configuration files to use this template with
different titles.  Any configuration value can be substituted
in this way.

=item C<opt.*>

The C<opt.*> directive (not used in this example) substitutes
values passed to the C<NMStreq> object's constructor into
the output document.

=item C<env.*>

The C<env.*> direcitve substitutes the values of environment
variables.  Any non-printable characters will be removed
from the values using the strip_nonprintable() method.

=item C<param.*>

The C<param.*> direcitve substitutes the values of CGI
parameters.  Any non-printable characters will be removed
from the values using the strip_nonprintable() method.

=item C<date>

The C<date> directive outputs the current date, formatted
according to the C<date_fmt> configuration setting.

=item C<param_values>

The C<param_values> directive iterates over the CGI
parameters and produces some output for each.

By default, the list of parameters to visit is that
returned by the param_list() method.  To have the list
sorted alphabetically, set the C<sort> configuration
value to "alpha".

For finer control of the list of parameters that produce
output, the C<sort> configuration value can be set to the
string "order:" followed by a comma-separated list of
parameter names.  That fixes both the set of parameters
that produce output and the order in which they produce
their output.

To produce the output for each parameter, the
C<param_values> directive uses another template.  The
sub-template C<pv_html> will be used if the
C<param_values> directive is encountered in an html
template, and the C<pv_email> template will be used in
an email template.  These sub-template names can be
overridden with the C<param_values_html_template> and
C<param_values_email_template> configuration values
respectively.

Within the sub-template, two extra directives are
available: C<name> for the parameter name and C<value>
for the parameter value.  Here is an example of how the
C<pv_html> sub-template might look:

  %% NMS html template file %%
    <p>
     <b>{= name =}</b>: {= value =}
    </p>

=back

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

