
=head1 NAME

B<CGI::NMS::Data> -
This class provides an interface to a the NML-format files that stores
the message data.

=head1 SYNOPSIS

    use CGI::NMS::Data;
    my $cfg = CGI::NMS::Data->new( -file => $datafile );
    my $obj = CGI::NMS::Data->new( $datafile ); # see below for parameter descriptions

	$next_id = $obj->print_thread( $cfg, $thread_id );  # prints specified thread, returns next thread
    $bool = $obj->print_message( $cfg, $msg_id )  # prints specified message, returns success
	
=head1 DESCRIPTION

=head2 Copyright

$Id: Data.pm,v 1.1.1.1 2003-01-31 01:41:29 neonedge Exp $

Copyright (c) 2000, 2001, Grant Mongardi.
This program is licensed in the same way as Perl
itself. You are free to choose between the GNU Public
License <http://www.gnu.org/licenses/gpl.html>  or
the Artistic License
<http://www.perl.com/pub/a/language/misc/Artistic.html>

For a list of changes see CHANGELOG
For help on configuration or installation see README

=head2 General

This class provides an interface to read and parse an NML-format
datafile for NMS scripts.

=head2 File Format

The NMS File format is as follows:

    The entire list is contained in a <nmsboard></nmsboard> 
	set of tags, with a 'name=' attribute specifying the 
	NMS name of the list. the 'name=' attribute is not
	presently used, however it may be at some future date.
	
	Each entry consist of an enclosing set of <MessID> tags.
	The opening tag has an 'Id=' attribute that specifies
	the Identification Number of the message, which also 
	corresponds to the message file that contains the content
	of the message. Within the <MessID> tags are contained the 
	field values of each message, excluding the message text 
	itself which is in the message file. The tag pairs used to 
	delimit these fields are:
	    <subject></subject>
		<user></user>
		<email></email>
		<IP></IP>
		<date></date>
		<moderate></moderate>
		<linkURL></linkURL>
		<linkTitle></linkTitle>
		<imageURL></imageURL>
	Only the subject, user, email and date fields are required.
	
	Any <MessID></MessID> entry can contain other message entries
	nested within them. These nested entries are threaded responses
	to the parent message. The nesting can iterate up to a maximum depth of 
	the value of 'max_followups' as specified in the configuration 
	file.

=back

=head1 AUTHOR

Grant Mongardi E<lt>wizard@neonedge.comE<gt>

=head1 KNOWN BUGS AND LIMITATIONS

None yet ;-)

=cut


package CGI::NMS::Data;
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

Answers an instance of class CGI::NMS::Config.
Example:

    $c = CGI::NMS::Data->new( $filename );
    $f = CGI::NMS::Data->new( -file => "$filename" );

where C<$filename> is the name of the file from which
contains all of the message data excluding the message
text. The default message file name is "./.nms.nml".

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
			if( exists $conf{-file} && -e $conf{-file} ) {
                $self->{_datfile} = delete $conf{-file};
			} else {
			    return 0;
			}
        } else {
            # passed in order
            $self->{_datfile} = shift @args;
			return 0 if( !-r $self->{_datfile});
        }
    } else {
        # no parameters
        return 0;
    }
    $self->_initialize();
	return $self;
} # end new()

=item * Class method B<print_thread('ID')>

=item

Prints the full thread specified by 'ID'. If 'ID' is 
'0' (zero), then the first thread in the list is printed.
The method returns the message_ID of the next thread in 
the list.
Example:

    $next_id = $obj->print_thread('ID'); 

=cut

