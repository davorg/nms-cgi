#!/usr/bin/perl -wT
#
# $Id: rand_text.pl,v 1.1.1.1 2001-11-11 16:48:57 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.3  2001/09/18 19:26:48  dave
# Added CVS keywords.
#
#

use strict;
use CGI qw(header);

# Configuration

#my $random_file = '/path/to/random.txt';
my $random_file = 'random.txt';

my $delimiter = "%%\n";

# End configuration

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
