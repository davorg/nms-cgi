#!/usr/bin/perl -wT
#
# $Id: rand_text.pl,v 1.3 2001-11-13 09:17:37 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
# Revision 1.1.1.1  2001/11/11 16:48:57  davorg
# Initial import
#

use strict;
use CGI qw(header);
use CGI qw(fatalsToBrowser);

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
