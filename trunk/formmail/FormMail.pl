#!/usr/bin/perl -wT
#
# $Id: FormMail.pl,v 1.12 2001-11-26 13:40:05 nickjc Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.11  2001/11/26 09:20:20  gellyfish
# Tidied up the error() subroutine
#
# Revision 1.10  2001/11/25 16:07:40  gellyfish
# A couple of nits
#
# Revision 1.9  2001/11/25 11:39:38  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.8  2001/11/24 11:59:58  gellyfish
# * documented strfime date formats is various places
# * added more %ENV cleanup
# * spread more XHTML goodness and CSS stylesheet
# * generalization in wwwadmin.pl
# * sundry tinkering
#
# Revision 1.7  2001/11/23 13:57:36  nickjc
# * added -T switch
# * Escape metachars in input variables when outputing HTML
#
# Revision 1.6  2001/11/20 17:39:20  nickjc
# * Fixed a problem with %Config initialisation
# * Reduced the scope for SPAM relaying
#
# Revision 1.5  2001/11/14 09:10:11  gellyfish
# Added extra check on the referer.
#
# Revision 1.4  2001/11/13 21:40:46  gellyfish
# Changed all of the sub calls to be without '&'
#
# Revision 1.3  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:47  davorg
# Initial import
#

use strict;
use POSIX qw(strftime);
use Socket;                  # for the inet_aton()
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser set_message);
use vars qw($DEBUGGING);

# Configuration

#
# $DEBUGGING must be set in a BEGIN block in order to have it be set before
# the program is fully compiled.
# This should almost certainly be set to 0 when the program is 'live'
#

BEGIN
{
   $DEBUGGING = 1;
}
   

# 
# Emulate as far as possible the original behaviour of the original
# beware that turning this on will lower the level of security.

my $emulate_matts_code = 0;


# If $secure is set to 1 then a set of security checks which are potentially
# incompatible with the original FormMail will kick in. 
# setting $emulate_matts_code will cause this to be ignored.

my $secure = 1;


# the mailer that should be used to send the mail message.
# this should be the full path to a program that will read a message
# from STDIN.  Any switches that the program requires should be provided here

my $mailprog = '/usr/lib/sendmail -oi -t';

# a list of referring hosts.  If $secure is set then if these are IP numbers
# the IP of the referring host will be determined and checked against this
# (this is to encourage people not to remove the check when their web host
# might have a large number of names)

my @referers = qw(dave.org.uk 209.207.222.64 localhost);

my @recipients = @referers;

my @valid_ENV = qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT);

# $date_fmt describes the format of the date that will output - the
# replacement parameters use here are:
#
# %A - the full name of the weekday according to the current locale
# %B - the full name of the month according to the current local
# %d - the day of the month as a number
# %Y - the year as a number including the century
# %H - the hour as number in the 24 hour clock
# %M - the mimute as a number
# %S - the seconds as a number
#

my $date_fmt = '%A, %B %d, %Y at %H:%M:%S';

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

# End configuration

if ( $emulate_matts_code )
{
   $secure = 0; # ;-}
}

BEGIN
{
   my $error_message = sub {
                             my ($message ) = @_;
                             print "<h1>It's all gone horribly wrong</h1>";
                             print $message if $DEBUGGING;
                            };
  set_message($error_message);
}   

#  Empty the environment of potentially harmful variables
#  This might cause problems if $mail_prog is a shell script :)

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

$ENV{PATH} = '/bin:/usr/bin';

my %valid_ENV;

@valid_ENV{@valid_ENV} = (1) x @valid_ENV;

check_url();

my $date = strftime($date_fmt, localtime);

my (%Config, %Form);
my @Field_Order = parse_form();

check_required();

send_mail();

return_html();

