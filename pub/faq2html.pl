#!/usr/bin/perl

use strict;
use warnings;

package NMS::Pod::View::HTML;

# Let Pod::POM::View::HTML do the heavy lifting
use Pod::POM::View::HTML;
our @ISA = 'Pod::POM::View::HTML';

my @toc;

# most of what we need to do is push the =headX levels down one,
# so =head1 becomes a <h2>, etc...
# Just handle =head1, =head2 and =head3 as that's all we currently have.
sub view_head1 {
  my ($self, $head) = @_;
  my $title = $head->title->present($self);
  return "<h2>$title</h2>\n\n"
	. $head->content->present($self);
}

sub view_head2 {
  my ($self, $head) = @_;
  my $title = $head->title->present($self);
  push @toc, { title => $title, url => _clean($title) };
  return qq(<h3><a name="$toc[-1]->{url}">$title</a></h3>\n\n)
	. $head->content->present($self);
}

sub view_head3 {
  my ($self, $head) = @_;
  my $title = $head->title->present($self);
  return "<h4>$title</h4>\n\n"
	. $head->content->present($self);
}

# remove invalid characters from a string that will be used in a URL
sub _clean {
  my $string = shift;

  $string =~ s/\W+/_/g;
  $string =~ s/^_+//;
  $string =~ s/_+$//;

  return $string;
}

# Also need to override the view_pod method to produce template stuff
# instead of HTML stuff
sub view_pod {
  my ($self, $pod) = @_;
  @toc = ();
  my $content = $pod->content->present($self);
  my $toc = join "\n",
            map { qq(<li><a href="#$_->{url}">$_->{title}</a></li>) } @toc;
  return qq([% META page="faqs" %]\n[% WRAPPER page.tt %]\n)
    . qq(<p class="bread">[<a href="faq_nms.html">General <span class="nms">nms</span> Questions</a>])
    . qq( [<a href="faq_perl.html">Perl Questions</a>])
    . qq( [<a href="faq_prob.html">Common Problems</a>])
    . "</p>\n"
    . "<ul>$toc</ul>"
    . $content
    . "\n[% END %]\n";
}

package main;

use Pod::POM;

# where the faq pods are found
my $faq_dir = '../docs';

# names of the faq pods
my @faqs = qw(prob perl nms);

# where the templates go
my $tmp_dir = './in';

my $parser = Pod::POM->new( warn => 1 )
    || die "$Pod::POM::ERROR\n";

foreach (@faqs) {
  my $pom = $parser->parse_file("$faq_dir/faq_$_.pod")
    || die $parser->error(), "\n";

  open TMPL, ">$tmp_dir/faq_$_.html" or die $!;

  print TMPL NMS::Pod::View::HTML->print($pom);
}
