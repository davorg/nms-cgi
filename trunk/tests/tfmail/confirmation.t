#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG1  => {
             START => \<<END,
%% NMS configuration file %%
recipient: foo\@test.domain
email_input:     email
realname_input:  realname
confirmation_template: confmail
confirmation_subject: This is the confirmation email
END
             NAME => 'default.trc',
            },
  _CONF =>  {
             START => \<<END,
%% NMS email template file %%
This is the confirmation email.

----
param.foo [{= param.foo =}]
HTTP_REFERER [{= env.HTTP_REFERER =}]
recipient [{= config.recipient =}]
----

END
             NAME => 'confmail.trt',
            },
  _SPAGE => {
             START => 'tfmail/spage.trt',
	     NAME  => 'spage.trt',
            },
  _EMAIL => {
             START => 'tfmail/email.trt',
	     NAME  => 'email.trt',
            },
);

my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'tfmail/TFmail.pl',
   REWRITERS    => [ \&rw_setup ],
   FILES        => \%files,
   CHECKER      => 'LocalChecks',
   CHECKS       => 'xhtml nodie confmail',
   HTTP_REFERER => 'http://moggie.moggie/moggie.html',
);

my @tests = (
  # TEST           REALNAME        E-MAIL               OK
  [ 'both ok',     "Mr \377 dude", 'foo@foo.domain',    1  ],
  [ 'rn empty',    "",             'foo@foo.domain',    1  ],
  [ 'email empty', "Mr \377 dude", '',                  0  ],
  [ 'email bad',   "Mr \377 dude", 'g%4g@foo.domain',   0  ],
);

use vars qw($id $r $e $ok);
foreach my $test (@tests)
{
   ($id, $r, $e, $ok) = (@$test);
   
   my @args = ('foo=moggie','moggie=moggie',"realname=$r", "email=$e");
   $t->run_test(
     CGI_ARGS => \@args,
     TEST_ID  => "confirmation $id",
   );
}

sub LocalChecks::check_confmail
{
   my ($self) = @_;

   if ($ok and not exists $self->{PAGES}{MAIL2})
   {
      die "no confirmation sent\n";
   }
   elsif (exists $self->{PAGES}{MAIL2} and not $ok)
   {
      die "confirmation sent in error\n";
   }

   return unless $ok;

   if ($self->{PAGES}{MAIL2} =~ /moggie/i)
   {
      die "user controled text interpolated into confirmation\n";
   }
   unless ($self->{PAGES}{MAIL2} =~ /\[foo\@test\.domain\]/)
   {
      die "config directive not interpolated\n";
   }
}

sub rw_setup
{
   #
   # The very old CGI.pm that comes with Perl 5.00404 generates
   # a warning on empty parameter values.  There's nothing we
   # can reasonably do about that, so we discard those warnings
   # to avoid failing the test.
   #
   my $no_cgi_warn = <<'END';

$SIG{__WARN__} = sub {
   my $warn = shift;
   warn $warn unless $warn =~ /CGI\.pm line /;
};

END
   s|^(.*?\n)|$1$no_cgi_warn|;

   my $cfg_root = $files{_CFG1}{PATH};
   $cfg_root =~ s#/[^/]+$##;

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$cfg_root';};
}


