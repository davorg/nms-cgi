#!/usr/bin/perl -w
#
# $Id: search.pl,v 1.4 2001-11-13 20:35:14 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.3  2001/11/13 09:17:59  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
#

use strict;
use CGI qw(header param);
use CGI::Carp qw(fatalsToBrowser set_message);

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
   

my $basedir = '/home/dave';
my $baseurl = 'http://worldwidemart.com/scripts/';
my @files = ('*.txt','*.html','*.dat', 'src');
my $title = "Matt's Script Archive";
my $title_url = 'http://worldwidemart.com/scripts/';
my $search_url = 'http://worldwidemart.com/scripts/demos/search/search.html';

# end config


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

# Parse Form Search Information

my %FORM = parse_form();

# Get Files To Search Through
my @search_files = get_files(@files);

# Search the files
my %files = search($FORM{terms}, $FORM{boolean}, $FORM{case}, @search_files);

# Print Results of Search
return_html($FORM{terms}, %files);


sub parse_form {
  my %FORM;

  $FORM{$_} = param($_) foreach param;

  return %FORM;
}


sub get_files {
  my @files = @_;

  chdir($basedir) or die "Can't chdir to $basedir: $!\n";

  my @found;

  foreach (@files) {
    $_ .= '/*' if -d "./$_" && !/\*/;
  }

  push @found, grep {-f $_ } glob($_) foreach @files;

  return @found;
}

sub search {
  my ($terms, $bool, $case, @files) = @_;

  my @terms = split(/\s+/, $terms);

  my %files;

  foreach (@files) {

    open(FILE, $_) or die "Can't open $_: $!\n";
    my $string = do { local $/; <FILE> };
    close(FILE);

    if ($bool eq 'AND') {
      foreach my $term (@terms) {
	if ($case eq 'Insensitive') {
	  if ($string =~ /$term/i) {
	    $files{include}{$_}++;
	  } else {
	    $files{include}{$_} = 0;
	    last;
	  }
	} elsif ($case eq 'Sensitive') {
	  if ($string =~ /$term/) {
	    $files{include}{$_} = 1;
	  } else {
	    $files{include}{$_} = 0;
	    last;
	  }
	}
	last unless $files{include}{$_};
      }
    } elsif ($bool eq 'OR') {
      foreach my $term (@terms) {
	if ($case eq 'Insensitive') {
	  if ($string =~ /$term/i) {
	    $files{include}{$_}++;
	  }
	} elsif ($case eq 'Sensitive') {
	  if ($string =~ /$term/) {
	    $files{include}{$_}++;
	    last;
	  }
	}
      }
    }
    if ($string =~ /<title>(.*)<\/title>/i) {
      $files{title}{$_} = $1;
    } else {
      $files{title}{$_} = $_;
    }
  }

  return %files;
}

sub return_html {
  my ($terms, %files) = @_;

  print header;
  print <<END_HTML;
<html>
  <head>
    <title>Results of Search</title>
  </head>
  <body>
    <h1 align="center">Results of Search in $title</h1>
    <p>Below are the results of your Search in no particular order:</p>
    <hr size=7 width=75%>
    <ul>
END_HTML

  foreach (keys %{$files{include}}) {
    if ($files{include}{$_}) {
      print qq(<li><a href="$baseurl$_">$files{title}{$_}</a>\n);
      }
   }

  print <<END_HTML;
    </ul>
    <hr size=7 width=75%>
   <p>Search Information:</p>
   <ul>
     <li><b>Terms:</b> $terms</li>
     <li><b>Boolean Used:</b> $FORM{boolean}</li>
     <li><b>Case:</b> $FORM{case}</li>
   </ul>
   <hr size=7 width=75%>
   <ul>
     <li><a href="$search_url">Back to Search Page</a></li>
     <li><a href="$title_url">$title</a>
   </ul>
   <hr size=7 width=75%>
   <p>Search Script written by Matt Wright and ca1n be found at 
   <a href="http://www.worldwidemart.com/scripts/">Matt\'s Script Archive</a>
 </body>
</html>
END_HTML
}
