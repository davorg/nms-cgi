#!/usr/bin/perl -wT
use strict;
#
# $Id: TFmail.pl,v 1.13 2002-07-10 08:16:14 nickjc Exp $
#
# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings, see the README file
# for detailed instructions.

use constant DEBUGGING      => 1;
use constant LIBDIR         => '.';
use constant MAILPROG       => '/usr/lib/sendmail -oi -t';
use constant POSTMASTER     => 'me@my.domain';
use constant CONFIG_ROOT    => '.';
use constant MAX_DEPTH      => 0;
use constant CONFIG_EXT     => '.trc';
use constant TEMPLATE_EXT   => '.trt';
use constant ENABLE_UPLOADS => 0;
use constant USE_MIME_LITE  => 1;
use constant LOGFILE_ROOT   => '';
use constant LOGFILE_EXT    => '.log';
use constant HTMLFILE_ROOT  => '';
use constant HTMLFILE_EXT   => '.html';
use constant CHARSET        => 'iso-8859-1';

# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)

=head1 NAME

TFmail.pl - template and config file driven formmail CGI

=head1 DESCRIPTION

This CGI script converts form input to an email message.  It
gets its configuration from a configuration file, and uses a
minimal templating system to generate output HTML and the
email message bodies.

See the F<README> file for instructions.

=cut

use constant MIME_LITE => USE_MIME_LITE || ENABLE_UPLOADS;

use Fcntl ':flock';
use lib LIBDIR;
BEGIN
{
   if (MIME_LITE)
   {
      # Use installed MIME::Lite if available, falling back to
      # the copy of MIME/Lite.pm distributed with the script.
      eval { local $SIG{__DIE__} ; require MIME::Lite };
      require MIME_Lite if $@;
      import MIME::Lite;
   }
   if (HTMLFILE_ROOT ne '')
   {
      require IO::File;
      import IO::File;
   }
   if (CHARSET eq 'utf-8')
   {
      require NMStreqUTF8;
   }
   else
   {
      require NMStreq;
   }
}

BEGIN
{
  use vars qw($VERSION);
  $VERSION = substr q$Revision: 1.13 $, 10, -1;
}

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} =~ /(.*)/ and $ENV{PATH} = $1;

use vars qw($done_headers);
$done_headers = 0;

#
# We want to trap die() calls, output an error page and
# then do another die() so that the script aborts and the
# message gets into the server's error log.  If there is
# already a __DIE__ handler installed then we must
# respect it on our final die() call.
#
eval { local $SIG{__DIE__} ; main() };
if ($@)
{
   my $message = $@;
   error_page($message);
   die($message);
}

sub main
{
   local ($CGI::DISABLE_UPLOADS, $CGI::POST_MAX);

   my $treq = (CHARSET eq 'utf-8' ? 'NMStreqUTF8' : 'NMStreq')->new(
      ConfigRoot    => CONFIG_ROOT,
      MaxDepth      => MAX_DEPTH,
      ConfigExt     => CONFIG_EXT,
      TemplateExt   => TEMPLATE_EXT,
      EnableUploads => ENABLE_UPLOADS,
      CGIPostMax    => 1000000,
   );

   if ( POSTMASTER eq 'me@my.domain' )
   {
      die "You must configure the POSTMASTER constant in the script\n";
   }
   unless ( $ENV{REQUEST_METHOD} eq 'POST' )
   {
      die 'request method must be "POST"';
   }

   my $recipients = check_recipients($treq);

   if ( check_required_fields($treq) )
   {
       setup_input_fields($treq);
       my $confto = send_main_email($treq, $recipients);
       if ( HTMLFILE_ROOT ne '' )
       {
          insert_into_html_files($treq);
       }
       if ( LOGFILE_ROOT ne '' )
       {
          log_to_file($treq);
       }
       send_confirmation_email($treq, $confto);
       return_html($treq);
   }
   else
   {
       missing_html($treq);
   }
}

=head1 INTERNAL FUNCTIONS

=over 4

=item check_recipients ( TREQ )

Checks that all configured recipients are reasonable email
addresses, and returns a string suitable for use as the value
of a To header.  Dies if any configured recipient is bad.
Returns the empty string if the 'no_email' configuration
setting is true.

=cut