sub print_thread
{
    my($self, @args) = @_;
	my $cfg = shift @args;
    my $id = shift @args;
    my $ret = undef;
	my $printed;
    my $msg_indent = 0;
	my $msg_index = 1;
	my $msg_subject = 2;
	my $msg_user = 3;
	my $msg_email = 4;
	my $msg_date = 5;
	my $msg_moderate = 6;
	
    # Set it from the input, if specified.
	if( $id == 0 ) {
		$id = $self->{'list_order'}[0];
		if( defined $id && exists $self->{ "MSG_$id" } && $self->{ "MSG_$id" }[$msg_indent] == 0 ) {
			print "<div class=\"list-item\"><a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$id\&cfg=", $cfg->get( '_cfgfile' ), "\">";
			print $self->{ "MSG_$id" }[$msg_subject], "</a>\n";
			print " - <b>", $self->{ "MSG_$id" }[$msg_user], "</b> <i>", $self->{ "MSG_$id" }[$msg_date], "</i></div>\n";
			my $next_item = $self->{ "MSG_$id" }[$msg_index] + 1;
			my $last_item = $#{$self->{'list_order'}};
			foreach( @{$self->{'list_order'}}[$next_item..$last_item] ) {
				if( $self->{ "MSG_$_" }[$msg_indent] != 0 ) {
					print "<div class=\"indent-item", $self->{ "MSG_$_" }[$msg_indent], "\">";
					print "<a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$_\&cfg=", $cfg->get( '_cfgfile' ), "\">";
					print $self->{ "MSG_$_" }[$msg_subject], "</a>\n";
					print " - <b>", $self->{ "MSG_$_" }[$msg_user], "</b> <i>", $self->{ "MSG_$_" }[$msg_date], "</i></div>\n";
				} else {
				    $ret = $_;
				    last;
				}
			}
		} else {
		}
	} else {
		if( exists $self->{ "MSG_$id" } ) {
			if( $self->{ "MSG_$id" }[$msg_indent] == 0 ) {
				print "<div class=\"list-item\"><a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$id\&cfg=", $cfg->get( '_cfgfile' ), "\">";
				print $self->{ "MSG_$id" }[$msg_subject], "</a>\n";
				print " - <b>", $self->{ "MSG_$id" }[$msg_user], "</b> <i>", $self->{ "MSG_$id" }[$msg_date], "</i></div>\n";
				my $next_item = $self->{ "MSG_$id" }[$msg_index] + 1;
				my $last_item = $#{$self->{'list_order'}};
				foreach( @{$self->{'list_order'}}[$next_item..$last_item] ) {
					if( $self->{ "MSG_$_" }[$msg_indent] != 0 ) {
						print "<div class=\"indent-item", $self->{ "MSG_$_" }[$msg_indent], "\">";
						print "<a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$_\&cfg=", $cfg->get( '_cfgfile' ), "\">";
						print $self->{ "MSG_$_" }[$msg_subject], "</a>\n";
						print " - <b>", $self->{ "MSG_$_" }[$msg_user], "</b> <i>", $self->{ "MSG_$_" }[$msg_date], "</i></div>\n";
						$ret = $self->{'list_order'}[ $self->{ "MSG_$_" }[$msg_index] + 1 ];
					} else {
					    $ret = $_;
					    last;
					}
				}
			} else {
			    my $last_root = 0;
				foreach( @{$self->{'list_order'}} ) {
					$last_root = $self->{ "MSG_$_" }[$msg_index] if( exists $self->{ "MSG_$_" } && defined $self->{ "MSG_$_" }[$msg_indent] && $self->{ "MSG_$_" }[$msg_indent] eq "0" );
					if( $_ == $id ) {
						my $id = $self->{ 'list_order' }[$last_root];
						print "<div class=\"list-item\"><a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$id\&cfg=", $cfg->get( '_cfgfile' ), "\">";
						print $self->{ "MSG_$id" }[$msg_subject], "</a>\n";
						print " - <b>", $self->{ "MSG_$id" }[$msg_user], "</b> <i>", $self->{ "MSG_$id" }[$msg_date], "</i></div>\n";
						my $next_item = $self->{ "MSG_$id" }[$msg_index] + 1;
						my $last_item = $#{$self->{'list_order'}};
						foreach( @{$self->{'list_order'}}[$next_item..$last_item] ) {
							if( $self->{ "MSG_$_" }[$msg_indent] != 0 ) {
								print "<div class=\"indent-item", $self->{ "MSG_$_" }[$msg_indent], "\">";
								print "<a href=\"", $cfg->get( 'cgi_url' ), "?proc=ShowMsg\&msg_id=$_\&cfg=", $cfg->get( '_cfgfile' ), "\">";
								print $self->{ "MSG_$_" }[$msg_subject], "</a>\n";
								print " - <b>", $self->{ "MSG_$_" }[$msg_user], "</b> <i>", $self->{ "MSG_$_" }[$msg_date], "</i></div>\n";
								$ret = $self->{'list_order'}[ $self->{ "MSG_$_" }[$msg_index] + 1 ];
							} else {
							    $ret = $_;
								last;
							}
						}
							
					}
				}
			}
		}
	}
    return $ret;
} # print_thread

