#!/usr/local/bin/perl -wT
#
# $Id: wwwadmin.pl,v 1.13 2002-03-04 09:09:39 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.12  2002/03/03 11:55:06  gellyfish
# * XHTML output from wwwadmin.pl
#
# Revision 1.11  2002/03/03 10:55:14  gellyfish
# * Added POST_MAX etc
# * File locking in wwwboard.pl
# * Started on wwwadmin
#
# Revision 1.10  2002/02/27 09:04:30  gellyfish
# * Added question about simple search and PDF to FAQ
# * Suppressed output of headers in fatalsToBrowser if $done_headers
# * Suppressed output of '<link rel...' if not $style
# * DOCTYPE in fatalsToBrowser
# * moved redirects until after possible cause of failure
# * some small XHTML fixes
#
# Revision 1.9  2002/02/04 21:14:39  dragonoe
# Added header to script and aligned values of parameter settings.
#
# Revision 1.8  2001/12/01 19:45:22  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
# Revision 1.7  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
# Revision 1.6  2001/11/25 11:39:40  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.5  2001/11/24 11:59:58  gellyfish
# * documented strfime date formats is various places
# * added more %ENV cleanup
# * spread more XHTML goodness and CSS stylesheet
# * generalization in wwwadmin.pl
# * sundry tinkering
#
# Revision 1.4  2001/11/19 09:21:44  gellyfish
# * added allow_html functionality
# * fixed potential for pre lock clobbering in guestbook
# * some XHTML toshing
#
# Revision 1.3  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
#

use strict;
use CGI qw(:standard);
use vars qw($DEBUGGING $done_headers);

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 1024 * 20;

# PROGRAM INFORMATION
# -------------------
# wwwadmin.pl v1.9 (part of wwwboard)
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
# parameters seems unclear, please see the
# ADMIN_README file.
#
BEGIN { $DEBUGGING      = 1;}
my $emulate_matts_code  = 1;
my $basedir             = '/var/www/html/wwwboard';
my $baseurl             = 'http://localhost/wwwboard';
my $cgi_url             = 'http://localhost/cgi-bin/wwwadmin.pl';
my $mesgdir             = 'messages';
my $datafile            = 'data.txt';
my $mesgfile            = 'wwwboard.html';
my $passwd_file         = 'passwd.txt';
my $ext                 = 'html';
my $title               = 'NMS WWWBoard Version 1.0';
my $use_time            = 1;
my $style               = '/css/nms.css';
#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)



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

my %HTML;
{
  local $/ = "==\n";

  while (<DATA>) {
    chomp;
    my ($k, $v) = split(/\n--\n/);

    $v =~ s/<!-- STYLE -->/$style_element/;

    $HTML{$k} = $v;
  }
}

print header;
$done_headers++;

# should we be allowing this ISINDEX stuff ?

my $command = $ENV{QUERY_STRING};
my $FORM = parse_form() unless $command;

my @lines;

