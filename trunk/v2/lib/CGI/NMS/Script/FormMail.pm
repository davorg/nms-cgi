package CGI::NMS::Script::FormMail;
use strict;

use vars qw($VERSION);
$VERSION = substr q$Revision: 1.2 $, 10, -1;

use Socket;  # for the inet_aton()

use CGI::NMS::Script;
use CGI::NMS::Validator;
use CGI::NMS::Mailer::ByScheme;
use base qw(CGI::NMS::Script CGI::NMS::Validator);

=head1 NAME

CGI::NMS::Script::FormMail - FormMail CGI script

=head1 SYNOPSIS

  #!/usr/bin/perl -wT
  use strict;

  use base qw(CGI::NMS::Script::FormMail);

  use vars qw($script);
  BEGIN {
    $script = __PACKAGE__->new(
      'DEBUGGING'     => 1,
      'postmaster'    => 'me@my.domain',
      'allow_mail_to' => 'me@my.domain',
    );
  }

  $script->request;

=head1 DESCRIPTION

This module implements the NMS plugin replacement for Matt Wright's
FormMail.pl CGI script.

=head1 CONFIGURATION SETTINGS

As well as the generic NMS script configuration settings described in
L<CGI::NMS::Script>, the FormMail constructor recognises the following
configuration settings:

=over

=item C<allow_emtpy_ref>

Some web proxies and office firewalls may strip certain headers from the
HTTP request that is sent by a browser.  Among these is the HTTP_REFERER
that FormMail uses as an additional check of the requests validity - this
will cause the program to fail with a 'bad referer' message even though the
configuration seems fine.

In these cases, setting this configuration setting to 1 will stop the
program from complaining about requests where no referer header was sent
while leaving the rest of the security features intact.

Default: 1

=item C<max_recipients>

The maximum number of e-mail addresses that any single form should be
allowed to send copies of the e-mail to.  If none of your forms send
e-mail to more than one recipient, then we recommend that you improve
the security of FormMail by reducing this value to 1.  Setting this
configuration setting to 0 removes all limits on the number of recipients
of each e-mail.

Default: 5

=item C<mailprog>

The system command that the script should invoke to send an outgoing email.
This should be the full path to a program that will read a message from
STDIN and determine the list of message recipients from the message headers.
Any switches that the program requires should be provided here.

For example:

  'mailprog' => '/usr/lib/sendmail -oi -t',

An SMTP relay can be specified instead of a sendmail compatable mail program,
using the prefix C<SMTP:>, for example:

  'mailprog' => 'SMTP:mailhost.your.domain',

Default: C<'/usr/lib/sendmail -oi -t'>

=item C<postmaster>

The envelope sender address to use for all emails sent by the script.

Default: ''

=item C<referers>

This configuration setting must be an array reference, holding a list  
of names and/or IP address of systems that will host forms that refer
to this FormMail.  An empty array here turns off all referer checking.

Default: [] 

=item C<allow_mail_to>

This configuration setting must be an array reference.

A list of the email addresses that FormMail can send email to. The
elements of this list can be either simple email addresses (like
'you@your.domain') or domain names (like 'your.domain'). If it's a
domain name then any address at that domain will be allowed.

Default: []

=item C<recipients>

This configuration setting must be an array reference.

A list of Perl regular expression patterns that determine who the
script will allow mail to be sent to in addition to those set in
C<allow_mail_to>.  This is present only for compatibility with the
original FormMail script.  We strongly advise against having anything
in C<recipients> as it's easy to make a mistake with the regular
expression syntax and turn your FormMail into an open SPAM relay.

Default: []

=item C<recipient_alias>

This configuration setting must be a hash reference.

A hash for predefining a list of recipients in the script, and then
choosing between them using the recipient form field, while keeping
all the email addresses out of the HTML so that they don't get
collected by address harvesters and sent junk email.

For example, suppose you have three forms on your site, and you want
each to submit to a different email address and you want to keep the
addresses hidden.  You might set up C<recipient_alias> like this:

  %recipient_alias = (
    '1' => 'one@your.domain',
    '2' => 'two@your.domain',
    '3' => 'three@your.domain',
  );

In the HTML form that should submit to the recipient C<two@your.domain>,
you would then set the recipient with:

  <input type="hidden" name="recipient" value="2" />

Default: {}

=item C<valid_ENV>

This configuration setting must be an array reference.

A list of all the environment variables that you want to be able to
include in the email.

Default: ['REMOTE_HOST','REMOTE_ADDR','REMOTE_USER','HTTP_USER_AGENT']

=item C<date_fmt>

