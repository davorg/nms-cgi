
=head1 NAME

B<CGI::NMS::Config> -
This class provides an interface to a hash of
information read from a configuration file. The module is written to be
used with various types of files, including 'B<.ini>',
'B<.properties>', and any other name=value or name=<<HERE format files.

=head1 SYNOPSIS

    use CGI::NMS::Config;
    my $cfg = CGI::NMS::Config->new( -file => $cfgfile, -section => $useSec,
                             -JoinLines => "yes" );
    my $obj = CGI::NMS::Config->new([$cfgfile[, $useSec]]); # see below for parameter descriptions

    $obj->joinLines(); # strips embedded newlines from HERE documents
    $value = $obj->get($key); # returns scalar value for hash key
    @keys = $obj->getKeys(); # returns an array of all of the hash keys
    $value = $obj->_Var_Name(); # Shortcut to 'Dyna-Safe' variables (AUTOLOADed)
    $value = $obj->{$key}; # allow direct access to the $key value;
    if ( $obj->exists($key) ) ... # returns a 1 or 0 for 'true' or 'false', respectively
    if ( $obj->defined($key) ) ... # returns a 1 or 0 for 'true' or 'false', respectively

=head1 DESCRIPTION

=head2 Copyright

$Id: Config.pm,v 1.2 2003-02-04 22:50:56 neonedge Exp $

Copyright (c) 2000, 2001, Grant Mongardi.
This program is licensed in the same way as Perl
itself. You are free to choose between the GNU Public
License <http://www.gnu.org/licenses/gpl.html>  or
the Artistic License
<http://www.perl.com/pub/a/language/misc/Artistic.html>

For a list of changes see CHANGELOG
For help on configuration or installation see README

=head2 General

This class provides an interface to variables defined by a user
configuration file. All of these variables are stored in an
anonymous hash, and accessed by either member functions or
directly (C<$obj->>C<{$hash_key}>).

The user-defined information is specified in
the file location passed to the new() function.
You can also specify the configuration file 
by setting the environment variable 'C<NMSCFGFILE>' to the
path/filename of the file. If no configuration file is found,
C<$obj->>C<get('_cfgfile')> will return I<undef>. If a 'B<$useSec>'
value is specified, then the file will be opened and 
read until a line is found that matches the RegEx 
C</^\[$useSec\]\s*$/>, at which point the module will suck
up name-value pairs until it sees a line that matches the 
RegEx C</^\[.*\]\s*$/>. The 'I<section name>' is stored in
the object element 'B<_secname>'. If the section specified 
was not found, then the $obj->exists('_secname') will
return false.

=head2 File Format

The Configuration File format is as follows:

    # Each key must begin on the first character of the line
    variable_name=value
    undefined_name=
    !_Var_Name=value # special format - see below
    ;_Ini_Var=value # special format - see below

    [Section Name]
    ... more variables

which results in a $obj->get( B<'variable_name'> ) returning
'B<value>' or $obj->get( B<'undefined_name'> ) returning
'I<undef>' or $obj->get( B<'_Var_Name'> ) returning
'B<value>' (*note the stripped '!'). Each configuration 
directive MUST occur on a line by itself, and I<cannot> 
include comments. The format for any configuration 
directive must meet the following requirements:

    $key must begin with A to Z, a to z, 0 to 9, underscore, '-', '!_', or ';_'
    $key or $value should not contain special characters or be reserved keywords
    $key or $value cannot contain embedded newline characters.
    $key must start at the beginning of the line (/^$key/). 
    $key should be explained in the config file header for DynaConf files.

> 
NOTE: ANY LINE THAT DOES NOT START WITH '#', ' '(space), ';', or '!' 
IS ASSUMED TO BE A CONFIGURATION DIRECTIVE (or continuation thereof), 
AND THEREFORE THE OBJECT ATTEMPTS TO SET A DIRECTIVE BY IT, UNLESS 
THE LINE LENGTH IS LESS THAN 1.

>The one exception to the $key requirements is that if $key
begins with '!_' or ';_' followed immediately by one or more Capitalized
A to Z characters, followed by any number of other valid 
capital letters, underscore, or dash, followed by an equals sign,
and the $value, then the directive will be stripped of the leading 
'!' or ';' and set as a key/value pair. These are what I call 
I<'Dyna-Safe'> variables and are the only type of variables that
can be called as Object methods. The reasoning behind this is so 
that the programmer can 'hide' the Dyna-Safe variables in the file.
This allows DynaConf to embed it's own special variables in .properties
and .ini files without confusing Java or Windows. This allows one to have
configuration files common to both the Perl application and a Java or
Windows program.
Example:

    !_My_Key=my_value
       or
    ;_My_Key=my_value

