#!/usr/bin/perl -wT
#
# $Id: FormMail.pl,v 1.56 2002-03-13 00:49:36 nickjc Exp $
#

use strict;
use POSIX qw(strftime);
use Socket;                  # for the inet_aton()
use CGI qw(:standard);
use vars qw($DEBUGGING $done_headers);

# PROGRAM INFORMATION
# -------------------
# FormMail.pl $Revision: 1.56 $
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For help on configuration or installation see the
# README file or the POD documentation at the end of
# this file.

# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#
BEGIN { $DEBUGGING    = 1; }
my $emulate_matts_code= 0;
my $secure            = 1;
my $mailprog          = '/usr/lib/sendmail -oi -t';
my @referers          = qw(dave.org.uk 209.207.222.64 localhost);
my @allow_mail_to     = qw(you@your.domain some.one.else@your.domain localhost);
my @recipients        = ();
my @valid_ENV         = qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT);
my $date_fmt          = '%A, %B %d, %Y at %H:%M:%S';
my $style             = '/css/nms.css';
my $send_confirmation_mail = 0;
my $confirmation_text = <<'END_OF_CONFIRMATION';
From: you@your.com
Subject: form submission

Thank you for your form submission.

END_OF_CONFIRMATION
#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)

my $VERSION = ('$Revision: 1.56 $' =~ /(\d+\.\d+)/ ? $1 : '?');

# We don't need file uploads or very large POST requests.
# Annoying locution to shut up 'used only once' warning in older perl

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 1000000;


my $hide_recipient = 0;


# Merge @allow_mail_to and @recipients into a single list of regexps
push @recipients, map { /\@/ ? "^\Q$_\E\$" : "\@\Q$_\E\$" } @allow_mail_to;

# We need finer control over what gets to the browser and the CGI::Carp
# set_message() is not available everywhere :(
# This is basically the same as what CGI::Carp does inside but simplified
# for our purposes here.

