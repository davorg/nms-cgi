#!/usr/bin/perl -Tw
#
# $Id: wwwboard.pl,v 1.9 2001-11-26 13:40:05 nickjc Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.8  2001/11/25 11:39:40  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.7  2001/11/25 09:45:25  gellyfish
# * Added stub FAQ (no answers just questions)
# * More toshing on wwwboard.pl
#
# Revision 1.6  2001/11/24 20:01:22  gellyfish
# Sundry refactoring
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
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:DEFAULT :flock :seek);
use POSIX qw(strftime);

use vars qw($DEBUGGING);

my $VERSION = '1.0';

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
   
my $basedir = '/var/www/nms-test/wwwboard';
my $baseurl = 'http://nms-test/wwwboard';
my $cgi_url = 'http://nms-test/cgi-bin/wwwboard.pl';

my $mesgdir  = 'messages';
my $datafile = 'data.txt';
my $mesgfile = 'wwwboard.html';
my $faqfile  = 'faq.html';

my $ext = 'html';

# $title is the title that will be displayed on the program generated pages

my $title = "NMS WWWBoard Version $VERSION";

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

# $emulate_matts_code determines whether the program should behave exactly
# like the original wwwboard program.  It should be set to 1 if you
# want to emulate the original program - this is recommended if you are
# replacing an existing installation with this program.  If it is set to 0
# then potentially it will not work with files produced by the original
# version - this is recommended for people installing this for the first time.

my $emulate_matts_code = 1;

# If $show_faq is set to 1 then the link for the WWWBoard FAQ will be shown
# on the generated pages.

my $show_faq     = 1;

# If $allow_html is set to 1 then HTML will not be removed from the body of
# the message.  Be warned however that setting this is a possible security
# risk allowing malicious defacement of the page and possible cross page
# scripting attacks on this or other site.

my $allow_html   = 1;

# If $quote_text is set to 1 then the text of the original message will
# be placed in the "Post Followup" text box

my $quote_text   = 1;

# $quote_char is the string that will be prepended to each quoted line
# if $quote_text described above is set to 1

my $quote_char  = ':';

# If $quote_html is set to 1 then if $quote_text is set to 1 above the
# original HTML in the post will be retained in the followup - otherwise
# it will be removed

my $quote_html = 0; 

my $subject_line = 0;	# 0 = Quote Subject Editable
                        # 1 = Quote Subject UnEditable; 
                        # 2 = Don't Quote Subject, Editable.

# If $use_time is set to 1 then the dates will be displayed as
# "$time_fmt $date_fmt" - see note below about date formats

my $use_time        = 1;

# $date_fmt and $time_fmt describe the format of the dates that
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

my $date_fmt = '%d/%m/%y';
my $time_fmt = '%T';

# $show_poster_ip determines whether the client IP address of the poster
# is displayed in the message.

my $show_poster_ip  = 1;

my $enforce_max_len = 0;   # 2 = YES, error; 1 = YES, truncate; 0 = NO

# These are the maximum lengths of the data allowed in the various
# fields - they must be supplied if $enforce_max_len is not 0

my %max_len = (name        => 50,
	       email       => 70,
	       subject     => 80,
	       url         => 150,
	       url_title   => 80,
	       img         => 150,
	       body        => 3000,
	       origsubject => 80,
	       origname    => 50,
	       origemail   => 70,
	       origdate    => 50);

# $strict_image if set to 1 will require that an image url if supplied
# must end in one of the common suffixes as defined in @image_suffixes

my $strict_image = 1;

# @images_suffixes is a list of the extensions that the image URL must end
# with if $strict_image above is set to 1 - this is to minimize a potential
# for the entry of entry of a malicious URL that may be used to attack
# another host or disfigure this web page.

my @image_suffixes = qw(png jpe?g gif);

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

if ( $use_time ) {
   $date_fmt = "$time_fmt $date_fmt";
}

# Nasty global variables. Need to localise them
my ($date, $followup, $subject, @followup_num, $message_img, $origemail,
    $origname, $origdate, $long_date, $name, @followups, $num_followups,
    $body, $last_message, $origsubject, $message_url_title, $hidden_body,
    $email, $message_url);

