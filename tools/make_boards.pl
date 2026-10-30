#!/usr/bin/perl
# Builds boards/<slug>.json from the text maps in boards/maps/*.txt.
#
#   perl tools/make_boards.pl
#
# A map file has "key: value" lines (name, goal, start_cash, base_salary,
# relay_bonus, and optionally names: a comma-separated list of lot names),
# then "map:" and the board drawn one cell per space, cells separated by
# spaces. Spaces next to each other (left/right/up/down) are linked both ways,
# so you can walk either way and turn round at a dead end.
#
#   D depot          S H V C  suits: Spade, Heart, Diamond (V), Club
#   a-h a lot in block A-H    *  Star       M  Moon       P  building plot
#   ?  Wildcard      R  Dice  X  Arcade     K  Market
#   T  Toll          W  Workshop            +  plain path    .  nothing
#
# Every board must have one depot, the four suits, one Star, one Moon, three
# plots, two Dice and one Arcade; the script stops on the first problem.
use strict;
use warnings;
use FindBin;

my $root = "$FindBin::Bin/..";
my %TYPE = ('D' => 'depot', 'S' => 'relay', 'H' => 'relay', 'V' => 'relay', 'C' => 'relay',
	'*' => 'interest', 'M' => 'break', 'P' => 'plot', '?' => 'wildcard', 'R' => 'dice',
	'X' => 'arcade', 'K' => 'market', 'T' => 'toll', 'W' => 'workshop',
	'+' => 'junction');
my %SUIT = ('S' => ['Spade', '#4a78ff'], 'H' => ['Heart', '#ff3b4a'],
	'V' => ['Diamond', '#ffcc1f'], 'C' => ['Club', '#22d65a']);
my @BLOCK_COLOURS = ('#e0703a', '#e8b33f', '#5fae4f', '#3f9ad0', '#9a6ad0', '#e05a95',
	'#3fc0b0', '#c0c050');
my @NAME_POOL = split /\s*,\s*/, 'Cupcake Corner, Kite Shop, Lemon Stand, Toy Box, Pet Parlour,
	Ice Cream Hut, Bookworm, Flower Cart, Pizza Place, Comic Nook, Tea House, Bike Barn, Jam Jar,
	Bubble Bath, Candy Stop, Puzzle Den, Noodle Bar, Hat Rack, Sock Shop, Bakery, Soap Studio,
	Yo-Yo Hut, Fruit Stall, Music Box, Paint Pot, Cheese Board, Pancake Place, Balloon Booth,
	Snow Globe, Waffle Wagon, Plant Pot, Taco Truck, Button Shop, Honey Hive, Popcorn Stand,
	Craft Corner, Teddy Bear Co, Smoothie Spot, Bead Barn, Cookie Jar, Map Maker, Kettle Cafe,
	Feather Fan, Pickle Pantry, Rainbow Rugs, Spice Rack, Juice Joint, Pebble Gems, Sandwich Shack,
	Marble Hall, Candle Cove, Pretzel Post, Mitten Mart, Hammock Hut, Dumpling Den, Lantern Lane,
	Cocoa Cabin, Pottery Place, Gelato Bar, Origami Shop';

my @files = sort glob("$root/boards/maps/*.txt");
die "no maps in boards/maps\n" unless @files;
for my $file (@files) {
	my ($slug) = $file =~ m{([^/\\]+)\.txt$};
	my $board = build($file);
	my $out = "$root/boards/$slug.json";
	open my $fh, '>:raw', $out or die "$out: $!";
	print $fh to_json($board);
	close $fh;
	my %n;
	$n{$_->{type}}++ for @{ $board->{spaces} };
	printf "%-26s %3d spaces, %2d lots in %d blocks -> boards/%s.json\n", $board->{name},
		scalar @{ $board->{spaces} }, $n{lot} // 0, scalar keys %{ $board->{blocks} }, $slug;
}


