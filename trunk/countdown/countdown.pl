#!/usr/bin/perl -wT
#
# $Id: countdown.pl,v 1.8 2002-01-14 09:31:48 gellyfish Exp $
#
# Revision 1.6  2001/12/01 19:45:21  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
# Revision 1.5  2001/11/25 11:39:38  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:14:41  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:45  davorg
# Initial import
#

use strict;
use POSIX qw(strftime);
use Time::Local;
use CGI qw(:standard);
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

# @from_date = (yyyy,mm,dd,hh,mm,ss);
# Which means: (year,month,day,hour,minute,second)
my @from_date = (2002,9,7,0,0,0);
my $delimiter = "<br />";
my $date_fmt = '%H:%M:%S %d/%b/%Y';

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

# If $EMULATE_MATTS_CODE is set to 1 then this will behave exactly as the
# original countdown.pl did.

my $EMULATE_MATTS_CODE = 1;

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

my @diffs = ('X', 12, 'X', 24, 60, 60);

# use the CGI module's param function to import from the query
# string the variable named date.  That variable is then split
# on a comma.  If there is a valid date in the query string, it
# replaces the default one.

# This will still get an uninitialized warning won't it ?

my @query_string = split(/,/, length param("date") > 0 ? 
                                   param("date") : param("keywords"));


# The appropriate days for each month.

my @days = (31, (is_leap($now[0]+1900) ? 29 : 28), 31, 30, 31, 30, 31,
	 31, 30, 31, 30, 31);

if ( @query_string == 6 )
{

   if ( ($from_date[1] < 13 and $from_date > 0) and 
        ($from_date[2] <= $days[$from_date[1] - 1 ]) and
        ($from_date[3] >= 0 and $from_date[3] < 24 ) and
        ($from_date[4] >= 0 and $from_date[4] < 60 ) and
        ($from_date[5] >= 0 and $from_date[5] < 60 ))
   {
      @from_date = @query_string;
   }
}

# format the date so that calculations can be more easily done
# to it.

$from_date[0] -= 1900;
$from_date[1]--;

my @now = reverse((localtime)[0 .. 5]);

my $from_date = strftime($date_fmt, reverse @from_date);
my $now = strftime($date_fmt, reverse @now);

# Output formatting

print header;

# Check to see whether the date has already passed.

if (timelocal(reverse @now) > timelocal(reverse @from_date)) {
  print p('Date has passed');
  exit;
}


my @diff = ('-') x 6;
my @skip = () x 6;

# Calculate the difference

foreach (reverse 0 .. $#from_date) {

  if ($from_date[$_] eq 'XX') {
    $skip[$_] = 1;
    next;
  }

  $diff[$_] = $from_date[$_] - $now[$_];

  if ($diff[$_] < 0) {
    if ($_ == 0) {
      die "$!";
    }
    elsif ($_ == 2)
    {
      $diff[$_] += $days[$now[1]];
      $now[$_ - 1]++;
    }
    else {
      $diff[$_] += $diffs[$_];
      $now[$_ - 1]++;
    }
  }
}

# Format then output the data.

my @units = qw(Year Month Day Hour Minute Second);


for my $diff_ index(0 .. $#diff) {
  if ($diff[$diff_index] == 0 and !$EMULATE_MATTS_CODE) {
    $skip[$diff_index] = 1;
  }
  next if $skip[$diff_index];

  $diff .= "$diff[$diff_index] $units[$diff_index]";
  $diff .= 's' if $diff[$diff_index] != 1;
  $diff .= "$delimiter\n";
}

# Print out the resulting difference in a <p></p>

print p($diff), "\n";

# is_leap is a subroutine that takes 1 argument, a year.  It then checks
# whether that year is a leap year; If it is, it returns true, otherwise
# it returns false.

sub is_leap {
  my $y = shift;
  return (!($y % 100) && !($y % 400)) || (($y % 100) && !($y % 4));
}

