#!/usr/bin/perl -Tw
#
# $Id: wwwadmin.pl,v 1.26 2004-07-23 21:13:17 codehelpgpg Exp $
#

use strict;
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(locale_h strftime);
use vars qw(
  $DEBUGGING $VERSION $done_headers $emulate_matts_code
  $basedir $baseurl $cgi_url $mesgdir $datafile $mesgfile
  $passwd_file $ext $title $style $locale $charset
);
BEGIN { $VERSION = substr q$Revision: 1.26 $, 10, -1; }

# PROGRAM INFORMATION
# -------------------
# wwwadmin.pl $Revision: 1.26 $
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For a list of changes see CHANGELOG
#
# For help on configuration or installation see ADMIN_README
#
# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#

BEGIN
{
  $DEBUGGING           = 1;
  $emulate_matts_code  = 1;
  $basedir             = '/var/www/nms-test/wwwboard';
  $baseurl             = 'http://nms-test/wwwboard';
  $cgi_url             = 'http://nms-test/cgi-bin/wwwadmin.pl';
  $mesgdir             = 'messages';
  $datafile            = 'data.txt';
  $mesgfile            = 'wwwboard.html';
  $passwd_file         = 'passwd.txt';
  $ext                 = 'html';
  $title               = "NMS WWWBoard Version $VERSION";
  $style               = '/css/nms.css';
  $locale              = '';
  $charset             = 'iso-8859-1';

#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)


  eval { sub SEEK_SET() {0;} } unless defined(&SEEK_SET);

  use vars qw($html_style);
  $html_style = $style ?
                qq%<link rel="stylesheet" type="text/css" href="$style" />%
              : '';
}

$done_headers = 0;

sub html_header {
    if ($CGI::VERSION >= 2.57) {
        # This is the correct way to set the charset
        print header('-type'=>'text/html', '-charset'=>$charset);
    }
    else {
        # However CGI.pm older than version 2.57 doesn't have the
        # -charset option so we cheat:
        print header('-type' => "text/html; charset=$charset");
    }
}

# We need finer control over what gets to the browser and the CGI::Carp
# set_message() is not available everywhere :(
# This is basically the same as what CGI::Carp does inside but simplified
# for our purposes here.


