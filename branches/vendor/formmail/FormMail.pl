#!/usr/bin/perl -w
#
# $Id: FormMail.pl,v 1.1.1.1 2001-11-11 16:48:47 davorg Exp $
#
# $Log: not supported by cvs2svn $
# Revision 1.2  2001/09/18 19:26:47  dave
# Added CVS keywords.
#
#

use strict;
use POSIX 'strftime';
use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

# Configuration

my $mailprog = '/usr/lib/sendmail';

my @referers = qw(dave.org.uk 209.207.222.64 localhost);

my @recipients = (@referers);

my @valid_ENV = qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT);

my $date_fmt = '%A, %B %d, %Y at %H:%M:%S';

# End configuration

$ENV{PATH} = '/bin;/usr/bin';

my %valid_ENV;
@valid_ENV{@valid_ENV} = (1) x @valid_ENV;

&check_url;

my $date = strftime($date_fmt, localtime);

my (%Config, %Form);
my @Field_Order = &parse_form;

&check_required;

&send_mail;

&return_html;

sub check_url {
  my $check_referer;

  if ($ENV{HTTP_REFERER}) {
    foreach (@referers) {
      if ($ENV{HTTP_REFERER} =~ m|https?://([^/]*)$_|i) {
	$check_referer = 1;
	last;
      }
    }
  } else {
    $check_referer = 1;
  }

  error('bad_referer') unless $check_referer;
}

sub parse_form {

  my @fields = qw(recipient subject email realname redirect bgcolor
		  background link_color vlink_color text_color
		  alink_color title sort print_config required
		  env_report return_link_title return_link_url
		  print_blank_fields missing_fields_redirect);

  @Config{@fields} = '' x @fields;

  my @field_order;

  foreach (param) {
    if (exists $Config{$_}) {
      $Config{$_} = param($_);
    } else {
      my @vals = param($_);
      $Form{$_} = @vals == 1 ? $vals[0] : [@vals];
      push @field_order, $_;
    }
  }

  foreach (qw(required env_report print_config)) {
    if ($Config{$_}) {
      $Config{$_} =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
      $Config{$_} =~ s/(\s+)?\n+(\s+)?//g;
      $Config{$_} = [split(/,/, $Config{$_})];
    }
  }

  $Config{env_report} = [ grep { $valid_ENV{$_} } @{$Config{env_report}} ];

  return @field_order;
}

sub check_required {
  my ($require, @error);

  if ($Config{subject} =~ /(\n|\r)/m ||
      $Config{recipient} =~ /(\n|\r)/m) {
    error('no_recipient');
  }

  if ($Config{recipient}) {
    my @valid;

    foreach (split /,/, $Config{recipient}) {
      foreach my $r (@recipients) {
	if (/$r/) {
	  push @valid, $_;
	  last;
	}
      }
    }
    $Config{recipient} = join ',', @valid;

    error('no_recipient') unless $Config{recipient};
  } else {
    if (%Form) {
      error('no_recipient')
    } else {
      error('bad_referer')
    }
  }

  foreach (@{$Config{required}}) {
    if ($_ eq 'email' && !&check_email($Config{$_})) {
      push(@error, $_);
    } elsif (defined($Config{$_})) {
      push(@error, $_) unless $Config{$_};
    } else {
      push(@error,$_) unless $Form{$_};
    }
  }

  error('missing_fields', @error) if @error;
}

