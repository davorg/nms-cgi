package CGI::NMS::HTMLFilter;
use strict;

require 5.00404;

use vars qw($VERSION);
$VERSION = sprintf '%d.%.2d', (q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use CGI::NMS::Charset;

=head1 NAME

CGI::NMS::HTMLFilter - whitelist based HTML filter

=head1 SYNOPSIS

   #
   # A simple way to strip malicious scripting constructs from
   # HTML that comes from an untrusted source:
   #

   use CGI::NMS::HTMLFilter;

   my $filter = CGI::NMS::HTMLFilter->new; 
   my $safe_html = $filter->filter($untrused_html);


   #
   # More advanced usage:
   # 

   use CGI::NMS::Charset;
   use CGI::NMS::HTMLFilter;

   my $charset = CGI::NMS::Charset->new('utf-8');

   my $filter = CGI::NMS::HTMLFilter->new(
      charset        => $charset,
      deny_tags      => ['hr'],
      allow_src      => 1,
      allow_href     => 1,
      allow_a_mailto => 1,
   );

   my $safe_html = $filter->filter($untrusted_html, 'Inline');

=head1 DESCRIPTION

This module provides a way to strip potentially malicious
scripting constucts from a block of HTML that has come from
an untrusted source.  Most harmless markup is allowed through.

It is well suited to filtering blocks of HTML that are to be
interpolated into the body of a page, less so for filtering
entire untrusted HTML documents.

To ensure security, a whitelist of harmless tags is used
rather than a blacklist of dangerous constructs.  By default,
this whitelist includes most commonly used cosmetic tags,
including tables but not including forms.

The filter ensures that there is a matching close tag for
each open tag, and that tags are closed in the proper order.

There is a bias towards XHTML in the output of the filter, but
some commonly used harmless that are illegal in XHTML are
allowed, such as the C<E<lt>nobrE<gt>> tag.

=head1 CONSTRUCTORS

=over

=item new ( OPTIONS )

Creates a new C<CGI::NMS::HTMLFilter> object, bound to a
particular character set and HTML filtering policy.

The OPTIONS are a list of key/value pairs.  The following
options are recognised:

=over

=item C<charset>

If present, the value for this option must be an object of class
C<CGI::NMS::Charset>, bound to the character set of the input data.
The default is C<iso-8859-1>.

=item C<deny_tags>

If present, the value for this option must be an array reference,
and the elements of the array must be the lower case names of HTML
tags.  These tags will be disallowed by the filter even if they
would normally be allowed because they present no cross site
scripting hazard.

=item C<allow_src>

By default, the filter won't allow constructs that cause 
the browser to fetch things automatically, such as C<E<lt>imgE<gt>>
tags and C<background> attributes.  If this option is present and
true then those constructs will be allowed.

=item C<allow_href>

By default, the filter won't allow constructs that cause the 
browser to fetch things if the user clicks on something, such
as the C<href> attribute in C<E<lt>aE<gt>> tags.  Set this option
to a true value to allow this type of construct.

=item C<allow_a_mailto>

By default, the filter won't allow C<mailto> URLs in C<E<lt>aE<gt>>
tags.  Set this option to a true value to allow C<mailto> URLs.

=back

=cut

use vars qw(%_Attributes %_Context %_Auto_deinterleave);

sub new
{
   my ($pkg, %opts) = @_;

   my $charset = $opts{charset} || CGI::NMS::Charset->new('iso-8859-1');

   my $self = {
                ESCAPE  => $charset->escape_html_coderef,
                STRIP   => $charset->strip_nonprint_coderef,
                OPTS    => \%opts,
                TAGS    => { %_Attributes },
              };
                
   if (exists $opts{deny_tags})
   {
      foreach my $deny (@{ $opts{deny_tags} })
      {
         delete $self->{TAGS}{$deny};
      }
   }

   delete $self->{TAGS}{img} unless $opts{allow_src};

   return bless $self, $pkg;
}

=back

=head1 METHODS

=over

=item filter ( INPUT [,CONTEXT] )

Applies the filter to the HTML string INPUT, and returns the
resulting string.  Any tags that the filter isn't configured
to pass will be removed, and any HTML metacharacters that
don't form part of acceptable tags or entities will be escaped.

The optional CONTEXT parameter can be used to limit the
allowed tags to a subset of the tags the that filter is
configured to pass.  A CONTEXT value of 'Inline' disallows
block level tags such as lists, paragraphs and tables.  A
CONTEXT value of 'Notags' dissallows all tags.  The default
CONTEXT of 'Flow' allows all tags that the filter is
configured to pass.

=cut

sub filter
{
   my ($self, $input, $context) = @_;

   $input = &{ $self->{STRIP} }($input);

   #
   # We maintain a stack of open tags, so that we can ensure
   # that all opened tags are closed and misplaced closing
   # tags are discarded.
   #
   # The items on this stack are hashrefs, with a NAME key
   # holding the name of the tag, a FULL key holding the full
   # text of the filtered tag (including anglebrackets) and
   # a CTX key holding the context that the tag provides.
   # 
   # The stack starts off holding a single fake tag, needed
   # to define the top level context.
   #
   $self->{STACK} = [{
                      NAME => '',
                      FULL => '',
                      CTX  => $context || 'Flow',
                    }];

   $input =~
    s[
      # An HTML comment - remove it
      (?: <!--.*?-->                                   ) |

      # Some sort of XML or DOCTYPE header - remove it
      (?: <[?!].*?>                                    ) |

      # An HTML tag.  $1 gets the name of the tag, $2
      # gets any other text up to the closing '>'
      (?: <([a-z0-9]+)\b((?:[^>'"]|"[^"]*"|'[^']*')*)> ) |

      # A closing tag.  $3 gets the tag name.
      (?: </([a-z0-9]+)>                               ) |

      # $4 gets some non-tag text.  We eat '<' only if
      # it's the first character, since a '<' as the
      # first character can't be the start of a well
      # formed tag or one of the patterns above would
      # have matched.
      (?: (.[^<]*)                                     )

    ][
      defined $1 ? $self->_filter_tag(lc $1, $2)       :
      defined $3 ? $self->_filter_close(lc $3)         :
      defined $4 ? $self->_filter_cdata($4)            :
      ' '
    ]igesx;

   # Ditch the fake tag that sets top level context, then use the
   # stack to close any tag that was left open.
   pop @{ $self->{STACK} };
   $input .= join '', map "</$_->{NAME}>", @{ $self->{STACK} };

   return $input;
}

=back

=head1 PRIVATE METHODS

=over

=item _filter_tag ( TAG, ATTRS )

Deals with a single HTML tag encountered in the filter's input.  The
TAG argument is the lower case tag name, and ATTRS is any text that
was found between the tag name and the E<gt> character that ends the
tag.

Returns the string that should replace this tag in the filter output.

=cut

sub _filter_tag
{
   my ($self, $tag, $attrs) = @_;

   return ' ' unless exists $self->{TAGS}{$tag};

   if ($tag eq 'a')
   {
      # special case: nested <a> is never allowed.
      foreach my $tag (@{ $self->{STACK} })
      {
         return ' ' if $tag->{NAME} eq 'a';
      }
   }

   my $pre_close = '';
   return ' ' unless $self->_close_until_ok($tag, \$pre_close);

   my $t = $self->{TAGS}{$tag};
   my $safe_attrs = '';
   while ($attrs =~ s#^\s*(\w+)(?:\s*=\s*(?:([^"'>\s]+)|"([^"]*)"|'([^']*)'))?##)
   {
      my $attr = lc $1;
      my $val = ( defined $2 ? $2                        :
                  defined $3 ? $self->_unescape_html($3) :
                  defined $4 ? $self->_unescape_html($4) :
                  ''
                );

      next unless exists $t->{$attr};

      my $cleaned = &{ $t->{$attr} }($val, $attr, $tag, $self);
      if (defined $cleaned)
      {
         my $escaped = &{ $self->{ESCAPE} }($cleaned);
         $safe_attrs .= qq| $attr="$escaped"|;
      }
   }

   my $new_context = $_Context{ $self->{STACK}[0]{CTX} }{ $tag };
   if ($new_context eq 'EMPTY')
   {
      return "$pre_close<$tag$safe_attrs />";
   }
   else
   {
      my $html = "<$tag$safe_attrs>";
      unshift @{ $self->{STACK} }, {
                                     NAME => $tag,
                                     FULL => $html,
                                     CTX  => $new_context
                                   };
      return "$pre_close$html";
   }
}

=item _close_until_ok( TAGNAME, OUTPUT )

If the tag TAGNAME is allowed in the current context or in
any context above, close tags until we reach a context where
TAGNAME is allowed and return true.  Otherwise return false.

OUTPUT is a scalar ref to which the text of any closing tags
generated will be appended.

=cut

sub _close_until_ok
{
   my ($self, $tag, $output) = @_;

   return 0 unless grep {exists $_Context{ $_->{CTX} }{$tag}} @{ $self->{STACK} };

   until (exists $_Context{ $self->{STACK}[0]{CTX} }{$tag})
   {
      $$output .= "</$self->{STACK}[0]{NAME}>";
      shift @{ $self->{STACK} };
      die 'tag stack underflow' unless scalar @{ $self->{STACK} };
   }
}

=item _filter_close ( TAG )

Deals with a single HTML closing tag encountered in the filter's input.
The TAG argument is the lowercase name of the closing tag.

Returns the string that should replace this closing tag in the filter
output.

=cut

sub _filter_close
{
   my ($self, $tag) = @_;

   # Ignore a close without an open
   return ' ' unless grep {$_->{NAME} eq $tag} @{ $self->{STACK} };

   # Close open tags up to the matching open
   my @close = ();
   while (scalar @{ $self->{STACK} } and $self->{STACK}[0]{NAME} ne $tag)
   {
      push @close, shift @{ $self->{STACK} };
   }
   push @close, shift @{ $self->{STACK} };

   my $html = join '', map {"</$_->{NAME}>"} @close;

   # Reopen any we closed early if all that were closed are
   # configured to be auto deinterleaved.
   unless (grep {! exists $_Auto_deinterleave{$_->{NAME}} } @close)
   {
      pop @close;
      $html .= join '', map {$_->{FULL}} reverse @close;
      unshift @{ $self->{STACK} }, @close;
   }

   return $html;
}

=item _filter_cdata ( CDATA )

Deals with a block of CDATA (i.e. text without opening or closing tags)
encountered in the filter's input.  Well-formed HTML entities such as
C<&amp;> pass through unaltered - other than that all HTML metacharacters
are escaped.

Returns the string that should replace this block of CDATA in the
filter output.

=cut

sub _filter_cdata
{
   my ($self, $cdata) = @_;

   # Discard the CDATA if it's somewhere that CDATA shouldn't be, 
   # like <table>hello</table>
   return ' ' if $cdata =~ /\S/ and not $_Context{ $self->{STACK}[0]{CTX} }{CDATA};

   $cdata =~ 
    s[ (?: & ( [a-zA-Z0-9]{2,15}       |
               [#][0-9]{2,6}           |
               [#][xX][a-fA-F0-9]{2,6}
             )
           ;
       ) | (.[^&]*)
    ][
       defined $1 ? "&$1;" : &{ $self->{ESCAPE} }($2)
    ]gesx;

  return $cdata;
}

=item _unescape_html ( STRING )

This method is applied to attribute values found between pairs of
doublequotes or singlequotes before processing them.  It returns
a copy of STRING with all entity encodings of C<us-ascii> characters
replaced with the characters they represent.

=cut

use vars qw(%_unescape_map);
%_unescape_map = ( 
                   ( map { ("\&\#$_\;" => chr($_)) } (1..255) ),
                   '&amp;'  => '&',
                   '&lt;'   => '<',
                   '&gt;'   => '>',
                   '&quot;' => '"',
                   '&apos;' => "'",
                 );

sub _unescape_html
{
   my ($self, $string) = @_;

   $string =~ s/(&[\w\#]{1,4};)/ $_unescape_map{$1} || $1 /ge;
   return &{ $self->{STRIP} }($string);
}

=back

=head1 METHODS TO OVERRIDE

Subclasses can replace these methods to alter the filter's
behavior.

=over

=item url_is_valid ( URL )

Returns true if the string URL holds a valid URL for an image
source or a link target, false otherwise.

Mailto URLs are handled separately and should not be recognized
by this method.

=cut

sub url_is_valid
{
   my ($self, $url) = @_;

   $url =~ m< ^ https? :// [\w\-\.]{1,100} (?:\:\d+)?
                (?: / [\w\-.!~*|;/?\@&=+\$,%#]{0,100} )?
              $
            >x ? 1 : 0;
}

=back

=head1 PRIVATE DATA STRUCTURES

These read-only data structures are used to initialise the policy
data.

=over

=item C<%_Context>

A hash by context name of hashes by tag name, specifying the set of
tags that are allowed in each context.  The values in the per-tag
subhashes are context names, giving the context that the tag
provides to other tags nested within it.

The context names are strings such as C<Inline> or C<Flow>, mostly
taken from the XHTML1 transitional DTD, see
C<http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd>.  The
string C<EMPTY> as a context is used for tags such as C<E<lt>imgE<gt>>,
which have no nested content or corresponding C<E<lt>/imgE<gt>> tag.

=cut

my %pre_content = (
  'br'      => 'EMPTY',
  'span'    => 'Inline',
  'tt'      => 'Inline',
  'i'       => 'Inline',
  'b'       => 'Inline',
  'u'       => 'Inline',
  's'       => 'Inline',
  'strike'  => 'Inline',
  'em'      => 'Inline',
  'strong'  => 'Inline',
  'dfn'     => 'Inline',
  'code'    => 'Inline',
  'q'       => 'Inline',
  'samp'    => 'Inline',
  'kbd'     => 'Inline',
  'var'     => 'Inline',
  'cite'    => 'Inline',
  'abbr'    => 'Inline',
  'acronym' => 'Inline',
  'ins'     => 'Inline',
  'del'     => 'Inline',
  'a'       => 'Inline',
  'CDATA'   => 'CDATA',
);

my %inline = (
  %pre_content,
  'img'   => 'EMPTY',
  'big'   => 'Inline',
  'small' => 'Inline',
  'sub'   => 'Inline',
  'sup'   => 'Inline',
  'font'  => 'Inline',
  'nobr'  => 'Inline',
);
  
my %flow = (
  %inline,
  'ins'        => 'Flow',
  'del'        => 'Flow',
  'div'        => 'Flow',
  'p'          => 'Inline',
  'h1'         => 'Inline',
  'h2'         => 'Inline',
  'h3'         => 'Inline',
  'h4'         => 'Inline',
  'h5'         => 'Inline',
  'h6'         => 'Inline',
  'ul'         => 'list',
  'ol'         => 'list',
  'menu'       => 'list',
  'dir'        => 'list',
  'dl'         => 'dt_dd',
  'address'    => 'Inline',
  'hr'         => 'EMPTY',
  'pre'        => 'pre.content',
  'blockquote' => 'Flow',
  'center'     => 'Flow',
  'table'      => 'table',
);

my %table = (
  'caption'  => 'Inline',
  'thead'    => 'tr_only',
  'tfoot'    => 'tr_only',
  'tbody'    => 'tr_only',
  'colgroup' => 'colgroup',
  'col'      => 'EMPTY',
  'tr'       => 'th_td',
  'th'       => 'Flow',
  'td'       => 'Flow',
);

%_Context = (
  'Inline'      => \%inline,
  'Flow'        => \%flow,
  'Notags'      => { 'CDATA' => 'CDATA' },
  'pre.content' => \%pre_content,
  'table'       => \%table,
  'list'        => { 'li' => 'Flow' },
  'dt_dd'       => { 'dt' => 'Inline', 'dd' => 'Flow' },
  'tr_only'     => { 'tr' => 'th_td' },
  'colgroup'    => { 'col' => 'EMPTY' },
  'th_td'       => { 'th' => 'Flow', 'td' => 'Flow' },
);

=item C<%_Auto_deinterleave>

A hash by tag name with true values for tags that should be
automatically untangled when encountered interleaved.  For
example, both C<E<lt>iE<gt>> and C<E<lt>bE<gt>> are in the
C<%_Auto_deinterleave> hash, so this:

    normal<i>italic<b>bold-italic</i>bold</b>normal

will be converted by the filter into this:

    normal<i>italic<b>bold-italic</b></i><b>bold</b>normal

=cut

%_Auto_deinterleave = map {$_ => 1} qw(

  tt i b big small u s strike font em strong dfn code
  q sub sup samp kbd var cite abbr acronym span

);

=item C<%_Attributes>

A hash by tag name of hashes by attribute name.  A tag is permitted
only if it appears in this hash, and a tag may have a particular
attribute only if the attribute appears in that tag's subhash.

The values in the attribute subhashes are coderefs to attribute
handler subs.  Whenever the filter encounters a permitted attribute,
it will invoke the corresponding attribute handler sub with the
following arguments:

=over

=item C<$_[0]>

The decoded attribute value.

=item C<$_[1]>

The lowercase attribute name.

=item C<$_[2]>

The lowercase tag name

=item C<$_[3]>

A reference to the C<CGI::NMS::HTMLFilter> object.

=back

The attribute handler may return either C<undef> (to delete this
attribute from the tag) or a new value for the attribute as a
string.  The attribute handler should not escape HTML
metacharacters in the returned value.

=cut

my %attr = ( 'style' => \&_attr_style );

my %font_attr = (
  %attr,
  'size'  => sub { $_[0] =~ /^([-+]?\d{1,3})$/    ? $1 : undef },
  'face'  => sub { $_[0] =~ /^([\w\-, ]{2,100})$/ ? $1 : undef },
  'color' => \&_attr_color,
);

my %insdel_attr = (
  %attr,
  'cite'     => \&_attr_uri,
  'datetime' => \&_attr_text,
);

my %texta_attr = (
  %attr,
  'align' => sub {
                   $_[0] =~ s/middle/center/i;
                   $_[0] =~ /^(left|center|right)$/i ? lc $1 : undef;
                 },
);

my %cellha_attr = (
  'align'    => sub {
                      $_[0] =~ s/middle/center/i;
                      $_[0] =~ /^(left|center|right|justify|char)$/i ? lc $1 : undef;
                    },
  'char'     => sub { $_[0] =~ /^([\w\-])$/ ? $1 : undef },
  'charoff'  => \&_attr_length,
);

my %cellva_attr = (
  'valign' => sub {
                    $_[0] =~ s/center/middle/i;
                    $_[0] =~ /^(top|middle|bottom|baseline)$/i ? lc $1 : undef;
                  },
);

my %cellhv_attr = ( %attr, %cellha_attr, %cellva_attr );

my %col_attr = (
  %attr, %cellhv_attr,
  'width' => sub { $_[0] =~ /^(\d+(?:\.\d+)?[*%]?)$/ ? $1 : undef },
  'span'  => \&_attr_number,
);

my %thtd_attr = (
  %attr,
  'abbr'    => \&_attr_text,
  'axis'    => \&_attr_text,
  'headers' => \&_attr_text,
  'scope'   => sub { $_[0] =~ /^(row|col|rowgroup|colgroup)$/i ? lc $1 : undef },
  'rowspan' => \&_attr_number,
  'colspan' => \&_attr_number,
  %cellhv_attr,
  'nowrap'  => sub {'nowrap'},
  'bgcolor' => \&_attr_color,
  'width'   => \&_attr_number,
  'height'  => \&_attr_number,
);

%_Attributes = (

  'br'         => { 
                    'clear' => sub { $_[0] =~ /^(left|right|all|none)$/i ? lc $1 : undef }
                  },
  'em'         => \%attr,
  'strong'     => \%attr,
  'dfn'        => \%attr,
  'code'       => \%attr,
  'samp'       => \%attr,
  'kbd'        => \%attr,
  'var'        => \%attr,
  'cite'       => \%attr,
  'abbr'       => \%attr,
  'acronym'    => \%attr,
  'q'          => { %attr, 'cite' => \&_attr_href },
  'blockquote' => { %attr, 'cite' => \&_attr_href },
  'sub'        => \%attr,
  'sup'        => \%attr,
  'tt'         => \%attr,
  'i'          => \%attr,
  'b'          => \%attr,
  'big'        => \%attr,
  'small'      => \%attr,
  'u'          => \%attr,
  's'          => \%attr,
  'strike'     => \%attr,
  'font'       => \%font_attr,
  'table'      => { %attr,
                    'frame'       => \&_attr_tframe,
                    'rules'       => \&_attr_trules,
                    %texta_attr,
                    'bgcolor'     => \&_attr_color,
                    'width'       => \&_attr_length,
                    'cellspacing' => \&_attr_length,
                    'cellpadding' => \&_attr_length,
                    'border'      => \&_attr_number,
                    'summary'     => \&_attr_text,
                  },
  'caption'    => { %attr,
                    'align' => sub { $_[0] =~ /^(top|bottom|left|right)$/i ? lc $1 : undef },
                  },
  'colgroup'   => \%col_attr,
  'col'        => \%col_attr,
  'thead'      => \%cellhv_attr,
  'tfoot'      => \%cellhv_attr,
  'tbody'      => \%cellhv_attr,
  'tr'         => { %attr,
                    bgcolor => \&_attr_color,
                    %cellhv_attr,
                  },
  'th'         => \%thtd_attr,
  'td'         => \%thtd_attr,
  'ins'        => \%insdel_attr,
  'del'        => \%insdel_attr,
  'a'          => { %attr,
                    href => \&_attr_a_href,
                  },
  'h1'         => \%texta_attr,
  'h2'         => \%texta_attr,
  'h3'         => \%texta_attr,
  'h4'         => \%texta_attr,
  'h5'         => \%texta_attr,
  'h6'         => \%texta_attr,
  'p'          => \%texta_attr,
  'div'        => \%texta_attr,
  'span'       => \%texta_attr,
  'ul'         => { %attr,
                    'type'    => sub { $_[0] =~ /^(disc|square|circle)$/i ? lc $1 : undef },
                    'compact' => sub {'compact'},
                  },
  'ol'         => { %attr,
                    'type'    => \&_attr_text,
                    'compact' => sub {'compact'},
                    'start'   => \&_attr_number,
                  },
  'li'         => { %attr,
                    'type'  => \&_attr_text,
                    'value' => \&_no_number,
                  },
  'dl'         => { %attr, 'compact' => sub {'compact'} },
  'dt'         => \%attr,
  'dd'         => \%attr,
  'address'    => \%attr,
  'hr'         => { %texta_attr,
                    'width'   => \&_attr_length,
                    'size '   => \&_attr_number,
                    'noshade' => sub {'noshade'},
                  },
  'pre'        => { %attr, 'width' => \&_attr_number },
  'center'     => \%attr,
  'nobr'       => {},
  'img'        => { 'src'    => \&_attr_src,
                    'alt'    => \&_attr_text,
                    'width'  => \&_attr_length,
                    'height' => \&_attr_length,
                    'border' => \&_attr_length,
                    'hspace' => \&_attr_number,
                    'vspace' => \&_attr_number,
                    'align'  => sub {
                                      $_[0] =~ s/center/middle/i;
                                      $_[0] =~ /^(top|middle|bottom|left|right)$/i ? lc $1 : undef;
                                    },
                  },
);

=back

=head1 ATTRIBUTE HANDLER SUBS

Some of the more complex attribute handler subs used in the
C<%_Attributes> hash are named subs rather than anonymous coderefs.

=over

=item _attr_style ( INPUT, ATTRNAME, TAGNAME, FILTER )

Handles the C<style> attribute.

=cut 

use vars qw(%_safe_style);
%_safe_style = (
  'color'            => \&_attr_color,
  'background-color' => \&_attr_color,
);

sub _attr_style
{
   my @clean = ();

   foreach my $elt (split /;/, $_[0])
   {
      next if $elt =~ m#^\s*$#;
      if ( $elt =~ m#^\s*([\w\-]+)\s*:\s*(.+?)\s*$#s )
      {
         my ($key, $val) = (lc $1, $2);
         my $sub = $_safe_style{$key};
         if (defined $sub)
         {
            my $cleanval = &{$sub}($val, $key, 'style-psuedo-attr', $_[3]);
            if (defined $cleanval)
            {
               push @clean, "$key:$val";
            }
         }
      }
   }

   return join '; ', @clean;
}

=item _attr_src ( INPUT, ATTRNAME, TAGNAME, FILTER )

A hander for attributes that cause an implicit fetch of an image, such
as C<img src>.

=cut

sub _attr_src
{
   my $filter = $_[3];

   ($filter->{OPTS}{allow_src} and $filter->url_is_valid($_[0])) ? $_[0] : undef;
}
   
=item _attr_a_href ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<href> attribute in the C<a> tag, allowing C<mailto>
URLs if the filter is so configured.

=cut

sub _attr_a_href
{ 

   if ($_[0] =~ /^mailto:([\w\-\.\,\=\*]{1,100}\@[\w\-\.]{1,100})$/i)
   {
      my $filter = $_[3];
      return ($filter->{OPTS}{allow_a_mailto} ? "mailto:$1" : undef);
   }
   else
   {
      return _attr_href(@_);
   }
}

=item _attr_href ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes that offer a link to the user, such as C<a href>.

=cut

sub _attr_href
{
   my $filter = $_[3];

   ($filter->{OPTS}{allow_href} and $filter->url_is_valid($_[0])) ? $_[0] : undef; 
}
   
=item _attr_number ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes who's value should be a positive integer

=cut

sub _attr_number { $_[0] =~ /^(\d{1,10})$/ ? $1 : undef }

=item _attr_length ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for attributes who's value should be a positive integer
or a percentage.

=cut

sub _attr_length { $_[0] =~ /^(\d{1,10}\%?)$/ ? $1 : undef }

=item _attr_text (INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for a text attribute such as C<img alt>.  Pretty much
wide open since the striping of non-printables is handled by the
filter itself.

=cut

sub _attr_text
{
   $_[0] =~ s#\s+# #g;
   length $_[0] <= 200 ? $_[0] : undef;
}

=item _attr_color ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for a color attribute

=cut

sub _attr_color { $_[0] =~ /^(\w{2,20}|#[\da-fA-F]{6})$/ ? $1 : undef }

=item _attr_tframe ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<table frame> attribute

=cut

sub _attr_tframe
{
  $_[0] =~ /^(void|above|below|hsides|lhs|rhs|vsides|box|border)$/i ? lc $1 : undef;
}

=item _attr_trules ( INPUT, ATTRNAME, TAGNAME, FILTER )

A handler for the C<table rules> attribute

=cut

sub _attr_trules { $_[0] =~ /^(none|groups|rows|cols|all)$/i ? lc $1 : undef }

=back

=head1 SEE ALSO

L<CGI::NMS::Charset>, C<http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd>

=head1 AUTHORS

The NMS project, E<lt>nms-cgi-devel@lists.sourceforge.netE<gt>

=head1 COPYRIGHT

Copyright 2002 London Perl Mongers, All rights reserved

=head1 LICENSE

This module is free software; you are free to redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;

