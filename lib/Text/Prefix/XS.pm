package Text::Prefix::XS;
use XSLoader;
use strict;
use warnings;

our $VERSION = '0.05';

XSLoader::load __PACKAGE__, $VERSION;
use base qw(Exporter);
our @EXPORT = qw(
    prefix_search_build
    prefix_search_create
    prefix_search);
1;

sub prefix_search_create(@)
{
    my @copy = @_;
    @copy = sort { length $b <=> length $a || $a cmp $b } @copy;
    return prefix_search_build(\@copy);
}

__END__

=head1 NAME

Text::Prefix::XS - Fast prefix searching

=head1 SYNOPSIS

    use Text::Prefix::XS;
    my @haystacks = qw(
        garbage
        blarrgh
        FOO
        meh
        AA-ggrr
        AB-hi!
    );
    
    my @needles = qw(AAA AB FOO FOO-BAR);
    
    my $search = prefix_search_create( map uc($_), @needles );
    
    my %seen_hash;
    
    foreach my $haystack (@haystacks) {
        if(my $prefix = prefix_search($search, $haystack)) {
            $seen_hash{$prefix}++;
        }
    }
    
    $seen_hash{'FOO'} == 1;
    
    #Compare to:
    my $re = join('|', map quotemeta $_, @needles);
    $re = qr/^($re)/;
    
    foreach my $haystack (@haystacks) {
        my ($match) = ($haystack =~ $re);
        if($match) {
            $seen_hash{$match}++;
        }
    }
    $seen_hash{'FOO'} == 1;

=head1 DESCRIPTION

This module implements something of an I<trie> algorithm for matching
(and extracting) prefixes from text strings.

A common application I had was to pre-filter lots and lots of text for a small
amount of preset prefixes.

Interestingly enough, the quickest solution until I wrote this module was to use
a large regular expression (as in the synopsis)

=head1 FUNCTIONS

The interface is relatively simple. This is alpha software and the API is subject
to change

=head2 prefix_search_create(@prefixes)

Create an opaque prefix search handle. It returns a thingy, which you should
keep around.

Internally it will order the elements in the list, with the longest prefix
being first.

It will then construct a search trie using a variety of caching and lookup layers.

=head2 prefix_search($thingy, $haystack)

Will check C<$haystack> for any of the prefixes in C<@needles> passed to
L</prefix_search_create>. If C<$haystack> has a prefix, it will be returned by
this function; otherwise, the return value is C<undef>

=head1 PERFORMANCE

In most normal use cases, C<Text::Prefix::XS> will outperform any other module
or search algorithm.

Specifically, this module is intended for a pessimistic search mechanism,
where most of the input is assumed not to match (which is usually the case anyway).

The ideal position of C<Text::Prefix::XS> would reside between raw but delimited
user input, and more complex searching and processing algorithms. This module
acts as a layer between those.

In addition to a trie, this module also uses a very fast sparse array to check
characters in the input against an index of known characters at the given
position. This is much quicker than a hash lookup.

See the C<trie.pl> script included with this distribution for detailed benchmark
comparison methods

Given a baseline of 1 CPU second - which is a non-capturing perl regex, the
following numbers appear:

    Pure-Perl based trie implementations:           1.75s
    Perl Regex (Capturing):                         1.30s
    RE2 Engine (Capturing):                         1.00s
    Perl Regex (Non-Capturing)                      1.00s
    Text::Match::FastAlternatives (Non-Capturing):  0.95
    RE2 Engine (Non-Capturing)                      0.85
    Text::Prefix::XS (implicit capturing)           0.60
    
I've mainly tested this on Debian's 5.10 - for newer perls, this module performs
better, and for el5 5.8, The differences are a bit lower. TBC


=head1 SEE ALSO 

There are quite a few modules out there which aim for a Trie-like search, but
they are all either not written in C, or would not be performant enough for this
application.

These two modules are implemented in pure perl, and are not part of the comparison.

L<Text::Trie>

L<Regexp::Trie>

L<Regexp::Optimizer>

L<Text::Match::FastAlternatives>

L<re::engine::RE2>


=head1 CAVEATS

I have yet to figure out a way to test this properly with threads. Currently
the trie data structure is stored as a private perl C<HV>, and I'm not sure
what happens when it's cloned across threads.

This algorithm performs quite poorly when search prefixes are very similar.

Search prefixes and search input is currently restricted to printable ASCII
characters

Search terms may not exceed 256 characters. You can increase this limit
(at the cost of more memory) by changing the C<#define> of
C<CHARTABLE_MAX> in the XS code and recompiling.

=head1 AUTHOR AND COPYRIGHT

Copyright (C) 2011 M. Nunberg

You may use and distribute this software under the same terms, conditions, and
licensing as Perl itself.

