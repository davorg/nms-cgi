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
  TEST_ID      => 'body_attributes unit tests',
  CHECKS       => 'nodie subtests',

)->run_test;

sub install_tests
{
   s#^check_url\(\);#unitTest\(\);#m;
   s#\z#$tests#;
}

__END__

sub unitTest
{
    my @attr = ( [ bgcolor     => 'bgcolor' ],
                 [ link_color  => 'link'    ],
                 [ vlink_color => 'vlink'   ],
                 [ alink_color => 'alink'   ],
                 [ text_color  => 'text'    ],
               );
                   
    my @background_tests = (

    [ 1, '/images/foo.png' ],
    [ 1, 'http://foo.domain/images/foo.png' ],
    [ 1, 'http://images-on-the-fly.foo.domain?foo' ],
    [ 0, 'huh ?' ],
    [ 0, 'foo://foo' ],
    [ 0, "\xff\xe7\x9b-foo" ],
    
    );

    foreach my $t (@background_tests)
    {
        %Config = ( background => $t->[1] );
        my $ok = (body_attributes() =~ /background/ ? 1 : 0);
        if ($ok != $t->[0])
        {
            warn "body background [$t->[1]] ",
                 ($ok ? 'accepted' : 'rejected'),
                 " in error\n";
        }
    }

    my @color_tests = (

    [ 1, 'red' ],
    [ 1, 'RED' ],
    [ 1, 'ReD' ],
    [ 1, '#ff00ff' ],
    [ 1, '#FF00FF' ],
    [ 1, '#1a1b1c' ],
    [ 1, '#1d1e1f' ],
    [ 1, '#3A3B3C' ],
    [ 1, '#3D3E3F' ],
    [ 1, '#000000' ],
    [ 0, 'alovelyshadeofpingwithaslighthintofgreenaroundtheedgesandsubtleovertonesofyellow' ],
    [ 0, '#red' ],
    [ 0, '#red' ],
    [ 0, '#00' ],
    [ 0, '#00000000' ],
    
    );

    foreach my $t (@color_tests)
    {
        foreach my $attrib (@attr)
        {
            %Config = ( $attrib->[0],  $t->[1] );
            my $ok = (body_attributes() =~ /$attrib->[1]/ ? 1 : 0);
            if ($ok != $t->[0])
            {
                warn "body $attrib->[0] [$t->[1]] ",
                     ($ok ? 'accepted' : 'rejected'),
                     " in error\n";
            }
        }
    }
    
    print "All subtests ran\n";
    exit 0;
}

