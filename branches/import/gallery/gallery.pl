#!/usr/bin/perl -wT

# $Id: gallery.pl,v 1.1.1.1 2002-01-22 20:37:41 gellyfish Exp $

# $Log: not supported by cvs2svn $

# Originally :
# Revision 1.1  2000/02/05 17:29:04  gellyfish

use strict;

use CGI qw(:standard);
use vars qw($DEBUGGING);

# Configuration items

BEGIN
{
   $DEBUGGING =1;
}

my $image_dir = '/u/www/virtual/www8-069/graphics/y2k';
my $image_url = 'http://www.gellyfish.com/graphics/y2k';

my @image_extns = qw(.jpg .gif);

my $index_file = 'gallery.dat';
my $css_file   = 'gallery.css';


# End of Configuration

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

my $style;

if ( -f "$image_dir/$css_file" )
{
  $style = { -src  => "$image_url/$css_file",
             -type => 'text/css' };
}
else
{
  $style = default_style();
}

my $ext_re  = join '|', map {quotemeta} @image_extns;

my $me = url;

my %descrips;

if ( -f "$image_dir/$index_file")
{
  open(INDEX,"$image_dir/$index_file") || die "Can't open $index_file - $!\n";

  while(<INDEX>)
  {
    chomp;
    my ($file,$desc) = split /%/;

    $descrips{$file} = $desc if defined $desc;
  }
  close INDEX;
}

opendir(DIR,$image_dir) || die "Can't open $image_dir - $!\n";

my @files = grep /($ext_re)$/, readdir(DIR);

closedir DIR;

my $image = param('image');

$image = 0 if (not defined($image) or ($image < 0 or $image > $#files));

print header, 
      start_html( -style => $style ),
      p({-class => 'image'},img({-src => "$image_url/$files[$image]",
           -align => 'center'}));

print h2($descrips{$files[$image]}) if exists $descrips{$files[$image]};
       
print qq{<table summary="" width="100%">\n<tr width="100%">\n};

print qq{<td width="50%">\n};

if ( $image > 0)
{
   my $prev = $image - 1;
   print qq%<a href="$me?image=$prev"><p class="backfor">Previous</p></a>\n%;
}
else
{
   print "<br />\n";
}

print "</td>\n";
print qq{<td width="50%">\n};
if ( $image < $#files)
{
   my $next = $image + 1;
   print qq%<a href="$me?image=$next"><p class="backfor">Next</p></a>\n%;
}
else
{
   print "<br />\n";
}

print "</td>\n</tr>\n</table>\n";
print end_html; 

sub default_style
{
  return <<EOSTYLE;
BODY {
       background: white;
       font-family: helvetica,arial,sans-serif;
     }
H2   {
       text-align: center;
     }
IMG  {
       text-align: center;
     }
P.image
     {
       text-align: center;
     }
P.backfor {
            font-family: helvetica,arial,sans-serif;
            text-align : center;
            font-size: 14px;
           }
EOSTYLE
}