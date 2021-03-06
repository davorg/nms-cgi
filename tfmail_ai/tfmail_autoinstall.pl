#!/usr/bin/perl -w
use strict;

use lib '../autoinstall';
use NMSAutoInstall;

my $ai = NMSAutoInstall->new('NMS TFmail', 'TFmail');

$ai->add_pm_file('NMStreq.pm',    '../tfmail/NMStreq.pm');
$ai->add_pm_file('NMSCharset.pm', '../tfmail/NMSCharset.pm');
$ai->add_pm_file('MIME/Lite.pm',  '../tfmail/MIME_Lite.pm');

$ai->add_cgi('',       '../tfmail/TFmail.pl');
$ai->add_cgi('Config', '../tfmail/TFmail_config.pl');
$ai->add_cgi('GBview', '../tfmail/GBview.pl');

print $ai->output_script, <<'END_LOCAL_CODE';

sub app_config_is_valid {
        ( app__sendmail_command_ok() or app__smtp_relay_ok() )
   and  app__postmaster_ok()
   and  app__charset_ok()
   ;
}

sub app__sendmail_command_ok {
    my $sc = $Config{sendmail_command} || '';
    return 0 unless length $sc;
    return 0 unless $sc =~ m#^(\S+)#;
    return 1;
}

sub app__smtp_relay_ok {
    my $relay = $Config{smtp_relay} || '';
    return 0 unless $relay =~ /^[\w\-\.]+$/;
    return 1;
}

sub app__postmaster_ok {
    my $pm = $Config{postmaster_address} || '';
    return 0 unless $pm =~ m#^[\w\-\.\+]{1,80}\@[\w\-\.]{1,100}$#;
    return 1;
}

sub app__charset_ok {
    $Config{charset} =~ /^[\w\-]+$/ ? 1 : 0;
}

sub app_edit_config_html {
    my ($sme, $pme, $cse) = ('', '', '');

    unless (app__sendmail_command_ok() or app__smtp_relay_ok()) {
        $sme = <<END;
<p>
 <font color="red">You must set either <b>sendmail location</b> or
 <b>SMTP relay</b> above.  Your system administrator or hosting provider
 should be able to tell you how to set one or other of these for your
 web server.</font>
</p>
END
    }

    unless (app__postmaster_ok()) {
        $pme = <<END;
<p><font color="red">You must enter a valid email address here.</font></p>
END
    }

    unless (app__charset_ok()) {
        $cse = <<END;
<p><font color="red">You must enter the name of a character set here, e.g.
<tt>iso-8859-1</tt>.</font></p>
END
    }

    print <<END;
<h1>Installation Settings</h1>
<p>
 Please adjust the installation settings below until you're happy with them.
 Text in <font color="red">red</font> marks places where you need to make a
 change before TFmail can be installed.
</p>
<hr />
<p>
 <b>Sendmail location</b>: the location of the <tt>sendmail</tt> program on
 the web server, e,g <tt>/usr/lib/sendmail</tt>.  If this web server has no
 <tt>sendmail</tt> program then leave this blank and set <b>SMTP relay</b>
 below instead.
</p>
<p>
 <input type="text" value="${\( ai_eschtml($Config{sendmail_command}) )}"
 name="sendmail_command" size="80" />
</p>
<hr />
<p>
 <b>SMTP relay</b>: the host name or IP address of an SMTP server that will
 relay outgoing emails for this web server.  You only need to set this if
 there is no <tt>sendmail</tt> program on the web server.
</p>
<p>
 <input type="text" value="${\( ai_eschtml($Config{smtp_relay}) )}"
 name="smtp_relay" size="50" />
</p>
$sme
<hr />
<p>
 <b>Postmaster Address</b>: the address to use as the envelope sender of
 mail sent by the script.  If in dought, put your own email address here.
</p>
<p>
 <input type="text" value="${\( ai_eschtml($Config{postmaster_address}) )}"
 name="postmaster_address" size="80" />
</p>
$pme
<hr />
<p>
 <input type="checkbox" name="debugging"
 ${\( $Config{debugging} ? ' checked="checked" value="1"' : '' )} />
 Tick here if you want debugging mode switched on.  You should have this
 on if you're having trouble getting the script working, but turn it off
 for normal operation.
</p>
<p>
 <input type="checkbox" name="enable_uploads"
 ${\( $Config{enable_uploads} ? ' checked="checked" value="1"' : '' )} />
 Tick here if you want to be able to set up forms where the user uploads
 a file and it comes through to you as an attachment to the email.
</p>
<p>
 <input type="checkbox" name="use_mime_lite"
 ${\( $Config{use_mime_lite} ? ' checked="checked" value="1"' : '' )} />
 Tick here if you want <tt>TFmail</tt> to use the <tt>MIME::Lite</tt>
 Perl module to send emails.  With this ticked your emails are less
 likely to be scrambled by mail servers but the script may start up
 slower on some systems.
</p>
<hr />
<p>
 <b>Character set</b>: <input type="text" size="20" name="charset"
 value="${\( ai_eschtml($Config{charset}) )}" />
</p>
$cse
END
}

