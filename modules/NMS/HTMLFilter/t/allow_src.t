
use strict;

BEGIN {

use vars qw(@tests);
@tests = (
  # test name, input, expected output
  [ 'img normal',     q{<img src="http://foo.domain/foo.png" />}, q{<img src="http://foo.domain/foo.png" />} ],
  [ 'img https' ,     q{<img src="https://foo.domain/foo.png" />}, q{<img src="https://foo.domain/foo.png" />} ],
  [ 'img badurl',     q{<img src="javascript:alert(1)" />}, q{<img />} ],
  [ 'img autoclose',  q{<img src=http://foo.foo/foo.png>}, q{<img src="http://foo.foo/foo.png" />} ],
  [ 'img align',      q{<img align="left" src="http://foo.foo/foo.png" />}, q{<img align="left" src="http://foo.foo/foo.png" />} ],
  [ 'alt text',       q{<img src='http://foo.foo/foo.png' alt="This is a picture">},
                      q{<img src="http://foo.foo/foo.png" alt="This is a picture" />} ],
  [ 'alt nonprint',   qq{<img src='http://foo.foo/foo.png' alt="\001">},
                      q{<img src="http://foo.foo/foo.png" alt=" " />} ],
  [ 'esc nonprint',   q{<img src='http://foo.foo/foo.png' alt="x&#1;y">},
                      q{<img src="http://foo.foo/foo.png" alt="x y" />} ],
  [ 'tag in alt',     q{<img src='http://foo.foo/foo.png' alt="<foo>">},
                      q{<img src="http://foo.foo/foo.png" alt="&lt;foo&gt;" />} ],
  [ 'esc tag in alt', q{<img src='http://foo.foo/foo.png' alt="&lt;foo&gt;">},
                      q{<img src="http://foo.foo/foo.png" alt="&lt;foo&gt;" />} ],
  [ 'numeric esc',    q{<img src='http://foo.foo/foo.png' alt="&#60;foo&#62;">},
                      q{<img src="http://foo.foo/foo.png" alt="&lt;foo&gt;" />} ],
  [ 'amp in alt',     q{<img alt="&">}, q{<img alt="&amp;" />} ],
  [ 'esc amp in alt', q{<img alt="&amp;">}, q{<img alt="&amp;" />} ],
  [ 'double esc amp', q{<img alt="&amp;amp;">}, q{<img alt="&amp;amp&#59;" />} ],
  [ 'q in alt',       q{<img src='http://foo.foo/foo.png' alt="'">},
                      q{<img src="http://foo.foo/foo.png" alt="&#39;" />} ],
  [ 'qq in alt',      q{<img src='http://foo.foo/foo.png' alt='"'>},
                      q{<img src="http://foo.foo/foo.png" alt="&quot;" />} ],
  [ 'no a href',      q{<a href="http://foo.foo/foo.html">x</a>}, q{<a>x</a>} ],
  [ 'no a mailto',    q{<a href="mailto:foo@foo.foo">x</a>}, q{<a>x</a>} ],
);

}

use Test::More tests => 2 + scalar(@tests);

use_ok( 'CGI::NMS::HTMLFilter' );

my $filt = CGI::NMS::HTMLFilter->new( allow_src => 1 );
is( ref $filt, 'CGI::NMS::HTMLFilter', "new returns HTMLFilter" );

foreach my $t (@tests)
{
   my ($name, $in, $want) = @$t;
   is( $filt->filter($in), $want, $name );
}

