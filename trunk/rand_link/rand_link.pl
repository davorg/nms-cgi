#! /usr/bin/perl -Tw
#
# $Id: rand_link.pl,v 1.1.1.1 2001-11-11 16:48:57 davorg Exp $
#
# $Log#
#

use strict;
use POSIX 'strftime';
use CGI 'redirect';
use Fcntl qw(:DEFAULT :flock);

# Configuration

my $linkfile = '/path/to/links/database';

my $uselog = 1;
my $logfile = '/path/to/rand_log';

my $date_format = '%Y-%m-%d %H:%M:%S';

# End configuration

open (LINKS, $linkfile)
  or die "Can't open link file: $!\n";

my @links = <LINKS>;
chomp @links;
my $link = $links[rand @links];
close LINKS;

print redirect($link);

if ($uselog) {
  my $date = strftime($date_format, localtime);

  sysopen (LOG, $logfile, O_RDWR|O_APPEND|O_CREAT)
    or die "Can't open logfile: $!\n";
  flock(LOG, LOCK_EX)
    or die "Can't lock logfile: $!\n";
   print LOG "$ENV{REMOTE_HOST} - [$date]\n";
  close (LOG)
    or die "Can't close logfile: $!\n";
  open (LOG, ">>$logfile");
  close (LOG);
}

exit;
