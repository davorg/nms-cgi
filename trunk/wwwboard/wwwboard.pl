#!/usr/bin/perl -Tw
#
# $Id: wwwboard.pl,v 1.36 2002-08-26 08:54:12 nickjc Exp $
#

use strict;
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(locale_h strftime);
use vars qw($DEBUGGING $done_headers);
my $VERSION = substr q$Revision: 1.36 $, 10, -1;

BEGIN
{ 
  eval
  {
    sub SEEK_SET() {0;}
  } unless defined(&SEEK_SET);
}

# Horrible locution to shut up warnings

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 1024 * 20;

# PROGRAM INFORMATION
# -------------------
# wwwboard.pl
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
BEGIN { $DEBUGGING      = 1; }
my $emulate_matts_code  = 1;
my $max_followups       = 10;
my $basedir             = '/var/www/nms-test/wwwboard';
my $baseurl             = 'http://nms-test/wwwboard';
my $cgi_url             = 'http://nms-test/cgi-bin/wwwboard.pl';
my $mesgdir             = 'messages';
my $datafile            = 'data.txt';
my $mesgfile            = 'wwwboard.html';
my $faqfile             = 'faq.html';
my $ext                 = 'html';
my $title               = "NMS WWWBoard Version $VERSION";
my $style               = '/css/nms.css';
my $show_faq            = 1;
my $allow_html          = 1;
my $quote_text          = 1;
my $quote_char          = ':';
my $quote_html          = 0; 
my $subject_line        = 0;
my $use_time            = 1;
my $date_fmt            = '%d/%m/%y';
my $time_fmt            = '%T';
my $show_poster_ip      = 1;
my $enforce_max_len     = 0;
my %max_len             = ('name'        => 50,
                           'email'       => 70,
                           'subject'     => 80,
                           'url'         => 150,
                           'url_title'   => 80,
                           'img'         => 150,
                           'body'        => 3000,
                           'origsubject' => 80,
                           'origname'    => 50,
                           'origemail'   => 70,
                           'origdate'    => 50);
my $strict_image        = 1;
my @image_suffixes      = qw(png jpe?g gif);
my $locale              = '';
my $charset             = 'iso-8859-1';

#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)


use vars qw($cs);
$cs = CGI::NMS::Charset->new($charset);

# %E is a fake hash for escaping HTML metachars as things are
# interploted into strings.
use vars qw(%E);
tie %E, __PACKAGE__;
sub TIEHASH { bless {}, shift }
sub FETCH { $cs->escape($_[1]) }


# We need finer control over what gets to the browser and the CGI::Carp
# set_message() is not available everywhere :(
# This is basically the same as what CGI::Carp does inside but simplified
# for our purposes here.