sub build {
	my ($file) = @_;
	open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!";
	my (%meta, @rows, $in_map);
	while (my $line = <$fh>) {
		$line =~ s/\r?\n$//;
		next if $line =~ /^\s*#/;
		if ($in_map) {
			push @rows, [split ' ', $line] if $line =~ /\S/;
		} elsif ($line =~ /^map:\s*$/) {
			$in_map = 1;
		} elsif ($line =~ /^(\w+):\s*(.*)$/) {
			$meta{$1} = $2;
		}
	}
	my $where = $file =~ s{.*[/\\]}{}r;
	die "$where: no map\n" unless @rows;

	# Spaces in reading order; the depot is renumbered to come first.
	my (@cells, %at);
	for my $y (0 .. $#rows) {
		for my $x (0 .. $#{ $rows[$y] }) {
			my $c = $rows[$y][$x];
			next if $c eq '.';
			die "$where: unknown cell '$c' at $x,$y\n" unless $TYPE{$c} || $c =~ /^[a-h]$/;
			push @cells, {c => $c, x => $x, y => $y};
		}
	}
	@cells = sort { ($b->{c} eq 'D') <=> ($a->{c} eq 'D') } @cells;
	$at{"$cells[$_]{x},$cells[$_]{y}"} = $_ for 0 .. $#cells;

	my %count;
	$count{$_->{c}}++ for @cells;
	my %need = ('D' => 1, 'S' => 1, 'H' => 1, 'V' => 1, 'C' => 1, '*' => 1, 'M' => 1,
		'P' => 3, 'R' => 2, 'X' => 1);
	for my $c (sort keys %need) {
		my $have = $count{$c} // 0;
		die "$where: needs $need{$c} '$c', has $have\n" unless $have == $need{$c};
	}

	# Blocks in order of first appearance; prices rise block by block and
	# within a block.
	my (%block_index, @names);
	@names = $meta{names} ? split(/\s*,\s*/, $meta{names}) : @NAME_POOL;
	my $offset = ($meta{name_offset} // 0);
	my (%blocks, @spaces, %in_block, $lot_n);
	for my $i (0 .. $#cells) {
		my $cell = $cells[$i];
		my @next;
		for my $d ([1, 0], [-1, 0], [0, 1], [0, -1]) {
			my $k = ($cell->{x} + $d->[0]) . ',' . ($cell->{y} + $d->[1]);
			push @next, $at{$k} if exists $at{$k};
		}
		die "$where: space at $cell->{x},$cell->{y} is cut off\n" unless @next;
		@next = sort { $a <=> $b } @next;
		my %s = (id => $i, x => $cell->{x}, y => $cell->{y}, next => \@next);
		my $c = $cell->{c};
		if ($c =~ /^[a-h]$/) {
			my $id = uc $c;
			unless (exists $block_index{$id}) {
				$block_index{$id} = scalar keys %block_index;
				$blocks{$id} = {name => $id, color => $BLOCK_COLOURS[$block_index{$id}]};
			}
			my $k = $in_block{$id}++;
			%s = (%s, type => 'lot', block => $id,
				price => 100 + 50 * $block_index{$id} + 20 * $k,
				name => $names[($offset + $lot_n++) % @names]);
		} else {
			$s{type} = $TYPE{$c};
			if ($SUIT{$c}) {
				$s{name} = $s{mark} = $SUIT{$c}[0];
				$s{color} = $SUIT{$c}[1];
			}
		}
		push @spaces, \%s;
	}
	for my $id (keys %in_block) {
		die "$where: block $id has only one lot\n" if $in_block{$id} < 2;
	}
	# Everything must be reachable from the depot.
	my %seen = (0 => 1);
	my @queue = (0);
	while (@queue) {
		my $id = shift @queue;
		for my $n (@{ $spaces[$id]{next} }) {
			push @queue, $n unless $seen{$n}++;
		}
	}
	die "$where: not every space can be reached from the depot\n" if keys %seen != @spaces;

	return {
		name => $meta{name} // $where,
		goal => $meta{goal} // 8000,
		start_cash => $meta{start_cash} // 1500,
		base_salary => $meta{base_salary} // 200,
		relay_bonus => $meta{relay_bonus} // 120,
		blocks => \%blocks,
		spaces => \@spaces,
	};
}


sub q_str { my $s = shift; $s =~ s/(["\\])/\\$1/g; return "\"$s\""; }

sub to_json {
	my ($b) = @_;
	my @lines = ("{");
	push @lines, "  \"name\": " . q_str($b->{name}) . ",";
	push @lines, "  \"$_\": $b->{$_}," for qw(goal start_cash base_salary relay_bonus);
	push @lines, "  \"blocks\": {";
	my @ids = sort keys %{ $b->{blocks} };
	for my $i (0 .. $#ids) {
		my $blk = $b->{blocks}{$ids[$i]};
		push @lines, sprintf('    "%s": { "name": %s, "color": "%s" }%s', $ids[$i], q_str($blk->{name}),
			$blk->{color}, $i < $#ids ? ',' : '');
	}
	push @lines, "  },";
	push @lines, "  \"spaces\": [";
	my @sp = @{ $b->{spaces} };
	for my $i (0 .. $#sp) {
		my $s = $sp[$i];
		my @f = (sprintf('"id": %d', $s->{id}), sprintf('"type": "%s"', $s->{type}),
			sprintf('"x": %d', $s->{x}), sprintf('"y": %d', $s->{y}),
			'"next": [' . join(', ', @{ $s->{next} }) . ']');
		push @f, sprintf('"block": "%s"', $s->{block}) if $s->{block};
		push @f, sprintf('"price": %d', $s->{price}) if $s->{price};
		push @f, '"name": ' . q_str($s->{name}) if $s->{name};
		push @f, sprintf('"mark": "%s"', $s->{mark}) if $s->{mark};
		push @f, sprintf('"color": "%s"', $s->{color}) if $s->{color};
		push @lines, '    { ' . join(', ', @f) . ' }' . ($i < $#sp ? ',' : '');
	}
	push @lines, "  ]", "}";
	return join("\n", @lines) . "\n";
}
