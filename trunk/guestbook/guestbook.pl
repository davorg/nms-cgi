#!/usr/local/perl-5.00404/bin/perl -Tw
#
# $Id: guestbook.pl,v 1.16 2001-12-10 23:34:37 nickjc Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.15  2001/12/09 23:33:53  nickjc
# bug fix: strip_html was breaking email sending by adding SSI exploit
# defence stuff to the email address.
#
# Revision 1.14  2001/12/01 17:53:11  gellyfish
# * Fixed up some 5.004.04 compatibility issues
# * Started rationalization of HTML handling
#
# Revision 1.13  2001/12/01 11:44:43  gellyfish
# SSI exploit fix as suggested by Pete Sargent
#
# Revision 1.12  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
# Revision 1.11  2001/11/25 15:28:43  gellyfish
# * Added security features
# * more refactoring
#
# Revision 1.10  2001/11/25 11:39:38  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.9  2001/11/24 11:59:58  gellyfish
# * documented strfime date formats is various places
# * added more %ENV cleanup
# * spread more XHTML goodness and CSS stylesheet
# * generalization in wwwadmin.pl
# * sundry tinkering
#
# Revision 1.8  2001/11/19 09:21:44  gellyfish
# * added allow_html functionality
# * fixed potential for pre lock clobbering in guestbook
# * some XHTML toshing
#
# Revision 1.7  2001/11/16 09:06:53  gellyfish
# Had forgotten to declare $DEBUGGING
#
# Revision 1.6  2001/11/14 23:00:13  davorg
# More XHTML fixes.
#
# Revision 1.5  2001/11/14 22:21:17  davorg
# Changed script archive URL to Sourceforge.
# Added link to support mailing list.
#
# Revision 1.4  2001/11/14 19:39:14  davorg
# Fixed stupid bug getting CGI parameters
#
# Revision 1.3  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:53  davorg
# Initial import
#

use strict;
use POSIX qw(strftime);
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);

# Older Fcntl doesn't deal with the SEEK_* defines :(

BEGIN
{
   sub SEEK_SET() { 0; }
};

use vars qw($DEBUGGING);

# sanitize the environment

delete @ENV{qw(ENV BASH_ENV IFS PATH)};

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
   
my $guestbookurl  = 'http://your.host.com/~yourname/guestbook.html';
my $guestbookreal = '/home/yourname/public_html/guestbook.html';
my $guestlog      = '/home/yourname/public_html/guestlog.html';
my $cgiurl        = 'http://your.host.com/cgi-bin/guestbook.pl';

# $emulate_matts_code determines whether the program should behave exactly
# like the original guestbook program.  It should be set to 1 if you
# want to emulate the original program - this is recommended if you are
# replacing an existing installation with this program.  If it is set to 0
# then potentially it will not work with files produced by the original
# version - this is recommended for people installing this for the first time.

my $emulate_matts_code = 1;

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';


my $mail        = 0;
my $uselog      = 1;
my $linkmail    = 1;
my $separator   = 1;
my $redirection = 0;
my $entry_order = 1;
my $remote_mail = 0;
my $allow_html  = 0;
my $line_breaks = 0;

# $mailprog is the program that will be used to send mail if that is 
# required.  It should be the full path of a program that will accept
# the message on its standard input, it should also include any required
# switches.  If $mail is set to 0 above this can be ignores.

my $mailprog  = '/usr/lib/sendmail -t -oi -oem';

# $recipient is the address of the person who should be mailed if $mail is
# set to 1 above.

my $recipient = 'you@your.com';

# $long_date_fmt and $short_date_fmt describe the format of the dates that 
# will output - the replacement parameters you can use here are:
#
# %A - the full name of the weekday according to the current locale
# %B - the full name of the month according to the current local
# %m - the month as a number
# %d - the day of the month as a number
# %D - the date in the form %m/%d/%y (i.e. the US format )
# %y - the year as a number without the century
# %Y - the year as a number including the century
# %H - the hour as number in the 24 hour clock
# %M - the minute as a number
# %S - the seconds as a number
# %T - the time in 24 hour format (%H:%M:%S)
# %Z - the time zone (full name or abbreviation)

my $long_date_fmt  = '%A, %B %d, %Y at %T (%Z)';
my $short_date_fmt = '%d/%m/%y %T %Z';

# End configuration

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

my @now       = localtime();
my $date      = strftime($long_date_fmt, @now);
my $shortdate = strftime($short_date_fmt, @now);

my ($username, $realname, $comments)
  = (param('username'), param('realname'), param('comments'));

my ($city, $state, $country)
  = (param('city'), param('state'), param('country'));

my ($url) = param('url');

# There is a possibility that the comments can be escaped if passed as
# the hidden field from the form_error() form

my $encoded_comments = param('encoded_comments') || 0;

form_error('no_comments') unless $comments;

$comments = unescape_html($comments) if $encoded_comments;

# crudely Strip out HTML unless we are allowing it
# strip_html should take care of everything.

