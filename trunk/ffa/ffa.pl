#!/usr/bin/perl -wT
#
#  $Id: ffa.pl,v 1.7 2001-11-26 13:40:05 nickjc Exp $
#
#  $Log: not supported by cvs2svn $
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
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:flock);

use vars qw($DEBUGGING);

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
# with this program.

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

BEGIN
{
   my $error_message = sub {
                             my ($message ) = @_;
                             print "<h1>It's all gone horribly wrong</h1>";
                             print $message if $DEBUGGING;
                            };
  set_message($error_message);
}   

my $linkscgi   = url();
my $url        = param('url')     || no_url();
my $title      = param('title')   || no_title();
my $section    = param('section') || $default_section;
my $host_added = remote_host();

no_url() if ($url eq 'http://' || $url !~ m#^(f|ht)tp://[-\w.]+?/?# );


open(FILE,$filename) || die "Cant open $filename (read) - $!\n";
flock(FILE,LOCK_SH) || die "Couldnt lock $filename (shared) - $!\n";
my @lines = <FILE>;
close(FILE);

my $i = 1;

foreach my $line (@lines) 
{    
    if ($line =~ m#<li><a href="?([^"]+)"?>([^<]+)</a>#) 
    {
        $i++;
        repeat_url($1) if ($url eq $1); 
    }
}

my $tmpnam = "$directory/@{[rand(time)]}${$}.tmp";

open (FILE,">$tmpnam") || die "$tmpnam - $!\n";
flock(FILE,LOCK_EX) || die "Cant lock $tmpnam (Exclusive) - $!\n";

foreach my $line (@lines) 
{ 
   if ($line =~ /<!--time-->/) 
   {
      print FILE "<!--time--><b>Last link was added",datestamp(),"</b><hr />\n";
   }
   elsif ($line =~ /<!--number-->/) 
   {
      print FILE "<!--number--><b>There are <i>",$i,
                 "</i> links on this page.</b><br />\n";
   }
   else 
   {
       print FILE $line;
   }

   SECTION:
   foreach my $tag ( keys %sections) 
   { 
      if (($section eq $sections{$tag}) && ($line =~ /<!--\Q$tag\E-->/)) 
      {
         print FILE qq%<li><a href="$url">$title</a></li>\n%; 
         last SECTION;
      }
   }
}

close (FILE);

rename( $tmpnam, $filename) || die "Cant rename $tmpnam - $!\n";

print redirect($linksurl);


if ($usedatabase) 
{
    open (DATABASE,">>$database") || die "Cant open $database - $!\n";
    flock(DATABASE,LOCK_EX) || die "Can't flock $database (exc) - $!\n";
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
         start_html(-title   => 'ERROR: No URL',
                    -BGCOLOR => '#FFFFFF',
                    -style => { src  => $style } );
   print <<EIEIO;
<h1>No URL</h1>
<p>
You either forgot to enter the url you wanted added to the Free for 
all link page or you entered one which was invalid.</p>
<p>
   <form method=POST action="$linkscgi">
      <input type=hidden name="title" value="$title" />
      <input type=hidden name="section" value="$section" />
      URL: <input type=text name="url" size=50 />
      <br />
      <input name="submit" value="OK" type=submit /> * 
      <input name="reset" value="Clear" type=reset />
<hr />
<a href="$linksurl">$linkstitle</a>
</form></p></body></html>
EIEIO

  exit;
}

sub no_title 
{
   print header, 
         start_html(-title   => 'ERROR: No Title',
                    -BGCOLOR => '#FFFFFF',
                    -style => { src  => $style } );
   print <<EIEIO;
<h1>No Title</h1>
<p>
You either forgot to enter the title you wanted for your link or the title
you did enter contained characters that can't be displayed.
</p>
<p>
<form method=POST action="$linkscgi">
   <input type=hidden name="url" value="$url" /> 
   <input type=hidden name="section" value="$section" />
   TITLE: <input type=text name="title" size=50 />
   <br />
   <input name="submit" value="OK" type=submit /> * 
   <input type=reset name="reset" value="clear">
   <hr />
   <a href="$linksurl">$linkstitle</a>
</form></p></body></html>
EIEIO

   exit;
}

sub repeat_url 
{
   print header, 
         start_html(-title   => 'ERROR: Repeat URL',
                    -BGCOLOR => '#FFFFFF',
                    -style => { src  => $style } );
   print <<EIEIO;
<h1>Repeat URL</h1>
<p>
Sorry, this link is already in the Free For All Link Page
You cannot add this URL to it again. </p>
<p>
<a href="$linksurl">$linkstitle</a>
</p>
</body></html>\n";
EIEIO

   exit;
}
