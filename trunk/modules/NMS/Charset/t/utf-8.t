
use strict;

use vars qw(@goodutf @badutf);
BEGIN {

# Some test sequences from http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt

    @goodutf = ( "\x41\xE2\x89\xA2\xCE\x91\x2E",
                 "\xED\x95\x9C\xEA\xB5\xAD\xEC\x96\xB4",
                 "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E",
                 "\xC2\xA9",
                 "\xE2\x89\xA0",
                 "\xED\x9F\xBF",
                 "\xEE\x80\x80",
                 "\xEF\xBF\xBD",
                 "\xF4\x8F\xBF\xBF",
                 "\xF4\x90\x80\x80",
               );

    @badutf =  ( 
                 "\x2F\xC0\xAE\x2E\x2F",
                 "\xA3\xA3",
                 "\xC0\xAF",
                 "\xE0\x80\xAF",
                 "\xF0\x80\x80\xAF",
                 "\xF8\x80\x80\x80\xAF",
                 "\xFC\x80\x80\x80\x80\xAF",
                 "\xC1\xBF",
                 "\xE0\x9F\xBF",
                 "\xF0\x8F\xBF\xBF",
                 "\xF8\x87\xBF\xBF\xBF",
                 "\xFC\x83\xBF\xBF\xBF\xBF",
                 "\xC0\x80",
                 "\xE0\x80\x80",
                 "\xF0\x80\x80\x80",
                 "\xF8\x80\x80\x80\x80",
                 "\xFC\x80\x80\x80\x80\x80",
                 "\xED\xAD\xBF",
                 "\xED\xAE\x80",
                 "\xED\xAF\xBF",
                 "\xED\xB0\x80",
                 "\xED\xBE\x80",
                 "\xED\xBF\xBF",
                 "\xED\xA0\x80\xED\xB0\x80",
                 "\xED\xA0\x80\xED\xBF\xBF",
                 "\xED\xAD\xBF\xED\xB0\x80",
                 "\xED\xAD\xBF\xED\xBF\xBF",
                 "\xED\xAE\x80\xED\xB0\x80",
                 "\xED\xAE\x80\xED\xBF\xBF",
                 "\xED\xAF\xBF\xED\xB0\x80",
                 "\xED\xAF\xBF\xED\xBF\xBF",
                 "\xEF\xBF\xBE",
                 "\xEF\xBF\xBF",
                 (split //, pack 'C*', 127..255),
               );
}

use Test::More tests => 8 + 2*(@goodutf+@badutf);

use_ok ( 'CGI::NMS::Charset' );

my $cs = CGI::NMS::Charset->new('utf-8');
is( ref $cs, 'CGI::NMS::Charset', "new utf-8 returns Charset" );

is( $cs->charset, 'utf-8', "charset method works" );

my $strip = $cs->strip_nonprint_coderef;
is( ref $strip, 'CODE', "strip_nonprint_coderef returns coderef" );

my $esc = $cs->escape_html_coderef;
is( ref $esc, 'CODE', "escape_html_coderef returns coderef" );

is( $cs->escape("<Foo>\xC2\xA9&"), "&lt;Foo&gt;\xC2\xA9&amp;", "escape gets metachars" );
is( &{ $esc }(  "<Foo>\xC2\xA9&"), "&lt;Foo&gt;\xC2\xA9&amp;", "escape_html gets metachars" );
is( &{ $strip }("<Foo>\xC2\xA9&"), "<Foo>\xC2\xA9&",           "strip leaves metachars" );

foreach my $i (0..$#goodutf)
{
   is( $cs->escape($goodutf[$i]), $goodutf[$i], "escape passes goodutf $i" );
   is( &{ $strip }($goodutf[$i]), $goodutf[$i], "strip passes goodutf $i" );
}
foreach my $i (0..$#badutf)
{
   unlike( $cs->escape($badutf[$i]), qr/[\177-\377\<\>\"]/, "escape blocks badutf $i" );
   unlike( &{ $strip }($badutf[$i]), qr/[\177-\377]/,       "strip blocks badutf $i" );
}

