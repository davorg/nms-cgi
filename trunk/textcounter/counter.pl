#!/usr/bin/perl -Tw
#
# $Id: counter.pl,v 1.10 2002-02-26 08:59:28 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.9  2002/02/11 09:16:35  gellyfish
# * provided method to turn off emission of headers
# * Fixed the locking race
# * Turned off uploads and POST
#
# Revision 1.8  2002/01/27 14:13:33  davorg
# Removed Matt's docs.
# Removed unnecessary reference to lock file.
#
# Revision 1.7  2001/12/01 19:45:22  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
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
use vars qw($DEBUGGING $done_header);

# Older Fcntl don't have the SEEK_* constants :(

sub SEEK_SET() { 0; }

# This program does not require uploads or POSTed form data
# The strange locution is to prevent a 'used once' warning

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 0;

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

my $show_link = 'http://nms-cgi.sourceforge.net/';

my $auto_create = 1;

my $show_date = 1;

my $pad_size = 5;

my $ssi_emit_cgi_headers = 1;

my @no_header_servers = qw(Xitami);

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

      print "Content-Type: text/html\n\n" unless $done_header;

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

# Some servers (notably Xitami) do not give $ENV{DOCUMENT_URI}

my $count_page = $ENV{DOCUMENT_URI} || $ENV{SCRIPT_NAME};

check_server_software();

print header if $ssi_emit_cgi_headers;

check_uri($count_page);


$count_page =~ s|/$||;
$count_page =~ s/[^\w]/_/g;

my ($date, $count);
if (-e "$data_dir$count_page") {
   sysopen(COUNT, "$data_dir$count_page", O_RDWR)
     or die "Can't open count file: $!\n";
   flock(COUNT, LOCK_EX)
     or die "Can't lock count file: $!\n";
   my $line;
   chomp($line = <COUNT>);

   ($date, $count) = split(/\|\|/,$line);
} elsif ($auto_create) {
   $date = create();
} else {
   die "Count file not found\n";
}

# Increment Count.
$count++;

truncate COUNT, 0;
seek COUNT,SEEK_SET,0;
print COUNT "$date\|\|$count";
close(COUNT);

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
    print qq(<a href="$show_link">$print_count</a>);
  } else {
    print "$print_count";
  }
}


sub check_uri {

  my ( $count_page ) = @_;

  my $uri_check;

  foreach (@valid_uri) {
    if ($count_page =~ /\Q$_\E/) {
      $uri_check = 1;
      last;
    }
  }

  foreach (@invalid_uri) {
    if ($count_page =~ /\Q$_\E/) {
      $uri_check = 0;
      last;
    }
  }
  die "Bad URI: $count_page" unless $uri_check;
}

sub create {
  my $date = strftime('%B %d %Y', localtime);

  sysopen(COUNT, "$data_dir$count_page", O_CREAT|O_RDWR) 
    or die "Can't create count file: $!\n";
  flock(COUNT, LOCK_EX)
    or die "Can't lock count file: $!\n";

  print COUNT "$date||0";
  return $date;
}

sub check_server_software
{
     my $server_re = join '|', @no_header_servers;

     if ( $ENV{SERVER_SOFTWARE} && $ENV{SERVER_SOFTWARE} =~ /($server_re)/ )
     {
        $ssi_emit_cgi_headers = 0;
     }   
}
