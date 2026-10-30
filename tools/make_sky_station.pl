#!/usr/bin/perl
# Builds boards/sky_station.json: a 3D board in the sky. Its spaces are laid
# out by hand here, because they don't lie on one flat grid:
#
#   main deck    a 7x5 loop at height 0, the Bank at its front-left corner
#   tower        seven spaces climbing the front face of a tower from the
#                deck's back edge (they stand on the wall: face "front")
#   top island   a 5x3 loop at height 8, behind and above the tower
#   side island  a 4x4 loop at height 3, floating off to the left
#   warps        a pad on the deck and one on the top island each link to a
#                pad on the side island; stepping onto one jumps across
#
# Every space has map coordinates (x, y: where it shows on the minimap) and a
# world position "at" (in tiles: across, up, towards the camera). Links run
# both ways. "props" are the floating islands and the tower under the spaces.
#
#   perl tools/make_sky_station.pl
use strict;
use warnings;
use FindBin;

my @spaces;  # [type, map x, map y, world x, world h, world z, face, extra]
my %at;      # "x,y" map position -> space id

sub add {
	my ($type, $mx, $my, $wx, $wh, $wz, $face, %extra) = @_;
	push @spaces, { type => $type, x => $mx, y => $my, at => [$wx, $wh, $wz],
		face => $face // "up", %extra, next => [] };
	$at{"$mx,$my"} = $#spaces;
	return $#spaces;
}

sub connect_both {
	my ($a, $b) = @_;
	push @{ $spaces[$a]{next} }, $b;
	push @{ $spaces[$b]{next} }, $a;
}

my %suit = (Spade => '#4a78ff', Heart => '#ff3b4a', Diamond => '#ffcc1f', Club => '#22d65a');
sub relay { my ($mark) = @_; return ("relay", mark => $mark, color => $suit{$mark}); }

# A loop of `cells` ([type, extra...] in order round it), the map and world
# positions given by `pos` for each step.
sub loop {
	my ($cells, $pos) = @_;
	my @ids;
	for my $i (0 .. $#$cells) {
		my ($type, %extra) = @{ $cells->[$i] };
		push @ids, add($type, @{ $pos->[$i] }, %extra);
	}
	connect_both($ids[$_], $ids[($_ + 1) % @ids]) for 0 .. $#ids;
	return @ids;
}

# Positions round a rectangle's edge, clockwise from its front-left corner:
# up the left side, along the back, down the right, back along the front.
sub ring {
	my ($w, $d) = @_;
	my @p;
	push @p, [0, $_] for reverse 0 .. $d - 1;
	push @p, [$_, 0] for 1 .. $w - 1;
	push @p, [$w - 1, $_] for 1 .. $d - 1;
	push @p, [$_, $d - 1] for reverse 1 .. $w - 2;
	return @p;
}

my %price;  # block -> next price
my %first = (A => 120, B => 200, C => 260, E => 300, F => 360, G => 420, H => 220);
sub lot { my ($b) = @_; $price{$b} //= $first{$b}; my $p = $price{$b}; $price{$b} += 20;
	return ("lot", block => $b, price => $p); }

# The main deck: map x 4..10, y 10..14; world x 0..6, z 0..4.
my @main = (["depot"], [lot("A")], ["warp"], [lot("A")], [relay("Spade")],
	[lot("B")], [lot("B")], ["junction"], [lot("B")], ["wildcard"],
	[relay("Heart")], [lot("C")], ["dice"], [lot("C")], ["plot"],
	[lot("C")], ["interest"], [lot("A")], [lot("A")], ["arcade"]);
my @m = loop(\@main, [map { [$_->[0] + 4, $_->[1] + 10, $_->[0], 0, $_->[1], "up"] } ring(7, 5)]);

# The tower: up the front face of a tower behind the deck's middle.
my @tower_cells = ([lot("E")], [lot("E")], ["wildcard"], [lot("E")], ["break"], ["dice"], [lot("E")]);
my @t;
for my $i (0 .. $#tower_cells) {
	my ($type, %extra) = @{ $tower_cells[$i] };
	push @t, add($type, 7, 9 - $i, 3, 1.15 + $i, -0.6, "front", %extra);
}
connect_both($m[7], $t[0]);
connect_both($t[$_], $t[$_ + 1]) for 0 .. $#t - 1;

# The top island: a 5x3 loop at height 8, entered at its front middle.
my @top_ring = ring(5, 3);
# The Diamond at the entry (the front row's middle, (2,2)), then these on round.
my @top_cells = ([lot("F")], [lot("F")], ["warp"], [lot("F")], ["plot"],
	[lot("G")], [lot("G")], ["wildcard"], [lot("G")], [lot("F")], [lot("G")]);
my ($entry) = grep { $top_ring[$_][0] == 2 && $top_ring[$_][1] == 2 } 0 .. $#top_ring;
my @rot = (@top_ring[$entry .. $#top_ring], @top_ring[0 .. $entry - 1]);
my @tp;
for my $i (0 .. $#rot) {
	my ($cx, $cz) = @{ $rot[$i] };
	my ($type, %extra) = $i == 0 ? relay("Diamond") : @{ $top_cells[$i - 1] };
	push @tp, add($type, $cx + 5, $cz, $cx + 1, 8, $cz - 4, "up", %extra);
}
connect_both($tp[$_], $tp[($_ + 1) % @tp]) for 0 .. $#tp;
connect_both($t[-1], $tp[0]);

# The side island: a 4x4 loop at height 3, off to the left.
my @side_cells = ([relay("Club")], [lot("H")], [lot("H")], ["plot"],
	["warp"], ["market"], ["wildcard"], ["wildcard"], [lot("H")], [lot("H")], ["warp"], [lot("H")]);
my @side_ring = ring(4, 4);
my @s;
for my $i (0 .. $#side_ring) {
	my ($cx, $cz) = @{ $side_ring[$i] };
	my ($type, %extra) = @{ $side_cells[$i] };
	push @s, add($type, $cx, $cz + 10, $cx - 7, 3, $cz, "up", %extra);
}
connect_both($s[$_], $s[($_ + 1) % @s]) for 0 .. $#s;

# Warps: the deck's pad to the side island's front-right pad, the top
# island's pad to the side island's back-left pad.
my @warps = grep { $spaces[$_]{type} eq "warp" } 0 .. $#spaces;
my ($deck_warp) = grep { $_ == $m[2] } @warps;
my ($top_warp) = grep { my $w = $_; grep { $_ == $w } @tp } @warps;
my @side_warps = grep { my $w = $_; grep { $_ == $w } @s } @warps;
die "warps: @warps\n" unless defined $deck_warp && defined $top_warp && @side_warps == 2;
connect_both($deck_warp, $side_warps[1]);
connect_both($top_warp, $side_warps[0]);
$spaces[$deck_warp]{pair} = $side_warps[1];
$spaces[$side_warps[1]]{pair} = $deck_warp;
$spaces[$top_warp]{pair} = $side_warps[0];
$spaces[$side_warps[0]]{pair} = $top_warp;

# Names for the lots.
my @names = ("Cloud Cafe", "Breeze Bakery", "Kite Shop", "Gust Garage", "Vapour Vinyl",
	"Nimbus Noodles", "Drizzle Diner", "Thunder Toys", "Hail Hats", "Mist Market", "Sleet Sweets",
	"Zephyr Zines", "Squall Shoes", "Stratus Studio", "Cirrus Cinema", "Comet Comics", "Gale Gym",
	"Rain Records", "Sunbeam Salon", "Halo Hotel", "Aurora Antiques", "Skyline Spa", "Updraft Union",
	"Jetstream Juice", "Horizon Hall", "Windmill Works", "Puffin Post", "Rainbow Rugs");
my $n = 0;
for my $sp (@spaces) {
	$sp->{name} = $names[$n++ % @names] if $sp->{type} eq "lot";
}

my @colours = ('#e0703a', '#e8b33f', '#5fae4f', '#3f9ad0', '#9a6ad0', '#e05a95', '#3fc0b0');
my %blocks;
my $c = 0;
$blocks{$_} = { name => $_, color => $colours[$c++] } for sort keys %first;

my $props = [
	{ kind => "island", at => [3, -0.2, 2], size => [8.4, 6.4], depth => 3.2 },
	{ kind => "island", at => [3, 7.8, -3], size => [6.4, 4.4], depth => 2.6 },
	{ kind => "island", at => [-5.5, 2.8, 1.5], size => [5.4, 5.4], depth => 2.4 },
	{ kind => "tower", at => [3, 0, -1.25], size => [1.6, 8.0, 1.2] },
];

# JSON out, a space per line.
sub j {
	my ($v) = @_;
	return "null" unless defined $v;
	if (ref $v eq 'ARRAY') { return "[" . join(", ", map { j($_) } @$v) . "]"; }
	if (ref $v eq 'HASH') { return "{ " . join(", ", map { "\"$_\": " . j($v->{$_}) } sort keys %$v) . " }"; }
	return $v =~ /^-?\d+(\.\d+)?$/ ? $v : "\"$v\"";
}
my @out = ("{", "  \"name\": \"Sky Station\",", "  \"theme\": \"space\",", "  \"goal\": 10000,",
	"  \"start_cash\": 1500,", "  \"base_salary\": 200,", "  \"relay_bonus\": 120,",
	"  \"blocks\": " . j(\%blocks) . ",", "  \"props\": " . j($props) . ",", "  \"spaces\": [");
for my $i (0 .. $#spaces) {
	my %sp = %{ $spaces[$i] };
	$sp{id} = $i;
	push @out, "    " . j(\%sp) . ($i < $#spaces ? "," : "");
}
push @out, "  ]", "}";
open my $f, '>', "$FindBin::Bin/../boards/sky_station.json" or die;
print $f join("\n", @out), "\n";
close $f;
my %count;
$count{$_->{type}}++ for @spaces;
printf "Sky Station: %d spaces (%s) -> boards/sky_station.json\n", scalar @spaces,
	join(", ", map { "$count{$_} $_" } sort keys %count);
