#!/usr/bin/perl -wT
#
# $Id: guestbook.pl,v 1.34 2002-04-09 19:56:25 nickjc Exp $
#

use strict;
use POSIX qw(strftime);
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);

use vars qw($DEBUGGING $done_headers @debug_msg);

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

my $style_element = $style ? 
                    qq%<link rel="stylesheet" type="text/css" href="$style" />%
                  : '';

my @now       = localtime();
my $date      = strftime($long_date_fmt, @now);
my $shortdate = strftime($short_date_fmt, @now);

my ($username, $realname, $comments)
  = (param('username'), param('realname'), param('comments'));

my ($city, $state, $country)
  = (param('city'), param('state'), param('country'));

my ($url) = param('url');
$url = '' if $url and not check_url_valid($url);

# There is a possibility that the comments can be escaped if passed as
# the hidden field from the form_error() form

my $encoded_comments = param('encoded_comments') || 0;

form_error('no_comments') unless $comments;

$comments = unescape_html($comments) if $encoded_comments;

# Strip out HTML unless we are allowing it
# process_html should take care of everything.

$comments = process_html($comments, $line_breaks, $allow_html);

form_error('no_name')     unless $realname;


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

open (LOCK, ">>$guestbookreal.lck")
  || die "Can't Open $guestbookreal.lck: $!\n";
flock LOCK, LOCK_EX
  || die "Can't lock $guestbookreal.lck: $!\n";

open (GUEST_IN, "<$guestbookreal")
  || die "Can't Open $guestbookreal: $!\n";
open (GUEST, ">$guestbookreal.tmp")
  || die "Can't Open $guestbookreal.tmp: $!\n";


