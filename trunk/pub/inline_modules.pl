#!/usr/bin/perl -w

=head1 NAME

pub/inline_modules.pl - update inlined NMS modules

=head1 SYNOPSIS

   $ cd /path/to/working/copy/of/nms-cgi/cvs/tree
   $ pub/inline_modules.pl

=head1 DESCRIPTION

This script updates any out of date inlined copies of CGI::NMS::*
modules in the nms-cgi scripts.  The steps to modify a module
are as follows:

=over

=item *

Edit your working copy of the module.

=item *

Run the module's tests.

=item *

Check the module into CVS.

=item *

Run this script.

=item *

Run the test suites of all of the CGI scripts.

=item *

Check all the CGI scripts into CVS.

=back

The list of scripts that have inlined modules and the list of
modules to inline are configured statically within this script.
Edit it to add modules and scripts.

=cut

# The scripts that contain inline modules
my @scripts = qw(

   wwwboard/wwwboard.pl

);

# The modules to inline
my %modules = (

   'CGI::NMS::Charset' => 'modules/NMS/Charset/Charset.pm',

);

##############################################################

use Fatal qw(open close);

foreach my $name (keys %modules)
{
   open MODULE, "<$modules{$name}";
   my $module = do { local $/ ; <MODULE> };
   close MODULE;

   # Need this to prevent CVS keywords in the modules that we
   # inline into the scripts from being substituted when the
   # scripts are checked into CVS.
   $module =~ s%(\$[A-Z][a-z]+: )% lc $1 %ge;

   $modules{$name} = $module;
}

foreach my $script (@scripts)
{
   -r $script or die "$script not found\n";

   open SCRIPT, "<$script";
   my $text = do { local $/ ; <SCRIPT> };  
   close SCRIPT;

   $text =~ s{\n## BEGIN INLINED (\S+).*\n## END INLINED \1\n}
             { "\n" . inline_module($1) }ges;

   open SCRIPT, ">$script";
   print SCRIPT $text;
   close SCRIPT;
}

sub inline_module
{
   my ($name) = @_;

   exists $modules{$name} or die "can't inline module [$name]\n";
   return <<END;
## BEGIN INLINED $name
$modules{$name}## END INLINED $name
END

}

