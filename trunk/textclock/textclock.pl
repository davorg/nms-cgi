#!/usr/bin/perl -Tw
#
# $Id: textclock.pl,v 1.6 2001-12-01 19:45:22 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.5  2001/11/25 11:39:40  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:18:45  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use POSIX 'strftime';
use CGI 'header';
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
   
my $Display_Week_Day  = 1;
my $Display_Month     = 1;
my $Display_Month_Day = 1;
my $Display_Year      = 1;
my $Display_Time      = 1;
my $Display_Time_Zone = 1;

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

my @date_fmt;

push @date_fmt, '%A'       if $Display_Week_Day;
push @date_fmt, '%B'       if $Display_Month;
push @date_fmt, '%d'       if $Display_Month_Day;
push @date_fmt, '%Y'       if $Display_Year;
push @date_fmt, '%H:%M:%S' if $Display_Time;
push @date_fmt, '%Z'       if $Display_Time_Zone;

print header(-type => 'text/plain');

print strftime(join(' ', @date_fmt), localtime);
