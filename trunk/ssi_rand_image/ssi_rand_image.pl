#!/usr/bin/perl -Tw
#
# $Id: ssi_rand_image.pl,v 1.8 2002-02-27 09:04:29 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.7  2002/01/27 17:25:48  davorg
# Remove unused $base_dir variable.
#
# Revision 1.6  2001/12/01 19:45:22  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
# Revision 1.5  2001/11/25 11:39:39  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:18:20  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use POSIX qw(strftime);
use CGI qw(header img a);
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
   
my @images = ({ file => 'first_image.gif',
		url => 'http://url_linked/to/first_image',
		alt => 'First WWW Page' },
	      { file => 'second_image.jpg',
		url => 'http://url_linked/to/second_image',
		alt => 'Second WWW Page' },
	      { file => 'third_image.gif',
		url => 'http://url_linked/to/third_image',
		alt => 'Third WWW Page' });

my $uselog = 1;
my $logfile = '/path/to/log/file';

my $date_fmt = '%c';
my $date = strftime $date_fmt, localtime;

my $link_image = 1;
my $align = 'left';
my $border = 2;

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

my $img = $images[rand(@images)];

# Print Out Header With Random Filename and Base Directory

print header;
$done_headers++;

my $output = img({-src => $img->{file},
		  -alt => $img->{alt},
		  -border => $border,
		  -align => $align});

if ($link_image && $img->{url}) {
  $output = a({-href => $img->{url}},
	      $output);
}

print $output;

# If You want a log, we add to it here.
if ($uselog) {
  sysopen(LOG, $logfile, O_APPEND|O_CREAT|O_RDWR)
    or die "Can't open log file: $!\n";
  flock LOG, LOCK_EX
    or die "Can't lock log file: $!\n";

  print LOG "$img->{file} - $date - $ENV{REMOTE_HOST}\n";
  close(LOG);
}
