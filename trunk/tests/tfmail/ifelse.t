#!/usr/bin/perl -w
use strict;

use NMSTest::ScriptUnderTest;

@LocalChecks::ISA = qw(NMSTest::OutputChecker);

my %files =
(
  _CFG   => {
             START => \&cfg,
             NAME  => 'default.trc',
            },
  _SPAGE => {
             START => \&spage,
             NAME  => 'spage.trt',
            },
);

my $t = NMSTest::ScriptUnderTest->new(
   SCRIPT      => 'tfmail/TFmail.pl',
   REWRITERS   => [ \&rw_setup ],
   FILES       => \%files,
   CHECKER     => 'LocalChecks',
   CHECKS      => 'nodie nomail foobar',
);

use vars qw($good $bad);

foreach my $test (
  [
    'allfalse',
    ['wee=wee'],
    ['no FOO'],
    ['bar', 'found the FOO'],
  ],
  [
    'foo',
    ['foo=foo'],
    ['found the FOO'],
    ['bar', 'no FOO'],
  ],
  [
    'bar',
    ['bar=bar'],
    ['no FOO', 'bar and not foo'],
    ['bar and foo', 'found the FOO'],
  ],
  [
    'foobar',
    ['foo=foo', 'bar=bar'],
    ['bar and foo', 'found the FOO'],
    ['no FOO', 'not foo'],
  ],)
{
   my ($name, $args);
   ($name, $args, $good, $bad) = @$test;
   $t->run_test(
      TEST_ID  => "if-else $name",
      CGI_ARGS => $args,
   );
}   

sub cfg
{
   return <<END;
%% NMS configuration file %%
no_email: 1
END
}

sub spage
{
   return <<END;
%% NMS html template file %%
<html>
{= IF param.foo =}
   <p>found the FOO!!!</p>
   {= IF param.bar =}
      <p>bar and foo</p>
   {= END =}
{= ELSE =}
   <p>there is no FOO!!!</p>
   {= IF param.bar =}
      <p>bar and not foo</p>
   {= END =}
{= END =}
</html>
END
}

sub LocalChecks::check_foobar
{
   my ($self) = @_;

   foreach my $g (@$good)
   {
      unless ($self->{PAGES}{OUT} =~ /\Q$g/)
      {
         die "expected string [$g] not found in output\n";
      }
   }

   foreach my $b (@$bad)
   {
      if ($self->{PAGES}{OUT} =~ /\Q$b/)
      {
         die "unexpected string [$b] found in output\n";
      }
   }
}

sub rw_setup
{
   my $cfg_root = $files{_CFG}{PATH};
   $cfg_root =~ s#/[^/]+$##;

   s{(POSTMASTER\s*=>).*}  {$1 'postmaster\@post.master.domain';};
   s{(LIBDIR\s*=>).*}      {$1 '$ENV{NMS_WORKING_COPY}/tfmail';};
   s{(CONFIG_ROOT\s*=>).*} {$1 '$cfg_root';};
}


