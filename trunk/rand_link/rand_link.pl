#! /usr/bin/perl -Tw
#
# $Id: rand_link.pl,v 1.9 2002-05-01 08:09:55 gellyfish Exp $
#

use strict;
use POSIX qw(locale_h strftime);
use CGI qw(redirect);
use Fcntl qw(:DEFAULT :flock);
use vars qw($DEBUGGING $done_headers);

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
   
my $linkfile = '/path/to/links/database';

# If $uselog is set to 1 then the redirections will be logged to the file
# set in $logfile

my $uselog = 1;

# $logfile should be the full filesystem path to a file that the CGI program
# can write to

my $logfile = '/path/to/rand_log';

# $date_format describes the format of the dates that
# will be used in the log - the replacement parameters you can use here are:
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

my $date_format = '%Y-%m-%d %H:%M:%S';

my $locale      = '';

# End configuration

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

open (LINKS, $linkfile)
  or die "Can't open link file: $!\n";

my @links = <LINKS>;

chomp @links;
my $link = $links[rand @links];
close LINKS;


if ($uselog) {

  eval
  {
       strftime(LC_TIME, $locale) if $locale;
  };

  my $date = strftime($date_format, localtime());

  sysopen (LOG, $logfile, O_RDWR|O_APPEND|O_CREAT)
    or die "Can't open logfile: $!\n";
  flock(LOG, LOCK_EX)
    or die "Can't lock logfile: $!\n";
   print LOG "$ENV{REMOTE_HOST} - [$date]\n";
  close (LOG)
    or die "Can't close logfile: $!\n";
}

print redirect($link);
$done_headers++;

exit;
