#!/usr/bin/perl -Tw
#
# $Id: wwwboard.pl,v 1.60 2005-02-09 11:45:11 gellyfish Exp $
#

use strict;
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use POSIX qw(locale_h strftime);

CGI::NMS::IPFilter->import();

use vars qw(
  $DEBUGGING $VERSION $done_headers $emulate_matts_code
  $max_followups $basedir $baseurl $cgi_url $mesgdir $datafile
  $mesgfile $faqfile $ext $title $style $show_faq $allow_html
  $quote_text $quote_char $quote_html $subject_line $use_time
  $date_fmt $time_fmt $show_poster_ip $enable_preview $enforce_max_len
  %max_len $strict_image @image_suffixes $locale $charset @bannedwords
  $bannedwords $bannednets @use_rbls $check_sc_uri
);
BEGIN { $VERSION = substr q$Revision: 1.60 $, 10, -1; }

# PROGRAM INFORMATION
# -------------------
# wwwboard.pl $Revision: 1.60 $
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

BEGIN
{
    $DEBUGGING          = 1;
    $emulate_matts_code = 1;
    $max_followups      = 10;
    $basedir            = '/var/www/nms-test/wwwboard';
    $baseurl            = 'http://nms-test/wwwboard';
    $cgi_url            = 'http://nms-test/cgi-bin/wwwboard.pl';
    $mesgdir            = 'messages';
    $datafile           = 'data.txt';
    $mesgfile           = 'wwwboard.html';
    $faqfile            = 'faq.html';
    $ext                = 'html';
    $title              = "NMS WWWBoard Version $VERSION";
    $style              = '/css/nms.css';
    $show_faq           = 1;
    $allow_html         = 1;
    $quote_text         = 1;
    $quote_char         = ':';
    $quote_html         = 1;
    $subject_line       = 0;
    $use_time           = 1;
    $date_fmt           = '%d/%m/%y';
    $time_fmt           = '%T';
    $show_poster_ip     = 1;
    $enable_preview     = 0;
    $enforce_max_len    = 0;
    %max_len            = (
        'name'        => 50,
        'email'       => 70,
        'subject'     => 80,
        'url'         => 150,
        'url_title'   => 80,
        'img'         => 150,
        'body'        => 3000,
        'origsubject' => 80,
        'origname'    => 50,
        'origemail'   => 70,
        'origdate'    => 50
    );
    $strict_image   = 1;
    @image_suffixes = qw(png jpe?g gif);
    $locale         = '';
    $charset        = 'iso-8859-1';

    $bannedwords    = '';
    $bannednets     = '';
    @use_rbls       = qw();
    $check_sc_uri   = 0;

    #
    # USER CONFIGURATION << END >>
    # ----------------------------
    # (no user serviceable parts beyond here)

    eval {
        sub SEEK_SET() { 0; }
    } unless defined(&SEEK_SET);

    if ($use_time)
    {
        $date_fmt = "$time_fmt $date_fmt";
    }

    use vars qw($html_preview_button);
    $html_preview_button = (
        $enable_preview
        ? ' <input type="submit" name="preview" value="Preview Post" />'
        : ''
    );
}

sub html_header
{
    if ( $CGI::VERSION >= 2.57 )
    {

        # This is the correct way to set the charset
        print header( '-type' => 'text/html', '-charset' => $charset );
    }
    else
    {

        # However CGI.pm older than version 2.57 doesn't have the
        # -charset option so we cheat:
        print header( '-type' => "text/html; charset=$charset" );
    }
}

# We need finer control over what gets to the browser and the CGI::Carp
# set_message() is not available everywhere :(
# This is basically the same as what CGI::Carp does inside but simplified
# for our purposes here.

BEGIN
{

    sub fatalsToBrowser
    {
        my ($message) = @_;

        if ($DEBUGGING)
        {
            $message =~ s/</&lt;/g;
            $message =~ s/>/&gt;/g;
        }
        else
        {
            $message = '';
        }

        my ( $pack, $file, $line, $sub ) = caller(0);
        my ($id) = $file =~ m%([^/]+)$%;

        return undef if $file =~ /^\(eval/;

        html_header() unless $done_headers;

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
    }

    $SIG{__DIE__} = \&fatalsToBrowser;
}

use vars qw($cs);
$cs = CGI::NMS::Charset->new($charset);

# %E is a fake hash for escaping HTML metachars as things are
# interploted into strings.
use vars qw(%E);
tie %E, __PACKAGE__;
sub TIEHASH { bless {}, shift }
sub FETCH { $cs->escape( $_[1] ) }

use vars qw($html_style);
$html_style = $style
  ? qq%<link rel="stylesheet" type="text/css" href="$E{$style}" />%
  : '';

# We don't need file uploads or very large POST requests.
# Annoying locution to shut up 'used only once' warning in
# older perl.  Localize these to avoid stomping on other
# scripts that need file uploads under Apache::Registry.

local ( $CGI::DISABLE_UPLOADS, $CGI::POST_MAX );
$CGI::DISABLE_UPLOADS = 1;
$CGI::POST_MAX        = 1000000;

# Empty the environment of potentially harmful variables,
# and detaint the path.  We accept anything in the path
# because $ENV{PATH} is trusted for a CGI script, and in
# general we have no way to tell what should be there.

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} =~ /(.*)/ and $ENV{PATH} = $1;

$done_headers = 0;

if ( check_ip($ENV{REMOTE_ADDR}) )
{
   error('blocked');
}
my $Form = parse_form();

my $variables = get_variables($Form);

if ( param('preview') )
{
    preview_post($variables);
}
else
{
    open LOCK, ">>$basedir/.lock" or die "open >>$basedir/.lock: $!";
    flock LOCK, LOCK_EX or die "flock $basedir/.lock: $!";

    my $ft = File::Transaction->new;

    eval {
        local $SIG{__DIE__};

        $variables->{id} = get_number($ft);

        new_file( $ft, $variables );
        main_page( $ft, $variables );

        thread_pages( $ft, $variables );
    };

    if ($@)
    {
        $ft->revert;
        close LOCK;
        die $@;
    }
    else
    {
        $ft->commit;
        close LOCK;
        return_html($variables);
    }
}

sub get_number
{
    my ($ft) = @_;
    my $num  = 0;
    my $file = "$basedir/$datafile";

    if ( open NUMBER, "<$file" )
    {
        $num = <NUMBER> || 0;
        $num =~ /^(\d+)\s*$/ or die "$file bad";
        $num = $1;
        close NUMBER;
    }

    $num++;
    $num = 1 if $num > 999999;

    open NUMBER, ">$file.tmp" or die "open >$file.tmp: $!";
    print NUMBER $num;
    close NUMBER or die "close $file.tmp: $!";

    $ft->addfile( $file, "$file.tmp" );

    return $num;
}

sub parse_form
{
    my %Form;

    foreach my $param ( keys %max_len, 'followup' )
    {
        my $val = param($param);
        defined $val or $val = '';
        $Form{$param} = &{ $cs->strip_nonprint_coderef }($val);
        $Form{$param} =~ s/[\r\n\0]/ /g unless $param eq 'body';
    }

    if ($enforce_max_len)
    {
        foreach ( keys %max_len )
        {
            if ( length( $Form{$_} ) > $max_len{$_} )
            {
                if ( $enforce_max_len == 2 )
                {
                    error( 'field_size', { Form => \%Form } );
                }
                else
                {
                    $Form{$_} = substr( $Form{$_}, 0, $max_len{$_} );
                }
            }
        }
    }
    return \%Form;
}

###############
# Get Variables

