#!/usr/bin/perl -Tw
#
# $Id: counter.pl,v 1.1.1.1 2001-11-13 16:36:30 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.3  2001/11/13 09:19:24  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:59  davorg
# Initial import
#

use strict;
use CGI 'header';
use CGI qw(fatalsToBrowser);
use Fcntl qw(:DEFAULT :flock);
use POSIX 'strftime';

# Configuration

my $data_dir = './data/';

my @valid_uri = ('/');

my @invalid_uri = ();

my $show_link = 'http://www.dave.org.uk/scripts/nms/';

my $auto_create = 1;

my $show_date = 1;

my $pad_size = 5;

# End configuration

print header;

my $count_page = $ENV{DOCUMENT_URI};

&check_uri;

$count_page =~ s|/$||;
$count_page =~ s/[^\w]/_/g;

my $lock_file = "$count_page.lock";

my ($date, $count);
if (-e "$data_dir$count_page") {
   sysopen(COUNT, "$data_dir$count_page", O_RDWR)
     or die "Can't open count file: $!\n";
   flock(COUNT, LOCK_SH)
     or die "Can't lock count file: $!\n";
   my $line;
   chomp($line = <COUNT>);
   close(COUNT);

   ($date, $count) = split(/\|\|/,$line);
} elsif ($auto_create) {
   $date = &create;
} else {
   die "Count file not found\n";
}

# Increment Count.
$count++;

my $print_count = sprintf("%0${pad_size}d", $count);

# Print the Count, Link and Date depending on what user has specified 
# they wish to print.

if ($show_date) {
  if ($show_link) {
    print qq(<a href="$show_link">$print_count</a> hits since $date);
  } else {
    print "$print_count hits since $date";
  }
} else {
  if ($show_link) {
    print "<a href=\"$show_link\">$print_count</a>";
  } else {
    print "$print_count";
  }
}

sysopen(COUNT, "$data_dir$count_page", O_RDWR)
  or die "Could_not_open count file: $!";
flock(COUNT, LOCK_EX)
  or die "Could not lock count file: $!\n";
truncate COUNT, 0;
print COUNT "$date\|\|$count";
close(COUNT);

sub check_uri {
  my $uri_check;

  foreach (@valid_uri) {
    if ($ENV{DOCUMENT_URI} =~ /$_/) {
      $uri_check = 1;
      last;
    }
  }

  foreach (@invalid_uri) {
    if ($ENV{DOCUMENT_URI} =~ /$_/) {
      $uri_check = 0;
      last;
    }
  }

  die "Bad URI: $ENV{DOCUMENT_URI}" unless $uri_check;
}

sub create {
  my $date = strftime('%B %d %Y', localtime);

  sysopen(COUNT, "$data_dir$count_page", O_CREAT|O_RDWR) 
    or die "Can't create count file: $!\n";
  flock(COUNT, LOCK_SH)
    or die "Can't lock count file: $!\n";

  print COUNT "$date||0";
  close(COUNT);

  return $date;
}
