#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

use vars qw($tests);
{
   local $/;
   $tests = <DATA>;
}

NMSTest::ScriptUnderTest->new(
  SCRIPT       => 'formmail/FormMail.pl',
  REWRITERS    => [ \&install_tests ],
  TEST_ID      => 'check_url_valid unit tests',
  CHECKS       => 'nodie subtests',

)->run_test;

sub install_tests
{
   s#^check_url\(\);#unitTest\(\);#m;
   s#(__END__|\z)#$tests$1#;
}

__END__

sub request {
    my ($self) = @_;

    my @unittests = (

    [ 0, '' ],
    [ 0, ':' ],
    [ 0, '://' ],
    [ 0, 'http://' ],
    [ 1, 'http://www.perl.com' ],
    [ 1, 'http://www.perl.com/' ],
    [ 0, 'foo://www.perl.com' ],
    [ 0, 'foo://www.perl.com/' ],
    [ 0, ' http://www.perl.com/' ],
    [ 1, 'https://www.perl.com/' ],
    [ 1, 'http://www.perl.domain' ],
    [ 1, 'http://www.perl.domain/' ],
    [ 1, 'https://www.perl.domain/' ],
    [ 1, 'http://intranet' ],
    [ 1, 'http://intranet/' ],
    [ 1, 'https://intranet/' ],
    [ 1, 'ftp://intranet/' ],
    [ 1, 'ftp://ftp.gnu.org/README' ],
    [ 1, 'http://foo.x/foo/foo/foo.htm' ],
    [ 1, 'http://foo.x/foo/foo/foo.cgi?adsf=%82as' ],
    [ 1, 'http://foo.x/foo/foo/foo.cgi/pah?adsf=%82as' ],
    [ 0, 'http://foo.x%82foo' ],
    [ 1, 'http://foo.x?%82foo' ],
    [ 1, 'http://foo.x/?%82foo' ],
    [ 0, 'http://foo.<.x/' ],
    [ 1, 'http://FOO.X/foo', ],
    [ 1, 'https://FOO.X/foo', ],
    [ 1, 'ftp://FOO.X/foo', ],
    [ 0, 'http://foo.x:' ],

    [ 0, 'http://foo.x/foo?foo=:bar' ],
    [ 0, 'http://foo.x:8080:8080' ],
    [ 0, 'http://:8080/foo' ],
    [ 1, 'http://foo.x:8080' ],
    [ 1, 'http://foo.x:8080/' ],
    [ 1, 'https://foo.x:8080' ],
    [ 1, 'https://foo.x:8080/' ],
    [ 1, 'ftp://foo.x:8080' ],
    [ 1, 'ftp://foo.x:8080/' ],
    [ 1, 'http://foo.x:8080?foo=foo' ],
    [ 1, 'http://foo.x:8080/?foo=foo' ],
    [ 1, 'http://foo.x:8080/foo.cgi?foo=foo' ],

    [ 1, '/html/foo.htm' ],
    [ 1, '/' ],
    [ 0, '../html/foo.html' ],
    );

    foreach my $t (@unittests)
    {
        my $result = ($self->validate_url($t->[1]) ? 1 : 0);
	if ( $result != $t->[0] )
	{
	    warn "URL $t->[1] validity $result, should be $t->[0]\n";
        }
    }
 
    print "All subtests ran\n";
    exit 0;
}

