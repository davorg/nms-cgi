#!/usr/bin/perl -wT
#
#   $Id: guestbook-admin.pl,v 1.3 2004-10-29 08:11:57 gellyfish Exp $
#
# guestbooksadmin.pl - admin script for guestbook.pl, allows for deletion and
# hiding of comments.
#
# originally by Richard Rose - nms@rikrose.net
# donated to the NMS scripts archive for distribtution under whichever licence
# they see fit, and maintainance by them.
#

use strict;
use POSIX qw(locale_h strftime);
use CGI qw(:standard);
use Fcntl qw(:DEFAULT :flock);
use IO::File;

use vars qw($DEBUGGING %inputs $shortdate
  $comment_is_hidden $done_headers %actions $password $session_dir
  $guestlog $guestbookreal $myURL $short_date_fmt);

# config section - these variables must be defined before any code runs
BEGIN
{
    $DEBUGGING      = 1;
    $password       = 'password';
    $session_dir    = '/tmp/guestbook-sessions/';
    $guestlog       = '/var/www/nms-test/guestbook/guestlog.html';
    $guestbookreal  = '/var/www/nms-test/guestbook/guestbook.html';
    $myURL          = 'http://nms-test/cgi-bin/guestbook-admin.pl';
    $short_date_fmt = '%d/%m/%y %T %Z';
}

