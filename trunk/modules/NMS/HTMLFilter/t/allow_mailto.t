
use strict;

BEGIN {

use vars qw(@tests);
@tests = (
  # test name, input, expected output

  [ 'allow a mailto', q{<a href="mailto:foo@foo.foo">x}, q{<a href="mailto:foo&#64;foo.foo">x</a>} ],
  [ 'malformed email',q{<a href="mailto:---!---">x}, q{<a>x</a>} ],
  [ 'mailto case',    q{<a href="MAILTO:fooFoo@Foo.foo">}, q{<a href="mailto:fooFoo&#64;Foo.foo"></a>} ],
  [ 'no img',         q{<img src="http://foo.foo/foo.png" />}, q{ } ],
  [ 'no a href',      q{<a href="http://foo.foo/foo.html">x</a>}, q{<a>x</a>} ],
);

}

use Test::More tests => 2 + scalar(@tests);

use_ok( 'CGI::NMS::HTMLFilter' );

my $filt = CGI::NMS::HTMLFilter->new( allow_a_mailto => 1 );
is( ref $filt, 'CGI::NMS::HTMLFilter', "new returns HTMLFilter" );

foreach my $t (@tests)
{
   my ($name, $in, $want) = @$t;
   is( $filt->filter($in), $want, $name );
}

