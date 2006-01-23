#!/usr/bin/perl -wT
#
# $Id: guestbook.pl,v 1.51 2006-01-23 16:18:12 gellyfish Exp $
#

use strict;
use POSIX qw(locale_h strftime);
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use IO::File;


use vars qw(
  $DEBUGGING $done_headers @debug_msg $guestbookurl
  $guestbookreal $guestlog $cgiurl
  $style $mail $uselog $linkmail $linkname $separator $redirection
  $entry_order $remote_mail $allow_html $line_breaks $postmaster
  $mailprog $recipient $short_date_fmt $long_date_fmt $locale $timezone
  $hide_new_comments $bannednets @use_rbls
);

# sanitize the environment

delete @ENV{qw(ENV BASH_ENV IFS PATH)};

# Configuration

#
# $DEBUGGING must be set in a BEGIN block in order to have it be set before
# the program is fully compiled.
# This should almost certainly be set to 0 when the program is 'live'
#

BEGIN
{
    $DEBUGGING = 1;

    $guestbookurl  = 'http://www.domain.com/guestbook/guestbook.html';
    $guestbookreal = '/your/real/path/guestbook/guestbook.html';
    $guestlog      = '/your/real/path/guestbook/guestlog.html';
    $cgiurl        = 'http://www.domain.com/cgi-bin/guestbook.pl';

    # $style is the URL of a CSS stylesheet which will be used for script
    # generated messages.  This probably want's to be the same as the one
    # that you use for all the other pages.  This should be a local absolute
    # URI fragment.

    $style = '/css/nms.css';

    $mail        = 0;
    $uselog      = 1;
    $linkmail    = 1;
    $linkname    = 1;
    $separator   = 1;
    $redirection = 0;
    $entry_order = 1;
    $remote_mail = 0;
    $allow_html  = 0;
    $line_breaks = 0;

    # $mailprog is the program that will be used to send mail if that is
    # required.  It should be the full path of a program that will accept
    # the message on its standard input, it should also include any required
    # switches.  If $mail is set to 0 above then this can be ignored.

    $mailprog = '/usr/lib/sendmail -t -oi -oem';

    # $recipient is the address of the person who should be mailed if $mail is
    # set to 1 above.

    $recipient = 'you@your.com';

    # $postmaster is the envelope sender to use for all outgoing emails.
    # If in doubt, put your own email address here.

    $postmaster = '';

    # $timezone is the timezone which you want the times to show as
    # if you are happy with the current timezone it should be left as '';

    $timezone = '';

    # $long_date_fmt and $short_date_fmt describe the format of the dates that
    # will output 

    $long_date_fmt  = '%A, %B %d, %Y at %T (%Z)';
    $short_date_fmt = '%d/%m/%y %T %Z';

    $locale = '';

    # If set to 1 then new comments will be commented out and
    # should be uncommented with the guestbook-admin.pl tool

    $hide_new_comments = 1;

    # $bannednets should be the full path to a file containing
    # banned IP addresses or networks
    # 
    $bannednets        = '';

    # @use_rbls is a list of DNSBLs to use to block access
    
    @use_rbls          = qw();
    
    # End configuration

    if ( $mailprog =~ /^SMTP:/i )
    {
        require IO::Socket;
        import IO::Socket;
    }
}

use vars qw($VERSION);
$VERSION = substr q$Revision: 1.51 $, 10, -1;

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

        print "Content-Type: text/html; charset=iso-8859-1\n\n"
          unless $done_headers;

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

use vars qw($style_element);
$style_element = $style
  ? qq%<link rel="stylesheet" type="text/css" href="$style" />%
  : '';

if ($timezone)
{
    $ENV{TZ} = $timezone;
    POSIX::tzset();
}

use vars qw($date $shortdate);
my @now = localtime();

eval { setlocale( LC_TIME, $locale ) if $locale; };

$date      = strftime( $long_date_fmt,  @now );
$shortdate = strftime( $short_date_fmt, @now );

die "Address [$ENV{REMOTE_ADDR}] blocked\n" if ( check_ip($ENV{REMOTE_ADDR}) );

my @input_names = qw(username realname comments city state country url);
use vars qw(%inputs);
foreach my $input (@input_names)
{
    $inputs{$input} = strip_nonprintable( param($input) );
}

# There is a possibility that the comments can be escaped if passed as
# the hidden field from the form_error() form
if ( param('encoded_comments') )
{
    $inputs{comments} = unescape_html( $inputs{comments} );
}

$inputs{'url'} = '' unless check_url_valid( $inputs{'url'} );
$inputs{username} = '' unless check_email( $inputs{username} );

# Strip out HTML unless we are allowing it.  The process_html
# sub should take care of everything.
use vars qw($comments);
$comments = process_html( $inputs{comments}, $line_breaks, $allow_html );

# Generate versions of the inputs with HTML metacharacters
# escaped - HTML should not be allowed anywhere but the
# comment.
use vars qw(%escaped);
%escaped = map { $_ => escape_html( $inputs{$_} ) } keys %inputs;

