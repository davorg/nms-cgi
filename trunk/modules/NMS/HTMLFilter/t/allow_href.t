
use strict;

BEGIN {

use vars qw(@tests);
@tests = (
  # test name, input, expected output
  [ 'a href normal',  q{<a href="http://foo.domain/foo.html">z</a>}, q{<a href="http://foo.domain/foo.html">z</a>} ],
  [ 'a href bare',    q{<a href="http://foo.domain/foo.html">}, q{<a href="http://foo.domain/foo.html"></a>} ],
  [ 'a href https' ,  q{<a href="https://foo.domain/foo.html">}, q{<a href="https://foo.domain/foo.html"></a>} ],
  [ 'href badurl',    q{<a href="javascript:alert(1)">}, q{<a></a>} ],

  [ 'no img',         q{<img src="http://foo.foo/foo.png" />}, q{ } ],
  [ 'no a mailto',    q{<a href="mailto:foo@foo.foo">x</a>}, q{<a>x</a>} ],
);

}

use Test::More tests => 2 + scalar(@tests);

use_ok( 'CGI::NMS::HTMLFilter' );

my $filt = CGI::NMS::HTMLFilter->new( allow_href => 1 );
is( ref $filt, 'CGI::NMS::HTMLFilter', "new returns HTMLFilter" );

foreach my $t (@tests)
{
   my ($name, $in, $want) = @$t;
   is( $filt->filter($in), $want, $name );
}

