#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);


use vars qw($double_spacing);
foreach $double_spacing (0, 1)
{
   NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     HTTP_REFERER => 'http://foo.domain/',
     CHECKER      => 'LocalChecks',
     CHECKS       => 'xhtml nodie double_spacing',
     TEST_ID      => "double_spacing $double_spacing",
     CGI_ARGS     => [qw(one=one two=two three=three)],
   )->run_test;
}
   
sub LocalChecks::check_double_spacing
{
   my ($self) = @_;

   $self->{PAGES}{OUT} =~ m{ 
                              <p><b>one:</b>[ ]one</p>     \s+
                              <p><b>two:</b>[ ]two</p>     \s+
                              <p><b>three:</b>[ ]three</p> \s+
                           }x or die "HTML output wrong";

   if ($double_spacing)
   {

      $self->{PAGES}{MAIL1} =~ m<
---------------------------------------------------------------------------


one: one

two: two

three: three

---------------------------------------------------------------------------
> or die "mail bad"; 

   }
   else
   {

      $self->{PAGES}{MAIL1} =~ m<
---------------------------------------------------------------------------
one: one
two: two
three: three
---------------------------------------------------------------------------
> or die "mail bad"; 

   }
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s| +\$double_spacing\s*=.*?;| \$double_spacing = $double_spacing;| or die;
}

