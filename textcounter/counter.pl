#!/usr/bin/perl -Tw
#
# $Id: counter.pl,v 1.19 2004-10-19 08:49:13 gellyfish Exp $
#

use strict;
use CGI qw(header virtual_host);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(locale_h strftime);
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

my $allow_virtual_hosts = 1;

my $use_single_file     = 0;

my $single_data_file    = 'counter.txt';

my $locale              = '';

my $canonicalize        = 1;

my @allow_hosts         = qw();

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

      if ( $DEBUGGING )
      {
         $message =~ s/</&lt;/g;
         $message =~ s/>/&gt;/g;
      }
      else
      {
         $message = '';
      }
      
      my ( $pack, $file, $line, $sub ) = caller(0);
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

my $vh = virtual_host();
check_host($vh) || die "bad host : '$vh'\n";

check_uri($count_page) || die "bad URI : '$count_page'\n";

my $can = $canonicalize ? '+' : '';

$count_page =~ s|/$||;
$count_page =~ s/[^\w]$can/_/g;
$count_page =~ /^(\w+)$/ or die 'failed to wordify count_page';
$count_page = $1;

my ($date, $count);


if ( $data_dir !~ m%/$% ) {
  $data_dir .= '/';
}

my $counter_file = $data_dir;

if ( $allow_virtual_hosts )
{
    my $vh = virtual_host();
    $vh =~ /^([\w\-\.]+)$/ and $counter_file .= $1;
    $counter_file .= '_';
}

if ( $use_single_file )
{
   $counter_file .= $single_data_file;
}
else
{
   $counter_file .= $count_page;
}

if (-e $counter_file) {
   sysopen(COUNT, $counter_file, O_RDWR)
     or die "Can't open count file: $!\n";
   flock(COUNT, LOCK_EX)
     or die "Can't lock count file: $!\n";
   my $line;
   chomp($line = <COUNT>);

   ($date, $count) = split(/\|\|/,$line);
} elsif ($auto_create) {
   $date = create($counter_file);
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
  return $uri_check;
}

sub create {

  my ( $counter_file ) = @_;

  eval
  {
     setlocale(LC_TIME, $locale) if $locale;
  };

  my $date = strftime('%B %d %Y', localtime);

  sysopen(COUNT, $counter_file, O_CREAT|O_RDWR) 
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

sub check_host
{
   my ( $host ) = @_;

   my $rc = 0;
   if ( @allow_hosts )
   {
      foreach my $check_host (@allow_hosts)
      {
         if ( $host eq $check_host )
         {
            $rc = 1;
            last;
         }
      }
   }
   else
   {
      $rc = 1;
   }

   return $rc;
}
