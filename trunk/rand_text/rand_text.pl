#!/usr/bin/perl -wT
#
# $Id: rand_text.pl,v 1.7 2002-01-27 17:35:28 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.6  2001/12/01 19:45:22  gellyfish
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
# Revision 1.3  2001/11/13 09:17:37  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use CGI qw(header);
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
   
my $random_file = '/path/to/random.txt';

my $delimiter = "%%\n";

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

open(FILE, $random_file) 
  or die "Can't open $random_file: $!\n";

my @phrases;
{
  local $/ = $delimiter;
  chomp (@phrases = <FILE>);
}

my $phrase = $phrases[rand(@phrases)];

print header(-type => 'text/plain');

print $phrase;

close(FILE);
