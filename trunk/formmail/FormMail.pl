#!/usr/bin/perl -wT
#
# $Id: FormMail.pl,v 1.33 2002-02-03 20:47:06 dragonoe Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.32  2002/01/31 17:26:43  proub
# no longer accepting email addresses with % characters in the name portion
#   (to avoid spoofing sendmail addressing on some systems) - revert
#   to old behavior when $emulate_matts_code is true
# when $emulate_matts_code is true, verify email addresses in a
#   case-insensitive manner.
#
# Revision 1.31  2002/01/30 19:04:45  proub
# now properly handling referer URLs involving authentication info (e.g.
#   http://www.dave.org.uk@actual.referer.com, or
#   http://someuser@dave.org.uk)
# cleared up warnings when no referer is present
#
# Revision 1.30  2002/01/29 00:05:01  nickjc
# * typo
# * added X-HTTP-Client header to the confirmation email.
#
# Revision 1.29  2002/01/27 16:00:04  nickjc
# allow_mail_to: explicit $ rather than depend on the one that's added
# unless $emulate_matts_code.
#
# Revision 1.28  2002/01/27 14:45:11  nickjc
# * re-wrote README
# * added @allow_mail_to config option
#
# Revision 1.27  2002/01/27 13:59:08  gellyfish
# Issues from  http://www.monkeys.com/anti-spam/formmail-advisory.pdf
# * Left anchored regex to check referer
# * If $secure and no referer supplied then croak
#
# Revision 1.26  2002/01/21 21:58:00  gellyfish
# Checkbox fix from Chris Benson
#
# Revision 1.25  2002/01/20 14:52:02  nickjc
# added a warning about the risks of turning on the confirmation email
#
# Revision 1.24  2002/01/19 23:44:28  nickjc
# Added the option to send a confirmation email to the submitter, in
# response to a user request.
#
# Revision 1.23  2002/01/14 08:54:10  nickjc
# Took out a warn statement left over from a debugging session
#
# Revision 1.22  2002/01/04 08:55:31  nickjc
# tightened valid url regex
#
# Revision 1.21  2002/01/02 21:21:45  gellyfish
# Altered regex in check_valid_url to deal with server port number
#
# Revision 1.20  2002/01/01 01:22:27  nickjc
# error message fix from Paul Sharpe
#
# Revision 1.19  2001/12/15 22:42:00  nickjc
# * Added a validity check on the redirect URLs
# * Moved the nonprintable character striping code to a sub
#
# Revision 1.18  2001/12/09 22:31:22  nickjc
# * anchor recipient checks at end (as per README) unless $emulate_matts_code
# * move repeated check_email call out one loop level
#
# Revision 1.17  2001/12/05 14:28:24  nickjc
# * Don't do things on GET if $secure
# * Eliminate some warnings in send_email
# * Restrict realname slightly if $secure
#
# Revision 1.16  2001/12/04 08:55:03  nickjc
# stricter check_email if $secure
#
# Revision 1.15  2001/12/01 19:45:21  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
# Revision 1.14  2001/11/29 14:18:38  nickjc
# * Removed CGI::Carp::set_message (doesn't work under 5.00404)
# * Added some very minimal input filtering
#
# Revision 1.13  2001/11/26 17:36:43  nickjc
# * Allow domain names without '.' so that user@localhost works.
# * Don't overwrite $Config{recipient} with the empty string before
#   displaying it on the error page.
# * Fixed a couple of minor errors.
#
# Revision 1.12  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
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
use vars qw($DEBUGGING);

# PROGRAM INFORMATION
# -------------------
# FormMail.pl v1.32
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For a list of changes see CHANGELOG
# 
# For help on configuration or installation see README
#
# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#
BEGIN { $DEBUGGING = 1; }
my $emulate_matts_code = 0;
my $secure = 1;
my $mailprog = '/usr/lib/sendmail -oi -t';
my @referers = qw(dave.org.uk 209.207.222.64 localhost);
my @allow_mail_to = qw(you@your.domain some.one.else@your.domain localhost);
my @recipients = ();
my @valid_ENV = qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT);
my $date_fmt = '%A, %B %d, %Y at %H:%M:%S';
my $style = '/css/nms.css';
my $send_confirmation_mail = 0;
my $confirmation_text = <<'END_OF_CONFIRMATION';
From: you@your.com
Subject: form submission

Thankyou for your form submission.

END_OF_CONFIRMATION
#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)


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

      print "Content-Type: text/html\n\n";

      print <<EOERR;
<html>
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

#  Empty the environment of potentially harmful variables
#  This might cause problems if $mail_prog is a shell script :)

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};

$ENV{PATH} = '/bin:/usr/bin';

my %valid_ENV;

@valid_ENV{@valid_ENV} = (1) x @valid_ENV;

#  Uncomment the following line (and the Unit Tests section)
#  to unit test URL checking functions
#
#  unitTest();

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
      $Form{$key} = @vals == 1 ? $vals[0] : [@vals];
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
    if (%Form) {
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
      push(@error, $_) unless $Config{$_};
    } else {
      push(@error,$_) unless $Form{$_};
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

  return(0);
}

