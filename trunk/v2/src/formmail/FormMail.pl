#!/usr/bin/perl -wT
#
# $Id: FormMail.pl,v 1.2 2003-01-24 20:30:32 nickjc Exp $
#

use strict;
use vars qw(
  $DEBUGGING $emulate_matts_code $secure %more_config
  $allow_empty_ref $max_recipients $mailprog @referers
  @allow_mail_to @recipients %recipient_alias
  @valid_ENV $date_fmt $style $send_confirmation_mail
  $confirmation_text $locale $charset $no_content
  $double_spacing $wrap_text $wrap_style $postmaster
);

# PROGRAM INFORMATION
# -------------------
# FormMail.pl $Revision: 1.2 $
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For help on configuration or installation see the
# README file or the POD documentation at the end of
# this file.

# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#
BEGIN
{
  $DEBUGGING         = 1;
  $emulate_matts_code= 0;
  $secure            = 1;
  $allow_empty_ref   = 1;
  $max_recipients    = 5;
  $mailprog          = '/usr/lib/sendmail -oi -t';
  $postmaster        = '';
  @referers          = qw(dave.org.uk 209.207.222.64 localhost);
  @allow_mail_to     = qw(you@your.domain some.one.else@your.domain localhost);
  @recipients        = ();
  %recipient_alias   = ();
  @valid_ENV         = qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT);
  $locale            = '';
  $charset           = 'iso-8859-1';
  $date_fmt          = '%A, %B %d, %Y at %H:%M:%S';
  $style             = '/css/nms.css';
  $no_content        = 0;
  $double_spacing    = 1;
  $wrap_text         = 0;
  $wrap_style        = 1;
  $send_confirmation_mail = 0;
  $confirmation_text = <<'END_OF_CONFIRMATION';
From: you@your.com
Subject: form submission

Thank you for your form submission.

END_OF_CONFIRMATION

# You may need to uncomment the line below and adjust the path.
# use lib './lib';

# USER CUSTOMISATION SECTION
# --------------------------
# Place any custom code here



# USER CUSTOMISATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)
}

use CGI::NMS::Script::FormMail;
use base qw(CGI::NMS::Script::FormMail);

use vars qw($script);
BEGIN {
  $script = __PACKAGE__->new(
     DEBUGGING              => $DEBUGGING,
     emulate_matts_code     => $emulate_matts_code,
     secure                 => $secure,
     allow_empty_ref        => $allow_empty_ref,
     max_recipients         => $max_recipients,
     mailprog               => $mailprog,
     postmaster             => $postmaster,
     referers               => [@referers],
     allow_mail_to          => [@allow_mail_to],
     recipients             => [@recipients],
     recipient_alias        => {%recipient_alias},
     valid_ENV              => [@valid_ENV],
     charset                => $charset,
     date_fmt               => $date_fmt,
     style                  => $style,
     no_content             => $no_content,
     double_spacing         => $double_spacing,
     wrap_text              => $wrap_text,
     wrap_style             => $wrap_style,
     send_confirmation_mail => $send_confirmation_mail,
     confirmation_text      => $confirmation_text,
     %more_config
  );
}

$script->request;

