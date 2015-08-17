package File::Transaction;
use strict;

use vars qw($VERSION);
$VERSION = '0.04';

use IO::File;

=head1 NAME

File::Transaction - transactional change to a set of files

=head1 SYNOPSIS

  #
  # In this example, we wish to replace the word 'foo' with the
  # word 'bar' in several files, and we wish to minimize the risk
  # of ending up with the replacement done in some files but not
  # in others.
  #

  use File::Transaction;

  my $ft = File::Transaction->new;

  eval {
      foreach my $file (@list_of_file_names) {
          $ft->linewise_rewrite($file, sub {
               s#\bfoo\b#bar#g;
          });
      }
  };

  if ($@) {
      $ft->revert;
      die "update aborted: $@";
  }
  else {
      $ft->commit;
  }

=head1 DESCRIPTION

A C<File::Transaction> object encapsulates a change to a set of files,
performed by writing out a new version of each file first and then
swapping all of the new versions in.  The set of files can only end up
in an inconsistent state if a C<rename> system call fails or if the
Perl process is interrupted during the commit().

Files will be committed in the order in which they are added to the
transaction.  This order should be chosen with care to limit the
damage to your data if the commit() fails part way through.  If there
is no order that renders a partial commit acceptable then consider
using L<File::Transaction::Atomic> instead.

=head1 CONSTRUCTORS

=over

=item new ( [TMPEXT] )

Creates a new empty C<File::Transaction> object.

The TMPEXT parameter gives the string to append to a filename to make
a temporary filename for the new version.  The default is C<.tmp>.

=cut

sub new {
    my ($pkg, $tmpext) = @_;
    defined $tmpext or $tmpext = '.tmp';

    return bless { FILES => [], TMPEXT => $tmpext }, $pkg;
}

=back

=head1 METHODS

=over

=item linewise_rewrite ( OLDFILE, CALLBACK )

Writes out a new version of the file OLDFILE and adds it to the
transaction, invoking the coderef CALLBACK once for each line of the
file, with the line in C<$_>.  The name of the new file is generated
by appending the TMPEXT passed to new() to OLDFILE, and this file is
overwritten if it already exists.

The callback must not invoke the commit() or revert() methods of the
C<File::Transaction> object that calls it.

This method calls die() on error, without first reverting any other
files in the transaction.

=cut

sub linewise_rewrite {
    my ($self, $oldfile, $callback) = @_;
    my $tmpfile = $oldfile . $self->{TMPEXT};

    my $in  = IO::File->new("<$oldfile");
    my $out = IO::File->new(">$tmpfile") or die "open >$tmpfile: $!";

    $self->addfile($oldfile, $tmpfile);

    local $_;
    while( defined $in and defined ($_ = <$in>) ) {
        &{ $callback }();
        next unless length $_;
        $out->print($_) or die "write to $tmpfile: $!";
    }

    $out->close or die "close >$tmpfile: $!";
}

=item addfile ( OLDFILE, TMPFILE )

Adds an update to a single file to the transaction.  OLDFILE is the
name of the old version of the file, and TMPFILE is the name of the
temporary file to which the new version has been written.

OLDFILE will be replaced with TMPFILE on commit(), and TMPFILE will be
unlinked on revert().  OLDFILE need not exist.

=cut

sub addfile {
    my ($self, $oldfile, $tmpfile) = @_;

    push @{ $self->{FILES} }, { OLD => $oldfile, TMP => $tmpfile };
}

=item revert ()

Deletes any new versions of files that have been created with the
addfile() method so far.   Dies on error.

=cut

sub revert {
    my ($self) = @_;

    foreach my $file (@{ $self->{FILES} }) {
        unlink $file->{TMP} or die "unlink $file->{TMP}: $!";
    }

    $self->{FILES} = [];
}

=item commit ()

Swaps all new versions that have been created so far into place.
Dies on error.

=cut

sub commit {
    my ($self) = @_;

    foreach my $file (@{ $self->{FILES} }) {
        rename $file->{TMP}, $file->{OLD} or die "update $file->{OLD}: $!";
    }

    $self->{FILES} = [];
}

=back

=head1 BUGS

=over

=item *

If a rename fails or the Perl process is interrupted in the commit()
method then some files will be updated but others will not.  See
L<File::Transaction::Atomic> if that's a problem for you.

=back

=head1 SEE ALSO

L<File::Transaction::Atomic>

=head1 AUTHOR

Nick Cleaton E<lt>nick@cleaton.netE<gt>

=head1 COPYRIGHT

Copyright (C) 2002 Nick Cleaton.  All Rights Reserved.

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