BEGIN
{
   sub fatalsToBrowser
   {

      my ($message) = @_;

      if ( $DEBUGGING )
      {
         $message =~ s/</&lt;/g;
         $message =~ s/>/&gt;/g;
      }
      else
      {
         $message = '';
      }

      my ( $pack, $file, $line, $sub ) = caller(0);
      my ($id ) = $file =~ m%([^/]+)$%;

      return undef if $file =~ /^\(eval/;

      html_header() unless $done_headers;

      print <<EOERR;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Error</title>
  </head>
  <body>
     <h1>Application Error</h1>
     <p>$message
     An error has occurred in the program.
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


use vars qw($cs);
$cs = CGI::NMS::Charset->new($charset);

# %E is a fake hash for escaping HTML metachars as things are
# interploted into strings.
use vars qw(%E);
tie %E, __PACKAGE__;
sub TIEHASH { bless {}, shift }
sub FETCH { $cs->escape($_[1]) }


# We don't need file uploads or very large POST requests.
# Annoying locution to shut up 'used only once' warning in
# older perl.  Localize these to avoid stomping on other
# scripts that need file uploads under Apache::Registry.

local ($CGI::DISABLE_UPLOADS, $CGI::POST_MAX);
$CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX        = 1000000;


# Empty the environment of potentially harmful variables,
# and detaint the path.  We accept anything in the path
# because $ENV{PATH} is trusted for a CGI script, and in
# general we have no way to tell what should be there.

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} =~ /(.*)/ and $ENV{PATH} = $1;


use vars qw(%HTML);

html_header();
$done_headers = 1;


if (request_method eq 'post') {
  my $FORM = parse_form();
  check_passwd($FORM);

  open LOCK, ">>$basedir/.lock" or die "open >>$basedir/.lock: $!";
  flock LOCK, LOCK_EX or die "flock $basedir/.lock: $!";

  run_command($FORM);

  close LOCK;
}
else {
  my $command = $ENV{QUERY_STRING} || '';
  if ($command =~ /^(\w+)$/) {
    display_form($1);
  }
  else {
    display_form('');
  }
}

sub display_form {
  my ($command) = @_;
  $command = uc $command;
  defined $HTML{"TOP_$command"} or $command = 'DEFAULT';

  print $HTML{HTML_DECL};
  print $HTML{"TOP_$command"};
  return if $command =~ /DEFAULT|CHANGE_PASSWD/;

  my $messages = parse_message_list("$basedir/$mesgfile");

  my $loop_over;
  if ($command eq 'REMOVE') {
    $loop_over = $messages;
  }
  elsif ($command eq 'REMOVE_BY_NUM') {
    $loop_over = [ reverse sort { $a->{id} <=> $b->{id} } @$messages ];
  }
  elsif ($command eq 'REMOVE_BY_DATE') {
    foreach my $msg (@$messages) {
      my $date = $msg->{date};
      $date =~ /(\S+)$/ and $date = $1; # remove time part if present
      $msg->{grouping_key} = $date;
    }
    $loop_over = group_messages($messages);
  }
  elsif ($command eq 'REMOVE_BY_AUTHOR') {
    foreach my $msg (@$messages) {
      $msg->{grouping_key} = $msg->{author};
    }
    $loop_over = group_messages($messages);
  }
  else {
    die "invalid command [$command]";
  }

  foreach my $item (@$loop_over) {
     print template("MID_$command", $item);
  }

  print $HTML{"BOT_$command"};
}

sub group_messages {
  my ($messages) = @_;

  my %bykey = ();
  foreach my $msg (@$messages) {
    my $k = $msg->{grouping_key};
    exists $bykey{$k} or $bykey{$k} = [];
    push @{ $bykey{$k} }, $msg->{id};
  }

  my @grouped = ();
  foreach my $key (sort keys %bykey) {

    my @links = map { qq(<a href="$E{"$baseurl/$mesgdir/$_.$ext"}">$E{$_}</a>) }
      @{ $bykey{$key} };

    my $html_links = join ' ', @links;
    my $ids = join '_', @{$bykey{$key}};
    my $count = @{$bykey{$key}};

    push @grouped, { key        => $key,
                     html_links => $html_links,
                     ids        => $ids,
                     count      => $count,
                   };
  }

  return \@grouped;
}

sub run_command {
  my ($FORM) = @_;

  if ($FORM->{action} =~ /remove/) {
    remove_messages($FORM);
  }
  elsif ($FORM->{action} eq 'change_passwd') {
    #change_passwd($FORM);
  }
  else {
    display_form('');
  }
}

sub remove_messages {
  my ($FORM) = @_;

  my (%del_id, %del_thread);

  foreach my $key (keys %$FORM) {
    if ($key =~ /^([\d_]+)$/ and $FORM->{$key} eq 'these') {
      foreach my $id (split /_/, $1) {
        $del_id{$id} = 1;
      }
    }
    elsif ($key =~ /^(\d+)$/) {
      $del_id{$1}     = 1 if $FORM->{$1} eq 'single';
      $del_thread{$1} = 1 if $FORM->{$1} eq 'all';
    }
  }

  my %to_delete = ();

  open MESG_IN, "<$basedir/$mesgfile" or die "open: $!";
  open MESG_OUT, ">$basedir/$mesgfile.tmp" or die "open: $!";
  local $_;
  my $in_dead_thread = 0;
  while(<MESG_IN>) {

    if (/<!--(top|responses|insert|end):\s*(\d+)-->/) {
      my ($marker, $id) = ($1, $2);

      if ($in_dead_thread) {
        if ($marker eq 'end' and $id == $in_dead_thread) {
          $in_dead_thread = 0;
        }
        $to_delete{$id} = 1;
      }
      elsif ($marker eq 'top' and exists $del_thread{$id}) {
        $in_dead_thread = $id;
        $to_delete{$id} = 1;
      }
      elsif (exists $del_id{$id}) {
        $to_delete{$id} = 1;
      }
      else {
        print MESG_OUT $_;
      }
    }
    else {
      print MESG_OUT $_;
    }

  }

  unless (close MESG_OUT) {
    my $err = $@;
    unlink "$basedir/$mesgfile.tmp";
    die "close $basedir/$mesgfile.tmp: $!";
  }

  rename "$basedir/$mesgfile.tmp", "$basedir/$mesgfile"
    or die "replace $basedir/$mesgfile: $!";

  my @attempted = sort { $a <=> $b } keys %to_delete;
  my (@not_removed, @no_file);
  foreach my $file (@attempted) {
    my $filename = "$basedir/$mesgdir/$file.$ext";
    if (-e $filename) {
      unlink($filename) || push @not_removed, $file;
    } else {
       push @no_file, $file;
    }
  }

  my $html_report = "<b>Attempted to Remove:</b> $E{join(' ',@attempted)}<p>\n"; #'
  if (@not_removed) {
    $html_report .= "<b>Files That Could Not Be Deleted:</b> $E{join(' ',@not_removed)}<p>\n"; #'
  }
  if (@no_file) {
    $html_report .= "<b>Files Not Found:</b> $E{join(' ',@no_file)}<p>\n";
  }#'

  print $HTML{HTML_DECL};
  print template("REMOVE_RESULTS",
                 { html_report => $html_report, remove_by => $FORM->{type} },
                );
}

sub change_passwd {
  my ($FORM) = @_;

  open(PASSWD,"<$basedir/$passwd_file") || error('passwd_file');
  my $passwd_line = <PASSWD>;
  chomp($passwd_line);
  close(PASSWD);

  my ($username, $passwd) = split(/:/,$passwd_line);

  if ($FORM->{passwd_1} ne $FORM->{passwd_2}) {
    error('not_same');
  }

  open(PASSWD,">$basedir/$passwd_file.tmp") || error('no_change');
  my $new_password = crypt($FORM->{passwd_1}, substr($passwd, 0, 2));
  my $new_username;
  if ($FORM->{new_username}) {
    $new_username = $FORM->{'new_username'};
  } else {
    $new_username = $username;
  }
  print PASSWD "$new_username:$new_password";
  close(PASSWD) or die "close: $!";

  rename "$basedir/$passwd_file.tmp", "$basedir/$passwd_file"
     or die "rename: $!";

  print $HTML{HTML_DECL};
  print template("CHANGE_PASSWD_RESULTS",
                 { new_username => $new_username, new_password => $FORM->{passwd_1} }
                );

}

sub parse_form {

  my $FORM = {};
  foreach (param()) {
    $FORM->{$_} = param($_);
  }

  return $FORM;
}

sub error {
  my ($error) = @_;

  my $args = {};
   if ($error eq 'bad_combo') {
      $args->{Title} = 'Bad Username - Password Combination';
      $args->{Body} = "You entered and invalid username password pair.  Please try again.";
   }
   elsif ($error eq 'passwd_file') {
      $args->{Title} = 'Could Not Open Password File For Reading';
      $args->{Body} = "Could not open the password file for reading!  Check permissions and try again.";
   }
   elsif ($error eq 'not_same') {
      $args->{Title} = 'Incorrect Password Type-In';
      $args->{Body} = "The passwords you typed in for your new password were not the same.\n";
      $args->{Body} .= "You may have mistyped, please try again.\n";
   }
   elsif ($error eq 'no_change') {
      $args->{Title} = 'Could Not Open Password File For Writing';
      $args->{Body} = 'Could not open the password file for writing!  Password not changed!';
   }
   else
   {
     $args->{Title}   = 'Unknown Error';
     $args->{Body}    = "Unknown Error: $error";
   }

   print $HTML{HTML_DECL}, template("ERROR_PAGE", $args);
   exit;
}

sub check_passwd {
   my ($FORM) = @_;

   open(PASSWD,"<$basedir/$passwd_file") || error('passwd_file');
   my $passwd_line = <PASSWD>;
   chomp($passwd_line);
   close(PASSWD);

   my ($username,$passwd) = split(/:/,$passwd_line);

   my $test_passwd = crypt($FORM->{'password'}, substr($passwd, 0, 2));
   if (!($test_passwd eq $passwd && $FORM->{'username'} eq $username)) {
      error('bad_combo');
   }
}

sub parse_message_list {
  my $filename = shift;

  my @messages = ();
  local $_;

  open MESG_IN, "<$filename" or die "open $filename: $!";
  while(<MESG_IN>) {
    if (m#<!--top: (\d+)-->(?:</li>)?<li><a href="[^"]+">(.*)<\/a> - <b>(.*)<\/b>\s*<i>(.*)<\/i>#) {
      my $msg = { id => $1, subject => $2, author => $3, date => $4 };

      push @messages, $msg;
    }
  }
  close MESG_IN;

  return \@messages;
}

sub template {
  my ($template, $vars) = @_;

  my $html = $HTML{$template} or die "no such template as [$template]";
  $html =~ s#\[\% \s* (html_\w+) \s* \%\]#     $vars->{$1}   #gex;
  $html =~ s#\[\% \s* (\w+)      \s* \%\]# $E{ $vars->{$1} } #gex;
  return $html;
}

BEGIN
{
  %HTML = (

    HTML_DECL => <<'END',
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
END

    TOP_REMOVE => <<"END",
<head>
<title>Remove Messages From WWWBoard</title>
$html_style
</head>
<body>
<center><h1>Remove Messages From WWWBoard</h1></center>
<p>Select below to remove those postings you wish to remove.
Checking the Input Box on the left will remove the whole thread
while checking the Input Box on the right to remove just that posting.</p>
<p>These messages have been left unsorted, so that you can see the order in
which they appear in the $mesgfile page.  This will give you an idea of
what the threads look like and is often more helpful than the sorted method.</p>
<hr size="7" width="75%"/><p align="center"><font size="-1">
[ <a href="$cgi_url?remove">Remove</a> ] [ <a href="$cgi_url?remove_by_date">Remove by Date</a> ] [ <a href="$cgi_url?remove_by_author">Remove by Author</a> ] [ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ] [ <a href="$baseurl/$mesgfile">$title</a> ]
</font></p><hr size="7" width="75%" />
<form method="post" action="$cgi_url">
<div><input type="hidden" name="action" value="remove" />
<table border="0" summary="">
<tr>
<th colspan="7">
Username: <input type="text" name="username" /> --
Password: <input type="password" name="password" /></th>
</tr><tr>
<th>Post #
</th><th>Thread </th><th>None</th>
<th>Single </th><th>Subject </th><th> Author</th><th> Date</th></tr>
END

    MID_REMOVE => <<"END",
<tr>
<th><b>[% id %]</b> </th><td><input type="radio" name="[% id %]" value="all"/></td>
<td><input type="radio" name="[% id %]" value="0" checked="checked" /></td>
<td><input type="radio" name="[% id %]" value="single"/> </td>
<td><a href="$baseurl/$mesgdir/[% id %].$ext">[% subject %]</a></td>
<td>[% author %]</td>
<td>[% date %]<br /></td>
</tr>
END

    BOT_REMOVE => <<"END",
</table>
<input type="hidden" name="type" value="" />
<input type="submit" value="Remove Messages" /> <input type="reset" />
</div></form>
</body></html>
END

    TOP_REMOVE_BY_NUM => <<"END",
<head><title>Remove Messages From WWWBoard By Number</title>
$html_style
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
[ <a href="$baseurl/$mesgfile">$title</a> ]
</font></center><hr size="7" width="75%" />
<form method="post" action="$cgi_url"><div>
<input type="hidden" name="action" value="remove" />
<table border="0" summary="">
<tr>
<th colspan="7">
Username: <input type="text" name="username" /> --
Password: <input type="password" name="password" /><br /></th>
</tr>
<tr>
<th>Post #
</th><th>Thread </th><th>None</th>
<th>Single </th><th>Subject </th><th> Author</th><th> Date</th></tr>
END

    MID_REMOVE_BY_NUM => <<"END",
<tr>
<th><b>[% id %]</b> </th><td>
<input type="radio" name="[% id %]" value="all" /></td>
<td><input type="radio" name="[% id %]" value="0" checked="checked" /></td>
<td><input type="radio" name="[% id %]" value="single" /></td>
<td><a href="$baseurl/$mesgdir/[% id %].$ext">[% subject %]</a></td>
<td>[% author %]</td>
<td>[% date %]</td>
</tr>
END

    BOT_REMOVE_BY_NUM => <<"END",
</table>
<center><p>
<input type="hidden" name="type" value=" By NUmber" /></p></center>
<input type="submit" value="Remove Messages" /> <input type="reset" />
</div></form>
</body></html>
END

    TOP_REMOVE_BY_DATE => <<"END",
<head>
<title>Remove Messages From WWWBoard By Date</title>
$html_style
</head>
<body><center><h1>Remove Messages From WWWBoard By Date</h1></center>
<p>Select below to remove those postings you wish to remove.
Checking the input box beside a date will remove all postings
that occurred on that date.
</p>
<hr size="7" width="75%"/>
<center><font size="-1">
[ <a href="$cgi_url?remove">Remove</a> ]
[ <a href="$cgi_url?remove_by_date">Remove by Date</a> ]
[ <a href="$cgi_url?remove_by_author">Remove by Author</a> ]
[ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ]
[ <a href="$baseurl/$mesgfile">$title</a> ]
</font></center><hr size="7" width="75%" />
<form method="post" action="$cgi_url"><div>
<input type="hidden" name="action" value="remove_by_date_or_author" />
<input type="hidden" name="type" value=" By Date" />
<center>
<table border="0" summary="">
<tr>
<th colspan="4">
Username: <input type="text" name="username" /> --
Password: <input type="password" name="password" /><br /></th>
</tr>
<tr>
<th>X </th>
<th>Date </th>
<th># of Messages </th>
<th>Message Numbers<br /></th></tr>
END

    MID_REMOVE_BY_DATE => <<"END",
<tr>
<td><input type="checkbox" name="[% ids %]" value="these" /></td>
<th>[% key %]</th>
<td>[% count %]</td>
<td>[% html_links %]<br /></td>
</tr>
END

    BOT_REMOVE_BY_DATE => <<"END",
</table>
<input type="submit" value="Remove Messages" /> <input type="reset" />
</center></div></form>
</body></html>
END

    TOP_REMOVE_BY_AUTHOR => <<"END",
<head>
<title>Remove Messages From WWWBoard By Author</title>
$html_style
</head>
<body><center><h1>Remove Messages From WWWBoard By Author</h1></center>
<p>Checking the checkbox beside the name of an author will remove
all postings which that author has created.
</p>
<hr size="7" width="75%"/><center><font size="-1">
[ <a href="$cgi_url?remove">Remove</a> ]
[ <a href="$cgi_url?remove_by_date">Remove by Date</a> ]
[ <a href="$cgi_url?remove_by_author">Remove by Author</a> ]
[ <a href="$cgi_url?remove_by_num">Remove by Message Number</a> ]
[ <a href="$baseurl/$mesgfile">$title</a> ]
</font></center><hr size="7" width="75%" />
<form method="post" action="$cgi_url"><div>
<input type="hidden" name="action" value="remove_by_date_or_author" />
<input type="hidden" name="type" value=" by Author" />
<center>
<table border="0" summary="">
<tr>
<th colspan="4">
Username: <input type="text" name="username" /> --
Password: <input type="password" name="password" /><br /></th>
</tr>
<tr>
<th>X </th><th>Author </th>
<th># of Messages </th><th>Message #'s<br /></th></tr>
END

    MID_REMOVE_BY_AUTHOR => <<"END",
<tr>
<td><input type="checkbox" name="[% ids %]" value="these" /></td>
<th>[% key %]</th>
<td>[% count %]</td>
<td>[% html_links %]<br /></td>
</tr>
END

    BOT_REMOVE_BY_AUTHOR => <<"END",
</table>
<input type="submit" value="Remove Messages" /> <input type="reset" />
</center></div></form>
</body></html>
END

    TOP_CHANGE_PASSWD => <<"END",
<head><title>Change WWWBoard Admin Password</title>
$html_style
</head>
<body>
<center><h1>Change WWWBoard Admin Password</h1></center>
Fill out the form below completely to change your password and user name.
If new username is left blank, your old one will be assumed.<p>
<hr size="7" width="75%" />
<form method="post" action="$cgi_url"><div>
<input type="hidden" name="action" value="change_passwd" />
<center><table border="0" summary="">
<tr>
<th align="left">Username: </th>
<td><input type="text" name="username" /><br /></td>
</tr><tr>
<th align="left">Password: </th>
<td><input type="password" name="password" /><br /></td>
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
</tr></table></center></div>
</form></body></html>
END

    TOP_DEFAULT => <<"END",
<head><title>WWWAdmin For WWWBoard</title>
$html_style
</head>
<body bgcolor="#FFFFFF" text="#000000"><center>
<h1>WWWAdmin For WWWBoard</h1></center>
<p>Choose your Method of modifying WWWBoard Below:</p>
<hr size="7" width="75%" /><br />
<ul>
<li>Remove Files
<ul>
<li><a href="$cgi_url?remove">Remove Files</a>
<li><a href="$cgi_url?remove_by_num">Remove Files by Message Number</a>
<li><a href="$cgi_url?remove_by_date">Remove Files by Date</a>
<li><a href="$cgi_url?remove_by_author">Remove Files by Author</a>
</ul><br />
<li>Password
<ul>
<li><a href="$cgi_url?change_passwd">Change Admin Password</a>
</ul>
</ul>
</body></html>
END

    CHANGE_PASSWD_RESULTS => <<"END",
<head><title>WWWBoard WWWAdmin Password Changed</title>
$html_style
</head>
<body><center><h1>WWWBoard WWWAdmin Password Changed</h1></center>
Your Password for WWWBoard WWWAdmin has been changed!  Results are below:<p><hr size="7" width="75%" /><p>
<b>New Username: [% new_username %]<p>
New Password: [% new_password %]</b><p>
<hr size="7" width="75%" /><p>
Do not forget these, since they are now encoded in a file, and not readable!.
</body></html>
END

    REMOVE_RESULTS => <<"END",
<head><title>Results of Message Board Removal[% remove_by %]</title>
$html_style
</head>
<body><center><h1>Results of Message Board Removal[% remove_by %]</h1></center>
Below is a short summary of what messages were removed from $mesgfile and the
$mesgdir directory.  All files that the script attempted to remove, were removed,
unless there is an error message stating otherwise.
<p><hr size="7" width="75%"/><p>
[% html_report %]
<hr size="7" width="75%"/><center><font size="-1">
[ <a href=\"$cgi_url\?remove\">Remove</a> ]
[ <a href=\"$cgi_url\?remove_by_date\">Remove by Date</a> ]
[ <a href=\"$cgi_url\?remove_by_author\">Remove by Author</a> ]
[ <a href=\"$cgi_url\?remove_by_num\">Remove by Message Number</a> ]
[ <a href=\"$baseurl/$mesgfile\">$title</a> ]
</font></center><hr size="7" width="75%"/>
</body></html>
END

    ERROR_PAGE => <<"END",
<head><title>[% Title %]</title>
$html_style
</head>
<body>
<center><h1>[% Title %]</h1></center>
<p>
[% Body %]
</p>
<center>
<font size="-1">
[ <a href="$cgi_url">NMS WWWAdmin</a> ]
[ <a href="$baseurl/$mesgfile">$title</a> ]
</font>
</center>
<hr size="7" width="75%" />
</body></html>
END

  );
}

###################################################################

BEGIN {
  eval 'local $SIG{__DIE__} ; require CGI::NMS::Charset';
  $@ and $INC{'CGI/NMS/Charset.pm'} = 1;
  $@ and eval <<'END_CGI_NMS_CHARSET' || die $@;

## BEGIN INLINED CGI::NMS::Charset
package CGI::NMS::Charset;
use strict;

require 5.00404;

use vars qw($VERSION);
$VERSION = sprintf '%d.%.2d', (q$revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

CGI::NMS::Charset - a charset-aware object for handling text strings

=head1 SYNOPSIS

   my $cs = CGI::NMS::Charset->new('iso-8859-1');

   my $safe_to_put_in_html = $cs->escape($untrusted_user_input);

   my $printable = &{ $cs->strip_nonprint_coderef }( $input );
   my $escaped = &{ $cs->escape_html_coderef }( $printable );

=head1 DESCRIPTION

Each object of class C<CGI::NMS::Charset> is bound to a particular
character set when it is created.  The object provides methods to
generate coderefs to perform a couple of character set dependent
operations on text strings.

=cut

=head1 CONSTRUCTORS

=over

=item new ( CHARSET )

Creates a new C<CGI::NMS::Charset> object, suitable for handing text
in the character set CHARSET.  The CHARSET parameter must be a
character set string, such as C<us-ascii> or C<utf-8> for example.

=cut

sub new
{
   my ($pkg, $charset) = @_;

   my $self = { CHARSET => $charset };

   if ($charset =~ /^utf-8$/i)
   {
      $self->{SN} = \&_strip_nonprint_utf8;
      $self->{EH} = \&_escape_html_utf8;
   }
   elsif ($charset =~ /^iso-8859/i)
   {
      $self->{SN} = \&_strip_nonprint_8859;
      if ($charset =~ /^iso-8859-1$/i)
      {
         $self->{EH} = \&_escape_html_8859_1;
      }
      else
      {
         $self->{EH} = \&_escape_html_8859;
      }
   }
   elsif ($charset =~ /^us-ascii$/i)
   {
      $self->{SN} = \&_strip_nonprint_ascii;
      $self->{EH} = \&_escape_html_8859_1;
   }
   else
   {
      $self->{SN} = \&_strip_nonprint_weak;
      $self->{EH} = \&_escape_html_weak;
   }

   return bless $self, $pkg;
}

=back

=head1 METHODS

=over

=item charset ()

Returns the CHARSET string that was passed to the constructor.

=cut

sub charset
{
   my ($self) = @_;

   return $self->{CHARSET};
}

=item escape ( STRING )

Returns a copy of STRING with runs of non-printable characters
replaced with spaces and HTML metacharacters replaced with the
equivalent entities.

If STRING is undef then the empty string will be returned.

=cut

sub escape
{
   my ($self, $string) = @_;

   return &{ $self->{EH} }(  &{ $self->{SN} }($string)  );
}

=item strip_nonprint_coderef ()

Returns a reference to a sub to replace runs of non-printable
characters with spaces, in a manner suited to the charset in
use.

The returned coderef points to a sub that takes a single readonly
string argument and returns a modified version of the string.  If
undef is passed to the function then the empty string will be
returned.

=cut

sub strip_nonprint_coderef
{
   my ($self) = @_;

   return $self->{SN};
}

=item escape_html_coderef ()

Returns a reference to a sub to escape HTML metacharacters in
a manner suited to the charset in use.

The returned coderef points to a sub that takes a single readonly
string argument and returns a modified version of the string.

=cut

sub escape_html_coderef
{
   my ($self) = @_;

   return $self->{EH};
}

=back

=head1 DATA TABLES

=over

=item C<%eschtml_map>

The C<%eschtml_map> hash maps C<iso-8859-1> characters to the
equivalent HTML entities.

=cut

use vars qw(%eschtml_map);
%eschtml_map = (
                 ( map {chr($_) => "&#$_;"} (0..255) ),
                 '<' => '&lt;',
                 '>' => '&gt;',
                 '&' => '&amp;',
                 '"' => '&quot;',
               );

=back

=head1 PRIVATE FUNCTIONS

These functions are returned by the strip_nonprint_coderef() and
escape_html_coderef() methods and invoked by the escape() method.
The function most appropriate to the character set in use will be
chosen.

=over

=item _strip_nonprint_utf8

Returns a copy of STRING with everything but printable C<us-ascii>
characters and valid C<utf-8> multibyte sequences replaced with
space characters.

=cut

sub _strip_nonprint_utf8
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~
   s%
    ( [\t\n\040-\176]               # printable us-ascii
    | [\xC2-\xDF][\x80-\xBF]        # U+00000080 to U+000007FF
    | \xE0[\xA0-\xBF][\x80-\xBF]    # U+00000800 to U+00000FFF
    | [\xE1-\xEF][\x80-\xBF]{2}     # U+00001000 to U+0000FFFF
    | \xF0[\x90-\xBF][\x80-\xBF]{2} # U+00010000 to U+0003FFFF
    | [\xF1-\xF7][\x80-\xBF]{3}     # U+00040000 to U+001FFFFF
    | \xF8[\x88-\xBF][\x80-\xBF]{3} # U+00200000 to U+00FFFFFF
    | [\xF9-\xFB][\x80-\xBF]{4}     # U+01000000 to U+03FFFFFF
    | \xFC[\x84-\xBF][\x80-\xBF]{4} # U+04000000 to U+3FFFFFFF
    | \xFD[\x80-\xBF]{5}            # U+40000000 to U+7FFFFFFF
    ) | .
   %
    defined $1 ? $1 : ' '
   %gexs;

   #
   # U+FFFE, U+FFFF and U+D800 to U+DFFF are dangerous and
   # should be treated as invalid combinations, according to
   # http://www.cl.cam.ac.uk/~mgk25/unicode.html
   #
   $string =~ s%\xEF\xBF[\xBE-\xBF]% %g;
   $string =~ s%\xED[\xA0-\xBF][\x80-\xBF]% %g;

   return $string;
}

=item _escape_html_utf8 ( STRING )

Returns a copy of STRING with any HTML metacharacters
escaped.  Escapes all but the most commonly occurring C<us-ascii>
characters and bytes that might form part of valid C<utf-8>
multibyte sequences.

=cut

sub _escape_html_utf8
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\x80-\xFD])| $eschtml_map{$1} |ge;
   return $string;
}

=item _strip_nonprint_weak ( STRING )

Returns a copy of STRING with sequences of NULL characters
replaced with space characters.

=cut

sub _strip_nonprint_weak
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ s/\0+/ /g;
   return $string;
}

=item _escape_html_weak ( STRING )

Returns a copy of STRING with any HTML metacharacters escaped.
In order to work in any charset, escapes only E<lt>, E<gt>, C<">
and C<&> characters.

=cut

sub _escape_html_weak
{
   my ($string) = @_;

   $string =~ s/[<>"&]/$eschtml_map{$1}/eg;
   return $string;
}

=item _escape_html_8859_1 ( STRING )

Returns a copy of STRING with all but the most commonly
occurring printable characters replaced with HTML entities.
Only suitable for C<us-ascii> or C<iso-8859-1> input.

=cut

sub _escape_html_8859_1
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\/\:])| $eschtml_map{$1} |ge;
   return $string;
}

=item _escape_html_8859 ( STRING )

Returns a copy of STRING with all but the most commonly
occurring printable C<us-ascii> characters and characters
that might be printable in some C<iso-8859-*> charset
replaced with HTML entities.

=cut

sub _escape_html_8859
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\/\:\240-\377])| $eschtml_map{$1} |ge;
   return $string;
}

=item _strip_nonprint_8859 ( STRING )

Returns a copy of STRING with runs of characters that are not
printable in any C<iso-8859-*> charset replaced with spaces.

=cut

sub _strip_nonprint_8859
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ tr#\t\n\040-\176\240-\377# #cs;
   return $string;
}

=item _strip_nonprint_ascii ( STRING )

Returns a copy of STRING with runs of characters that are not
printable C<us-ascii> replaced with spaces.

=cut

sub _strip_nonprint_ascii
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ tr#\t\n\040-\176# #cs;
   return $string;
}

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

1;

## END INLINED CGI::NMS::Charset
END_CGI_NMS_CHARSET

}

