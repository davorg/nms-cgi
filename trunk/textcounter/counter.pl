#!/usr/bin/perl -Tw
#
# $Id: counter.pl,v 1.7 2001-12-01 19:45:22 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.6  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
# Revision 1.5  2001/11/25 11:39:40  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
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
use CGI qw(header);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(strftime);
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
   
my $data_dir = './data/';

my @valid_uri = ('/');

my @invalid_uri = ();

my $show_link = 'http://www.dave.org.uk/scripts/nms/';

my $auto_create = 1;

my $show_date = 1;

my $pad_size = 5;

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
print header;

my $count_page = $ENV{DOCUMENT_URI};

check_uri();

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
   $date = create();
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
    if ($ENV{DOCUMENT_URI} =~ /\Q$_\E/) {
      $uri_check = 1;
      last;
    }
  }

  foreach (@invalid_uri) {
    if ($ENV{DOCUMENT_URI} =~ /\Q$_\E/) {
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
