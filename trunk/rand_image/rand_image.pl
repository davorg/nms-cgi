#! /usr/bin/perl -wT
#
# $Id: rand_image.pl,v 1.9 2002-07-23 20:44:50 nickjc Exp $
#

use strict;
use CGI qw(redirect header);
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
   
# If this is set to 1 then the program will issue a redirect to the image
# and $baseurl must be the beginning of the URI where the images reside.
# This might not work on all browsers.
# If it is set to 0 then the program will send the image to the browser
# directly (which is more costly for the server) in which case $basedir
# must be the full system path to the directory where the image files are.
# It might be necessary to add new extenstion => content type pairs to
# the %content_type below if you are using file extenstions that are not
# among the defaults.
`
my $use_redirect = 0;
my $baseurl = 'http://nms-test.gellyfish.com/images/';
my $basedir = '/var/www/nms-test/images/';

# Your image files here.

my @files = qw(
               foo.jpg
               bah.png
              );

my $uselog = 0; # 1 = YES; 0 = NO
my $logfile = '/path/to/piclog';

# End configuration

# Might need to add to content types mapping extensions 

my %content_types = (
                       jpg => 'image/jpeg',
                       gif => 'image/gif',
                       png => 'image/png'
                    );

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

if ( $use_redirect )
{
   if ( $baseurl !~ m%/$% )
   {
      $baseurl .= '/';
   }
    print redirect("$baseurl$pic");
    $done_headers++;
}
else
{
   if ( $basedir !~ m%/$% )
   {
      $basedir .= '/';
   }

   my ( $extension ) = $pic =~ /\.(\S+)$/;

   my $ctype = $content_types{$extension} || 'image/png';

   open INFILE, "<$basedir$pic" or die "Can't open $basedir$pic - $!";
   binmode INFILE;
   local $/;
   
   my $image = <INFILE>;
   close INFILE;
 
    print header(-type => $ctype),
          $image;
}
