#!/usr/bin/perl -wT
#
# $Id: search.pl,v 1.11 2002-01-16 09:25:30 gellyfish Exp $
#
# Revision 1.8  2001/12/01 19:45:22  gellyfish
# * Tested everything with 5.004.04
# * Replaced the CGI::Carp with local variant
#
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

# the "use subs 'File::Find::chdir'" is necessary here so that the
# over-riding of the core chdir() works - see the note above the
# File::Find::chdir subroutine

use subs 'File::Find::chdir';
use vars qw($DEBUGGING);
use File::Find;

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


my $basedir = '/indigo/html';
my $baseurl = '/indigo/html';
my @files = ('*.txt','*.html','*.dat', 'src');
my $title = "NMS Search Program";
my $title_url = 'http://cgi-nms.sourceforge.net';
my $search_url = 'http://localhost/search.html';
my @blocked = ();

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
# URI fragment.  Set to '' if there will be no style sheet used.

my $style = '';

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
my $case  = param("case") ? param("case") : "Insensitive";
my $bool  = param("boolean") ? param("boolean") : "OR";
my $terms = param("terms") ? param("terms") : "";

# Print page headers

start_of_html($title, $style);

my @term_list = ();
my ($wclist, $dirlist) = ('', '');

my %extra_basedirs = ();
my $old_file_find = ( $] < 5.006 ? 1 : 0 );
my $startdir;

if ($terms)
{
    @term_list = split(/\s+/, $terms);
    ($wclist, $dirlist) = build_list(@files);

    # I have taken out the reimplementation hack ;-}

    $startdir = $basedir;
    find ( \&do_search, $startdir);
}
else
{
    print "<li>No Terms Specified</li>";
}

end_of_html($search_url, $title_url, $title, $terms, $bool, $case);


sub do_search
{
    return if $File::Find::name eq $startdir;
    $File::Find::name =~ m#^\Q$basedir\E(.*/)([^/]+)$#
         or die "can't parse File::Find::name [$File::Find::name]";
    my ($dirname, $basename) = ($1, $2);
    $dirname =~ s#^/+##;

    return if($basename =~ /^\./);

    my @stats = stat $File::Find::name;
    if (-d _) {
        if ("$dirname$basename" !~ /$dirlist/o) {
            $File::Find::prune = 1;
        } elsif ($old_file_find) {
            $extra_basedirs{detaint_dirname($File::Find::name)} = 1;
            $File::Find::prune = 1;
        }
        return;
    }
    return unless ("$dirname$basename" =~ m/$wclist/i);
    return unless -r _;
    foreach my $blocked (@blocked) {
        return if ($File::Find::dir eq $blocked)
    }

    open(FILE, "<$File::Find::name") or return;
    my $string = do { local $/; <FILE> };
    close(FILE);

    if ($bool eq 'AND') {
        foreach my $term (@term_list) {
           if ($case eq 'Insensitive') {
                return if ($string !~ m/\Q$term\E/i);
           }
           elsif ($case eq 'Sensitive') {
                return if ($string !~ m/\Q$term\E/);
           }
        }
    }
    elsif ($bool eq 'OR') {
       my $find;
       foreach my $term (@term_list) {
          if ($case eq 'Insensitive') {
                $find++ if ($string =~ /\Q$term\E/i);
          }
          elsif ($case eq 'Sensitive') {
                $find++ if ($string =~ /\Q$term\E/)
          }
       }
       return unless $find;
    }

    my $page_title = $basename;

    if ($string =~ /<title>(.+?)<\/title>/is) {
        $page_title = $1;
    }

    print_result($baseurl, "$dirname$basename", $page_title);
}

#
# Returns a list of 2 strings holding regular expressions.  The
# first matches the names of files to be searched.  The second
# matches the names of directories that might have matching
# files in them.
#
# Treats '*' like the shell does, all else is literal.
#
sub build_list
{
    my @files = @_;

    my (@filepat, %dirpat);
    foreach my $file (@files) {
        # The README says 'fun/' means 'fun/*'
        $file =~ s#/$#/*#;

        my $filepat = quotemeta($file);
        $filepat =~ s#\\\*#(?:(?:[^/.][^/]*)?)#g;
        push @filepat, $filepat;

        while ($file =~ s#/[^/]+$##) {
            my $dirpat = quotemeta($file);
            $dirpat =~ s#\\\*#(?:(?:[^/.][^/]*)?)#g;
            $dirpat{$dirpat} = 1;
        }
    }

    return( '^(?:(?:' . join(')|(?:', @filepat)     . '))$',
            '^(?:(?:' . join(')|(?:', keys %dirpat) . '))$'
          );
}

sub start_of_html
{
    my ($title,$style) = @_;
    print header;
    print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Results of Search</title>
END_HTML

print qq(    <link rel="stylesheet" type="text/css" href="$style" />) if $style;

print <<END_HTML;
  </head>
  <body>
    <h1 align="center">Results of Search in $title</h1>
    <p>Below are the results of your Search in no particular order:</p>
    <hr size="7" width="75%" />
    <ul>
END_HTML
}


sub print_result
{
    my ($baseurl, $file, $title) = @_;
    print qq(<li><a href="$baseurl/$file">$title</a></li>\n);
}


sub end_of_html
{
  my ($search_url, $title_url, $title, $terms, $boolean, $case) = @_;
  print <<END_HTML;
    </ul>
    <hr size="7" width="75%" />
   <p>Search Information:</p>
   <ul>
     <li><b>Terms:</b> $terms</li>
     <li><b>Boolean Used:</b> $boolean</li>
     <li><b>Case:</b> $case</li>
   </ul>
   <hr size="7" width="75%" />
   <ul>
     <li><a href="$search_url">Back to Search Page</a></li>
     <li><a href="$title_url">$title</a>
   </ul>
   <hr size="7" width="75%" />
   <p>Search Script (c) London Perl Mongers 2001 part of
   <a href="http://nms-cgi.sourceforge.net/">NMS Project</a></p>
 </body>
</html>
END_HTML
}

# This subroutine overrides the core chdir in order that detainting
# can be done on the directory name before being passed to the real
# one - newer File::Find can overcome this need but it is needed for
# 5.004.04 - 5.005.03

sub File::Find::chdir
{
   return CORE::chdir(main::detaint_dirname($_[0]);
}

sub detaint_dirname
{
    my ($dirname) = @_;

    # Pattern from File/Find.pm in Perl 5.6.1
    $dirname =~ m|^([-+@\w./]+)$| or die "suspect directory name: $dirname";
    return $1;
}

