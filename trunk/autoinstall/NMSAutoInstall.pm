package NMSAutoInstall;
use strict;

use IO::File;

=head1 NAME

NMSAutoInstall - autoinstall CGI script generator

=head1 SYNOPSIS

  use NMSAutoInstall;

  my $ai = NMSAutoInstall->new('Acme WebFoo', 'Foo');

  $ai->add_pm_file('WebFoo/Foo.pm', 'src/Foo.pm');
  $ai->add_pm_file('MIME/Lite.pm',  '../cpan_bits/MIME_Lite.pm');

  $ai->add_cgi('',      'src/Foo.pl');
  $ai->add_cgi('Admin', 'src/FooAdmin.pl');

  print $ai->output_script, $localcode;

=head1 DESCRIPTION

If you have a web application consisting of one or more Perl CGI
scripts and zero or more C<.pm> files that they need, you can use
this package to generate a single large CGI script which an end
user can upload and run to install and configure your application.

You must append some Perl code to the generated script, to fill
in the application specific bits of the install process. Details
below.

=head1 METHODS

=over

=item new ( APPNAME, CGINAME )

Creates a new NMSAutoInstall object, for a CGI application called
APPNAME.

The value of the CGINAME parameter should be a sensible default name
under which to install your main CGI script, without file extension.

=cut

sub new {
    my ($pkg, $appname, $cginame) = @_;

    return bless { APPNAME => $appname,
	           CGINAME => $cginame,
		   PM => {}, CGI => {},
	         }, $pkg;
}

=item add_pm_file ( TARGET, SOURCE )

Adds a single C<.pm> file to the autoinstall script, to be installed
as TARGET under the application's F<lib> directory.  The contents
for the file are read from local file SOURCE.

=cut

sub add_pm_file {
    my ($self, $target, $source) = @_;

    $self->{PM}{$target} = $self->_readfile($source);
}

=item add_cgi ( TARGET_SUFFIX, SOURCE )

Adds a single CGI script to the autoinstall script.  TARGET_SUFFIX
should be the string to append to the name under which your main
CGI script is installed to give a sensible default name under which
to install this CGI.

=cut

sub add_cgi {
    my ($self, $target, $source) = @_;

    $self->{CGI}{$target} = $self->_readfile($source);
}

=item output_script ()

Returns the autoinstall CGI script, as a single multiline string.

=cut

sub output_script {
    my ($self) = @_;

    my $modules = '';
    foreach my $pm (keys %{ $self->{PM} }) {
        my $text = $self->{PM}{$pm};
	$text =~ s#\n$##;
	my $end = 'NMSAI_END_PM_FILE';
	$end .= 'x' while $text =~ /\Q$end/;
	$modules .= <<END;

    '$pm' => <<'$end',
$text
$end
END
    }

    my $scripts = '';
    foreach my $cgi (keys %{ $self->{CGI} }) {
        my $text = $self->{CGI}{$cgi};
	my $end = 'NMSAI_END_CGI_SCRIPT';
	$end .= 'X' while $text =~ /$end/;
	$scripts .= <<END;

    '$cgi' => <<'$end',
$text
$end
END
    }
    
    my $ai = do { local $/ ; <DATA> };
    $ai =~ s#<<APPNAME>>#$self->{APPNAME}#g;
    $ai =~ s#<<CGINAME>>#$self->{CGINAME}#g;
    $ai =~ s#<<MODULES>>#$modules#;
    $ai =~ s#<<SCRIPTS>>#$scripts#;

    return $ai;
}

=back

=head1 GLOBAL VARIABLES

When the application specific install code (discussed below) runs on
the target system, the following package globals will be available
to it:

=over

=item C<%Probe>

The C<%Probe> hash holds the results of some tests that the autoinstall
script applies to the target system:

=over

=item C<ME>

The filesystem path to the running autoinstall CGI script.

=item C<CGI_BIN>

The filesystem path to the directory that holds the running autoinstall
script.

=item C<CGI_BIN_URI>

An absolute URI segment (without host) that points to the the directory
that holds the running autoinstall script.

=item C<CGI_EXT>

The file extension (if any) that CGI scripts should have on the target
system.  Determined from the name of the running autoinstall CGI
script.

=item C<SHEBANG>

