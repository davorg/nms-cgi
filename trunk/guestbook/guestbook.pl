#!/usr/bin/perl -Tw
#
# $Id: guestbook.pl,v 1.10 2001-11-25 11:39:38 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
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
use POSIX 'strftime';
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:DEFAULT :flock :seek);

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
my $allow_html  = 1;
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


BEGIN
{
   my $error_message = sub {
                             my ($message ) = @_;
                             print "<h1>It's all gone horribly wrong</h1>";
                             print $message if $DEBUGGING;
                            };
  set_message($error_message);
}   

my @now       = localtime();
my $date      = strftime($long_date_fmt, @now);
my $shortdate = strftime($short_date_fmt, @now);

my ($username, $realname, $comments)
  = (param('username'), param('realname'), param('comments'));

my ($city, $state, $country)
  = (param('city'), param('state'), param('country'));

my ($url)
  = param('url');

no_comments() unless $comments;
no_name()     unless $realname;

# crudely Strip out HTML unless we are allowing it
# usually one would use HTML::Parser

$comments =~ s/(?:<[^>'"]*|".*?"|'.*?')+>//gs unless $allow_html;

# substitute newlines in the comments for html line breaks if required.

$comments =~ s%\cM\n%<br />\n%g if $line_breaks;


open (GUEST, "+<$guestbookreal")
  || die "Can't Open $guestbookreal: $!\n";
flock GUEST, LOCK_EX
  || die "Can't lock $guestbookreal: $!\n";

my @lines = <GUEST>;

seek GUEST, SEEK_SET, 0;
truncate GUEST, 0;

foreach (@lines) {
   if (/<!--begin-->/) {

     if ($entry_order == 1) {
       print GUEST "<!--begin-->\n";
     }


     print GUEST "<b>$comments</b><br />\n";

     if ($url) {
       print GUEST qq(<a href="$url">$realname</a>);
      } else {
         print GUEST $realname;
      }

     if ($username){
       if ($linkmail) {
	 print GUEST qq( &lt;<a href="mailto:$username">);
	 print GUEST "$username</a>&gt;";
       } else {
	 print GUEST " &lt;$username&gt;";
       }
     }

     print GUEST "<br />\n";

     if ($city){
       print GUEST "$city, ";
     }

     if ($state){
       print GUEST $state;
     }

     if ($country){
       print GUEST " country";
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

if ($uselog) {
   write_log('entry');
}

if ($mail) {
  open (MAIL, "|$mailprog") || die "Can't open $mailprog!\n";

  print MAIL "To: $recipient\n";
  print MAIL "Reply-to: $username ($realname)\n";
  print MAIL "From: $username ($realname)\n";
  print MAIL "Subject: Entry to Guestbook\n\n";
  print MAIL "You have a new entry in your guestbook:\n\n";
  print MAIL "------------------------------------------------------\n";
  print MAIL "$comments\n";
  print MAIL "$realname";

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

if ($remote_mail && $username) {
  open (MAIL, "|$mailprog -t") || die "Can't open $mailprog!\n";

  print MAIL "To: $username\n";
  print MAIL "From: $recipient\n";
  print MAIL "Subject: Entry to Guestbook\n\n";
  print MAIL "Thank you for adding to my guestbook.\n\n";
  print MAIL "------------------------------------------------------\n";
  print MAIL "$comments\n";
  print MAIL "$realname";

  print MAIL " <$username>" if $username;

  print MAIL "\n";

  print MAIL "$city," if $city;

  print MAIL " $state" if $state;

  print MAIL " $country" if $country;

  print MAIL " - $date\n";
  print MAIL "------------------------------------------------------\n";

  close (MAIL);
}

# Print Out Initial Output Location Heading
if ($redirection) {
  print "Location: $guestbookurl\n\n";
} else {
  no_redirection();
}

sub no_comments {
  print <<END_FORM;
Content-type: text/html

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>No Comments</title>
     <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1>Your Comments appear to be blank</h1>
    <p>The comment section in the guestbook fillout form appears
      to be blank and therefore the Guestbook Addition was not
      added.  Please enter your comments below.</p>
    <form method="post" action="$cgiurl">
      <p>Your Name:<input type="text" name="realname" size="30"
                          value="$realname" /><br />
        E-Mail: <input type=text name="username"
                       value="$username" size="40" /><br />
        City: <input type="text" name="city" value="$city" 
                     size="15" />, 
        State: <input type="text" name="state" 
                      value="$state" size="15" /> 
        Country: <input type="text" name="country" 
                        value="$country" size="15" /></p>
      <p>Comments:<br>
        <textarea name="comments" cols="60" rows="4"></textarea></p>
      <p><input type="submit" /> * <input type="reset" /></p>
    </form>
    <hr />
    <p>Return to the <a href="$guestbookurl">Guestbook</a>.</p>
  </body>
</html>
END_FORM

  # Log The Error
  if ($uselog) {
    write_log('no_comments');
  }

  exit;
}

sub no_name {
  print <<END_FORM;
Content-type: text/html

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>No Name</title>
     <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1>Your Name appears to be blank</h1>
    <p>The Name Section in the guestbook fillout form appears to
      be blank and therefore your entry to the guestbook was not
      added.  Please add your name in the blank below.</p>
    <form method="post" action="$cgiurl">
      <p>Your Name: <input type="text" name="realname" size="30" /><br />
        E-Mail: <input type="text" name="username"
                       value="$username" size="40" /><br />
        City: <input type="text" name="city" value="$city" 
                     size="15" />, 
        State: <input type="text" name="state" 
                      value="$state" size="2" /> 
        Country: <input type="text" name="country" value="$country" 
                        size="15" /></p>
      <p>Comments have been retained.
        <input type="hidden" name="comments" value="$comments"></p>
      <p><input type="submit"> * <input type="reset"></p>
    </form>
    <hr />
    <p>Return to the <a href="$guestbookurl">Guestbook</a>.
  </body>
</html>

END_FORM

  # Log The Error
  if ($uselog) {
    write_log('no_name');
  }

  exit;
}

# Log the Entry or Error
sub write_log {
  my $log_type = $_[0];
  open(LOG, ">>$guestlog")
    or die "Can't open log file: $!\n";
  flock LOG, LOCK_EX
    or die "Can't lock log file: $!\n";

  if ($log_type eq 'entry') {
    print LOG "$ENV{REMOTE_HOST} - [$shortdate]<br>\n";
  } elsif ($log_type eq 'no_name') {
    print LOG "$ENV{REMOTE_HOST} - [$shortdate] - ERR: No Name<br>\n";
  } elsif ($log_type eq 'no_comments') {
    print LOG "$ENV{REMOTE_HOST} - [$shortdate] - ERR: No ";
    print LOG "Comments<br>\n";
  }
}

# Redirection Option
sub no_redirection {

  print <<END_HTML;
Content-Type: text/html

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
    print qq(<a href="$url">$realname</a>);
   } else {
     print $realname;
   }

  if ($username){
    if ($linkmail) {
      print qq( &lt;<a href="mailto:$username">);
      print "$username</a>&gt;";
    } else {
      print " &lt;$username&gt;";
    }
  }

  print "<br />\n";

  print "$city," if $city;

  print " $state" if $state;

  print " $country" if $country;

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