will cause $obj->_My_Key(); to return "my_value". whereas:

    !1Mykey=my_value
    !MY_KEY=My_value
    ;vMY_KEY=my_value

will all be ignored (treated as comments). Similarly, any
other non-'Dyna-Safe' variables will return the method by
which it was called. Example:

onEntry=username

will, when called as C<$obj->>C<onEntry()>, return the string
'B<onEntry>'. Please also note
that any variable containing special characters such 
as '.', '$' etc., will cause the application to fail 
if called as a method, but will work up to the point 
at which it is called (no run-time error).

NOTE: IF THE CONSTRUCTOR FAILS TO FIND A ".cfg" FILE, THEN
"$obj->get('_cfgfile')" WILL RETURN I<undef> AND
"$obj->defined('_cfgfile')" WILL RETURN '0'. THIS VALUE
SHOULD BE CHECKED ANY TIME YOU ARE EXPECTING THE OBJECT TO 
CREATE A CUSTOM CONFIGURATION FROM A FILE. Additionally, 
if you specify a section name and that section is not found
within the file that you specified, the variable '_sectname' 
will also remain undefined.

=back

=head1 AUTHOR

Grant M. E<lt>wizard@neonedge.comE<gt>

Thanks to: Jonathan S. E<lt>Address witheldE<gt>

=head1 KNOWN BUGS AND LIMITATIONS

If you call the autoload object method using a variable 
name that contains special characters, the call will cause the 
program to exit immediately without a warning. This is true of 
any Perl object.

=cut


package CGI::NMS::Config;
$VERSION = 0.70;
require 5.001;
use vars qw($AUTOLOAD);

require Exporter;

@ISA = qw( Exporter );
@EXPORT = qw( );
@EXPORT_OK = qw( new joinLines getKeys get exists defined );

### PACKAGE GLOBALS

=head1 INSTANCE MEMBER METHODS

=head2 B<Public>

=item * Class method B<new()>

=item

Answers an instance of class DynaConf.
Example:

    $c = CGI::NMS::Config->new([$filename, ['$useSec']]);
    $f = CGI::NMS::Config->new( -file => "$filename", -section => "$useSec",
             -JoinLines => "yes" );
    $k = CGI::NMS::Config->new();

where C<$filename> is the name of the file from which to 
read all of the configuration name-value pairs from, and 
C<useSec> is the name of an .ini file section from which 
to grab the name-value pairs. if C<useSec> is not specified, 
then all name value pairs are sucked-up, which results in 
duplicate keys being overwritten by the last one listed.
If the -JoinLines parameter is specified any HERE
document value will be stripped of embedded newlines. If no
parameters are passed, it will check for the environment
variable C<SRC_CFG> and use that if it exists, or it will assume
a file in the current working directory called "dyn.cfg".

=cut

sub new
{
    my($proto, @args) = @_;
    my($class) = ref($proto) || $proto;
    my ($self) = {};
    bless $self, $class;
    
    # parse parameters (if any)
    if ($#args >= 0) {
        # foreach (@args) {print "$_\n";}
        $_ = $args[0];
        if ( /^-\w+\s*/ ) {
            # passed as hash
            my %conf = @args;
            $self->{_cfgfile} = delete $conf{-file} if(exists $conf{-file});
            $self->{_secname} = delete $conf{-section} if(exists $conf{-section});
            
            if ( exists $conf{-JoinLines} && $conf{-JoinLines} eq "1"
                  || uc($conf{-JoinLines}) eq "TRUE"
                  || uc($conf{-JoinLines}) eq "YES" ) {
                      $self->{_JoinLines} = 1;
            }
        } else {
            # passed in order
            $self->{_cfgfile} = shift @args;
            if ( @args ){
                $self->{_secname} = shift @args;
            }
        }
    } else {
        # no parameters
        if ( defined( $ENV{SRC_CFG} )) {
            $self->{_cfgfile} =  $ENV{NMSCFGFILE};
        } else {
            return 0;
        }
    }

    if ( defined $self->{_secname} ){
        $self->_initini();
    } else {
        $self->_initialize();
    }
    return $self;
}


=item * Class method B<joinLines()>

=item

Allows the caller to remove any embedded newlines from
the values of any HERE parameters. This can be used after the
Configuration file is read, so that the functionality
can be used when passing arguments to C<new()> as an
array. It also sets the internal 'B<_JoinLines>' variable.
Example:

    $obj = DyanConf->new( "../etc/conf.cfg" );
    $obj->joinLines(); # remove embedded newlines from HERE documents

=cut

sub joinLines
{
    my($self, @args) = @_;
    my (@ret, $key);
    foreach $key ( keys %{ $self }) {
        $self->{$key} =~ s/\n//g;
    }
    $self->{_JoinLines} = 1;

} # joinLines


=item * Class method B<getKeys()>

=item