The C<#!> line of the running autoinstall CGI script, including the
terminating newline.  If the running autoinstall CGI script appears to
have no C<#!> line then this will be the empty string.  

=item C<BASEDIR>

The filesystem path to a directory set aside for this application's
private files, where private means not viewable via the web.  Any
state or config files which your application needs to install should go
here.

If the end user chooses to install several different instances of your
application, each will get a different BASEDIR.

=item C<REL_BASEDIR>

As BASEDIR, but expressed as a relative path starting from the
directory that holds the autoinstall CGI script.

=item C<LIBDIR>

The filesystem path to the location under which the C<.pm> files will
be installed.

=item C<PASSWORD>

The activation password for the autoinstall CGI.  If your application
includes a password protected admin script, this password may be
suitable for use there.

=back

=item C<%Config>

The C<%Config> hash holds the configuration settings for the
application being installed.  It is up to you to decide what
configuration variables to define for your application, but the
keys in this hash must consist of word characters and minus
characters only, and the values may not contain NULLs.

=item C<$ai_cgi_name>

The name (without file extension) under which the main CGI script
is to be installed.

=item C<%Scripts>

A hash by TARGET_SUFFIX (as passed to the add_cgi() method when the
autoinstall script was built) of the bodies of the CGI scripts of
the application.

=item C<%Modules>

A hash by TARGET (as passed to the add_pm_file() method when the
autoinstall script was built) of the bodies of the C<.pm> files of
the application.

=back

=head1 APPLICATION SPECIFIC CODE

To make a working autoinstall script, several C<sub> definitions must
be appended to the script returned by the output_script() method.

=over

=item C<app_config_is_valid()>

This sub must examine the configuration in the C<%Config> hash and
return true if it is a valid configuration for this application,
false otherwise.

=item C<app_edit_config_html()>

This sub must print HTML to STDOUT, offering the configuration in
C<%Config> to the user for editing.  If the current config is not a
valid config for the application, then the output should be
annotated to show where the problems are.

This sub need not output the E<lt>formE<gt> or E<lt>/formE<gt> tags
or a submit button.

=item C<app_get_config_from_inputs ( CGI )>

This sub must populate the C<%Config> hash with values obtained from
the CGI.pm object CGI.  It will be invoked after the user has
submitted the form containing the output of app_edit_config_html().

