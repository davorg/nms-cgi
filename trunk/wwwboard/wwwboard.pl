#!/usr/bin/perl -Tw
#
# $Id: wwwboard.pl,v 1.27 2002-07-23 20:44:51 nickjc Exp $
#

use strict;
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(locale_h strftime);
use vars qw($DEBUGGING $done_headers);
my $VERSION = '1.0';

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
# wwwboard.pl v1.0
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

      if ( $DEBUGGING )
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

if ( $use_time ) {
   $date_fmt = "$time_fmt $date_fmt";
}


my $id = get_number();


my $Form = parse_form();

my $variables = get_variables($Form,$id);

new_file($variables);
main_page($variables);

thread_pages($variables);

return_html($variables);

sub get_number {
  sysopen(NUMBER, "$basedir/$datafile", O_RDWR|O_CREAT)
    || die "Can't open number file: $!\n";
  flock(NUMBER, LOCK_EX)
    || die "Can't lock number file: $!\n";
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


    @followup_num = keys %fcheck;

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
    $name =~ s/\"//g;
    $name =~ s/<//g;
    $name =~ s/>//g;
    $name =~ s/\&//g;

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
    $variables->{subject} = escape_html($Form->{subject});
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
  if ($Form->{'img'} =~ m%^(.+tp://.*\.$image_suffixes)$%) {
    $variables->{message_img} = $1;
  }

  if (my $body = $Form->{'body'}) {
    $body = strip_html($body,$allow_html);
    $body = "<p>$body</p>";
    $body =~ s/\cM//g;
    $body =~ s|\n\n|</p><p>|g;
    $body =~ s%\n%<br />%g;

    # I'm not entirely sure if this is what is actually meant :
    # it would allow someone to subvert $allow_html by putting escaped stuff
    # in the message and having the script expand it.

    $variables->{'body'} = unescape_html($body);
     
  } else {
    error('no_body',{Form => $Form});
  }

  if ($quote_text) 
  {
    my $hidden_body = $variables->{'body'};

    if ( $quote_html ) 
    {
       $hidden_body = escape_html($hidden_body);
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

  flock(NEWFILE,LOCK_EX)
    || die "Flock: $! [$basedir/$mesgdir/$variables->{id}.$ext]";

  my $faq = $show_faq ? qq( [ <a href="$baseurl/$faqfile">FAQ</a> ]) : '';
  my $print_name = $variables->{email} ? 
            qq(<a href="mailto:$variables->{email}">$variables->{name}</a> ) : 
            $variables->{name};
  my $ip = $show_poster_ip ? "($ENV{REMOTE_ADDR})" : '';

  my $pr_follow = '';

  if ( $variables->{followup} )
  {
     $pr_follow = 
    qq(<p>In Reply to:
       <a href="$variables->{last_message}.$ext">$variables->{origsubject}</a> posted by ); 

      if ( $variables->{origemail} )
      {
        $pr_follow .=  
         qq(<a href="$variables->{origemail}">$variables->{origname}</a>) ;
      }
      else
      {
        $pr_follow .= $variables->{origname};
      }
      $pr_follow .= '</p>';
  }

  my $img = $variables->{message_img} ?
    qq(<p align="center"><img src="$variables->{message_img}"></p>\n) : '';
  my $url = $variables->{message_url} ? 
    qq(<ul><li><a href="$variables->{message_url}">$variables->{message_url_title}</a></li></ul><br>) :
      '';

  print NEWFILE <<END_HTML;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <title>$variables->{subject}</title>
    $style_element
  </head>
  <body>
    <h1 align="center">$variables->{subject}</h1>
    <hr />
    <p align="center">
      [ <a href="#followups">Follow Ups</a> ]
      [ <a href="#postfp">Post Followup</a> ]
      [ <a href="$baseurl/$mesgfile">$title</a> ]
      $faq
    </p>

  <hr />
  <p>Posted by $print_name $ip on $variables->{date}</p>

  $pr_follow 

  $img

  $variables->{'body'}<br />$url

  <hr />
  <p><a id="followups" name="followups">Follow Ups:</a></p>
  <ul><!--insert: $variables->{id}-->
  </ul><!--end: $variables->{id}-->
  <br /><hr />
  <p><a id="postfp" name="postfp">Post a Followup</a></p>
  <form method=POST action="$cgi_url">
END_HTML

  my $follow_ups = ( defined $variables->{followups} )  ? 
                     join( ',', @{$variables->{followups}}) : '';

  $follow_ups .= ',' if length($follow_ups);

  my $id = $variables->{id};

  print NEWFILE qq(<input type="hidden" name="followup" value="$follow_ups$id" />);

  print NEWFILE qq(<input type=hidden name="origname" value="$variables->{name}" />);
  print NEWFILE qq(<input type=hidden name="origemail" value="$variables->{email}" />)
    if $variables->{email};

  print NEWFILE <<END_HTML;
<input type="hidden" name="origsubject" value="$variables->{subject}" />
<input type="hidden" name="origdate" value="$variables->{date}" />
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
    print NEWFILE map { "$quote_char " . strip_html($_) . "\n" } 
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

   my ( $variables ) = @_;

  open(MAIN_LOCK,">>$basedir/$mesgfile.lck") ||
    die "Open: $! [$basedir/$mesgfile.lck]";

  flock(MAIN_LOCK,LOCK_EX) ||
    die "Flock: $! [$basedir/$mesgfile.lck]";

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
<!--top: $id--><li><a href="$mesgdir/$id.$ext">$subject</a> - <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } else {
        print MAIN_OUT $_;
      }
    }
  } else {
    foreach (@main) {
      my $work = 0;
      if (/<ul><!--insert: $variables->{last_message}-->/) {
        print MAIN_OUT <<END_HTML;
<ul><!--insert: $variables->{last_message}-->
<!--top: $id--><li><a href="$mesgdir/$id.$ext">$subject</a> - <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } elsif (/\(<!--responses: (\d+?)-->(\d+?)\)/) {
        my $response_num = $1;
        my $num_responses = $2;
        $num_responses++;
        foreach my $followup_num (@{$variables->{followups}}) {
          if ($followup_num == $response_num) {
            print MAIN "(<!--responses: $followup_num-->$num_responses)\n";
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

  close(MAIN_LOCK);
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

    open(FOLLOWUP_LOCK, ">>$basedir/$mesgdir/$followup_num.lck")
      || die "$!";

    flock FOLLOWUP_LOCK, LOCK_EX or die "Can't lock $!\n";

    open(FOLLOWUP, "<$basedir/$mesgdir/$followup_num.$ext")
      || die "$!";

    my @followup_lines = <FOLLOWUP>;
    close(FOLLOWUP);


    open(FOLLOWUP, ">$basedir/$mesgdir/$followup_num.tmp") || die "$!"; 

    flock FOLLOWUP, LOCK_EX or die "Can't lock $!\n";

    foreach (@followup_lines) {
      my $work = 0;
      if (/<ul><!--insert: $variables->{last_message}-->/) {
        print FOLLOWUP<<END_HTML;
<ul><!--insert: $variables->{last_message}-->
<!--top: $id--><li><a href="$id\.$ext">$subject</a> <b>$name</b> <i>$date</i>
(<!--responses: $id-->0)
<ul><!--insert: $id-->
</ul><!--end: $id-->
END_HTML
      } elsif (/\(<!--responses: (\d+?)-->(\d+?)\)/) {
        my $response_num = $1;
        my $num_responses = $2;
        $num_responses++;
        foreach $followup_num (@{$variables->{followups}}) {
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

  my $url = $variables->{message_url} ? 
    qq(<p><b>Link:</b> <a href="$variables->{message_url}">$variables->{message_url_title}</a></p>) : '';
  my $img = $variables->{message_img} ? 
    qq(<p><b>Image:</b> <img src="$variables->{message_img}"></p>) : '';

  print <<END_HTML;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Message Added: $variables->{subject}</title>
    $style_element
  </head>
  <body>
    <h1 align="center">Message Added: $variables->{subject}</h1>
    <p>The following information was added to the message board:</p>
    <hr />
    <p><b>Name:</b> $variables->{name}<br />
      <b>E-Mail:</b> $variables->{email}<br />
      <b>Subject:</b> $variables->{subject}<br />
      <b>Body of Message:</b></p>
      <p>$variables->{'body'}</p>
    $url
    $img

    <p><b>Added on Date:</b> $variables->{date}</p>
    <hr />
    <p align="center">
       [ <a href="$baseurl/$mesgdir/$id.$ext">Go to Your Message</a> ] 
       [ <a href="$baseurl/$mesgfile">$title</a> ]
    </p>
  </body>
</html>
END_HTML
}

sub error {
  my ($error, $variables) = @_;

  print header;
  $done_headers++;

  my ($error_message, $error_title);
  if ($error eq 'no_name') {
    $error_title = 'No Name';
    $error_message =<<EOMESS;
  <p>You forgot to fill in the 'Name' field in your posting.  Correct it 
    below and re-submit.  The necessary fields are: Name, Subject and 
    Message.</p>
EOMESS
  } elsif ($error eq 'no_subject') {
    $error_title = 'No Subject';
    $error_message =<<EOMESS;
  <p>You forgot to fill in the 'Subject' field in your posting.  Correct it 
  below and re-submit.  The necessary fields are: Name, Subject and 
  Message.</p>
EOMESS
  } elsif ($error eq 'no_body') {
    $error_title = 'No Message';
    $error_message =<<EOMESS;
<p>You forgot to fill in the 'Message' field in your posting.  Correct it
below and re-submit.  The necessary fields are: Name, Subject and 
Message.</p>
EOMESS
   } elsif ($error eq 'field_size') {
     $error_title = 'Field too Long';
     $error_message =<<EOMESS;
  <p>One of the form fields in the message submission was too long.  The 
  following are the limits on the size of each field (in characters):</p>
  <ul>
    <li>Name: $max_len{'name'}</li>
    <li>E-Mail: $max_len{'email'}</li>
    <li>Subject: $max_len{'subject'}</li>
    <li>Body: $max_len{'body'}</li>
    <li>URL: $max_len{'url'}</li>
    <li>URL Title: $max_len{'url_title'}</li>
    <li>Image URL: $max_len{'img'}</li>
  </ul>
  <p>Please modify the form data and resubmit.</p>
EOMESS
   } else {
     $error_title = 'Application error';
     $error_message =<<EOMESS;
<p>An error has occurred while your message was being submitted
please use your back button and try again</p>
EOMESS
   }
   print <<END_HTML;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title ERROR: $error_title</title>
    $style_element
  </head>
  <body><h1 align="center">ERROR: $error_title</h1>
    $error_message
  <hr>
END_HTML
  rest_of_form($variables);
  exit;
}

sub rest_of_form {

  my ( $variables ) = @_;

  print qq(<form method="POST" action="$cgi_url">\n);

  my %Form = %{$variables->{Form}};

  if ($variables->{followup} == 1) {
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
  
  $Form{'body'} = escape_html($Form{'body'});

  print "Message:<br>\n";
  print qq(<textarea COLS="50" ROWS="10" name="body">\n);

  print "$Form{'body'}\n";
  print "</textarea><p>\n";
  print qq(Optional Link URL: <input type=text name="url" value="$Form{'url'}" size="45" /><br />\n);
  print qq(Link Title: <input type="text" name="url_title" value="$Form{'url_title'}" size="50" /><br />\n);
  print qq(Optional Image URL: <input type="text" name="img" value="$Form{'img'}" size="45" /><p />\n);
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

# subroutine to crudely strip html from a text string
# ideally we would want to use HTML::Parser or somesuch.
# we will also implement any selective tag replacement here
# thus all user supplied input that will be displayed should
# be passed through this before being displayed.

sub strip_html
{
   my ( $comments,$allow_html ) = @_;

   $allow_html = defined $allow_html ? $allow_html : 0;

   $comments =~ s/(?:<[^>'"]*|".*?"|'.*?')+>//gs unless $allow_html;

   # remove any comments that could harbour an attempt at an SSI exploit
   # suggested by Pete Sargeant

   $comments =~ s/<!--.*?-->/ /gs;

   # mop up any stray start or end of comment tags.

   $comments = "<!-- -->$comments<!-- -->" if $allow_html;

   return $comments;
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
