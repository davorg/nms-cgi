#!/usr/bin/perl -Tw
#
# $Id: countdown.pl,v 1.1.1.1 2001-11-11 16:48:45 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/09/18 19:26:47  dave
# Added CVS keywords.
#
#

#use strict;
use POSIX 'strftime';
use Time::Local;
use CGI qw(:standard);

# Configuration

# @from_date = (yyyy,mm,dd,hh,mm,ss);
# Which means: (year,month,day,hour,minute,second)
my @from_date = (2002,9,7,0,0,0);

my $date_fmt = '%c';

# End configuration

$from_date[0] -= 1900;
$from_date[1]--;

my @diffs = ('X', 12, 'X', 24, 60, 60);

if ($ENV{QUERY_STRING}) {
  $ENV{QUERY_STRING} =~ s/%2C/,/g;
  $ENV{QUERY_STRING} =~ s/=//g;
   @from_date = split(/,/, $ENV{QUERY_STRING});
}

my @now = reverse((localtime)[0 .. 5]);

my $from_date = strftime($date_fmt, reverse @from_date);
my $now = strftime($date_fmt, reverse @now);

print header;
print start_html(-title => "Countdown to: $from_date");
print h1("Countdown to: $from_date");
print hr;

if (timelocal(reverse @now) > timelocal(reverse @from_date)) {
  print p('Date has passed');
  exit;
}

@days = (31, is_leap($now[0]+1900) ? 29 : 28 , 31, 30, 31, 30, 31,
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
      die "Argh!!";
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

print hr;
print p("It is currently $now");
print end_html;

sub is_leap {
  my $y = shift;

  (!($y % 100) && !($y % 400)) || (($y % 100) && !($y % 4));
}