if ($command eq 'remove') {
  my $html = $HTML{REMOVE_TOP};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

  open(MSGS, "$basedir/$mesgfile")
    || die $!;
  @lines = <MSGS>;
  close(MSGS);

  my ($min, $max);

  foreach my $line (@lines) {
    if (my ($id, $subject, $author, $date) 
        = $line =~ /<!--top: (.*)--><li><a href="\Q$mesgdir\E\/\1\Q.$ext\E">(.*)<\/a> - <b>(.*)<\/b>\s+<i>(.*)<\/i>/) {
      $min = $id if ! defined $min or $id < $min;
      $max = $id if ! defined $max or $id > $max;

      $html = $HTML{REMOVE_MID};
      $html =~ s/(\$\w+)/$1/eeg;
      print $html;
    }
  }

  $html = $HTML{REMOVE_BOT};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

} elsif ($command eq 'remove_by_num') {

  my $html = $HTML{REM_NUM_TOP};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

  open(MSGS,"$basedir/$mesgfile") || die $!;
  my @lines = <MSGS>;
  close(MSGS);

  my ($min, $max, @entries);

  foreach my $line (@lines) {
    if (my ($id, $subject, $author, $date)
        = $line =~ /<!--top: (.*)--><li><a href="$mesgdir\/\1.$ext">(.*)<\/a> - <b>(.*)<\/b>\s+<i>(.*)<\/i>/) {
      $min = $id if ! defined $min or $id < $min;
      $max = $id if ! defined $max or $id > $max;

      push @entries, {id => $1, subject => $2, author => $3, date => $4};
    }
  }

  foreach (sort { $a->{id} <=> $b->{id} } @entries ) {
    my %entry = %$_;
    my ($id, $subject, $author, $date) = @entry{qw(id subject author date)};

    $html = $HTML{REM_NUM_MID};
    $html =~ s/(\$\w+)/$1/eeg;
    print $html;
  }

  $html = $HTML{REM_NUM_BOT};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

} elsif ($command eq 'remove_by_date') {

  my $html = $HTML{REM_DATE_TOP};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

  open(MSGS,"$basedir/$mesgfile") || die $!;
  my @lines = <MSGS>;
  close(MSGS);

  my %entries;
  foreach my $line (@lines) {
    if (my ($id, $date)
        = $line =~ /<!--top: (.*)--><li><a href="$mesgdir\/\1.$ext">.*<\/a> - <b>.*<\/b>\s+<i>(.*)<\/i>/) {

      my $day;
      if ($use_time) {
        (undef, $day) = split(/\s+/, $date);
      } else {
        $day = $date;
      }
      push @{$entries{$day}}, $id;
    }
  }

  foreach my $date (sort keys %entries) {

    my @links = map { qq(<a href="$baseurl/$mesgdir/$_.$ext">$_</a>) }
      @{$entries{$date}};

    my $links = join ' ', @links;
    my $ids = join ' ', @{$entries{$date}};
    my $count = @{$entries{$date}};

    my $html = $HTML{REM_DATE_MID};
    $html =~ s/(\$\w+)/$1/eeg;
    print $html;
  }

  my $dates = join ' ', keys %entries;

  $html = $HTML{REM_DATE_BOT};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

} elsif ($command eq 'remove_by_author') {

  my $html = $HTML{REM_AUTH_TOP};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

  open(MSGS,"$basedir/$mesgfile") || die $!;
  my @lines = <MSGS>;
  close(MSGS);

  my %entries;
  foreach my $line (@lines) {
    if (my ($id, $author)
        = $line =~ /<!--top: (.*)--><li><a href="$mesgdir\/\1\.$ext">.*<\/a> - <b>(.*)<\/b>\s+<i>.*<\/i>/) {
      push @{$entries{$author}}, $id;
    }
  }

  foreach my $author (sort keys %entries) {

    my @links = map { qq(<a href="$baseurl/$mesgdir/$_.$ext">$_</a>) }
      @{$entries{$author}};

    my $links = join ' ', @links;
    my $ids = join ' ', @{$entries{$author}};
    my $count = @{$entries{$author}};

    my $html = $HTML{REM_AUTH_MID};
    $html =~ s/(\$\w+)/$1/eeg;
    print $html;
  }

  my $authors = join ' ', keys %entries;

  $html = $HTML{REM_AUTH_BOT};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

} elsif ($command eq 'change_passwd') {

  my $html = $HTML{PASSWD};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;

} elsif ($FORM->{action} eq 'remove') {

   check_passwd();

   my (@all, @single);
   foreach ($FORM->{'min'} .. $FORM->{'max'}) {
      if ($FORM->{$_} eq 'all') {
         push(@all, $_);
      }
      elsif ($FORM->{$_} eq 'single') {
         push(@single, $_);
      }
   }

   open(MSGS,"$basedir/$mesgfile") || die $!;
   my @lines = <MSGS>;
   close(MSGS);

   my (@attempted, @not_removed, @no_file, @top_bot);

   foreach my $single (@single) {
     foreach (0 .. $#lines) {
       if ($lines[$_] =~ /<!--top: $single-->/) {
         splice(@lines, $_, 3);
         $_ -= 3;
       } elsif ($lines[$_] =~ /<!--end: $single-->/) {
         splice(@lines, $_, 1);
         $_--;
       }
     }
     my $filename = "$basedir/$mesgdir/$single.$ext";
     if (-e $filename) {
       unlink($filename) || push @not_removed, ,$single;
      } else {
         push @no_file, $single;
      }
      push @attempted, $single ;
   }

   foreach my $all (@all) {
     my ($top,  $bottom, @delete);

     foreach (my $j = 0; $j <= @lines; $j++) {
       if ($lines[$j] =~ /<!--top: $all-->/) {
         $top = $j;
       } elsif ($lines[$j] =~ /<!--end: $all-->/) {
         $bottom = $j;
       }
     }
     if ($top && $bottom) {
       my $diff = ($bottom - $top) + 1;
       for (my $k = $top;$k <= $bottom;$k++) {
         if ($lines[$k] =~ /<!--top: (.*)-->/) {
           push(@delete, $1);
         }
       }
       splice(@lines, $top, $diff);
       foreach my $delete (@delete) {
         my $filename = "$basedir/$mesgdir/$delete.$ext";
         if (-e $filename) {
           unlink($filename) || push @not_removed, $delete;
         } else {
           push @no_file, $delete;
         }
         push @attempted,$delete;
       }
     } else {
       push(@top_bot, $all);
     }
   }

   open(WWWBOARD,">$basedir/$mesgfile") || die $!;
   print WWWBOARD @lines;
   close(WWWBOARD);

   return_html($FORM->{type});

} elsif ($FORM->{action} eq 'remove_by_date_or_author') {

   check_passwd();

   my (@attempted, @not_removed, @no_file, @top_bot);

   my @single;
   my @used_values = split(/\s/, $FORM->{used_values});
   foreach my $used_value (@used_values) {
      my @misc_values = split(/\s/,$FORM->{$used_value});
      foreach my $misc_value (@misc_values) {
         push(@single, $misc_value);
      }
   }

   open(WWWBOARD,">$basedir/$mesgfile") || die $!;
   print WWWBOARD @lines;
   close(WWWBOARD);

   return_html($FORM->{type});

} elsif ($FORM->{action} eq 'change_passwd') {

  open(PASSWD,"$basedir/$passwd_file") || error('passwd_file');
  my $passwd_line = <PASSWD>;
  chomp($passwd_line);
  close(PASSWD);

  my ($username, $passwd) = split(/:/,$passwd_line);

  if (!($FORM->{passwd_1} eq $FORM->{passwd_2})) {
    error('not_same');
  }

  my $test_passwd = crypt($FORM->{password}, substr($passwd, 0, 2));
  if ($test_passwd eq $passwd && $FORM->{username} eq $username) {
    open(PASSWD,">$basedir/$passwd_file") || error('no_change');
    my $new_password = crypt($FORM->{passwd_1}, substr($passwd, 0, 2));
    my $new_username;
    if ($FORM->{new_username}) {
      $new_username = $FORM->{'new_username'};
    } else {
      $new_username = $username;
    }
    print PASSWD "$new_username:$new_password";
    close(PASSWD);
  } else {
    error('bad_combo');
  }

  return_html('change_passwd');
} else {
  my $html = $HTML{DEFAULT};
  $html =~ s/(\$\w+)/$1/eeg;
  print $html;
}


