
use strict;

BEGIN {

use vars qw(@tests);
@tests = (
  # test name, input, expected output

  [ 'allow a mailto'  q{<a href="mailto:foo@foo.foo">x}, q{<a href="mailto:foo@foo.foo">x</a>} ],
  [ 'malformed email',q{<a href="mailto:---!---">x}, q{<a>x</a>} ],
  [ 'mailto case'
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