sub return_html {
  my ($key, $sort_order, $sorted_field);

  if ($Config{redirect}) {
    print redirect $Config{redirect};
  } else {
    print header;
    print "<html>\n <head>\n";

    my $title = $Config{title} || 'Thank You';

    print "  <title>$title}</title>\n";

    print " </head>\n <body";

    &body_attributes;

    print ">\n  <center>\n";

    print qq(<h1 align="center">$title</h1>\n);

    print "<p>Below is what you submitted to $Config{recipient} on ";
    print "$date<p><hr size=1 width=75%></p>\n";

    my @sorted_fields;
    if ($Config{sort}) {
      if ($Config{sort} eq 'alphabetic') {
	@sorted_fields = sort keys %Form;
      } elsif ($Config{sort} =~ /^order:.*,.*/) {
	$sort_order = $Config{'sort'};
	$sort_order =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
	$sort_order =~ s/(\s+)?\n+(\s+)?//g;
	$sort_order =~ s/order://;
	@sorted_fields = split(/,/, $sort_order);
      } else {
	@sorted_fields = @Field_Order;
      }
    } else {
      @sorted_fields = @Field_Order;
    }

    foreach (@sorted_fields) {
      if ($Config{print_blank_fields} || $Form{$_}) {
	print "<p><b>$_:</b> $Form{$_}</p>\n";
      }
    }

    print "<p><hr size=1 width=75%><p>\n";

    if ($Config{return_link_url} && $Config{return_link_title}) {
      print "<ul>\n";
      print qq(<li><a href="$Config{return_link_url}">$Config{return_link_title}</a>\n);
      print "</ul>\n";
    }

    print <<END_HTML_FOOTER;
        <hr size="1" width="75%">
        <p align="center"><font size="-1"><a href="http://www.dave.org.uk/scripts/nms/">FormMail</a> &copy; 2001  London Perl Mongers</font></p>
        </body>
       </html>
END_HTML_FOOTER
  }
}

sub send_mail {
  open(MAIL,"|$mailprog -oi -t")
    || die "Can't open sendmail\n";

  print MAIL "To: $Config{recipient}\n";
  print MAIL "From: $Config{email} ($Config{realname})\n";

  my $subject = $Config{subject} || 'WWW Form Submission';
  print MAIL "Subject: $subject\n\n";

  print MAIL "Below is the result of your feedback form.  It was submitted by\n";
  print MAIL "$Config{realname} ($Config{email}) on $date\n";
  print MAIL '-' x 75 . "\n\n";

  if ($Config{print_config}) {
    foreach (@{$Config{print_config}}) {
      print MAIL "$_: $Config{$_}\n\n" if $Config{$_};
    }
  }

  my @sorted_keys;
  if ($Config{sort}) {
    if ($Config{sort} eq 'alphabetic') {
      @sorted_keys = sort keys %Form;
    } elsif ($Config{sort} =~ /^order:.*,.*/) {
      $Config{sort} =~ s/(\s+|\n)?,(\s+|\n)?/,/g;
      $Config{sort} =~ s/(\s+)?\n+(\s+)?//g;
      $Config{sort} =~ s/order://;
      @sorted_keys = split(/,/, $Config{sort});
    } else {
      @sorted_keys = @Field_Order;
    }
  } else {
    @sorted_keys = @Field_Order;
  }

  foreach (@sorted_keys) {
    if ($Config{'print_blank_fields'} || defined $Form{$_}) {
      print MAIL "$_: $Form{$_}\n\n";
    }
  }

  print MAIL '-' x 75 . "\n\n";

  foreach (@{$Config{env_report}}) {
    print MAIL "$_: $ENV{$_}\n" if $ENV{$_};
  }

  close (MAIL) || die $!;
}

sub check_email {
  my $email = $_[0];

  # If the e-mail address contains:
  if ($email =~ /(@.*@)|(\.\.)|(@\.)|(\.@)|(^\.)/ ||

      # the e-mail address contains an invalid syntax.  Or, if the
      # syntax does not match the following regular expression pattern
      # it fails basic syntax verification.

      $email !~ /^.+\@(\[?)[a-zA-Z0-9\-\.]+\.([a-zA-Z0-9]+)(\]?)$/) {

    # Basic syntax requires:  one or more characters before the @ sign,
    # followed by an optional '[', then any number of letters, numbers,
    # dashes or periods (valid domain/IP characters) ending in a period
    # and then 2 or 3 letters (for domain suffixes) or 1 to 3 numbers
    # (for IP addresses).  An ending bracket is also allowed as it is
    # valid syntax to have an email address like: user@[255.255.255.0]

    # Return a false value, since the e-mail address did not pass valid
    # syntax.
    return 0;
  } else {
    # Return a true value, e-mail verification passed.
    return 1;
  }
}

sub body_attributes {
  my %attrs = (bgcolor => 'bgcolor',
	       background => 'background',
	       link_color => 'link',
	       vlink_color => 'vlink',
	       alink_color => 'alink',
	       text_color => 'text');

  foreach (keys %attrs) {
    print qq( $attrs{$_}="$Config{$_}") if $Config{$_};
  }
}

