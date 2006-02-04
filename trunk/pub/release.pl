#!/usr/bin/perl -w
use strict;
use Net::FTP;

# The username on shell.sourceforge.net under which to upload
# the stuff.
use constant USERNAME => 'username';

# The path the to root directory of your read/write working
# copy of the NMS CVS tree.
use constant CVSBASE  => '/home/username/nms/working';

# The path to a location to put temporary files when building
# a release.
use constant RELDIR   => '/home/username/nms/release';

################################################################

my $package = shift;
defined $package and $package =~ /^(\w+)$/ and -r "@{[ CVSBASE ]}/$package/MANIFEST" or die
   "usage: release.pl <package>\n";
$package = $1;

system('nmstests',$package) and die "tests failed - aborting release\n";


chdir "@{[ CVSBASE ]}/modules" or die "chdir modules: $!";
system 'cvs diff >/dev/null' and die "first get @{[ CVSBASE ]}/modules in date\n";


chdir CVSBASE or die "chdir CVSBASE: $!";
system 'pub/inline_modules.pl' or die 'pub/inline_modules failed';


chdir "@{[ CVSBASE ]}/$package" or die "chdir: $!";

system 'cvs diff >/dev/null' and die "first get @{[ CVSBASE ]}/$package in date\n";

system "cvs2cl.pl --revisions" and die;

system('rm','-rf',"@{[ RELDIR ]}/$package","@{[ RELDIR ]}/$package.tar.gz","@{[ RELDIR ]}/$package.zip") and die;
system('cp','-rp',"@{[ CVSBASE ]}/$package", RELDIR) and die;

unlink "@{[ CVSBASE ]}/$package/ChangeLog" or die "unlink ChangeLog: $!";

chdir RELDIR or die "chdir @{[ RELDIR ]}: $!";

open MAN, "<$package/MANIFEST" or die "open: $!";
chomp (my @files = <MAN>);
close MAN;

open MAINFILE, "<$files[0]" or die "open <$files[0]: $!";
my $mainfile = do { local $/ ; <MAINFILE> };
close MAINFILE;

$mainfile =~ /\$[I]d: \S+ (\d+\.\d+) / or die "can't find CVS id tag in $files[0]";
my $version = $1;

open VERSION, ">$package.VER" or die "open >$package.VER: $!";
print VERSION $version;
close VERSION;

system('tar','cf',"$package.tar",@files) and die;
system('gzip','-9',"$package.tar") and die;

foreach my $file (@files)
{
   if (-T $file)
   {
      print "unix2dos $file\n";
      system('unix2dos','-p',$file) and die;
   }
   else
   {
      print "NOT applying unix2dos to binary file $file\n";
   }
}

system("zip $package.zip -\@ <$package/MANIFEST") and die;

system('scp',
       "$package.tar.gz",
       "$package.zip",
       "$package.VER",
       USERNAME.'@shell.sourceforge.net:/home/groups/n/nm/nms-cgi/htdocs'
      ) and die;


print "uploading packages via ftp...\n";
my $ftp = Net::FTP->new('upload.sourceforge.net', Passive => 1) or die;
$ftp->login('anonymous',USERNAME.'@users.sourceforge.net') or die;
$ftp->cwd("/incoming") or die;
$ftp->binary or die;
$ftp->put("$package.tar.gz","$package.$version.tar.gz") or die;
$ftp->put("$package.zip","$package.$version.zip") or die;
$ftp->quit or die;
print "ftp done\n";