BEGIN
{
   sub fatalsToBrowser
   {
      my ( $message ) = @_;

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


my $html_style = $style ?
                 qq%<link rel="stylesheet" type="text/css" href="$E{$style}" />%
               : '';

if ( $use_time ) {
   $date_fmt = "$time_fmt $date_fmt";
}


my $Form = parse_form();

open LOCK, ">>$basedir/.lock" or die "open >>$basedir/.lock: $!";
flock LOCK, LOCK_EX or die "flock $basedir/.lock: $!";

my $id = get_number();

my $variables = get_variables($Form,$id);

new_file($variables);
main_page($variables);

thread_pages($variables);

close LOCK;

return_html($variables);

sub get_number {
  sysopen(NUMBER, "$basedir/$datafile", O_RDWR|O_CREAT)
    || die "Can't open number file: $!\n";

  my $num = <NUMBER> || 0;

  if ($num =~ /^(\d+)$/) {
    $num = $1;
  } else {
    $num = 0;
  }

  if ($num == 999999 )  {
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


  foreach my $param ( keys %max_len , 'followup' )
  {
     $Form{$param} = param($param) || '';
  }

  if ($enforce_max_len) {
    foreach (keys %max_len) {
      if (length($Form{$_}) > $max_len{$_}) {
        if ($enforce_max_len == 2) {
          error('field_size',{Form => \%Form});
        } else {
          $Form{$_} = substr($Form{$_}, 0, $max_len{$_});
        }
      }
    }
  }
  return \%Form;
}

###############
# Get Variables

sub get_variables {

  my ( $Form,$id ) = @_;

  my $variables = {id   => $id,
                   Form => $Form}; # Just in case ;-}

  my @followup_num;

  if (exists $Form->{followup} && length($Form->{followup})) {
    $variables->{followup} = 1;
    @followup_num = split(/,/, $Form->{followup});

    my %fcheck;
    foreach my $fn (@followup_num) {
      error('followup_data',{Form => $Form}) if $fn !~ /^\d+$/ || $fcheck{$fn};
      $fcheck{$fn}++;
    }

    @followup_num = sort {$a <=> $b} keys %fcheck;

    # truncate the list of followups so that a vandal can't followup
    # to every existing message on the site.

    if ( !$emulate_matts_code && $max_followups && 
                                 $max_followups < @followup_num ) {

        my $start_followups = $#followup_num - $max_followups;

        @followup_num = @followup_num[$start_followups .. $#followup_num];
    }
    
    $variables->{followups} = \@followup_num;
    $variables->{num_followups} = scalar @followup_num;
    $variables->{last_message} = $followup_num[$#followup_num];
    $variables->{origdate} = $Form->{origdate};
    $variables->{origname} = $Form->{origname};
    $variables->{origsubject} = $Form->{origsubject};
  } else {
    $variables->{followup} = $variables->{num_followups} = 0;
  }

  if (my $name = $Form->{name}) {
    $name =~ tr/"<>&/ /s;

    $variables->{name} = $name;
  } else {
    error('no_name',{ Form => $Form});
  }

  if ($Form->{email} =~ /(.*\@.*\..*)/) {
    $variables->{email} = $1;
  }
  else {
    $variables->{email} = '';
  }

  if ($Form->{subject}) {
    $variables->{subject} = $Form->{subject};
  } else {
    error('no_subject',{ Form => $Form });
  }

  if ($Form->{'url'} =~ /(.*\:.*\..*)/ && $Form->{'url_title'}) {
    $variables->{message_url} = $1;
    $variables->{message_url_title} = $Form->{'url_title'};
  }

  my $image_suffixes = '.+';

  if ( $strict_image )
  {
     $image_suffixes = join '|', @image_suffixes;

     $image_suffixes = "($image_suffixes)";
  }
  if ($Form->{'img'} =~ m%^(https?://.*\.$image_suffixes)$%) {
    $variables->{message_img} = $1;
  }

  if (my $body = $Form->{'body'}) {
    $body = strip_html($body,$allow_html);
    $body = "<p>$body</p>";
    $body =~ s/\cM//g;
    $body =~ s|\n\n|</p><p>|g;
    $body =~ s%\n%<br />%g;

    $variables->{'body'} = $body;

  } else {
    error('no_body',{Form => $Form});
  }

  if ($quote_text) 
  {
    my $hidden_body = $Form->{'body'};

    if ( $quote_html ) 
    {
       $hidden_body = $cs->escape($hidden_body);
    }
    else 
    {
       $hidden_body = strip_html($hidden_body,$allow_html);
    }

    $variables->{hidden_body} = $hidden_body;
   
   }

   eval
   {
       setlocale(LC_TIME, $locale ) if $locale;
   };

   $variables->{date} = strftime($date_fmt , localtime());

   return $variables;
}

#####################
# New File Subroutine

sub new_file {

  my ($variables) = @_;

  open(NEWFILE,">$basedir/$mesgdir/$variables->{id}.$ext")
    || die "Open: $! [$basedir/$mesgdir/$variables->{id}.$ext]";

  my $html_faq = $show_faq ? qq( [ <a href="$E{"$baseurl/$faqfile"}">FAQ</a> ]) : '';
  my $html_print_name = $variables->{email} ? 
            qq(<a href="$E{"mailto:$variables->{email}"}">$E{$variables->{name}}</a> ) : 
            $E{$variables->{name}};
  my $ip = $show_poster_ip ? "($ENV{REMOTE_ADDR})" : '';

  my $html_pr_follow = '';

  if ( $variables->{followup} )
  {
     $html_pr_follow = 
    qq(<p>In Reply to:
       <a href="$E{"$variables->{last_message}.$ext"}">$E{$variables->{origsubject}}</a> posted by ); 

      if ( $variables->{origemail} )
      {
        $html_pr_follow .=  
         qq(<a href="$E{$variables->{origemail}}">$E{$variables->{origname}}</a>) ;
      }
      else
      {
        $html_pr_follow .= $E{$variables->{origname}};
      }
      $html_pr_follow .= '</p>';
  }

  my $html_img = $variables->{message_img} ?
    qq(<p align="center"><img src="$E{$variables->{message_img}}" /></p>\n) : '';
  my $html_url = $variables->{message_url} ? 
    qq(<ul><li><a href="$E{$variables->{message_url}}">$E{$variables->{message_url_title}}</a></li></ul><br />) :
      '';

  print NEWFILE <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$E{$variables->{subject}}</title>
    $html_style
  </head>
  <body>
    <h1 align="center">$E{$variables->{subject}}</h1>
    <hr />
    <p align="center">
      [ <a href="#followups">Follow Ups</a> ]
      [ <a href="#postfp">Post Followup</a> ]
      [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]
      $html_faq
    </p>

  <hr />
  <p>Posted by $html_print_name $E{$ip} on $E{$variables->{date}}</p>

  $html_pr_follow 

  $html_img

  $variables->{'body'}<br />$html_url

  <hr />
  <p><a id="followups" name="followups">Follow Ups:</a></p>
  <ul><!--insert: $E{$variables->{id}}-->
  </ul><!--end: $E{$variables->{id}}-->
  <br /><hr />
  <p><a id="postfp" name="postfp">Post a Followup</a></p>
  <form method=POST action="$E{$cgi_url}">
END_HTML

  my $follow_ups = ( defined $variables->{followups} )  ? 
                     join( ',', @{$variables->{followups}}) : '';

  $follow_ups .= ',' if length($follow_ups);

  my $id = $variables->{id};

  print NEWFILE qq(<input type="hidden" name="followup" value="$E{"$follow_ups$id"}" />);

  print NEWFILE qq(<input type=hidden name="origname" value="$E{$variables->{name}}" />);
  print NEWFILE qq(<input type=hidden name="origemail" value="$E{$variables->{email}}" />)
    if $variables->{email};

  print NEWFILE <<END_HTML;
<input type="hidden" name="origsubject" value="$E{$variables->{subject}}" />
<input type="hidden" name="origdate" value="$E{$variables->{date}}" />
<table summary="">
<tr>
<td>Name:</td>
<td><input type="text" name="name" size="50" /></td>
</tr>
<tr>
<td>E-Mail:</td>
<td><input type="text" name="email" size="50" /></td>
</tr>
END_HTML

  my $subject = $variables->{subject};

  $subject = 'Re: ' . $subject unless $subject =~ /^Re:/i;

  if ($subject_line == 1) {
    print NEWFILE qq(<input type="hidden" name="subject" value="$E{$subject}" />\n);
    print NEWFILE "<tr><td>Subject:</td><td><b>$E{$subject}</b></td></tr>\n";
  } elsif ($subject_line == 2) {
    print NEWFILE qq(<tr><td>Subject:</td><td><input type="text" name="subject" size="50"></td></tr>\n);
  } else {
    print NEWFILE qq(<tr><td>Subject:</td><td><input type="text" name="subject" value="$E{$subject}" size="50"></td></tr>\n);
  }
  print NEWFILE "<tr><td>Comments:</td>\n";
  print NEWFILE qq(<td><textarea name="body" cols="50" rows="10">\n);
  if ($quote_text) {
    print NEWFILE map { "$E{$quote_char} " . strip_html($_) . "\n" } 
                  split /\n/, $variables->{hidden_body};
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
</table>
</form>
<hr />
<p align="center">
   [ <a href="#followups">Follow Ups</a> ] 
   [ <a href="#postfp">Post Followup</a> ] 
   [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ] 
   $html_faq
</p>
</body>
</html>
END_HTML
  close(NEWFILE);
}

###############################
# Main WWWBoard Page Subroutine

sub main_page {

   my ( $variables ) = @_;

  open(MAIN,"<$basedir/$mesgfile") ||
    die "Open: $! [$basedir/$mesgfile]";

  my @main = <MAIN>;
  close(MAIN);

  open(MAIN_OUT,">$basedir/$mesgfile.tmp") || die $!;

  my $id = $variables->{id};
  my $name = $variables->{name};
  my $subject = $variables->{subject};
  my $date = $variables->{date};

  if ($variables->{followup} == 0) {
    foreach (@main) {
      if (/<!--begin-->/) {
        print MAIN_OUT <<END_HTML;
<!--begin-->
<!--top: $E{$id}--><li><a href="$E{"$mesgdir/$id.$ext"}">$E{$subject}</a> - <b>$E{$name}</b> <i>$E{$date}</i>
(<!--responses: $E{$id}-->0)
<ul><!--insert: $E{$id}-->
</ul><!--end: $E{$id}-->
END_HTML
      } else {
        print MAIN_OUT $_;
      }
    }
  } else {
    foreach (@main) {
      my $work = 0;
      if (/\Q<ul><!--insert: $E{$variables->{last_message}}-->/) {
        print MAIN_OUT <<END_HTML;
<ul><!--insert: $E{$variables->{last_message}}-->
<!--top: $E{$id}--><li><a href="$E{"$mesgdir/$id.$ext"}">$E{$subject}</a> - <b>$E{$name}</b> <i>$E{$date}</i>
(<!--responses: $E{$id}-->0)
<ul><!--insert: $E{$id}-->
</ul><!--end: $E{$id}-->
END_HTML
      } elsif (/\(<!--responses: (\d+?)-->(\d+?)\)/) {
        my $response_num = $1;
        my $num_responses = $2;
        $num_responses++;
        foreach my $followup_num (@{$variables->{followups}}) {
          if ($followup_num == $response_num) {
            print MAIN_OUT "(<!--responses: $E{$followup_num}-->$E{$num_responses})\n";
            $work = 1;
          }
        }
        if ($work != 1) {
          print MAIN_OUT $_;
        }
      } else {
        print MAIN_OUT $_;
      }
    }
  }

  unless(close(MAIN_OUT)) {
     unlink "$basedir/$mesgfile.tmp";
     die "write to : $basedir/$mesgfile.tmp - $!";
  }

  rename "$basedir/$mesgfile.tmp", "$basedir/$mesgfile"
   or die "rename $basedir/$mesgfile.tmp => $basedir/$mesgfile - $!";
}

############################################
# Add Followup Threading to Individual Pages
sub thread_pages {

  my ($variables) = @_;

  return unless $variables->{num_followups};

  my $id = $variables->{id};
  my $subject = $variables->{subject};
  my $name    = $variables->{name};
  my $date    = $variables->{date};

  foreach my $followup_num (@{$variables->{followups}}) {

    open(FOLLOWUP, "<$basedir/$mesgdir/$followup_num.$ext")
      || die "$!";

    my @followup_lines = <FOLLOWUP>;
    close(FOLLOWUP);

    open(FOLLOWUP, ">$basedir/$mesgdir/$followup_num.tmp") || die "$!"; 

    foreach (@followup_lines) {
      my $work = 0;
      if (/\Q<ul><!--insert: $E{$variables->{last_message}}-->/) {
        print FOLLOWUP<<END_HTML;
<ul><!--insert: $E{$variables->{last_message}}-->
<!--top: $E{$id}--><li><a href="$E{"$id\.$ext"}">$E{$subject}</a> <b>$E{$name}</b> <i>$E{$date}</i>
(<!--responses: $E{$id}-->0)
<ul><!--insert: $E{$id}-->
</ul><!--end: $E{$id}-->
END_HTML
      } elsif (/\(<!--responses: (\d+?)-->(\d+?)\)/) {
        my $response_num = $1;
        my $num_responses = $2;
        $num_responses++;
        foreach $followup_num (@{$variables->{followups}}) {
          if ($followup_num == $response_num) {
            print FOLLOWUP "(<!--responses: $E{$followup_num}-->$E{$num_responses})\n";
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

    unless (close(FOLLOWUP)) {
       unlink "$basedir/$mesgdir/$followup_num.tmp";
       die "write $basedir/$mesgdir/$followup_num.tmp $!";
    }
    rename "$basedir/$mesgdir/$followup_num.tmp",
            "$basedir/$mesgdir/$followup_num.$ext"
     or die "rename : $followup_num.tmp => $followup_num.$ext - $!";
  }
}

sub return_html {

  my ( $variables ) = @_;

  print header;
  $done_headers++;

  my $html_url = $variables->{message_url} ? 
    qq(<p><b>Link:</b> <a href="$E{$variables->{message_url}}">$E{$variables->{message_url_title}}</a></p>) : '';
  my $html_img = $variables->{message_img} ? 
    qq(<p><b>Image:</b> <img src="$E{$variables->{message_img}}" /></p>) : '';

  print <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Message Added: $E{$variables->{subject}}</title>
    $html_style
  </head>
  <body>
    <h1 align="center">Message Added: $E{$variables->{subject}}</h1>
    <p>The following information was added to the message board:</p>
    <hr />
    <p><b>Name:</b> $E{$variables->{name}}<br />
      <b>E-Mail:</b> $E{$variables->{email}}<br />
      <b>Subject:</b> $E{$variables->{subject}}<br />
      <b>Body of Message:</b></p>
      <p>$variables->{'body'}</p>
    $html_url
    $html_img

    <p><b>Added on Date:</b> $E{$variables->{date}}</p>
    <hr />
    <p align="center">
       [ <a href="$E{"$baseurl/$mesgdir/$id.$ext"}">Go to Your Message</a> ] 
       [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]
    </p>
  </body>
</html>
END_HTML
}

sub error {
  my ($error, $variables) = @_;

  print header;
  $done_headers++;

  my ($html_error_message, $error_title);
  if ($error eq 'no_name') {
    $error_title = 'No Name';
    $html_error_message =<<EOMESS;
  <p>You forgot to fill in the 'Name' field in your posting.  Correct it 
    below and re-submit.  The necessary fields are: Name, Subject and 
    Message.</p>
EOMESS
  } elsif ($error eq 'no_subject') {
    $error_title = 'No Subject';
    $html_error_message =<<EOMESS;
  <p>You forgot to fill in the 'Subject' field in your posting.  Correct it 
  below and re-submit.  The necessary fields are: Name, Subject and 
  Message.</p>
EOMESS
  } elsif ($error eq 'no_body') {
    $error_title = 'No Message';
    $html_error_message =<<EOMESS;
<p>You forgot to fill in the 'Message' field in your posting.  Correct it
below and re-submit.  The necessary fields are: Name, Subject and 
Message.</p>
EOMESS
   } elsif ($error eq 'field_size') {
     $error_title = 'Field too Long';
     $html_error_message =<<EOMESS;
  <p>One of the form fields in the message submission was too long.  The 
  following are the limits on the size of each field (in characters):</p>
  <ul>
    <li>Name: $E{$max_len{'name'}}</li>
    <li>E-Mail: $E{$max_len{'email'}}</li>
    <li>Subject: $E{$max_len{'subject'}}</li>
    <li>Body: $E{$max_len{'body'}}</li>
    <li>URL: $E{$max_len{'url'}}</li>
    <li>URL Title: $E{$max_len{'url_title'}}</li>
    <li>Image URL: $E{$max_len{'img'}}</li>
  </ul>
  <p>Please modify the form data and resubmit.</p>
EOMESS
   } else {
     $error_title = 'Application error';
     $html_error_message =<<EOMESS;
<p>An error has occurred while your message was being submitted
please use your back button and try again</p>
EOMESS
   }
   print <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$E{"$title ERROR: $error_title"}</title>
    $html_style
  </head>
  <body><h1 align="center">ERROR: $E{$error_title}</h1>
    $html_error_message
  <hr />
END_HTML
  rest_of_form($variables);
  exit;
}

sub rest_of_form {

  my ( $variables ) = @_;

  print qq(<form method="POST" action="$E{$cgi_url}">\n);

  my %Form = %{$variables->{Form}};

  if (defined $variables->{followup} and $variables->{followup} == 1) {
    print qq(<input type="hidden" name="origsubject" value="$E{$Form{origsubject}}" />\n);
    print qq(<input type="hidden" name="origname" value="$E{$Form{origname}}" />\n);
    print qq(<input type="hidden" name="origemail" value="$E{$Form{origemail}}" />\n);
    print qq(<input type="hidden" name="origdate" value="$E{$Form{origdate}}" />\n);
    print qq(<input type="hidden" name="followup" value="$E{$Form{followup}}" />\n);
  }
  print qq(Name: <input type="text" name="name" value="$E{$Form{name}}" size="50" /><br />\n);
  print qq(E-Mail: <input type="text" name="email" value="$E{$Form{email}}" size="50" /><p />\n);
  if ($subject_line == 1) {
    print qq(<input type="hidden" name="subject" value="$E{$Form{subject}}" />\n);
    print qq(Subject: <b>$E{$Form{subject}}</b><p />\n);
  } else {
    print qq(Subject: <input type="text" name="subject" value="$E{$Form{subject}}" size="50" /><p />\n);
   }
  
  print "Message:<br />\n";
  print qq(<textarea cols="50" rows="10" name="body">\n);

  print "$E{$Form{'body'}}\n";
  print "</textarea><p />\n";
  print qq(Optional Link URL: <input type="text" name="url" value="$E{$Form{'url'}}" size="45" /><br />\n);
  print qq(Link Title: <input type="text" name="url_title" value="$E{$Form{'url_title'}}" size="50" /><br />\n);
  print qq(Optional Image URL: <input type="text" name="img" value="$E{$Form{'img'}}" size="45" /><p />\n);
  print qq(<input type="submit" value="Post Message" /> <input type="reset" />\n);
  print "</form>\n";
  print qq(<br /><hr size="7" width="75%" />\n);
  if ($show_faq) {
    print qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ] [ <a href="$E{"$baseurl/$faqfile"}">FAQ</a> ]</center>\n);
  } else {
    print qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]</center>\n);
  }
  print "</body></html>\n";
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

   # $allow_html not yet implemented, always strip.

   $comments =~ s#</?\w+[^>]*># #g;
   $comments =~ s#<#&lt;#g;
   $comments =~ s#>#&gt;#g;
   $comments =~ s#"#&quot;#g;

   # escape & unless part of a valid looking entity.
   $comments =~ s/(&#?\w{1,20};)|&/ defined $1 ? $1 : '&amp;' /ge;

   return $comments;
}

###################################################################

BEGIN { # START OF INLINED use CGI::NMS::Charset
package CGI::NMS::Charset;
use strict;

require 5.00404;

use vars qw($VERSION);
$VERSION = sprintf '%d.%.2d', (q$Revision: 1.36 $ =~ /(\d+)\.(\d+)/);

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

} # END OF INLINED use CGI::NMS::Charset