=item * Class method B<print_message( $cfg_object, 'ID')>

=item

Prints the individual specified by 'ID'. If 'ID' is 
'0' (zero), then the first thread in the list is printed.
The method returns the message_ID of the next thread in 
the list.
Example:

    $next_id = $obj->print_message( $cfg_object, 'ID'); 

=cut

sub print_message
{
    my($self, @args) = @_;
	my $cfg = shift @args;
    my $id = shift @args;
    my $ret = undef;
	my $printed;
    my $msg_indent = 0;
	my $msg_index = 1;
	my $msg_subject = 2;
	my $msg_user = 3;
	my $msg_email = 4;
	my $msg_date = 5;
	my $msg_moderate = 6;
	my $msg_ip = 7;
	my $msg_linkURL = 8;
	my $msg_linkTitle = 9;
	my $msg_imageURL = 10;
	
    # Set it from the input, if specified.
	if( exists $self->{ "MSG_$id" } ) {
		print "<div class=\"list-item\">Posted By <a href=\"mailto:", $self->{ "MSG_$id" }[$msg_email], "\">";
		print $self->{ "MSG_$id" }[$msg_user], "</a> \(", $self->{ "MSG_$id" }[$msg_ip], "\) on ", $self->{ "MSG_$id" }[$msg_date], "</div>\n";
		my $msg_path = $cfg->get( 'mesgdir' ) . "/$id\." . $cfg->get( 'ext' );
		open( MSG, $msg_path ) or die "Can't open $msg_path: $!\n";
		print <MSG>;
		close( MSG );
	}
    return $id;
} # print_message

=item * Class method B<print_form( $cfg_object, 'ID', $cgi_obj)>

=item

Prints the individual form using data from message 'ID', 
if in ShowMsg or ShowThr mode. Else prints blank form.
Example:

    $next_id = $obj->print_message( $cfg_object, 'ID', $cgi_obj); 

=cut