form_error('no_comments') unless $inputs{comments};
form_error('no_name')     unless $inputs{realname};

rewrite_file(
    $guestbookreal,
    sub {
        if ( defined and /<!--begin-->/ )
        {

            $_ = '' unless $entry_order;
            $_ .= "<!-- comment start -->\n";
            $_ .= "<!-- comment hidden\n" if $hide_new_comments;
            $_ .= qq%<div class="comments">\n%;
            $_ .= "<b>$comments</b><br />\n";

            if ( $linkname and $inputs{'url'} )
            {
                $_ .= qq(<a href="$escaped{'url'}">$escaped{realname}</a>);
            }
            else
            {
                $_ .= $escaped{realname};
            }

            if ( $inputs{username} )
            {
                if ($linkmail)
                {
                    $_ .= qq( &lt;<a href="mailto:$escaped{username}">);
                    $_ .= "$escaped{username}</a>&gt;";
                }
                else
                {
                    $_ .= " &lt;$escaped{username}&gt;";
                }
            }

            $_ .= "<br />\n";

            if ( $inputs{city} )
            {
                $_ .= "$escaped{city}, ";
            }

            if ( $inputs{state} )
            {
                $_ .= $escaped{state};
            }

            if ( $inputs{country} )
            {
                $_ .= " $escaped{country}";
            }

            $_ .= "</div>\n";

            if ($separator)
            {
                $_ .= " - $date<hr />\n\n";
            }
            else
            {
                $_ .= " - $date<p />\n\n";
            }

            $_ .= "-->\n" if $hide_new_comments;
            $_ .= "\n<!-- comment end -->\n";

            $_ .= "<!--begin-->\n" unless $entry_order;
        }
    }
);

chmod 0755, $guestbookreal;

write_log('entry') if $uselog;

my $mailsafe_username =
  ( check_email( $inputs{username} ) ? $inputs{username} : '' );
my $mailsafe_realname = cleanup_realname( $inputs{realname} );

if ($mail)
{
    my $to      = $recipient;
    my $from    = "$mailsafe_username ($mailsafe_realname)";
    my $reply   = "$mailsafe_username ($mailsafe_realname)";
    my $subject = 'Entry to Guestbook';
    my $body    = 'You have a new entry in your guestbook:';
    do_mail( $to, $from, $reply, $subject, $body );
}

if ( $remote_mail && $mailsafe_username )
{

    my $to      = $mailsafe_username;
    my $from    = $recipient;
    my $reply   = $recipient;
    my $subject = 'Entry to Guestbook';
    my $body    = 'Thank you for adding to my guestbook.';
    do_mail( $to, $from, $reply, $subject, $body );
}

# Print Out Initial Output Location Heading
if ($redirection)
{
    print redirect($guestbookurl);
}
else
{
    no_redirection();
}

sub form_error
{

    my ($why) = @_;

    my ( $title, $heading, $text, $comments_field );

    if ( $why eq 'no_name' )
    {
        $inputs{realname}  = '';
        $escaped{realname} = '';
        $title             = 'No Name';
        $heading           = 'Your Name appears to be blank';
        $text              = <<EOTEXT;
The Name Section in the guestbook fillout form appears to
be blank and therefore your entry to the guestbook was not
added.  Please add your name in the blank below.
EOTEXT
        $comments_field = <<EOCOMMENT;
    Comments have been retained.
        <input type="hidden" name="comments" value="$escaped{comments}" />
        <input type="hidden" name="comments_encoded" value="1" />
EOCOMMENT
    }
    elsif ( $why eq 'no_comments' )
    {
        $title   = 'No Comments';
        $heading = 'Your Comments appear to be blank';
        $text    = <<EOTEXT;
The comment section in the guestbook fillout form appears
to be blank and therefore the Guestbook Addition was not
added.  Please enter your comments below.
EOTEXT
        $comments_field = <<EOCOMMENT;
    Comments:<br />
    <textarea name="comments" cols="60" rows="4"></textarea>
EOCOMMENT
    }
    else
    {
        $title          = 'Unknown Error';
        $heading        = 'Something appears to be wrong with your submission';
        $text           = 'Please check your input and resubmit';
        $comments_field = <<EOCOMMENT;
    Comments:<br />
    <textarea name="comments" cols="60" rows="4">$escaped{comments}</textarea />
    <input type="hidden" name="comments_encoded" value="1" />
EOCOMMENT
    }

    print "Content-Type: text/html; charset=iso-8859-1\n\n";
    $done_headers++;
    print <<END_FORM;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>$title</title>
    $style_element
  </head>
  <body>
    <h1>$heading</h1>
    <p>
      $text
    </p>
    <form method="post" action="$cgiurl">
      <p>Your Name: <input type="text" name="realname"
                           value="$escaped{realname}" size="30" /><br />
        E-Mail: <input type="text" name="username"
                       value="$escaped{username}" size="40" /><br />
        City: <input type="text" name="city" value="$escaped{city}"
                     size="15" />,
        State: <input type="text" name="state"
                      value="$escaped{state}" size="2" />
        Country: <input type="text" name="country" value="$escaped{country}"
                        size="15" /></p>
      <p>
       $comments_field
      </p>
      <p><input type="submit" /> * <input type="reset" /></p>
    </form>
    <hr />
    <p>Return to the <a href="$guestbookurl">Guestbook</a></p>.
  </body>
</html>

END_FORM

    # Log The Error

    write_log($why) if $uselog;

    exit;
}