Allows the caller to retrieve all of the keys
that have been defined within this object. This method
will always return AT LEAST the C<_cfgfile> variable, although
it may be I<undef>ined.
Example:

    @keys = $obj->getKeys();

=cut

sub getKeys
{
    my($self, @args) = @_;
    my (@ret, $key, $i);
    $i = 0;
    foreach $key ( keys %{ $self }) {
        $ret[$i] = $key;
        $i++;
    }
    return @ret;

} # getKeys


=item * Class method B<get('KEY')>

=item

Allows the caller to retrieve one of the configuration 
settings from the object. The caller must pass a 
directive that is set in the .cfg file (variable_name=)
or else the call will return I<undef>. The call returns
the value of the directive, or I<undef> if not defined.
Example:

    $serverName = $obj->get('Server');

=cut

sub get
{
    my($self, @args) = @_;
    my $ret = undef;
    my $key;

    # Set it from the input, if specified.
    if (@args) {
        $key = shift @args;
        if( defined( $self->{$key} )){
            $ret = $self->{$key};
        } else {
            $ret = undef;
        }
    } else {
        $ret = undef;
    }

    return $ret;
} # get

=item * Class method B<exists('KEY')>

=item

Allows the caller to determine if a variable has been 
initialized within the object. This will return true
even if the variable is equal to an empty string or I<undef>.
Use the 'defined' function to see if it has a value.
Example:

    $bool = $obj->exists('MY_VAR');

=cut

sub exists
{
    my($self, @args) = @_;
    my $key = shift @args;
    my $ret = undef;

    # Check for the key passed.
    if (exists $self->{$key}) {
        $ret = 1;
    } else {
        $ret = 0;
    }
    return $ret;
} # exists

=item * Class method B<defined('KEY')>

=item

Allows the caller to determine if a variable has been 
defined within the object hash. This will return true 
only if the variable exists and is not equal to an empty
string or I<undef>.
Example:

    $bool = $obj->defined('MY_VAR'); 

=cut

sub defined
{
    my($self, @args) = @_;
    my $key = shift @args;
    my $ret = undef;

    # Set it from the input, if specified.
    if (defined $self->{$key}) {
        $ret = 1;
    } else {
        $ret = 0;
    }
    return $ret;
} # defined

=item * Class method B<is_true('KEY')>

=item

Allows the caller to determine if a variable has a 
value that equates to true. This will return true 
if the value is equal to any of the following:
'Yes', 'yes', 'y', 'Y', 'True', 'true', 'T', 't', 'On', 'on' or '1'.
Example:

    $bool = $obj->is_true('MY_VAR'); 

=cut

sub is_true
{
    my($self, @args) = @_;
    my $key = shift @args;
    my $ret = undef;
	my $truth_test = '^[Yy][Ee][Ss]\s*$|^[Yy]\s*$|^[Tt][Rr][Uu][Ee]\s*$|^[Tt]\s*$|^[Oo][Nn]\s*$|^[1]\s*$';
	my $false_test = '^[Nn][Oo]\s*$|^[Ff][Aa][Ll][Ss][Ee]\s*$|^[Ff]\s*$|^[Oo][Ff][Ff]\s*$|^[0]\s*$';

    # Set it from the input, if specified.
    if ( (defined $self->{$key}) && ($self->{$key} =~ /$truth_test/) ) {
        $ret = 1;
    } elsif( (defined $self->{$key}) && ($self->{$key} =~ /$false_test/) ) {
        $ret = 0;
    } else {
	    die "Value \"", $self->{$key}, "\" is not boolean.";
	}
    return $ret;
} # is_true

=item * Class method B<is_false('KEY')>

=item

Allows the caller to determine if a variable has a 
value that equates to false. This will return false 
if the value is equal to any of the following:
'No', 'no', 'N', 'n', 'False', 'false', 'F', 'f', 'Off', 'off' or '0'.
Example:

    $bool = $obj->is_false('MY_VAR'); 

=cut

sub is_false
{
    my($self, @args) = @_;
    my $key = shift @args;
    my $ret = undef;
	my $truth_test = '[Nn]|[Ff]|[Oo]ff|[0]';

    # Set it from the input, if specified.
    if ( (defined $self->{$key}) && ($self->{$key} =~ /^$truth_test/) ) {
        $ret = 1;
    } else {
        $ret = 0;
    }
    return $ret;
} # is_false

=item * Class methods B<$KEY_NAME()>

=item

Allows the caller to retrieve any 'I<Dyna-Safe>'
variable by simply calling the variable as a
subroutine. The definition of a 'I<Dyna-Safe>'
variable in the context of this module is any
varaible that meets the RegEx of /^_[a-zA-Z]+[a-zA-Z_\-0-9]+/. 
This includes the 'B<_cfgfile>', 'B<_section>', and 'B<_JoinLines>' variables.
Example:

    $bin = $obj->_binDir(); # in the config file as "_binDir=/directory/path"