sub print_form
{
    my($self, @args) = @_;
	my $cfg = shift @args;
	my $id = shift @args;
    my $cgi_data = shift @args;
    my $ret = undef;
	my $printed;
    use vars qw( $msg_indent $msg_index $msg_subject $msg_user $msg_email $msg_date $msg_moderate $msg_linkURL $msg_linkTitle $msg_imageURL );
    $msg_indent = 0;
	$msg_index = 1;
	$msg_subject = 2;
	$msg_user = 3;
	$msg_email = 4;
	$msg_date = 5;
	$msg_moderate = 6;
	$msg_linkURL = 8;
	$msg_linkTitle = 9;
	$msg_imageURL = 10;
	
	$template = $cfg->get( 'formtemplate' );
	open( FORM, "$template" );
	@tmpl = <FORM>;
 	my $hiddens = "<input type=\"hidden\" name=\"cfg\" value=\"" . $cfg->get( "_cfgfile" ) . "\" />\n";
    # Set it from the input, if specified.
    $id = 0 if( !defined $id );
	if( $id == 0 ) {
		$template = $cfg->get( 'formtemplate' );
		foreach( @tmpl ) {
			# 'PARSE_DATA_*' strings in template are replaced with "" in ListView mode
			$_ =~ s/NMS_FORM_ACTION/$cfg->{ 'NMS_FORM_ACTION' }/g;
			$_ =~ s/NMS_HIDDENS/$hiddens/g;
            $_ =~ s/PARSE_ITEM_([a-zA-Z0-9_-]+)/$cfg->{ "LIST_$1" }/g;  # Had to use direct access because get() won't interpolate
			$_ =~ s/NMS_DATA_([a-zA-Z0-9_-]+)//g;
			$_ =~ s/NMS_CONTENT//g;
			print $_;
		}
	} else {
	    my $proc = $cgi_data->param( "proc" ) if $cgi_data->param( "proc" );
        if( exists $self->{ "MSG_$id" } && $proc eq 'ShowThr' ) {
			if( $self->{ "MSG_$id" }[$msg_indent] == 0 ) {
				$hiddens .= "<input type=\"hidden\" name=\"parent\" value=\"$id\" />\n";
                my $msg_path = $cfg->get( 'mesgdir' ) . "/$id\." . $cfg->get( 'ext' );
                open( MSG, $msg_path ) or die "Can't open $msg_path: $!\n";
                my @msg_txt = <MSG>;
                close( MSG );
				foreach( @tmpl ) {
					# 'PARSE_DATA_*' strings in template are replaced with Message equivalents in ShowThr mode
					$_ =~ s/(NMS_FORM_[a-zA-Z0-9_-]+)/$cfg->{ "$1" }/g;
					$_ =~ s/(NMS_HIDDENS)/$hiddens/g;
                    $_ =~ s/PARSE_ITEM_([a-zA-Z0-9_-]+)/$cfg->{ "THREAD_$1" }/g;  # Had to use direct access because get() won't interpolate
					# $_ =~ s/NMS_DATA_([a-zA-Z0-9_-]+)/$self->{ "MSG_$id" }[${ "msg_$1" }]/g;
                    if( /NMS_DATA_REsubject/ ) {
                        if( $self->{ "MSG_$id" }[$msg_subject] !~ /^Re\:/ ) {
                            $_ =~ s/NMS_DATA_REsubject/Re\: $self->{ "MSG_$id" }[$msg_subject]/g;
                        } else {
                            $_ =~ s/NMS_DATA_REsubject/$self->{ "MSG_$id" }[$msg_subject]/g;
                        }
                    }
                    $_ =~ s/NMS_DATA_([a-zA-Z0-9_-]+)/$self->{ "MSG_$id" }[${ "msg_$1" }]/g;
			        $_ =~ s/NMS_CONTENT/@msg_txt/g;
					print $_;
				}
			} else {
			    my $last_root = 0;
				foreach( @{$self->{'list_order'}} ) {
					$last_root = $self->{ "MSG_$_" }[$msg_index] if( exists $self->{ "MSG_$_" } && defined $self->{ "MSG_$_" }[$msg_indent] && $self->{ "MSG_$_" }[$msg_indent] == 0 );
					if( $_ == $id ) {
						my $id = $self->{ 'list_order' }[$last_root];
						$hiddens .= "<input type=\"hidden\" name=\"parent\" value=\"$id\" />\n";
                        my $msg_path = $cfg->get( 'mesgdir' ) . "/$id\." . $cfg->get( 'ext' );
                        open( MSG, $msg_path ) or die "Can't open $msg_path: $!\n";
                        my @msg_txt = <MSG>;
                        close( MSG );
						foreach( @tmpl ) {
							# 'PARSE_DATA_*' strings in template are replaced with Message equivalents in ShowThr mode
							$_ =~ s/(NMS_FORM_[a-zA-Z0-9_-]+)/$cfg->{ "$1" }/g;
                            $_ =~ s/(NMS_HIDDENS)/$hiddens/g;
                            $_ =~ s/PARSE_ITEM_([a-zA-Z0-9_-]+)/$cfg->{ "THREAD_$1" }/g;  # Had to use direct access because get() won't interpolate
                            if( /NMS_DATA_REsubject/ ) {
                                if( $self->{ "MSG_$id" }[$msg_subject] !~ /^Re\:/ ) {
                                    $_ =~ s/NMS_DATA_REsubject/Re\: $self->{ "MSG_$id" }[$msg_subject]/g;
                                } else {
                                    $_ =~ s/NMS_DATA_REsubject/$self->{ "MSG_$id" }[$msg_subject]/g;
                                }
                            }
							$_ =~ s/NMS_DATA_([a-zA-Z0-9_-]+)/$self->{ "MSG_$id" }[${ "msg_$1" }]/g;
							$_ =~ s/NMS_CONTENT/@msg_txt/g;
							print $_;
						}
					}
				}
			}
		} elsif( exists $self->{ "MSG_$id" } && $proc eq 'ShowMsg' ) {
            $hiddens .= "<input type=\"hidden\" name=\"parent\" value=\"$id\" />\n";
            my $msg_path = $cfg->get( 'mesgdir' ) . "/$id\." . $cfg->get( 'ext' );
            open( MSG, $msg_path ) or die "Can't open $msg_path: $!\n";
            my @msg_txt = <MSG>;
            close( MSG );
            foreach( @tmpl ) {
                # 'PARSE_DATA_*' strings in template are replaced with Message equivalents in ShowThr mode
                $_ =~ s/(NMS_FORM_[a-zA-Z0-9_-]+)/$cfg->{ "$1" }/g;
                $_ =~ s/(NMS_HIDDENS)/$hiddens/g;
                $_ =~ s/PARSE_ITEM_([a-zA-Z0-9_-]+)/$cfg->{ "MESSAGE_$1" }/g;  # Had to use direct access because get() won't interpolate
                if( /NMS_DATA_REsubject/ ) {
                    if( $self->{ "MSG_$id" }[$msg_subject] !~ /^Re\:/ ) {
                        $_ =~ s/NMS_DATA_REsubject/Re\: $self->{ "MSG_$id" }[$msg_subject]/g;
                    } else {
                        $_ =~ s/NMS_DATA_REsubject/$self->{ "MSG_$id" }[$msg_subject]/g;
                    }
                }
                $_ =~ s/NMS_DATA_([a-zA-Z0-9_-]+)/$self->{ "MSG_$id" }[${ "msg_$1" }]/g;
                $_ =~ s/NMS_CONTENT/@msg_txt/g;
                print $_;
            }
		}         
	}
	close( FORM );
    return $ret;
} # print_form