The format that the date will be displayed in, as a string suitable for
passing to strftime().

Default: '%A, %B %d, %Y at %H:%M:%S'

=item C<date_offset>

The emtpy string to use local time for the date, or an offset from GMT
in hours to fix the timezone independent of the server's locale settings.

Default: ''

=item C<no_content>

If this is set to 1 then rather than returning the HTML confirmation page
or doing a redirect the script will output a header that indicates that no
content will be returned and that the submitted form should not be
replaced.  This should be used carefully as an unwitting visitor may click
the submit button several times thinking that nothing has happened.

Default: 0

=item C<double_spacing>

If this is set to 1 then a blank line is printed after each form value in
the e-mail.  Change this value to 0 if you want the e-mail to be more
compact.

Default: 1

=item C<join_string>

If an input occurs multilpe times, the values are joined to make a
single string value.  The value of this configuration setting is
inserted between each value when they are joined.

Default: ' '

=item C<wrap_text>

If this is set to 1 then the content of any long text fields will be
wrapped at around 72 columns in the e-mail which is sent.  The way that
this is done is controlled by the C<wrap_style> configuration setting.

Default: 0

=item C<wrap_style>

If C<wrap_text> is set to 1 then if this is set to 1 then the text will
be wrapped in such a way that the left margin of the text is lined up
with the beginning of the text after the description of the field -
that is to say it is indented by the length of the field name plus 2.

If it is set to 2 then the subsequent lines of the text will not be
indented at all and will be flush with the start of the lines.  The
choice of style is really a matter of taste although you might find
that style 1 does not work particularly well if your e-mail client
uses a proportional font where the spaces of the indent might be
smaller than the characters in the field name.

Default: 1

=item C<force_config_*>

Configuration settings of this form can be used to fix configuration
settings that would normally be set in hidden form fields.  For
example, to force the email subject to be "Foo" irrespective of what's
in the C<subject> form field, you would set:

  'force_config_subject' => 'Foo',

Default: none set

=back

=head1 COMPILE TIME METHODS

These methods are invoked at CGI script compile time only, so long as
the new() call is placed inside a BEGIN block as shown above.

=over

=item default_configuration ()

Returns the default values for the configuration passed to the new()
method, as a key,value,key,value list.

=cut

sub default_configuration {
  return ( 
    allow_empty_ref        => 1,
    max_recipients         => 5,
    mailprog               => '/usr/lib/sendmail -oi -t',
    postmaster             => '',
    referers               => [],
    allow_mail_to          => [],
    recipients             => [],
    recipient_alias        => {},
    valid_ENV              => [qw(REMOTE_HOST REMOTE_ADDR REMOTE_USER HTTP_USER_AGENT)],
    date_fmt               => '%A, %B %d, %Y at %H:%M:%S',
    date_offset            => '',
    no_content             => 0,
    double_spacing         => 1,
    join_string            => ' ',
    wrap_text              => 0,
    wrap_style             => 1,
  );
}

=item init ()

Invoked from the new() method inherited from L<CGI::NMS::Script>,
this method performs FormMail specific initialisation of the script
object.

=cut

sub init {
  my ($self) = @_;

  if ($self->{CFG}{wrap_text}) {
    require Text::Wrap;
    import  Text::Wrap;
  }

  $self->{Valid_Env} = {  map {$_=>1} @{ $self->{CFG}{valid_ENV} }  };

  $self->init_allowed_address_list;

  $self->{Mailer} = CGI::NMS::Mailer::ByScheme->new($self->{CFG}{mailprog});
}

=item init_allowed_address_list ()

Invoked from init(), this method sets up a hash with a key for each
allowed recipient email address as C<Allow_Mail}> and a hash with a
key for each domain at which any address is allowed as C<Allow_Domain>.

=cut

sub init_allowed_address_list {
  my ($self) = @_;

  my @allow_mail = ();
  my @allow_domain = ();

  foreach my $m (@{ $self->{CFG}{allow_mail_to} }) {
    if ($m =~ /\@/) {
      push @allow_mail, $m;
    }
    else {
      push @allow_domain, $m;
    }
  }

  my @alias_targets = split(/\s*,\s*/, join ',', values %{ $self->{CFG}{recipient_alias} });
  foreach my $m (@alias_targets) {
    if ($m =~ /\@/) {
      push @allow_mail, $m;
    }
  }

  # The username part of email addresses should be case sensitive, but the
  # domain name part should not.  Map all domain names to lower case for
  # comparison.
  my (%allow_mail, %allow_domain);
  foreach my $m (@allow_mail) {
    $m =~ /^([^@]+)\@([^@]+)$/ or die "internal failure [$m]";
    $m = $1 . '@' . lc $2;
    $allow_mail{$m} = 1;
  }
  foreach my $m (@allow_domain) {
    $m = lc $m;
    $allow_domain{$m} = 1;
  }

  $self->{Allow_Mail}   = \%allow_mail;
  $self->{Allow_Domain} = \%allow_domain;
}

