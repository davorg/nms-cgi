#!/usr/bin/perl -wT
#
# $Id: search.pl,v 1.8 2001-12-01 19:45:22 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.7  2001/11/26 13:40:05  nickjc
# Added \Q \E around variables in regexps where metacharacters in the
# variables shouldn't be interpreted by the regex engine.
#
# Revision 1.6  2001/11/25 11:39:38  gellyfish
# * add missing use vars qw($DEBUGGING) from most of the files
# * sundry other compilation failures
#
# Revision 1.5  2001/11/20 08:43:56  nickjc
# security fix on file open
#
# Revision 1.4  2001/11/13 20:35:14  gellyfish
# Added the CGI::Carp workaround
#
# Revision 1.3  2001/11/13 09:17:59  gellyfish
# Added CGI::Carp
#
# Revision 1.2  2001/11/11 17:55:27  davorg
# Small amount of post-import tidying :)
#
#

use strict;
use CGI qw(header param);
use vars qw($DEBUGGING);

# sanitize the environment

$ENV{PATH} = '/bin:/usr/bin';

delete @ENV{qw(ENV BASH_ENV IFS)};


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
my $title = "NMS Search Program";
my $title_url = 'http://worldwidemart.com/scripts/';
my $search_url = 'http://worldwidemart.com/scripts/demos/search/search.html';

# $emulate_matts_code determines whether the program should behave exactly
# like the original guestbook program.  It should be set to 1 if you
# want to emulate the original program - this is recommended if you are
# replacing an existing installation with this program.  If it is set to 0
# then potentially it will not work with files produced by the original
# version - this is recommended for people installing this for the first time.

my $emulate_matts_code = 1;

# $style is the URL of a CSS stylesheet which will be used for script
# generated messages.  This probably want's to be the same as the one
# that you use for all the other pages.  This should be a local absolute
# URI fragment.

my $style = '/css/nms.css';

# end config

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

  foreach my $param ( param() )
  {
    $FORM{$param} = param($param);
  }
  return %FORM;
}


sub get_files {
  my @files = @_;

  chdir($basedir) or die "Can't chdir to $basedir: $!\n";

  my @found;

  foreach (@files) {
    $_ .= '/*' if -d "./$_" && !/\*/;
  }

  foreach my $file ( grep {-f $_ } map { glob($_) } @files )
  {
    push @found, $file;
  }

  return @found;
}

sub search {
  my ($terms, $bool, $case, @files) = @_;

  my @terms = split(/\s+/, $terms);

  my %files;

  foreach (@files) {

    open(FILE, "<$_") or die "Can't open $_: $!\n";
    my $string = do { local $/; <FILE> };
    close(FILE);

    if ($bool eq 'AND') {
      foreach my $term (@terms) {
	if ($case eq 'Insensitive') {
	  if ($string =~ /\Q$term\E/i) {
	    $files{include}{$_}++;
	  } else {
	    $files{include}{$_} = 0;
	    last;
	  }
	} elsif ($case eq 'Sensitive') {
	  if ($string =~ /\Q$term\E/) {
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
	  if ($string =~ /\Q$term\E/i) {
	    $files{include}{$_}++;
	  }
	} elsif ($case eq 'Sensitive') {
	  if ($string =~ /\Q$term\E/) {
	    $files{include}{$_}++;
	    last;
	  }
	}
      }
    }
    if ($string =~ /<title>(.*)<\/title>/is) {
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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Results of Search</title>
    <link rel="stylesheet" type="text/css" href="$style" />
  </head>
  <body>
    <h1 align="center">Results of Search in $title</h1>
    <p>Below are the results of your Search in no particular order:</p>
    <hr size="7" width="75%" />
    <ul>
END_HTML

  foreach (keys %{$files{include}}) {
    if ($files{include}{$_}) {
      print qq(<li><a href="$baseurl$_">$files{title}{$_}</a></li>\n);
      }
   }

  print <<END_HTML;
    </ul>
    <hr size="7" width="75%" />
   <p>Search Information:</p>
   <ul>
     <li><b>Terms:</b> $terms</li>
     <li><b>Boolean Used:</b> $FORM{boolean}</li>
     <li><b>Case:</b> $FORM{case}</li>
   </ul>
   <hr size="7" width="75%" />
   <ul>
     <li><a href="$search_url">Back to Search Page</a></li>
     <li><a href="$title_url">$title</a>
   </ul>
   <hr size="7" width="75%" />
   <p>Search Script (c) London Perl Mongers 2001 part of
   <a href="http://nms-cgi.sourceforge.net/">NMS Project</a>
 </body>
</html>
END_HTML
}