my $id = get_number();
my %Form = parse_form();
get_variables();
new_file();
main_page();

if ($num_followups >= 1) {
  thread_pages();
}

return_html();
increment_num(); # Is this necessary with the current implementation of
                 # get_number() ?

sub get_number {
  sysopen(NUMBER, "$basedir/$datafile", O_RDWR|O_CREAT)
    || die "Can't open number file: $!\n";
  flock(NUMBER, LOCK_EX)
    || die "Can't lock number file: $!\n";
  my $num = <NUMBER> || 0;

  if ($num =~ /^(\d)+$/) {
    $num = $1;
  } else {
    $num = 0;
  }

  if ($num == 999999 || $num !~ /^\d+$/)  {
    $num = 1;
  } else {
    $num++;
  }

  seek(NUMBER, SEEK_SET, 0);
  truncate NUMBER, 0;
  print NUMBER $num;

  close NUMBER;

  return $num;
}

sub parse_form {
  my %Form;

  # Are we sure this is valid syntax in 5.004.04 ?

  $Form{$_} = param($_) || '' foreach keys %max_len, 'followup';

  if ($enforce_max_len) {
    foreach (keys %max_len) {
      if (length($Form{$_}) > $max_len{$_}) {
	if ($enforce_max_len == 2) {
	  &error('field_size');
	} else {
	  $Form{$_} = substr($Form{$_}, 0, $max_len{$_});
	}
      }
    }
  }

  return %Form;
}

###############
# Get Variables

sub get_variables {
  if ($Form{followup}) {
    $followup = 1;
    @followup_num = split(/,/, $Form{followup});

    my %fcheck;
    foreach my $fn (@followup_num) {
      error('followup_data') if $fn !~ /^\d+$/ || $fcheck{$fn};
      $fcheck{$fn} = 1;
    }

    @followup_num = keys %fcheck;

    @followups = @followup_num;
    $num_followups = @followup_num;
    $last_message = pop(@followups);
    $origdate = $Form{origdate};
    $origname = $Form{origname};
    $origsubject = $Form{origsubject};
  } else {
    $followup = $num_followups = 0;
  }

  if ($Form{name}) {
    $name = $Form{name};
    $name =~ s/\"//g;
    $name =~ s/<//g;
    $name =~ s/>//g;
    $name =~ s/\&//g;
  } else {
    error('no_name');
  }

  if ($Form{email} =~ /.*\@.*\..*/) {
    $email = $Form{email};
  }

  if ($Form{subject}) {
    $subject = escape_html($Form{subject});
  } else {
    error('no_subject');
  }

  if ($Form{url} =~ /.*\:.*\..*/ && $Form{url_title}) {
    $message_url = $Form{url};
    $message_url_title = $Form{url_title};
  }

  my $image_suffixes = '.+';

  if ( $strict_image )
  {
     $image_suffixes = join '|', @image_suffixes;

     $image_suffixes = "($image_suffixes)";
  }
  if ($Form{img} =~ m%^.+tp://.*\.image_suffixes$%) {
    $message_img = $Form{img};
  }

  if ($Form{body}) {
    $body = $Form{body};
    $body = strip_html($body) unless $allow_html; 
    $body = "<p>$body</p>";
    $body =~ s/\cM//g;
    $body =~ s|\n\n|</p><p>|g;
    $body =~ s%\n%<br />%g;

    # I'm not entirely sure if this is what is actually meant :
    # it would allow someone to subvert $allow_html by putting escaped stuff
    # in the message and having the script expand it.

    $body = unescape_html($body);
     
  } else {
    error('no_body');
  }

  if ($quote_text) 
  {
    $hidden_body = $body;
    if ( $quote_html ) 
    {
       $hidden_body = escape_html($hidden_body);
    }
    else 
    {
       $hidden_body = strip_html($hidden_body);
    }
   
   }

   $date = strftime($date_fmt , localtime());
}

#####################
# New File Subroutine

