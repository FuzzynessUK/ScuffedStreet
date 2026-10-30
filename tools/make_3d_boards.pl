#!/usr/bin/perl
# Builds the 3D boards whose spaces don't lie on one flat grid:
#
#   boards/island_hop.json   a beach island with the Bank, and four giant
#                            turtles round it carrying spaces on their shells,
#                            each at its own height, joined only by warp pads;
#                            a suit on each turtle
#   boards/bottle.json       a giant glass bottle in space: a ring of spaces
#                            round its base (the Bank), a path spiralling twice
#                            up the outside of the glass to a ring round its
#                            neck, and a warp pad from there back down
#
# Each space has map coordinates (x, y: the minimap) and a world position "at"
# in tiles [across, up, towards the camera]; "face" says which way its top
# points ("up", or a direction [x, y, z] for spaces on the bottle's side).
# Links run both ways. "props" are what the spaces stand on (BoardView).
#
#   perl tools/make_3d_boards.pl
use strict;
use warnings;
use FindBin;

my (@spaces, %price);
my %first;
my %suit = (Spade => '#4a78ff', Heart => '#ff3b4a', Diamond => '#ffcc1f', Club => '#22d65a');

sub reset_board { @spaces = (); %price = (); %first = @_; }
sub add {
	my ($cell, $mx, $my, $at, $face) = @_;
	my ($type, %extra) = @$cell;
	push @spaces, { type => $type, x => $mx, y => $my, at => $at, face => $face // "up", %extra, next => [] };
	return $#spaces;
}
sub join_both { my ($a, $b) = @_; push @{ $spaces[$a]{next} }, $b; push @{ $spaces[$b]{next} }, $a; }
sub warp_pair { my ($a, $b) = @_; join_both($a, $b); $spaces[$a]{pair} = $b; $spaces[$b]{pair} = $a; }
sub relay { my ($m) = @_; return ["relay", mark => $m, color => $suit{$m}]; }
sub lot { my ($b) = @_; $price{$b} //= $first{$b}; my $p = $price{$b}; $price{$b} += 20; return ["lot", block => $b, price => $p]; }
sub cell { return [@_]; }

# Positions round a rectangle's edge, from its front-left corner: up the
# left side, along the back, down the right, back along the front.
sub ring {
	my ($w, $d) = @_;
	my @p;
	push @p, [0, $_] for reverse 0 .. $d - 1;
	push @p, [$_, 0] for 1 .. $w - 1;
	push @p, [$w - 1, $_] for 1 .. $d - 1;
	push @p, [$_, $d - 1] for reverse 1 .. $w - 2;
	return @p;
}

# A loop of `cells` round a w x d ring whose corner is at map (mx, my) and
# world (wx, h, wz). Returns the space ids in order.
sub island {
	my ($cells, $w, $d, $mx, $my, $wx, $h, $wz) = @_;
	my @pos = ring($w, $d);
	die "island: " . scalar(@$cells) . " cells for " . scalar(@pos) . " spots\n" unless @$cells == @pos;
	my @ids = map { add($cells->[$_], $pos[$_][0] + $mx, $pos[$_][1] + $my,
		[$pos[$_][0] + $wx, $h, $pos[$_][1] + $wz]) } 0 .. $#pos;
	join_both($ids[$_], $ids[($_ + 1) % @ids]) for 0 .. $#ids;
	return @ids;
}

my @names = ("Cloud Cafe", "Breeze Bakery", "Kite Shop", "Gust Garage", "Vapour Vinyl", "Nimbus Noodles",
	"Drizzle Diner", "Thunder Toys", "Hail Hats", "Mist Market", "Sleet Sweets", "Zephyr Zines",
	"Squall Shoes", "Stratus Studio", "Cirrus Cinema", "Comet Comics", "Gale Gym", "Rain Records",
	"Sunbeam Salon", "Halo Hotel", "Aurora Antiques", "Skyline Spa", "Updraft Union", "Jetstream Juice",
	"Horizon Hall", "Windmill Works", "Puffin Post", "Rainbow Rugs", "Lagoon Lamps", "Coral Corner",
	"Tidepool Teas", "Driftwood Deli", "Seashell Shoes", "Anchor Arcade", "Harbour Hats", "Pebble Pizza");
my @colours = ('#e0703a', '#e8b33f', '#5fae4f', '#3f9ad0', '#9a6ad0', '#e05a95', '#3fc0b0', '#c87a3a',
	'#7a9a3a', '#5a6ad0');

sub j {
	my ($v) = @_;
	return "null" unless defined $v;
	return "[" . join(", ", map { j($_) } @$v) . "]" if ref $v eq 'ARRAY';
	return "{ " . join(", ", map { "\"$_\": " . j($v->{$_}) } sort keys %$v) . " }" if ref $v eq 'HASH';
	return $v =~ /^-?\d+(\.\d+)?$/ ? $v : "\"$v\"";
}

sub write_board {
	my ($file, $name, $theme, $props, $camera) = @_;
	my $n = 0;
	for (@spaces) { $_->{name} = $names[$n++ % @names] if $_->{type} eq "lot"; }
	my %blocks;
	my $c = 0;
	$blocks{$_} = { name => $_, color => $colours[$c++ % @colours] } for sort keys %first;
	my %count;
	$count{$_->{block}}++ for grep { $_->{type} eq "lot" } @spaces;
	for (sort keys %count) { die "$name: block $_ has $count{$_} lots\n" if $count{$_} > 5 || $count{$_} < 2; }
	my @out = ("{", "  \"name\": \"$name\",", "  \"theme\": \"$theme\",", "  \"goal\": 10000,",
		"  \"start_cash\": 1500,", "  \"base_salary\": 200,", "  \"relay_bonus\": 120,",
		($camera ? ("  \"camera\": " . j($camera) . ",") : ()),
		"  \"blocks\": " . j(\%blocks) . ",", "  \"props\": " . j($props) . ",", "  \"spaces\": [");
	for my $i (0 .. $#spaces) {
		my %sp = %{ $spaces[$i] };
		$sp{id} = $i;
		push @out, "    " . j(\%sp) . ($i < $#spaces ? "," : "");
	}
	push @out, "  ]", "}";
	open my $f, '>', "$FindBin::Bin/../boards/$file" or die;
	print $f join("\n", @out), "\n";
	close $f;
	my %types;
	$types{$_->{type}}++ for @spaces;
	printf "%-20s %d spaces (%s) -> boards/%s\n", $name, scalar @spaces,
		join(", ", map { "$types{$_} $_" } sort keys %types), $file;
}

# --- Turtle Islands -------------------------------------------------------
# Round everything: a circle of 16 spaces on a round beach island in the
# middle, and four giant turtles round it, each carrying a circle of 8 spaces
# on its shell, a warp pad facing the beach. Angles run from the front (+z)
# towards the right (+x).
reset_board(A => 120, B => 180, C => 240, D => 160, E => 300, F => 260, G => 220);
my ($CX, $CZ) = (2, 2);  # the middle of it all, in tiles
my $GAP = 1.2;  # tiles of circle between neighbouring spaces
# A circle of `cells` round (x, h, z), the first at angle `a0`; map positions
# from a ring(mw, md) at map (mx, my) so the minimap shows a loop.
sub circle {
	my ($cells, $x, $h, $z, $a0, $mx, $my, $mw, $md) = @_;
	my $n = @$cells;
	my $r = $n * $GAP / (2 * 3.14159265);
	my @map = ring($mw, $md);
	my @ids;
	for my $i (0 .. $n - 1) {
		my $a = $a0 + 2 * 3.14159265 * $i / $n;
		push @ids, add($cells->[$i], $map[$i][0] + $mx, $map[$i][1] + $my,
			[sprintf("%.3f", $x + sin($a) * $r), $h, sprintf("%.3f", $z + cos($a) * $r)]);
	}
	join_both($ids[$_], $ids[($_ + 1) % @ids]) for 0 .. $#ids;
	return @ids;
}
my $PI = 3.14159265;
# The middle: warp pads at the front, right, back and left (0, 4, 8, 12).
my @mid = circle([cell("warp"), lot("C"), cell("dice"), lot("C"), cell("warp"), lot("B"), lot("B"), cell("wildcard"),
	cell("warp"), lot("B"), lot("A"), lot("A"), cell("warp"), lot("A"), cell("depot"), lot("C")],
	$CX, 0, $CZ, 0, 6, 6, 5, 5);
# The turtles, 8.4 tiles out, each with its warp pad (first) facing the middle.
my $OUT = 8.4;
my %turtle = (
	front => [0, -0.5, [cell("warp"), lot("G"), cell("plot"), lot("G"), relay("Club"), lot("G"), cell("interest"), lot("G")], 7, 13],
	right => [$PI / 2, 0.8, [cell("warp"), lot("F"), relay("Diamond"), lot("F"), cell("break"), lot("F"), cell("wildcard"), lot("F")], 14, 7],
	back => [$PI, 1.3, [cell("warp"), lot("E"), relay("Heart"), lot("E"), lot("E"), cell("arcade"), lot("E"), cell("plot")], 7, 0],
	left => [3 * $PI / 2, 0.4, [cell("warp"), lot("D"), cell("plot"), relay("Spade"), lot("D"), lot("D"), cell("dice"), lot("D")], 0, 7],
);
my @props = ({ kind => "isle", at => [$CX, 0, $CZ], size => [8.4, 8.4] });
my $k = 0;
for my $side (qw(front right back left)) {
	my ($a, $h, $cells, $mx, $my) = @{ $turtle{$side} };
	my ($tx, $tz) = ($CX + sin($a) * $OUT, $CZ + cos($a) * $OUT);
	my @ring = circle($cells, $tx, $h, $tz, $a + $PI, $mx, $my, 3, 3);  # first space faces the middle
	warp_pair($mid[$k * 4], $ring[0]);
	push @props, { kind => "turtle", at => [sprintf("%.3f", $tx), $h, sprintf("%.3f", $tz)], radius => 3.1,
		heading => [sprintf("%.3f", sin($a)), 0, sprintf("%.3f", cos($a))] };
	$k++;
}
write_board("island_hop.json", "Turtle Islands", "lagoon", \@props);

# --- Lost Bottle ---------------------------------------------------------
# The whole board wraps round the glass: two rings of 16 spaces round the
# bottle (the Bank on the lower one, at the front), joined by a ladder of
# three spaces straight up the front and another up the back.
reset_board(A => 120, B => 160, C => 200, D => 240, E => 280, F => 320, G => 360, H => 400);
my $R = 3.0;  # the bottle's radius, in tiles
my ($LOW, $HIGH) = (1.2, 5.6);  # the rings' heights
# A space on the glass at angle `a` round (0 = facing the camera), height `h`.
sub on_glass {
	my ($cell, $a, $h, $mx, $my) = @_;
	my ($sx, $sz) = (sin($a), cos($a));
	return add($cell, $mx, $my, [sprintf("%.3f", $sx * $R), $h, sprintf("%.3f", $sz * $R)],
		[sprintf("%.3f", $sx), 0, sprintf("%.3f", $sz)]);
}
sub glass_ring {
	my ($cells, $h, $my) = @_;
	my @ids = map { on_glass($cells->[$_], 2 * 3.14159265 * $_ / @$cells, $h, $_, $my) } 0 .. $#$cells;
	join_both($ids[$_], $ids[($_ + 1) % @ids]) for 0 .. $#ids;
	return @ids;
}
my @low = glass_ring([cell("depot"), lot("A"), lot("A"), lot("A"), relay("Spade"), lot("B"), lot("B"), cell("wildcard"),
	cell("dice"), lot("B"), lot("C"), lot("C"), relay("Heart"), lot("C"), cell("plot"), cell("arcade")], $LOW, 4);
my @high = glass_ring([relay("Diamond"), lot("D"), lot("D"), lot("D"), cell("wildcard"), lot("E"), lot("E"),
	lot("E"), cell("interest"), cell("wildcard"), lot("F"), lot("F"), relay("Club"), lot("F"), cell("plot"), cell("break")],
	$HIGH, 0);
# The ladders: front (angle 0, joining the rings' first spaces) and back.
for my $ladder ([0, 0, [lot("G"), cell("plot"), lot("G")]], [3.14159265, 8, [lot("H"), cell("dice"), lot("H")]]) {
	my ($a, $k, $cells) = @$ladder;
	my @rungs = map { on_glass($cells->[$_], $a, sprintf("%.2f", $LOW + ($HIGH - $LOW) * ($_ + 1) / 4), $k, 3 - $_) } 0 .. 2;
	join_both($low[$k], $rungs[0]);
	join_both($rungs[$_], $rungs[$_ + 1]) for 0 .. 1;
	join_both($rungs[2], $high[$k]);
}
write_board("bottle.json", "Lost Bottle", "space", [
	{ kind => "bottle", at => [0, 0, 0], radius => $R, height => 7.0 },
], [0, 0.42, 1]);  # seen from lower, more side on