$comments = strip_html($comments, $allow_html);

form_error('no_name')     unless $realname;

# substitute newlines in the comments for html line breaks if required.

$comments =~ s%\cM\n%<br />\n%g if $line_breaks;

# Get rid of the $username unless it is a valid e-mail address

$username = '' unless check_email($username);

# Escape any HTML in the rest of the fields - HTML should not
# be allowed anywhere but the comment.

my %escaped = (
 username => escape_html($username),
 realname => escape_html($realname),
 city     => escape_html($city),
 state    => escape_html($state),
 country  => escape_html($country),
);

open (GUEST, "+<$guestbookreal")
  || die "Can't Open $guestbookreal: $!\n";
flock GUEST, LOCK_EX
  || die "Can't lock $guestbookreal: $!\n";

my @lines = <GUEST>;

seek GUEST, SEEK_SET, 0;
truncate GUEST, 0;

foreach (@lines) {
   if (/<!--begin-->/) {

     if ($entry_order) {
       print GUEST "<!--begin-->\n";
     }


     print GUEST "<b>$comments</b><br />\n";

     if ($url) {
       print GUEST qq(<a href="$url">$escaped{realname}</a>);
      } else {
         print GUEST $escaped{realname};
      }

     if ($username){
       if ($linkmail) {
	 print GUEST qq( &lt;<a href="mailto:$escaped{username}">);
	 print GUEST "$escaped{username}</a>&gt;";
       } else {
	 print GUEST " &lt;$escaped{username}&gt;";
       }
     }

     print GUEST "<br />\n";

     if ($city){
       print GUEST "$escaped{city}, ";
     }

     if ($state){
       print GUEST $escaped{state};
     }

     if ($country){
       print GUEST " $escaped{country}";
     }

     if ($separator) {
       print GUEST " - $date<hr />\n\n";
     } else {
       print GUEST " - $date<p />\n\n";
     }

     unless ($entry_order) {
       print GUEST "<!--begin-->\n";
     }

   } else {
     print GUEST $_;
   }
}

close (GUEST);

write_log('entry') if $uselog;

if ($mail) {
   my $to = $recipient;
   my $reply = "$username ($realname)";
   my $from   = "$username ($realname)";
   my $subject = 'Entry to Guestbook';
   my $body    = 'You have a new entry in your guestbook:';
   do_mail($to, $from, $reply, $subject, $body );
}

if ($remote_mail && $username) {

  my $to = $username;
  my $from = $recipient;
  my $reply = $recipient;
  my $subject = 'Entry to Guestbook';
  my $body    = 'Thank you for adding to my guestbook.';
  do_mail($to, $from, $reply, $subject, $body );
}

# Print Out Initial Output Location Heading
if ($redirection) {
  print redirect($guestbookurl);
} else {
  no_redirection();
}

sub form_error {

  my ( $why ) = @_;

  $comments = escape_html($comments) if $comments;

  my ( $title, $heading, $text, $comments_field ) ;

  if ( $why eq 'no_name' ) {
      $realname = '';
      $title = 'No Name';
      $heading = 'Your Name appears to be blank';
      $text =<<EOTEXT;
The Name Section in the guestbook fillout form appears to
be blank and therefore your entry to the guestbook was not
added.  Please add your name in the blank below.
EOTEXT
      $comments_field =<<EOCOMMENT;
    Comments have been retained.
        <input type="hidden" name="comments" value="$comments" />
        <input type="hidden" name="comments_encoded" value="1" />
EOCOMMENT
   }
   elsif ( $why eq 'no_comments' ) {
      $title = 'No Comments';
      $heading = 'Your Comments appear to be blank';
      $text =<<EOTEXT;
The comment section in the guestbook fillout form appears
to be blank and therefore the Guestbook Addition was not
added.  Please enter your comments below.
EOTEXT
      $comments_field =<<EOCOMMENT;
      Comments:<br />
      <textarea name="comments" cols="60" rows="4"></textarea>
EOCOMMENT
   }
   else {
      $title = 'Unknown Error';
      $heading = 'Something appears to be wrong with your submission';
      $text    = 'Please check your input and resubmit'; 
      $comments_field =<<EOCOMMENT;
      Comments:<br />
      <textarea name="comments" cols="60" rows="4">$comments</textarea />
      <input type="hidden" name="comments_encoded" value="1" />
EOCOMMENT
   }
  
  local $^W; # suppress warnings as we may have missing fields;

  print header;
  print <<END_FORM;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$title</title>
     <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1>$heading</h1>
    <p>
      $text
    </p>
    <form method="post" action="$cgiurl">
      <p>Your Name: <input type="text" name="realname" 
                           value="$realname" size="30" /><br />
        E-Mail: <input type="text" name="username"
                       value="$username" size="40" /><br />
        City: <input type="text" name="city" value="$city" 
                     size="15" />, 
        State: <input type="text" name="state" 
                      value="$state" size="2" /> 
        Country: <input type="text" name="country" value="$country" 
                        size="15" /></p>
      <p>
       $comments_field
      </p>
      <p><input type="submit"> * <input type="reset"></p>
    </form>
    <hr />
    <p>Return to the <a href="$guestbookurl">Guestbook</a>.
  </body>
</html>

END_FORM

  # Log The Error

  write_log($why) if $uselog;

  exit;
}