sub check_url {
  my $check_referer;

  if (my $referer = referer()) {
    foreach my $test_ref (@referers) {
      if ($referer =~ m|https?://([^/]*)\Q$test_ref\E|i) {
	$check_referer = 1;
	last;
      }
      elsif ( $secure && $test_ref =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ ) {
        if ( $referer =~ m|https?://([^/]+)| ) {
          if ( my $ref_host = inet_aton($1) ) {
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
    }
  } else {
    $check_referer = 1;
  }
  error('bad_referer') unless $check_referer;
}

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

  @Config{@fields} = () x @fields; # make it undef rather than empty string

  my @field_order;

  foreach (param()) {
    if (exists $Config{$_}) {
      $Config{$_} = param($_);
    } else {
      my @vals = param($_);
      $Form{$_} = @vals == 1 ? $vals[0] : [@vals];
      push @field_order, $_;
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

  if ($Config{subject} =~ /[\n\r]/m ||
      $Config{recipient} =~ /[\n\r]/m) {
    error('no_recipient');
  }

  if ($Config{recipient}) {
    my @valid;

    foreach (split /,/, $Config{recipient}) {
      foreach my $r (@recipients) {
	if (/$r/ && check_email($_)) {
	  push @valid, $_;
	  last;
	}
      }
    }
    $Config{recipient} = join ',', @valid;

    error('no_recipient') unless $Config{recipient};
  } else {
    if (%Form) {
      error('no_recipient')
    } else {
      error('bad_referer')
    }
  }

  foreach (@{$Config{required}}) {
    if ($_ eq 'email' && !check_email($Config{$_})) {
      push(@error, $_);
    } elsif (defined($Config{$_})) {
      push(@error, $_) unless $Config{$_};
    } else {
      push(@error,$_) unless $Form{$_};
    }
  }

  error('missing_fields', @error) if @error;
}

sub return_html {
  my ($key, $sort_order, $sorted_field);

  if ($Config{redirect}) {
    print redirect $Config{redirect};
  } else {
    print header;

    my $title = escape_html( $Config{title} || 'Thank You' );
    my $recipient = escape_html($Config{recipient});
    my $attr = body_attributes(); # surely this should be done with CSS

    print <<EOHTML;
<html>
  <head>
     <title>$title</title>
     <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body $attr>
    <h1 align="center">$title</h1>
    <p>Below is what you submitted to $recipient on $date</p>
    <p><hr size="1" width="75%" /></p>
EOHTML

    my @sorted_fields;
    if ($Config{sort}) {
      if ($Config{sort} eq 'alphabetic') {
	@sorted_fields = sort keys %Form;
      } elsif ($Config{sort} =~ /^order:.*,.*/) {
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
      if ($Config{print_blank_fields} || $Form{$_}) {
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

  if ("$Config{recipient}$Config{email}$Config{realname}$Config{subject}" =~ /\r|\n/) {
    die 'multiline variable in mail header, unsafe to continue';
  }

  my $subject = $Config{subject} || 'WWW Form Submission';

  open(MAIL,"|$mailprog")
    || die "Can't open sendmail\n";

  print MAIL <<EOMAIL;
To: $Config{recipient}
From: $Config{email} ($Config{realname})
Subject: $subject

Below is the result of your feedback form.  It was submitted by
$Config{realname} ($Config{email}) on $date
$dashes


EOMAIL

  if ($Config{print_config}) {
    foreach (@{$Config{print_config}}) {
      print MAIL "$_: $Config{$_}\n\n" if $Config{$_};
    }
  }

  my @sorted_keys;
  if ($Config{sort}) {
    if ($Config{sort} eq 'alphabetic') {
      @sorted_keys = sort keys %Form;
    } elsif ($Config{sort} =~ /^order:.*,.*/) {
      $Config{sort} =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
      $Config{sort} =~ s/(\s+)?\n+(\s+)?//g;
      $Config{sort} =~ s/order://;
      @sorted_keys = split(/,/, $Config{sort});
    } else {
      @sorted_keys = @Field_Order;
    }
  } else {
    @sorted_keys = @Field_Order;
  }

  foreach (@sorted_keys) {
    if ($Config{'print_blank_fields'} || defined $Form{$_}) {
      print MAIL "$_: $Form{$_}\n\n";
    }
  }

  print MAIL "$dashes\n\n";

  foreach (@{$Config{env_report}}) {
    print MAIL "$_: $ENV{$_}\n" if $ENV{$_};
  }

  close (MAIL) || die $!;
}

sub check_email {
  my ($email) = @_;

  # If the e-mail address contains:
  if ($email =~ /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ ||

      # the e-mail address contains an invalid syntax.  Or, if the
      # syntax does not match the following regular expression pattern
      # it fails basic syntax verification.

      $email !~ /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z0-9]+)(\]?)$/) {

    # Basic syntax requires:  one or more characters before the @ sign,
    # followed by an optional '[', then any number of letters, numbers,
    # dashes or periods (valid domain/IP characters) ending in a period
    # and then 2 or 3 letters (for domain suffixes) or 1 to 3 numbers
    # (for IP addresses).  An ending bracket is also allowed as it is
    # valid syntax to have an email address like: user@[255.255.255.0]

    # Return a false value, since the e-mail address did not pass valid
    # syntax.
    return 0;
  } else {
    # Return a true value, e-mail verification passed.
    return 1;
  }
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
    $attr .= qq( $attrs{$_}="), escape_html($Config{$_}), '"' if $Config{$_};
  }

  return $attr;
}

sub error {
  my ($error, @error_fields) = @_;
  my ($host, $missing_field, $missing_field_list);

  my ($title, $heading,$error_body);

  if ($error eq 'bad_referer') {
    my $referer = referer();
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
 elsif ( $error eq 'no_recipient') {
   
   my $recipient = escape_html($Config{recipient});
   $title = 'Error: Bad or Missing Recipient';
   $heading = $title;
   $error_body =<<EOBODY;
<p>
  There was no recipient or an invalid recipient specified in the
  data sent to FormMail. Please make sure you have filled in the
  <tt>recipient</tt> form field with an e-mail address that has
  been configured in <tt>\@recipients</tt>. More information on
  filling in <tt>recipient</tt> form fields and variables can be
  found in the README file.  
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
        my $missing_field_list = map { '<li>' . escape_html($_) . "</li>\n" }
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
  print <<END_ERROR_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
    <link rel="stylesheet" type="text/css" href="$style" />
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
  <body>
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

  $str =~ s/([\Q$chars\E])/$escape_html_map{$1}/g;
  return $str;
}
