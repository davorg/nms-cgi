#!c:/Perl/bin/perl -Tw
#
# $Id: nmsview.pl,v 1.2 2003-02-04 22:50:55 neonedge Exp $
#
# Part of Next Generation WWWBoard
#   nmsview.pl - Controls viewing of the NMSBoard data entries.
#
# Dependencies:
#    CGI.pm, strict.pm, constant.pm, vars.pm, Fcntl.pm, POSIX.pm -
#        Part of the standard Perl Library
#        Available from http://www.cpan.org. 
#    NMS::Config.pm -
#        An NMS module for reading in name=value configuration pairs from a file.
#        Distributed with this package.
#

use strict;
use lib "./lib/";
use CGI qw(:cgi);
use CGI::NMS::Config;
use CGI::NMS::Scripts::NMSBoard::DataView;
use vars qw( $DEBUGGING $VERSION );
BEGIN { $VERSION = "X"; }

delete @ENV{qw(IFS CDPATH ENV BASH_ENV)};
$ENV{PATH} =~ /(.*)/ and $ENV{PATH} = $1;

# PROGRAM INFORMATION
# -------------------
# nmsview.pl $Revision: 1.2 $
#
# This program is licensed in the same way as Perl
# itself. You are free to choose between the GNU Public
# License <http://www.gnu.org/licenses/gpl.html>  or
# the Artistic License
# <http://www.perl.com/pub/a/language/misc/Artistic.html>
#
# For a list of changes see CHANGELOG
# 
# For help on configuration or installation see README
#
# USER CONFIGURATION SECTION
# --------------------------
# Modify these to your own settings. You might have to
# contact your system administrator if you do not run
# your own web server. If the purpose of these
# parameters seems unclear, please see the README file.
#
# this is the location of the default configuration file. 
my $cfg_name = '.nms';
my $cfg_path = './.conf/';
my $cfg_ext = 'cfg';
# my $def_cfg = "./.conf/.nms.cfg";
#
# USER CONFIGURATION << END >>
# ----------------------------
# (no user serviceable parts beyond here)

$| = 1;     # don't buffer output
my $cgi_data = CGI->new();        # New CGI object

# check if 'cfg' is set via the URL query_string, if so use that.
my $esc_cfg = defined $cgi_data->param('cfg') ? $cgi_data->param('cfg') : $cfg_name;
$esc_cfg =~ /^(\.*[\w\-]{1,100})$/ or die "bad cfg value [$esc_cfg]";
$cgi_data->param('cfg', $esc_cfg );
my $def_cfg = "$cfg_path$esc_cfg.$cfg_ext";

my $cfg = CGI::NMS::Config->new( -file => $def_cfg );
$DEBUGGING = $cfg->get( 'DEBUGGING' );
# this is to ensure we only run one process and then finish 
# (in case someone uses a 'proc=' that is not a defined dispatch value)
# $sub_run needs to be set to 1 anytime a proc is run that produces output
my $sub_run = 0;

# dispatch based on 'proc' param
&show_message if ( defined( $cgi_data->param('proc') ) && $cgi_data->param('proc') eq "ShowMsg");
&show_thread if (defined( $cgi_data->param('proc') ) && $cgi_data->param('proc') eq "ShowThr");
&search if (defined( $cgi_data->param('proc') ) && $cgi_data->param('proc') eq "Search");

&default if (defined( $cgi_data->param('proc') ) && $cgi_data->param('proc') eq "");
&default if (!$sub_run);   # this is if no 'proc' is specified or no prior dispatch has yet run.

# ============================================================================#
# ALL SUBROUTINES GO BELOW THIS LINE                                          #
#    (Please describe briefly when adding new subroutines)                    #
#    [Dispatched functions at top, internal functions at bottom]              #
# ============================================================================#

# ***************DEFAULT ROUTINE************************
# :::::::::::::::::::::::::::::::::::::::::::::::::::
# default() runs if no _process is selected, Shows
#     complete List with all Threads

sub default {

# output HTTP and XHTML or HTML headers
print "Content-type: ", $cfg->get( 'Content_type' ), "\n\n\n";
my $header = $cfg->get( 'LISTHeader' );
&print_header( $header );

print "\n<!-- In default -->\n\n" if $DEBUGGING;
my $data_file = $cfg->get( 'mesgfile' ) if( defined $cfg->get( 'mesgfile' ) );
if( defined $data_file ) {
	my $base_dir = $cfg->get( 'basedir' ) if( defined $cfg->get( 'basedir' ) );
    if( my $data = CGI::NMS::Scripts::NMSBoard::DataView->new( "$base_dir/$data_file" ) ) {    # create a NMSData object
	    my $tid = 0;
        while( $tid = $data->print_thread( $cgi_data, $cfg, $tid ) ){;}    # print all threads starting at LIST_ROOT
		$data->print_form( $cgi_data, $cfg, $tid );
	} else {
	    print $cfg->get( 'DATA_OBJECT_FAIL' ), "$base_dir/$data_file\n";
	}
} else {
    print $cfg->get( 'LISTFILE_NOT_DEFINED' );
}

# output XHTML or HTML footer
my $footer = $cfg->get( 'LISTFooter' );
open( FOOT, "$footer" );
print <FOOT>;
close( FOOT );

$sub_run = 1;    # make sure we don't run anything else
} # end default

