
use strict;

BEGIN {

use vars qw(@tests);
@tests = (
  # test name, input, expected output
  [ 'empty',             q{}, q{} ],
  [ 'space',             q{ }, q{ } ],
  [ 'plain',             q{hello mum},      q{hello mum} ],
  [ 'plain nl',          qq{hello mum\n},    "hello mum\n" ],
  [ 'nonprint',          qq{foo\0bar}, "foo bar" ],
  [ 'i tag',             qq{<i>hello mum\n}, "<i>hello mum\n</i>" ],
  [ 'p tag',             qq{<p>hello mum\n}, " hello mum\n" ],
  [ 'hr tag',            q{<hr>}, q{ } ],
  [ 'hr tag selfclose',  q{<hr />}, q{ } ],
  [ 'ins escape inline', q{<ins>x<p>y</p>z</ins>}, q{<ins>x y z</ins>} ],
  [ 'del escape inline', q{<del>x<p>y</p>z</del>}, q{<del>x y z</del>} ],
);

}

use Test::More tests => 2 + scalar(@tests);

use_ok( 'CGI::NMS::HTMLFilter' );

my $filt = CGI::NMS::HTMLFilter->new;
is( ref $filt, 'CGI::NMS::HTMLFilter', "new returns HTMLFilter" );

foreach my $t (@tests)
{
   my ($name, $in, $want) = @$t;
   is( $filt->filter($in, 'Inline'), $want, $name );
}

