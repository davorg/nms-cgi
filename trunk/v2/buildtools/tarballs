#!/usr/bin/perl -w
use strict;

=head1 NAME

tarballs.pl - generate NMS .tar.gz and .zip packages

=head1 SYNOPSYS

  tarballs.pl <TARBALL_DIR> <NAME> <PACKAGE_FILE, ...>

=head1 DESCRIPTION

Builds .tar.gz and .zip archives of an NMS package, storing the
archives as F<$TARBALL_DIR/$NAME.tar.gz> and
F<$TARBALL_DIR/$NAME.zip>.  

The PACKAGE_FILE arguments list the files to go in the archive,
relative to the current directory.  The first element in the path
of each package file will be replaced by the package name, so if
NAME is C<formmail> then the package file F<.pkg/README> will be
packaged as F<formmail/README> in the archive.  All package files
must have the same first path element.

A F<MANIFEST> file is automatically generated and added to the
archives.

=cut

my $tarball_dir = shift;
$tarball_dir =~ m#^([\w\-\.\/]+)$# or die "bad TARBALL_DIR [$tarball_dir]";
$tarball_dir = $1;

my $name = shift;
$name =~ /^([\w\-]+)$/ or die "bad NAME [$name]";
$name = $1;

my @files = @ARGV;
defined $files[0] or die "no package files specified";

$files[0] =~ m#^([\w\.]+)/# or die "bad first path elt in [$files[0]]";
my $prefix = $1;

foreach (@files) {
    s#^\Q$prefix\E/## or die "file [$_] lacks [$prefix] prefix";
    m#^([\w\-\.\/]+)$# or die "bad character in file [$_]";
    $_ = $1;
}

system('rm','-rf','--',"$tarball_dir/$name","$tarball_dir/$name.tar.gz","$tarball_dir/$name.zip")
   and die "rm failed";

mkdir "$tarball_dir/$name", 0755 or die "mkdir $tarball_dir/$name: $!";

my $files = join ' ', map "'$_'", @files;
system "(cd '$prefix' && tar cf - -- $files) | (cd '$tarball_dir/$name' && tar xf -)"
   and die "package copy via tar failed";

open MANIFEST, ">$tarball_dir/$name/MANIFEST" or die "open: $!";
foreach (@files) {
    print MANIFEST "$name/$_\n";
}
close MANIFEST;

chdir $tarball_dir or die "chdir $tarball_dir: $!";

system('tar','cf',"$name.tar",$name) and die "tar failed";
system('gzip','-9',"$name.tar") and die "gzip failed";

foreach my $file (@files) {
    if (-T $file) {
        unix2dos("$name/$file");
    }
}

system("zip '$name.zip' -\@ <$name/MANIFEST") and die "zip failed";

system('rm','-rf',$name);

sub unix2dos {
    my ($filename) = @_;

    open IN, "<$filename" or die "open <$filename: $!";
    my $data = do { local $/ ; <IN> };
    close IN;

    $data =~ s#\r?\n#\r\n#g;

    open OUT, ">$filename" or die "open >$filename: $!";
    print OUT $data or die "write to $filename: $!";
    close OUT or die "close >$filename: $!";
}