=back

=head1 RUN TIME METHODS

These methods are invoked at script run time, as a result of the call
to the request() method inherited from L<CGI::NMS::Script>.

=over

=item handle_request ()

Handles the core of a single CGI request, outputing the HTML success
or error page or redirect header and sending emails.

Dies on error.

=cut

sub handle_request {
  my ($self) = @_;

  $self->{Hide_Recipient} = 0;

  my $referer = $self->cgi_object->referer;
  unless ($self->referer_is_ok($referer)) {
    $self->referer_error_page;
    return;
  }

  $self->check_method_is_post    or return;

  $self->parse_form;

  $self->check_recipients( $self->get_recipients ) or return;

  my @missing = $self->get_missing_fields;
  if (scalar @missing) {
    $self->missing_fields_output(@missing);
    return;
  }

  my $date     = $self->date_string;
  my $email    = $self->get_user_email;
  my $realname = $self->get_user_realname;

  $self->send_main_email($date, $email, $realname);
  $self->send_conf_email($date, $email, $realname);

  $self->success_page($date);
}

=item date_string ()

Returns a string giving the current date and time, in the configured
format.

=cut

sub date_string {
  my ($self) = @_;

  return $self->format_date( $self->{CFG}{date_fmt},
                             $self->{CFG}{date_offset} );
}

=item referer_is_ok ( REFERER )

Returns true if the referer is OK, false otherwise.

=cut

sub referer_is_ok {
  my ($self, $referer) = @_;

  unless ($referer) {
    return ($self->{CFG}{allow_empty_ref} ? 1 : 0);
  }

  if ($referer =~ m!^https?://([^/]*\@)?([\w\-\.]+)!i) {
    my $refhost = $2;
    return $self->refering_host_is_ok($refhost);
  }
  else {
    return 0;
  }
}

=item refering_host_is_ok ( REFERING_HOST )

Returns true if the host name REFERING_HOST is on the list of allowed
referers, or resolves to an allowed IP address.

=cut

sub refering_host_is_ok {
  my ($self, $refhost) = @_;

  my @allow = @{ $self->{CFG}{referers} };
  return 1 unless scalar @allow;

  foreach my $test_ref (@allow) {
    if ($refhost =~ m|\Q$test_ref\E$|i) {
      return 1;
    }
  }

  my $ref_ip = inet_aton($refhost) or return 0;
  foreach my $test_ref (@allow) {
    next unless $test_ref =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;

    my $test_ref_ip = inet_aton($test_ref) or next;
    if ($ref_ip eq $test_ref_ip) {
      return 1;
    }
  }
}

=item referer_error_page ()

Invoked if the referer is bad, this method outputs an error page
describing the problem with the referer.

=cut

sub referer_error_page {
  my ($self) = @_;

  my $referer = $self->cgi_object->referer || '';
  my $escaped_referer = $self->escape_html($referer);

  if ( $referer =~ m|^https?://([\w\.\-]+)|i) {
    my $host = $1;
    $self->error_page( 'Bad Referrer - Access Denied', <<END );
<p>
  The form attempting to use this script resides at <tt>$escaped_referer</tt>,
  which is not allowed to access this program.
</p>
<p>
  If you are attempting to configure FormMail to run with this form,
  you need to add the following to \@referers, explained in detail in the
  README file.
</p>
<p>
  Add <tt>'$host'</tt> to your <tt><b>\@referers</b></tt> array.
</p>
END
  }
  elsif (length $referer) {
    $self->error_page( 'Malformed Referrer - Access Denied', <<END );
<p>
  The referrer value <tt>$escaped_referer</tt> cannot be parsed, so
  it is not possible to check that the referring page is allowed to
  access this program.
</p>
END
  }
  else {
    $self->error_page( 'Missing Referrer - Access Denied', <<END );
<p>
  Your browser did not send a <tt>Referer</tt> header with this
  request, so it is not possible to check that the referring page
  is allowed to access this program.
</p>
END
  }
}

=item check_method_is_post ()

Unless the C<secure> configuration setting is false, this method checks
that the request method is POST.  Returns true if OK, otherwise outputs
an error page and returns false.

=cut

