package NMSDevel::SourceFileSet::Package;
use strict;

use NMSDevel::SourceFileSet;
use base qw(NMSDevel::SourceFileSet);

=head1 NAME

NMSDevel::SourceFileSet::Package - source files for an NMS package

=head1 DESCRIPTION

This class encapsulates the set of NMS source files that contribute to
a particular package of a particular NMS script.

=head1 CONSTRUCTORS

=over

=item new ( BASEPATH, NAME, SCRIPT )

BASEPATH is the full filesystem path to the F</v2> directory in a working
copy against the NMS CVS tree, and NAME is the name of this package, e.g.
C<formmail_compat>.

SCRIPT is a reference to an L<NMSDevel::SourceFileSet::Script> object that
encapsulates the set of source files that are common to all packages of
this script.

=back

=head1 METHODS

=over

=item version_string ()

Returns the script version (a string such as C<3.12c1>) as read from the
C<VERSION> file in the package directory.

=item source_files ()

Returns a list of the source files that contribute to the package, as read
from the C<SOURCES> file in the package directory.  Source files common to
all packages of this script are not included.

=item release ()

Ensures that all working files in the set are in date with respect to CVS,
and assigns a new version number and updates the package F<VERSION> file if
there have been changes since the last version increment.

=item is_package ()

Returns 1, indicating that objects of this class encapsulate a single NMS
package.

=cut

sub is_package { 1 }

=item upstream ()

Returns a reference to the 'upstream' source file set object,  which
encompassing the source files common to all packages of this script.

=cut

sub upstream {
    my ($self) = @_;

    return $self->{UPSTREAM};
}

=item all_sourcefiles ()

Returns a list of all sourcefiles that contribute to this package, including
those from the upstream L<NMSDevel::SourceFileSet::Script> object that are
common to all packages of this script.

=cut

sub all_sourcefiles {
    my ($self) = @_;

    $self->sourcefiles, $self->upstream->sourcefiles;
}

=item write_changelog ()

Creates the C<ChangeLog> file in the package directory, from CVS log entries.

=cut

sub write_changelog {
    my ($self) = @_;

    my $pid = fork;
    defined $pid or die "fork: $!";
    if ($pid) {
        wait;
    }
    else {
	chdir $self->basepath or die "chdir: $!";
	open STDOUT, ">".$self->srcdir."/ChangeLog" or die "open: $!";
	exec('buildtools/cvs2cl.pl', '--stdout', $self->all_sourcefiles);
    }
}

=item archive_name ()

Returns the name of the leading directory in any archive of this
package, e.g. C<formmail_compat-3.12c4>.

=cut

sub archive_name {
    my ($self) = @_;

    $self->{NAME} . '-' . $self->version_string;
}

=item archive_path ()

Returns the full filesystem path to the archive directory used when the
archive is under construction.

=cut

sub archive_path {
    my ($self) = @_;

    $self->srcpath . "/" . $self->archive_name;
}

=item gererate_tarballs ()

Builds C<.tar.gz> and C<.zip> packages for this package, using the
file F<MANIFEST> in the package directory to determine which files to
include.

=cut