sub new_file {
  open(NEWFILE,">$basedir/$mesgdir/$id.$ext")
    || die "$! [$basedir/$mesgdir/$id.$ext]";

  my $faq = $show_faq ? qq( [ <a href="$baseurl/$faqfile">FAQ</a> ]) : '';
  my $print_name = $email ? qq(<a href="mailto:$email">$name</a> ) : $name;
  my $ip = $show_poster_ip ? "($ENV{REMOTE_ADDR})" : '';
  my $pr_follow = $followup ? 
    qq(<p>In Reply to:
       <a href="$last_message.$ext">$origsubject</a> posted by ) .
	 $origemail ? qq(<a href="$origemail">$origname</a>) 
	   : $origname . "on $origdate:</p>" : '';
  my $img = $message_img ? 
    qq(<p align="center"><img src="$message_img"></p>\n) : '';
  my $url = $message_url ? 
    qq(<ul><li><a href="$message_url">$message_url_title</a></li></ul><br>) :
      '';

  print NEWFILE <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$subject</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1 align="center">$subject</h1>
    <hr />
    <p align="center">
      [ <a href="#followups">Follow Ups</a> ]
      [ <a href="#postfp">Post Followup</a> ]
      [ <a href="$baseurl/$mesgfile">$title</a> ]
      $faq
    </p>

  <hr />
  <p>Posted by $print_name $ip on $date</p>

  $followup $img

  $body<br />$url

  <hr />
  <p><a name="followups">Follow Ups:</a><br />
  <ul><!--insert: $id-->
  </ul><!--end: $id-->
  <br /><hr />
  <p><a name="postfp">Post a Followup</a></p>
  <form method=POST action="$cgi_url">
END_HTML

  my $follow_ups = @followup_num ? map { "$_," } @followup_num : '';

  print NEWFILE qq(<input type="hidden" name="followup" value="$follow_ups$id" />);

  print NEWFILE qq(<input type=hidden name="origname" value="$name" />);
  print NEWFILE qq(<input type=hidden name="origemail" value="$email" />)
    if $email;

  print NEWFILE <<END_HTML;
<input type="hidden" name="origsubject" value="$subject" />
<input type="hidden" name="origdate" value="$date" />
<table>
<tr>
<td>Name:</td>
<td><input type="text" name="name" size="50" /></td>
</tr>
<tr>
<td>E-Mail:</td>
<td><input type="text" name="email" size="50" /></td>
</tr>
END_HTML

  $subject = 'Re: ' . $subject unless $subject =~ /^Re:/i;

  if ($subject_line == 1) {
    print NEWFILE qq(<input type="hidden" name="subject" value="$subject" />\n);
    print NEWFILE "<tr><td>Subject:</td><td><b>$subject</b></td></tr>\n";
  } elsif ($subject_line == 2) {
    print NEWFILE qq(<tr><td>Subject:</td><td><input type="text" name="subject" size="50"></td></tr>\n);
  } else {
    print NEWFILE qq(<tr><td>Subject:</td><td><input type="text" name="subject"value="$subject" size="50"></td></tr>\n);
  }
  print NEWFILE "<tr><td>Comments:</td>\n";
  print NEWFILE qq(<td><textarea name="body" COLS="50" ROWS="10">\n);
  if ($quote_text) {
    print NEWFILE map { "$quote_char $_\n" } split /\n/, $hidden_body;
    print NEWFILE "\n";
  }
  print NEWFILE "</textarea></td></tr>\n";
  print NEWFILE <<END_HTML;
<tr>
<td>Optional Link URL:</td>
<td><input type="text" name="url" size="50" /></td>
</tr>
<tr>
<td>Link Title:</td>
<td><input type="text" name="url_title" size="48" /></td>
</tr>
<tr>
<td>Optional Image URL:</td>
<td><input type="text" name="img" size="49" /></td>
</tr>
<tr>
<td colspan="2"><input type="submit" value="Submit Follow Up" /> 
<input type="reset" /></td>
</tr>
<hr />
<p align="center">
   [ <a href="#followups">Follow Ups</a> ] 
   [ <a href="#postfp">Post Followup</a> ] 
   [ <a href="$baseurl/$mesgfile">$title</a> ] 
   $faq
</p>
</body>
</html>
END_HTML
  close(NEWFILE);
}