sub app_get_config_from_inputs {
    my ($cgi) = @_;

    defined $cgi->param('postmaster_address') or return 0;

    foreach my $p (qw(postmaster_address sendmail_command smtp_relay charset)) {
        $Config{$p} = $cgi->param($p) || '';
    }

    foreach my $p (qw(debugging enable_uploads use_mime_lite)) {
        $Config{$p} = ($cgi->param($p) ? 1 : 0);
    }

    return 1;
}

sub app_fill_in_missing_defaults {
    
    unless ($Config{sendmail_command}) {
        foreach my $bin (qw(/usr/sbin/sendmail /usr/lib/sendmail
	                    /usr/bin/sendmail /bin/sendmail
                        /var/qmail/bin/sendmail
                        )) {
            if (-x $bin and not -d $bin) {
	            $Config{sendmail_command} = $bin;
              last;
            }
        }
    }

    $Config{debugging} = '1' unless $Config{debugging} eq '0';
    $Config{enable_uploads} = '0' unless $Config{enable_uploads} eq '1';
    $Config{use_mime_lite} = '1' unless $Config{use_mime_lite} eq '0';
    $Config{charset} |= 'iso-8859-1';
}

sub app_prepare_for_install {
    
    my $mailprog;
    if ( length $Config{sendmail_command} ) {
        $mailprog = $Config{sendmail_command};
        $mailprog .= " -oi -t" unless $mailprog =~ /\S\s+\S/;
    }
    else {
        $mailprog = "SMTP:$Config{smtp_relay}";
    }

    app__subst_constant('DEBUGGING',      $Config{debugging});
    app__subst_constant('LIBDIR',         $Probe{LIBDIR});
    app__subst_constant('MAILPROG',       $mailprog);
    app__subst_constant('POSTMASTER',     $Config{postmaster_address});
    app__subst_constant('CONFIG_ROOT',    "$Probe{BASEDIR}/cfg");
    app__subst_constant('LOGFILE_ROOT',   "$Probe{BASEDIR}/log");
    app__subst_constant('ENABLE_UPLOADS', $Config{enable_uploads});
    app__subst_constant('USE_MIME_LITE',  $Config{use_mime_lite});
    app__subst_constant('CHARSET',        $Config{charset});
    app__subst_constant('LOCKFILE',       "$Probe{BASEDIR}/.lock");
    app__subst_constant('PASSWORD',       $Probe{PASSWORD});

    foreach my $script (keys %Scripts) {
	$Scripts{$script} =~ s/^\#\!.*\n/$Probe{SHEBANG}/;
    }

    ai_mkdir_p("$Probe{BASEDIR}/cfg");
    ai_mkdir_p("$Probe{BASEDIR}/log");

    my $v = eval q{ require MIME::Lite ; $MIME::Lite::VERSION };
    if (defined $v and $v =~ /^2/) {
        delete $Modules{'MIME/Lite.pm'};
    }
}

sub app__subst_constant {
    my ($constant, $value) = @_;

    $value =~ s#([\\'])#\\$1#g;
    foreach my $script (keys %Scripts) {
        $Scripts{$script} =~ s#(\nuse constant \Q$constant\E[ \t]+\=\>)[^\n]+#$1 '$value';#;
    }
}

sub app_success_html {

    my $config_edit = "$Probe{CGI_BIN_URI}/${ai_cgi_name}Config$Probe{CGI_EXT}";

    print <<END;
<form method="post" action="${\( ai_eschtml($config_edit) )}">
<p>
<input type="hidden" name="password" value="${\( ai_eschtml( $Probe{PASSWORD} ) )}" />
The <input type="submit" value="TFmail Interactive Configuration Editor" />
has been installed as <tt>${\( ai_eschtml($config_edit) )}</tt>.  The password
for the configuration editor is the same as the activation password of this
autoinstall script.
</p>
</form>
<p>
If you prefer to edit the TFmail configuration files using a text editor
and then upload them, you should upload all <tt>.trc</tt> and <tt>.trt</tt>
files to the <tt>${\( ai_eschtml("$Probe{REL_BASEDIR}/cfg") )}</tt>
subdirectory of the directory into which you uploaded this autoinstall
script.
</p>
END
}

END_LOCAL_CODE

