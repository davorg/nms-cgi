#!/usr/bin/perl -Tw
#
# $Id: countdown.pl,v 1.6 2001-12-01 19:45:21 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
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

my $date_fmt = '%c';

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

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

$from_date[0] -= 1900;
$from_date[1]--;

my @diffs = ('X', 12, 'X', 24, 60, 60);

if (my $query = query_string()) {
   $query =~ s/%2C/,/g;
   $query =~ s/=//g;
   @from_date = split(/,/, $query);
}

my @now = reverse((localtime)[0 .. 5]);

my $from_date = strftime($date_fmt, reverse @from_date);
my $now = strftime($date_fmt, reverse @now);

print header(),
      start_html('title' => "Countdown to: $from_date",
                 'style' => {'href' => $style});

print h1("Countdown to: $from_date"),
      hr();

if (timelocal(reverse @now) > timelocal(reverse @from_date)) {
  print p('Date has passed'),
        end_html();
  exit;
}

my @days = (31, is_leap($now[0]+1900) ? 29 : 28 , 31, 30, 31, 30, 31,
	    31, 30, 31, 30, 31);

my @diff = ('-') x 6;
my @skip = () x 6;

foreach (reverse 0 .. $#from_date) {
#  print "$_: [@from_date][@now][@diff]\n";

  if ($from_date[$_] eq 'XX') {
    $skip[$_] = 1;
    next;
  }

  $diff[$_] = $from_date[$_] - $now[$_];

  if ($diff[$_] < 0) {
    if ($_ == 0) {
      die "Argh!! Time travel not implemented";
    } elsif ($_ == 2) {
      $diff[$_] += $days[$now[1]];
      $now[$_ - 1]++;
    } else {
      $diff[$_] += $diffs[$_];
      $now[$_ - 1]++;
    }
  }
}

#print " : [@from_date][@now][@diff]\n";

my @units = qw(Year Month Day Hour Minute Second);

my $diff;

for (0 .. $#diff) {
  next if $skip[$_];

  $diff .= "$diff[$_] $units[$_]";
  $diff .= 's' if $diff[$_] != 1;
  $diff .= "<br>\n";
}

print p($diff);

print hr(),
      p("It is currently $now"),
      end_html();

sub is_leap {
  my $y = shift;

  (!($y % 100) && !($y % 400)) || (($y % 100) && !($y % 4));
}