=head2 Private

=item * Instance method B<_initialize()>

=item

Perform internal initialization(s).

=cut

sub _initialize {
    my($self, @args) = @_;

    if( !$self->{_datfile} ) {
        return 0;
    }

    my( @entries, $indent, $currentID, $parentID );
	my $iter = 0;
    $indent =0;

    if( open (FILE, "$self->{_datfile}") ) {
        while ( <FILE> ) {
			if( /^\s*\<nmsboard\s name=\"[A-za-z0-9_-]+\"\>\s*$/ ) {
				$indent = 0;
				$currentID = 0;
			    next;
			}
			if( /^\s*\<MessID\sId=\"([0-9]+)\"\>\s*$/ ) {
				$parentID = $currentID;
				$currentID = $1;
				push @{$self->{ "list_order" }}, $currentID;
			    $self->{ "MSG_$currentID" }[0] = $indent;
				$self->{ "MSG_$currentID" }[1] = $iter;
				$iter++;
				$indent++;
			}
			if( /^\s*\<subject\>(.*)\<\/subject\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[2] = $1;
			}
			if( /^\s*\<user\>(.*)\<\/user\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[3] = $1;
			}
			if( /^\s*\<email\>(.*)\<\/email\>\s*$/ ) {
				my $esc_email = $1;
				$esc_email =~ s/\@/\\\@/g;
				$self->{ "MSG_$currentID" }[4] = $esc_email;
			}
			if( /^\s*\<date\>(.*)\<\/date\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[5] = $1;
			}
			if( /^\s*\<moderate\>(.*)\<\/moderate\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[6] = $1;
			}
			if( /^\s*\<ipaddress\>(.*)\<\/ipaddress\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[7] = $1;
			}
			if( /^\s*\<linkURL\>(.*)\<\/linkURL\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[8] = $1;
			}
			if( /^\s*\<linkTitle\>(.*)\<\/linkTitle\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[9] = $1;
			}
			if( /^\s*\<imageURL\>(.*)\<\/imageURL\>\s*$/ ) {
				$self->{ "MSG_$currentID" }[10] = $1;
			}
			if( /^\s*\<\/MessID\>\s*$/ ) {
				$currentID = $parentID if $parentID;
				$parentID = $self->{ "MSG_$currentID" }[1];
				$indent--;
			}
			
        }
        close(FILE);
    } else {
        $self->{_datfile}=undef;
    }
} # _initialize

### END CGI::NMS::Data.pm

1;








