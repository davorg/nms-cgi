#!/usr/bin/perl -Tw
#
# $Id: search.pl,v 1.29 2002-04-09 20:27:44 nickjc Exp $
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
# search.pl $Revision: 1.29 $
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