# Routines that need to be defined before we use them
BEGIN
{

    # Error messages should be sent to the users browser
    #  from guestbook.pl
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

        if ( $file =~ /^\(eval/ ) { return undef; }

        if ( !$done_headers )
        {
            print "Content-Type: text/html; charset=iso-8859-1\n\n";
        }

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

    # from guestbook.pl
    sub strip_nonprintable
    {
        my $text = shift;
        return '' unless defined $text;
        $text =~ tr#\t\n\040-\176\240-\377# #cs;
        return $text;
    }

    # Log the Entry or Error
    # from guestbook.pl

    $SIG{__DIE__} = \&fatalsToBrowser;
}

# check for the login cookie sent by the browser as a valid login cookie
sub has_login_cookie
{

    # check for existing login cookie
    return -f $session_dir . $inputs{cookie};
}

# check whether a given cookie is a valid cookie and > 6 hours old. this is
# used in cleaning up old cookies.
sub is_old_cookie
{
    my $filename = shift;
    local $_;

    my $now = time;

    return 0 if $filename =~ /^\./;
    return 0 if $filename !~ /\w{40}/;
    return 1
      if ( stat $session_dir . $filename )[10] < ( $now - ( 6 * 60 * 60 ) );
}

# print html fragments for admin functions
sub add_admin_html
{
    my ($comment_num) = @_;

    print <<EODELETE;
<a href="$myURL?action=delete&entry=$comment_num&cookie=$inputs{cookie}">
delete comment</a>
EODELETE
    print <<EOHIDE;
<a href="$myURL?action=hide&entry=$comment_num&cookie=$inputs{cookie}">hide/unhide comment (currently 
EOHIDE
    print 'not ' unless $comment_is_hidden;
    print qq%hidden)</a><br /><br />\n%;
}

# show the admin view of guestbook.html
sub view_guestbook_as_admin
{
    local $_;

    die "Not logged in!" if ( !&has_login_cookie );

    my $in = new IO::File->new("<$guestbookreal") or die "<$guestbookreal: $!";

    print header();
    print html_top();

    my $comment_num = -1;
    my $in_comment  = 0;
    while (<$in>)
    {
        chomp;
        if (/^<!-- comment start -->$/)
        {
            $comment_num++;
            $in_comment = 1;
        }
        if (/^<!-- comment hidden$/) { $comment_is_hidden = 1; next; }
        if (/<\/body>/i)
        {
            print <<EOBOD;
<a href="$myURL?action=logout&cookie=$inputs{cookie}">Logout</a>\n
</body>
EOBOD
        }
        print $_ . "\n" unless ( /^-->/ or !$in_comment );
        if (/^<!-- comment end -->$/)
        {
            add_admin_html($comment_num);
            print "<hr />\n";
            $comment_is_hidden = 0;
            $in_comment        = 0;
        }

    }

    $in->close;

    exit 0;
}

# show a login page before we can get started
sub show_login_page
{
    print <<EOP;
Content-type: text/html

<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Login</title>
    </head>
    <body>
      <h1>Login</h1>
      <p>You must login before you may administer the guestbook</p>
      <form method="post" action="$myURL?action=login">
        <p>Password: <input type="password" size="30" name="password"/></p>
        <button name="submit" value="submit" type="submit">Login</button>
      </form>
  </html>
EOP

    exit 0;
}

# check whether the given password is correct, and setup the environment if it
# is. redirect to either the login page or the admin view, accordingly
sub process_login
{
    local $_;
    my ( @old_files, $file );
    my $now = time;

    # first, garbage collect sessions over 6 hours old
    opendir SESSION_DIR, $session_dir
      or die "could not open session directory $session_dir";
    @old_files = grep { &is_old_cookie($_) } ( readdir SESSION_DIR );
    closedir SESSION_DIR;
    foreach $file (@old_files)
    {
        if ( $file =~ /(\w{40})/ )
        {
            unlink( $session_dir . $1 );
        }
    }

    if ( $inputs{password} eq 'password' )
    {
        die "You have not changed the password\n";
    }

    # now verify password
    if ( $password and $password eq $inputs{password} )
    {

        # Successful login. Things to do.
        #  generate cookie.
        #  send cookie to user
        #  save cookie to disk
        #  redirect to self, so user can edit

        my $cookiename = unpack 'H*', join '',
          map { chr int rand 256 } ( 1 .. 20 );

        # create cookie file on disk, avoiding exist/create race
        sysopen( SAVED,
            $session_dir . $cookiename,
            O_CREAT | O_WRONLY | O_EXCL
          )
          or die $session_dir . $cookiename . ": $!";

        print SAVED "1";
        close SAVED;

        # send cookie to user
        print CGI::header(
            -type    => "text/html",
            status   => "302 Moved",
            location => "$myURL?action=view&cookie=$cookiename"
        );

        exit 0;
    }

    print CGI::redirect( -URL => $myURL );

}

# toggle an entry's hidden status
# most of this code is a replication of rewrite_file. this could be refactored
# later
sub do_toggle_hidden
{
    die "Not logged in!" if ( !&has_login_cookie );

    my $lock = IO::File->new(">>$guestbookreal.lck")
      or die "open $guestbookreal.lck: $!";
    flock $lock, LOCK_EX or die "flock $guestbookreal: $!@";

    my $temp = IO::File->new(">$guestbookreal.tmp")
      or die "open >$guestbookreal.tmp: $!";

    my $in = new IO::File->new("<$guestbookreal") or die "<$guestbookreal: $!";

    my $comment_num = 0;
    my $hiding      = 0;
    while (<$in>)
    {
        if ( !$temp->print($_) )
        {
            my $write_err = $!;
            $temp->close;
            unlink "$guestbookreal.tmp";
            die "write to $guestbookreal.tmp: $write_err";
        }
        last if /^<!-- comment start -->\n$/;
    }
    while (<$in>)
    {
        chomp;
        if (/^<!-- comment start -->$/)
        {
            ++$comment_num;
            if ( !$temp->print( $_ . "\n" ) )
            {
                my $write_err = $!;
                $temp->close;
                unlink "$guestbookreal.tmp";
                die "write to $guestbookreal.tmp: $write_err";
            }
            next;
        }

        if ( $inputs{entry} != $comment_num )
        {

            # not the comment we're after. save it.
            if ( !$temp->print( $_ . "\n" ) )
            {
                my $write_err = $!;
                $temp->close;
                unlink "$guestbookreal.tmp";
                die "write to $guestbookreal.tmp: $write_err";
            }
        }
        else
        {

            # comment we're going to do something to.

            # first, decide whether we are starting to deal with a hidden
            # comment
            if (/^<!-- comment hidden/)
            {

                # hidden comment. skip this line, then save lines until we
                # find the --> marker, then skip that, then increment the
                # comment number, and save the rest of the file.
                while (<$in>)
                {
                    chomp;
                    last if /^--\>/;

                    if ( !$temp->print( $_ . "\n" ) )
                    {
                        my $write_err = $!;
                        $temp->close;
                        unlink "$guestbookreal.tmp";
                        die "write to $guestbookreal.tmp: $write_err";
                    }
                }
                ++$comment_num;
                next;
            }

            # entry is not hidden. hide it by putting the comment hidden
            # marker, the current line, then lines until we find the end of
            # comment marker, then write the end of hidden text marker, then
            # the end of comment marker, then save the rest of the file
            if ( !$temp->print("<!-- comment hidden\n$_\n") )
            {
                my $write_err = $!;
                $temp->close;
                unlink "$guestbookreal.tmp";
                die "write to $guestbookreal.tmp: $write_err";
            }
            while (<$in>)
            {
                chomp;
                if (/^<!-- comment end -->/)
                {
                    if ( !$temp->print( "-->\n" . $_ . "\n" ) )
                    {
                        my $write_err = $!;
                        $temp->close;
                        unlink "$guestbookreal.tmp";
                        die "write to $guestbookreal.tmp: $write_err";
                    }
                    last;
                }

                if ( !$temp->print( $_ . "\n" ) )
                {
                    my $write_err = $!;
                    $temp->close;
                    unlink "$guestbookreal.tmp";
                    die "write to $guestbookreal.tmp: $write_err";
                }
            }
            ++$comment_num;
            next;

        }

    }
    if ( !$temp->close )
    {
        my $close_err = $!;
        unlink "$guestbookreal.tmp";
        die "close $guestbookreal.tmp: $close_err";
    }

    $in->close;

    rename "$guestbookreal.tmp", $guestbookreal
      or die "rename $guestbookreal.tmp -> $guestbookreal: $!";

    $lock->close;

    &view_guestbook_as_admin;
}

# delete an entry
# most of this code is a replication of rewrite_file. this could be refactored
# later
sub do_delete_entry
{
    die "Not logged in!" if ( !&has_login_cookie );

    my $lock = IO::File->new(">>$guestbookreal.lck")
      or die "open $guestbookreal.lck: $!";
    flock $lock, LOCK_EX or die "flock $guestbookreal: $!@";

    my $temp = IO::File->new(">$guestbookreal.tmp")
      or die "open >$guestbookreal.tmp: $!";

    my $in = new IO::File->new("<$guestbookreal") or die "<$guestbookreal: $!";

    my $comment_num = -1;
    my $in_comment  = 0;
    while (<$in>)
    {
        chomp;
        if (/^<!-- comment start -->$/)
        {
            $comment_num++;
            $in_comment = 1;
        }
        if ( $inputs{entry} != $comment_num or !$in_comment )
        {
            if ( !$temp->print( $_ . "\n" ) )
            {
                my $write_err = $!;
                $temp->close;
                unlink "$guestbookreal.tmp";
                die "write to $guestbookreal.tmp: $write_err";
            }
        }
        if (/^<!-- comment end -->$/)
        {
            $in_comment = 0;
        }

    }
    if ( !$temp->close )
    {
        my $close_err = $!;
        unlink "$guestbookreal.tmp";
        die "close $guestbookreal.tmp: $close_err";
    }

    $in->close;

    rename "$guestbookreal.tmp", $guestbookreal
      or die "rename $guestbookreal.tmp -> $guestbookreal: $!";

    $lock->close;

    &view_guestbook_as_admin;
}

# invalidate the current session
sub do_logout
{
    if ( $inputs{cookie} =~ /(\w{40})/ )
    {
        unlink( $session_dir . $1 );
    }

    print CGI::redirect( -URL => $myURL );
}

$| = 1;

# sanitize environment
delete @ENV{qw(ENV BASH_ENV IFS PATH)};

# setup our allowed variables
foreach my $input (qw(password action entry cookie))
{
    my $t = param($input);
    $t = url_param($input) unless defined $t;
    $inputs{$input} = strip_nonprintable($t);
}

# setup environment for rest of script.
$shortdate = strftime( $short_date_fmt, localtime );

# allowed set of actions, called by references straight from the action input
%actions = (
    'login'  => \&process_login,
    ''       => \&show_login_page,
    'hide'   => \&do_toggle_hidden,
    'delete' => \&do_delete_entry,
    'view'   => \&view_guestbook_as_admin,
    'logout' => \&do_logout
);

# do the action, if we know about it, otherwise, show an error message instead
&{ $actions{ $inputs{action} } }() if defined( $actions{ $inputs{action} } );
die "Unknown action";

sub html_top
{
    return <<EOTOP;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Guestbook Administration</title>
  </head>
  <body>
     <h1>Administer Guestbook entries</h1>
     <hr />
EOTOP
}