sub error { 
  my ($error, @error_fields) = @_;
  my ($host, $missing_field, $missing_field_list);

  if ($error eq 'bad_referer') {
    if ($ENV{'HTTP_REFERER'} =~ m|^https?://([\w\.]+)|i) {
      $host = $1;
      print <<END_ERROR_HTML;
Content-type: text/html

<html>
 <head>
  <title>Bad Referrer - Access Denied</title>
 </head>
 <body bgcolor="#FFFFFF" text="#000000">
   <table border="0" width="600" bgcolor="#9C9C9C" align="center">
    <tr><th><font size="+2">Bad Referrer - Access Denied</font></th></tr>
   </table>
   <table border="0" width="600" bgcolor="#CFCFCF" align="center">
    <tr><td><p>The form attempting to use FormMail
     resides at <tt>$ENV{'HTTP_REFERER'}</tt>, which is not allowed to access
     this cgi script.</p>

     <p>If you are attempting to configure FormMail to run with this form, 
     you need to add the following to \@referers, explained in detail in the 
     README file.</p>

     <p>Add <tt>'$host'</tt> to your <tt><b>\@referers</b></tt> array.</p>
     <hr size="1">
     <p align="center"><font size="-1"><a href="http://www.dave.org.uk/scripts/nms/">FormMail</a> &copy; 2001
       London Perl Mongers</font></p>
    </td></tr>
   </table>
 </body>
</html>
END_ERROR_HTML

} else {
  print <<END_ERROR_HTML;
Content-type: text/html

<html>
 <head>
  <title>FormMail</title>
 </head>
 <body bgcolor="#FFFFFF" text="#000000">
   <table border="0" width="600" bgcolor="#9C9C9C" align="center">
    <tr><th><font size="+2">FormMail</font></th></tr>
    <tr><td>Badness!</td></tr>
    <tr><th><font size="+1"><a href="http://www.dave.org.uk/scripts/nms/">FormMail</a> &copy; 2001 London Perl Mongers</font></th></tr>
   </table>
 </body>
</html>
END_ERROR_HTML

  }
} elsif ($error eq 'no_recipient') {
  print <<END_ERROR_HTML;
Content-type: text/html

<html>
 <head>
  <title>Error: Bad/No Recipient</title>
 </head>
 <body bgcolor="#FFFFFF" text="#000000">
   <table border="0" width="600" bgcolor="#9C9C9C" align="center">
    <tr><th><font size="+2">Error: Bad/No Recipient</font></th></tr>
   </table>
   <table border="0" width="600" bgcolor="#CFCFCF" align="center">
    <tr><td>There was no recipient or an invalid recipient specified in 
     the data sent to FormMail. Please make sure you have filled in the 
     <tt>recipient</tt> form field with an e-mail address that has been 
     configured in <tt>\@recipients</tt>.  More information on filling in 
     <tt>recipient</tt> form fields and variables can be found in the README 
     file.<hr size=1>
     The recipient was: [$Config{recipient}]<hr>
     <p align="center"><font size="-1">
      <a href="http://www.dave.org.uk/scripts/nms/">FormMail</a> &copy; 2001 London Perl Mongers<br></font></p>
    </td></tr>
   </table>
 </body>
</html>

END_ERROR_HTML

} elsif ($error eq 'missing_fields') {
  if ($Config{'missing_fields_redirect'}) {
    print redirect($Config{missing_fields_redirect});
  } else {
    foreach $missing_field (@error_fields) {
      $missing_field_list .= "      <li>$missing_field</li>\n";
    }

    print <<END_ERROR_HTML;
Content-type: text/html

<html>
 <head>
  <title>Error: Blank Fields</title>
 </head>
   <table border="0" width="600" bgcolor="#9C9C9C" align="center">
    <tr><th><font size="+2">Error: Blank Fields</font></th></tr>
   </table>
   <table border="0" width="600" bgcolor="#CFCFCF">
    <tr><td><p>The following fields were left blank in your submission 
      form:</p>
     <ul>
$missing_field_list
     </ul>

     <p>These fields must be filled in before you can successfully submit 
     the form.</p>
     <p>Please use your back button to return to the form and try again.</p>
     <hr size=1>
     <p align="center"><font size="-1">
      <a href="http://www.dave.org.uk/scripts/nms/">FormMail</a> &copy; 2001 London Perl Mongers
     </font></p>
    </td></tr>
   </table>
  </center>
 </body>
</html>

END_ERROR_HTML
}
}

exit;
}

