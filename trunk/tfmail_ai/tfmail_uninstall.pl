#!/usr/local/bin/perl -wT
use strict;
#
# This is an automatic uninstallation script for NMS TFmail.  You
# should only upload this script if you wish to delete all of the
# files that the TFMail auto-install creates, including config and
# log files.
#
# You may need to replace "/usr/local/bin/perl" on the first line of
# this script with a different path.  Your hosting provider or system
# administrator will be able to tell you the correct path to the Perl
# interpreter for your system.
#
# You should upload this script in ASCII mode, and you may need to
# enable execute permission after uploading it.
#
# If this script fails to run and gives an error message that looks
# like "too late for -T" then you should delete the 'T' from the end
# of the first line of the script.
#
######################################################################
#
#  NO USER SERVICEABLE PARTS BELOW THIS POINT
#
######################################################################
#

my $me = $ENV{SCRIPT_FILENAME} || $ENV{PATH_TRANSLATED};
$me =~ tr#\\#/#;
$me =~ m#^([\w\-\.\/ \:]+)$# or mydie("failed to get script filename");
$me = $1;

$me =~ m#^([\w\-\.\/ \:]+)/[^/]+$# or mydie("failed to get cgi-bin directory");
my $cgibin = $1;

if ( -d "$cgibin/.nmsai" ) {
    blatdir("$cgibin/.nmsai");
    unlink $me;
    message("The .nmsai subdirectory has been removed");
}
else {
    message("No .nmsai subdirectory found");
}

sub blatdir {
    my ($dir) = @_;

    opendir D, $dir or mydie("opendir $dir: $!");
    my @files = readdir D;
    closedir D;

    foreach my $file (@files) {
        next if $file eq ".";
        next if $file eq "..";
        next unless $file =~ /^([\w\.\-]+)\z/;
        unlink "$dir/$1";
        if (-d "$dir/$1") {
            blatdir("$dir/$1");
        }
    }

    rmdir $dir or mydie("rmdir $dir: $!");
}

sub mydie {
    my ($why) = @_;

    message("Error: $why");
    exit;
}

sub message {
    my ($msg) = @_;

    print "Content-type: text/plain\r\n\r\n$msg\n";
}