sub parse_form {

  my $FORM = {};
  foreach (param()) {
    $FORM->{$_} = param($_);
  }

  return $FORM;
}

sub return_html {
  my $type = $_[0];
  my @NOT_REMOVED;
  my @ATTEMPTED;
  my @NO_FILE;
  my ($mesgpage, $mesgdir, $new_username);

   if ($type eq 'remove') {
      print "<html><head><title>Results of Message Board Removal</title></head>\n";
      print "<body><center><h1>Results of Message Board Removal</h1></center>\n";
   }
   elsif ($type eq 'remove_by_num') {
      print "<html><head><title>Results of Message Board Removal by Number</title></head>\n";
      print "<body><center><h1>Results of Message Board Removal by Number</h1></center>\n";
   }
   elsif ($type eq 'remove_by_date') {
      print "<html><head><title>Results of Message Board Removal by Date</title></head>\n";
      print "<body><center><h1>Results of Message Board Removal by Date</h1></center>\n";
   }
   elsif ($type eq 'remove_by_author') {
      print "<html><head><title>Results of Message Board Removal by Author</title></head>\n";
      print "<body><center><h1>Results of Message Board Removal by Author</h1></center>\n";
   }
   elsif ($type eq 'change_passwd') {
      print "<html><head><title>WWWBoard WWWAdmin Password Changed</title></head>\n";
      print "<body><center><h1>WWWBoard WWWAdmin Password Changed</h1></center>\n";
      print "Your Password for WWWBoard WWWAdmin has been changed!  Results are below:<p><hr size=7 width=75%><p>\n";
      print "<b>New Username: $new_username<p>\n";
      print "New Password: $FORM->{'passwd_1'}</b><p>\n";
      print "<hr size=7 width=75%><p>\n";
      print "Do not forget these, since they are now encoded in a file, and not readable!.\n";
      print "</body></html>\n";
   }
   if ($type =~ /^remove/) {
      print "Below is a short summary of what messages were removed from $mesgpage and the\n";
      print "$mesgdir directory.  All files that the script attempted to remove, were removed,\n";
      print "unless there is an error message stating otherwise.<p><hr size=7 width=75%><p>\n";
 
      print "<b>Attempted to Remove:</b> @ATTEMPTED<p>\n";
      if (@NOT_REMOVED) {
         print "<b>Files That Could Not Be Deleted:</b> @NOT_REMOVED<p>\n";
      }
      if (@NO_FILE) {
         print "<b>Files Not Found:</b> @NO_FILE<p>\n";
      }
      print "<hr size=7 width=75%><center><font size=-1>\n";
      print "[ <a href=\"$cgi_url\?remove\">Remove</a> ] [ <a href=\"$cgi_url\?remove_by_date\">Remove by Date</a> ] [ <a href=\"$cgi_url\?remove_by_author\">Remove by Author</a> ] [ <a href=\"$cgi_url\?remove_by_num\">Remove by Message Number</a> ] [ <a 
href=\"$baseurl/$mesgpage\">$title</a> ]\n";
      print "</font></center><hr size=7 width=75%>\n";
      print "</body></html>\n";
   }
}

