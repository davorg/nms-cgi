#!/usr/bin/perl -Tw
#
# $Id: textclock.pl,v 1.1.1.1 2001-11-11 16:48:57 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/09/18 19:26:48  dave
# Added CVS keywords.
#
#

use strict;
use POSIX 'strftime';
use CGI 'header';

# Configuration

my $Display_Week_Day = 1;
my $Display_Month = 1;
my $Display_Month_Day = 1;
my $Display_Year = 1;
my $Display_Time = 1;
my $Display_Time_Zone = 1;

# End configuration

my @date_fmt;

push @date_fmt, '%A' if $Display_Week_Day;
push @date_fmt, '%B' if $Display_Month;
push @date_fmt, '%d' if $Display_Month_Day;
push @date_fmt, '%Y' if $Display_Year;
push @date_fmt, '%H:%M:%S' if $Display_Time;
push @date_fmt, '%Z' if $Display_Time_Zone;

print header(-type => 'text/plain');

print strftime(join(' ', @date_fmt), localtime);