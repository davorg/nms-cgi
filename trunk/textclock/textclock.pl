#!/usr/bin/perl -Tw
#
# $Id: textclock.pl,v 1.11 2002-07-23 21:00:17 nickjc Exp $
#

use strict;
use POSIX qw(locale_h strftime);
use CGI 'header';
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
   
my $Display_Week_Day  = 1;
my $Display_Month     = 1;
my $Display_Month_Day = 1;
my $Display_Year      = 1;
my $Display_Time      = 1;
my $Display_Time_Zone = 1;
my $locale            = '';

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

      if ( $DEBUGGING )
      {
         $message =~ s/</&lt;/g;
         $message =~ s/>/&gt;/g;
      }
      else
      {
         $message = '';
      }
      
      my ( $pack, $file, $line, $sub ) = caller(0);
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

my @date_fmt;

push @date_fmt, '%A'       if $Display_Week_Day;
push @date_fmt, '%B'       if $Display_Month;
push @date_fmt, '%d'       if $Display_Month_Day;
push @date_fmt, '%Y'       if $Display_Year;
push @date_fmt, '%H:%M:%S' if $Display_Time;
push @date_fmt, '%Z'       if $Display_Time_Zone;

print header(-type => 'text/plain');
$done_headers++;

eval
{
   setlocale(LC_TIME, $locale ) if $locale;
};

print strftime(join(' ', @date_fmt), localtime);