while ( defined( $_ = <GUEST_IN> ) ) {
   if (/<!--begin-->/) {

     if ($entry_order) {
       print GUEST "<!--begin-->\n";
     }


     print GUEST "<b>$comments</b><br />\n";

     if ($url) {
       my $eurl = escape_html($url);
       print GUEST qq(<a href="$eurl">$escaped{realname}</a>);
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

unless ( close GUEST ) {
   unlink "$guestbookreal.tmp";
   die "write to $guestbookreal.tmp: $!";
}

close GUEST_IN;

rename "$guestbookreal.tmp", $guestbookreal
   or die "rename $guestbookreal.tmp -> $guestbookreal: $!";

write_log('entry') if $uselog;

close LOCK;

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
  $done_headers++;
  print <<END_FORM;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
    $style_element
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
    <p>Return to the <a href="$guestbookurl">Guestbook</a></p>.
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
  $done_headers++;
  print <<END_HTML;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Thank You</title>
    $style_element
  </head>
  <body>
    <h1>Thank You For Signing The Guestbook</h1>

    <p>Thank you for filling in the guestbook.  Your entry has
      been added to the guestbook.</p>
    <hr />
    <p>Here is what you submitted:</p>
    <p><b>$comments</b></p><br />

END_HTML

  if ($url) {
    my $eurl = escape_html($url);
    print qq(<a href="$eurl">$escaped{realname}</a>);
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

  print " - $date\n";

  if (scalar @debug_msg) {
    print qq|<br /><font color="red">\n|;
    print map { escape_html($_) . qq|<br />\n| } @debug_msg;
    print "</font>\n";
  }

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

##############################################################
#
# Validity checks for various contexts.
#

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

##################################################################
#
# HTML handling code
#
# The code below provides some functions for manipulating HTML.
#
#  check_url_valid ( URL )
#
#    Returns 1 if the string URL is a valid http, https or ftp
#    URL, 0 otherwise.
#
#  process_html ( INPUT [,LINE_BREAKS [,ALLOW]] )
#
#    Returns a modified version of the HTML string INPUT, with
#    any potentially malicious HTML constructs (such as java,
#    javascript and IMG tags) removed.
#
#    If the LINE_BREAKS parameter is present and true then
#    line breaks in the input will be converted to html <br />
#    tags in the output.
#
#    If the ALLOW parameter is present and true then most
#    harmless tags will be left in, otherwise all tags will be
#    removed.
#
#  escape_html ( INPUT )
#
#    Returns a copy of the string INPUT with any HTML
#    metacharacters replaced with character escapes.
#
#  unescape_html ( INPUT )
#
#    Returns a copy of the string INPUT with HTML character
#    entities converted to literal characters where possible.
#    Note that some entites have no 8-bit character equivalent,
#    see "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent"
#    for some examples.  unescape_html() leaves these entities
#    in their encoded form.
#

use vars qw(%html_entities $html_safe_chars %escape_html_map);
use vars qw(%safe_tags %safe_style %tag_is_empty $convert_nl
            %auto_deinterleave $auto_deinterleave_pattern);

# check the validity of a URL.

sub check_url_valid {
  my $url = shift;

  $url =~ m< ^ (?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?
               (?: / [\w\-.!~*'(|);/?\@&=+\$,%#]* )?
             $
           >x ? 1 : 0;
}

sub process_html {
  my ($text, $line_breaks, $allow_html) = @_;

  cleanup_html( $text,
                $line_breaks,
                ($allow_html ? \%safe_tags : {})
              );
}

BEGIN
{
  %html_entities = (
    'lt'     => '<',
    'gt'     => '>',
    'quot'   => '"',
    'amp'    => '&',

    'nbsp'   => "\240", 'iexcl'  => "\241",
    'cent'   => "\242", 'pound'  => "\243",
    'curren' => "\244", 'yen'    => "\245",
    'brvbar' => "\246", 'sect'   => "\247",
    'uml'    => "\250", 'copy'   => "\251",
    'ordf'   => "\252", 'laquo'  => "\253",
    'not'    => "\254", 'shy'    => "\255",
    'reg'    => "\256", 'macr'   => "\257",
    'deg'    => "\260", 'plusmn' => "\261",
    'sup2'   => "\262", 'sup3'   => "\263",
    'acute'  => "\264", 'micro'  => "\265",
    'para'   => "\266", 'middot' => "\267",
    'cedil'  => "\270", 'supl'   => "\271",
    'ordm'   => "\272", 'raquo'  => "\273",
    'frac14' => "\274", 'frac12 '=> "\275",
    'frac34' => "\276", 'iquest' => "\277",

    'Agrave' => "\300", 'Aacute' => "\301",
    'Acirc'  => "\302", 'Atilde' => "\303",
    'Auml'   => "\304", 'Aring'  => "\305",
    'AElig'  => "\306", 'Ccedil' => "\307",
    'Egrave' => "\310", 'Eacute' => "\311",
    'Ecirc'  => "\312", 'Euml'   => "\313",
    'Igrave' => "\314", 'Iacute' => "\315",
    'Icirc'  => "\316", 'Iuml'   => "\317",
    'ETH'    => "\320", 'Ntilde' => "\321",
    'Ograve' => "\322", 'Oacute' => "\323",
    'Ocirc'  => "\324", 'Otilde' => "\325",
    'Ouml'   => "\326", 'times'  => "\327",
    'Oslash' => "\330", 'Ugrave' => "\331",
    'Uacute' => "\332", 'Ucirc'  => "\333",
    'Uuml'   => "\334", 'Yacute' => "\335",
    'THORN'  => "\336", 'szlig'  => "\337",

    'agrave' => "\340", 'aacute' => "\341",
    'acirc'  => "\342", 'atilde' => "\343",
    'auml'   => "\344", 'aring'  => "\345",
    'aelig'  => "\346", 'ccedil' => "\347",
    'egrave' => "\350", 'eacute' => "\351",
    'ecirc'  => "\352", 'euml'   => "\353",
    'igrave' => "\354", 'iacute' => "\355",
    'icirc'  => "\356", 'iuml'   => "\357",
    'eth'    => "\360", 'ntilde' => "\361",
    'ograve' => "\362", 'oacute' => "\363",
    'ocirc'  => "\364", 'otilde' => "\365",
    'ouml'   => "\366", 'divide' => "\367",
    'oslash' => "\370", 'ugrave' => "\371",
    'uacute' => "\372", 'ucirc'  => "\373",
    'uuml'   => "\374", 'yacute' => "\375",
    'thorn'  => "\376", 'yuml'   => "\377",
  );

  #
  # Build a map for representing characters in HTML.
  #
  $html_safe_chars = '()[]{}/?.,\\|;:@#~=+-_*^%$! ' . "\r\n\t";
  %escape_html_map =
     map {$_,$_} ( 'A'..'Z', 'a'..'z', '0'..'9',
                   split(//, $html_safe_chars)
                 );
  foreach my $ent (keys %html_entities) {
    $escape_html_map{$html_entities{$ent}} = "&$ent;";
  }
  foreach my $c (0..255) {
    unless ( exists $escape_html_map{chr $c} ) {
      $escape_html_map{chr $c} = sprintf '&#%d;', $c;
    }
  }

  #
  # Tables for use by cleanup_html() (below).
  #
  # The main table is %safe_tags, which is a hash by tag name of
  # all the tags that it's safe to leave in.  The value for each
  # tag is another hash, and each key of that hash defines an
  # attribute that the tag is allowed to have.
  #
  # The values in the tag attribute hash can be undef (for an
  # attribute that takes no value, for example the nowrap
  # attribute in the tag <td align="left" nowrap>) or they can
  # be coderefs pointing to subs for cleaning up the attribute
  # values.
  #
  # These subs will called with the attribute value in $_, and
  # they can return either a cleaned attribute value or undef.
  # If undef is returned then the attribute will be deleted
  # from the tag.
  #
  # The list of tags and attributes was taken from
  # "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
  #
  # The %tag_is_empty table defines the set of tags that have
  # no corresponding close tag.
  #
  # cleanup_html() moves close tags around to force all tags to
  # be closed in the correct sequence.  For example, the text
  # "<h1><i>foo</h1>bar</i>" will be converted to the text
  # "<h1><i>foo</i></h1>bar".
  #
  # The %auto_deinterleave table defines the set of tags which
  # should be automatically reopened if they're closed early
  # in this way.  All the tags involved must be in
  # %auto_deinterleave for the tag to be reopened.  For example,
  # the text "<b>bb<i>bi</b>ii</i>" will be converted into the
  # text "<b>bb<i>bi</i></b><i>ii</i>" rather than into the
  # text "<b>bb<i>bi</i></b>ii", because *both* "b" and "i" are
  # in %auto_deinterleave.
  #
  %tag_is_empty = ( 'hr' => 1, 'br' => 1, 'basefont' => 1 );
  %auto_deinterleave = map {$_,1} qw(
    tt i b big small u s strike font basefont
    em strong dfn code q sub sup samp kbd var
    cite abbr acronym span
  );
  $auto_deinterleave_pattern = join '|', keys %auto_deinterleave;
  my %attr = ( 'style' => \&cleanup_attr_style );
  my %font_attr = (
    %attr,
    size  => sub { /^([-+]?\d{1,3})$/    ? $1 : undef },
    face  => sub { /^([\w\-, ]{2,100})$/ ? $1 : undef },
    color => \&cleanup_attr_color,
  );
  my %insdel_attr = (
    %attr,
    'cite'     => \&cleanup_attr_uri,
    'datetime' => \&cleanup_attr_text,
  );
  my %texta_attr = (
    %attr,
    align => sub { s/middle/center/i;
                   /^(left|center|right)$/i ? lc $1 : undef
                 },
  );
  my %cellha_attr = (
    align   => sub { s/middle/center/i;
                     /^(left|center|right|justify|char)$/i
                     ? lc $1 : undef
                   },
    char    => sub { /^([\w\-])$/ ? $1 : undef },
    charoff => \&cleanup_attr_length,
  );
  my %cellva_attr = (
    valign => sub { s/center/middle/i;
                    /^(top|middle|bottom|baseline)$/i ? lc $1 : undef
                  },
  );
  my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );
  my %col_attr = (
    %attr,
    width => \&cleanup_attr_multilength,
    span =>  \&cleanup_attr_number,
    %cellhv_attr,
  );
  my %thtd_attr = (
    %attr,
    abbr    => \&cleanup_attr_text,
    axis    => \&cleanup_attr_text,
    headers => \&cleanup_attr_text,
    scope   => sub { /^(row|col|rowgroup|colgroup)$/i ? lc $1 : undef },
    rowspan => \&cleanup_attr_number,
    colspan => \&cleanup_attr_number,
    %cellhv_attr,
    nowrap  => undef,
    bgcolor => \&cleanup_attr_color,
    width   => \&cleanup_attr_number,
    height  => \&cleanup_attr_number,
  );
  my $none = {};
  %safe_tags = (
    'br'         => { 'clear' => sub { /^(left|right|all|none)$/i ? lc $1 : undef }
                    },
    'em'         => \%attr,
    'strong'     => \%attr,
    'dfn'        => \%attr,
    'code'       => \%attr,
    'samp'       => \%attr,
    'kbd'        => \%attr,
    'var'        => \%attr,
    'cite'       => \%attr,
    'abbr'       => \%attr,
    'acronym'    => \%attr,
    'q'          => { %attr, 'cite' => \&cleanup_attr_uri },
    'blockquote' => { %attr, 'cite' => \&cleanup_attr_uri },
    'sub'        => \%attr,
    'sup'        => \%attr,
    'tt'         => \%attr,
    'i'          => \%attr,
    'b'          => \%attr,
    'big'        => \%attr,
    'small'      => \%attr,
    'u'          => \%attr,
    's'          => \%attr,
    'font'       => \%font_attr,
    'table'      => { %attr,
                      'frame'       => \&cleanup_attr_tframe,
                      'rules'       => \&cleanup_attr_trules,
                      %texta_attr,
                      'bgcolor'     => \&cleanup_attr_color,
                      'width'       => \&cleanup_attr_length,
                      'cellspacing' => \&cleanup_attr_length,
                      'cellpadding' => \&cleanup_attr_length,
                      'border'      => \&cleanup_attr_number,
                      'summary'     => \&cleanup_attr_text,
                    },
    'caption'    => { %attr,
                      'align' => sub { /^(top|bottom|left|right)$/i ? lc $1 : undef },
                    },
    'colgroup'   => \%col_attr,
    'col'        => \%col_attr,
    'thead'      => \%cellhv_attr,
    'tfoot'      => \%cellhv_attr,
    'tbody'      => \%cellhv_attr,
    'tr'         => { %attr,
                      bgcolor => \&cleanup_attr_color,
                      %cellhv_attr,
                    },
    'th'         => \%thtd_attr,
    'td'         => \%thtd_attr,
    'ins'        => \%insdel_attr,
    'del'        => \%insdel_attr,
    'a'          => { %attr,
                      href => \&cleanup_attr_uri,
                    },
    'h1'         => \%texta_attr,
    'h2'         => \%texta_attr,
    'h3'         => \%texta_attr,
    'h4'         => \%texta_attr,
    'h5'         => \%texta_attr,
    'h6'         => \%texta_attr,
    'p'          => \%texta_attr,
    'div'        => \%texta_attr,
    'span'       => \%texta_attr,
    'ul'         => { %attr,
                      'type'    => sub { /^(disc|square|circle)$/i ? lc $1 : undef },
                      'compact' => undef,
                    },
    'ol'         => { %attr,
                      'type'    => \&cleanup_attr_text,
                      'compact' => undef,
                      'start'   => \&cleanup_attr_number,
                    },
    'li'         => { %attr,
                      'type'  => \&cleanup_attr_text,
                      'value' => \&cleanup_no_number,
                    },
    'dl'         => { %attr, 'compact' => undef },
    'dt'         => \%attr,
    'dd'         => \%attr,
    'address'    => \%attr,
    'pre'        => { %attr, 'width' => \&cleanup_attr_number },
    'center'     => \%attr,
    'nobr'       => $none,
  );
  %safe_style = (
    'color'            => \&cleanup_attr_color,
    'background-color' => \&cleanup_attr_color,
    # XXX TODO: the CSS spec defines loads more, add 'em
  );
}
sub cleanup_attr_style {
  my @clean = ();
  foreach my $elt (split /;/, $_) {
    next if $elt =~ m#^\s*$#;
    if ( $elt =~ m#^\s*([\w\-]+)\s*:\s*(.+?)\s*$#s ) {
      my ($key, $val) = (lc $1, $2);
      local $_ = $val;
      my $sub = $safe_style{$key};
      if (defined $sub) {
        my $cleanval = &{$sub}();
        if (defined $cleanval) {
          push @clean, "$key:$val";
        } elsif ($DEBUGGING) {
          push @debug_msg, "style $key: bad value <$val>";
        }
      } elsif ($DEBUGGING) {
        push @debug_msg, "rejected style element <$key>";
      }
    } elsif ($DEBUGGING) {
      push @debug_msg, "malformed style element <$elt>";
    }
  }
  return join '; ', @clean;
}
sub cleanup_attr_number {
  /^(\d+)$/ ? $1 : undef;
}
sub cleanup_attr_multilength {
  /^(\d+(?:\.\d+)?[*%]?)$/ ? $1 : undef;
}
sub cleanup_attr_text {
  tr/-a-zA-Z0-9()[]{}\/?.,\\|;:@#~=+*^%$! //dc;
  $_;
}
sub cleanup_attr_length {
  /^(\d+\%?)$/ ? $1 : undef;
}
sub cleanup_attr_color {
  /^(\w{2,20}|#[\da-fA-F]{6})$/ or die "color <<$_>> bad";
  /^(\w{2,20}|#[\da-fA-F]{6})$/ ? $1 : undef;
}
sub cleanup_attr_uri {
  check_url_valid($_) ? $_ : undef;
}
sub cleanup_attr_tframe {
  /^(void|above|below|hsides|lhs|rhs|vsides|box|border)$/i
  ? lc $1 : undef;
}
sub cleanup_attr_trules {
  /^(none|groups|rows|cols|all)$/i ? lc $1 : undef;
}

use vars qw(@stack $safe_tags $convert_nl);
sub cleanup_html {
  local ($_, $convert_nl, $safe_tags) = @_;
  local @stack = ();

  s[
    (?: <!--.*?-->                                   ) |
    (?: <[?!].*?>                                    ) |
    (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |
    (?: </([a-z0-9]+)>                               ) |
    (?: (.[^<]*)                                     )
  ][
    defined $1 ? cleanup_tag(lc $1, $2)              :
    defined $3 ? cleanup_close(lc $3)                :
    defined $4 ? cleanup_cdata($4)                   :
    ''
  ]igesx;

  # Close anything that was left open
  $_ .= join '', map "</$_->{NAME}>", @stack;

  # Where we turned <i><b>foo</i></b> into <i><b>foo</b></i><b></b>,
  # take out the pointless <b></b>.
  1 while s#<($auto_deinterleave_pattern)\b[^>]*></\1>##go;
  return $_;
}

sub cleanup_tag
{
  my ($tag, $attrs) = @_;

  unless (exists $safe_tags->{$tag}) {
    push @debug_msg, "reject tag <$tag>" if $DEBUGGING;
    return '';
  }

  my $t = $safe_tags->{$tag};
  my $safe_attrs = '';
  while ($attrs =~ s#^\s*(\w+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?##) {
    my $attr = lc $1;
    my $val = ( defined $2 ? $2                :
                defined $3 ? unescape_html($3) :
                defined $4 ? unescape_html($4) :
                ''
              );
    unless (exists $t->{$attr}) {
      push @debug_msg, "<$tag>: attr '$attr' rejected" if $DEBUGGING;
      next;
    }
    if (defined $t->{$attr}) {
      local $_ = $val;
      my $cleaned = &{ $t->{$attr} }();
      if (defined $cleaned) {
        $safe_attrs .= qq| $attr="${\( escape_html($cleaned) )}"|;
        if ($DEBUGGING and $cleaned ne $val) {
          push @debug_msg, "<$tag>'$attr':val [$val]->[$cleaned]";
        }
      } elsif ($DEBUGGING) {
        push @debug_msg, "<$tag>'$attr':val [$val] rejected";
      }
    } else {
      $safe_attrs .= " $attr";
    }
  }

  if (exists $tag_is_empty{$tag}) {
    return "<$tag$safe_attrs />";
  } else {
    my $html = "<$tag$safe_attrs>";
    unshift @stack, { NAME => $tag, FULL => $html };
    return $html;
  }
}

sub cleanup_close {
  my $tag = shift;

  # Ignore a close without an open
  unless (grep {$_->{NAME} eq $tag} @stack) {
    push @debug_msg, "misplaced </$tag> rejected" if $DEBUGGING;
    return '';
  }

  # Close open tags up to the matching open
  my @close = ();
  while (scalar @stack and $stack[0]{NAME} ne $tag) {
    push @close, shift @stack;
  }
  push @close, shift @stack;

  my $html = join '', map {"</$_->{NAME}>"} @close;

  # Reopen any we closed early if all that were closed are
  # configured to be auto deinterleaved.
  unless (grep {! exists $auto_deinterleave{$_->{NAME}} } @close) {
    pop @close;
    $html .= join '', map {$_->{FULL}} reverse @close;
    unshift @stack, @close;
  }

  return $html;
}

sub cleanup_cdata {
  local $_ = shift;

  s[ (?: & ( [a-zA-Z0-9]{2,15}       |
             [#][0-9]{2,6}           |
             [#][xX][a-fA-F0-9]{2,6} | ) \b ;?
     ) | (.)
  ][
     defined $1 ? "&$1;" : $escape_html_map{$2}
  ]gesx;

  # substitute newlines in the input for html line breaks if required.
  s%\cM\n%<br />\n%g if $convert_nl;

  return $_;
}

# subroutine to escape the necessary characters to the appropriate HTML
# entities

sub escape_html {
  my $str = shift;
  defined $str or $str = '';
  $str =~ s/([^\w\Q$html_safe_chars\E])/$escape_html_map{$1}/og;
  return $str;
}

# subroutine to unescape escaped HTML entities.  Note that some entites
# have no 8-bit character equivalent, see
# "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent" for some examples.
# unescape_html() leaves these entities in their encoded form.

sub unescape_html {
  my $str = shift;
  $str =~
    s/ &( (\w+) | [#](\d+) ) \b (;?)
     /
       defined $2 && exists $html_entities{$2} ? $html_entities{$2} :
       defined $3 && $3 > 0 && $3 <= 255       ? chr $3             :
       "&$1$4"
     /gex;

  return $str;
}

#
# End of HTML handling code
#
##################################################################
