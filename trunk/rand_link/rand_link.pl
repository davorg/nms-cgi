#! /usr/bin/perl -Tw
#
# $Id: rand_link.pl,v 1.4 2001-11-13 20:35:14 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.3  2001/11/13 09:16:45  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
#

use strict;
use POSIX 'strftime';
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
   
my $linkfile = '/path/to/links/database';

my $uselog = 1;
my $logfile = '/path/to/rand_log';

my $date_format = '%Y-%m-%d %H:%M:%S';

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