###############################
# Main WWWBoard Page Subroutine

sub main_page {
  open(MAIN,"$basedir/$mesgfile") ||
    die "$! [$basedir/$mesgfile]";

  my @main = <MAIN>;
  close(MAIN);

  open(MAIN,">$basedir/$mesgfile") || die $!;
  if ($followup == 0) {
    foreach (@main) {
      if (/<!--begin-->/) {
	print MAIN <<END_HTML;
<!--begin-->
<!--top: $id--><li><a href="$mesgdir/$id.$ext">$subject</a> - <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } else {
	print MAIN $_;
      }
    }
  } else {
    foreach (@main) {
      my $work = 0;
      if (/<ul><!--insert: $last_message-->/) {
	print MAIN <<END_HTML;
<ul><!--insert: $last_message-->
<!--top: $id--><li><a href="$mesgdir/$id.$ext">$subject</a> - <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } elsif (/\(<!--responses: (.*)-->(.*)\)/) {
	my $response_num = $1;
	my $num_responses = $2;
	$num_responses++;
	foreach my $followup_num (@followup_num) {
	  if ($followup_num == $response_num) {
	    print MAIN "(<!--responses: $followup_num-->$num_responses)\n";
	    $work = 1;
	  }
	}
	if ($work != 1) {
	  print MAIN $_;
	}
      } else {
	print MAIN $_;
      }
    }
  }
  close(MAIN);
}

############################################
# Add Followup Threading to Individual Pages
sub thread_pages {

  foreach my $followup_num (@followup_num) {
    open(FOLLOWUP, "$basedir/$mesgdir/$followup_num.$ext")
      || die "$!";

    my @followup_lines = <FOLLOWUP>;
    close(FOLLOWUP);

    open(FOLLOWUP, ">$basedir/$mesgdir/$followup_num.$ext")
      || die "$!";

    foreach (@followup_lines) {
      my $work = 0;
      if (/<ul><!--insert: $last_message-->/) {
	print FOLLOWUP<<END_HTML;
<ul><!--insert: $last_message-->
<!--top: $id--><li><a href="$id\.$ext">$subject</a> <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } elsif (/\(<!--responses: (.*)-->(.*)\)/) {
	my $response_num = $1;
	my $num_responses = $2;
	$num_responses++;
	foreach $followup_num (@followup_num) {
	  if ($followup_num == $response_num) {
	    print FOLLOWUP "(<!--responses: $followup_num-->$num_responses)\n";
	    $work = 1;
	  }
	}
	if ($work != 1) {
	  print FOLLOWUP $_;
	}
      } else {
	print FOLLOWUP $_;
      }
    }
    close(FOLLOWUP);
  }
}

sub return_html {
  print header;

  my $url = $message_url ? 
    qq(<p><b>Link:</b> <a href="$message_url">$message_url_title</a></p>) : '';
  my $img = $message_img ? 
    qq(<p><b>Image:</b> <img src="$message_img"></p>) : '';

  print <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>Message Added: $subject</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1 align="center">Message Added: $subject</h1>
    <p>The following information was added to the message board:</p>
    <hr>
    <p><b>Name:</b> $name<br>
      <b>E-Mail:</b> $email<br>
      <b>Subject:</b> $subject<br>
      <b>Body of Message:</b></p>
      <p>$body</p>
    $url
    $img

    <p><b>Added on Date:</b> $date</p>
    <hr>
    <p align="center">[ <a href="$baseurl/$mesgdir/$id.$ext">Go to Your Message</a> ] [ <a href="$baseurl/$mesgfile">$title</a> ]</p>
  </body>
</html>
END_HTML
}

sub increment_num {
  open(NUM,">$basedir/$datafile") || die $!;
  print NUM $id;
  close(NUM);
}

