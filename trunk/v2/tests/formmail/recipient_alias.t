#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;
@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw($expected_recipient);

my $t = NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&rw_setup ],
  HTTP_REFERER => 'http://foo.domain/',
  CHECKER      => 'LocalChecks',
  CHECKS       => 'xhtml nodie somemail correct_recipient hide_secret_email',
);

my @tests = 
(
  [ 'alias 0',       '0',              'zero@secret.domain'                      ],
  [ 'alias 1',       '1',              'one-a@secret.domain,one-b@secret.domain' ],
  [ 'alias 2',       '2',              'two@secret.domain'                       ],
  [ 'direct',        'x@x.x',          'x@x.x'                                   ],
  [ 'direct 2',      'x@x.x,y@x.x',    'x@x.x,y@x.x'                             ],
  [ 'direct 2 ws',   'x@x.x, y@x.x',   'x@x.x,y@x.x'                             ],
  [ 'direct 2 ws2',  'x@x.x , y@x.x',  'x@x.x,y@x.x'                             ],
  [ 'auto allow',    'x',              'x@secret-foo.domain'                     ],
  [ 'double',        '2,0',            'two@secret.domain,zero@secret.domain'    ],
  [ 'double ws',     '2, 0',           'two@secret.domain,zero@secret.domain'    ],
  [ 'double expand', '1,2',            'one-a@secret.domain,one-b@secret.domain,two@secret.domain' ],
  [ 'mixed',         'x@x.x,0',        'x@x.x,zero@secret.domain' ],
  [ 'mixed ws',      'x@x.x, 0',       'x@x.x,zero@secret.domain' ],
  [ 'alias ws',      'z',              'z@z.z,zz@z.z'             ],
  [ 'xmas',          'z,x@x.x, 2,1',   'z@z.z,zz@z.z,x@x.x,two@secret.domain,one-a@secret.domain,one-b@secret.domain' ],
);

foreach my $test (@tests)
{
   $expected_recipient = $test->[2];
   $t->run_test(
      TEST_ID  => "recipient_alias $test->[0]",
      CGI_ARGS => ['foo=foo', "recipient=$test->[1]", "sort=order:foo,recipient"],
   );
}

sub LocalChecks::check_hide_secret_email
{
   my ($self) = @_;

   if ( $self->{PAGES}{OUT} =~ /secret/i )
   {
      die "secret email address leaked to output HTML\n";
   }
} 

sub LocalChecks::check_correct_recipient
{
   my ($self) = @_;

   $self->{PAGES}{MAIL1} =~ /^(.*?)\n\n/s or die "can't find email header\n";
   my $header = $1;
   $header =~ /^To: (.+)$/m or die "no To field in email\n";
   my $recip = $1;

   $recip =~ s/^\s+//;
   $recip =~ s/\s+$//;

   if ( $recip ne $expected_recipient )
   {
      die "Got recipient [$recip], expected [$expected_recipient]\n";
   }
}

sub rw_setup
{
   s|^# use lib .*|use lib '$ENV{NMS_WORKING_COPY}/v2/lib';|m or die;
   s|\s+\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)|;
   s|\s+\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(secret.domain other.domain x.x);|;
   s|\s+\$max_recipients\s*=.*?;| \$max_recipients = 6;|;
   s{\s+\%recipient_alias\s*=.*?;}
    {
      \%recipient_alias = (
         '0'=>'zero\@secret.domain',
         '1'=>'one-a\@secret.domain,one-b\@secret.domain',
         '2'=>'two\@secret.domain',
         'x'=>'x\@secret-foo.domain',
         'z'=>'z\@z.z, zz\@z.z',
      );
    }x;
}

