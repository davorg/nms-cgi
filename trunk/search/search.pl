#!/usr/bin/perl -Tw
#
# $Id: search.pl,v 1.38 2002-09-15 12:19:23 nickjc Exp $
#

use strict;
use CGI qw(param);
use subs 'File::Find::chdir';# see note above the File::Find::chdir subroutine
use vars qw($DEBUGGING $done_headers);
use File::Find;
$ENV{PATH} = '/bin:/usr/bin';# sanitize the environment
delete @ENV{qw(ENV BASH_ENV IFS)};# ditto

$CGI::DISABLE_UPLOADS = $CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX = $CGI::POST_MAX = 4096;


# PROGRAM INFORMATION
# -------------------
# search.pl $Revision: 1.38 $
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
my $charset             = 'iso-8859-1';

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

# a common error is to put a trailing / on $basedir.
$basedir =~ s#/$##;

# We need finer control over what gets to the browser and the CGI::Carp
# set_message() is not available everywhere :(
# This is basically the same as what CGI::Carp does inside but simplified
# for our purposes here.

BEGIN
{
   sub fatalsToBrowser
   {
      my ( $message ) = @_;

      if ( $DEBUGGING )
      {
         $message =~ s/</&lt;/g;
         $message =~ s/>/&gt;/g;
      }
      else
      {
         $message = '';
      }

      my ( $pack, $file, $line, $sub ) = caller(0);
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

use vars qw($cs);
$cs = CGI::NMS::Charset->new($charset);

# %E is a fake hash for escaping HTML metachars as things are
# interploted into strings.
use vars qw(%E);
tie %E, __PACKAGE__;
sub TIEHASH { bless {}, shift }
sub FETCH { $cs->escape($_[1]) }


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
        foreach my $blocked (@blocked) {
            if ($emulate_matts_code ) {
                $File::Find::prune = 1 if "$dirname$basename" eq $blocked;
            }
            else {
               $File::Find::prune = 1 if "$dirname$basename" =~ /$blocked/;
            }
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
           return if $_ eq $blocked;
        }
        else {
           return if /$blocked/;
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

    $dirname =~ m|^([:\\+\@\w./ -]*)$| or die "suspect directory name: $dirname";
    return $1;
}


sub start_of_html
{
    my ($title,$style) = @_;
    print "Content-Type: text/html; charset=$charset\n\n";
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
    <h1 align="center">Results of Search in $E{$title}</h1>
    <p>Below are the results of your Search in no particular order:</p>
    <hr size="7" width="75%" />
    <ul>
END_HTML
}


sub print_result
{
    my ($baseurl, $file, $title) = @_;

    $file    =~ s#^/##;
    $baseurl =~ s#/$##;

    print qq(<li><a href="$E{"$baseurl/$file"}">$E{$title}</a></li>\n);
}


sub end_of_html
{
  my ($search_url, $title_url, $title, $terms, $boolean, $case) = @_;
  print <<END_HTML;
    </ul>
    <hr size="7" width="75%" />
   <p>Search Information:</p>
   <ul>
     <li><b>Terms:</b> $E{$terms}</li>
     <li><b>Boolean Used:</b> $E{$boolean}</li>
     <li><b>Case:</b> $E{$case}</li>
   </ul>
   <hr size="7" width="75%" />
   <ul>
     <li><a href="$E{$search_url}">Back to Search Page</a></li>
     <li><a href="$E{$title_url}">$E{$title}</a></li>
   </ul>
   <hr size="7" width="75%" />
   <p>Search Script (c) London Perl Mongers 2001 part of
   <a href="http://nms-cgi.sourceforge.net/">NMS Project</a></p>
 </body>
</html>
END_HTML
}

###################################################################

BEGIN {
  eval 'local $SIG{__DIE__} ; require CGI::NMS::Charset';
  $@ and $INC{'CGI/NMS/Charset.pm'} = 1;
  $@ and eval <<'END_CGI_NMS_CHARSET' || die $@;

## BEGIN INLINED CGI::NMS::Charset
package CGI::NMS::Charset;
use strict;

require 5.00404;

use vars qw($VERSION);
$VERSION = sprintf '%d.%.2d', (q$revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=head1 NAME

CGI::NMS::Charset - a charset-aware object for handling text strings

=head1 SYNOPSIS

   my $cs = CGI::NMS::Charset->new('iso-8859-1');

   my $safe_to_put_in_html = $cs->escape($untrusted_user_input);

   my $printable = &{ $cs->strip_nonprint_coderef }( $input );
   my $escaped = &{ $cs->escape_html_coderef }( $printable );

=head1 DESCRIPTION

Each object of class C<CGI::NMS::Charset> is bound to a particular
character set when it is created.  The object provides methods to
generate coderefs to perform a couple of character set dependent
operations on text strings.

=cut

=head1 CONSTRUCTORS

=over

=item new ( CHARSET )

Creates a new C<CGI::NMS::Charset> object, suitable for handing text
in the character set CHARSET.  The CHARSET parameter must be a
character set string, such as C<us-ascii> or C<utf-8> for example.

=cut

sub new
{
   my ($pkg, $charset) = @_;

   my $self = { CHARSET => $charset };

   if ($charset =~ /^utf-8$/i)
   {
      $self->{SN} = \&_strip_nonprint_utf8;
      $self->{EH} = \&_escape_html_utf8;
   }
   elsif ($charset =~ /^iso-8859/i)
   {
      $self->{SN} = \&_strip_nonprint_8859;
      if ($charset =~ /^iso-8859-1$/i)
      {
         $self->{EH} = \&_escape_html_8859_1;
      }
      else
      {
         $self->{EH} = \&_escape_html_8859;
      }
   }
   elsif ($charset =~ /^us-ascii$/i)
   {
      $self->{SN} = \&_strip_nonprint_ascii;
      $self->{EH} = \&_escape_html_8859_1;
   }
   else
   {
      $self->{SN} = \&_strip_nonprint_weak;
      $self->{EH} = \&_escape_html_weak;
   }

   return bless $self, $pkg;
}

=back

=head1 METHODS

=over

=item charset ()

Returns the CHARSET string that was passed to the constructor.

=cut

sub charset
{
   my ($self) = @_;

   return $self->{CHARSET};
}

=item escape ( STRING )

Returns a copy of STRING with runs of non-printable characters
replaced with spaces and HTML metacharacters replaced with the
equivalent entities.

If STRING is undef then the empty string will be returned.

=cut

sub escape
{
   my ($self, $string) = @_;

   return &{ $self->{EH} }(  &{ $self->{SN} }($string)  );
}

=item strip_nonprint_coderef ()

Returns a reference to a sub to replace runs of non-printable
characters with spaces, in a manner suited to the charset in
use.

The returned coderef points to a sub that takes a single readonly
string argument and returns a modified version of the string.  If
undef is passed to the function then the empty string will be
returned.

=cut

sub strip_nonprint_coderef
{
   my ($self) = @_;

   return $self->{SN};
}

=item escape_html_coderef ()

Returns a reference to a sub to escape HTML metacharacters in
a manner suited to the charset in use.

The returned coderef points to a sub that takes a single readonly
string argument and returns a modified version of the string.

=cut

sub escape_html_coderef
{
   my ($self) = @_;

   return $self->{EH};
}

=back

=head1 DATA TABLES

=over

=item C<%eschtml_map>

The C<%eschtml_map> hash maps C<iso-8859-1> characters to the
equivalent HTML entities.

=cut

use vars qw(%eschtml_map);
%eschtml_map = ( 
                 ( map {chr($_) => "&#$_;"} (0..255) ),
                 '<' => '&lt;',
                 '>' => '&gt;',
                 '&' => '&amp;',
                 '"' => '&quot;',
               );

=back

=head1 PRIVATE FUNCTIONS

These functions are returned by the strip_nonprint_coderef() and
escape_html_coderef() methods and invoked by the escape() method.
The function most appropriate to the character set in use will be
chosen.

=over

=item _strip_nonprint_utf8

Returns a copy of STRING with everything but printable C<us-ascii>
characters and valid C<utf-8> multibyte sequences replaced with
space characters.

=cut

sub _strip_nonprint_utf8
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~
   s%
    ( [\t\n\040-\176]               # printable us-ascii
    | [\xC2-\xDF][\x80-\xBF]        # U+00000080 to U+000007FF
    | \xE0[\xA0-\xBF][\x80-\xBF]    # U+00000800 to U+00000FFF
    | [\xE1-\xEF][\x80-\xBF]{2}     # U+00001000 to U+0000FFFF
    | \xF0[\x90-\xBF][\x80-\xBF]{2} # U+00010000 to U+0003FFFF
    | [\xF1-\xF7][\x80-\xBF]{3}     # U+00040000 to U+001FFFFF
    | \xF8[\x88-\xBF][\x80-\xBF]{3} # U+00200000 to U+00FFFFFF
    | [\xF9-\xFB][\x80-\xBF]{4}     # U+01000000 to U+03FFFFFF
    | \xFC[\x84-\xBF][\x80-\xBF]{4} # U+04000000 to U+3FFFFFFF
    | \xFD[\x80-\xBF]{5}            # U+40000000 to U+7FFFFFFF
    ) | .
   %
    defined $1 ? $1 : ' '
   %gexs;

   #
   # U+FFFE, U+FFFF and U+D800 to U+DFFF are dangerous and
   # should be treated as invalid combinations, according to
   # http://www.cl.cam.ac.uk/~mgk25/unicode.html
   #
   $string =~ s%\xEF\xBF[\xBE-\xBF]% %g;
   $string =~ s%\xED[\xA0-\xBF][\x80-\xBF]% %g;

   return $string;
}

=item _escape_html_utf8 ( STRING )

Returns a copy of STRING with any HTML metacharacters
escaped.  Escapes all but the most commonly occurring C<us-ascii>
characters and bytes that might form part of valid C<utf-8>
multibyte sequences.

=cut

sub _escape_html_utf8
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\x80-\xFD])| $eschtml_map{$1} |ge;
   return $string;
}