sub error {
  my $error = $_[0];

  print header;

  if ($error eq 'no_name') {
    print <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$title ERROR: No Name</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body><h1 align="center">ERROR: No Name</h1>
  <p>You forgot to fill in the 'Name' field in your posting.  Correct it 
    below and re-submit.  The necessary fields are: Name, Subject and 
    Message.</p>
  <hr>
END_HTML
    rest_of_form();
  } elsif ($error eq 'no_subject') {
    print <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$title ERROR: No Subject</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body><h1 align="center">ERROR: No Subject</h1>
  <p>You forgot to fill in the 'Subject' field in your posting.  Correct it 
  below and re-submit.  The necessary fields are: Name, Subject and 
  Message.</p>
  <hr>
END_HTML
    rest_of_form();
  } elsif ($error eq 'no_body') {
    print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<title>$title ERROR: No Message</title>
<link rel="stylesheet" type="text/css" href="$style" />
</head>
<body><align="center"><h1>ERROR: No Message</h1>
<p>You forgot to fill in the 'Message' field in your posting.  Correct it
below and re-submit.  The necessary fields are: Name, Subject and 
Message.</p>
<hr>
END_HTML
rest_of_form();
} elsif ($error eq 'field_size') {
printf <<END_HTML;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$title ERROR: Field too Long</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body><h1 align="center">ERROR: Field too Long</h1>
  <p>One of the form fields in the message submission was too long.  The 
  following are the limits on the size of each field (in characters):</p>
  <ul>
    <li>Name: $max_len{name}</li>
    <li>E-Mail: $max_len{email}</li>
    <li>Subject: $max_len{subject}</li>
    <li>Body: $max_len{body}</li>
    <li>URL: $max_len{url}</li>
    <li>URL Title: $max_len{url_title}</li>
    <li>Image URL: $max_len{img}</li>
  </ul>
  <p>Please modify the form data and resubmit.</p>
  <hr>
END_HTML
     &rest_of_form;
   } else {
     print "<p>ERROR!  Undefined.</p>";
   }
  exit;
}

sub rest_of_form {

  print qq(<form method="POST" action="$cgi_url">\n);

  if ($followup == 1) {
    print qq(<input type="hidden" name="origsubject" value="$Form{origsubject}" />\n);
    print qq(<input type="hidden" name="origname" value="$Form{origname}" />\n);
    print qq(<input type="hidden" name="origemail" value="$Form{origemail}" />\n);
    print qq(<input type="hidden" name="origdate" value="$Form{origdate}" />\n);
    print qq(<input type="hidden" name="followup" value="$Form{followup}" />\n);
  }
  print qq(Name: <input type="text" name="name" value="$Form{name}" size="50" /><br />\n);
  print qq(E-Mail: <input type="text" name="email" value="$Form{email}" size="50" /><p />\n);
  if ($subject_line == 1) {
    print qq(<input type="hidden" name="subject" value="$Form{subject}" />\n);
    print qq(Subject: <b>$Form{subject}</b><p />\n);
  } else {
    print qq(Subject: <input type="text" name="subject" value="$Form{subject}" size="50" /><p />\n);
   }
  
  $Form{body} = escape_html($Form{body});

  print "Message:<br>\n";
  print qq(<textarea COLS="50" ROWS="10" name="body">\n);

  print "$Form{body}\n";
  print "</textarea><p>\n";
  print qq(Optional Link URL: <input type=text name="url" value="$Form{url}" size="45" /><br />\n);
  print qq(Link Title: <input type="text" name="url_title" value="$Form{url_title}" size="50" /><br />\n);
  print qq(Optional Image URL: <input type="text" name="img" value="$Form{img}" size="45" /><p />\n);
  print qq(<input type="submit" value="Post Message" /> <input type="reset" />\n);
  print "</form>\n";
  print qq(<br /><hr size="7" width="75%" />\n);
  if ($show_faq) {
    print qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$baseurl/$mesgfile">$title</a> ] [ <a href="$baseurl/$faqfile">FAQ</a> ]</center>\n);
  } else {
    print qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$baseurl/$mesgfile">$title</a> ]</center>\n);
  }
  print "</body></html>\n";
}

# subroutine to remove HTML from a string.
# Ideally one would use something like HTML::Parser but we make not have
# that luxury.

sub strip_html
{
   my ( $text ) = @_;
   $text =~ s/(?:<[^>'"]*|".*?"|'.*?')+>//gs;
   return $text;
}

# subroutine to escape the necessary characters to the appropriate HTML
# entities

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
