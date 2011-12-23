#!/usr/bin/perl
use strict;
use warnings;
use Digest::SHA1 qw(sha1_hex);
use Data::Dumper;
use Time::HiRes qw(time);
use blib;
use Text::Prefix::XS;
use Log::Fu;
use Getopt::Long;
use Text::Match::FastAlternatives;
use List::MoreUtils qw(uniq);
use MIME::Base64;

GetOptions(
    'pp' => \my $UsePP,
    'xs' => \my $UseXS,
    're' => \my $UseRE,
    're2' => \my $UseRE2,
    'tmfa' => \my $UseTMFA,
    'cached' => \my $UseCached,
    'cycles=i' => \my $Cycles,
    'count=i' => \my $StringCount,
);

$Cycles ||= 0;
$StringCount ||= 2_000_000;

if(!($UsePP||$UseXS||$UseRE||$UseRE2)) {
    $UsePP = 1;
    $UseXS = 1;
    $UseRE = 1;
    $UseRE2 = 1;
    $UseTMFA = 1;
}

my %index;
my %fullmatch;
my $matches = 0;
my $match_first_pass = 0;
my $not_filtered = 0;

sub reset_counters {
    $matches = 0;
    $match_first_pass = 0;
    $not_filtered = 0;
}

sub print_counters {
    printf("Got %d matches\n", $matches);
    printf("Got %d matches on first pass\n",
        $match_first_pass);
    printf("Got %d non-filtered\n", $not_filtered);
}

#Build string list, so that we can accurately benchark the searching

my $STRING_COUNT = $StringCount;
my $TERM_COUNT = 20;
my $PREFIX_MIN = 5;
my $PREFIX_MAX = 20;

my @strings = map substr(encode_base64(sha1_hex($_)),0, $PREFIX_MAX+1), (0..$STRING_COUNT);

my @terms;
while(@terms < $TERM_COUNT) {
    my $str = $strings[int(rand($STRING_COUNT))];
    my $prefix = substr($str, 0, 
        int(rand($PREFIX_MAX - $PREFIX_MIN)) + $PREFIX_MIN);
    push @terms, $prefix;
}

@terms = uniq(@terms);

#Build index;
my $MIN_INDEX = 100;
foreach my $term (@terms) {
    if(length($term) < $MIN_INDEX) {
        $MIN_INDEX = length($term);
    }

    my @chars = split(//, $term);
    while(@chars) {
        $index{join("", @chars)} = 1;
        pop @chars;
    }
    $fullmatch{$term} = 1;

}
@terms = sort { length $b <=> length $a || $a cmp $b } @terms;

my $begin_time = time();
my $duration;
print "Beginning search\n";
if($UsePP) {
    CHECK_TERM:
    foreach my $str (@strings) {
        my $j = 1;
        while($j <= $MIN_INDEX) {
            if(!exists $index{substr($str,0,$j)}){
                next CHECK_TERM;
            }
            $j++;
        }
        $not_filtered++;
        #The prefix matches
        foreach my $term (@terms) {
            if(substr($str,0,length($term)) eq $term) {
                $matches++;
                next CHECK_TERM;
            }
        }
    };

    my $now = time();
    $duration = $now-$begin_time;
    printf("my Trie: Duration: %0.2f\n", $duration);
    print_counters();
}

#Try large regex version..
reset_counters();
my $BIG_RE;

sub gen_big_re { 
    $BIG_RE = join '|',  map quotemeta, @terms;
    $BIG_RE = qr/^($BIG_RE)/;
}

sub gen_big_re2 {
    use re::engine::RE2;
    $BIG_RE = join '|',  map quotemeta, @terms;
    $BIG_RE = qr/^(?:$BIG_RE)/;
    die "Not an RE2 object" unless $BIG_RE->isa('re::engine::RE2');
}

log_infof("Have %d terms", scalar @terms);

if($UseRE) {
    gen_big_re();
    $begin_time = time();
    foreach my $str (@strings) {
        if($str =~ $BIG_RE) {
            #my ($match) = ($str =~ $BIG_RE);
            $matches++;
        }
    }
    $duration = time() - $begin_time;
    printf("BIG RE: Duration: %0.2f\n", $duration);
    print_counters();
}

reset_counters();

if($UseRE2) {
    use re::engine::RE2 -strict => 1;
    gen_big_re2();
    $begin_time = time();
    foreach my $str (@strings) {
        if($str =~ $BIG_RE) {
            #my ($match) = ($str =~ $BIG_RE);
            $matches++;
        }
    }
    $duration = time() - $begin_time;
    printf("BIG RE (RE2): Duration: %0.2f\n", $duration);
    print_counters();
}

reset_counters();


if($UseTMFA) {
    my $tmfa = Text::Match::FastAlternatives->new(@terms);
    $begin_time = time();
    foreach my $str (@strings) {
        if($tmfa->match_at($str, 0)) {
            $matches++;
        }
    }
    $duration = time() - $begin_time;
    printf("TMFA: Duration: %0.2f\n", $duration);
    print_counters();
}

reset_counters();
if($UseXS) {
    my $xs_search = prefix_search_build(\@terms);
    foreach (0..$Cycles) {
        $begin_time = time();
        foreach my $str (@strings) {
            if(my $result = prefix_search $xs_search, $str) {
                $matches++;
            }
        }
        $duration = time() - $begin_time;
        printf("C Implementation: %0.2f\n", $duration);
        print_counters();
        Text::Prefix::XS::print_optimized("");
    }
}
1;