sub error {
  my ($error) = @_;
  my $args = {};
   if ($error eq 'bad_combo') {
      $args->{Title} = 'Bad Username - Password Combination';
      $args->{Heading} = 'Bad Username - Password Combination';
      $args->{Body} = "You entered and invalid username password pair.  Please try again.";
   }
   elsif ($error eq 'passwd_file') {
      $args->{Title} = 'Could Not Open Password File For Reading';
      $args->{Heading} = 'Could Not Open Password File For Reading';
      $args->{Body} = "Could not open the password file for reading!  Check permissions and try again.";
   }
   elsif ($error eq 'not_same') {
      $args->{Title} = 'Incorrect Password Type-In';
      $args->{Heading} = 'Incorrect Password Type-In';
      $args->{Body} = "The passwords you typed in for your new password were not the same.\n";
      $args->{Body} .= "You may have mistyped, please try again.\n";
   }
   elsif ($error eq 'no_change') {
      $args->{Title} = 'Could Not Open Password File For Writing';
      $args->{Heading} = 'Could Not Open Password File For Writing';
      $args->{Body} = 'Could not open the password file for writing!  Password not changed!';
   }
   else
   {
     $args->{Title}   = 'Unknown Error';
     $args->{Heading} = 'Unknown Error';
     $args->{Body}    = 'Unknown Error';
   }

   print passwd_error($args);
   exit;
}

sub passwd_error
{
   my ( $args ) = @_;
   return <<TUBBIES_SAY_EO;
$HTML{HTML_DECL}
<hr size="7" width="75%" />
<html>
  <head>
    <title>$args->{Title}</title>
    $style_element;
    <body>
     <center>
       <h1>$args->{Heading}</a> 
     </center>
     <p>
      $args->{Body}
     </p> 
     <center>
       <font size="-1">
         [ <a href="$cgi_url">NMS WWWAdmin</a> ] 
         [ <a href="$baseurl/$mesgfile">$title</a> ]
       </font>
     </center>
     <hr size="7" width="75%" />
   </body>
</html>
TUBBIES_SAY_EO
}

sub check_passwd {
   open(PASSWD,"$basedir/$passwd_file") || error('passwd_file');
   my $passwd_line = <PASSWD>;
   chomp($passwd_line);
   close(PASSWD);

   my ($username,$passwd) = split(/:/,$passwd_line);

   my $test_passwd = crypt($FORM->{'password'}, substr($passwd, 0, 2));
   if (!($test_passwd eq $passwd && $FORM->{'username'} eq $username)) {
      error('bad_combo');
   }
}

