#!/usr/bin/perl -Tw
#
# $Id: ssi_rand_image.pl,v 1.2 2001-11-11 17:55:27 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use POSIX 'strftime';
use CGI qw(header img a);
use Fcntl qw(:DEFAULT :flock);

# Configuration

my $basedir = 'http://your.host.xxx/path/to/images/';

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

my $img = $images[rand(@images)];

# Print Out Header With Random Filename and Base Directory
print header;

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
