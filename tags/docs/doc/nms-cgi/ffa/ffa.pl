#!/usr/bin/perl -wT
#
#  $Id: ffa.pl,v 1.1.1.1 2001-11-13 16:36:29 gellyfish Exp $
#
#  $Log: not supported by cvs2svn $
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
use CGI::Carp qw(fatalsToBrowser);
use Fcntl qw(:flock);

@ENV{qw(PATH IFS)} = ('') x 2;

#
# Configurable stuff
#

# must be set for all configurations
# 

my $directory  = '/usr/local/apache/htdocs/links';
my $linkstitle = "Blah Blah Pointless FFA Script";

# Act as drop in replacement for Matts FFA script
# if so the $filename & $linksurl must be valid (otherwise not used);

my $emulate_matts_ffa = 1;
my $filename          = "$directory/links.html";
my $linksurl          = "http://localhost/links/links.html";

# Store all links in database file ?

my $usedatabase = 1;
my $database    = "$directory/database.txt";

# if matts ffa is not being emulated then we must use the database.

unless ( $emulate_matts_ffa )
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
# generated messages.

my $style = '';

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
#

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

   foreach my $tag ( keys %sections) 
   { 
      if (($section eq $sections{$tag}) && ($line =~ /<!--$tag-->/)) 
      {
         print FILE qq%<li><a href="$url">$title</a></li>\n%; 
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
                    -style   => $style );
   print <<EIEIO;
<h1>No URL</h1>
You forgot to enter a url you wanted added to the Free for 
all link page.  Another possible problem was that your link was invalid.<p>
<form method=POST action="$linkscgi">
<input type=hidden name="title" value="$title">
<input type=hidden name="section" value="$section">
URL: <input type=text name="url" size=50><p>
<input type=submit> * <input type=reset>
<hr>
<a href="$linksurl">$linkstitle</a>
</form></body></html>
EIEIO

  exit;
}

sub no_title 
{
   print header, 
         start_html(-title   => 'ERROR: No Title',
                    -BGCOLOR => '#FFFFFF',
                    -style   => $style );
   print <<EIEIO;
<h1>No Title</h1>
You forgot to enter a title you wanted added to the Free for
all link page.  Another possible problem is that the title contained illegal 
characters.<p>
<form method=POST action="$linkscgi">
<input type=hidden name="url" value="$url"> 
<input type=hidden name="section" value="$section">
TITLE: <input type=text name="title" size=50><p>
<input type=submit> * <input type=reset>
<hr>
<a href="$linksurl">$linkstitle</a>
</form></body></html>
EIEIO

   exit;
}

sub repeat_url 
{
   print header, 
         start_html(-title   => 'ERROR: Repeat URL',
                    -BGCOLOR => '#FFFFFF',
                    -style   => $style );
   print <<EIEIO;
<h1>Repeat URL</h1>
Sorry, this URL is already in the Free For All Link Page
You cannot add this URL to it again. <p>
<a href="$linksurl">$linkstitle</a>
</body></html>\n";
EIEIO

   exit;
}