=cut

# see end of this file for actual AUTOLOAD method.

=back

=head2 Private

=item * Instance method B<_initialize()>

=item

Perform internal initialization(s).

=cut

sub _initialize {
    my($self, @args) = @_;

    if( !$self->{_cfgfile} ) {
        $self->{_cfgfile}="dyn.cfg";
    }

    my($cfg_name,$cfg_value);

    if( open (FILE, "<$self->{_cfgfile}") ) {

        while ( <FILE> ) {
            # print "<!-- $_ -->\n";
            # Remove leading comment characters '!' and ';'
            $_ =~ s/^[!;](_[a-zA-Z]+[a-zA-Z0-9_\-]+\s*\=.*)/$1/g;

            # ignore lines that are comments, section names, or have leading spaces
            if (/^[^#\s!\;\[]/) {
                ($cfg_name,$cfg_value) = split(/=/,$_,2);
                chomp $cfg_value if ( $self->{_JoinLines} );
                if ($cfg_value =~ /^<<.*$/) {
                    my $here = $cfg_value;
                    $here =~ s/^<<(.*)/$1/;
                    $cfg_value = "";
                    while ( <FILE> ) {
                        if ( /^$here/ ) {
                            last;
                        } else {
                            chomp if ( $self->{_JoinLines} );
                            $cfg_value .= $_;
                        }
                    }
                }
                $cfg_value =~ s/^\s+//g;
                $cfg_value =~ s/\n$//g;
                $cfg_value = undef if ( length($cfg_value) == 0 );
                if($cfg_name)
                {
                    $cfg_name =~ s/\s+$//;
                    $self->{$cfg_name} = $cfg_value;
                }
            }
        }
        close(FILE);
    } else {
        $self->{_cfgfile}=undef;
    }
} # _initialize

=item * Instance method B<_initini()>

=item

Perform internal initialization(s) by section.

=cut

sub _initini
{
    my($self, @args) = @_;

    if( !$self->{_cfgfile} )  # 
    {
        $self->{_cfgfile}="dyn.cfg";
    }

    my($cfg_name,$cfg_value,$sec_found,$sec_done);
    my @LINES;
    my $SIZE;
    my $i;

    if( open (FILE, "$self->{_cfgfile}") ) {
        while ( <FILE> ) {
            # Remove leading comment characters '!' and ';'
            $_ =~ s/^[!;](_[a-zA-Z]+[a-zA-Z_\-0-9]+\=.*)/$1/g;

            # ignore lines that are comments or have leading spaces
            if (/^[^#\s!\;]/)
            {
                if ( $sec_found ) {
                    if ( /^\[.*\]\s*$/ ) {
                        $sec_found = 0;
                        $sec_done = 1;
                        $i = $SIZE;
                        last;
                    }
                    ($cfg_name,$cfg_value) = split(/=/,$_);
                    chomp $cfg_value if ( $self->{_JoinLines} );
                    if ($cfg_value =~ /^<<.*$/) {
                        my $here = $cfg_value;
                        $here =~ s/^<<(.*)/$1/;
                        $cfg_value = "";
                        while ( <FILE> ) {
                            if ( /^$here/ ) {
                                last;
                            } else {
                                chomp if ( $self->{_JoinLines} );
                                $cfg_value .= $_;
                            }
                        }
                    }
                    $cfg_value =~ s/^\s+//;
                    chomp $cfg_value;
                    $cfg_value = undef if ( length($cfg_value) == 0 );
                    if($cfg_name)
                    {
                        $cfg_name =~ s/\s+$//;
                        $self->{$cfg_name} = $cfg_value;
                    }
                } elsif ( /^\[$self->{_secname}\]\s*$/ ) {
                    $sec_found = 1;
                }       
            }
        }
    } else {
        $self->{_cfgfile}=undef;
    }
    if ( !$sec_found && !$sec_done ) { delete $self->{_secname}; }
} # _initini

sub AUTOLOAD { 
    my $self = shift; 
    my $method = $AUTOLOAD; 
 
 
    # splat the leading package name 
    $method =~ s/.*:://; 

    # be sure that it is one of our 'Perl-safe' vars
    if ($method !~ /^_[a-zA-Z]+[a-zA-Z_\-0-9]+/ ){
        return $method;
    }
 
    # ignore destructor 
    if ($method eq 'DESTROY') {
        return;
    } 
    
    # now let's setup for speed
    if ( exists $self->{ $method } ){
        *{$AUTOLOAD} = sub { return $_[0]->{ $method } };
        return $self->{ $method }; 
    } else {
        return $method;
    }

} 

### END CGI::NMS::Config.pm

1;








