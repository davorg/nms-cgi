#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

use vars qw(@output_order);

my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT       => 'tfmail/TFmail.pl',
   REWRITERS    => [ \&rw_setup ],
   CHECKER      => 'LocalChecks',
);

my @tests = (

   # NAME        INPUTS       CONFIG                  OUTPUT ORDER
   [ 'empty1',   'foo',       undef,                  'foo'        ],
   [ 'empty2',   'foo,bar',   undef,                  'foo,bar'    ],
   [ 'empty0',   '0',         undef,                  '0'          ],
   [ 'empty02',  'foo,0',     undef,                  'foo,0'      ],
   [ 'alpha1',   'foo',       'sortalpha',            'foo'        ],
   [ 'alpha2',   'foo,bar',   'sortalpha',            'bar,foo'    ],
   [ 'alpha0',   '0',         'sortalpha',            '0'          ],
   [ 'alpha02',  'foo,0',     'sortalpha',            '0,foo'      ],
   [ 'subset1',  'foo,bar,x', 'sortorderfoo',         'foo'        ],
   [ 'subset2',  'foo,bar,x', 'sortorderxfoo',        'x,foo'      ],
   [ 'all1',     'foo',       'sortorderfoo',         'foo'        ],
   [ 'all1is0',  '0',         'sortorder0',           '0'          ],
   [ 'pick0',    'x,0,foo',   'sortorder0',           '0'          ],
   [ 'notblank', 'x,y',       'sortorderyz',          'y'          ],
   [ 'yesblank', 'x,y',       'sortorderyz_pbf',      'y,z'        ],
   [ 'space',    'x x,yz',    'sortordersp',          'yz,x x'     ],
   [ 
     'big',

     q(wooo,don't mention it,(gack),EVER!!,thanks Mrs Doyle,).
     q(your're welocme,shwoo,ahhh gwan gwan gwan,ignorethisone),

     'sortorderbig',

     q(shwoo,wooo,ahhh gwan gwan gwan,thanks Mrs Doyle,your're welocme,).
     q(don't mention it,EVER!!,(gack)),
   ],
);


foreach my $test (@tests)
{
   my ($name, $inputs, $config, $outputs) = @$test;


   my @args = (  
	         (map {"$_=hic"} split /,/, $inputs),
	      );
   push @args, "_config=$config" if defined $config;

   @output_order = split /,/, $outputs;

   $t->run_test(
     TEST_ID     => "sort $name",
     CGI_ARGS    => \@args,
     CHECKS      => 'xhtml nodie goodorder',
   );
}

sub LocalChecks::check_goodorder
{
   my ($self) = @_;

   $self->{PAGES}{OUT}   =~ m#sort:.*order# and die "sort value shown\n";
   $self->{PAGES}{MAIL1} =~ m#sort:.*order# and die "sort value mailed\n";

   my @out = $self->{PAGES}{OUT} =~ m#<p><b>([^<]+):</b>\s*(?:hic)?</p>#g;
   foreach (@out) { s/&#(\d+);/chr($1)/ge }
   array_comp("wrong fields on output HTML page", \@out, \@output_order);

   my @mail = $self->{PAGES}{MAIL1} =~ /^\s+([^:,]+)\s*:(?: |=20)(?:hic)?\n/mg;
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
   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$ENV{NMS_WORKING_COPY}/tests/tfmail';};
}