sub return_html {
  my ($key, $sort_order, $sorted_field);

  if ($Config{'redirect'}) {
    print redirect $Config{'redirect'};
  } else {
    print header;

    my $title = escape_html( $Config{'title'} || 'Thank You' );
    my $recipient = escape_html($Config{'recipient'});
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

  my $realname = $Config{realname};
  if (defined $realname) {
    if ($secure) {
      # A transform to eliminate some potential problem characters
      $realname =~ tr#()\\#{}/#;
      $realname =~ s#\s+# #g;
    }
    $realname = " ($realname)";
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
    $xheader = "X-HTTP-Client: [$1]\n";
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
    if ($Config{'print_blank_fields'} || defined $Form{$_}) {
      print MAIL "$_: ", (ref $Form{$_} ? "@{$Form{$_}}" : $Form{$_}),"\n\n";
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

      $email !~ /^(.+)\@(?:[a-zA-Z0-9\-\.]+|\[[0-9\.]+\])$/ || 
      ($secure and ($1 =~ /\%/)))
      {

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
    if ($secure) {
      # An extra check on the local part: allow only those characters
      # that RFC822 permits without quoting.
      my $localpart = $1;
      if ($localpart !~ /^[A-Za-z0-9_\Q!#\$\%&'*+-.\/=?^_`{|}~\E\200-\377]+$/) {
        return 0;
      }
    }
    # Return a true value, e-mail verification passed.
    return 1;
  }
}

# check the validity of a URL.

sub check_url_valid {
  my $url = shift;

  $url =~ m< ^ (?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?
               (?: / [\w\-.!~*'(|);/?\@&=+\$,%#]* )?
             $
           >x ? 1 : 0;
}

sub strip_nonprintable {
  my $text = shift;
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

  if (defined($str))
  {
    $str =~ s/([\Q$chars\E])/$escape_html_map{$1}/g;
  }

  return $str;
}



# begin Unit Tests
#  sub unitTest
#  {
#      recipientTests();
#      refererTests();
#      exit(0);
#  }
#
#  sub recipientTests()
#  {
#      recipCheck('you@your.domain', 1, 1);
#      recipCheck('you@your.domain', 1, 0);
#      recipCheck('some.one.else@your.domain', 1, 1);
#      recipCheck('some.one.else@your.domain', 1, 0);
#      recipCheck('anyone@localhost', 1, 1);
#      recipCheck('anyone@localhost', 1, 0);
#      recipCheck('localhost', 0, 1);
#      recipCheck('localhost', 0, 0);
#      recipCheck('user%elsewhere.com@localhost', 1, 1);
#      recipCheck('user%elsewhere.com@localhost', 0, 0);
#
#      recipCheck('YOU@your.domain', 1, 1);
#      recipCheck('YOU@your.domain', 0, 0);
#      recipCheck('some.one.else@YOUR.domain', 1, 1);
#      recipCheck('some.one.else@YOUR.domain', 0, 0);
#      recipCheck('anyone@Localhost', 1, 1);
#      recipCheck('anyone@Localhost', 0, 0);
#
#      recipCheck('<user@elsewhere.com>your.domain', 0, 0);
#      recipCheck('user@elsewhere.com(your.domain', 0, 0);
#  }
#
#  sub recipCheck
#  {
#      my ($recip, $shouldBeGood, $emulate) = @_;
#     my $secureMsg;
#
#     $emulate = 0 if ! defined( $emulate );
#
#     if ($emulate) 
#     {
#  	$secure = 0;
#  	$emulate_matts_code = 1;
#  	$secureMsg = 'insecure';
#     }
#     else
#     {
#  	$secure = 1;
#  	$emulate_matts_code = 0;
#  	$secureMsg = 'secure';
#     }
#
#     if ($shouldBeGood)
#     {
#         if ((! check_email($recip)) or (! check_recipient($recip)))
#         {
#  	 warn "$recip should be good ($secureMsg)";
#         }
#     }
#     else
#     {
#         if (check_email($recip) and check_recipient($recip))
#         {
#  	   warn "$recip should be bad ($secureMsg)";
#         }
#     }
#  }
#
#  sub refererTests
#  {
#     refCheck('xxx.xxx.xxx', 0);
#     refCheck('http://dave.org.uk', 1);
#     refCheck('http://dave.org.uk/', 1);
#     refCheck('http://dave.org.uk/more', 1);
#     refCheck('https://dave.org.uk/', 1);
#     refCheck(undef, 0, 0);
#     refCheck(undef, 1, 1);
#     refCheck('https://dave.org.uk@someplace.else.com', 0);
#     refCheck('https://dave.org.uk@someplace.else.com', 1, 1);
#     refCheck('https://someguy@dave.org.uk', 0, 1);
#     refCheck('https://someguy@dave.org.uk', 1, 0);
#     refCheck('https://someguy@dave.org.uk/more', 1, 0);
#     refCheck('http://209.207.222.64', 1);
#     refCheck('http://localhost/', 1);
#  }
#
#  sub refCheck
#  {
#     my ($referer, $shouldBeGood, $emulate) = @_;
#     my $secureMsg;
#
#     $emulate = 0 if ! defined( $emulate );
#
#     if ($emulate) 
#     {
#  	$secure = 0;
#  	$secureMsg = 'insecure';
#     }
#     else
#     {
#  	$secure = 1;
#  	$secureMsg = 'secure';
#     }
#	
#     if ($shouldBeGood)
#     {
#  	warn "$referer should be good ($secureMsg)" if ! check_referer($referer);
#     }
#     else
#     {
#  	warn "$referer should be bad ($secureMsg)" if check_referer($referer);
#     }
#  }
