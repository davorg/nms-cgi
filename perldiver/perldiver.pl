#!/usr/bin/perl -wT
#
# $Id: perldiver.pl,v 1.4 2002-07-20 08:56:39 gellyfish Exp $
#
use strict;
use subs 'File::Find::chdir';
use File::Find;

delete @ENV{qw(BASH_ENV ENV IFS)};

$ENV{PATH} = '/bin:/usr/bin';

my $plocation  = join('<br />', split(' ', `whereis perl`));
my $sendmail   = join('<br />', split(' ', `whereis sendmail`));
my $inc        = join('<br />', @INC);

my $dev = 'nms';
my $program = 'perldiver';
my $version = sprintf "%d.%02d", '$Revision: 1.4 $ ' =~ /(\d+)\.(\d+)/;

my $env;
foreach (keys %ENV){
  $env .= qq(<tr><th width="35%" valign="top">$_</th><td width="65%" valign="top">$ENV{$_}</td></tr>\n);
}

my @foundmods;
find( \&wanted, @INC);

my %found;
foreach (@foundmods)
{
   ++$found{$_} ;
}

@foundmods = sort keys(%found);
my $modcount = @foundmods;

my $third = int(@foundmods / 3);

push @foundmods, '' while @foundmods % 3;

my $mods;
for (0 .. $third) {
  $mods .= qq(<tr><td width="33%">$foundmods[$_]</td><td width="33%">$foundmods[$_ + $third + 1]</td><td width="33%">$foundmods[$_ + 2 + (2 * $third)]</td></tr>\n);
}

print "Content-type:  text/html\n\n";

my $page = do { local $/; <DATA>};

$page =~ s/\[%\s*(\S+)\s*%]/$1/eeg;

print $page;

exit;

sub wanted {
  if ($File::Find::name =~ /\.pm$/){
    open(MODFILE, $File::Find::name) || return;
    while(<MODFILE>){
      if (/^ *package +(\S+);/) {
	push (@foundmods, $1);
	last;
      }
    }
  }
}

sub File::Find::chdir
{
   return CORE::chdir(main::detaint_dirname($_[0]));
}

sub detaint_dirname
{
    my ($dirname) = @_;

    $dirname =~ m|^([:\\+@\w./-]*)$| or die "suspect directory name: $dirname";
    return $1;
}


__END__
<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>[% $program %] [% $version %]</title>
<style type="text/css">
body { font-family: Verdana, sans serif;
       font-weight: normal; }
th { background-color: ghostwhite;
     text-align: left;
     font-weight: bold; }
</style>
</head>
<body>

<h1>[% $program %] [% $version %]</h1>
<h2>Server Program Paths</h2>
<table border="0" cellpadding="3" width="95%">
<tr>
<th valign="top" width="35%">Perl Executable:</th>
<td valign="top">[% $^X %]</td>
</tr>
<tr>
<th valign="top">Perl Version:</th>
<td valign="top">[% $] %]</td>
</tr>
<tr>
<th valign="top">Perl compile version OS:</th>
<td valign="top">[% $^O %]</td>
</tr>
<tr>
<th valign="top">GID: <span style="font-size: smaller; font-weight:normal">(If not blank, you are on a machine that supports membership in multiple groups simultaneously)</span></th>
<td valign="top">[% $< %]</td>
</tr>
<tr>
<th valign="top">Location of Perl:</th>
<td valign="top">[% $plocation %]</td>
</tr>
<tr>
<th valign="top">Location of Sendmail:</th>
<td valign="top">[% $sendmail %]</td>
</tr>
<tr>
<th valign="top">Directory locations searched for perl modules</th>
<td valign="top">[% $inc %]</td>
</tr>
</table>

<h2>Environment Variables</h2>
<table border="0" cellpadding="3" width="95%">[% $env %]</table>

<h2>Installed Modules</h2>
<p>[% $modcount %] modules found</p>
<table border="0" cellpadding="3" width="95%">
[% $mods %]
</table>
<hr />
<address>perldiver is Copyright &copy; 2002, London Perl Mongers. Latest
version of this and many other scripts is always available from
<a href="http://nms-cgi.sourceforge.net/">the <i>nms</i> project</a>.</address>
</body>
</html>
