#!/usr/bin/perl -wT
#
# $Id: rand_text.pl,v 1.4 2001-11-13 20:35:14 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.3  2001/11/13 09:17:37  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use CGI qw(header);
use CGI qw(fatalsToBrowser set_message);

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
   
#my $random_file = '/path/to/random.txt';
my $random_file = 'random.txt';

my $delimiter = "%%\n";

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

open(FILE, $random_file) 
  or die "Can't open $random_file: $!\n";

my @phrases;
{
  local $/ = $delimiter;
  chomp (@phrases = <FILE>);
}

my $phrase = $phrases[rand(@phrases)];

print header(-type => 'text/plain');

print $phrase;

close(FILE);
