#!/usr/bin/perl -wT
#
#  $Id: ffa.pl,v 1.11 2002-02-01 09:18:48 gellyfish Exp $
#
#  $Log: not supported by cvs2svn $
#  Revision 1.10  2002/01/31 23:50:04  nickjc
#  * start_html syntax fix
#  * file locking review
#  * handle write errors better
#  * escape_html before the first place HTML could be displayed
#  * silence some warnings
#  * minor XHTML fixes
#
#  Revision 1.9  2002/01/30 09:21:04  lertl
#  *) redone error checking for no_url() and no_title()
#  *) added escape_html function from FormMail.pl
#  *) added strip_nonprintable function from FormMail.pl
#  *) added $CGI::DISABLE_UPLOADS and $CGI::POST_MAX
#  *) added lock file checking (I guess this needs some more work)
#  *) allow https:// URLs
#  *) fixed various typos
#
#  Revision 1.8  2001/12/01 19:45:21  gellyfish
#  * Tested everything with 5.004.04
#  * Replaced the CGI::Carp with local variant
#
#  Revision 1.7  2001/11/26 13:40:05  nickjc
#  Added \Q \E around variables in regexps where metacharacters in the
#  variables shouldn't be interpreted by the regex engine.
#
#  Revision 1.6  2001/11/24 11:59:58  gellyfish
#  * documented strfime date formats is various places
#  * added more %ENV cleanup
#  * spread more XHTML goodness and CSS stylesheet
#  * generalization in wwwadmin.pl
#  * sundry tinkering
#
#  Revision 1.5  2001/11/15 09:11:04  gellyfish
#  * Fixed the -style thing in start_html
#  * added nms.css to the links page
#  * fixed the hard coded HTML to be nearly XHTML
#  * fixed header in the die handler.
#
#  Revision 1.4  2001/11/13 20:35:14  gellyfish
#  Added the CGI::Carp workaround
#
#  Revision 1.3  2001/11/12 21:24:37  gellyfish
#  * Captured newer version from elsewhere
#  * Made links.html an XHTML file
#
#  Revision 1.2  2001/11/12 16:52:36  gellyfish
#  * Removed confusing log messages
#
#
# 

use strict;
use CGI qw(:standard);
use Fcntl qw(:flock);

use vars qw($DEBUGGING);

# We don't need file uploads or very large POST requests.
# Annoying locution to shut up 'used only once' warning in older perl

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 1000000;

# sanitize the environment.

delete @ENV{qw(ENV BASH_ENV IFS PATH)};

#
# Configurable stuff
#

#
# $DEBUGGING must be set in a BEGIN block in order to have it be set before
# the program is fully compiled.
# This should almost certainly be set to 0 when the program is 'live'
#

BEGIN
{
   $DEBUGGING = 1;
}
   

# must be set for all configurations

# $directory is the full filesystem path to the files that are associated
# with this program. The webserver needs write permissions for this path.

my $directory  = '/usr/local/apache/htdocs/links';

# This is the title that will be displayed for some of the pages.

my $linkstitle = "Blah Blah Pointless FFA Script";

# Act as drop in replacement for Matts FFA script
# if so the $filename & $linksurl must be valid (otherwise not used);

my $emulate_matts_code = 1;

# $filename is the full filesystem path of the html file in which the links
# are created.

my $filename          = "$directory/links.html";

# $linksurl is the public URL of the links page.

my $linksurl          = "http://localhost/links/links.html";

# Store all links in database file ?

my $usedatabase = 1;

# This is the location of the database file in which the links can be kept.

my $database    = "$directory/database.txt";

# if matts ffa is not being emulated then we must use the database.

unless ( $emulate_matts_code )
{
   $usedatabase = 1;
}

#
# If $sendmail is set to 1 then:
#
# *   $mailer must be set to be a valid path for a mailer on the machine
#     which this script will run.
# *   $mail_address must be set to a valid e-mail address to which you
#     you want notifications of new additions sent.
#

my $sendmail = 1;
my $mailer = '/usr/lib/sendmail -t -oi -oem';
my $mail_address = 'gellyfish@localhost';

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

#

# $default_section indicates the section to which a link will be added
# if for some reason a section isn't provided.

my $default_section = 'misc';

# %sections lists the sections that are available for links to be added to
# if the links.html is altered to contain different sections then this will
# need to be changed to.  The keys of the hash (the bits to the left of the
# '=>') should match the appropriate comments in the links.html file.
#

my %sections = (
                busi => 'Business',
                comp => 'Computers',
                educ => 'Education',
                ente => 'Entertainment',
                gove => 'Government',
                pers => 'Personal',
                misc => 'Miscellaneous'
               );

#
# No user maintainable parts beneath here
#

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

my $linkscgi   = url();
my $url        = param('url')     || '';
my $title      = param('title')   || '';
my $section    = param('section') || $default_section;
my $host_added = remote_host();

# Remove non-printable characters
$url     = strip_nonprintable($url);
$title   = strip_nonprintable($title);
$section = strip_nonprintable($section);

# Escape HTML
$url     = escape_html($url);
$title   = escape_html($title);
$section = escape_html($section);

# Don't waste time with jokers who just hit the submit button.
unless ($url or $title) {
    print redirect($linksurl);
    exit;
}

no_url()   unless $url;
no_title() unless $title;