The sub should return true if some configs were got from the CGI
inputs (even if the config wasn't valid) or false if no config
was found.

=item C<app_fill_in_missing_defaults()>

Set up sensible default values for any configuration values missing
from C<%Config>.

=item C<app_prepare_for_install()>

This sub will be invoked once the user has chosen to go ahead with
the installation, using a valid configuration.  It must:

=over

=item

Optionally delete from C<%Scripts> any scripts that need not be
installed for this target system and configuration.

=item

Optionally delete from C<%Modules> any modules that need not be
installed for this target system and configuration.

=item

Make any changes necessary to the CGI script bodies in C<%Scripts>,
to adapt them to this target system and user configuration.

=item

Do any application specific installation operations, such as
creating files and directories in the docroot or under $Probe{BASEDIR}.

=back

=item C<app_success_html()>

This sub will be called to output the application specific portion of
the success page once the installation has been completed.  It should
print HTML to STDOUT.

=back

=head1 SUBS AVAILABLE

The following subs are defined in the autoinstall script, and the
application specific subs above are free to make use of them.

=over

=item C<ai_usererror( MESSAGE )>

Outputs an error page and aborts the installation.  The MESSAGE
parameter (HTML - don't forget to run untrusted input through
ai_eschtml() first) should detail the problem and tell the user
exactly what to do to fix it.

This error handler is suitable for situations where the user needs
to do something before the installation can continue, such as
enabling write permission on something.

=item C<ai_syserror( MESSAGE )>

Similar to ai_usererror(), but for an unexpected OS error such
as a failed system call in a situation where that shouldn't
happen.

Lots of diagnostic output is produced.

=item C<ai_scripterror( MESSAGE )>

As ai_syserror(), except that the message is phrased to suggest
that the problem is a bug in the autoinstall script rather than
a fault with the user's system.

=item C<ai_mkdir_p( DIRNAME )>

Ensures that directory DIRNAME exists.  Calls one of the non-returning
error subs on failure.

=item C<ai_mkdir_p_dirname( FILENAME )>

Calls ai_mkdir_p() on the directory name portion of filename FILENAME.

=item C<ai_writefile( FILENAME, CONTENTS, MODE )>

Writes CONTENTS to file FILENAME, giving it numerical mode MODE.  Uses
a temporary file and a rename to make the change atomic.  Calls a
non-returning error sub on failure.

=item C<ai_eschtml( TEXT )>

Returns a copy of TEXT with any HTML metacharacters escaped.

=back

=head1 PRIVATE METHODS

=over

=item _readfile ( FILENNAME )

Return the contents of a file.

=cut

sub _readfile {
    my ($self, $filename) = @_;

    my $fh = IO::File->new("<$filename");
    defined $fh or die "open <$filename: $!";
    my $buf;
    $fh->read($buf, -s $fh) or die "read from $filename: $!"; 
    return $buf;
}

=back

=cut

1;

__DATA__
#!/usr/local/bin/perl -wT
use strict;
#
# This is an automatic installation script for <<APPNAME>>
#
# You may need to replace "/usr/local/bin/perl" on the first line of
# this script with a different path.  Your hosting provider or system
# administrator will be able to tell you the correct path to the Perl
# interpreter for your system.
#
# You should upload this script in ASCII mode, and you may need to
# enable execute permission after uploading it.
#
# Before you upload this script, you must set a password.  Change the
# string "password" below to some secret word known only to you.  It
# is very important to make this password hard to guess, since anyone
# who knows it will be able to break into your web site, take full
# control of your pages and use your web server to attack other hosts
# on the internet.
my $pw = 'password';
#
# If this script fails to run and gives an error message that looks
# like "too late for -T" then you should delete the 'T' from the end
# of the first line of the script.
#
######################################################################
#
#  NO USER SERVICEABLE PARTS BELOW THIS POINT
#
######################################################################
#

use CGI;
use Fcntl ':flock';
use IO::File;

use vars qw(%Scripts %Modules);

%Scripts = (
<<SCRIPTS>>
);

%Modules = (
<<MODULES>>
);

######################################################################

use vars qw($ai_auth_done %Probe $ai_cgi_name %Config);
$ai_auth_done = 0;
%Probe = ();
$ai_cgi_name = '';
%Config = ();

eval {

    if (length $pw < 7) {
        ai_usererror(<<END);
<p>The password configured in this autoinstall script is too short to
be secure.  Please choose a password of at least 7 characters and
upload this autoinstall script again.</p>
END
    }
    elsif ($pw =~ /pa[s5][s5]|w[0o]rd/i) {
        ai_usererror(<<END);
<p>The password configured in this autoinstall script is too similar
to the default value of 'password' to be secure.  Please choose a
password that's nothing like the word 'password' and upload this
autoinstall script again.</p>
END
    }
    
    ai_probe_and_create_nmsai_files();
    
    my $lockfile = "$Probe{BASEDIR_ROOT}/.lock";
    my $lock = IO::File->new(">>$lockfile");
    defined $lock or ai_syserror("open >>$lockfile: $!");
    flock($lock, LOCK_EX) or ai_syserror("flock $lockfile: $!");
    
    if (-s $lockfile > 5) {
        ai_usererror(<<END);
<p>
This autoinstall script is disabled, because there have been too many
incorrect password attempts.
</p><p>
To re-enable it, you must go to the directory on the web server where
the autoinstall CGI is, go into the <tt>.nmsai</tt> subdirectory, go
into the subdirectory that you find there (there should only be one)
and delete the file called <tt>.lock</tt>.
</p>
END
    }
    
    ai_password_page() unless $ENV{REQUEST_METHOD} eq 'POST';
    
    local $CGI::DISABLE_UPLOADS = 1;
    local $CGI::POST_MAX        = 1000000;
    my $cgi = CGI->new;
    
    my $gotpass = $cgi->param('_nmsai_pw') || '';
    if ($gotpass eq $pw) {
        truncate LOCK, 0;
        $ai_auth_done = 1;
    }
    else {
        print $lock 'x';
        $lock->close;
        ai_password_page();
    }
    $Probe{PASSWORD} = $pw;
    
    $ai_cgi_name = $cgi->param('_nmsai_cgi_name') || '';
    unless ($ai_cgi_name =~ /^([\w\-]+)$/) {
        ai_choose_cgi_name_page('<<CGINAME>>', $Probe{CGI_EXT});
    }
    $ai_cgi_name = $1;
    $Probe{BASEDIR} = $Probe{BASEDIR_ROOT} . "/$ai_cgi_name";
    $Probe{REL_BASEDIR} = ".nmsai/$Probe{RAND_NAMED_DIR}/$ai_cgi_name";
    
    unless ( app_get_config_from_inputs( $cgi) ) {
        ai_load_config();
        app_fill_in_missing_defaults();
    }
    
    my $is_valid = app_config_is_valid();
    
    if ($is_valid and $cgi->param('_nmsai_do_install')) {
        ai_save_config();
        app_prepare_for_install();
        ai_do_install();
        ai_success_page();
    }
    else {
        ai_config_edit_page();
    }

};

ai_scripterror("runtime error [$@]") if $@;

####################################################################

sub ai_password_page {
    ai_html_header();

    print <<END;
<p>
Please enter the password that you put in the autoinstall script
before you uploaded it.
</p><p>
<input type="password" name="_nmsai_pw" />
<input type="submit" value="Continue" />
</p>
</form>
</body>
</html>
END

    exit;
}

sub ai_choose_cgi_name_page {
    my ($default, $ext) = @_;

    ai_html_header();
    print <<END;
<p>
Please choose the name under which the <tt>$default</tt> CGI script
will be installed:
<input type="text" name="_nmsai_cgi_name" value="$default"
/><tt>$ext</tt>
</p>
<p><input type="submit" value="Continue" /></p>
<p>Note that the CGI name that you put in the box may contain
letters, numbers, underscores and minus characters only.</p>
</form>
</body>
</html>
END

    exit;
}

sub ai_load_config {

    my %all_config = ();
    %Config = ();

    ai_load_all_config(\%all_config);

    # Configuration variables such as 'postmaster' go into the config
    # hash for this application, to act as defaults.
    foreach my $k (keys %all_config) {
        next if $k =~ /:/;
	$Config{$k} = $all_config{$k};
    }

    # Configuration variables such as 'foo:postmaster' override
    # configuration variables such as 'postmaster' if and only if we
    # are installing a CGI called 'foo'.
    foreach my $k (keys %all_config) {
        next unless $k =~ /^\Q$ai_cgi_name\E:([^:]+)$/;
	$Config{$1} = $all_config{$k};
    }
}

sub ai_load_all_config {
    my ($all_config) = @_;

    my $in = IO::File->new("<$Probe{BASEDIR_ROOT}/.config");
    defined $in or return;
    local $/ = "\0";
    while (1) {
        my $key = <$in>;
      last unless defined $key;
	chomp $key;
	$key =~ /^([\w\-\:]+)$/ or ai_scripterror("bad config key [$key]");
	$key = $1;

	my $val = <$in>;
	defined $val or ai_scripterror("key [$key] lacks a value");
	chomp $val;
	
	$all_config->{$key} = $val;
    }
    $in->close;
}

sub ai_save_config {
    my %all_config = ();
    ai_load_all_config(\%all_config);
    foreach my $k (keys %Config) {
        $all_config{$k} = $Config{$k};
	$all_config{"$ai_cgi_name:$k"} = $Config{$k};
    }
    ai_writefile("$Probe{BASEDIR_ROOT}/.config", join("\0",%all_config)."\0", 0644);
}

sub ai_config_edit_page {

    ai_html_header();
    app_edit_config_html();
    print <<END;
<p><input type="submit" value="Check this configuration" /></p>
END

    if ( app_config_is_valid() ) {
        print <<END;
<input type="submit" name="_nmsai_do_install"
value="Install with this configuration" />
END
    }

    print <<END;
</form>
</body>
</html>
END

    exit;
}

sub ai_success_page {

    ai_html_header('noform');
    print "<h2>Installation successful</h2>\n";

    if (unlink $Probe{ME}) {
        print <<END;
<p>The autoinstall script has completed the installation and deleted
itself.</p>
END
    }
    else {
        print <<END;
<p>The autoinstall script completed the installation OK, but was
unable to delete itself afterwards.  Please delete the autoinstall
script now.</p>
END
    }

    print <<END;
<p>If you had to change the permissions on the directory into which
you uploaded the autoinstall script in order to get it to work, you
should now change them back to what they were before.</p>
END

    app_success_html();
    print <<END;
</body>
</html>
END

    exit;
}

sub ai_html_header {
    my ($no_form) = @_;

    print <<END;
Content-Type: text/html; charset=iso-8859-1

<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
 <title><<APPNAME>> AutoInstall</title>
</head>
<body>
END

    ai_form_header() unless $no_form;
}

sub ai_form_header {
    print qq{<form method="post">\n};
    if ($ai_auth_done) {
        print qq|<input type="hidden" name="_nmsai_pw" value="${\( ai_eschtml($Probe{PASSWORD}) )}" />\n|;
    }
    if ($ai_cgi_name) {
        print qq|<input type="hidden" name="_nmsai_cgi_name" value="${\( ai_eschtml($ai_cgi_name) )}" />\n|;
    } 
}

sub ai_do_install {

    foreach my $module (keys %Modules) {
        my $filename = "$Probe{LIBDIR}/$module";
        ai_mkdir_p_dirname($filename);
	ai_writefile($filename, $Modules{$module}, 0644);
    }

    foreach my $cgi (keys %Scripts) {
        my $install_as = $ai_cgi_name .$cgi;
	my $filename = "$Probe{CGI_BIN}/$install_as$Probe{CGI_EXT}";
	ai_writefile($filename, $Scripts{$cgi}, 0755);
    }
}

sub ai_probe_and_create_nmsai_files {
    
    my $me = $ENV{SCRIPT_FILENAME} || $ENV{PATH_TRANSLATED};
    $me =~ tr#\\#/#;
    $me =~ m#^([\w\-\.\/ \:]+)$# or ai_scripterror("failed to get script filename");
    $Probe{ME} = $me = $1;

    $Probe{CGI_EXT} = '';
    if ($me =~ m#(\.\w{1,10})$#) {
        $Probe{CGI_EXT} = $1;
    }

    $me =~ m#^([\w\-\.\/ \:]+)/[^/]+$# or ai_scripterror("failed to get cgi-bin directory");
    $Probe{CGI_BIN} = $1;

    my $uri = $ENV{SCRIPT_NAME};
    defined $uri or ai_scripterror("failed to get script URI");
    $uri =~ s#/[^/]+$## or ai_scripterror("failed to get cgi-bin directory uri");
    $Probe{CGI_BIN_URI} = $uri;

    $Probe{SHEBANG} = '';
    my $this_script = IO::File->new("<$me");
    defined $this_script or ai_scripterror("failed to open myself for read: $!");
    my $line = <$this_script>;
    $this_script->close;
    if ($line =~ /^(\#\!.*\n)$/) {
        $Probe{SHEBANG} = $1;
    }

    my $root = "$Probe{CGI_BIN}/.nmsai";
    unless (-d $root or mkdir $root, 0755) {
        ai_usererror(<<END);
<p>
The autoinstall script failed to create the <tt>.nmsai</tt>
subdirectory, which it needs.  The error message received from the
operating system was <tt>${\( ai_eschtml($!) )}</tt>.
</p><p>
The most likely cause of this problem is that the web server process
lacks write permission on the directory into which you uploaded the
autoinstall CGI.  You must give the web server process write
permission on that directory before the installation can continue.
Depending on server configuration, that may mean making the
directory world writable (mode 0777).
</p>
END
    }

    my $subdir = ai_find_subdir($root);
    unless (defined $subdir) {
        $subdir = ai_random_string();
    }
    $Probe{RAND_NAMED_DIR} = $subdir;

    ai_mkdir_p("$root/$subdir/.lib");
    $Probe{BASEDIR_ROOT} = "$root/$subdir";
    $Probe{LIBDIR}       = "$root/$subdir/.lib";

    ai_writefile("$root/.htaccess", <<END, 0644);

Order deny allow
deny from all

END

    foreach my $index (qw(index.html index.htm default.htm welcome.htm)) {
        ai_writefile("$root/$index", <<END, 0644);
<html>
<head>Access Denied</head>
<body>
<p>You do not have permission to access this directory</p>
</body>
</html>
END
    }
}

sub ai_random_string {

    my $random = pack 'C6', map rand(256), (1..6);

    if ( my $rnd = IO::File->new("</dev/urandom") ) {
        my $devrnd;
        $rnd->read($devrnd, 6);
	$random ^= $devrnd;
    }

    my @chars = ('a'..'z', 'A'..'Z', '0'..'9', '-', '_');
    my $buf = unpack 'b*', $random;
    $buf =~ s/([01]{1,6})/$chars[ord pack 'b*', $1]/ge;

    $buf =~ /^([\w\-]{8})$/ or ai_scripterror("bad rnd [$buf]");
    return $1;
}

sub ai_find_subdir {
    my ($dir) = @_;

    opendir D, $dir;
    my @hits = grep /^[\w\-]{4,20}$/, readdir D;
    return undef unless @hits;
    if (@hits > 1) {
         ai_scripterror( "multiple subdirs of [$dir]: ".join(':',@hits) );
    }
    $hits[0] =~ /^([\w\-]{4,20})$/ or ai_scripterror("bad subdir [$hits[0]]");
    return $1;
}

sub ai_writefile {
    my ($filename, $contents, $mode) = @_;

    my $out = IO::File->new(">$filename.tmp");
    defined $out or ai_syserror("open >$filename.tmp: $!");
    $out->print($contents) or ai_syserror("write to $filename.tmp: $!");
    $out->close or ai_syserror("close $filename.tmp: $!");

    chmod $mode, "$filename.tmp" or ai_syserror("chmod $filename.tmp: $!");
    rename "$filename.tmp", $filename or ai_syserror("rename [$filename.tmp]: $!");
}

sub ai_mkdir_p_dirname {
    my ($filename) = @_;
    $filename =~ s#/[^/]+$## or ai_scripterror("dirname [$filename]");
    ai_mkdir_p($filename);
}

sub ai_mkdir_p {
    my ($dir) = @_;
    my $orig_dir = $dir;

    my @dirs = ();
    until (-d $dir) {
        $dir =~ s#/([^/]+)$## or ai_scripterror("mkdir_p [$orig_dir]: down to [$dir]");
	unshift @dirs, $1;
    }

    foreach my $d (@dirs) {
        $dir .= "/$d";
	mkdir $dir, 0755 or ai_syserror("mkdir [$dir]: $!");
    }

    -d $orig_dir or ai_scripterror("mkdir_p failed to build [$orig_dir]");
}

sub ai_usererror {
    my ($msg) = @_;

    ai_html_header('noform');
    print <<END;
<h1>Error</h1>
$msg
<hr />
</body>
</html>
END

    exit;
}

sub ai_syserror {
    my ($msg) = @_;

    ai_html_header('noform');
    print <<END;
<h1>Server Fault</h1>
<p>
An error has occurred, and it appears to be some sort of fault on
the server.  It could be that the server's hard disk is full, your
account has exceeded its disk space quota or the permissions or
ownership of a file has changed unexpectedly.
</p>
END

    ai_output_diagnostics($msg);
    print <<END;
<hr />
</body>
</html>
END

    exit;
}

sub ai_scripterror {
    my ($msg) = @_;

    ai_html_header('noform');
    print <<END;
<h1>Installation Script Fault</h1>
<p>
An error has occurred, and it appears to be the result of a fault or
shortcoming of this installation script.
</p>
END

    ai_output_diagnostics($msg);
    print <<END;
<hr />
</body>
</html>
END

    exit;
}

sub ai_output_diagnostics {
    my ($msg) = @_;

    if ($ai_auth_done) {
        print <<END;
<p>The error that occurred was: <tt>${\( ai_eschtml($msg) )}</tt>.</p>
<p>
If you choose to report this error to the script maintainers, please
include the following diagnostic information:
</p>
END
	foreach my $k (keys %ENV) {
            print "<b>${\( ai_eschtml($k) )}</b>: ${\( ai_eschtml($ENV{$k}) )}<br />\n";
        }
    }
    else {
	print STDERR "NMS autoinstall error details: [$msg]\n";
	print <<END;
<p>Details of the error can be found in the web server's error log.</p>
END
    }
}

sub ai_eschtml {
    my ($input) = @_;

    return CGI::escapeHTML($input);
}