__END__
HTML_DECL
--
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
==
REMOVE_TOP
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Remove Messages From WWWBoard</title>
<!-- STYLE -->
</head>
<body>
<center><h1>Remove Messages From WWWBoard</h1></center>
<p>Select below to remove those postings you wish to remove.
Checking the Input Box on the left will remove the whole thread
while checking the Input Box on the right to remove just that posting.</p>
<p>These messages have been left unsorted, so that you can see the order in
which they appear in the $mesgfile page.  This will give you an idea of
what the threads look like and is often more helpful than the sorted method.</p>
<hr size=7 width=75%><p align="center"><font size=-1>
[ <a href="$cgi_url?remove">Remove</a> ] [ <a href="$cgi_url?remove_by_date">Remove by Date</a> ] [ <a href="$cgi_url?remove_by_author">Remove by Author</a> ] [ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ] [ <a href="$baseurl/$mesgpage">$title</a> ]
</font></p><hr size="7" width="75%" /><p>
<form method="POST" action="$cgi_url">
<input type=hidden name="action" value="remove" />
<table border="0" summary="">
<tr>
<th colspan="6">
Username: <input type="text" name="username" /> -- 
Password: <input type=password name="password" /></th>
</tr><tr>
<th>Post \# </th><th>Thread </th><th>Single </th><th>Subject </th><th> Author</th><th> Date</th></tr>
==
REMOVE_MID
--
<tr>
<th><b>$id</b> </th><td><input type=radio name="$id" value="all"></td>
<td><input type=radio name="$id" value="single"> </td>
<td><a href="$baseurl/$mesgdir/$id.$ext">$subject</a></td>
<td>$author</td>
<td>$date<br /></td>
</tr>
==
REMOVE_BOT
--
</table>

