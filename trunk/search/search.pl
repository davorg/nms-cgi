#!/usr/bin/perl -Tw
#
# $Id: search.pl,v 1.26 2002-03-04 21:45:11 gellyfish Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.25  2002/03/04 10:27:39  gellyfish
# * Added $no_prune to cause the search to recurse all sub-directories.
# * Removed some old debugging code.
#
# Revision 1.24  2002/03/04 09:09:39  gellyfish
# * No point in lying about the encoding of our output
# * Made the use of the directory parameter safer in search.pl
# * Added example of use of directory parameter to search.pl
#
# Revision 1.23  2002/03/03 21:52:45  gellyfish
# * Folded in the intent of the patches from  Gianluca Sforna
#
# Revision 1.22  2002/02/27 09:04:29  gellyfish
# * Added question about simple search and PDF to FAQ
# * Suppressed output of headers in fatalsToBrowser if $done_headers
# * Suppressed output of '<link rel...' if not $style
# * DOCTYPE in fatalsToBrowser
# * moved redirects until after possible cause of failure
# * some small XHTML fixes
#
# Revision 1.21  2002/02/13 15:09:20  jfryan
# Expanded detaint_dirname to include a colon so that win32 paths would 
# pass taint checking
#
# Revision 1.20  2002/02/05 04:24:38  jfryan
# Added $hit_threshhold config var and also moved output functions to end
#
# Revision 1.19  2002/02/05 03:48:05  jfryan
# Accidentally left $emulate_matts_code off by default :(
#
# Revision 1.18  2002/02/05 03:42:39  jfryan
# Added sorted results guarded by a $emulate_matts_code
#
# Revision 1.17  2002/02/03 22:06:29  dragonoe
# Added header to script after log. Also cleaned up the pre-header (use &
# stuff) information so it looks less confusing for newbies and aligned
# config values.
#
# Revision 1.16  2002/02/02 13:57:54  nickjc
# match the empty string as a valid directory name
#
# Revision 1.15  2002/02/01 22:50:28  nickjc
# * Took out some remains of the old tainted chdir botch
#
# Revision 1.14  2002/01/27 12:40:41  gellyfish
# Fixed typo
#
# Revision 1.13  2002/01/16 09:34:26  gellyfish
# Put back the missing log messages
#
# Revision 1.12  2002/01/16 09:26:40  gellyfish
# Put the mysteriously dissapeared Log keyword
#
# Revision 1.11  2002/01/16 09:25:30  gellyfish
# Refixed the File::Find tainting issue
#
# Revision 1.10  2002/01/11 22:37:22  nickjc
# * nasty fix for File::Find/chdir/taint issue
# * misc minor tweaks
# * filename matching as documented in the README
# * eliminate some warnings
#
# Revision 1.9  2001/12/02 10:20:28  gellyfish
# Merged in changes from Joseph Ryan to use File::Find
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
use subs 'File::Find::chdir';# see note above the File::Find::chdir subroutine
use vars qw($DEBUGGING $done_headers);
use File::Find;
$ENV{PATH} = '/bin:/usr/bin';# sanitize the environment
delete @ENV{qw(ENV BASH_ENV IFS)};# ditto

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 4096;


# PROGRAM INFORMATION
# -------------------
# search.pl v1.17
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For a list of changes see CHANGELOG
#
# For help on configuration or installation see README
#
# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#
BEGIN { $DEBUGGING      = 1; }
my $basedir             = '/usr/local/apache/htdocs';
my $baseurl             = 'http://localhost/';
my @files               = ('*.html','*/*.html');
my $title               = "NMS Search Program";
my $title_url           = 'http://cgi-nms.sourceforge.net';
my $search_url          = 'http://localhost/search.html';
my @blocked             = ();
my $emulate_matts_code  = 1;
my $style               = '';

# the following config variables only affect the program if
# $emulate_matts_code is switched off $hit_threshhold is what the minimum
# amount of hits per page that are required for the match to be outputted

my $hit_threshhold      = 1;
my @subdirs             = ('','/manual','/vmanual');
my $no_prune            = 1;

#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)


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

my $style_element = $style ?
                    qq%<link rel="stylesheet" type="text/css" href="$style" />%
                  : '';

# Parse Form Search Information
my $case   = param("case") ? param("case") : "Insensitive";
my $bool   = param("boolean") ? param("boolean") : "OR";
my $terms  = param("terms") ? param("terms") : "";

my $directory = param('directory') || 0;
my $seldir = $directory && $directory < @subdirs ? 
                                            $subdirs[$directory] : "";

# Print page headers

start_of_html($title, $style);

my (@term_list,@paths,@hits,@titles);
my ($wclist, $dirlist, $termlist);

my $startdir;

if ($terms)
{
    @term_list = split(/\s+/, $terms);
    ($wclist, $dirlist) = build_list(@files);
    my @temp_list = @term_list;

    $termlist = join '|', map { "\Q$_\E" } @temp_list;
    $termlist = "(?:$termlist)";

    if ( $emulate_matts_code ) 
    {
      $startdir = $basedir;
    }
    else
    {
       $startdir = "$basedir$seldir";
    }

    find ( \&do_search, $startdir);
    if (!$emulate_matts_code)
    {
        my @base = sort {$hits[$b] <=> $hits[$a]} (0 .. $#hits);
        @titles  = @titles[@base];
        @paths   = @paths[@base];

        for my $i (0 .. $#hits)
        {
           print_result($baseurl, $paths[$i], $titles[$i]) 
                 if ($hits[$i] >= $hit_threshhold);
        }
    }
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
            $File::Find::prune = 1 unless (!$emulate_matts_code and $no_prune);
        }
        return;
    }
    if (!$emulate_matts_code and $no_prune )
    {
       return unless $basename =~ /$wclist/io;
    }
    else
    {
      return unless ("$dirname$basename" =~ m/$wclist/io);
    }
    return unless -r _;
    foreach my $blocked (@blocked) {
        if ($emulate_matts_code ) {
           return if $File::Find::dir eq $blocked;
        }
        else {
           return if $File::Find::dir =~ /$blocked/;
        }
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

    if ($string =~ m%<title>(.+?)</title>%is) {
        $page_title = $1;
    }

    if ($emulate_matts_code) {
        print_result($baseurl, "$dirname$basename", $page_title);
    }
    else {
        my @m = split(/$termlist/i, $string);
        my $matches = scalar(@m);
        push (@hits, $matches);
        push (@paths, "$dirname$basename");
        push (@titles, $page_title);
    }
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

# This subroutine overrides the core chdir in order that detainting
# can be done on the directory name before being passed to the real
# one - newer File::Find can overcome this need but it is needed for
# 5.004.04 - 5.005.03

sub File::Find::chdir
{
   return CORE::chdir(main::detaint_dirname($_[0]));
}

sub detaint_dirname
{
    my ($dirname) = @_;

    # Pattern from File/Find.pm in Perl 5.6.1
    $dirname =~ m|^([:\\+@\w./-]*)$| or die "suspect directory name: $dirname";
    return $1;
}


sub start_of_html
{
    my ($title,$style) = @_;
    print header;
    $done_headers++;
    print <<END_HTML;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Results of Search</title>
    $style_element
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