# Log the Entry or Error
sub write_log {
  my ($log_type) = @_;   

  if ( open(LOG, ">>$guestlog") )
  {
      if ( flock LOG, LOCK_EX )
      {

         my $remote = remote_host();
         if ($log_type eq 'entry') {
           print LOG "$remote - [$shortdate]<br />\n";
         } elsif ($log_type eq 'no_name') {
           print LOG "$remote - [$shortdate] - ERR: No Name<br />\n";
         } elsif ($log_type eq 'no_comments') {
           print LOG "$remote - [$shortdate] - ERR: No Comments<br />\n";
         }
      }
      else
      {
         die "Can't lock log file: $!\n" if $main::DEBUGGING;
      }
  }
  else
  {
    # We probably dont wan't to show this to the crowd :)

    die "Can't open log file: $!\n" if $DEBUGGING;

  }

}

# Redirection Option
sub no_redirection {

  print header();
  print <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>Thank You</title>
     <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1>Thank You For Signing The Guestbook</h1>

    <p>Thank you for filling in the guestbook.  Your entry has
      been added to the guestbook.</p>
    <hr />
    <p>Here is what you submitted:</p>
    <p><b>$comments</b><br>

END_HTML

  if ($url) {
    print qq(<a href="$url">$escaped{realname}</a>);
   } else {
     print $escaped{realname};
   }

  if ($username){
    if ($linkmail) {
      print qq( &lt;<a href="mailto:$escaped{username}">);
      print "$escaped{username}</a>&gt;";
    } else {
      print " &lt;$escaped{username}&gt;";
    }
  }

  print "<br />\n";

  print "$escaped{city}," if $city;

  print " $escaped{state}" if $state;

  print " $escaped{country}" if $country;

  print " - $date<p>\n";

  # Print End of HTML

  print <<END_HTML;

    <hr />
    <p><a href="$guestbookurl">Back to the Guestbook</a>
      - You may need to reload it when you get there to see your
      entry.</p>
  </body>
</html>

END_HTML

  exit;
}

sub do_mail
{

  my ( $to, $from,$reply , $subject, $body ) = @_;

  open (MAIL, "|$mailprog") || die "Can't open $mailprog - $!\n";

  print MAIL <<EOMAIL;
To: $to
Reply-to: $reply
From: $from
Subject: $subject

$body
------------------------------------------------------
$comments
$realname
EOMAIL

  if ($username){
    print MAIL " <$username>";
  }

  print MAIL "\n";

  print MAIL "$city'," if $city;

  print MAIL " $state" if $state;

  print MAIL " $country" if $country;

  print MAIL " - $date\n";
  print MAIL "------------------------------------------------------\n";

  close (MAIL);
}

# subroutine to crudely strip html from a text string
# ideally we would want to use HTML::Parser or somesuch.
# we will also implement any selective tag replacement here
# thus all user supplied input that will be displayed should
# be passed through this before being displayed.

sub strip_html
{
   my ( $comments,$allow_html ) = @_;

   $allow_html = defined $allow_html ? $allow_html : 0;

   if ( $allow_html ) {
     # XXX whitelist based HTML filter goes here XXX

     # remove any comments that could harbour an attempt at an SSI exploit
     # suggested by Pete Sargeant

     $comments =~ s/<!--.*?-->/ /gs;

     # mop up any stray start or end of comment tags.
     return "<!-- -->$comments<!-- -->";
   } else {
     $comments =~ s/<(?:[^>'"]+|".*?"|'.*?')*>//gs;
     return escape_html($comments);
   }
}

use vars qw(%escape_html_map %unescape_html_map);

BEGIN
{
   %escape_html_map = ( '&' => '&amp;',
                        '<' => '&lt;',
                        '>' => '&gt;',
                        '"' => '&quot;',
                        "'" => '&#39;',
                      );

   while ( my ( $key, $value ) = each %escape_html_map )
   {
      $unescape_html_map{$value} = $key;
   }
}

# subroutine to escape the necessary characters to the appropriate HTML
# entities

sub escape_html {
  my $str = shift;
  my $chars = join '', keys %escape_html_map;
  $str =~ s/([\Q$chars\E])/$escape_html_map{$1}/g;
  return $str;
}

sub unescape_html {
  my $str = shift;
  my $pattern = join '|', map { quotemeta($_) } keys(%unescape_html_map);
  $str =~ s/($pattern)/$unescape_html_map{$1}/g;
  return $str;
}

# basic check on e-mail address - this is very crude and is better achieved
# by the use of one of the modules

sub check_email {
  my $email = $_[0];

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

