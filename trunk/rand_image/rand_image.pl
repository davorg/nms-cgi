#! /usr/bin/perl -wT
#
# $Id: rand_image.pl,v 1.1.1.1 2001-11-11 16:48:54 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/09/18 19:26:47  dave
# Added CVS keywords.
#
#

use strict;
use CGI 'redirect';
use Fcntl qw(:DEFAULT :flock);

# Configuration
my $basedir = 'http://your.host.com/images/';

my @files = qw(first_image.gif
	       test.gif
	       random.gif
	       neat.jpg);

my $uselog = 1; # 1 = YES; 0 = NO
my $logfile = '/path/to/piclog';

# End configuration

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
