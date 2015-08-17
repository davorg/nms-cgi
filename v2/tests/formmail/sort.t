#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw(@output_order);

my @tests = (

   # NAME       INPUTS       SORT                 PBF   OUTPUT ORDER
   [ 'empty1',  'foo',       undef,               0,    'foo'        ],
   [ 'empty2',  'foo,bar',   undef,               0,    'foo,bar'    ],
   [ 'empty0',  '0',         undef,               0,    '0'          ],
   [ 'empty02', 'foo,0',     undef,               0,    'foo,0'      ],
   [ 'alpha1',  'foo',       'alphabetic',        0,    'foo'        ],
   [ 'alpha2',  'foo,bar',   'alphabetic',        0,    'bar,foo'    ],
   [ 'alpha0',  '0',         'alphabetic',        0,    '0'          ],
   [ 'alpha02', 'foo,0',     'alphabetic',        0,    '0,foo'      ],
   [ 'subset1', 'foo,bar,x', 'order:foo',         0,    'foo'        ],
   [ 'subset2', 'foo,bar,x', 'order:x,foo',       0,    'x,foo'      ],
   [ 'all1',    'foo',       'order:foo',         0,    'foo'        ],
   [ 'all1is0', '0',         'order:0',           0,    '0'          ],
   [ 'pick0',   'x,0,foo',   'order:0',           0,    '0'          ],
   [ 'notblank', 'x,y',      'order:y,z',         0,    'y'          ],
   [ 'yesblank', 'x,y',      'order:y,z',         1,    'y,z'        ],
   [ 'notconf0', 'z',        'order:sort,z',      0,    'z'          ], 
   [ 'notconf1', 'z',        'order:sort,z',      1,    'sort,z'     ], 
   [ 'space',    'x x,yz',   'order:yz,x x',      0,    'yz,x x'     ],
   [ 'spaced',   'x x,yz',   'order: yz , x x',   0,    'yz,x x'     ],
   [ 
     'big',

     q(wooo,don't mention it,(gack),EVER!!,thanks Mrs Doyle,).
     q(your're welocme,shwoo,ahhh gwan gwan gwan,ignorethisone),

     "order:shwoo, wooo, ahhh gwan gwan gwan, thanks Mrs Doyle,
     your're welocme,
     don't mention it,



     EVER!!
     ,
     (gack)",

     0,

     q(shwoo,wooo,ahhh gwan gwan gwan,thanks Mrs Doyle,your're welocme,).
     q(don't mention it,EVER!!,(gack)),
   ],
);

use vars qw($emulate);
foreach $emulate (0, 1)
{
   my $t = NMSTest::ScriptUnderTest->new(
     SCRIPT       => 'formmail/FormMail.pl',
     REWRITERS    => [ \&rw_setup ],
     HTTP_REFERER => 'http://foo.domain/',
     CHECKER      => 'LocalChecks',
   );

   foreach my $test (@tests)
   {
      my ($name, $inputs, $sort, $pbf, $outputs) = @$test;
      next if $name eq 'notconf1' and $emulate == 0;
   
      my @args = (
                    "print_blank_fields=$pbf",
   	         (map {"$_=hic"} split /,/, $inputs),
   	      );
      unshift @args, "sort=$sort" if defined $sort;
   
      @output_order = split /,/, $outputs;
   
      $t->run_test(
        TEST_ID     => "sort e=$emulate $name",
        CGI_ARGS    => [@args, 'recipient=foo@foo.domain'],
        CHECKS      => 'xhtml nodie goodorder',
      );
   }

}

sub LocalChecks::check_goodorder
{
   my ($self) = @_;

   if ($emulate)
   {
      $self->{PAGES}{OUT}   =~ m#sort:.*order# and die "sort value shown\n";
      $self->{PAGES}{MAIL1} =~ m#sort:.*order# and die "sort value mailed\n";
   }

   my @out = $self->{PAGES}{OUT} =~ m#<p><b>([^<]+):</b>\s*(?:hic)?</p>#g;
   foreach (@out) { s/&#39;/'/g ; s/&#40;/(/g ; s/&#41;/)/g ; s/&#33;/!/g }
   array_comp("wrong fields on output HTML page", \@out, \@output_order);

   my @mail = $self->{PAGES}{MAIL1} =~ /^\s+([^:,]+)\s*: (?:hic)?\n/mg;
   array_comp("wrong fields in email body", \@mail, \@output_order);
}

sub array_comp
{
   my ($msg, $got, $want) = @_;

   if (scalar @$got == scalar @$want)
   {
      my $bad = 0;
      for my $i (0..$#$got)
      {
         $bad = 1 unless $got->[$i] eq $want->[$i];
      }
      return unless $bad;
   }

   die "$msg: got <" . join(':',@$got) . ">, wanted <" . join(':',@$want) . ">\n";
}

sub rw_setup
{
   s| +\@referers\s*=\s*qw\(.*?\)| \@referers = qw(foo.domain)| or die;
   s| +\@allow_mail_to\s*=.*?;| \@allow_mail_to = qw(foo\@foo.domain);| or die;
   s| +\$emulate_matts_code\s*=.*?;| \$emulate_matts_code = $emulate;| or die;
}

