#! /usr/bin/perl -wT
#
# $Id: rand_image.pl,v 1.7 2002-03-27 20:36:37 davorg Exp $
#

use strict;
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
   
my $basedir = 'http://your.host.com/images/';

my @files = qw(first_image.gif
	       test.gif
	       random.gif
	       neat.jpg);

my $uselog = 1; # 1 = YES; 0 = NO
my $logfile = '/path/to/piclog';

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

if ( $basedir !~ m%/$% )
{
   $basedir .= '/';
}

my $pic = $files[rand @files];

# Log Image
if ($uselog) {
  sysopen (LOG, $logfile, O_RDWR|O_APPEND|O_CREAT)
    or die "Can't open logfile: $!\n";
  flock(LOG, LOCK_EX)
    or die "Can't lock logfile: $!\n";
  print LOG "$pic\n";
  close (LOG)
    or die "Can't close logfile: $!\n";
}

print redirect("$basedir$pic");
$done_headers++;
