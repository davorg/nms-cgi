#! /usr/bin/perl -Tw
#
# $Id: rand_link.pl,v 1.5 2001-11-25 11:39:38 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:16:45  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
#

use strict;
use POSIX qw(strftime);
use CGI qw(redirect);
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:DEFAULT :flock);
use vars qw($DEBUGGING);

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

open (LINKS, $linkfile)
  or die "Can't open link file: $!\n";

my @links = <LINKS>;

chomp @links;
my $link = $links[rand @links];
close LINKS;

print redirect($link);

if ($uselog) {
  my $date = strftime($date_format, localtime());

  sysopen (LOG, $logfile, O_RDWR|O_APPEND|O_CREAT)
    or die "Can't open logfile: $!\n";
  flock(LOG, LOCK_EX)
    or die "Can't lock logfile: $!\n";
   print LOG "$ENV{REMOTE_HOST} - [$date]\n";
  close (LOG)
    or die "Can't close logfile: $!\n";
  open (LOG, ">>$logfile");
  close (LOG);
}

exit;