=item _strip_nonprint_weak ( STRING )

Returns a copy of STRING with sequences of NULL characters
replaced with space characters.

=cut

sub _strip_nonprint_weak
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ s/\0+/ /g;
   return $string;
}
   
=item _escape_html_weak ( STRING )

Returns a copy of STRING with any HTML metacharacters escaped.
In order to work in any charset, escapes only E<lt>, E<gt>, C<">
and C<&> characters.

=cut

sub _escape_html_weak
{
   my ($string) = @_;

   $string =~ s/[<>"&]/$eschtml_map{$1}/eg;
   return $string;
}

=item _escape_html_8859_1 ( STRING )

Returns a copy of STRING with all but the most commonly
occurring printable characters replaced with HTML entities.
Only suitable for C<us-ascii> or C<iso-8859-1> input.

=cut

sub _escape_html_8859_1
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\/\:])| $eschtml_map{$1} |ge;
   return $string;
}

=item _escape_html_8859 ( STRING )

Returns a copy of STRING with all but the most commonly
occurring printable C<us-ascii> characters and characters
that might be printable in some C<iso-8859-*> charset
replaced with HTML entities.

=cut

sub _escape_html_8859
{
   my ($string) = @_;

   $string =~ s|([^\w \t\r\n\-\.\,\/\:\240-\377])| $eschtml_map{$1} |ge;
   return $string;
}

=item _strip_nonprint_8859 ( STRING )

Returns a copy of STRING with runs of characters that are not
printable in any C<iso-8859-*> charset replaced with spaces.

=cut

sub _strip_nonprint_8859
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ tr#\t\n\040-\176\240-\377# #cs;
   return $string;
}

=item _strip_nonprint_ascii ( STRING )

Returns a copy of STRING with runs of characters that are not
printable C<us-ascii> replaced with spaces.

=cut

sub _strip_nonprint_ascii
{
   my ($string) = @_;
   return '' unless defined $string;

   $string =~ tr#\t\n\040-\176# #cs;
   return $string;
}

=back

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

## END INLINED CGI::NMS::Charset
END_CGI_NMS_CHARSET
}