sub generate_tarballs {
    my ($self) = @_;
 
    my $src_path = $self->srcpath;
    my $arc_name = $self->archive_name;
    my $arc_path = $self->archive_path;

    system('rm', '-rf', $arc_path, "$arc_path.tar.gz", "$arc_path.zip")
        and die "rm failed";

    mkdir $arc_path, 0755 or die "mkdir: $!";
    
    my $manifest_in = IO::File->new("$src_path/MANIFEST") or die "open $src_path/MANIFEST: $!";
    my $manifest_out = IO::File->new(">$arc_path/MANIFEST") or
        die "open $arc_path/MANIFEST: $!";

    my @files = ();
    foreach my $line (<$manifest_in>) {
        next if $line =~ /^\s*$/;
	$line =~ m#^([\w\-\.\/]+)$# or die "bad MANIFEST line [$line]";
	my $file = $1;
        push @files, $file;

        if ($file =~ m#(.+)/[^/]+$#) {
            my $dirname = $1;
            system('mkdir', '-p', "$arc_path/$dirname") and die "mkdir -p failed";
        }

	$file eq 'MANIFEST'                                                              or
	$self->_file_into_package("$src_path/$file",                  "$arc_path/$file") or
	$self->_file_into_package($self->upstream->srcpath."/$file",  "$arc_path/$file") or
	$self->_file_into_package($self->basepath."/$file",           "$arc_path/$file") or
	# Allow ChangeLog to be missing so that packages can be built and tests run
	# against them without access to CVS.
	$file eq 'ChangeLog'                                                             or
        die "can't generate package file [$file]";

	$manifest_out->print("$arc_name/$file\n");
    }
    $manifest_out->close or die "close: $!";
    $manifest_in->close  or die "close: $!";

    system "cd $src_path && (tar cf - $arc_name | gzip -9 >$arc_name.tar.gz)"
       and die "tar/gzip failed";

    foreach my $file (@files) {
        if (-T $file) {
            $self->_unix2dos("$arc_path/$file");
        }
    }

   system("cd $src_path && (zip '$arc_name.zip' -\@ <$arc_name/MANIFEST)")
       and die "zip failed";

   system('rm', '-rf', $arc_path) and die "rm failed";

   my $cl = IO::File->new("<$src_path/ChangeLog");
   if ($cl) {
       my $lastmod = <$cl>;
       $cl->close;
       $lastmod =~ /^(\d{4}-\d\d-\d\d \d\d:\d\d)\s/ or die "bad ChangeLog";
       $lastmod = $1;
       
       my $lm = IO::File->new(">$src_path/".$self->name.".LASTMOD") or die "open: $!";
       $lm->print("$lastmod\n");
       $lm->close or die "close: $!";
   }

   my $ver = IO::File->new(">$src_path/".$self->name.".VERSION") or die "open: $!";
   $ver->print( $self->version_string, "\n" );
   $ver->close or die "close: $!";
}

=item run_tests_against_package ()

Runs the regression tests for this script against the contents of an archive
previously created with the generate_tarballs() method.

=cut

sub run_tests_against_package {
    my ($self) = @_;

    my $src_path = $self->srcpath;
    my $arc_name = $self->archive_name;
    my $arc_path = $self->archive_path;
    
    system "cd $src_path && gzip -dc $arc_name.tar.gz | tar xvf -" and die;
    system "cd $arc_path && ln -s . ".$self->upstream->name       and die;
    local $ENV{NMSTEST_USE_LIB} = "$arc_path/lib";
    local $ENV{NMSTEST_SRCDIR} = $arc_path;
    system($self->basepath."/buildtools/run_tests", $self->upstream->name) and die;
}

=back

=head1 PRIVATE METHODS

=over

=item _file_into_package( SOURCEFILE, DESTFILE )

Tries to build the package file DESTFILE from SOURCEFILE.  Returns true on
success or falas on failure.

=cut

sub _file_into_package {
    my ($self, $sourcefile, $destfile) = @_;

    if (-r $sourcefile) {
        system('cp', $sourcefile, $destfile) and die "cp failed";
        return 1;
    }
    elsif (-x "$sourcefile.in") {
        my $srcpath = $self->srcpath;
        system "cd $srcpath && ($sourcefile.in >$destfile)" and die "$sourcefile.in failed at [$srcpath] [$destfile]";
	chmod 0755, $destfile if $destfile =~ m#\.pl$#;
        return 1;
    }
    else {
        return 0;
    }
}
             
=item _unix2dos ( FILENAME )

Modifies FILENAME in place to convert UNIX line endings to DOS line endings.

=cut

sub _unix2dos {
    my ($self, $filename) = @_;

    my $in = IO::File->new("<$filename") or die "open <$filename: $!";
    my @lines = <$in>;
    $in->close or die "close <$filename: $!";

    my $out = IO::File->new(">$filename") or die "open >$filename: $!";
    foreach my $line (@lines) {
        $line =~ s#\r?\n#\r\n#;
	$out->print($line);
    }
    $out->close or die "close >$filename: $!";
}

=back


=cut

1;