sub get_variables
{

    my ($Form) = @_;

    my $variables = { Form => $Form };

    my @followup_num;

    if ( exists $Form->{followup} && length( $Form->{followup} ) )
    {
        $variables->{followup} = 1;
        @followup_num = split( /,/, $Form->{followup} );

        my %fcheck;
        foreach my $fn (@followup_num)
        {
            if ( $fcheck{$fn} or $fn !~ /^(\d+)$/ )
            {
                error( 'followup_data', { Form => $Form } );
            }
            else
            {
                $fn = $1;
                $fcheck{$fn} = 1;
            }
        }

        # truncate the list of followups so that a vandal can't followup
        # to every existing message on the site.
        if (   !$emulate_matts_code
            && $max_followups
            && $max_followups < @followup_num )
        {

            my $start_followups = $#followup_num - $max_followups;

            @followup_num = @followup_num[ $start_followups .. $#followup_num ];
        }

        $variables->{followups}     = \@followup_num;
        $variables->{num_followups} = scalar @followup_num;
        $variables->{last_message}  = $followup_num[$#followup_num];
        $variables->{origdate}      = $Form->{origdate};
        $variables->{origname}      = $Form->{origname};
        $variables->{origsubject}   = $Form->{origsubject};
    }
    else
    {
        $variables->{followup} = $variables->{num_followups} = 0;
    }

    length $Form->{name} or error( 'no_name', $variables );

    check_banned( $Form->{name} ) or error('invalid');

    $variables->{name} = $Form->{name};

    if ( $Form->{email} =~ /(.*\@.*\..*)/ )
    {
        $variables->{email} = $1;
    }
    else
    {
        $variables->{email} = '';
    }

    if ( $Form->{subject} )
    {
        check_banned( $Form->{subject} ) or error('invalid');
        check_uri_rbl( $Form->{subject} ) and error ('invalid');
        $variables->{subject} = $Form->{subject};
    }
    else
    {
        error( 'no_subject', $variables );
    }

    my $url = validate_url( $Form->{'url'} || '' );
    check_uri_rbl( $url ) and error ('invalid');
    $Form->{'url_title'} =~ s/&#[0-9]{1,3};//g;
    $Form->{'url_title'} =~ s/[^a-zA-Z0-9_ ?!&;]//g;
    if ( $url and $Form->{'url_title'} )
    {
        $variables->{message_url}       = $url;
        $variables->{message_url_title} = $Form->{'url_title'};
    }

    my $message_img = validate_url( $Form->{'img'} || '' );
    check_uri_rbl( $message_img ) and error ('invalid');
    if ( $message_img and $strict_image )
    {
        my $image_suffixes = join '|', @image_suffixes;
        unless ( $message_img =~ /($image_suffixes)$/i )
        {
            undef $message_img;
        }
    }
    $message_img and $variables->{message_img} = $message_img;

    if ( my $body = $Form->{'body'} )
    {

        unless ($allow_html)
        {

            # strip out what look like tags, then escape all but
            # wellformed HTML entities.
            $body =~ s#</?\w+[^>]*># #g;
            $body =~
              s/(&#?\w{1,20};)|(.[^&]*)/ defined $1 ? $1 : $cs->escape($2) /ges;
        }

        $body = "<p>$body</p>";
        $body =~ s/\cM//g;
        $body =~ s|\n\n|</p><p>|g;
        $body =~ s%\n%<br />%g;

        if ($allow_html)
        {
            $body = filter_html($body);
        }

        check_banned($body) or error('invalid');
        check_uri_rbl( $body ) and error ('invalid');

        $variables->{html_body} = $body;

    }
    else
    {
        error( 'no_body', $variables );
    }

    if ($quote_text)
    {
        my $hidden_body = $Form->{'body'};
        $hidden_body =~ s#(</?[a-z][^>]*>)+# #ig unless $quote_html;
        $variables->{hidden_body} = $hidden_body;
    }

    eval { setlocale( LC_TIME, $locale ) if $locale; };

    $variables->{date} = strftime( $date_fmt, localtime() );

    return $variables;
}

=item check_ip IPNUMBER

If the $bannednets configuration is defined and contains network
specifications then check IPNUMBER against it, also if @use_rbls is
defined will perform a check against these if it is not found in the
local list. Returns a true value if the IP is found in either source.

=cut

sub check_ip
{
   my ( $ip ) = @_;

   if ( $bannednets and -s $bannednets )
   {
      open BANNED, "<$bannednets" or die "Can't open $bannednets - $!";
      while (<BANNED>)
      {
         chomp;
         next unless $_;
         if (ip_in_network($ip, $_))
         {
            return 1;
         }
            
      }
   }

   foreach my $rbl (@use_rbls)
   {
      if ( !rbl_check($ip, $rbl ))
      {
         return 1;
      }

   }

   return 0;
}

=item check_banned

Implement banned words list.  If $bannedwords configuration is defined
and is a file will take each line as a regular expression to be compared
with the content presented as an argument.

=cut

sub check_banned
{
    my ($temp) = @_;

    if ( $bannedwords and -s $bannedwords )
    {
       if (!@bannedwords)
       {
          open BANNED, "<$bannedwords" or die "Can't open $bannedwords - $!";
          chomp(@bannedwords = <BANNED>);
       }

      foreach my $word (@bannedwords)
      {
         return 0 if ( lc($temp) =~ /$word/ );
      }
    }

    return 1;
}

#####################
# New File Subroutine

sub new_file
{

    my ( $ft, $variables ) = @_;

    my $md   = "$basedir/$mesgdir";
    my $file = "$md/$variables->{id}.$ext";
    -r $file and die "refusing to overwrite [$file]";

    -d $md or mkdir $md, 0755 or die "mkdir $md: $!";
    open( NEWFILE, ">$file.tmp" ) || die "Open [$file.tmp]: $!";

    my $html_faq =
      $show_faq ? qq( [ <a href="$E{"$baseurl/$faqfile"}">FAQ</a> ]) : '';
    my $html_print_name =
      $variables->{email}
      ? qq(<a href="$E{"mailto:$variables->{email}"}">$E{$variables->{name}}</a> )
      : $E{ $variables->{name} };
    my $ip = $show_poster_ip ? "($ENV{REMOTE_ADDR})" : '';

    my $html_pr_follow = '';

    if ( $variables->{followup} )
    {
        $html_pr_follow = qq(<p>In Reply to:
       <a href="$E{"$variables->{last_message}.$ext"}">$E{$variables->{origsubject}}</a> posted by );

        if ( $variables->{origemail} )
        {
            $html_pr_follow .=
qq(<a href="$E{$variables->{origemail}}">$E{$variables->{origname}}</a>);
        }
        else
        {
            $html_pr_follow .= $E{ $variables->{origname} };
        }
        $html_pr_follow .= '</p>';
    }

    my $html_img =
      $variables->{message_img}
      ? qq(<p align="center"><img src="$E{$variables->{message_img}}" /></p>\n)
      : '';
    my $html_email_input =
      $variables->{email}
      ? qq(<input type="hidden" name="origemail" value="$E{$variables->{email}}" />)
      : '';
    my $html_url =
      $variables->{message_url}
      ? qq(<ul><li><a href="$E{$variables->{message_url}}">$E{$variables->{message_url_title}}</a></li></ul><br />)
      : '';

    my $followups = $variables->{id};
    if ( defined $variables->{followups} )
    {
        $followups = join( ',', @{ $variables->{followups} }, $followups );
    }

    print NEWFILE <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$E{$variables->{subject}}</title>
    $html_style
  </head>
  <body>
    <h1 align="center">$E{$variables->{subject}}</h1>
    <hr />
    <p align="center">
      [ <a href="#followups">Follow Ups</a> ]
      [ <a href="#postfp">Post Followup</a> ]
      [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]
      $html_faq
    </p>

  <hr />
  <p>Posted by $html_print_name $E{$ip} on $E{$variables->{date}}</p>

  $html_pr_follow

  $html_img

  $variables->{html_body}<br />$html_url

  <hr />
  <p><a id="followups" name="followups">Follow Ups:</a></p>
  <ul><!--insert: $E{$variables->{id}}-->
  </ul><!--end: $E{$variables->{id}}-->
  <br /><hr />
  <p><a id="postfp" name="postfp">Post a Followup</a></p>
  <form method="post" action="$E{$cgi_url}">
  <input type="hidden" name="followup" value="$E{$followups}" />
  <input type="hidden" name="origname" value="$E{$variables->{name}}" />
  $html_email_input
  <input type="hidden" name="origsubject" value="$E{$variables->{subject}}" />
  <input type="hidden" name="origdate" value="$E{$variables->{date}}" />
  <table summary="">
  <tr>
  <td>Name:</td>
  <td><input type="text" name="name" size="50" /></td>
  </tr>
  <tr>
  <td>E-Mail:</td>
  <td><input type="text" name="email" size="50" /></td>
  </tr>
END_HTML

    my $subject = $variables->{subject};

    $subject = 'Re: ' . $subject unless $subject =~ /^Re:/i;

    if ( $subject_line == 1 )
    {
        print NEWFILE
          qq(<input type="hidden" name="subject" value="$E{$subject}" />\n);
        print NEWFILE
          "<tr><td>Subject:</td><td><b>$E{$subject}</b></td></tr>\n";
    }
    elsif ( $subject_line == 2 )
    {
        print NEWFILE
qq(<tr><td>Subject:</td><td><input type="text" name="subject" size="50" /></td></tr>\n);
    }
    else
    {
        print NEWFILE
qq(<tr><td>Subject:</td><td><input type="text" name="subject" value="$E{$subject}" size="50" /></td></tr>\n);
    }
    print NEWFILE "<tr><td>Comments:</td>\n";
    print NEWFILE qq(<td><textarea name="body" cols="50" rows="10">\n);
    if ($quote_text)
    {
        print NEWFILE map { $E{"$quote_char $_\n"} }
          split /\n/, $variables->{hidden_body};
        print NEWFILE "\n";
    }
    print NEWFILE "</textarea></td></tr>\n";
    print NEWFILE <<END_HTML;
<tr>
<td>Optional Link URL:</td>
<td><input type="text" name="url" size="50" /></td>
</tr>
<tr>
<td>Link Title:</td>
<td><input type="text" name="url_title" size="48" /></td>
</tr>
<tr>
<td>Optional Image URL:</td>
<td><input type="text" name="img" size="49" /></td>
</tr>
<tr>
<td colspan="2"><input type="submit" value="Submit Follow Up" />
<input type="reset" />$html_preview_button</td>
</tr>
</table>
</form>
<hr />
<p align="center">
   [ <a href="#followups">Follow Ups</a> ]
   [ <a href="#postfp">Post Followup</a> ]
   [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]
   $html_faq
</p>
</body>
</html>
END_HTML

    unless ( close NEWFILE )
    {
        my $err = "close $file.tmp: $!";
        unlink "$file.tmp";
        die $err;
    }

    $ft->addfile( $file, "$file.tmp" );
}

###############################
# Main WWWBoard Page Subroutine

sub main_page
{
    my ( $ft, $variables ) = @_;

    if ( $variables->{followup} )
    {
        insert_followup( $ft, $variables, "$basedir/$mesgfile", "$mesgdir/" );
    }
    else
    {
        $ft->linewise_rewrite(
            "$basedir/$mesgfile",
            sub {
                if (/<!--begin-->/)
                {
                    $_ .= html_message_line( $variables, "$mesgdir/" );
                }
            }
        );
    }
}

sub insert_followup
{
    my ( $ft, $variables, $file, $url_prefix ) = @_;

    my %is_followup_to = map { $_ => 1 } @{ $variables->{followups} };

    $ft->linewise_rewrite(
        $file,
        sub {

            if (/\Q<ul><!--insert: $E{$variables->{last_message}}-->/)
            {
                $_ .= html_message_line( $variables, $url_prefix );
            }
            elsif (m#\(<!--responses: (\d+?)-->(\d+?)\)#)
            {
                my ( $respto, $respcount ) = ( $1, $2 );
                if ( exists $is_followup_to{$respto} )
                {
                    $respcount++;
s#\(<!--responses: \d+-->\d+\)#(<!--responses: $respto-->$respcount)#
                      or die "unexpected s/// failure";
                }
            }

        }
    );
}

sub html_message_line
{
    my ( $variables, $url_prefix ) = @_;

    my $id      = $variables->{id};
    my $subject = $variables->{subject};
    my $name    = $variables->{name};
    my $date    = $variables->{date};

    return <<END_HTML;
<!--top: $E{$id}--><li><a href="$E{"$url_prefix$id.$ext"}">$E{$subject}</a> - <b>$E{$name}</b> <i>$E{$date}</i>
(<!--responses: $E{$id}-->0)
<ul><!--insert: $E{$id}-->
</ul><!--end: $E{$id}--></li>
END_HTML

}

############################################
# Add Followup Threading to Individual Pages
sub thread_pages
{

    my ( $ft, $variables ) = @_;

    return unless $variables->{num_followups};

    foreach my $followup_num ( @{ $variables->{followups} } )
    {
        insert_followup( $ft, $variables,
            "$basedir/$mesgdir/$followup_num.$ext", '' );
    }

}

sub return_html
{

    my ($variables) = @_;
    my $id = $variables->{id};

    html_header();
    $done_headers++;

    my $html_url =
      $variables->{message_url}
      ? qq(<p><b>Link:</b> <a href="$E{$variables->{message_url}}">$E{$variables->{message_url_title}}</a></p>)
      : '';
    my $html_img =
      $variables->{message_img}
      ? qq(<p><b>Image:</b> <img src="$E{$variables->{message_img}}" /></p>)
      : '';

    print <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Message Added: $E{$variables->{subject}}</title>
    $html_style
  </head>
  <body>
    <h1 align="center">Message Added: $E{$variables->{subject}}</h1>
    <p>The following information was added to the message board:</p>
    <hr />
    <p><b>Name:</b> $E{$variables->{name}}<br />
      <b>E-Mail:</b> $E{$variables->{email}}<br />
      <b>Subject:</b> $E{$variables->{subject}}<br />
      <b>Body of Message:</b></p>
      <p>$variables->{html_body}</p>
    $html_url
    $html_img

    <p><b>Added on Date:</b> $E{$variables->{date}}</p>
    <hr />
    <p align="center">
       [ <a href="$E{"$baseurl/$mesgdir/$id.$ext"}">Go to Your Message</a> ]
       [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]
    </p>
  </body>
</html>
END_HTML
}

sub preview_post
{
    my ($variables) = @_;

    html_header();
    $done_headers = 1;

    print <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Preview</title>
    $html_style
  </head>
  <body><h1 align="center">$E{$variables->{subject}}</h1>
  <hr />
    $variables->{html_body}
  <hr />
END_HTML
    rest_of_form($variables);
}

sub error
{
    my ( $error, $variables ) = @_;

    html_header();
    $done_headers++;

    my ( $html_error_message, $error_title );
    if ( $error =~ /^no_(name|subject|body)$/ )
    {
        my $missing = ucfirst $1;
        $error_title        = "No $missing";
        $html_error_message = <<EOMESS;
  <p>You forgot to fill in the '$missing' field in your posting.  Correct it
    below and re-submit.  The necessary fields are: Name, Subject and
    Message.</p>
EOMESS
    }
    elsif ( $error eq 'field_size' )
    {
        $error_title        = 'Field too Long';
        $html_error_message = <<EOMESS;
  <p>One of the form fields in the message submission was too long.  The
  following are the limits on the size of each field (in characters):</p>
  <ul>
    <li>Name: $E{$max_len{'name'}}</li>
    <li>E-Mail: $E{$max_len{'email'}}</li>
    <li>Subject: $E{$max_len{'subject'}}</li>
    <li>Body: $E{$max_len{'body'}}</li>
    <li>URL: $E{$max_len{'url'}}</li>
    <li>URL Title: $E{$max_len{'url_title'}}</li>
    <li>Image URL: $E{$max_len{'img'}}</li>
  </ul>
  <p>Please modify the form data and resubmit.</p>
EOMESS
    }
    elsif ( $error eq 'invalid' )
    {
        $error_title        = 'Invalid data';
        $html_error_message = <<EOMESS;
<p>Attempt to submit invalid data. Your message will not be added.</p>
EOMESS
    }
    elsif ($error eq 'blocked' )
    {
       $error_title        = 'Blocked client';
       $html_error_message =<<EOMESS;
<p>The address you are posting from has been blocked - if you believe this
is a mistake please contact the owner of this site</p>
EOMESS
    }
    else
    {
        $error_title        = 'Application error';
        $html_error_message = <<EOMESS;
<p>An error has occurred while your message was being submitted
please use your back button and try again</p>
EOMESS
    }
    print <<END_HTML;
<?xml version="1.0" encoding="$charset"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$E{"$title ERROR: $error_title"}</title>
    $html_style
  </head>
  <body><h1 align="center">ERROR: $E{$error_title}</h1>
    $html_error_message
  <hr />
END_HTML
    if ($variables) { rest_of_form($variables); }
    exit;
}

sub rest_of_form
{

    my ($variables) = @_;

    print qq(<form method="POST" action="$E{$cgi_url}">\n);

    my %Form = %{ $variables->{Form} };

    if ( defined $variables->{followup} and $variables->{followup} == 1 )
    {
        print <<END_HTML;
<input type="hidden" name="origsubject" value="$E{$Form{origsubject}}" />
<input type="hidden" name="origname" value="$E{$Form{origname}}" />
<input type="hidden" name="origemail" value="$E{$Form{origemail}}" />
<input type="hidden" name="origdate" value="$E{$Form{origdate}}" />
<input type="hidden" name="followup" value="$E{$Form{followup}}" />
END_HTML
    }
    print
qq(Name: <input type="text" name="name" value="$E{$Form{name}}" size="50" /><br />\n);
    print
qq(E-Mail: <input type="text" name="email" value="$E{$Form{email}}" size="50" /><p />\n);
    if ( $subject_line == 1 )
    {
        print
qq(<input type="hidden" name="subject" value="$E{$Form{subject}}" />\n);
        print qq(Subject: <b>$E{$Form{subject}}</b><p />\n);
    }
    else
    {
        print
qq(Subject: <input type="text" name="subject" value="$E{$Form{subject}}" size="50" /><p />\n);
    }

    print <<END_HTML;
Message:<br />
<textarea cols="50" rows="10" name="body">
$E{$Form{'body'}}
</textarea><p />
Optional Link URL: <input type="text" name="url" value="$E{$Form{'url'}}" size="45" /><br />
Link Title: <input type="text" name="url_title" value="$E{$Form{'url_title'}}" size="50" /><br />
Optional Image URL: <input type="text" name="img" value="$E{$Form{'img'}}" size="45" /><p />
<input type="submit" value="Post Message" /> <input type="reset" />$html_preview_button
</form>
<br /><hr size="7" width="75%" />
END_HTML

    if ($show_faq)
    {
        print
qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ] [ <a href="$E{"$baseurl/$faqfile"}">FAQ</a> ]</center>\n);
    }
    else
    {
        print
qq(<center>[ <a href="#followups">Follow Ups</a> ] [ <a href="#postfp">Post Followup</a> ] [ <a href="$E{"$baseurl/$mesgfile"}">$E{$title}</a> ]</center>\n);
    }
    print "</body></html>\n";
}

sub filter_html
{
    my ($comments) = @_;

    my $filter = CGI::NMS::HTMLFilter->new(
        charset        => $cs,
        allow_href     => 1,
        allow_a_mailto => 1,
        allow_src      => 1,
    );
    return $filter->filter( $comments, 'Flow' );
}

sub validate_url
{
    my ($url) = @_;

    $url = "http://$url" unless $url =~ /:/;

    $url =~ m<( ^ (?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?
                (?: /  [\w\-.!~*'(|);/\@+\$,%#]*   )?
                (?: \? [\w\-.!~*'(|);/\@&=+\$,%#]* )?
              $
            )>x ? $1 : undef;
}

=item check_uri_rbl (URI)

Checks the host of the provided URI against the sc.surbl.org DNSBL
returns 1 if part of the domain name is in the DNSBL

=cut

sub check_uri_rbl
{
   my ($text) = @_;

   if ( $check_sc_uri )
   {
      my @urls = $text =~ m%(?:ftp|http|https)://([^:/?\s\x00-\x21\x7F-\xFF">]+)%g;

      foreach my $host ( @urls )
      {
         $host =~ s/(?:%|=)([0-9a-fA-F]{2})/chr(hex($1))/eg;

         my @bits = split /\./, $host;

         while (@bits > 1 )
         {
            my $host = join '.', (@bits,'sc.surbl.org');

            return 1 if ( defined gethostbyname($host));

            shift @bits;
         }
      }
   }

   return 0;
}

###############################################################

BEGIN
{
    eval 'local $SIG{__DIE__} ; require File::Transaction';
    $@ and $INC{'File/Transaction.pm'} = 1;
    $@ and eval <<'END_FILE_TRANSACTION' || die $@;

## BEGIN INLINED File::Transaction
package File::Transaction;
use strict;

use vars qw($VERSION);
$VERSION = '0.04';

use IO::File;

=head1 NAME

File::Transaction - transactional change to a set of files

=head1 SYNOPSIS

  #
  # In this example, we wish to replace the word 'foo' with the
  # word 'bar' in several files, and we wish to minimize the risk
  # of ending up with the replacement done in some files but not
  # in others.
  #

  use File::Transaction;

  my $ft = File::Transaction->new;

  eval {
      foreach my $file (@list_of_file_names) {
          $ft->linewise_rewrite($file, sub {
               s#\bfoo\b#bar#g;
          });
      }
  };

  if ($@) {
      $ft->revert;
      die "update aborted: $@";
  }
  else {
      $ft->commit;
  }

=head1 DESCRIPTION

A C<File::Transaction> object encapsulates a change to a set of files,
performed by writing out a new version of each file first and then
swapping all of the new versions in.  The set of files can only end up
in an inconsistent state if a C<rename> system call fails or if the
Perl process is interrupted during the commit().

Files will be committed in the order in which they are added to the
transaction.  This order should be chosen with care to limit the
damage to your data if the commit() fails part way through.  If there
is no order that renders a partial commit acceptable then consider
using L<File::Transaction::Atomic> instead.

=head1 CONSTRUCTORS

=over

=item new ( [TMPEXT] )

Creates a new empty C<File::Transaction> object.

The TMPEXT parameter gives the string to append to a filename to make
a temporary filename for the new version.  The default is C<.tmp>.

=cut

sub new {
    my ($pkg, $tmpext) = @_;
    defined $tmpext or $tmpext = '.tmp';

    return bless { FILES => [], TMPEXT => $tmpext }, $pkg;
}

=back

=head1 METHODS

=over

=item linewise_rewrite ( OLDFILE, CALLBACK )

Writes out a new version of the file OLDFILE and adds it to the
transaction, invoking the coderef CALLBACK once for each line of the
file, with the line in C<$_>.  The name of the new file is generated
by appending the TMPEXT passed to new() to OLDFILE, and this file is
overwritten if it already exists.

The callback must not invoke the commit() or revert() methods of the
C<File::Transaction> object that calls it.

This method calls die() on error, without first reverting any other
files in the transaction.

=cut

sub linewise_rewrite {
    my ($self, $oldfile, $callback) = @_;
    my $tmpfile = $oldfile . $self->{TMPEXT};

    my $in  = IO::File->new("<$oldfile");
    my $out = IO::File->new(">$tmpfile") or die "open >$tmpfile: $!";

    $self->addfile($oldfile, $tmpfile);

    local $_;
    while( defined $in and defined ($_ = <$in>) ) {
        &{ $callback }();
        next unless length $_;
        $out->print($_) or die "write to $tmpfile: $!";
    }

    $out->close or die "close >$tmpfile: $!";
}

=item addfile ( OLDFILE, TMPFILE )

Adds an update to a single file to the transaction.  OLDFILE is the
name of the old version of the file, and TMPFILE is the name of the
temporary file to which the new version has been written.

OLDFILE will be replaced with TMPFILE on commit(), and TMPFILE will be
unlinked on revert().  OLDFILE need not exist.

=cut

sub addfile {
    my ($self, $oldfile, $tmpfile) = @_;

    push @{ $self->{FILES} }, { OLD => $oldfile, TMP => $tmpfile };
}

=item revert ()

Deletes any new versions of files that have been created with the
addfile() method so far.   Dies on error.

=cut

sub revert {
    my ($self) = @_;

    foreach my $file (@{ $self->{FILES} }) {
        unlink $file->{TMP} or die "unlink $file->{TMP}: $!";
    }

    $self->{FILES} = [];
}

=item commit ()

Swaps all new versions that have been created so far into place.
Dies on error.

=cut

sub commit {
    my ($self) = @_;

    foreach my $file (@{ $self->{FILES} }) {
        rename $file->{TMP}, $file->{OLD} or die "update $file->{OLD}: $!";
    }

    $self->{FILES} = [];
}

=back

=head1 BUGS

=over

=item *

If a rename fails or the Perl process is interrupted in the commit()
method then some files will be updated but others will not.  See
L<File::Transaction::Atomic> if that's a problem for you.

=back

=head1 SEE ALSO

L<File::Transaction::Atomic>

=head1 AUTHOR

Nick Cleaton E<lt>nick@cleaton.netE<gt>

=head1 COPYRIGHT

Copyright (C) 2002 Nick Cleaton.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

## END INLINED File::Transaction
END_FILE_TRANSACTION

###################################################################

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

###############################################################

    eval 'local $SIG{__DIE__} ; require CGI::NMS::HTMLFilter';
    $@ and $INC{'CGI/NMS/HTMLFilter.pm'} = 1;
    $@ and eval <<'END_CGI_NMS_HTMLFILTER' || die $@;

## BEGIN INLINED CGI::NMS::HTMLFilter
package CGI::NMS::HTMLFilter;
use strict;

require 5.00404;

use vars qw($VERSION);
$VERSION = sprintf '%d.%.2d', (q$revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use CGI::NMS::Charset;

=head1 NAME

CGI::NMS::HTMLFilter - whitelist based HTML filter

=head1 SYNOPSIS

   #
   # A simple way to strip malicious scripting constructs from
   # HTML that comes from an untrusted source:
   #

   use CGI::NMS::HTMLFilter;

   my $filter = CGI::NMS::HTMLFilter->new; 
   my $safe_html = $filter->filter($untrused_html);


   #
   # More advanced usage:
   # 

   use CGI::NMS::Charset;
   use CGI::NMS::HTMLFilter;

   my $charset = CGI::NMS::Charset->new('utf-8');

   my $filter = CGI::NMS::HTMLFilter->new(
      charset        => $charset,
      deny_tags      => ['hr'],
      allow_src      => 1,
      allow_href     => 1,
      allow_a_mailto => 1,
   );

   my $safe_html = $filter->filter($untrusted_html, 'Inline');

=head1 DESCRIPTION

This module provides a way to strip potentially malicious
scripting constucts from a block of HTML that has come from
an untrusted source.  Most harmless markup is allowed through.

It is well suited to filtering blocks of HTML that are to be
interpolated into the body of a page, less so for filtering
entire untrusted HTML documents.

To ensure security, a whitelist of harmless tags is used
rather than a blacklist of dangerous constructs.  By default,
this whitelist includes most commonly used cosmetic tags,
including tables but not including forms.

The filter ensures that there is a matching close tag for
each open tag, and that tags are closed in the proper order.

There is a bias towards XHTML in the output of the filter, but
some commonly used harmless that are illegal in XHTML are
allowed, such as the C<E<lt>nobrE<gt>> tag.

=head1 CONSTRUCTORS

=over

=item new ( OPTIONS )

Creates a new C<CGI::NMS::HTMLFilter> object, bound to a
particular character set and HTML filtering policy.

The OPTIONS are a list of key/value pairs.  The following
options are recognised:

=over

=item C<charset>

If present, the value for this option must be an object of class
C<CGI::NMS::Charset>, bound to the character set of the input data.
The default is C<iso-8859-1>.

=item C<deny_tags>

If present, the value for this option must be an array reference,
and the elements of the array must be the lower case names of HTML
tags.  These tags will be disallowed by the filter even if they
would normally be allowed because they present no cross site
scripting hazard.

=item C<allow_src>

By default, the filter won't allow constructs that cause 
the browser to fetch things automatically, such as C<E<lt>imgE<gt>>
tags and C<background> attributes.  If this option is present and
true then those constructs will be allowed.

=item C<allow_href>

By default, the filter won't allow constructs that cause the 
browser to fetch things if the user clicks on something, such
as the C<href> attribute in C<E<lt>aE<gt>> tags.  Set this option
to a true value to allow this type of construct.

=item C<allow_a_mailto>

By default, the filter won't allow C<mailto> URLs in C<E<lt>aE<gt>>
tags.  Set this option to a true value to allow C<mailto> URLs.

=back

=cut

use vars qw(%_Attributes %_Context %_Auto_deinterleave);

sub new
{
   my ($pkg, %opts) = @_;

   my $charset = $opts{charset} || CGI::NMS::Charset->new('iso-8859-1');

   my $self = {
                ESCAPE  => $charset->escape_html_coderef,
                STRIP   => $charset->strip_nonprint_coderef,
                OPTS    => \%opts,
                TAGS    => { %_Attributes },
              };
                
   if (exists $opts{deny_tags})
   {
      foreach my $deny (@{ $opts{deny_tags} })
      {
         delete $self->{TAGS}{$deny};
      }
   }

   delete $self->{TAGS}{img} unless $opts{allow_src};

   return bless $self, $pkg;
}

=back

=head1 METHODS

=over

=item filter ( INPUT [,CONTEXT] )

Applies the filter to the HTML string INPUT, and returns the
resulting string.  Any tags that the filter isn't configured
to pass will be removed, and any HTML metacharacters that
don't form part of acceptable tags or entities will be escaped.

The optional CONTEXT parameter can be used to limit the
allowed tags to a subset of the tags the that filter is
configured to pass.  A CONTEXT value of 'Inline' disallows
block level tags such as lists, paragraphs and tables.  A
CONTEXT value of 'Notags' dissallows all tags.  The default
CONTEXT of 'Flow' allows all tags that the filter is
configured to pass.

=cut

sub filter
{
   my ($self, $input, $context) = @_;

   $input = &{ $self->{STRIP} }($input);

   #
   # We maintain a stack of open tags, so that we can ensure
   # that all opened tags are closed and misplaced closing
   # tags are discarded.
   #
   # The items on this stack are hashrefs, with a NAME key
   # holding the name of the tag, a FULL key holding the full
   # text of the filtered tag (including anglebrackets) and
   # a CTX key holding the context that the tag provides.
   # 
   # The stack starts off holding a single fake tag, needed
   # to define the top level context.
   #
   $self->{STACK} = [{
                      NAME => '',
                      FULL => '',
                      CTX  => $context || 'Flow',
                    }];

   $input =~
    s[
      # An HTML comment - remove it
      (?: <!--.*?-->                                   ) |

      # Some sort of XML or DOCTYPE header - remove it
      (?: <[?!].*?>                                    ) |

      # An HTML tag.  $1 gets the name of the tag, $2
      # gets any other text up to the closing '>'
      (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |

      # A closing tag.  $3 gets the tag name.
      (?: </([a-z0-9]+)>                               ) |

      # $4 gets some non-tag text.  We eat '<' only if
      # it's the first character, since a '<' as the
      # first character can't be the start of a well
      # formed tag or one of the patterns above would
      # have matched.
      (?: (.[^<]*)                                     )

    ][
      defined $1 ? $self->_filter_tag(lc $1, $2)       :
      defined $3 ? $self->_filter_close(lc $3)         :
      defined $4 ? $self->_filter_cdata($4)            :
      ' '
    ]igesx;

   # Ditch the fake tag that sets top level context, then use the
   # stack to close any tag that was left open.
   pop @{ $self->{STACK} };
   $input .= join '', map "</$_->{NAME}>", @{ $self->{STACK} };

   return $input;
}

=back

=head1 PRIVATE METHODS

=over

=item _filter_tag ( TAG, ATTRS )

Deals with a single HTML tag encountered in the filter's input.  The
TAG argument is the lower case tag name, and ATTRS is any text that
was found between the tag name and the E<gt> character that ends the
tag.

Returns the string that should replace this tag in the filter output.

=cut

sub _filter_tag
{
   my ($self, $tag, $attrs) = @_;

   return ' ' unless exists $self->{TAGS}{$tag};

   if ($tag eq 'a')
   {
      # special case: nested <a> is never allowed.
      foreach my $tag (@{ $self->{STACK} })
      {
         return ' ' if $tag->{NAME} eq 'a';
      }
   }

   my $pre_close = '';
   return ' ' unless $self->_close_until_ok($tag, \$pre_close);

   my $t = $self->{TAGS}{$tag};
   my $safe_attrs = '';
   while ($attrs =~ s#^\s*(\w+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?##)
   {
      my $attr = lc $1;
      my $val = ( defined $2 ? $2                        :
                  defined $3 ? $self->_unescape_html($3) :
                  defined $4 ? $self->_unescape_html($4) :
                  ''
                );

      next unless exists $t->{$attr};

      my $cleaned = &{ $t->{$attr} }($val, $attr, $tag, $self);
      if (defined $cleaned)
      {
         my $escaped = &{ $self->{ESCAPE} }($cleaned);
         $safe_attrs .= qq| $attr="$escaped"|;
      }
   }

   my $new_context = $_Context{ $self->{STACK}[0]{CTX} }{ $tag };
   if ($new_context eq 'EMPTY')
   {
      return "$pre_close<$tag$safe_attrs />";
   }
   else
   {
      my $html = "<$tag$safe_attrs>";
      unshift @{ $self->{STACK} }, {
                                     NAME => $tag,
                                     FULL => $html,
                                     CTX  => $new_context
                                   };
      return "$pre_close$html";
   }
}

=item _close_until_ok( TAGNAME, OUTPUT )

If the tag TAGNAME is allowed in the current context or in
any context above, close tags until we reach a context where
TAGNAME is allowed and return true.  Otherwise return false.

OUTPUT is a scalar ref to which the text of any closing tags
generated will be appended.

=cut

sub _close_until_ok
{
   my ($self, $tag, $output) = @_;

   return 0 unless grep {exists $_Context{ $_->{CTX} }{$tag}} @{ $self->{STACK} };

   until (exists $_Context{ $self->{STACK}[0]{CTX} }{$tag})
   {
      $$output .= "</$self->{STACK}[0]{NAME}>";
      shift @{ $self->{STACK} };
      die 'tag stack underflow' unless scalar @{ $self->{STACK} };
   }
}

=item _filter_close ( TAG )

Deals with a single HTML closing tag encountered in the filter's input.
The TAG argument is the lowercase name of the closing tag.

Returns the string that should replace this closing tag in the filter
output.

=cut

sub _filter_close
{
   my ($self, $tag) = @_;

   # Ignore a close without an open
   return ' ' unless grep {$_->{NAME} eq $tag} @{ $self->{STACK} };

   # Close open tags up to the matching open
   my @close = ();
   while (scalar @{ $self->{STACK} } and $self->{STACK}[0]{NAME} ne $tag)
   {
      push @close, shift @{ $self->{STACK} };
   }
   push @close, shift @{ $self->{STACK} };

   my $html = join '', map {"</$_->{NAME}>"} @close;

   # Reopen any we closed early if all that were closed are
   # configured to be auto deinterleaved.
   unless (grep {! exists $_Auto_deinterleave{$_->{NAME}} } @close)
   {
      pop @close;
      $html .= join '', map {$_->{FULL}} reverse @close;
      unshift @{ $self->{STACK} }, @close;
   }

   return $html;
}

=item _filter_cdata ( CDATA )

Deals with a block of CDATA (i.e. text without opening or closing tags)
encountered in the filter's input.  Well-formed HTML entities such as
C<&amp;> pass through unaltered - other than that all HTML metacharacters
are escaped.

Returns the string that should replace this block of CDATA in the
filter output.

=cut

sub _filter_cdata
{
   my ($self, $cdata) = @_;

   # Discard the CDATA if it's somewhere that CDATA shouldn't be, 
   # like <table>hello</table>
   return ' ' if $cdata =~ /\S/ and not $_Context{ $self->{STACK}[0]{CTX} }{CDATA};

   $cdata =~ 
    s[ (?: & ( [a-zA-Z0-9]{2,15}       |
               [#][0-9]{2,6}           |
               [#][xX][a-fA-F0-9]{2,6}
             )
           ;
       ) | (.[^&]*)
    ][
       defined $1 ? "&$1;" : &{ $self->{ESCAPE} }($2)
    ]gesx;

  return $cdata;
}

=item _unescape_html ( STRING )

This method is applied to attribute values found between pairs of
doublequotes or singlequotes before processing them.  It returns
a copy of STRING with all entity encodings of C<us-ascii> characters
replaced with the characters they represent.

=cut

use vars qw(%_unescape_map);
%_unescape_map = ( 
                   ( map { ("\&\#$_\;" => chr($_)) } (1..255) ),
                   '&amp;'  => '&',
                   '&lt;'   => '<',
                   '&gt;'   => '>',
                   '&quot;' => '"',
                   '&apos;' => "'",
                 );

sub _unescape_html
{
   my ($self, $string) = @_;

   $string =~ s/(&[\w\#]{1,4};)/ $_unescape_map{$1} || $1 /ge;
   return &{ $self->{STRIP} }($string);
}

=back

=head1 METHODS TO OVERRIDE

Subclasses can replace these methods to alter the filter's
behavior.

=over

=item url_is_valid ( URL )

Returns true if the string URL holds a valid URL for an image
source or a link target, false otherwise.

Mailto URLs are handled separately and should not be recognized
by this method.

=cut

sub url_is_valid
{
   my ($self, $url) = @_;

   $url =~ m< ^ https? :// [\w\-\.]{1,100} (?:\:\d+)?
                (?: / [\w\-.!~*|;/?\@&=+\$,%#]{0,100} )?
              $
            >x ? 1 : 0;
}

=back

=head1 PRIVATE DATA STRUCTURES

These read-only data structures are used to initialise the policy
data.

=over

=item C<%_Context>

A hash by context name of hashes by tag name, specifying the set of
tags that are allowed in each context.  The values in the per-tag
subhashes are context names, giving the context that the tag
provides to other tags nested within it.

The context names are strings such as C<Inline> or C<Flow>, mostly
taken from the XHTML1 transitional DTD, see
C<http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd>.  The
string C<EMPTY> as a context is used for tags such as C<E<lt>imgE<gt>>,
which have no nested content or corresponding C<E<lt>/imgE<gt>> tag.

=cut

my %pre_content = (
  'br'      => 'EMPTY',
  'span'    => 'Inline',
  'tt'      => 'Inline',
  'i'       => 'Inline',
  'b'       => 'Inline',
  'u'       => 'Inline',
  's'       => 'Inline',
  'strike'  => 'Inline',
  'em'      => 'Inline',
  'strong'  => 'Inline',
  'dfn'     => 'Inline',
  'code'    => 'Inline',
  'q'       => 'Inline',
  'samp'    => 'Inline',
  'kbd'     => 'Inline',
  'var'     => 'Inline',
  'cite'    => 'Inline',
  'abbr'    => 'Inline',
  'acronym' => 'Inline',
  'ins'     => 'Inline',
  'del'     => 'Inline',
  'a'       => 'Inline',
  'CDATA'   => 'CDATA',
);

my %inline = (
  %pre_content,
  'img'   => 'EMPTY',
  'big'   => 'Inline',
  'small' => 'Inline',
  'sub'   => 'Inline',
  'sup'   => 'Inline',
  'font'  => 'Inline',
  'nobr'  => 'Inline',
);
  
my %flow = (
  %inline,
  'ins'        => 'Flow',
  'del'        => 'Flow',
  'div'        => 'Flow',
  'p'          => 'Inline',
  'h1'         => 'Inline',
  'h2'         => 'Inline',
  'h3'         => 'Inline',
  'h4'         => 'Inline',
  'h5'         => 'Inline',
  'h6'         => 'Inline',
  'ul'         => 'list',
  'ol'         => 'list',
  'menu'       => 'list',
  'dir'        => 'list',
  'dl'         => 'dt_dd',
  'address'    => 'Inline',
  'hr'         => 'EMPTY',
  'pre'        => 'pre.content',
  'blockquote' => 'Flow',
  'center'     => 'Flow',
  'table'      => 'table',
);

my %table = (
  'caption'  => 'Inline',
  'thead'    => 'tr_only',
  'tfoot'    => 'tr_only',
  'tbody'    => 'tr_only',
  'colgroup' => 'colgroup',
  'col'      => 'EMPTY',
  'tr'       => 'th_td',
);

%_Context = (
  'Inline'      => \%inline,
  'Flow'        => \%flow,
  'Notags'      => { 'CDATA' => 'CDATA' },
  'pre.content' => \%pre_content,
  'table'       => \%table,
  'list'        => { 'li' => 'Flow' },
  'dt_dd'       => { 'dt' => 'Inline', 'dd' => 'Flow' },
  'tr_only'     => { 'tr' => 'th_td' },
  'colgroup'    => { 'col' => 'EMPTY' },
  'th_td'       => { 'th' => 'Flow', 'td' => 'Flow' },
);

=item C<%_Auto_deinterleave>

A hash by tag name with true values for tags that should be
automatically untangled when encountered interleaved.  For
example, both C<E<lt>iE<gt>> and C<E<lt>bE<gt>> are in the
C<%_Auto_deinterleave> hash, so this:

    normal<i>italic<b>bold-italic</i>bold</b>normal

will be converted by the filter into this:

    normal<i>italic<b>bold-italic</b></i><b>bold</b>normal

=cut

%_Auto_deinterleave = map {$_ => 1} qw(

  tt i b big small u s strike font em strong dfn code
  q sub sup samp kbd var cite abbr acronym span

);

=item C<%_Attributes>

A hash by tag name of hashes by attribute name.  A tag is permitted
only if it appears in this hash, and a tag may have a particular
attribute only if the attribute appears in that tag's subhash.

The values in the attribute subhashes are coderefs to attribute
handler subs.  Whenever the filter encounters a permitted attribute,
it will invoke the corresponding attribute handler sub with the
following arguments:

=over

=item C<$_[0]>

The decoded attribute value.

=item C<$_[1]>

The lowercase attribute name.

=item C<$_[2]>

The lowercase tag name

=item C<$_[3]>

A reference to the C<CGI::NMS::HTMLFilter> object.

=back

The attribute handler may return either C<undef> (to delete this
attribute from the tag) or a new value for the attribute as a
string.  The attribute handler should not escape HTML
metacharacters in the returned value.

=cut

my %attr = ( 'style' => \&_attr_style );

my %font_attr = (
  %attr,
  'size'  => sub { $_[0] =~ /^([-+]?\d{1,3})$/    ? $1 : undef },
  'face'  => sub { $_[0] =~ /^([\w\-, ]{2,100})$/ ? $1 : undef },
  'color' => \&_attr_color,
);

my %insdel_attr = (
  %attr,
  'cite'     => \&_attr_uri,
  'datetime' => \&_attr_text,
);

my %texta_attr = (
  %attr,
  'align' => sub {
                   $_[0] =~ s/middle/center/i;
                   $_[0] =~ /^(left|center|right)$/i ? lc $1 : undef;
                 },
);

my %cellha_attr = (
  'align'    => sub {
                      $_[0] =~ s/middle/center/i;
                      $_[0] =~ /^(left|center|right|justify|char)$/i ? lc $1 : undef;
                    },
  'char'     => sub { $_[0] =~ /^([\w\-])$/ ? $1 : undef },
  'charoff'  => \&_attr_length,
);

my %cellva_attr = (
  'valign' => sub {
                    $_[0] =~ s/center/middle/i;
                    $_[0] =~ /^(top|middle|bottom|baseline)$/i ? lc $1 : undef;
                  },
);

my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );

my %col_attr = (
  %attr, %cellhv_attr,
  'width' => sub { $_[0] =~ /^(\d+(?:\.\d+)?[*%]?)$/ ? $1 : undef },
  'span'  => \&_attr_number,
);

my %thtd_attr = (
  %attr,
  'abbr'    => \&_attr_text,
  'axis'    => \&_attr_text,
  'headers' => \&_attr_text,
  'scope'   => sub { $_[0] =~ /^(row|col|rowgroup|colgroup)$/i ? lc $1 : undef },
  'rowspan' => \&_attr_number,
  'colspan' => \&_attr_number,
  %cellhv_attr,
  'nowrap'  => sub {'nowrap'},
  'bgcolor' => \&_attr_color,
  'width'   => \&_attr_number,
  'height'  => \&_attr_number,
);

%_Attributes = (

  'br'         => { 
                    'clear' => sub { $_[0] =~ /^(left|right|all|none)$/i ? lc $1 : undef }
                  },
  'em'         => \%attr,
  'strong'     => \%attr,
  'dfn'        => \%attr,
  'code'       => \%attr,
  'samp'       => \%attr,
  'kbd'        => \%attr,
  'var'        => \%attr,
  'cite'       => \%attr,
  'abbr'       => \%attr,
  'acronym'    => \%attr,
  'q'          => { %attr, 'cite' => \&_attr_href },
  'blockquote' => { %attr, 'cite' => \&_attr_href },
  'sub'        => \%attr,
  'sup'        => \%attr,
  'tt'         => \%attr,
  'i'          => \%attr,
  'b'          => \%attr,
  'big'        => \%attr,
  'small'      => \%attr,
  'u'          => \%attr,
  's'          => \%attr,
  'strike'     => \%attr,
  'font'       => \%font_attr,
  'table'      => { %attr,
                    'frame'       => \&_attr_tframe,
                    'rules'       => \&_attr_trules,
                    %texta_attr,
                    'bgcolor'     => \&_attr_color,
                    'width'       => \&_attr_length,
                    'cellspacing' => \&_attr_length,
                    'cellpadding' => \&_attr_length,
                    'border'      => \&_attr_number,
                    'summary'     => \&_attr_text,
                  },
  'caption'    => { %attr,
                    'align' => sub { $_[0] =~ /^(top|bottom|left|right)$/i ? lc $1 : undef },
                  },
  'colgroup'   => \%col_attr,
  'col'        => \%col_attr,
  'thead'      => \%cellhv_attr,
  'tfoot'      => \%cellhv_attr,
  'tbody'      => \%cellhv_attr,
  'tr'         => { %attr,
                    bgcolor => \&_attr_color,
                    %cellhv_attr,
                  },
  'th'         => \%thtd_attr,
  'td'         => \%thtd_attr,
  'ins'        => \%insdel_attr,
  'del'        => \%insdel_attr,
  'a'          => { %attr,
                    href => \&_attr_a_href,
                  },
  'h1'         => \%texta_attr,
  'h2'         => \%texta_attr,
  'h3'         => \%texta_attr,
  'h4'         => \%texta_attr,
  'h5'         => \%texta_attr,
  'h6'         => \%texta_attr,
  'p'          => \%texta_attr,
  'div'        => \%texta_attr,
  'span'       => \%texta_attr,
  'ul'         => { %attr,
                    'type'    => sub { $_[0] =~ /^(disc|square|circle)$/i ? lc $1 : undef },
                    'compact' => sub {'compact'},
                  },
  'ol'         => { %attr,
                    'type'    => \&_attr_text,
                    'compact' => sub {'compact'},
                    'start'   => \&_attr_number,
                  },
  'li'         => { %attr,
                    'type'  => \&_attr_text,
                    'value' => \&_no_number,
                  },
  'dl'         => { %attr, 'compact' => sub {'compact'} },
  'dt'         => \%attr,
  'dd'         => \%attr,
  'address'    => \%attr,
  'hr'         => { %texta_attr,
                    'width'   => \&_attr_length,
                    'size '   => \&_attr_number,
                    'noshade' => sub {'noshade'},
                  },
  'pre'        => { %attr, 'width' => \&_attr_number },
  'center'     => \%attr,
  'nobr'       => {},
  'img'        => { 'src'    => \&_attr_src,
                    'alt'    => \&_attr_text,
                    'width'  => \&_attr_length,
                    'height' => \&_attr_length,
                    'border' => \&_attr_length,
                    'hspace' => \&_attr_number,
                    'vspace' => \&_attr_number,
                    'align'  => sub {
                                      $_[0] =~ s/center/middle/i;
                                      $_[0] =~ /^(top|middle|bottom|left|right)$/i ? lc $1 : undef;
                                    },
                  },
);

=back

=head1 ATTRIBUTE HANDLER SUBS

Some of the more complex attribute handler subs used in the
C<%_Attributes> hash are named subs rather than anonymous coderefs.

=over

=item _attr_style ( INPUT, ATTRNAME, TAGNAME, FILTER )

Handles the C<style> attribute.

=cut 

use vars qw(%_safe_style);
%_safe_style = (
  'color'            => \&_attr_color,
  'background-color' => \&_attr_color,
);

sub _attr_style
{
   my @clean = ();

   foreach my $elt (split /;/, $_[0])
   {
      next if $elt =~ m#^\s*$#;
      if ( $elt =~ m#^\s*([\w\-]+)\s*:\s*(.+?)\s*$#s )
      {
         my ($key, $val) = (lc $1, $2);
         my $sub = $_safe_style{$key};
         if (defined $sub)
         {
            my $cleanval = &{$sub}($val, $key, 'style-psuedo-attr', $_[3]);
            if (defined $cleanval)
            {
               push @clean, "$key:$val";
            }
         }
      }
   }

   return join '; ', @clean;
}

=item _attr_src ( INPUT, ATTRNAME, TAGNAME, FILTER )

A hander for attributes that cause an implicit fetch of an image, such
as C<img src>.

=cut

sub _attr_src
{
   my $filter = $_[3];

   ($filter->{OPTS}{allow_src} and $filter->url_is_valid($_[0])) ? $_[0] : undef;
}
   
=item _attr_a_href ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<href> attribute in the C<a> tag, allowing C<mailto>
URLs if the filter is so configured.

=cut

sub _attr_a_href
{ 

   if ($_[0] =~ /^mailto:([\w\-\.\,\=\*]{1,100}\@[\w\-\.]{1,100})$/i)
   {
      my $filter = $_[3];
      return ($filter->{OPTS}{allow_a_mailto} ? "mailto:$1" : undef);
   }
   else
   {
      return _attr_href(@_);
   }
}

=item _attr_href ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes that offer a link to the user, such as C<a href>.

=cut

sub _attr_href
{
   my $filter = $_[3];

   ($filter->{OPTS}{allow_href} and $filter->url_is_valid($_[0])) ? $_[0] : undef; 
}
   
=item _attr_number ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes who's value should be a positive integer

=cut

sub _attr_number { $_[0] =~ /^(\d{1,10})$/ ? $1 : undef }

=item _attr_length ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes who's value should be a positive integer
or a percentage.

=cut

sub _attr_length { $_[0] =~ /^(\d{1,10}\%?)$/ ? $1 : undef }

=item _attr_text (INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for a text attribute such as C<img alt>.  Pretty much
wide open since the striping of non-printables is handled by the
filter itself.

=cut

sub _attr_text
{
   $_[0] =~ s#\s+# #g;
   length $_[0] <= 200 ? $_[0] : undef;
}

=item _attr_color ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for a color attribute

=cut

sub _attr_color { $_[0] =~ /^(\w{2,20}|#[\da-fA-F]{6})$/ ? $1 : undef }

=item _attr_tframe ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<table frame> attribute

=cut

sub _attr_tframe
{
  $_[0] =~ /^(void|above|below|hsides|lhs|rhs|vsides|box|border)$/i ? lc $1 : undef;
}

=item _attr_trules ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<table rules> attribute

=cut

sub _attr_trules { $_[0] =~ /^(none|groups|rows|cols|all)$/i ? lc $1 : undef }

=back

=head1 SEE ALSO

L<CGI::NMS::Charset>, C<http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd>

=head1 AUTHORS

The NMS project, E<lt>nms-cgi-devel@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

## END INLINED CGI::NMS::HTMLFilter
END_CGI_NMS_HTMLFILTER

    unless ( eval { local $SIG{__DIE__}; require NMS::IPFilter } )
    {
        eval <<'END_INLINED_NMS_IPFilter' or die $@;
package CGI::NMS::IPFilter;
use strict;
                                                                               
require 5.00404;
                                                                               
use Socket;
require Exporter;
use vars qw($VERSION @ISA @EXPORT);

@ISA = qw(Exporter);

$VERSION = '0.1';
                                                                               

@EXPORT = qw(ip_in_network rbl_check);

=item cidr_calc

Given an integer between 1 and 32 (which is assumed to have been extracted
from a CIDR network description) will return the number of IP addresses in
the block.

=cut 

sub cidr_calc
{
   my ( $block) = @_;

   my $ips_in_block = (2 ** (32 - $block)  ) ;
   return $ips_in_block;
}

=item add_number_to_ip

Given an IP in dotted decimal notation and a number (assumed to be a block
size derived from a CIDR) will return the IP address at the top of the
notional block of IP addresses.

=cut

sub add_number_to_ip
{
   my ($ip,$number ) = @_;
   my $ip_i = ip_to_int($ip);
   $ip_i += $number;
   return inet_ntoa(pack('N', $ip_i));
}

=item ip_to_int

When passed an IP in dotted decimal notation will return an integer that
this address represents.

=cut

sub ip_to_int
{
   my ( $ip ) = @_;
   my $ip_n = inet_aton($ip);
   my $ip_i = unpack('N', $ip_n);
   return $ip_i
}

=item ip_in_network ( IP, NETWORK )

Will determine whether IP is in the CIDR network NETWORK. A NETWORK without
a /n suffix is assumed to be a /32 and the IP is compared directly. Returns
a true value if IP is within NETWORK.

=cut

sub ip_in_network
{
   my ( $ip, $network ) = @_;
   my $rc = 0;

   my $ip_n = ip_to_int($ip);

   my ($lower, $upper ) = network_bounds_int($network);

   if ( $lower <= $ip_n and $ip_n <= $upper )
   {
      $rc = 1;
   }

   return $rc;
}

=item network_bounds_int(NETWORK)

NETWORK is an IP network description in CIDR format ( nnn.nnn.nnn.nnn/n ).
The return values are the lower and upper bounds of the network represented
as integers for easy comparision.  A single IP without a /n is special cased
and will return the integer value of that IP as both upper and lower values.

=cut

sub network_bounds_int
{
   my ( $network ) = @_;

   my ( $lower, $upper );

   if ( $network =~ m%^([^/]+)/(\d+)% )
   {
      $lower = ip_to_int($1);
      $upper = ip_to_int($1) + cidr_calc($2);
   }
   else
   {
      $lower = $upper = ip_to_int($network);
   }

   return ($lower, $upper );
}

=item rbl_check (IP, ZONE )

This performs a dns block list lookup of the supplied IP in the specified
zone, returning false if there is an entry listed and true otherwise.
It can block for a long time if the SOA for the supplied zone is busy or
unavailable.  It is only really useful if the DNSBL zone provided is one
that lists open HTTP proxies and know exploited machines that may be used
by spammers or crackers.  

=cut

=for developers

This has only been tested against a local DNSBL which I can put my own
IP in, so it could probably be tested more thoroughly against a real
DNSBL using some known proxies.

=cut

sub rbl_check 
{
    my ( $ip, $zone ) = @_;

    my $rc = 1;
    if ( $ip =~ /(\d+)\.(\d+).(\d+)\.(\d+)/ ) {
        my $query = "$4.$3.$2.$1.$zone.";
        my $res   = gethostbyname($query);
        if ( defined $res ) {
            $rc = 0;
        }
    }

    return $rc;
}

1;

END_INLINED_NMS_IPFilter
        $INC{'NMS/IPFilter.pm'} = 1;
    }

}