sub check_recipients
{
   my ($treq) = @_;

   $treq->config('no_email', '') and return '';

   my @recip = split /[\s,]+/, $treq->config('recipient', '');
   scalar @recip or die 'no recipients specified in the config file';
   foreach my $rec (@recip)
   {
      address_ok($rec) or die
         "malformed recipient [$rec] specified in config file";
   }
   return join ', ', @recip;
}

=item address_ok ( ADDRESS )

Returns true if ADDRESS is a reasonable email address, false
otherwise.  Allows leading and trailing spaces and tabs on the
address.

=cut

sub address_ok
{
   my ($addr) = @_;

   $addr =~ m#^[ \t]*[\w\-\.\*]{1,100}\@[\w\-\.]{1,100}[ \t]*$# ? 1 : 0;
}

=item check_required_fields ( TREQ )

Returns false if any fields configured as "required" have
been left blank, true otherwise.

=cut

sub check_required_fields
{
   my ($treq) = @_;

   my @require = split /\s*,\s*/, $treq->config('required', '');

   my @missing = ();
   foreach my $r (@require)
   {
      if ($r =~ /^_?email$/)
      {
         push @missing, $r unless address_ok($treq->param($r));
      }
      else
      {
         push @missing, $r if $treq->param($r) =~ /^\s*$/;
      }
   }

   if (scalar @missing)
   {
      $treq->install_foreach('missing_field', [map {{name=>$_}} @missing]);
      return 0;
   }
   else
   {
      return 1;
   }
}

=item setup_input_fields ( TREQ )

Installs a FOREACH directive in the TREQ object to
iterate over the names and values of input fields.

Honors the 'sort' and 'print_blank_fields' configuration
settings.

=cut

