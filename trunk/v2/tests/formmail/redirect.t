#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($expect_redirect);

my $t = NMSTest::ScriptUnderTest->new(
    SCRIPT       => 'formmail/FormMail.pl',
    REWRITERS    => [ \&rw_setup ],
    HTTP_REFERER => 'http://foo.domain/',
    CHECKER      => 'LocalChecks',
    CHECKS       => 'nodie redirect',
);

$expect_redirect = "http://www.foo.domain/thanks.html";
$t->run_test(
    TEST_ID => 'redirect',
    CGI_ARGS => ["redirect=$expect_redirect", 'foo=foo'],
);
  
$expect_redirect = "http://www.foo.domain/missing.html";
$t->run_test(
    TEST_ID => 'missing_fields_redirect',
    CGI_ARGS => ["missing_fields_redirect=$expect_redirect", 'required=foo'],
);
  
sub LocalChecks::check_redirect {
    my ($self) = @_;

    unless ($self->{PAGES}{OUT} =~ /^Location: \Q$expect_redirect\E\r?\n/m) {
        die "expected redirect to [$expect_redirect] in [$self->{PAGES}{OUT}]";
    }
}

sub rw_setup
{
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
}