sub check_method_is_post {
  my ($self) = @_;

  return 1 unless $self->{CFG}{secure};

  my $method = $self->cgi_object->request_method || '';
  if ($method ne 'POST') {
    $self->error_page( 'Error: GET request', <<END );
<p>
  The HTML form fails to specify the POST method, so it would not
  be correct for this script to take any action in response to
  your request.
</p>
<p>
  If you are attempting to configure this form to run with FormMail,
  you need to set the request method to POST in the opening form tag,
  like this:
  <tt>&lt;form action=&quot;/cgi-bin/FormMail.pl&quot; method=&quot;post&quot;&gt;</tt>
</p>
END
    return 0;
  }
  else {
    return 1;
  }
}

=item parse_form ()

Parses the HTML form, storing the results in various fields in the
C<FormMail> object, as follows:

=over

=item C<FormConfig>

A hash holding the values of the configuration inputs, such as
C<recipient> and C<subject>.

=item C<Form>

A hash holding the values of inputs other than configuration inputs.

=item C<Field_Order>

An array giving the set and order of fields to be included in the
email and on the success page.

=back

=cut

sub parse_form {
  my ($self) = @_;

  $self->{FormConfig} = { map {$_=>''} $self->configuration_form_fields };
  $self->{Field_Order} = [];
  $self->{Form} = {};

  foreach my $p ($self->cgi_object->param()) {
    if (exists $self->{FormConfig}{$p}) {
      $self->parse_config_form_input($p);
    }
    else {
      $self->parse_nonconfig_form_input($p);
    }
  }

  $self->substitute_forced_config_values;

  $self->expand_list_config_items;

  $self->sort_field_order;
  $self->remove_blank_fields;
}

=item configuration_form_fields ()

Returns a list of the names of the form fields which are used
to configure formmail rather than to provide user input, such
as C<subject> and C<recipient>.  The specially treated C<email>
and C<realname> fields are included in this list.

=cut

sub configuration_form_fields {
  qw(
    recipient
    subject
    email
    realname
    redirect
    bgcolor
    background
    link_color
    vlink_color
    text_color
    alink_color
    title
    sort
    print_config
    required
    env_report
    return_link_title
    return_link_url
    print_blank_fields
    missing_fields_redirect
  );
}

=item parse_config_form_input ( NAME )

Deals with the configuration form input NAME, incorperating it into
the C<FormConfig> field in the blessed hash.

=cut

sub parse_config_form_input {
  my ($self, $name) = @_;

  my $val = $self->strip_nonprint($self->cgi_object->param($name));
  if ($name =~ /return_link_url|redirect$/) {
    $val = $self->validate_url($val);
  }
  $self->{FormConfig}{$name} = $val;
  unless ($self->{CFG}{emulate_matts_code}) {
    $self->{Form}{$name} = $val;
  }
}

=item parse_nonconfig_form_input ( NAME )

Deals with the non-configuration form input NAME, incorperating it into
the C<Form> and C<Field_Order> fields in the blessed hash.

=cut

sub parse_nonconfig_form_input {
  my ($self, $name) = @_;

  my @vals = map {$self->strip_nonprint($_)} $self->cgi_object->param($name);
  my $key = $self->strip_nonprint($name);
  $self->{Form}{$key} = join $self->{CFG}{join_string}, @vals;
  push @{ $self->{Field_Order} }, $key;
}

=item expand_list_config_items ()

Converts the form configuration values C<required>, C<env_report> and
C<print_config> from strings of comma seperated values to arrays, and
removes anything not in the C<valid_ENV> configuration setting from
C<env_report>.

=cut

sub expand_list_config_items {
  my ($self) = @_;

  foreach my $p (qw(required env_report print_config)) {
    if ($self->{FormConfig}{$p}) {
      $self->{FormConfig}{$p} = [split(/\s*,\s*/, $self->{FormConfig}{$p})];
    }
    else {
      $self->{FormConfig}{$p} = [];
    }
  }

  $self->{FormConfig}{env_report} =
     [ grep { $self->{Valid_Env}{$_} } @{ $self->{FormConfig}{env_report} } ];
}

=item substitute_forced_config_values ()

Replaces form configuration values for which there is a forced value
configuration setting with the forced value.

=cut

sub substitute_forced_config_values {
  my ($self) = @_;

  foreach my $k (keys %{ $self->{FormConfig} }) {
    if (exists $self->{CFG}{"force_config_$k"}) {
      $self->{FormConfig}{$k} = $self->{CFG}{"force_config_$k"};
    }
  }
}

=item sort_field_order ()

