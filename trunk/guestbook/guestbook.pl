#!/usr/bin/perl -Tw
#
# $Id: guestbook.pl,v 1.2 2001-11-11 17:55:27 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.1.1.1  2001/11/11 16:48:53  davorg
# Initial import
#

use strict;
use POSIX 'strftime';
use CGI qw(param);
use Fcntl qw(:DEFAULT :flock);

# Configuration

my $guestbookurl = 'http://your.host.com/~yourname/guestbook.html';
my $guestbookreal = '/home/yourname/public_html/guestbook.html';
my $guestlog = '/home/yourname/public_html/guestlog.html';
my $cgiurl = 'http://your.host.com/cgi-bin/guestbook.pl';

my $mail = 0;
my $uselog = 1;
my $linkmail = 1;
my $separator = 1;
my $redirection = 0;
my $entry_order = 1;
my $remote_mail = 0;
my $allow_html = 1;
my $line_breaks = 0;

my $mailprog = '/usr/lib/sendmail';
my $recipient = 'you@your.com';

my $long_date_fmt = '%A, %B %d, %Y at %T (%Z)';
my $short_date_fmt = '%D %T %Z';

# End configuration

my @now = localtime;
my $date = strftime($long_date_fmt, @now);
my $shortdate = strftime($short_date_fmt, @now);

my ($username, $realname, $comments)
  = param('username'), param('realname'), param('comments');

my ($city, $state, $country)
  = param('city'), param('state'), param('country');

my ($url)
  = param('url');

&no_comments unless $comments;
&no_name unless $realname;

open (GUEST, "+>$guestbookreal")
  || die "Can't Open $guestbookreal: $!\n";
flock GUEST, LOCK_EX
  || die "Can't lock $guestbookreal: $!\n";

my @lines = <GUEST>;

seek GUEST, 0, 0;
truncate GUEST, 0;

foreach (@lines) {
   if (/<!--begin-->/) {

     if ($entry_order == 1) {
       print GUEST "<!--begin-->\n";
     }

     if ($line_breaks == 1) {
       $comments =~ s/\cM\n/<br>\n/g;
     }

     print GUEST "<b>$comments</b><br>\n";

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
    
     print GUEST "<br>\n";

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
       print GUEST " - $date<hr>\n\n";
     } else {
       print GUEST " - $date<p>\n\n";
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
   &log('entry');
}

if ($mail) {
  open (MAIL, "|$mailprog $recipient") || die "Can't open $mailprog!\n";

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
  &no_redirection;
}

sub no_comments {
  print <<END_FORM;
Content-type: text/html


<html><head><title>No Comments</title></head>
<body><h1>Your Comments appear to be blank</h1>
<p>The comment section in the guestbook fillout form appears
to be blank and therefore the Guestbook Addition was not
added.  Please enter your comments below.</p>
<form method=POST action="$cgiurl">
<p>Your Name:<input type=text name="realname" size=30
           value="$realname"><br>
E-Mail: <input type=text name="username"
         value="$username" size=40><br>
City: <input type=text name="city" value="$city'" 
       size=15>, 
State: <input type=text name="state" 
        value="$state" size=15> 
Country: <input type=text name="country" 
          value="$country" size=15></p>
<p>Comments:<br>
<textarea name="comments" COLS=60 ROWS=4></textarea></p>
<p><input type=submit> * <input type=reset></p></form><hr>
<p>Return to the <a href="$guestbookurl">Guestbook</a>.</p>
</body></html>
END_FORM

  # Log The Error
  if ($uselog) {
    &log('no_comments');
  }

  exit;
}

sub no_name {
  print <<END_FORM;
Content-type: text/html

<html><head><title>No Name</title></head>
<body><h1>Your Name appears to be blank</h1>
<p>The Name Section in the guestbook fillout form appears to
be blank and therefore your entry to the guestbook was not
added.  Please add your name in the blank below.</p>
<form method=POST action="$cgiurl">
<p>Your Name:<input type=text name="realname" size=30><br>
E-Mail: <input type=text name="username"
          value="$username" size=40><br>
City: <input type=text name="city" value="$city" 
       size=15>, 
State: <input type=text name="state" 
        value="$state" size=2> 
Country: <input type=text name="country" value="$country" 
          size=15></p>
<p>Comments have been retained.
<input type=hidden name="comments" value="$comments"></p>
<p><input type=submit> * <input type=reset></p></form><hr>
<p>Return to the <a href="$guestbookurl">Guestbook</a>.
</body></html>

END_FORM

  # Log The Error
  if ($uselog) {
    &log('no_name');
  }

  exit;
}

# Log the Entry or Error
sub log {
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

<html><head><title>Thank You</title></head>
<body><h1>Thank You For Signing The Guestbook</h1>

<p>Thank you for filling in the guestbook.  Your entry has
been added to the guestbook.</p><hr>
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

  print "<br>\n";

  print "$city," if $city;

  print " $state" if $state;

  print " $country" if $country;

  print " - $date<p>\n";

  # Print End of HTML

  print <<END_HTML;

<hr>
<p><a href="$guestbookurl">Back to the Guestbook</a>
- You may need to reload it when you get there to see your
entry.</p>
</body></html>

END_HTML

  exit;
}

