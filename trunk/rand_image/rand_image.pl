#! /usr/bin/perl -wT
#
# $Id: rand_image.pl,v 1.3 2001-11-13 20:35:14 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:54  davorg
# Initial import
#

use strict;
use CGI 'redirect';
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:DEFAULT :flock);

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

BEGIN
{
   my $error_message = sub {
                             my ($message ) = @_;
                             print "Content-Type: text/html\n\n";
                             print "<h1>It's all gone horribly wrong</h1>";
                             print $message if $DEBUGGING;
                            };
  set_message($error_message);
}   

my $pic = $files[rand @files];
print redirect("$basedir$pic");

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