Modifies the C<Field_Order> field in the blessed hash according to
the sorting scheme set in the C<sort> form configuration, if any.

=cut

sub sort_field_order {
  my ($self) = @_;

  my $sort = $self->{FormConfig}{'sort'};
  if (defined $sort) {
    if ($sort eq 'alphabetic') {
      $self->{Field_Order} = [ sort @{ $self->{Field_Order} } ];
    }
    elsif ($sort =~ /^\s*order:\s*(.*)$/s) {
      $self->{Field_Order} = [ split /\s*,\s*/, $1 ];
    }
  }
}

=item remove_blank_fields ()

Removes the names of blank or missing fields from the C<Field_Order> array
unless the C<print_blank_fields> form configuration value is true.

=cut

sub remove_blank_fields {
  my ($self) = @_;

  return if $self->{FormConfig}{print_blank_fields};

  $self->{Field_Order} = [
    grep { defined $self->{Form}{$_} and $self->{Form}{$_} !~ /^\s*$/ } 
    @{ $self->{Field_Order} }
  ];
}

=item get_recipients ()

Determins the list of configured recipients from the form inputs and the
C<recipient_alias> configuration setting, and returns them as a list.

Sets the C<Hide_Recipient> field in the blessed hash to a true value if
one or more of the recipients were aliased and so should be hidden to
foil address harvesters.

=cut

sub get_recipients {
  my ($self) = @_;

  my $recipient = $self->{FormConfig}{recipient};
  my @recipients;

  if (length $recipient) {
    foreach my $r (split /\s*,\s*/, $recipient) {
      if (exists $self->{CFG}{recipient_alias}{$r}) {
        push @recipients, split /\s*,\s*/, $self->{CFG}{recipient_alias}{$r};
        $self->{Hide_Recipient} = 1;
      }
      else {
        push @recipients, $r;
      }
    }
  }
  else {
    return $self->default_recipients;
  }

  return @recipients;
}

=item default_recipients ()

Invoked from get_recipients if no C<recipient> input is found, this method
returns the default recipient list.  The default recipient is the first email
address listed in the C<allow_mail_to> configuration setting, if any.

=cut

sub default_recipients {
  my ($self) = @_;

  my @allow = grep {/\@/} @{ $self->{CFG}{allow_mail_to} };
  if (scalar @allow > 0 and not $self->{CFG}{emulate_matts_code}) {
    $self->{Hide_Recipient} = 1;
    return ($allow[0]);
  }
  else {
    return ();
  }
}

=item check_recipients ( @RECIPIENTS )

Works through the array of recipients passed in and discards any the the script
is not configured to allow, storing the list of valid recipients in the
C<Recipients> field in the blessed hash.

Returns true if at least one (and not too many) valid recipients are found,
otherwise outputs an error page and returns false.

=cut

sub check_recipients {
  my ($self, @recipients) = @_;

  my @valid = grep { $self->recipient_is_ok($_) } @recipients;
  $self->{Recipients} = \@valid;

  if (scalar(@valid) == 0) {
    $self->bad_recipient_error_page;
    return 0;
  }
  elsif ($self->{CFG}{max_recipients} and scalar(@valid) > $self->{CFG}{max_recipients}) {
    $self->too_many_recipients_error_page;
    return 0;
  }
  else {
    return 1;
  }
}

=item recipient_is_ok ( RECIPIENT )

Returns true if the recipient RECIPIENT should be allowed, false otherwise.

=cut

sub recipient_is_ok {
  my ($self, $recipient) = @_;

  return 0 unless $self->validate_email($recipient);

  $recipient =~ /^(.+)\@([^@]+)$/m or die "regex failure [$recipient]";
  my ($user, $host) = ($1, lc $2);
  return 1 if exists $self->{Allow_Domain}{$host};
  return 1 if exists $self->{Allow_Mail}{"$user\@$host"};

  foreach my $r (@{ $self->{CFG}{recipients} }) {
    return 1 if $recipient =~ /(?:$r)$/;
    return 1 if $self->{CFG}{emulate_matts_code} and $recipient =~ /(?:$r)$/i;
  }

  return 0;
}

=item bad_recipient_error_page ()

Outputs the error page for a bad or missing recipient.

=cut