<input type="hidden" name="min" value="$min" />
<input type="hidden" name="max" value="$max" />
<input type="hidden" name="type" value="remove" />
<input type="submit" value="Remove Messages" /> <input type="reset" />
</form>
</body></html>
==
REM_NUM_TOP
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Remove Messages From WWWBoard By Number</title>
<!-- STYLE -->
</head>
<body><center><h1>Remove Messages From WWWBoard By Number</h1></center>
<p>Select below to remove those postings you wish to remove.
Checking the Input Box on the left will remove the whole thread
while checking the Input Box on the right to remove just that posting.</p>
<hr size="7" width="75%" />
<center><font size="-1">
[ <a href="$cgi_url?remove">Remove</a> ] 
[ <a href="$cgi_url?remove_by_date">Remove by Date</a> ] 
[ <a href="$cgi_url?remove_by_author">Remove by Author</a> ] 
[ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ] 
[ <a href="$baseurl/$mesgpage">$title</a> ]
</font></center><hr size="7" width="75%" /><p>
<form method="POST" action="$cgi_url">
<input type="hidden" name="action" value="remove" />
<table border="0" summary="">
<tr>
<th colspan="6">
Username: <input type="text" name="username" /> -- 
Password: <input type="password" name="password" /><br /></th>
</tr>
<tr>
<th>Post # </th><th>Thread </th><th>Single </th><th>Subject </th><th> Author</th><th> Date</th></tr>
==
REM_NUM_MID
--
<tr>
<th><b>$id</b> </th><td>
<input type="radio" name="$id" value="all" /></td>
<td><input type="radio" name="$id" value="single" /></td>
<td><a href="$baseurl/$mesgdir/$id.$ext">$subject</a></td>
<td>$author</td>
<td>$date</td>
</tr>
==
REM_NUM_BOT
--
</table>
<center><p>
<input type="hidden" name="min" value="$min" />
<input type="hidden" name="max" value="$max" />
<input type="hidden" name="type" value="remove" />
<input type="submit" value="Remove Messages" /> <input type="reset" />
</form>
</body></html>
==
REM_DATE_TOP
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Remove Messages From WWWBoard By Date</title>
<!-- STYLE -->
</head>
<body><center><h1>Remove Messages From WWWBoard By Date</h1></center>
Select below to remove those postings you wish to remove.
Checking the input box beside a date will remove all postings 
that occurred on that date.
<p>
<hr size="7" width="75%">
<center><font size="-1">
[ <a href="$cgi_url\?remove">Remove</a> ] 
[ <a href="$cgi_url?remove_by_date">Remove by Date</a> ] 
[ <a href="$cgi_url?remove_by_author">Remove by Author</a> ] 
[ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ] 
[ <a href="$baseurl/$mesgpage">$title</a> ]
</font></center><hr size="7" width="75%" />
<p>
<form method="POST" action="$cgi_url">
<input type="hidden" name="action" value="remove_by_date_or_author" />
<input type="hidden" name="type" value="remove_by_date" />
<center>
<table border="0" summary="">
<tr>
<th colspan="4">
Username: <input type="text" name="username"> -- 
Password: <input type="password" name="password"><br /></th>
</tr>
<tr>
<th>X </th>
<th>Date </th>
<th># of Messages </th>
<th>Message Numbers<br></th></tr>
==
REM_DATE_MID
--
<tr>
<td><input type="checkbox" name="$date" value="$ids" /></td>
<th>$date</th>
<td>$count</td>
<td>$links<br></td>
</tr>
==
REM_DATE_BOT
--
</table>
<input type="hidden" name="used_values" value="$dates" />
<input type="submit" value="Remove Messages"> <input type="reset" />
</form></center>
</body></html>
==
REM_AUTH_TOP
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Remove Messages From WWWBoard By Author</title>
<!-- STYLE -->
</head>
<body><center><h1>Remove Messages From WWWBoard By Author</h1></center>
Checking the checkbox beside the name of an author will remove 
all postings which that author has created.
<p>
<hr size="7" width="75%"><center><font size="-1">
[ <a href="$cgi_url?remove">Remove</a> ] 
[ <a href="$cgi_url?remove_by_date">Remove by Date</a> ] 
[ <a href="$cgi_url?remove_by_author">Remove by Author</a> ] 
[ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ] 
[ <a href="$baseurl/$mesgpage">$title</a> ]
</font></center><hr size="7" width="75%" />
<p>
<form method="POST" action="$cgi_url">
<input type="hidden" name="action" value="remove_by_date_or_author" />
<input type="hidden" name="type" value="remove_by_author" />
<center>
<table border="0" summary="">
<tr>
<th colspan=4>
Username: <input type="text" name="username" /> -- 
Password: <input type="password" name="password" /><br /></th>
</tr>
<tr>
<th>X </th><th>Author </th>
<th># of Messages </th><th>Message #'s<br /></th></tr>
==
REM_AUTH_MID
--
<tr>
<td><input type="checkbox" name="$author" value="$ids" /></td>
<th>$author</th>
<td>$count</td>
<td>$links<br /></td>
</tr>
==
REM_AUTH_BOT
--
</table>
<input type="hidden" name="used_values" value="$authors" />
<input type="submit" value="Remove Messages" /> <input type="reset" />
</form></center>
</body></html>
==
PASSWD
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Change WWWBoard Admin Password</title>
<!-- STYLE -->
</head>
<body>
<center><h1>Change WWWBoard Admin Password</h1></center>
Fill out the form below completely to change your password and user name.
If new username is left blank, your old one will be assumed.<p>
<hr size="7" width="75%" /><p>
<form method="POST" action="$cgi_url">
<input type="hidden" name="action" value="change_passwd" />
<center><table border="0" summary="">
<tr>
<th align="left">Username: </th>
<td><input type="text" name="username" /><br /></td>
</tr><tr>
<th align="left">Password: </th>
<td><input type=password name="password" /><br /></td>
</tr><tr> </tr><tr>
<th align="left">New Username: </th>
<td><input type="text" name="new_username" /><br /></td>
</tr><tr>
<th align="left">New Password: </th>
<td><input type="password" name="passwd_1" /><br /></td>
</tr><tr>
<th align="left">Re-type New Password: </th>
<td><input type="password" name="passwd_2" /><br /></td>
</tr><tr>
<td align="center">
<input type="submit" value="Change Password" /> </td>
<td align="center"><input type="reset" /></td>
</tr></table></center>
</form></body></html>
==
DEFAULT
--
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>WWWAdmin For WWWBoard</title>
<!-- STYLE -->
</head>
<body bgcolor="#FFFFFF" text="#000000"><center>
<h1>WWWAdmin For WWWBoard</h1></center>
<p>Choose your Method of modifying WWWBoard Below:</p>
<hr size="7" width="75%" /><br />
<ul>
<li>Remove Files
<ul>
<li><a href="$cgi_url?remove">Remove Files</a>
<li><a href="$cgi_url?remove_by_num">Remove Files by Mesage Number</a>
<li><a href="$cgi_url?remove_by_date">Remove Files by Date</a>
<li><a href="$cgi_url?remove_by_author">Remove Files by Author</a>
</ul><br />
<li>Password
<ul>
<li><a href="$cgi_url?change_passwd">Change Admin Password</a>
</ul>
</ul>