# ***************END OF DEFAULT ROUTINE**************

# ***************show_message ROUTINE************************
# :::::::::::::::::::::::::::::::::::::::::::::::::::
# show_message() runs if proc = ShowMsg,
#    displays the selected message text.
sub show_message {

# output HTTP and XHTML or HTML headers
print "Content-type: ", $cfg->get( 'Content_type' ), "\n\n\n";
my $header = $cfg->get( 'MSGHeader' );
&print_header( $header, $cgi_data->param( "msg_id" ) );
print "\n<!-- In ShowMsg -->\n\n" if $DEBUGGING;
my $data_file = $cfg->get( 'mesgfile' ) if( defined $cfg->get( 'mesgfile' ) );
if( defined $data_file ) {
	my $base_dir = $cfg->get( 'basedir' ) if( defined $cfg->get( 'basedir' ) );
    if( my $data = CGI::NMS::Scripts::NMSBoard::DataView->new( "$base_dir/$data_file" ) ) {    # create an NMSData object
		if( defined $cgi_data->param( "msg_id" ) ) {
			$data->print_message( $cgi_data, $cfg, $cgi_data->param( "msg_id" ) );   # print out message
		} else {
			print $cfg->get( 'MSGID_NOT_SPECIFIED' );
		}
		$data->print_form( $cgi_data, $cfg, $cgi_data->param( "msg_id" ) );
	} else {
		print $cfg->get( 'DATA_OBJECT_FAIL' ), "$base_dir/$data_file\n";
	}
} else {
    print $cfg->get( 'LISTFILE_NOT_DEFINED' );
}

# output XHTML or HTML footer
my $footer = $cfg->get( 'MSGFooter' );
open( FOOT, "$footer" );
print <FOOT>;
close( FOOT );

$sub_run = 1;    # make sure we don't run anything else
} # end show_message

# ***************END OF SHOW_MESSAGE ROUTINE**************

# ***************show_thread ROUTINE************************
# :::::::::::::::::::::::::::::::::::::::::::::::::::
# show_thread() runs if proc = ShowThr,
#    displays the complete thread that contains 'msg_id, starting at LIST_ROOT.
sub show_thread {

# output HTTP and XHTML or HTML headers
print "Content-type: ", $cfg->get( 'Content_type' ), "\n\n\n";
my $header = $cfg->get( 'LISTHeader' );
my $this_id = $cgi_data->param( "msg_id" );
&print_header( $header, "[$this_id]" );

print "\n<!-- In ShowThr -->\n\n" if $DEBUGGING;
my $data_file = $cfg->get( 'mesgfile' ) if( defined $cfg->get( 'mesgfile' ) );
if( defined $data_file ) {
	my $base_dir = $cfg->get( 'basedir' ) if( defined $cfg->get( 'basedir' ) );
    if( my $data = CGI::NMS::Scripts::NMSBoard::DataView->new( "$base_dir/$data_file" ) ) {    # create a NMSData object
		if( defined $this_id ) {
			$data->print_thread( $cgi_data, $cfg, $this_id );    # print the complete thread specified
			$data->print_form( $cgi_data, $cfg, $this_id );
		} else {
			print $cfg->get( 'MSGID_NOT_SPECIFIED' );
		}
	} else {
		print $cfg->get( 'DATA_OBJECT_FAIL' ), "$base_dir/$data_file\n";
	}
} else {
    print $cfg->get( 'LISTFILE_NOT_DEFINED' );
}

# output XHTML or HTML footer
my $footer = $cfg->get( 'LISTFooter' );
open( FOOT, "$footer" );
print <FOOT>;
close( FOOT );

$sub_run = 1;    # make sure we don't run anything else
} # end show_thread

# ***************END OF SHOW_THREAD ROUTINE**************

# ***************PRINT_HEADER ROUTINE************************
# :::::::::::::::::::::::::::::::::::::::::::::::::::
# print_header() called to print & parser the head XHTML
#    Parameters: 
#        $cfg - Config object
#        $hdr - The header template path
#		 $id - LIST = 0 or ''  | THREAD = [ID] | MESSAGE = ID
#    Return:
#        1 on success, 0 on failure
sub print_header {

# output HTTP and XHTML or HTML headers
my $hdr = shift @_;
my $id = shift @_ if @_;
my $context = '';
if( defined $id ) {
	$context = '_MESSAGE';
}
if( defined $id && ($id =~ s/\[([0-9]+)\]/$1/ ) ) {
	$context = '_THREAD';
}

open( HEAD, "$hdr" );
my @tmpl = <HEAD>;
close( HEAD );

foreach( @tmpl ) {
	# 'PARSE_ITEM_*' strings in template return the value from the Config object that matches the * part
	$_ =~ s/{=\s*NMS_CFG_ITEM_([a-zA-Z0-9_-]+)\s*=}/$cfg->get( "$1$context" )/ge;  
	if( $id ){
		$_ =~ s/{=\s*NMS_ID_NUM\s*=}/$id/g;
	} else {
		$_ =~ s/{=\s*NMS_ID_NUMs*=}//g;
	}
	print $_;
}
return 1;

} # end print_header

# ***************END OF PRINT_HEADER ROUTINE**************