sub bad_recipient_error_page {
  my ($self) = @_;

  my $esc_rec = $self->escape_html( $self->{FormConfig}{recipient} );

  $self->error_page( 'Error: Bad or Missing Recipient', <<END );
<p>
  There was no recipient or an invalid recipient specified in the
  data sent to FormMail. Please make sure you have filled in the
  <tt>recipient</tt> form field with an e-mail address that has
  been configured in <tt>\@recipients</tt> or <tt>\@allow_mail_to</tt>.
  More information on filling in <tt>recipient/allow_mail_to</tt>
  form fields and variables can be found in the README file.
</p>
<hr size="1" />
<p>
 The recipient was: [ $esc_rec ]
</p>
END
}

=item too_many_recipients_error_page ()

Outputs the error page for too many recipients configured.

=cut

sub too_many_recipients_error_page {
  my ($self) = @_;

  $self->error_page( 'Error: Too many Recipients', <<END );
<p>
  The number of recipients configured in the form exceeds the
  maximum number of recipients configured in the script.  If
  you are attempting to configure FormMail to run with this form
  then you will need to increase the <tt>\$max_recipients</tt>
  configuration setting in the script.
</p>
END
}

=item get_missing_fields ()

Returns a list of the names of the required fields that have not been
filled in acceptably, each one possibly annotated with details of the
problem with the way the field was filled in.

=cut

sub get_missing_fields {
  my ($self) = @_;

  my @missing = ();

  foreach my $f (@{ $self->{FormConfig}{required} }) {
    if ($f eq 'email' and $self->get_user_email !~ /\@/) {
      push @missing, 'email (must be a valid email address)';
    }
    else {
      my $val = $self->{Form}{$f};
      if (! defined $val or $val =~ /^\s*$/) {
        push @missing, $f;
      }
    }
  }

  return @missing;
}

=item missing_fields_output ( @MISSING )

Produces the configured output (an error page or a redirect) for the
case when there are missing fileds.  Takes a list of the missing
fields as arguments.

=cut

sub missing_fields_output {
  my ($self, @missing) = @_;

  if ( $self->{FormConfig}{'missing_fields_redirect'} ) {
    print $self->cgi_object->redirect($self->{FormConfig}{'missing_fields_redirect'});
  }
  else {
    my $missing_field_list = join '',
                             map { '<li>' . $self->escape_html($_) . "</li>\n" }
                             @missing;
    $self->error_page( 'Error: Blank Fields', <<END );
<p>
    The following fields were left blank in your submission form:
</p>
<div class="c2">
   <ul>
     $missing_field_list
   </ul>
</div>
<p>
    These fields must be filled in before you can successfully
    submit the form.
</p>
<p>
    Please use your back button to return to the form and
    try again.
</p>
END
  }
}

=item get_user_email ()

Returns the user's email address if they entered a valid one in the C<email>
form field, otherwise returns the string C<nobody>.

=cut

sub get_user_email {
  my ($self) = @_;

  my $email = $self->{FormConfig}{email};
  $email = $self->validate_email($email);
  $email = 'nobody' unless $email;

  return $email;
}

=item get_user_realname ()

Returns the user's real name, as entered in the C<realname> form field.

=cut

sub get_user_realname {
  my ($self) = @_;

  my $realname = $self->{FormConfig}{realname};
  if (defined $realname) {
    $realname = $self->validate_realname($realname);
  } else {
    $realname = '';
  }

  return $realname;
}

=item send_main_email ( DATE, EMAIL, REALNAME )

Sends the main email.  DATE is a date string, EMAIL is the
user's email address if they entered a valid one and REALNAME
is the user's real name if entered.

=cut

sub send_main_email {
  my ($self, $date, $email, $realname) = @_;

  my $mailer = $self->mailer;
  $mailer->newmail("NMS FormMail.pm v$VERSION", $self->{CFG}{postmaster}, @{ $self->{Recipients} });

  $self->send_main_email_header($email, $realname);
  $mailer->print("\n");

  $self->send_main_email_body_header($date);

  $self->send_main_email_print_config;

  $self->send_main_email_fields;

  $self->send_main_email_footer;

  $mailer->endmail;
}

=item send_main_email_header ( EMAIL, REALNAME )

Sends the email header for the main email, not including the terminating
blank line.

=cut

sub send_main_email_header {
  my ($self, $email, $realname) = @_;

  my $subject = $self->{FormConfig}{subject} || 'WWW Form Submission';
  if ($self->{CFG}{secure}) {
    $subject = substr($subject, 0, 256);
  }
  $subject =~ s#[\r\n\t]+# #g;

  my $to = join ',', @{ $self->{Recipients} };
  my $from = (length $realname ? "$email ($realname)" : $email);

  $self->mailer->print(<<END);
X-Mailer: NMS FormMail.pm v$VERSION
To: $to
From: $from
Subject: $subject
END
}

=item send_main_email_body_header ( DATE )