# Log the Entry or Error
sub write_log
{
    my ($log_type) = @_;

    my $found_close_body = 0;

    rewrite_file(
        $guestlog,
        sub {
            if ( not defined )
            {

                # Matt's original guestlog.html is missing these close
                # tags, so if we don't find </body> we append them to
                # make guestlog.html into valid XHTML.
                $_ = "</body>\n</html>\n" unless $found_close_body;
            }
            if ( defined and m#</body>#i )
            {
                $found_close_body = 1;
                my $remote = remote_host();
                my $logline;
                if ( $log_type eq 'entry' )
                {
                    $logline = "$remote - [$shortdate]<br />\n";
                }
                elsif ( $log_type eq 'no_name' )
                {
                    $logline = "$remote - [$shortdate] - ERR: No Name<br />\n";
                }
                elsif ( $log_type eq 'no_comments' )
                {
                    $logline =
                      "$remote - [$shortdate] - ERR: No Comments<br />\n";
                }
                $_ = "$logline$_";
            }
        }
    );

}

# Redirection Option
sub no_redirection
{

    print "Content-Type: text/html; charset=iso-8859-1\n\n";
    $done_headers++;
    print <<END_HTML;
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Thank You</title>
    $style_element
  </head>
  <body>
    <h1>Thank You For Signing The Guestbook</h1>

    <p>Thank you for filling in the guestbook.  Your entry has
      been added to the guestbook.</p>
    <hr />
    <p>Here is what you submitted:</p>
    <p><b>$comments</b></p><br />

END_HTML

    if ( $inputs{'url'} )
    {
        print qq(<a href="$escaped{'url'}">$escaped{realname}</a>);
    }
    else
    {
        print $escaped{realname};
    }

    if ( $inputs{username} )
    {
        if ($linkmail)
        {
            print qq( &lt;<a href="mailto:$escaped{username}">);
            print "$escaped{username}</a>&gt;";
        }
        else
        {
            print " &lt;$escaped{username}&gt;";
        }
    }

    print "<br />\n";

    print "$escaped{city}," if $inputs{city};

    print " $escaped{state}" if $inputs{state};

    print " $escaped{country}" if $inputs{country};

    print " - $date\n";

    if ( scalar @debug_msg )
    {
        print qq|<br /><font color="red">\n|;
        print map { escape_html($_) . qq|<br />\n| } @debug_msg;
        print "</font>\n";
    }

    # Print End of HTML
    print <<END_HTML;

    <hr />
    <p><a href="$guestbookurl">Back to the Guestbook</a>
      - You may need to reload it when you get there to see your
      entry.</p>
  </body>
</html>

END_HTML

    exit;
}

sub do_mail
{

    my ( $to, $from, $reply, $subject, $body ) = @_;

    email_start( $postmaster, $to );

    my $addr = remote_addr();
    $addr =~ /^([\d\.]+)$/ or die "bad remote addr [$addr]";
    $addr = $1;

    email_data(<<EOMAIL);
X-HTTP-Client: [$addr]
X-Generated-By: NMS guestbook.pl v$VERSION
To: $to
Reply-to: $reply
From: $from
Subject: $subject

$body
------------------------------------------------------
$comments
$inputs{realname}
EOMAIL

    if ( $inputs{username} )
    {
        email_data(" <$inputs{username}>");
    }

    email_data("\n");

    email_data("$inputs{city}',") if $inputs{city};

    email_data(" $inputs{state}") if $inputs{state};

    email_data(" $inputs{country}") if $inputs{country};

    email_data(<<EOMAIL);
 - $date
------------------------------------------------------
EOMAIL

    email_end();
}

use vars qw($smtp);

sub email_start
{
    my ( $sender, @recipients ) = @_;

    if ( $mailprog =~ /^SMTP:([\w\-\.]+(:\d+)?)$/i )
    {
        my $mailhost = $1;
        $mailhost .= ':25' unless $mailhost =~ /:/;
        $smtp = IO::Socket::INET->new($mailhost);
        defined $smtp or die "SMTP connect to [$mailhost]: $!";

        my $banner = smtp_getline();
        $banner =~ /^2/ or die "bad SMTP banner [$banner] from [$mailhost]";

        my $helohost = ( $ENV{SERVER_NAME} =~ /^([\w\-\.]+)$/ ? $1 : '.' );
        smtp_command("HELO $helohost");
        smtp_command("MAIL FROM: <$sender>");
        foreach my $r (@recipients)
        {
            smtp_command("RCPT TO: <$r>");
        }
        smtp_command( "DATA", '3' );
    }
    else
    {
        my $command = $mailprog;
        $command .= qq{ -f "$postmaster"} if $postmaster;
        my $result;
        eval {
            local $SIG{__DIE__};
            $result = open SENDMAIL, "| $command";
        };
        if ($@)
        {
            die $@ unless $@ =~ /Insecure directory/;
            delete $ENV{PATH};
            $result = open SENDMAIL, "| $command";
        }

        die "Can't open mailprog [$command]\n" unless $result;
    }
}

sub email_data
{
    my ($data) = @_;

    if ( defined $smtp )
    {
        $data =~ s#\n#\015\012#g;
        $data =~ s#^\.#..#mg;
        $smtp->print($data) or die "write to SMTP server: $!";
    }
    else
    {
        print SENDMAIL $data or die "write to sendmail pipe: $!";
    }
}

sub email_end
{
    if ( defined $smtp )
    {
        smtp_command(".");
        smtp_command("QUIT");
        undef $smtp;
    }
    else
    {
        close SENDMAIL
          or die "close sendmail pipe failed, mailprog=[$mailprog]";
    }
}

sub smtp_command
{
    my ( $cmd, $want ) = @_;
    defined $want or $want = '2';

    $smtp->print("$cmd\015\012")
      or die "write [$cmd] to SMTP server: $!";

    my $resp = smtp_getline();
    unless ( substr( $resp, 0, 1 ) eq $want )
    {
        die "SMTP command [$cmd] gave response [$resp]";
    }
}

sub smtp_getline
{
    my $line = <$smtp>;
    defined $line or die "read from SMTP server: $!";
    $line =~ tr#\012\015##d;
    return $line;
}

##############################################################

sub strip_nonprintable
{
    my $text = shift;
    return '' unless defined $text;
    $text =~ tr#\t\n\040-\176\240-\377# #cs;
    return $text;
}


##############################################################
#
# Validity checks for various contexts.
#

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

sub cleanup_realname
{
    my ($realname) = @_;

    return '' unless defined $realname;

    $realname =~ s#\s+# #g;
    $realname =~ tr# a-zA-Z0-9_\-,./'\241-\377# #cs;
    return substr $realname, 0, 128;
}

sub check_email
{
    my ($email) = @_;

    return 0 if $email =~ /^\s*$/;

    return 0 unless $email =~ /^(.+)\@([a-z0-9_\.\-\[\]]+)$/is;
    my ( $user, $host ) = ( $1, $2 );

    return 0 if $host =~ m#^\.|\.\.|\.$#;
    return 0 if $user =~ /[^a-z0-9_\-\.\*\+\=]/i;
    return 0 if length $user > 100;
    return 0 if length $host > 100;

    return 1 if $host =~ /^\[\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\]$/;
    return 1 if $host =~ /^[a-z0-9\-\.]+$/i;

    return 0;
}

=head1 FILE MANIPULATION FUNCTIONS

=over

=item rewrite_file( FILENAME, CALLBACK )

This function makes an atomic chanage to a file, by copying
an old version to a new version line by line and then
renaming the new version over the old version.  An external
lock file is used to prevent clashes between several
processes accessing the file at once.

Dies on error.

FILENAME is the filesystem path to the file.

CALLBACK is a coderef to act on the contents of the file
line by line.  It gets called once for each line in the
file, with the line stored in C<$_>.  Any changes made to
C<$_> will be reflected in the new version of the file.

The CALLBACK coderef will be called one more time after
all the lines have been processed, with C<$_> set to
undef.

=cut

sub rewrite_file
{
    my ( $filename, $callback ) = @_;
    local $_;

    my $lock = IO::File->new(">>$filename.lck") or die "open $filename.lck: $!";
    flock $lock, LOCK_EX or die "flock $filename: $!";

    my $temp = IO::File->new(">$filename.tmp") or die "open >$filename.tmp: $!";

    my $in = IO::File->new("<$filename") or die "open <$filename: $!";

    my $last_line_done = 0;
    until ($last_line_done)
    {
        $last_line_done = not defined( $_ = <$in> );

        &{$callback}();
        if ( defined and length and not $temp->print($_) )
        {
            my $write_err = $!;
            $temp->close;
            unlink "$filename.tmp";
            die "write to $filename.tmp: $write_err";
        }
    }

    unless ( $temp->close )
    {
        my $close_err = $!;
        unlink "$filename.tmp";
        die "close $filename.tmp: $close_err";
    }

    $in->close;

    rename "$filename.tmp", $filename
      or die "rename $filename.tmp -> $filename: $!";

    $lock->close;
}

=back

=cut

##################################################################
#
# HTML handling code
#
# The code below provides some functions for manipulating HTML.
#
#  check_url_valid ( URL )
#
#    Returns 1 if the string URL is a valid http, https or ftp
#    URL, 0 otherwise.
#
#  process_html ( INPUT [,LINE_BREAKS [,ALLOW]] )
#
#    Returns a modified version of the HTML string INPUT, with
#    any potentially malicious HTML constructs (such as java,
#    javascript and IMG tags) removed.
#
#    If the LINE_BREAKS parameter is present and true then
#    line breaks in the input will be converted to html <br />
#    tags in the output.
#
#    If the ALLOW parameter is present and true then most
#    harmless tags will be left in, otherwise all tags will be
#    removed.
#
#  escape_html ( INPUT )
#
#    Returns a copy of the string INPUT with any HTML
#    metacharacters replaced with character escapes.
#
#  unescape_html ( INPUT )
#
#    Returns a copy of the string INPUT with HTML character
#    entities converted to literal characters where possible.
#    Note that some entites have no 8-bit character equivalent,
#    see "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent"
#    for some examples.  unescape_html() leaves these entities
#    in their encoded form.
#

use vars qw(%html_entities $html_safe_chars %escape_html_map);
use vars qw(%safe_tags %safe_style %tag_is_empty $convert_nl
  %auto_deinterleave $auto_deinterleave_pattern);

# check the validity of a URL.

sub check_url_valid
{
    my $url = shift;

    $url =~ m< ^ (?:ftp|http|https):// [\w\-\.]+ (?:\:\d+)?
               (?: / [\w\-.!~*'(|);/?\@&=+\$,%#]* )?
             $
           >x ? 1 : 0;
}

sub process_html
{
    my ( $text, $line_breaks, $allow_html ) = @_;

    cleanup_html( $text, $line_breaks, ( $allow_html ? \%safe_tags : {} ) );
}

BEGIN
{
    %html_entities = (
        'lt'   => '<',
        'gt'   => '>',
        'quot' => '"',
        'amp'  => '&',

        'nbsp'   => "\240",
        'iexcl'  => "\241",
        'cent'   => "\242",
        'pound'  => "\243",
        'curren' => "\244",
        'yen'    => "\245",
        'brvbar' => "\246",
        'sect'   => "\247",
        'uml'    => "\250",
        'copy'   => "\251",
        'ordf'   => "\252",
        'laquo'  => "\253",
        'not'    => "\254",
        'shy'    => "\255",
        'reg'    => "\256",
        'macr'   => "\257",
        'deg'    => "\260",
        'plusmn' => "\261",
        'sup2'   => "\262",
        'sup3'   => "\263",
        'acute'  => "\264",
        'micro'  => "\265",
        'para'   => "\266",
        'middot' => "\267",
        'cedil'  => "\270",
        'supl'   => "\271",
        'ordm'   => "\272",
        'raquo'  => "\273",
        'frac14' => "\274",
        'frac12' => "\275",
        'frac34' => "\276",
        'iquest' => "\277",

        'Agrave' => "\300",
        'Aacute' => "\301",
        'Acirc'  => "\302",
        'Atilde' => "\303",
        'Auml'   => "\304",
        'Aring'  => "\305",
        'AElig'  => "\306",
        'Ccedil' => "\307",
        'Egrave' => "\310",
        'Eacute' => "\311",
        'Ecirc'  => "\312",
        'Euml'   => "\313",
        'Igrave' => "\314",
        'Iacute' => "\315",
        'Icirc'  => "\316",
        'Iuml'   => "\317",
        'ETH'    => "\320",
        'Ntilde' => "\321",
        'Ograve' => "\322",
        'Oacute' => "\323",
        'Ocirc'  => "\324",
        'Otilde' => "\325",
        'Ouml'   => "\326",
        'times'  => "\327",
        'Oslash' => "\330",
        'Ugrave' => "\331",
        'Uacute' => "\332",
        'Ucirc'  => "\333",
        'Uuml'   => "\334",
        'Yacute' => "\335",
        'THORN'  => "\336",
        'szlig'  => "\337",

        'agrave' => "\340",
        'aacute' => "\341",
        'acirc'  => "\342",
        'atilde' => "\343",
        'auml'   => "\344",
        'aring'  => "\345",
        'aelig'  => "\346",
        'ccedil' => "\347",
        'egrave' => "\350",
        'eacute' => "\351",
        'ecirc'  => "\352",
        'euml'   => "\353",
        'igrave' => "\354",
        'iacute' => "\355",
        'icirc'  => "\356",
        'iuml'   => "\357",
        'eth'    => "\360",
        'ntilde' => "\361",
        'ograve' => "\362",
        'oacute' => "\363",
        'ocirc'  => "\364",
        'otilde' => "\365",
        'ouml'   => "\366",
        'divide' => "\367",
        'oslash' => "\370",
        'ugrave' => "\371",
        'uacute' => "\372",
        'ucirc'  => "\373",
        'uuml'   => "\374",
        'yacute' => "\375",
        'thorn'  => "\376",
        'yuml'   => "\377",
    );

    #
    # Build a map for representing characters in HTML.
    #
    $html_safe_chars = '()[]{}/?.,\\|;:@#~=+-_*^%$! ' . "\r\n\t";
    %escape_html_map =
      map { $_, $_ }
      ( 'A' .. 'Z', 'a' .. 'z', '0' .. '9', split( //, $html_safe_chars ) );
    foreach my $ent ( keys %html_entities )
    {
        $escape_html_map{ $html_entities{$ent} } = "&$ent;";
    }
    foreach my $c ( 0 .. 255 )
    {
        unless ( exists $escape_html_map{ chr $c } )
        {
            $escape_html_map{ chr $c } = sprintf '&#%d;', $c;
        }
    }

    #
    # Tables for use by cleanup_html() (below).
    #
    # The main table is %safe_tags, which is a hash by tag name of
    # all the tags that it's safe to leave in.  The value for each
    # tag is another hash, and each key of that hash defines an
    # attribute that the tag is allowed to have.
    #
    # The values in the tag attribute hash can be undef (for an
    # attribute that takes no value, for example the nowrap
    # attribute in the tag <td align="left" nowrap>) or they can
    # be coderefs pointing to subs for cleaning up the attribute
    # values.
    #
    # These subs will called with the attribute value in $_, and
    # they can return either a cleaned attribute value or undef.
    # If undef is returned then the attribute will be deleted
    # from the tag.
    #
    # The list of tags and attributes was taken from
    # "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
    #
    # The %tag_is_empty table defines the set of tags that have
    # no corresponding close tag.
    #
    # cleanup_html() moves close tags around to force all tags to
    # be closed in the correct sequence.  For example, the text
    # "<h1><i>foo</h1>bar</i>" will be converted to the text
    # "<h1><i>foo</i></h1>bar".
    #
    # The %auto_deinterleave table defines the set of tags which
    # should be automatically reopened if they're closed early
    # in this way.  All the tags involved must be in
    # %auto_deinterleave for the tag to be reopened.  For example,
    # the text "<b>bb<i>bi</b>ii</i>" will be converted into the
    # text "<b>bb<i>bi</i></b><i>ii</i>" rather than into the
    # text "<b>bb<i>bi</i></b>ii", because *both* "b" and "i" are
    # in %auto_deinterleave.
    #
    %tag_is_empty = ( 'hr' => 1, 'br' => 1, 'basefont' => 1 );
    %auto_deinterleave = map { $_, 1 } qw(
      tt i b big small u s strike font basefont
      em strong dfn code q sub sup samp kbd var
      cite abbr acronym span
    );
    $auto_deinterleave_pattern = join '|', keys %auto_deinterleave;
    my %attr = ( 'style' => \&cleanup_attr_style );
    my %font_attr = (
        %attr,
        size => sub { /^([-+]?\d{1,3})$/    ? $1 : undef },
        face => sub { /^([\w\-, ]{2,100})$/ ? $1 : undef },
        color => \&cleanup_attr_color,
    );
    my %insdel_attr = (
        %attr,
        'cite'     => \&cleanup_attr_uri,
        'datetime' => \&cleanup_attr_text,
    );
    my %texta_attr = (
        %attr,
        align => sub {
            s/middle/center/i;
            /^(left|center|right)$/i ? lc $1 : undef;
        },
    );
    my %cellha_attr = (
        align => sub {
            s/middle/center/i;
            /^(left|center|right|justify|char)$/i ? lc $1 : undef;
        },
        char => sub { /^([\w\-])$/ ? $1 : undef },
        charoff => \&cleanup_attr_length,
    );
    my %cellva_attr = (
        valign => sub {
            s/center/middle/i;
            /^(top|middle|bottom|baseline)$/i ? lc $1 : undef;
        },
    );
    my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );
    my %col_attr = (
        %attr,
        width => \&cleanup_attr_multilength,
        span  => \&cleanup_attr_number,
        %cellhv_attr,
    );
    my %thtd_attr = (
        %attr,
        abbr    => \&cleanup_attr_text,
        axis    => \&cleanup_attr_text,
        headers => \&cleanup_attr_text,
        scope   => sub { /^(row|col|rowgroup|colgroup)$/i ? lc $1 : undef },
        rowspan => \&cleanup_attr_number,
        colspan => \&cleanup_attr_number,
        %cellhv_attr,
        nowrap  => undef,
        bgcolor => \&cleanup_attr_color,
        width   => \&cleanup_attr_number,
        height  => \&cleanup_attr_number,
    );
    my $none = {};
    %safe_tags = (
        'br' => {
            'clear' => sub { /^(left|right|all|none)$/i ? lc $1 : undef }
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
        'q'          => { %attr, 'cite' => \&cleanup_attr_uri },
        'blockquote' => { %attr, 'cite' => \&cleanup_attr_uri },
        'sub'        => \%attr,
        'sup'        => \%attr,
        'tt'         => \%attr,
        'i'          => \%attr,
        'b'          => \%attr,
        'big'        => \%attr,
        'small'      => \%attr,
        'u'          => \%attr,
        's'          => \%attr,
        'font'       => \%font_attr,
        'table'      => {
            %attr,
            'frame' => \&cleanup_attr_tframe,
            'rules' => \&cleanup_attr_trules,
            %texta_attr,
            'bgcolor'     => \&cleanup_attr_color,
            'width'       => \&cleanup_attr_length,
            'cellspacing' => \&cleanup_attr_length,
            'cellpadding' => \&cleanup_attr_length,
            'border'      => \&cleanup_attr_number,
            'summary'     => \&cleanup_attr_text,
        },
        'caption' => {
            %attr,
            'align' => sub { /^(top|bottom|left|right)$/i ? lc $1 : undef },
        },
        'colgroup' => \%col_attr,
        'col'      => \%col_attr,
        'thead'    => \%cellhv_attr,
        'tfoot'    => \%cellhv_attr,
        'tbody'    => \%cellhv_attr,
        'tr'       => {
            %attr,
            bgcolor => \&cleanup_attr_color,
            %cellhv_attr,
        },
        'th'   => \%thtd_attr,
        'td'   => \%thtd_attr,
        'ins'  => \%insdel_attr,
        'del'  => \%insdel_attr,
        'a'    => { %attr, href => \&cleanup_attr_uri, },
        'h1'   => \%texta_attr,
        'h2'   => \%texta_attr,
        'h3'   => \%texta_attr,
        'h4'   => \%texta_attr,
        'h5'   => \%texta_attr,
        'h6'   => \%texta_attr,
        'p'    => \%texta_attr,
        'div'  => \%texta_attr,
        'span' => \%texta_attr,
        'ul'   => {
            %attr,
            'type' => sub { /^(disc|square|circle)$/i ? lc $1 : undef },
            'compact' => undef,
        },
        'ol' => {
            %attr,
            'type'    => \&cleanup_attr_text,
            'compact' => undef,
            'start'   => \&cleanup_attr_number,
        },
        'li' => {
            %attr,
            'type'  => \&cleanup_attr_text,
            'value' => \&cleanup_no_number,
        },
        'dl'      => { %attr, 'compact' => undef },
        'dt'      => \%attr,
        'dd'      => \%attr,
        'address' => \%attr,
        'pre'     => { %attr, 'width'   => \&cleanup_attr_number },
        'center'  => \%attr,
        'nobr'    => $none,
    );
    %safe_style = (
        'color'            => \&cleanup_attr_color,
        'background-color' => \&cleanup_attr_color,

        # XXX TODO: the CSS spec defines loads more, add 'em
    );
}

sub cleanup_attr_style
{
    my @clean = ();
    foreach my $elt ( split /;/, $_ )
    {
        next if $elt =~ m#^\s*$#;
        if ( $elt =~ m#^\s*([\w\-]+)\s*:\s*(.+?)\s*$#s )
        {
            my ( $key, $val ) = ( lc $1, $2 );
            local $_ = $val;
            my $sub = $safe_style{$key};
            if ( defined $sub )
            {
                my $cleanval = &{$sub}();
                if ( defined $cleanval )
                {
                    push @clean, "$key:$val";
                }
                elsif ($DEBUGGING)
                {
                    push @debug_msg, "style $key: bad value <$val>";
                }
            }
            elsif ($DEBUGGING)
            {
                push @debug_msg, "rejected style element <$key>";
            }
        }
        elsif ($DEBUGGING)
        {
            push @debug_msg, "malformed style element <$elt>";
        }
    }
    return join '; ', @clean;
}

sub cleanup_attr_number
{
    /^(\d+)$/ ? $1 : undef;
}

sub cleanup_attr_multilength
{
    /^(\d+(?:\.\d+)?[*%]?)$/ ? $1 : undef;
}

sub cleanup_attr_text
{
    tr/-a-zA-Z0-9()[]{}\/?.,\\|;:@#~=+*^%$! / /cs;
    $_;
}

sub cleanup_attr_length
{
    /^(\d+\%?)$/ ? $1 : undef;
}

sub cleanup_attr_color
{
    /^(\w{2,20}|#[\da-fA-F]{6})$/ or die "color <<$_>> bad";
    /^(\w{2,20}|#[\da-fA-F]{6})$/ ? $1 : undef;
}

sub cleanup_attr_uri
{
    check_url_valid($_) ? $_ : undef;
}

sub cleanup_attr_tframe
{
    /^(void|above|below|hsides|lhs|rhs|vsides|box|border)$/i ? lc $1 : undef;
}

sub cleanup_attr_trules
{
    /^(none|groups|rows|cols|all)$/i ? lc $1 : undef;
}

use vars qw(@stack $safe_tags $convert_nl);

sub cleanup_html
{
    local ( $_, $convert_nl, $safe_tags ) = @_;
    local @stack = ();

    s[
    (?: <!--.*?-->                                   ) |
    (?: <[?!].*?>                                    ) |
    (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |
    (?: </([a-z0-9]+)>                               ) |
    (?: (.[^<]*)                                     )
  ][
    defined $1 ? cleanup_tag(lc $1, $2)              :
    defined $3 ? cleanup_close(lc $3)                :
    defined $4 ? cleanup_cdata($4)                   :
    ''
  ]igesx;

    # Close anything that was left open
    $_ .= join '', map "</$_->{NAME}>", @stack;

    # Where we turned <i><b>foo</i></b> into <i><b>foo</b></i><b></b>,
    # take out the pointless <b></b>.
    1 while s#<($auto_deinterleave_pattern)\b[^>]*></\1>##go;
    return $_;
}

sub cleanup_tag
{
    my ( $tag, $attrs ) = @_;

    unless ( exists $safe_tags->{$tag} )
    {
        push @debug_msg, "reject tag <$tag>" if $DEBUGGING;
        return '';
    }

    my $t          = $safe_tags->{$tag};
    my $safe_attrs = '';
    while (
        $attrs =~ s#^\s*(\w+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?## )
    {
        my $attr = lc $1;
        my $val  = (
              defined $2 ? $2
            : defined $3 ? unescape_html($3)
            : defined $4 ? unescape_html($4)
            : ''
        );
        unless ( exists $t->{$attr} )
        {
            push @debug_msg, "<$tag>: attr '$attr' rejected" if $DEBUGGING;
            next;
        }
        if ( defined $t->{$attr} )
        {
            local $_ = $val;
            my $cleaned = &{ $t->{$attr} }();
            if ( defined $cleaned )
            {
                $safe_attrs .= qq| $attr="${\( escape_html($cleaned) )}"|;
                if ( $DEBUGGING and $cleaned ne $val )
                {
                    push @debug_msg, "<$tag>'$attr':val [$val]->[$cleaned]";
                }
            }
            elsif ($DEBUGGING)
            {
                push @debug_msg, "<$tag>'$attr':val [$val] rejected";
            }
        }
        else
        {
            $safe_attrs .= " $attr";
        }
    }

    if ( exists $tag_is_empty{$tag} )
    {
        return "<$tag$safe_attrs />";
    }
    else
    {
        my $html = "<$tag$safe_attrs>";
        unshift @stack, { NAME => $tag, FULL => $html };
        return $html;
    }
}

sub cleanup_close
{
    my $tag = shift;

    # Ignore a close without an open
    unless ( grep { $_->{NAME} eq $tag } @stack )
    {
        push @debug_msg, "misplaced </$tag> rejected" if $DEBUGGING;
        return '';
    }

    # Close open tags up to the matching open
    my @close = ();
    while ( scalar @stack and $stack[0]{NAME} ne $tag )
    {
        push @close, shift @stack;
    }
    push @close, shift @stack;

    my $html = join '', map { "</$_->{NAME}>" } @close;

    # Reopen any we closed early if all that were closed are
    # configured to be auto deinterleaved.
    unless ( grep { !exists $auto_deinterleave{ $_->{NAME} } } @close )
    {
        pop @close;
        $html .= join '', map { $_->{FULL} } reverse @close;
        unshift @stack, @close;
    }

    return $html;
}

sub cleanup_cdata
{
    local $_ = shift;

    s[ (?: & ( [a-zA-Z0-9]{2,15}       |
             [#][0-9]{2,6}           |
             [#][xX][a-fA-F0-9]{2,6} | ) \b ;?
     ) | (.)
  ][
     defined $1 ? "&$1;" : $escape_html_map{$2}
  ]gesx;

    # substitute newlines in the input for html line breaks if required.
    s%\cM?\n%<br />\n%g if $convert_nl;

    return $_;
}

# subroutine to escape the necessary characters to the appropriate HTML
# entities

sub escape_html
{
    my $str = shift;
    defined $str or $str = '';
    $str =~ s/([^\w\Q$html_safe_chars\E])/$escape_html_map{$1}/og;
    return $str;
}

# subroutine to unescape escaped HTML entities.  Note that some entites
# have no 8-bit character equivalent, see
# "http://www.w3.org/TR/xhtml1/DTD/xhtml-symbol.ent" for some examples.
# unescape_html() leaves these entities in their encoded form.

sub unescape_html
{
    my $str = shift;
    $str =~ s/ &( (\w+) | [#](\d+) ) \b (;?)
     /
       defined $2 && exists $html_entities{$2} ? $html_entities{$2} :
       defined $3 && $3 > 0 && $3 <= 255       ? chr $3             :
       "&$1$4"
     /gex;

    return strip_nonprintable($str);
}

#
# End of HTML handling code
#
##################################################################

BEGIN
{
   eval 'local $SIG{__DIE__} ; require CGI::NMS::IPFilter';
   $@ and $INC{'CGI/NMS/IPFilter.pm'} = 1;
   $@ and eval <<'END_CGI_NMS_IPFILTER' || die $@;
                                                                                               

## BEGIN INLINED CGI::NMS::IPFilter
package CGI::NMS::IPFilter;
use strict;
                                                                               
require 5.00404;
                                                                               
use Socket;
require Exporter;
use vars qw($VERSION @ISA @EXPORT);

@ISA = qw(Exporter);

$VERSION = sprintf '%d.%.2d', (q$revision: 1.6 $ =~ /(\d+)\.(\d+)/);
                                                                               

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
## END INLINED CGI::NMS::IPFilter
END_CGI_NMS_IPFILTER
CGI::NMS::IPFilter->import();
}