no_url() if ($url eq 'http://' || $url !~ m#^(f|ht)tps?://[-\w.]+?/?# );

open(LOCK, ">$filename.lck") || die "Can't open $filename.lck (write) - $!\n";
flock(LOCK, LOCK_EX)         || die "Can't lock $filename.lck (excl) - $!\n";

open(FILE,"<$filename") || die "Can't open $filename (read) - $!\n";

my $i = 1;

while ( defined(my $line = <FILE>) )
{    
    if ($line =~ m#<li><a href="?([^"]+)"?>([^<]+)</a>#) 
    {
        $i++;
        repeat_url($1) if ($url eq $1); 
    }
}

seek FILE, 0, 0 or die "seek to start of $filename: $!";

my $tmpnam = "$filename.tmp";

open (NEWFILE,">$tmpnam") || die "Can't open $tmpnam (write) - $!\n";

while ( defined(my $line = <FILE>) )
{ 
   if ($line =~ /<!--time-->/) 
   {
      print NEWFILE "<!--time--><b>Last link was added ",datestamp(),"</b><hr />\n"
         or ( unlink($tmpnam), die "write to $tmpnam: $!" );
   }
   elsif ($line =~ /<!--number-->/) 
   {
      print NEWFILE "<!--number--><b>There are <i>",$i,
                    "</i> links on this page.</b><br />\n"
                    or ( unlink($tmpnam), die "write to $tmpnam: $!" );
   }
   else 
   {
       print NEWFILE $line or ( unlink($tmpnam), die "write to $tmpnam: $!" );
   }

   SECTION:
   foreach my $tag ( keys %sections) 
   { 
      if (($section eq $sections{$tag}) && ($line =~ /<!--\Q$tag\E-->/)) 
      {
         print NEWFILE qq%<li><a href="$url">$title</a></li>\n%
             or ( unlink($tmpnam), die "write to $tmpnam: $!" );
         last SECTION;
      }
   }
}

close NEWFILE or ( unlink($tmpnam), die "write to $tmpnam: $!" );

rename( $tmpnam, $filename) || die "Can't rename $tmpnam - $!\n";

close (LOCK);

print redirect($linksurl);


if ($usedatabase) 
{
    open (DATABASE,">>$database") || die "Can't open $database - $!\n";
    flock(DATABASE,LOCK_EX)       || die "Can't flock $database (excl) - $!\n";
    print DATABASE "$section|$url|$title|@{[time]}|$host_added\n";
    close(DATABASE);
}

if ($sendmail )
{
    open(MAILER,"| $mailer" ) || die "Can't fork for mail - $!\n";
    print MAILER <<EIEIO;
To: $mail_address
From: $linkstitle <$mail_address>
Subject: Link Added !

The link $url ($title) was added from $host_added
EIEIO

    close(MAILER) || die "Error with $mailer - $? \n";
}

sub datestamp
{
   my ( $time ) = @_;

   $time ||= time();

   my @months = qw(
                   January
                   February
                   March
                   April
                   May
                   June
                   July
                   August
                   September
                   October
                   November
                   December
                  );

   my @days   = qw(
                   Sunday
                   Monday
                   Tuesday
                   Wednesday
                   Thursday
                   Friday
                   Saturday
                  );

   my ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime($time))[0 .. 6];
   return sprintf "on %s, %s %.2d, %.4d at %.2d:%.2d:%.2d",
                  $days[$wday], $months[$mon],$mday,$year+1900,$hour,$min,$sec;
}

sub no_url 
{
   print header, 
         start_html('-title'   => 'ERROR: No URL',
                    '-BGCOLOR' => '#FFFFFF',
                    '-style' => { src  => $style } );
   print <<EIEIO;
<h1>No URL</h1>
<p>
You either forgot to enter the url you wanted added to the Free for 
all link page or you entered one which was invalid.</p>
<p>
   <form method="POST" action="$linkscgi">
      <input type="hidden" name="title" value="$title" />
      <input type="hidden" name="section" value="$section" />
      URL: <input type="text" name="url" size="50" />
      <br />
      <input name="submit" value="OK" type="submit" /> * 
      <input name="reset" value="Clear" type="reset" />
<hr />
<a href="$linksurl">$linkstitle</a>
</form></p></body></html>
EIEIO

  exit;
}

sub no_title 
{
   print header, 
         start_html('-title'   => 'ERROR: No Title',
                    '-BGCOLOR' => '#FFFFFF',
                    '-style' => { src  => $style } );
   print <<EIEIO;
<h1>No Title</h1>
<p>
You either forgot to enter the title you wanted for your link or the title
you did enter contained characters that can't be displayed.
</p>
<p>
<form method="POST" action="$linkscgi">
   <input type="hidden" name="url" value="$url" /> 
   <input type="hidden" name="section" value="$section" />
   TITLE: <input type="text" name="title" size="50" />
   <br />
   <input name="submit" value="OK" type="submit" /> * 
   <input type="reset" name="reset" value="clear" />
   <hr />
   <a href="$linksurl">$linkstitle</a>
</form></p></body></html>
EIEIO

   exit;
}

sub repeat_url 
{
   print header, 
         start_html('-title'   => 'ERROR: Repeat URL',
                    '-BGCOLOR' => '#FFFFFF',
                    '-style'   => { src  => $style } );
   print <<EIEIO;
<h1>Repeat URL</h1>
<p>
Sorry, this link is already in the Free For All Link Page
You cannot add this URL to it again. </p>
<p>
<a href="$linksurl">$linkstitle</a>
</p>
</body></html>
EIEIO

   exit;
}

sub strip_nonprintable {
   my $text = shift;
   $text=~ tr#\011\012\040-\176\200-\377##dc;
   return $text;
}

sub escape_html {
   my $str = shift;

   my %escape_html_map = (
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      "'" => '&#39;',
   );

   my $chars = join '', keys %escape_html_map;

   $str =~ s/([\Q$chars\E])/$escape_html_map{$1}/g;
   return $str;
}