Invoked after the blank line to terminate the header is sent, this method
outputs the header of the email body.

=cut

sub send_main_email_body_header {
  my ($self, $date) = @_;

  my $dashes = '-' x 75;
  $dashes .= "\n\n" if $self->{CFG}{double_spacing};

  $self->mailer->print(<<END);
Below is the result of your feedback form.  It was submitted by
$self->{FormConfig}{realname} ($self->{FormConfig}{email}) on $date
$dashes
END
}

=item send_main_email_print_config ()

If the C<print_config> form configuration field is set, outputs the configured
config values to the email.

=cut

sub send_main_email_print_config {
  my ($self) = @_;

  if ($self->{FormConfig}{print_config}) {
    foreach my $cfg (@{ $self->{FormConfig}{print_config} }) {
      if ($self->{FormConfig}{$cfg}) {
        $self->mailer->print("$cfg: $self->{FormConfig}{$cfg}\n");
	$self->mailer->print("\n") if $self->{CFG}{double_spacing};
      }
    }
  }
}

=item send_main_email_fields ()

Outputs the form fields to the email body.

=cut

sub send_main_email_fields {
  my ($self) = @_;

  my $nl = ($self->{CFG}{double_spacing} ? "\n\n" : "\n");

  foreach my $f (@{ $self->{Field_Order} }) {
    my $val = (defined $self->{Form}{$f} ? $self->{Form}{$f} : '');

    my $field_name = "$f: ";
    if ( $self->{CFG}{wrap_text} and length("$field_name$val") > 72 ) {
      $self->mailer->print( $self->wrap_field_for_email($f, $val) . $nl );
    }
    else {
      $self->mailer->print("$field_name$val$nl");
    }
  }
}

=item wrap_field_for_email ( NAME, VALUE )

Takes the name and value of a field as arguments, and returns them as
a text wraped paragraph suitable for inclusion in the main email.

=cut

sub wrap_field_for_email {
  my ($self, $name, $value) = @_;

  my $prefix = "$name: ";
  my $subs_indent = '';
  $subs_indent = ' ' x length($prefix) if $self->{CFG}{wrap_style} == 1;

  $Text::Wrap::columns = 72;

  # Some early versions of Text::Wrap will die on very long words, if that
  # happpens we fall back to no wraping.
  my $wraped;
  eval { local $SIG{__DIE__} ; $wraped = wrap($prefix,$subs_indent,$value) };
  return ($@ ? "$prefix$value" : $wraped);
}

=item send_main_email_footer ()

Sends the footer of the main email body, including any environment variables
listed in the C<env_report> configuration form field.

=cut

sub send_main_email_footer {
  my ($self) = @_;

  my $dashes = '-' x 75;
  $self->mailer->print("$dashes\n\n");

  foreach my $e (@{ $self->{FormConfig}{env_report}}) {
    if ($ENV{$e}) {
      $self->mailer->print("$e: " . $self->strip_nonprint($ENV{$e}) . "\n");
    }
  }
}

=item send_conf_email ( DATE, EMAIL, REALNAME )

Sends a confirmation email back to the user, if configured to do so and the
user entered a valid email addresss.

=cut

sub send_conf_email {
  my ($self, $date, $email, $realname) = @_;

  if ( $self->{CFG}{send_confirmation_mail} and $email =~ /\@/ ) {
    my $to = (length $realname ? "$email ($realname)" : $email);
    $self->mailer->newmail("NMS FormMail.pm v$VERSION", $self->{CFG}{postmaster}, $email);
    $self->mailer->print("To: $to\n$self->{CFG}{confirmation_text}");
    $self->mailer->endmail;
  }
}

=item success_page ()

Outputs the HTML success page (or redirect if configured) after the email
has been successfully sent.

=cut

sub success_page {
  my ($self, $date) = @_;

  if ($self->{CFG}{'redirect'}) {
    print $self->cgi_object->redirect( $self->{CFG}{'redirect'} );
  }
  else {
    $self->output_cgi_html_header;
    $self->success_page_html_preamble($date);
    $self->success_page_fields;
    $self->success_page_footer;
  }
}

=item success_page_html_preamble ( DATE )

Outputs the start of the HTML for the success page, not including the
standard HTML headers dealt with by output_cgi_html_header().

=cut

