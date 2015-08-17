package NMSDevel::SourceFileSet;
use strict;

use IO::File;

=head1 NAME

NMSDevel::SourceFileSet - set of source files

=head1 DESCRIPTION

This module provides the underlying implementation for both
L<NMSDevel::SourceFileSet::Script> and L<NMSDevel::SourceFileSet::Package>.

=head1 CONSTUCTORS

=over

=item new ( BASEPATH, NAME [,UPSTREAM] )

Implements the new() method of both L<NMSDevel::SourceFileSet::Script>
and L<NMSDevel::SourceFileSet::Package>, using the is_package() method
to do the right thing in both cases.

=cut

sub new {
    my ($pkg, $basepath, $name, $upstream) = @_;

    my $sourcedir;
    if ($pkg->is_package) {
	$sourcedir = "package/$name";
	defined $upstream or die "missing upstream script file set";
    }
    else {
	$sourcedir = "src/$name";
	defined $upstream and die "unexpected upstream script file set";
    }

    my $self = bless {
      BASEPATH  => $basepath,
      NAME      => $name,
      SOURCEDIR => $sourcedir,
      UPSTREAM  => $upstream,
    }, ref $pkg || $pkg;

    $self->_read_sources_file || return undef;
    $self->_read_version_file || return undef;

    return $self;
}

=back

=head1 METHODS

=over

=item name ()

Returns the name that was passed to new().

=cut

sub name {
    my ($self) = @_;

    $self->{NAME};
}

=item basepath ()

Returns the basepath that was passed to new().

=cut

sub basepath {
    my ($self) = @_;

    $self->{BASEPATH};
}

=item srcdir ()

Returns the source directory of the set, relative to the basepath.

=cut

sub srcdir {
    my ($self) = @_;

    $self->{SOURCEDIR};
}

=item srcpath ()

Returns the full filesystem path ot the source directory of the set.

=cut

sub srcpath {
    my ($self) = @_;

    "$self->{BASEPATH}/$self->{SOURCEDIR}";
}

=back

=cut

sub version_string {
    my ($self) = @_;

    sprintf '%d.%.2d%s%s', $self->{MAJOR}, $self->{MINOR}, $self->{PKGSTR}, $self->{PKGVER};
}

sub sourcefiles {
    my ($self) = @_;

    return @{ $self->{SOURCEFILES} };
}

sub release {
    my ($self) = @_;

    $self->_assert_cvs_indate;

    return unless $self->_version_change_needed;
    my $newver = $self->version_string;

    # If this is a pure numeric version, we'll make the CVS revision of
    # the VERSION file match it.
    my @args = ();
    $newver =~ /^\d+\.\d+$/ and @args = ('-r', $newver);

    $self->_write_version_file;
    $self->_cvs_command('ci', @args,
                        '-m', "Released $self->{NAME} $newver",
                        "$self->{SOURCEDIR}/VERSION"
                       );
}

=head1 PRIVATE METHODS

The following methods should only be used within this module.

=over

=item _assert_cvs_indate ()

Calls die unless the working copies of all files in the set are indate with
respect to CVS.

=cut

sub _assert_cvs_indate {
    my ($self) = @_;

    return if $self->{CVS_INDATE_DONE};

    my $status = $self->_cvs_command('-n', '-q', 'update', $self->sourcefiles);

    unless (!defined $status or $status =~ /^\s*$/) {
        die "First get the following files in sync with CVS:\n$status";
    }

    $self->{CVS_INDATE_DONE} = 1;
}

=item _version_change_needed ()

If source files have changed since the last version increment, increments
the internal representation of the current version and returns true, otherwise
returns false.

=cut

sub _version_change_needed {
    my ($self) = @_;

    if ($self->is_package) {
        my $upver = $self->upstream->version_string;
	$upver =~ /^(\d+)\.(\d+)$/ or die "bad upstream version $upver";
	if ($1 > $self->{MAJOR} or $2 > $self->{MINOR}) {
	    $self->{MAJOR} = $1;
	    $self->{MINOR} = $2;
	    $self->{PKGVER} = 1;
            return 1;
        }
    }

    if ($self->_version_file_is_newest) {
        return 0;
    }
    else {
	if ($self->is_package) {
	    $self->{PKGVER}++;
	}
	else {
	    $self->{MINOR}++;
	}
	return 1;
    }
}
   
=item _version_file_is_newest ()

Returns true is the F<VERSION> file is the newest file in the set.

=cut

sub _version_file_is_newest {
    my ($self) = @_;

    my $version_path = $self->srcpath . "/VERSION";
    my $version_mtime = (stat $version_path)[9];

    foreach my $src ($self->sourcefiles) {
        if ( (stat "$self->{BASEPATH}/$src")[9] > $version_mtime ) {
            return 0;
        }
    }

    return 1;
}

=item _read_sources_file ()

Reads the F<SOURCES> file and builds the internal list of sources.

=cut

sub _read_sources_file {
    my ($self) = @_;

    my $in = IO::File->new("<$self->{BASEPATH}/$self->{SOURCEDIR}/SOURCES")
       or return undef;

    my @files;
    foreach my $line (<$in>) {
        next if $line =~ /^\s*$/;
        $line =~ m#^([\w\-\.\/]+)$# or die "bad line [$line] in $self->{SOURCEDIR}/SOURCES";
        push @files, $1;
    }
    $in->close;

    $self->{SOURCEFILES} = \@files;
    return 1;
}

=item _read_version_file ()

Reads the F<VERSION> file and builds the internal representation of the
current version.

=cut

sub _read_version_file {
    my ($self) = @_;

    my $in = IO::File->new("<$self->{BASEPATH}/$self->{SOURCEDIR}/VERSION")
        or return undef;

    <$in> =~ /^(\d+)\.(\d+)([a-z]*)(\d*)\s*$/ or die "bad $self->{SOURCEDIR}/VERSION";   
    $in->close;
    $self->{MAJOR}  = $1;
    $self->{MINOR}  = $2;
    $self->{PKGSTR} = $3;
    $self->{PKGVER} = $4;

    if ($self->{PKGSTR}) {
	$self->is_package or die "package type version in non-package source set";
    }
    else {
	$self->is_package and die "non-package type version in package source set";
    }

    return 1;
}

=item _write_version_file ()

Writes the internal representation of the current version out to the F<VERSION>
file.

=cut

sub _write_version_file {
    my ($self) = @_;

    my $out = IO::File->new(">$self->{BASEPATH}/$self->{SOURCEDIR}/VERSION")
        or die "open VERSION: $!";

    $out->print($self->version_string, "\n");
    $out->close or die "close VERSION: $!";
}

=item _cvs_command ( ARGS )

Runs the C<cvs> binary with ARGS as arguments, and returns STDOUT from the cvs
command as a string.  Dies if the cvs command fails.

=cut

sub _cvs_command {
    my $self = shift;

    my $pid = open CVS, "-|";
    defined $pid or die "fork: $!";
    if ($pid) {
        my $result = do { local $/ ; <CVS> };
	close CVS;
        $? and die "cvs command failed: " . join(' ', @_);
	return $result;
    }
    else {
        chdir $self->{BASEPATH} or die "chdir $self->{BASEPATH}: $!";
	exec('cvs', @_) or die "exec: $!";
    } 
}

=back

=cut

1;