BEGIN
{
   sub fatalsToBrowser
   {
      my ( $message ) = @_;

      if ( $main::DEBUGGING )
      {
         $message =~ s/</&lt;/g;
         $message =~ s/>/&gt;/g;
      }
      else
      {
         $message = '';
      }

      my ( $pack, $file, $line, $sub ) = caller(1);
      my ($id ) = $file =~ m%([^/]+)$%;

      return undef if $file =~ /^\(eval/;

      print "Content-Type: text/html\n\n" unless $done_headers;

      print <<EOERR;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
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
EOERR
     die @_;
   };

   $SIG{__DIE__} = \&fatalsToBrowser;
}

if ( $emulate_matts_code )
{
   $secure = 0; # ;-}
}

my $debug_warnings = '';

#  Empty the environment of potentially harmful variables
#  This might cause problems if $mail_prog is a shell script :)

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

$ENV{PATH} = '/bin:/usr/bin';

my %valid_ENV;

@valid_ENV{@valid_ENV} = (1) x @valid_ENV;

my $style_element = $style ?
                    qq%<link rel="stylesheet" type="text/css" href="$style" />%
                    : '';

check_url();

my $date = strftime($date_fmt, localtime);

my (%Config, %Form);
my @Field_Order = parse_form();

check_required();

send_mail();

return_html();

sub check_url {
  my $check_referer = check_referer(referer());

  error('bad_referer') unless $check_referer;
}

sub check_referer
{
  my $check_referer;
  my ($referer) = @_;

  if ($referer && ($referer =~ m!^https?://([^/]*\@)?([^/]+)!i)) {
    my $refHost;

    if (defined($1) and (! $secure)) {
      $refHost = $1;
      chop $refHost;
    } else {
      $refHost = $2;
    }

    foreach my $test_ref (@referers) {
      if ($refHost =~ m|\Q$test_ref\E$|i) {
        $check_referer = 1;
        last;
      }
      elsif ( $secure && $test_ref =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) {
        if ( my $ref_host = inet_aton($refHost) ) {
          $ref_host = unpack "l", $ref_host;
          if ( my $test_ref_ip = inet_aton($test_ref) ) {
            $test_ref_ip = unpack "l", $test_ref_ip;
            if ( $test_ref_ip == $ref_host ) {
              $check_referer = 1;
              last;
            }
          }
        }
      }
    }
  } else {
    $check_referer = $secure ? 0 : 1;
  }

  return $check_referer;
};

sub parse_form {

  my @fields = qw(
                  recipient
                  subject
                  email
                  realname
                  redirect
                  bgcolor
                  background
                  link_color
                  vlink_color
                  text_color
                  alink_color
                  title
                  sort
                  print_config
                  required
                  env_report
                  return_link_title
                  return_link_url
                  print_blank_fields
                  missing_fields_redirect
                 );

  @Config{@fields} = (undef) x @fields; # make it undef rather than empty string

  my @field_order;

  foreach (param()) {
    if (exists $Config{$_}) {
      my $val = strip_nonprintable(param($_));
      next if /redirect$/ and not check_url_valid($val);
      $Config{$_} = $val;
    } else {
      my @vals = map {strip_nonprintable($_)} param($_);
      my $key = strip_nonprintable($_);
      $Form{$key} = join ' ', @vals;
      push @field_order, $key;
    }
  }

  foreach (qw(required env_report print_config)) {
    if ($Config{$_}) {
      $Config{$_} =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
      $Config{$_} =~ s/(\s+)?\n+(\s+)?//g;
      $Config{$_} = [split(/,/, $Config{$_})];
    } else {
      $Config{$_} = [];
    }
  }

  $Config{env_report} = [ grep { $valid_ENV{$_} } @{$Config{env_report}} ];

  return @field_order;
}

sub check_required {
  my ($require, @error);

  defined $Config{subject} or $Config{subject} = '';
  defined $Config{recipient} or $Config{recipient} = '';
  if ($Config{subject} =~ /[\n\r]/m ||
      $Config{recipient} =~ /[\n\r]/m) {
    error('no_recipient');
  }

  if ($Config{recipient}) {
    my @valid;

    foreach (split /,/, $Config{recipient}) {
      next unless check_email($_);

      if (check_recipient($_)) {
        push @valid, $_;
      }
    }

    error('no_recipient') unless scalar @valid;
    $Config{recipient} = join ',', @valid;

  } else {
    my @allow = grep {/\@/} @allow_mail_to;
    if (scalar @allow > 0 and not $emulate_matts_code) {
      $Config{recipient} = $allow[0];
      $hide_recipient = 1;
    } elsif (%Form) {
      error('no_recipient')
    } else {
      error('bad_referer')
    }
  }

  if ($secure and request_method() ne 'POST') {
    error('bad_method');
  }

  foreach (@{$Config{required}}) {
    if ($_ eq 'email' && !check_email($Config{$_})) {
      push(@error, $_);
    } elsif (defined($Config{$_})) {
      push(@error, $_) unless length $Config{$_};
    } else {
      push(@error,$_) unless defined $Form{$_} and length $Form{$_};
    }
  }

  error('missing_fields', @error) if @error;
}

sub check_recipient {
  my ($recip) = @_;

  foreach my $r (@recipients) {
    if ( ($recip =~ /(?:$r)$/) or $emulate_matts_code and ($recip =~ /$r/i) ) {
      return(1);
    }
  }

  warn_bad_email($recip, "script not configured to allow this address");
  return(0);
}

sub return_html {
  my ($key, $sort_order, $sorted_field);

  if ($Config{'redirect'}) {
    print redirect $Config{'redirect'};
  } else {
    print header();
    $done_headers++;

    my $title = escape_html( $Config{'title'} || 'Thank You' );
    my $torecipient = 'to ' . escape_html($Config{'recipient'});
    $torecipient = '' if $hide_recipient;
    my $attr = body_attributes(); # surely this should be done with CSS

    print <<EOHTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
     <title>$title</title>
     $style_element
     <style>
       h1.title {
                   text-align : center;
                }
     </style>
  </head>
  <body $attr>$debug_warnings
    <h1 class="title">$title</h1>
    <p>Below is what you submitted $torecipient on $date</p>
    <p><hr size="1" width="75%" /></p>
EOHTML

    my @sorted_fields;
    if ($Config{'sort'}) {
      if ($Config{'sort'} eq 'alphabetic') {
        @sorted_fields = sort keys %Form;
      } elsif ($Config{'sort'} =~ /^order:.*,.*/) {
        $sort_order = $Config{'sort'};
        $sort_order =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
        $sort_order =~ s/(\s+)?\n+(\s+)?//g;
        $sort_order =~ s/order://;
        @sorted_fields = split(/,/, $sort_order);
      } else {
        @sorted_fields = @Field_Order;
      }
    } else {
      @sorted_fields = @Field_Order;
    }

    foreach (@sorted_fields) {
      if ($Config{print_blank_fields} || $Form{$_} !~ /^\s*$/) {
        print '<p><b>', escape_html($_), ':</b> ',
                        escape_html($Form{$_}), "</p>\n";
      }
    }

    print qq{<p><hr size="1" width="75%" /></p>\n};

    if ($Config{return_link_url} && $Config{return_link_title}) {
      print "<ul>\n";
      print '<li><a href="', escape_html($Config{return_link_url}),
         '">', escape_html($Config{return_link_title}), "</a>\n";
      print "</li>\n</ul>\n";
    }

    print <<END_HTML_FOOTER;
        <hr size="1" width="75%" />
        <p align="center">
           <font size="-1">
             <a href="http://nms-cgi.sourceforge.net/">FormMail</a>
             &copy; 2001  London Perl Mongers
           </font>
        </p>
        </body>
       </html>
END_HTML_FOOTER
  }
}

sub send_mail {

  my $dashes = '-' x 75;

  my $realname = $Config{realname};
  if (defined $realname) {
    $realname = ' (' . cleanup_realname($realname) . ')';
  } else {
    $realname = $Config{realname} = '';
  }

  my $subject = $Config{subject} || 'WWW Form Submission';

  my $email = $Config{email};
  unless (defined $email and check_email($email)) {
    $email = 'nobody';
  }

  if ("$Config{recipient}$email$realname$subject" =~ /\r|\n/) {
    die 'multiline variable in mail header, unsafe to continue';
  }

  my $xheader = '';
  if ( $secure and defined (my $addr = remote_addr()) ) {
    $addr =~ /^([\d\.]+)$/ or die "bad remote addr [$addr]";
    $xheader = "X-HTTP-Client: [$1]\n"
             . "X-Generated-By: NMS FormMail.pl v$VERSION\n";
  }

  if ( $send_confirmation_mail ) {
    open(CMAIL,"|$mailprog")
      || die "Can't open $mailprog\n";
    print CMAIL $xheader, "To: $email$realname\n$confirmation_text";
    close CMAIL;
  }

  open(MAIL,"|$mailprog")
    || die "Can't open $mailprog\n";

  print MAIL $xheader, <<EOMAIL;
To: $Config{recipient}
From: $email$realname
Subject: $subject

Below is the result of your feedback form.  It was submitted by
$Config{realname} (${\( $Config{email}||'' )}) on $date
$dashes


EOMAIL

  if ($Config{print_config}) {
    foreach (@{$Config{print_config}}) {
      print MAIL "$_: $Config{$_}\n\n" if $Config{$_};
    }
  }

  my @sorted_keys;
  if ($Config{'sort'}) {
    if ($Config{'sort'} eq 'alphabetic') {
      @sorted_keys = sort keys %Form;
    } elsif ($Config{'sort'} =~ /^order:.*,.*/) {
      $Config{'sort'} =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
      $Config{'sort'} =~ s/(\s+)?\n+(\s+)?//g;
      $Config{'sort'} =~ s/order://;
      @sorted_keys = split(/,/, $Config{'sort'});
    } else {
      @sorted_keys = @Field_Order;
    }
  } else {
    @sorted_keys = @Field_Order;
  }

  foreach (@sorted_keys) {
    if ($Config{'print_blank_fields'} || $Form{$_} !~ /^\s*$/) {
      print MAIL "$_: $Form{$_}\n\n";
    }
  }

  print MAIL "$dashes\n\n";

  foreach (@{$Config{env_report}}) {
    print MAIL "$_: ", strip_nonprintable($ENV{$_}), "\n" if $ENV{$_};
  }

  close (MAIL) || die "close mailprog: \$?=$?,\$!=$!";
}

sub cleanup_realname {
  my ($realname) = @_;

  return '' unless defined $realname;

  $realname =~ s#\s+# #g;

  if ($secure) {
    # Allow no unusual characters and impose a length limit. We
    # need to allow extented ASCII characters because they can
    # occur in non-English names.
    $realname =~ tr# a-zA-Z0-9_\-,./'\200-377##dc;
    $realname = substr $realname, 0, 128;
  } else {
    # Be as generous as possible without opening any known or
    # strongly suspected relaying holes.
    $realname =~ tr#()\\#{}/#;
  }

  return $realname;
}

sub check_email {
  my ($email) = @_;

  return 0 if $email =~ /^\s*$/;

  unless ($email =~ /^(.+)\@([a-z0-9_\.\-\[\]]+)$/is) {
    warn_bad_email($email, "malformed email address");
    return 0;
  }
  my ($user, $host) = ($1, $2);

  if ($host =~ /\.\./) {
    warn_bad_email($email, "hostname $host contains '..'");
    return 0;
  } elsif ($host =~ /^\./) {
    warn_bad_email($email, "hostname $host starts with '.'");
    return 0;
  } elsif ($host =~ /\.$/) {
    warn_bad_email($email, "hostname $host ends with '.'");
    return 0;
  }

  if ($emulate_matts_code and not $secure) {
    # Be as generous as possible without opening any known or strongly
    # suspected relaying holes.
    if ($user =~ /([^a-z0-9_\-\.\#\$\&\'\*\+\/\=\?\^\`\{\|\}\~\200-\377])/i) {
      my $c = sprintf '%s (ASCII 0x%.2X)', $1, unpack('C',$1);
      warn_bad_email($email, "bad character $c");
      return 0;
    } else {
      return 1;
    }
  } else {
    # Only allow reasonable email addresses.

    if ($user =~ /([^a-z0-9_\-\.\*\+\=])/i) {
      my $c = sprintf '%s (ASCII 0x%.2X)', $1, unpack('C',$1);
      warn_bad_email($email, "bad character $c");
      return 0;
    } elsif (length $user > 100) {
      warn_bad_email($email, "username part too long");
      return 0;
    }

    if (length $host > 100) {
      warn_bad_email($email, "hostname too long");
      return 0;
    }
    return 1 if $host =~ /^\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\]$/;
    return 1 if $host =~ /^[a-z0-9\-\.]+$/i;

    warn_bad_email($email, "invalid hostname $host");
    return 0;
  }

  # not reached
  return 0;
}

sub warn_bad_email {
  my ($email, $whybad) = @_;

  $debug_warnings .= <<END if $DEBUGGING;
<p>
<font color="red">Warning:</font>
The email address <tt>${\( escape_html($email) )}</tt> was rejected
for the following reason: ${\( escape_html($whybad) )}
</p>
END
}

# check the validity of a URL.

sub check_url_valid {
  my $url = shift;

  # allow relative URLs with sane values
  return 1 if $url =~ m#^[a-z0-9_\-\.\,\+\/]+$#i;

  $url =~ m< ^ (?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?
               (?: /  [\w\-.!~*'(|);/\@+\$,%#]*   )?
               (?: \? [\w\-.!~*'(|);/\@&=+\$,%#]* )?
             $
           >x ? 1 : 0;
}

sub strip_nonprintable {
  my $text = shift;
  return '' unless defined $text;
  $text=~ tr#\011\012\040-\176\200-\377##dc;
  return $text;
}

sub body_attributes {
  my %attrs = (bgcolor     => 'bgcolor',
               background  => 'background',
               link_color  => 'link',
               vlink_color => 'vlink',
               alink_color => 'alink',
               text_color  => 'text');

  my $attr = '';

  foreach (keys %attrs) {
    next unless $Config{$_};
    if (/color$/) {
      next unless $Config{$_} =~ /^(?:#[0-9a-z]{6}|[\w\-]{2,50})$/i;
    } elsif ($_ eq 'background') {
      next unless check_url_valid($Config{$_});
    } else {
      die "no check defined for body attribute [$_]";
    }
    $attr .= qq( $attrs{$_}=") . escape_html($Config{$_}) . '"' if $Config{$_};
  }

  return $attr;
}

sub error {
  my ($error, @error_fields) = @_;
  my ($host, $missing_field, $missing_field_list);

  my ($title, $heading,$error_body);

  if ($error eq 'bad_referer') {
    my $referer = referer();
    $referer = '' if ! defined( $referer );
    my $escaped_referer = escape_html($referer);

    if ( $referer =~ m|^https?://([\w\.]+)|i) {
       $host = $1;
       $title = 'Bad Referrer - Access Denied';
       $heading = $title;
       $error_body =<<EOBODY;
<p>
  The form attempting to use FormMail resides at <tt>$escaped_referer</tt>,
  which is not allowed to access this program.
</p>
<p>
  If you are attempting to configure FormMail to run with this form,
  you need to add the following to \@referers, explained in detail in the
  README file.
</p>
<p>
  Add <tt>'$host'</tt> to your <tt><b>\@referers</b></tt> array.
</p>
EOBODY
    }
    else {
      $title = 'Formail';
      $heading = $title;
      $error_body = '<p><b>Badness!</b></p>';
    }
 }
 elsif ($error eq 'bad_method') {
   my $ref = referer();
   if (defined $ref and $ref =~ m#^https?://#) {
     $ref = 'at <tt>' . escape_html($ref) . '</tt>';
   } else {
     $ref = 'that you just filled in';
   }
   $title = 'Error: GET request';
   $heading = $title;
   $error_body =<<EOBODY;
<p>
  The form $ref fails to specify the POST method, so it would not
  be correct for this script to take any action in response to
  your request.
</p>
<p>
  If you are attempting to configure this form to run with FormMail,
  you need to set the request method to POST in the opening form tag,
  like this:
  <tt>&lt;form action=&quot;/cgi-bin/FormMail.pl&quot; method=&quot;POST&quot;&gt;</tt>
</p>
EOBODY
 } elsif ($error eq 'no_recipient') {

   my $recipient = escape_html($Config{recipient});
   $title = 'Error: Bad or Missing Recipient';
   $heading = $title;
   $error_body =<<EOBODY;
<p>
  There was no recipient or an invalid recipient specified in the
  data sent to FormMail. Please make sure you have filled in the
  <tt>recipient</tt> form field with an e-mail address that has
  been configured in <tt>\@recipients</tt> or <tt>\@allow_mail_to</tt>. 
  More information on filling in <tt>recipient/allow_mail_to</tt> 
  form fields and variables can be found in the README file.
</p>
<hr size="1" />
<p>
 The recipient was: [ $recipient ]
</p>
EOBODY
  }
  elsif ( $error eq 'missing_fields' ) {
     if ( $Config{'missing_fields_redirect'} ) {
        print  redirect($Config{'missing_fields_redirect'});
        exit;
      }
      else {
        my $missing_field_list = join '',
                                 map { '<li>' . escape_html($_) . "</li>\n" }
                                 @error_fields;
        $title = 'Error: Blank Fields';
        $heading = $title;
        $error_body =<<EOBODY;
<p>
    The following fields were left blank in your submission form:
</p>
<div class="c2">
   <ul>
     $missing_field_list
   </ul>
</div>
<p>
    These fields must be filled in before you can successfully
    submit the form.
</p>

<p>
    Please use your back button to return to the form and
    try again.
</p>
EOBODY
     }
  }

  print header();
  $done_headers++;
  print <<END_ERROR_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
    $style_element
    <style type="text/css">
    <!--
       body {
              background-color: #FFFFFF;
              color: #000000;
             }
       p.c2 {
              font-size: 80%;
              text-align: center;
            }
       th.c1 {
               font-size: 143%;
             }
       p.c3 {font-size: 80%; text-align: center}
       div.c2 {margin-left: 2em}
     -->
    </style>
  </head>
  <body>$debug_warnings
    <table border="0" width="600" bgcolor="#9C9C9C" align="center" summary="">
      <tr>
        <th class="c1">$heading</th>
      </tr>
    </table>
    <table border="0" width="600" bgcolor="#CFCFCF">
      <tr>
        <td>
          $error_body
          <hr size="1" />
          <p class="c3">
            <a href="http://nms-cgi.sourceforge.net/">FormMail</a>
            &copy; 2001 London Perl Mongers
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
END_ERROR_HTML
   exit;
}

use vars qw(%escape_html_map);

BEGIN
{
   %escape_html_map = ( '&' => '&amp;',
                        '<' => '&lt;',
                        '>' => '&gt;',
                        '"' => '&quot;',
                        "'" => '&#39;',
                      );
}

sub escape_html {
  my $str = shift;

  my $chars = join '', keys %escape_html_map;

  if (defined($str))
  {
    $str =~ s/([\Q$chars\E])/$escape_html_map{$1}/g;
  }

  return $str;
}

__END__

=head1 COPYRIGHT

FormMail $Revision: 1.56 $
Copyright 2001 London Perl Mongers, All rights reserved

=head1 LICENSE

This script is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=head1 URL

The most up to date version of this script is available from the nms
script archive at  E<lt>http://nms-cgi.sourceforge.net/E<gt>

=head1 SUMMARY

formmail is a script which allows you to receive the results of an
HTML form submission via an email message.

=head1 FILES

In this distribution, you will find three files:

=over

=item FormMail.pl

The main Perl script

=item README

This documentation. Instructions on how to install and use
formmail

=item MANIFEST

List of files

=back


=head1 CONFIGURATION

There are a number of variables that you can change in formmail.pl which
alter the way that the program works.

=over

=item $DEBUGGING

This should be set to 1 whilst you are installing
and testing the script. Once the script is live you
should change it to 0. When set to 1, errors will
be output to the browser. This is a security risk and
should not be used when the script is live.

=item $emulate_matts_code

When this variable is set to a true value (e.g. 1)
formmail will work in exactly the same way as its
counterpart at Matt's Script Archive. If it is set
to a false value (e.g. 0) then more advanced features
are switched on. We do not recommend changing this
variable to 1, as the resulting drop in security
may leave your formmail open to use as a SPAM relay.

=item $secure

When this variable is set to a true value (e.g. 1)
many additional security features are turned on.  We
do not recommend changing this variable to 0, as the
resulting drop in security may leave your formmail
open to use as a SPAM relay.

=item $mailprog

The system command that the script should invoke to
send an outgoing email. This should be the full path
to a program that will read a message from STDIN and
determine the list of message recipients from the
message headers. Any switches that the program
requires should be provided here. Your hosting
provider or system administrator should be able to
tell you what to set this variable to.

=item @referers

A list of referring hosts. This should be a list of
the names or IP addresses of all the systems that
will host HTML forms that refer to this formmail
script. Only these hosts will be allowed to use the
formmail script. This is needed to prevent others
from hijacking your formmail script for their own use
by linking to it from their own HTML forms.

=item @allow_mail_to

A list of the email addresses that formmail can send
email to. The elements of this list can be either
simple email addresses (like 'you@your.domain') or
domain names (like 'your.domain'). If it's a domain
name then *any* address at the domain will be allowed.

Example: to allow mail to be sent to 'you@your.domain'
or any address at the host 'mail.your.domain', you
would set:

C<@allow_mail_to = qw(you@your.domain mail.your.domain);>

=item @recipients

A list of Perl regular expression patterns that
determine who the script will allow mail to be sent
to in addition to those set in @allow_mail_to. This is
present only for compatibility with the original
formmail script.  We strongly advise against having
anything in @recipients as it's easy to make a mistake
with the regular expression syntax and turn your
formmail into an open SPAM relay.

There is an implicit $ at the end of the regular
expression, but you need to include the ^ if you want
it anchored at the start.  Note also that since '.' is
a regular expression metacharacter, you'll need to
escape it before using it in domain names.

If that last paragraph makes no sense to you then
please don't put anything in @recipients, stick to
using the less error prone @allow_mail_to.

=item @valid_ENV

A list of all the environment variables that you want
to be able to include in the email. See L<env_report|/item_env_report>
below.

=item $date_fmt   

The format that the date will be displayed in. This
is a string that contains a number of different 'tags'.
Each tag consists of a % character followed by a letter.
Each tag represents one way of displaying a particular
part of the date or time. Here are some common tags:

 %Y - four digit year (2002)
 %y - two digit year (02)
 %m - month of the year (01 to 12)
 %b - short month name (Jan to Dec)
 %B - long month name (January to December)
 %d - day of the month (01 to 31)
 %a - short day name (Sun to Sat)
 %A - long day name (Sunday to Saturday)
 %H - hour in 24 hour clock (00 to 23)
 %I - hour in 12 hour clock (01 to 12)
 %p - AM or PM
 %M - minutes (00 to 59)
 %S - seconds (00 to 59)

=item $style

This is the URL of a CSS stylesheet which will be
used for script generated messages.  This probably
wants to be the same as the one that you use for all
the other pages.  This should be a local absolute URI
fragment.  Set $style to '0' or the emtpy string if
you do not want to use style sheets.

=item $send_confirmation_mail

If this flag is set to 1 then an additional email
will be sent to the person who submitted the
form.

B<CAUTION:> with this feature turned on it's
possible for someone to put someone else's email
address in the form and submit it 5000 times,
causing this script to send a flood of email to a
third party.  This third party is likely to blame
you for the email flood attack.

=item $confirmation_text

The header and body of the confirmation email
sent to the person who submits the form, if the
$send_confirmation_mail flag is set. We use a
Perl 'here document' to allow us to configure it
as a single block of text in the script. In the
example below, everything between the lines

  my $confirmation_text = E<lt>E<lt>'END_OF_CONFIRMATION';

and

  END_OF_CONFIRMATION

is treated as part of the email. Everything
before the first blank line is taken as part of
the email header, and everything after the first
blank line is the body of the email.

  my $confirmation_text = <<'END_OF_CONFIRMATION';
  From: you@your.com
  Subject: form submission

  Thankyou for your form submission.

  END_OF_CONFIRMATION

=back

=head1 INSTALLATION

Formmail is installed simply by copying the file FormMail.pl into your
cgi-bin directory. If you don't know where your cgi-bin directory is, then
please ask your system administrator.

You may need to rename FormMail.pl to FormMail.cgi. Again, your system
administrator will know if this is the case.

You will probably need to turn on execute permissions to the file. You can
do this by running the command "chmod +x FormMail.pl" from your command
line. If you don't have command line access to your web server then there
will probably be an equivalent function in your file transfer program.

To make use of it, you need to write an HTML form that refers to the
FormMail script. Here's an example which will send mail to the address
'feedback@your.domain' when someone submits the form:

  <form method="POST" action="http://your.domain/cgi-bin/FormMail.pl">
    <input type="hidden" name="recipient" value="feedback@your.domain" />
    <input type="text" name="feedback" /><br />
    Please enter your comments<br />
    <input type="submit" />
  </form>

=head1 FORM CONFIGURATION

See how the hidden 'recipient' input in the example above told formmail who
to send the mail to? This is how almost all of formmail's configuration
works. Here's the full list of things you can set with hidden form inputs:

=over

=item recipient  

The email address to which the form submission
should be sent. If you would like it copied to
more than one recipient then you can separate
multiple email addresses with commas, for
example:

 <input type="hidden" name="recipient"
        value="you@your.domain,me@your.domain" />

If you leave the 'recipient' field out of the
form, formmail will send to the first address
listed in the @allow_mail_to configuration
variable (see above).  This allows you to avoid
putting your email address in the form, which
might be desirable if you're concerned about
address harvesters collecting it and sending
you SPAM. This feature is disabled if the
emulate_matts_code configuration variable is
set to 0.

=item subject

The subject line for the email. For example:

 <input type="hidden" name="subject"
        value="From the feedback form" />

=item redirect

If this value is present it should be a URL, and
the user will be redirected there after a
successful form submission.  For example:

 <input type="hidden" name="redirect"
        value="http://www.your.domain/foo.html" />

If you don't specify a redirect URL then instead
of redirecting formmail will generate a success
page telling the user that their submission was
successful.

=item bgcolor

The background color for the success page.

=item background

The URL of the background image for the success
page.

=item text_color

The  text color for the success page.

=item link_color

The link color for the success page.

=item vlink_color

The vlink color for the success page.

=item alink_color

The alink color for the success page.

=item title

The title for the success page.

=item return_link_url

The target URL for a link at the end of the
success page. This is normally used to provide
a link from the success page back to your main
page or back to the page with the form on. For
example:

 <input type="hidden" name="return_link_url"
        value="/home.html" />

=item return_link_title

The label for the return link.  For example:

 <input type="hidden" name="return_link_title"
        value="Back to my home page" />

=item sort

This sets the order in which the submitted form
inputs will appear in the email and on the
success page.  It can be the string 'alphabetic'
for alphabetic order, or the string "order:"
followed by a comma separated list of the input
names, for example:

 <input type="hidden" name="sort"
        value="order:name,email,age,comments">

=item print_config

This is mainly used for debugging, and if set it
causes formmail to include a dump of the
specified configuration settings in the email.

For example:

 <input type="hidden" name="print_config"
        value="title,sort">

... will include whatever values you set for
title' and 'sort' (if any) in the email.

=item required

This is a list of fields that the user must fill
in before they submit the form. If they leave
any of these fields blank then they will be sent
back to the form to try again.  For example:

 <input type="hidden" name="required"
        value="name,comments">

=item missing_fields_redirect

If this is set, it must be a URL, and the user
will be redirected there if any of the fields
listed in 'required' are left blank. Use this if
you want finer control over the the error that
the user see's if they miss out a field.

=item env_report

This is a list of the CGI environment variables
that should be included in the email.  This is
useful for recording things like the IP address
of the user in the email. Any environment
variables that you want to use in 'env_report' in
any of your forms will need to be in the
valid_ENV configuration variable described
above.

=item print_blank_fields

If this is set then fields that the user left
blank will be included in the email.  Normally,
blank fields are suppressed to save space.

=back

As well as all these hidden inputs, there are a couple of non-hidden
inputs which get special treatment:

=over

=item email

If one of the things you're asking the user to fill in is their
email address and you call that input 'email', formmail will use
it as the address part of the sender's email address in the
email.

=item realname

If one of the things you're asking the user to fill in is their
full name and you call that input 'realname', formmail will use
it as the name part of the sender's email address in the email.

=back

=head1 SUPPORT

For support of this script please email:

nms-cgi-support@lists.sourceforge.net

=head1 CHANGELOG

 $Log: not supported by cvs2svn $
 Revision 1.55  2002/03/12 23:58:57  nickjc
 minor POD tweak for its new context

 Revision 1.54  2002/03/12 23:46:17  nickjc
 * moved the POD to the end, and put the changelog inside the POD

 Revision 1.53  2002/03/12 19:43:02  nickjc
 * Duplicate input name display bug fix.
 * Better diagnostics when $mailprog exits nonzero.
 * Replaced out of date hardcoded version numbers with
   CVS Revision tags.

 Revision 1.52  2002/03/12 00:41:04  nickjc
 * Allow the value '0' in a required field

 Revision 1.51  2002/03/10 01:05:11  nickjc
 * tightened weak checking on the realname part of email addresses
 * added a test for that

 Revision 1.50  2002/03/07 23:00:05  nickjc
 * eliminated the remaining path for nonprintable characters to get into
   the email body.
 * added a test for that.

 Revision 1.49  2002/03/06 14:48:53  proub
 Inserted README text, in POD format.
 Moved Log messages to the end of the file.

 Revision 1.48  2002/02/28 21:14:10  nickjc
 * warning fix
 * fixed print_blank_fields bug

 Revision 1.47  2002/02/28 08:51:05  nickjc
 Allowed pathless URLs with query strings in check_url_valid

 Revision 1.46  2002/02/27 17:51:20  davorg
 typo

 Revision 1.45  2002/02/27 09:04:28  gellyfish
 * Added question about simple search and PDF to FAQ
 * Suppressed output of headers in fatalsToBrowser if $done_headers
 * Suppressed output of '<link rel...' if not $style
 * DOCTYPE in fatalsToBrowser
 * moved redirects until after possible cause of failure
 * some small XHTML fixes

 Revision 1.44  2002/02/26 22:30:49  proub
 Updated no-recipients-defined error message -- we now suggest both
 @allow_mail_to and @recipients as places to add valid emails.

 Revision 1.43  2002/02/26 22:13:20  proub
 Removed commented-out unit-tests (unit tests now live in /tests/formail)

 Revision 1.42  2002/02/26 08:50:15  nickjc
 Hide the recipient when it comes directly from @allow_mail_to and
 isn't in $recipient, to prevent SPAM harvesting

 Revision 1.41  2002/02/24 21:54:41  nickjc
 * DOCTYPE declarations on all output pages

 Revision 1.40  2002/02/22 12:08:30  nickjc
 * removed stray ';' from output HTML

 Revision 1.39  2002/02/21 09:17:29  gellyfish
 Stylesheet elements will not be added if $style is empty

 Revision 1.38  2002/02/14 08:45:04  nickjc
 * fixed silly error in body attribute checking

 Revision 1.37  2002/02/14 01:33:20  proub
 Updated unit tests to reflect new check_email behavior (specifically,
   disallowing % in names when emulate_matts_code is in effect)

 Revision 1.36  2002/02/13 23:36:46  nickjc
 (This is the log message for the previous checkin)
 * reworked check_email
 * made it produce debugging output when rejecting recipients
 * sort order: doc correction
 * doc typo
 * added a way to keep the email address out of the form (user request)
 * POST_MAX and DISABLE_UPLOADS stuff
 * restricted the body attribute inputs to sane values
 * squished a couple of warnings
 * allowed relative URLs in check_url_valid

 Revision 1.35  2002/02/13 23:33:52  nickjc
 *** empty log message ***

 Revision 1.34  2002/02/03 21:32:47  dragonoe
 Indent configuration variables so they are all aligned. Made sure that it fits in 80 characters.

 Revision 1.33  2002/02/03 20:47:06  dragonoe
 Added header to script after the cvs log.

 Revision 1.32  2002/01/31 17:26:43  proub
 no longer accepting email addresses with % characters in the name portion
   (to avoid spoofing sendmail addressing on some systems) - revert
   to old behavior when $emulate_matts_code is true
 when $emulate_matts_code is true, verify email addresses in a
   case-insensitive manner.

 Revision 1.31  2002/01/30 19:04:45  proub
 now properly handling referer URLs involving authentication info (e.g.
   http://www.dave.org.uk@actual.referer.com, or
   http://someuser@dave.org.uk)
 cleared up warnings when no referer is present

 Revision 1.30  2002/01/29 00:05:01  nickjc
 * typo
 * added X-HTTP-Client header to the confirmation email.

 Revision 1.29  2002/01/27 16:00:04  nickjc
 allow_mail_to: explicit $ rather than depend on the one that's added
 unless $emulate_matts_code.

 Revision 1.28  2002/01/27 14:45:11  nickjc
 * re-wrote README
 * added @allow_mail_to config option

 Revision 1.27  2002/01/27 13:59:08  gellyfish
 Issues from  http://www.monkeys.com/anti-spam/formmail-advisory.pdf
 * Left anchored regex to check referer
 * If $secure and no referer supplied then croak

 Revision 1.26  2002/01/21 21:58:00  gellyfish
 Checkbox fix from Chris Benson

 Revision 1.25  2002/01/20 14:52:02  nickjc
 added a warning about the risks of turning on the confirmation email

 Revision 1.24  2002/01/19 23:44:28  nickjc
 Added the option to send a confirmation email to the submitter, in
 response to a user request.

 Revision 1.23  2002/01/14 08:54:10  nickjc
 Took out a warn statement left over from a debugging session

 Revision 1.22  2002/01/04 08:55:31  nickjc
 tightened valid url regex

 Revision 1.21  2002/01/02 21:21:45  gellyfish
 Altered regex in check_valid_url to deal with server port number

 Revision 1.20  2002/01/01 01:22:27  nickjc
 error message fix from Paul Sharpe

 Revision 1.19  2001/12/15 22:42:00  nickjc
 * Added a validity check on the redirect URLs
 * Moved the nonprintable character striping code to a sub

 Revision 1.18  2001/12/09 22:31:22  nickjc
 * anchor recipient checks at end (as per README) unless $emulate_matts_code
 * move repeated check_email call out one loop level

 Revision 1.17  2001/12/05 14:28:24  nickjc
 * Don't do things on GET if $secure
 * Eliminate some warnings in send_email
 * Restrict realname slightly if $secure

 Revision 1.16  2001/12/04 08:55:03  nickjc
 stricter check_email if $secure

 Revision 1.15  2001/12/01 19:45:21  gellyfish
 * Tested everything with 5.004.04
 * Replaced the CGI::Carp with local variant

 Revision 1.14  2001/11/29 14:18:38  nickjc
 * Removed CGI::Carp::set_message (doesn't work under 5.00404)
 * Added some very minimal input filtering

 Revision 1.13  2001/11/26 17:36:43  nickjc
 * Allow domain names without '.' so that user@localhost works.
 * Don't overwrite $Config{recipient} with the empty string before
   displaying it on the error page.
 * Fixed a couple of minor errors.

 Revision 1.12  2001/11/26 13:40:05  nickjc
 Added \Q \E around variables in regexps where metacharacters in the
 variables shouldn't be interpreted by the regex engine.

 Revision 1.11  2001/11/26 09:20:20  gellyfish
 Tidied up the error() subroutine

 Revision 1.10  2001/11/25 16:07:40  gellyfish
 A couple of nits

 Revision 1.9  2001/11/25 11:39:38  gellyfish
 * add missing use vars qw($DEBUGGING) from most of the files
 * sundry other compilation failures

 Revision 1.8  2001/11/24 11:59:58  gellyfish
 * documented strfime date formats is various places
 * added more %ENV cleanup
 * spread more XHTML goodness and CSS stylesheet
 * generalization in wwwadmin.pl
 * sundry tinkering

 Revision 1.7  2001/11/23 13:57:36  nickjc
 * added -T switch
 * Escape metachars in input variables when outputing HTML

 Revision 1.6  2001/11/20 17:39:20  nickjc
 * Fixed a problem with %Config initialisation
 * Reduced the scope for SPAM relaying

 Revision 1.5  2001/11/14 09:10:11  gellyfish
 Added extra check on the referer.

 Revision 1.4  2001/11/13 21:40:46  gellyfish
 Changed all of the sub calls to be without '&'

 Revision 1.3  2001/11/13 20:35:14  gellyfish
 Added the CGI::Carp workaround

 Revision 1.2  2001/11/11 17:55:27  davorg
 Small amount of post-import tidying :)

 Revision 1.1.1.1  2001/11/11 16:48:47  davorg
 Initial import

=cut