sub success_page_html_preamble {
  my ($self, $date) = @_;

  my $title = $self->escape_html( $self->{FormConfig}{'title'} || 'Thank You' );
  my $torecipient = 'to ' . $self->escape_html($self->{FormConfig}{'recipient'});
  $torecipient = '' if $self->{Hide_Recipient};
  my $attr = $self->body_attributes;

    print <<END;
  <head>
     <title>$title</title>
END

    $self->output_style_element;

    print <<END;
     <style>
       h1.title {
                   text-align : center;
                }
     </style>
  </head>
  <body $attr>
    <h1 class="title">$title</h1>
    <p>Below is what you submitted $torecipient on $date</p>
    <p><hr size="1" width="75%" /></p>
END
}

=item success_page_fields ()

Produces success page HTML output for each input field.

=cut

sub success_page_fields {
  my ($self) = @_;

  foreach my $f (@{ $self->{Field_Order} }) {
    my $val = (defined $self->{Form}{$f} ? $self->{Form}{$f} : '');
    print '<p><b>', $self->escape_html($f), ':</b> ',
                    $self->escape_html($val), "</p>\n";
  }
}

=item success_page_footer ()

Outputs the footer of the success page, including the return link if
configured.

=cut

sub success_page_footer {
  my ($self) = @_;

  print qq{<p><hr size="1" width="75%" /></p>\n};
  $self->success_page_return_link;
  print <<END;
        <hr size="1" width="75%" />
        <p align="center">
           <font size="-1">
             <a href="http://nms-cgi.sourceforge.net/">FormMail</a>
             &copy; 2001  London Perl Mongers
           </font>
        </p>
        </body>
       </html>
END
}

=item success_page_return_link ()

Outputs the success page return link if any is configured.

=cut

sub success_page_return_link {
  my ($self) = @_;

  if ($self->{FormConfig}{return_link_url} and $self->{FormConfig}{return_link_title}) {
    print "<ul>\n";
    print '<li><a href="', $self->escape_html($self->{FormConfig}{return_link_url}),
       '">', $self->escape_html($self->{FormConfig}{return_link_title}), "</a>\n";
    print "</li>\n</ul>\n";
  }
}

=item body_attributes ()

Gets the body attributes for the success page from the form
configuration, and returns the string that should go inside
the C<body> tag.

=cut

sub body_attributes {
  my ($self) = @_;

  my %attrs = (bgcolor     => 'bgcolor',
               background  => 'background',
               link_color  => 'link',
               vlink_color => 'vlink',
               alink_color => 'alink',
               text_color  => 'text');

  my $attr = '';

  foreach my $at (keys %attrs) {
    my $val = $self->{FormConfig}{$at};
    next unless $val;
    if ($at =~ /color$/) {
      $val = $self->validate_html_color($val);
    }
    elsif ($at eq 'background') {
      $val = $self->validate_url($val);
    }
    else {
      die "no check defined for body attribute [$at]";
    }
    $attr .= qq( $attrs{$at}=") . $self->escape_html($val) . '"' if $val;
  }

  return $attr;
}

=item error_page( TITLE, ERROR_BODY )

Outputs a FormMail error page, giving the HTML document the title
TITLE and displaying the HTML error message ERROR_BODY.

=cut

sub error_page {
  my ($self, $title, $error_body) = @_;

  $self->output_cgi_html_header;

  my $etitle = $self->escape_html($title);
  print <<END;
  <head>
    <title>$etitle</title>
END

  $self->output_style_element;

  print <<END;
    <style type="text/css">
    <!--
       body {
              background-color: #FFFFFF;
              color: #000000;
             }
       p.c2 {
              font-size: 80%;
              text-align: center;
            }
       th.c1 {
               text-align: center;
               font-size: 143%;
             }
       p.c3 {font-size: 80%; text-align: center}
       div.c2 {margin-left: 2em}
     -->
    </style>
  </head>
  <body>
    <table border="0" width="600" bgcolor="#9C9C9C" summary="">
      <tr bgcolor="#9C9C9C">
        <th class="c1">$etitle</th>
      </tr>
      <tr bgcolor="#CFCFCF">
        <td>
          $error_body
          <hr size="1" />
          <p class="c3">
            <a href="http://nms-cgi.sourceforge.net/">FormMail</a>
            &copy; 2001-2003 London Perl Mongers
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>
END
}

=item mailer ()

Returns an object satisfying the definition in L<CGI::NMS::Mailer>,
to be used for sending outgoing email.

=cut

sub mailer {
  my ($self) = @_;

  return $self->{Mailer};
}

=back

=head1 SEE ALSO

L<CGI::NMS::Script>

=head1 MAINTAINERS

The NMS project, E<lt>http://nms-cgi.sourceforge.net/E<gt>

To request support or report bugs, please email
E<lt>nms-cgi-support@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2003 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