sub setup_input_fields
{
   my ($treq) = @_;

   my @fields;
   my $sort = $treq->config('sort', '');
   if ($sort =~ s/^\s*order\s*:\s*//i)
   {
      @fields = split /\s*,\s*/, $sort;
   }
   else
   {
      @fields = grep {/^[a-zA-Z0-9]/} $treq->param_list;
      if ($sort =~ /^alpha/i)
      {
         @fields = sort @fields;
      }
   }

   unless ( $treq->config('print_blank_fields', '') )
   {
      @fields = grep {$treq->param($_) !~ /^\s*$/} @fields;
   }

   $treq->install_foreach('input_field',
     [map { {name => $_, value => $treq->param($_)} } @fields]
   );
}

=item send_main_email ( TREQ, RECIPIENTS )

Sends the main email to the configured recipient.

Any file uploads configured will be attached to the main email,
with "content/type" forced to "application/octet-stream" so
that mail software will do nothing with the attachments other
than allow them to be saved.

Returns the email address of the user if a valid one was
supplied, the empty string otherwise.

Dies on error.

=cut

sub send_main_email
{
   my ($treq, $recipients) = @_;

   my $email_input  = $treq->config('email_input', '');
   my $realname_input  = $treq->config('realname_input', '');

   my $from = POSTMASTER;
   my $confto = '';
   if ($email_input and address_ok($treq->param($email_input)) )
   {
      $from = $treq->param($email_input);
      $from =~ s#\s+##g;
      $confto = $from;
      if ($realname_input)
      {
         my $realname = $treq->param($realname_input, '');
         $realname =~ tr#a-zA-Z0-9_\-\.\,\'\241-\377# #cs;
         $realname = substr $realname, 0, 100;
         $from = "$from ($realname)" unless $realname =~ /^\s*$/;
      }
      my $by = $treq->config('by_submitter_by', 'by');
      $treq->install_directive('by_submitter', "$by $from ");
   }

   return $confto unless length $recipients;

   my $template = $treq->config('email_template', 'email');

   my $msg = {
      To       => $recipients,
      From     => $from,
      Subject  => $treq->config('subject', 'WWW Form Submission'),
      body     => $treq->process_template($template, 'email', undef),
   };

   if (ENABLE_UPLOADS)
   {
      $msg->{attach} = [];
      my $cgi = $treq->cgi;
      foreach my $param ($treq->param_list)
      {
         next if $param !~ /^(\w+)$/;
         $param = $1;

         my @goodext = split /\s+/, $treq->config("upload_$param", '');
         next unless scalar @goodext;
         my %goodext = map {lc $_=>$_} @goodext;

         my $filename = $cgi->param($param);
         my $info = $cgi->uploadInfo($filename);
         next unless defined $info;
         my $ct = $info->{'Content-Type'} || $info->{'Content-type'} || '';

         my $filehandle = $cgi->param($param);
         next unless defined $filehandle;
         my $data;
         { local $/; $data = <$filehandle> }

         my $bestext = $goodext[-1];
         if ( $filename =~ m#\.(\w{1,8})$# and exists $goodext{lc $1} )
         {
            $bestext = $goodext{lc $1};
         }
         elsif ( $ct =~ m#^[\w\-]+/(\w{1,8})$# and exists $goodext{lc $1} )
         {
            $bestext = $goodext{lc $1};
         }

         # Some versions of MIME::Lite can loop forever in some circumstances
         # when fed on tainted data.
         $data =~ /^(.*)$/s or die;
         $data = $1;
         $bestext =~ /^([\w\-]+)$/ or die "suspect file extension [$bestext]";
         $bestext = $1;

         push @{ $msg->{attach} }, {
            Type        => 'application/octet-stream',
            Filename    => "$param.$bestext",
            Data        => $data,
            Disposition => 'attachment',
            Encoding    => 'base64',
         };
      }
   }

   send_email($msg);

   return $confto;
}

=item send_confirmation_email ( TREQ, CONFTO )

Sends the confirmation email back to the user if configured
to do so and we have a reasonable email address for the user.

The CONFTO parameter must be the sanity checked user's email
address or the empty string it no valid email address was
given.

Dies on error.

=cut

sub send_confirmation_email
{
   my ($treq, $confto) = @_;

   return unless length $confto;

   my $conftemp = $treq->config('confirmation_template', '');
   return unless length $conftemp;

   my %save = (
     'param'        => $treq->uninstall_directive('param'),
     'param_values' => $treq->uninstall_directive('param_values'),
     'env'          => $treq->uninstall_directive('env'),
     'by_submitter' => $treq->uninstall_directive('by_submitter'),
   );
   my $save_foreach = $treq->uninstall_foreach('input_field');

   my $body = $treq->process_template($conftemp, 'email', undef);

   foreach my $k (keys %save)
   {
     $treq->install_directive($k, $save{$k});
   }
   $treq->install_foreach('input_field', $save_foreach);

   send_email({
      To      => $confto,
      From    => POSTMASTER,
      Subject => $treq->config('confirmation_subject', 'Thanks'),
      body    => $body,
   });
}

=item send_email ( HASHREF )

Adds abuse tracing headers to an outgoing email stored in a
hashref, and sends it.  Dies on error.

=cut

sub send_email
{
   my ($msg) = @_;

   my $remote_addr = $ENV{REMOTE_ADDR};
   $remote_addr =~ /^[\d\.]+$/ or die "weird remote_addr [$remote_addr]";

   my $x_remote = "[$remote_addr]";
   my $x_gen_by = "NMS TFmail v$VERSION (NMStreq $NMStreq::VERSION)";

   open SENDMAIL, '| '.MAILPROG.' -f '.POSTMASTER or die
      "open MAILPROG: $!";

   if (MIME_LITE)
   {
      my $ml = MIME::Lite->new(
         To               => $msg->{To},
         From             => $msg->{From},
         Subject          => $msg->{Subject},
         'X-Http-Client'  => $x_remote,
         'X-Generated-By' => $x_gen_by,
         Type             => 'text/plain; charset=' . CHARSET,
         Data             => $msg->{body},
         Date             => '',
         Encoding         => 'quoted-printable',
      );

      foreach my $a (@{ $msg->{attach} || [] })
      {
         $ml->attach( %$a );
      }

      $ml->print(\*SENDMAIL);
   }
   else
   {
      print SENDMAIL <<END;
X-Http-Client: $x_remote
X-Generated-By: $x_gen_by
To: $msg->{To}
From: $msg->{From}
Subject: $msg->{Subject}

$msg->{body}
END
   }

   close SENDMAIL or die
     "SENDMAIL command failed, MAILPROG constant may be set wrong\n";
}

=item log_to_file ( TREQ )

Appends to a log file, if configured to do so

=cut

sub log_to_file
{
   my ($treq) = @_;

   my $file = $treq->config('logfile', '');
   return unless $file;
   $file =~ m#^([\/\-\w]{1,100})$# or die "bad logfile name [$file]";
   $file = $1;

   open LOG, ">>@{[ LOGFILE_ROOT ]}/$file@{[ LOGFILE_EXT ]}" or die "open [$file]: $!";
   flock LOG, LOCK_EX or die "flock [$file]: $!";
   seek LOG, 0, 2 or die "seek to end of [$file]: $!";

   $treq->process_template(
      $treq->config('log_template', 'log'),
      'email',
      \*LOG
   );

   close LOG or die "close [$file] after append: $!";
}

=item insert_into_html_files ( TREQ )

Inserts template output into one or more HTML files, if configured
to do so.

=cut

sub insert_into_html_files
{
   my ($treq) = @_;

   my @files = split /[\s ,]+/, $treq->config('modify_html_files', '');
   foreach my $file (@files)
   {
      $file =~ m#^([\/\-\w]{1,100})$# or die "bad htmlfile name [$file]";
      $file = $1;
      my $path = "@{[ HTMLFILE_ROOT ]}/$file@{[ HTMLFILE_EXT ]}";

      my $template = $treq->config("htmlfile_template_$file", '');
      die "missing [htmlfile_template_$file] config directive" unless $template;

      rewrite_html_file($treq, $path, $template);
   }
}

=item rewrite_html_file ( TREQ, FILENAME, TEMPLATE )

Rewrites the HTML file FILENAME, inserting the result of running
the template TEMPLATE either above or below the HTML comment
that marks the correct location.

=cut

sub rewrite_html_file
{
   my ($treq, $filename, $template) = @_;

   my $lock = IO::File->new(">>$filename.lck") or die
      "open $filename.lck: $!";
   flock $lock, LOCK_EX or die "flock $filename: $!";

   my $temp = IO::File->new(">$filename.tmp") or die
      "open >$filename.tmp: $!";

   my $in = IO::File->new("<$filename") or die
      "open <$filename: $!";

   while( defined(my $line = <$in>) )
   {
      if ($line =~ /^<!-- NMS insert (above|below) -->\s*$/)
      {
         if ($1 eq 'above')
         {
            $treq->process_template($template, 'html', $temp);
            $temp->print($line);
         }
         else
         {
            $temp->print($line);
            $treq->process_template($template, 'html', $temp);
         }
      }
      else
      {
         $temp->print($line);
      }
   }
 
   unless ($temp->close)
   {
      my $close_err = $!;
      unlink "$filename.tmp";
      die "close $filename.tmp: $close_err";
   }

   $in->close;

   rename "$filename.tmp", $filename or die
      "rename $filename.tmp -> $filename: $!";

   $lock->close;
}

=item missing_html ( TREQ )

Generates the output page in the case where some inputs that
were configured as required have been left blank.

=cut

sub missing_html
{
   my ($treq) = @_;

   my $redirect = $treq->config('missing_fields_redirect');
   if ( $redirect )
   {
      print "Location: $redirect\n\n";
   }
   else
   {
      html_page($treq, $treq->config('missing_template','missing'));
   }
}

=item return_html ( TREQ )

Generates the output page in the case where the email has been
successfully sent.

=cut

sub return_html
{
   my ($treq) = @_;

   my $redirect = $treq->config('redirect');
   if ( defined $redirect )
   {
      print "Location: $redirect\n\n";
   }
   else
   {
      html_page($treq, $treq->config('success_page_template','spage'));
   }
}

=item html_page ( TREQ, TEMPLATE )

Outputs an HTML page using the template TEMPLATE.

=cut

sub html_page
{
   my ($treq, $template) = @_;

   print "Content-type: text/html; charset=@{[ CHARSET ]}\n\n";
   $done_headers = 1;

   $treq->process_template($template, 'html', \*STDOUT);
}

=item error_page ( MESSAGE )

Displays an "S<Application Error>" page, without using a
template since the error may have arisen during template
resolution.

=cut

sub error_page
{
   my ($message) = @_;

   unless ( $done_headers )
   {
      print <<EOERR;
Content-type: text/html; charset=@{[ CHARSET ]}

<?xml version="1.0" encoding="@{[ CHARSET ]}"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Error</title>
  </head>
  <body>
EOERR

      $done_headers = 1;
   }

   if ( DEBUGGING )
   {
      $message = '<p>' . NMStreq->escape_html($message) . '</p>';
   }
   else
   {
      $message = '';
   }

   print <<EOERR;
    <h1>Application Error</h1>
    <p>
     An error has occurred in the program
    </p>
    $message
  </body>
</html>
EOERR
}

=back

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 London Perl Mongers, All rights reserved

=head1 LICENSE

This script is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

