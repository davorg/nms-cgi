#!/usr/bin/perl -Tw
#
# $Id: icounter.pl,v 1.10 2002-02-27 09:04:29 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.9  2002/02/26 08:59:28  gellyfish
# * Fixed imagecounter to something
# * fixed typo in textcounter/README
# * suppressed emission of headers in fatalsToBrowser if already done.
#
# Revision 1.8  2002/02/14 10:46:50  gellyfish
# * Realized that it didn't do anything
#
# Revision 1.7  2001/12/01 19:45:22  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
# Revision 1.6  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
# Revision 1.5  2001/11/25 11:39:38  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:15:22  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:53  davorg
# Initial import
#

use strict;
use CGI 'header';
use Fcntl qw(:DEFAULT :flock);
use POSIX 'strftime';
use vars qw($DEBUGGING $done_headers);

# Older Fcntl module doesn't have the SEEK_* constants

BEGIN 
{
  eval
  {
     sub SEEK_SET() { 0; }
  } unless defined(&SEEK_SET);
}

# The program does not require any upload or posted data
# this is done in a strange way to shut up the warnings.

$CGI::POST_MAX = $CGI::POST_MAX = 0;
$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;

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
   
my $data_dir             = './data/';
my $digit_url            = '/digits';
my $digit_ext            = '.gif';
my @valid_uri            = ('/');
my @invalid_uri          = ();
my $auto_create          = 1;
my $ssi_emit_cgi_headers = 1;
my @no_header_servers    = qw(Xitami);

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

# Some servers (notably Xitami) do not give $ENV{DOCUMENT_URI}

my $count_page = $ENV{DOCUMENT_URI} || $ENV{SCRIPT_NAME};

check_server_software();

print header if $ssi_emit_cgi_headers;
$done_headers++;

check_uri($count_page);

$count_page =~ s|/$||;
$count_page =~ s/[^\w]/_/g;

if ( $data_dir !~ m%/$% ) {
  $data_dir .= '/';
}


my $count = 0;
if (-e "$data_dir$count_page") {
   sysopen(COUNT, "$data_dir$count_page", O_RDWR)
     or die "Can't open count file: $!\n";
   flock(COUNT, LOCK_EX)
     or die "Can't lock count file: $!\n";
   my $line;
   chomp($line = <COUNT>);
   $count = $line;
} elsif ($auto_create) {
   create();
} else {
   die "Count file not found\n";
}

$count++;

truncate COUNT, 0;
seek COUNT,SEEK_SET,0;
print COUNT $count;
close(COUNT);


my @digits = split //, $count;

foreach my $digit (@digits )
{
  
  if ($digit_ext !~ /^\./ )
  {
     $digit .= '.';
  }

  my $digit_src = "$digit_url/$digit$digit_ext";

  print qq%<img src="$digit_src" alt="$digit" />%;
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
  sysopen(COUNT, "$data_dir$count_page", O_CREAT|O_RDWR) 
    or die "Can't create count file: $!\n";
  flock(COUNT, LOCK_SH)
    or die "Can't lock count file: $!\n";
}

sub check_server_software
{
     my $server_re = join '|', @no_header_servers;

     if ( $ENV{SERVER_SOFTWARE} && $ENV{SERVER_SOFTWARE} =~ /($server_re)/ )
     {
        $ssi_emit_cgi_headers = 0;
     }
}

