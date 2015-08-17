package NMSTest::OptionParser;
use strict;

use Carp;

=head1 NAME

NMSTest::OptionParser - class constructor option parser

=head1 DESCRIPTION

This class adds an option parsing capability to any subclass,
falling back to "NMSTEST_" prefixed environment variables and
then to default values for missing options.

The construct C<[[FOO]]> within an option value gets replaced
with the value of option C<FOO>.  This allows defaults to be
interrelated, for example:

   BASE => '/a/path',
   BIN  => '[[BASE]]/bin',
   ...

This causes BIN to default to C<'/a/path/bin'>, but if BASE
is specified as '/a/second/path/' and BIN is unspecified,
then BIN will default to '/a/second/path/bin'.

=head1 METHODS

=over 4

=item parse_options ( OPTIONS )

OPTIONS must be a hashref, specifying the names and default
values of the options to be parsed.  Any explicit options
should be placed in a C<$self->{Opts}> hash before invoking
this method.

The parsed options will be place directly in the object's
C<$self> hash.

=cut

sub parse_options
{
   my ($self, $options) = @_;

   my %all_opts = (
      # lowest priority, the defaults in %$options.
      %$options,

      # environment variables override defaults.
      ( map { /^NMSTEST_(.+)$/ ? ($1,$ENV{$_}) : () } keys %ENV ),

      # explicit options override environment variables.
      %{ $self->{Opts} }
   );

   foreach my $opt (keys %$options)
   {
      $self->{$opt} = $all_opts{$opt};

      unless (defined $self->{$opt})
      {
         confess "No value supplied for option $opt";
      }

      next if ref $self->{$opt};

      my $i = 0;
      while ( $self->{$opt} =~ s%\[\[([A-Z]+)\]\]
                                %defined $all_opts{$1} ?
                                         $all_opts{$1} :
                                         confess "can't substitute [[$1]]"
                                %ex )
      {
         $i++ > 100 and confess "recursion too deep in option $opt";
      }

      $self->{Opts}{$opt} = $self->{$opt};
   }
}

=back

=head1 COPYRIGHT

Copyright (c) 2002 The London Perl Mongers. All rights reserved.
This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

