#!/usr/bin/perl -Tw
#
# $Id: icounter.pl,v 1.5 2001-11-25 11:39:38 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
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
use CGI::Carp qw(fatalsToBrowser set_message);
use Fcntl qw(:DEFAULT :flock);
use POSIX 'strftime';
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
   
my $data_dir    = './data/';
my @valid_uri   = ('/');
my @invalid_uri = ();
my $auto_create = 1;

# End configuration


BEGIN
{
   my $error_message = sub {
                             my ($message ) = @_;
                             print "<h1>It's all gone horribly wrong</h1>";
                             print $message if $DEBUGGING;
                            };
  set_message($error_message);
}   

print header;
my $count_page = $ENV{DOCUMENT_URI};
check_uri();

$count_page =~ s|/$||;
$count_page =~ s/[^\w]/_/g;


my $count;
if (-e "$data_dir$count_page") {
   sysopen(COUNT, "$data_dir$count_page", O_RDWR)
     or die "Can't open count file: $!\n";
   flock(COUNT, LOCK_SH)
     or die "Can't lock count file: $!\n";
   my $line;
   chomp($line = <COUNT>);
   close(COUNT);
   $count = $line;
} elsif ($auto_create) {
   create();
} else {
   die "Count file not found\n";
}

$count++;

#my $print_count = sprintf("%0${pad_size}d", $count);

sysopen(COUNT, "$data_dir$count_page", O_RDWR)
  or die "Could_not_open count file: $!";
flock(COUNT, LOCK_EX)
  or die "Could not lock count file: $!\n";
truncate COUNT, 0;
print COUNT "$count";
close(COUNT);

sub check_uri {
  my $uri_check_flag = 0; # Guilty until proven innocent
  foreach (@valid_uri) {
    if ($ENV{DOCUMENT_URI} =~ /$_/) {
      $uri_check_flag = 1;
      last;
    }
  }
  foreach (@invalid_uri) {
    if ($ENV{DOCUMENT_URI} =~ /$_/) {
      $uri_check_flag = 0;
      last;
    }
  }
  die "Bad URI: $ENV{DOCUMENT_URI}" unless $uri_check_flag;
}

sub create {
  sysopen(COUNT, "$data_dir$count_page", O_CREAT|O_RDWR) 
    or die "Can't create count file: $!\n";
  flock(COUNT, LOCK_SH)
    or die "Can't lock count file: $!\n";
  print COUNT "0";
  close(COUNT);
}
