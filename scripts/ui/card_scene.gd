class_name CardScene
extends RefCounted
## The 3D picture on a Wildcard: a little diorama on a round patch of grass,
## its subject in the middle, built from the same pieces as the board (houses,
## the bank, the arcade cabinet, the walking figures) plus coins, cars, dice
## and so on. CardArt shows it in its own viewport, turning gently, with the
## caption above. build() returns the scene, standing on y = 0 and about 1.6
## across; caption() the few characters printed over it on the card.

const B := preload("res://scripts/ui/board_view.gd")  # its model builders
const GOLD := Color("#f2bf2a")
const GOLD_DARK := Color("#b8860b")
const RED := Color("#e8463a")
const BLUE := Color("#3a7fe0")
const GREEN := Color("#2fae5a")
const INK := Color("#3a3446")
## The cards with a scene of their own; the rest borrow one or use a template.
const BESPOKE := ["Scrap Drive", "Parking Ticket", "Rush Hour", "Inspection", "Grand Opening",
	"Power Cut", "Lucky Find", "Bond Bump", "Bond Slump", "Shortcut", "Tax Refund", "Swap Meet",
	"Charity", "Back to Base", "Free Renovation", "Lucky Dip", "Heavy Traffic", "Double Rent",
	"Market Tip", "Scrap Tax", "Any Suit", "Arcade Ticket"]
const DARK_CARDS := ["Power Cut"]  # lit like night


static func build(card: String) -> Node3D:
	if card not in BESPOKE:  # a newer card: a shared or template scene
		return _template(card)
	var root := Node3D.new()
	root.add_child(_base(card in DARK_CARDS))
	var rng := RandomNumberGenerator.new()
	rng.seed = card.hash()
	match card:
		"Scrap Drive":  # everyone tosses coins onto your pile
			_add(root, _pile(9, 0.17), Vector3(0, 0, 0.2))
			for at in [Vector3(-0.62, 0, -0.2), Vector3(0, 0, -0.55), Vector3(0.62, 0, -0.2)]:
				var who := _person(Color("#8a9ab0"), 1.6)
				_add(root, who, at)
				who.rotation.y = atan2(-at.x, -at.z)
				_add(root, _coin(0.09), at * 0.5 + Vector3(0, 0.75, 0.1))
		"Parking Ticket":  # a ticket stuck on the windscreen
			var car := _car(BLUE)
			car.scale = Vector3.ONE * 1.5
			car.rotation.y = -0.5
			_add(root, car, Vector3(0, 0, 0))
			var ticket := _plate(Vector2(0.3, 0.16), Color("#ffe04a"), "FINE", 0.4)
			_add(root, ticket, Vector3(0.05, 0.62, 0.28))
			ticket.rotation.x = -0.4
		"Rush Hour":  # two dice flying, speed lines behind them
			var d1 := _die(0.42, 5)
			d1.rotation = Vector3(0.4, 0.6, 0.25)
			_add(root, d1, Vector3(-0.25, 0.6, 0))
			var d2 := _die(0.36, 3)
			d2.rotation = Vector3(-0.3, -0.7, 0.2)
			_add(root, d2, Vector3(0.38, 0.42, 0.15))
			for i in 4:
				_add(root, B._box(Vector3(0.45, 0.025, 0.025), Color.WHITE),
						Vector3(-0.85, 0.35 + i * 0.12, -0.05 + i * 0.04))
		"Inspection":  # a magnifying glass held up to your building
			_add(root, _house(0.75, 0.62, Color("#f4f1ea"), Color("#4a6ac0")), Vector3(-0.15, 0, -0.15))
			var glass := Node3D.new()
			_add(root, glass, Vector3(0.38, 0.55, 0.35))
			glass.rotation.z = -0.5
			var rim := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.17
			ring.outer_radius = 0.22
			rim.mesh = ring
			rim.material_override = B._material(INK)
			rim.rotation.x = PI / 2
			glass.add_child(rim)
			var lens := B._cyl(0.18, 0.18, 0.01, Color.WHITE)
			var lens_mat := B._material(Color(0.75, 0.9, 1.0, 0.45))
			lens_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lens.material_override = lens_mat
			lens.rotation.x = PI / 2
			glass.add_child(lens)
			var handle := B._box(Vector3(0.06, 0.36, 0.06), Color("#6b4a2e"))
			handle.position.y = -0.38
			glass.add_child(handle)
		"Grand Opening":  # a ribbon across the shop door, confetti in the air
			_add(root, _house(0.95, 0.55, Color("#fff8ee"), RED), Vector3(0, 0, -0.1))
			_add(root, B._box(Vector3(1.4, 0.06, 0.02), RED), Vector3(0, 0.22, 0.34))
			for side in [-1, 1]:  # the bow
				var loop := _ball(0.07, RED.darkened(0.1))
				loop.scale = Vector3(1.3, 0.9, 0.5)
				_add(root, loop, Vector3(side * 0.08, 0.22, 0.36))
			_confetti(root, rng, 26, Vector3(1.4, 0.7, 0.6), 0.75)
		"Power Cut":  # the shop goes dark; the bulb is out
			var house := _house(0.85, 0.7, Color("#6a6a80"), Color("#4a4a60"))
			_unlight(house)
			_add(root, house, Vector3(-0.2, 0, -0.1))
			var bulb := _ball(0.16, Color("#d8d8e0"))
			_add(root, bulb, Vector3(0.5, 0.85, 0.2))
			_add(root, B._cyl(0.07, 0.07, 0.1, Color("#9a9aa6")), Vector3(0.5, 0.67, 0.2))
			for angle in [PI / 4, -PI / 4]:
				var bar := B._box(Vector3(0.5, 0.06, 0.04), RED)
				bar.material_override = B._material(RED, 0.5)
				bar.rotation.z = angle
				_add(root, bar, Vector3(0.5, 0.8, 0.4))
		"Lucky Find":  # a four-leaf clover and coins in the grass
			var clover := Node3D.new()
			_add(root, clover, Vector3(-0.15, 0, 0))
			var stem := B._cyl(0.025, 0.03, 0.6, Color("#2f8a3a"))
			stem.position.y = 0.3
			clover.add_child(stem)
			var head := Node3D.new()
			head.position = Vector3(0, 0.65, 0)
			head.rotation.x = 1.2  # faces the camera
			clover.add_child(head)
			for k in 4:
				var dir := Vector3.FORWARD.rotated(Vector3.UP, k * PI / 2 + PI / 4)
				for side in [-1, 1]:
					var leaf := _ball(0.11, Color("#3fb34a"))
					leaf.scale = Vector3(1, 0.3, 1)
					leaf.position = dir * 0.15 + dir.cross(Vector3.UP) * 0.07 * side
					head.add_child(leaf)
			for at in [Vector3(0.45, 0.12, 0.2), Vector3(0.65, 0.1, -0.1), Vector3(0.3, 0.1, 0.45)]:
				_add(root, _coin(0.1), at)
			_sparkles(root, rng, 6, Vector3(1.2, 0.8, 0.4), 0.6)
		"Bond Bump", "Bond Slump":  # a whiteboard on an easel, the chart climbing or diving
			_add(root, _whiteboard(card == "Bond Bump"), Vector3(0, 0, -0.05))
		"Shortcut":  # a straight arrow cutting across a winding road to a suit
			for i in 24:
				var t := i / 23.0
				var piece := B._box(Vector3(0.14, 0.03, 0.16), Color("#8a8a96"))
				var x := -0.8 + t * 1.6
				piece.position = Vector3(x, 0.015, sin(t * TAU * 1.5) * 0.35)
				var next := sin((t + 0.05) * TAU * 1.5) * 0.35
				piece.rotation.y = -atan2(next - piece.position.z, 0.07)
				root.add_child(piece)
			_arrow(root, Vector3(-0.75, 0.25, 0.4), Vector3(0.45, 0.5, -0.3), RED)
			var suit := B._suit("Spade", BLUE)
			suit.scale = Vector3.ONE * 1.6
			_add(root, suit, Vector3(0.65, 0.7, -0.4))
		"Tax Refund":  # coins popping out of an envelope
			var envelope := B._box(Vector3(0.8, 0.5, 0.05), Color("#f4ead2"))
			_add(root, envelope, Vector3(0, 0.3, 0))
			var flap := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.8, 0.26, 0.02)
			flap.mesh = prism
			flap.material_override = B._material(Color("#e6d6b2"))
			flap.rotation.z = PI
			_add(root, flap, Vector3(0, 0.42, 0.035))
			var word := _word("REFUND", 70, GREEN)
			_add(root, word, Vector3(0, 0.18, 0.03))
			for c in [Vector3(-0.25, 0.75, 0), Vector3(0.02, 0.88, 0.02), Vector3(0.28, 0.72, 0)]:
				_add(root, _coin(0.11), c)
			_sparkles(root, rng, 5, Vector3(1, 0.5, 0.2), 0.9)
		"Swap Meet":  # two shacks and the arrows trading them
			_add(root, _house(0.5, 0.36, Color("#f4ead8"), RED), Vector3(-0.5, 0, 0))
			_add(root, _house(0.5, 0.36, Color("#f4ead8"), BLUE), Vector3(0.5, 0, 0))
			_arc_arrow(root, Vector3(-0.4, 0.75, 0.1), Vector3(0.4, 0.75, 0.1), 0.25, INK)
			_arc_arrow(root, Vector3(0.4, 0.6, 0.25), Vector3(-0.4, 0.6, 0.25), -0.2, INK)
		"Charity":  # the richest hands a coin down to the poorest
			var rich := _person(GOLD_DARK, 2.2)
			rich.rotation.y = 0.9
			_add(root, rich, Vector3(-0.45, 0, 0))
			var poor := _person(Color("#8a8a9a"), 1.4)
			poor.rotation.y = -0.9
			_add(root, poor, Vector3(0.45, 0, 0.1))
			_add(root, _coin(0.11), Vector3(0, 0.55, 0.1))
			var heart := _word("♥", 160, Color("#e0405a"), true)
			_add(root, heart, Vector3(0, 1.05, 0))
		"Back to Base":  # an arrow curving home to the Bank
			var bank := B._bank_building()
			bank.scale = Vector3.ONE * 1.05
			_add(root, bank, Vector3(-0.15, 0, -0.1))
			_arc_arrow(root, Vector3(0.75, 0.2, 0.45), Vector3(0.0, 0.3, 0.35), 0.35, RED)
		"Free Renovation":  # a hammer and spanner over the building
			_add(root, _house(0.75, 0.6, Color("#fff8ee"), Color("#4a8ac0")), Vector3(-0.2, 0, -0.15))
			var hammer := Node3D.new()
			_add(root, hammer, Vector3(0.45, 0.55, 0.3))
			hammer.rotation.z = 0.6
			hammer.add_child(B._box(Vector3(0.06, 0.5, 0.06), Color("#a0703c")))
			var head := B._box(Vector3(0.24, 0.1, 0.1), Color("#7a808a"))
			head.position.y = 0.25
			hammer.add_child(head)
			var spanner := Node3D.new()
			_add(root, spanner, Vector3(0.45, 0.55, 0.34))
			spanner.rotation.z = -0.6
			spanner.add_child(B._box(Vector3(0.06, 0.5, 0.04), Color("#c0c6d0")))
			for x in [-0.05, 0.05]:
				var jaw := B._box(Vector3(0.04, 0.1, 0.04), Color("#c0c6d0"))
				jaw.position = Vector3(x, 0.28, 0)
				spanner.add_child(jaw)
			_sparkles(root, rng, 6, Vector3(1.3, 0.6, 0.3), 0.7)
		"Lucky Dip":  # a treasure chest, lid open, spilling coins
			var chest := Node3D.new()
			_add(root, chest, Vector3(-0.1, 0, 0))
			chest.rotation.y = 0.25
			var wood := Color("#9a5a2a")
			_add(chest, B._box(Vector3(0.7, 0.36, 0.44), wood), Vector3(0, 0.18, 0))
			for x in [-0.25, 0.25]:  # its gold bands
				_add(chest, B._box(Vector3(0.06, 0.37, 0.45), GOLD_DARK), Vector3(x, 0.18, 0))
			_add(chest, _pile(5, 0.22), Vector3(0, 0.36, 0))
			_add(chest, _coin(0.1), Vector3(-0.12, 0.58, 0.05))
			var lid := Node3D.new()  # hinged at the back, swung open
			_add(chest, lid, Vector3(0, 0.36, -0.22))
			lid.rotation.x = -1.1
			_add(lid, B._box(Vector3(0.7, 0.08, 0.44), wood.lightened(0.1)), Vector3(0, 0.04, 0.22))
			_add(lid, B._box(Vector3(0.12, 0.1, 0.06), GOLD), Vector3(0, 0.04, 0.44))  # the clasp
			for i in 4:
				_add(root, _coin(0.08), Vector3(0.35 + i * 0.13, 0.35 - i * 0.09, 0.25))
			_sparkles(root, rng, 7, Vector3(1.4, 0.8, 0.4), 0.7)
		"Heavy Traffic":  # cars nose to tail at a red light
			for i in 3:
				var car := _car([Color("#e8a02a"), BLUE, GREEN][i])
				car.scale = Vector3.ONE * 0.85
				_add(root, car, Vector3(-0.62 + i * 0.5, 0, 0.05 - i * 0.05))
			var light := Node3D.new()
			_add(root, light, Vector3(0.78, 0, -0.1))
			var pole := B._box(Vector3(0.04, 0.6, 0.04), Color("#505058"))
			pole.position.y = 0.3
			light.add_child(pole)
			var box := B._box(Vector3(0.14, 0.36, 0.1), Color("#303038"))
			box.position.y = 0.75
			light.add_child(box)
			for k in 3:
				var lamp := _ball(0.04, [RED, Color("#5a4a20"), Color("#1f4a2a")][k])
				if k == 0:
					lamp.material_override = B._material(RED, 1.2)
				lamp.position = Vector3(0, 0.86 - k * 0.11, 0.05)
				light.add_child(lamp)
		"Double Rent":  # your shop, two coins and a big x2
			_add(root, _house(0.7, 0.55, Color("#fff8ee"), Color("#2f9a6a")), Vector3(-0.35, 0, -0.1))
			_add(root, _coin(0.15), Vector3(0.3, 0.3, 0.2))
			_add(root, _coin(0.15), Vector3(0.55, 0.42, 0.1))
			_add(root, _word("x2", 120, GREEN, true), Vector3(0.45, 0.85, 0))
		"Market Tip":  # a bond with its price tag cut
			var bond := _plate(Vector2(0.8, 0.55), Color.WHITE, "BOND", 0.35, Color("#2e8b80"))
			bond.rotation.x = -0.2
			_add(root, bond, Vector3(-0.15, 0.4, -0.05))
			var tag := _plate(Vector2(0.36, 0.2), RED, "-10%", 0.5, Color.WHITE)
			tag.rotation.z = 0.25
			_add(root, tag, Vector3(0.4, 0.3, 0.2))
			var bulb := _ball(0.1, Color("#ffe98a"))
			bulb.material_override = B._material(Color("#ffe98a"), 0.8)
			_add(root, bulb, Vector3(0.45, 0.85, 0))
		"Scrap Tax":  # your coins flying into the Bank
			var bank := B._bank_building()
			bank.scale = Vector3.ONE * 1.05
			_add(root, bank, Vector3(0.2, 0, -0.1))
			for i in 4:
				var t := i / 3.0
				_add(root, _coin(0.08), Vector3(-0.8 + t * 0.7, 0.35 + sin(t * PI) * 0.35, 0.3))
		"Any Suit":  # the four suits round a rainbow
			var colours := [Color("#ff5a5a"), Color("#ffa64a"), Color("#ffe04a"), Color("#5ad86a"),
					Color("#4aa8ff"), Color("#a46aff")]
			for i in colours.size():
				var band := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.52 - i * 0.05
				torus.outer_radius = 0.56 - i * 0.05
				band.mesh = torus
				band.material_override = B._material(colours[i], 0.3)
				band.rotation.x = PI / 2
				_add(root, band, Vector3(0, 0.62, -0.2))
			var marks := [["Spade", Color("#2f3a8a")], ["Heart", Color("#e0405a")],
					["Diamond", Color("#f08a24")], ["Club", Color("#2f9a4a")]]
			for i in marks.size():
				var suit := B._suit(marks[i][0], marks[i][1])
				suit.scale = Vector3.ONE * 1.1
				var a := PI / 2 + i * TAU / 4 + PI / 4
				_add(root, suit, Vector3(cos(a) * 0.3, 0.45 + sin(a) * 0.25, 0))
		"Arcade Ticket":  # the arcade cabinet and a ticket to play
			var cabinet := B._arcade_cabinet()
			cabinet.scale = Vector3.ONE * 1.35
			_add(root, cabinet, Vector3(0.1, 0, -0.1))
			var ticket := _plate(Vector2(0.42, 0.2), Color("#ff8c3a"), "PLAY!", 0.45)
			ticket.rotation = Vector3(-0.2, 0.3, 0.2)
			_add(root, ticket, Vector3(-0.5, 0.55, 0.25))
	return root


## The bespoke scenes the newer cards borrow, by effect.
const BORROW := {
	"collect_each": "Scrap Drive", "charity": "Charity", "rich_pays_all": "Charity",
	"take_from_richest": "Charity", "pay_per_tier": "Inspection", "pay_per_lot": "Inspection",
	"blackout": "Power Cut", "free_invest": "Free Renovation", "invest_rate": "Free Renovation",
	"gain_random": "Lucky Dip", "move_again": "Rush Hour", "to_relay": "Shortcut",
	"to_depot": "Back to Base", "skip": "Heavy Traffic", "skip_rival": "Heavy Traffic",
	"double_rent": "Double Rent", "any_suit": "Any Suit", "swap": "Swap Meet",
	"gain_lot_pct": "Tax Refund", "warp_bank": "Back to Base", "warp_relay": "Shortcut",
}
const MOOD_OF_FX := {
	"gain": "gain", "collect_each": "gain", "all_gain": "gain", "gain_cash_pct": "gain",
	"gain_net_pct": "gain", "gain_lot_pct": "gain", "gain_per_lot": "gain", "gain_random": "gain",
	"double_rent": "gain", "charity": "gain", "take_from_richest": "gain", "commission": "gain",
	"pay_bank": "pay", "pay_each": "pay", "all_pay": "pay", "pay_cash_pct": "pay",
	"pay_net_pct": "pay", "pay_per_lot": "pay", "pay_per_tier": "pay", "skip": "pay",
	"lose_suit": "pay", "rich_pays_all": "pay",
	"move_again": "move", "move_ahead": "move", "to_random": "move", "to_relay": "move",
	"to_depot": "move", "minigame": "move", "skip_rival": "move",
	"bond_swing": "bonds", "free_bonds": "bonds", "bond_discount": "bonds", "bond_dividend": "bonds",
	"blackout": "night", "blackout_block": "night", "warp_any": "move", "warp_bank": "move",
	"warp_relay": "move", "reverse": "pay", "reverse_rival": "move",
}
const GAME_NAMES := {"": "Play a minigame!", "slots": "Play Scrap Slots!", "pick_a_card": "Play Pick a Card!",
		"wheel": "Spin the Wheel!", "race": "Race Day!"}
const TICKETS := {"slots": "SLOTS", "pick_a_card": "CARDS", "wheel": "WHEEL", "race": "RACE"}


## The backdrop's kind for `card`: gain, pay, move, bonds, lots or night.
static func mood(card: String) -> String:
	if card in DARK_CARDS:
		return "night"
	return MOOD_OF_FX.get(Wildcards.by_name(card).get("fx", ""), "lots")


## The few characters on the card over its picture, and their colour: just
## the number and a sign ("+60G", "-10%", "x2"). The card's name and what it
## does are written under the card.
static func caption(card: String) -> Array:
	var c := Wildcards.by_name(card)
	var pct := roundi(c.get("pct", 0.0) * 100)
	var amount: int = c.get("amount", 0)
	match c.get("fx", ""):
		"gain", "take_from_richest": return ["+%dG" % amount, GREEN]
		"gain_random": return ["?G", GREEN if c.min >= 0 else Color("#d4581a")]
		"pay_bank": return ["-%dG" % amount, RED]
		"collect_each": return ["+%dG each" % amount, GREEN]
		"pay_each", "rich_pays_all": return ["-%dG each" % amount, RED]
		"all_gain": return ["+%dG all" % amount, GREEN]
		"all_pay": return ["-%dG all" % amount, RED]
		"gain_cash_pct", "gain_net_pct", "gain_lot_pct": return ["+%d%%" % pct, GREEN]
		"pay_cash_pct", "pay_net_pct": return ["-%d%%" % pct, RED]
		"gain_per_lot": return ["+%dG/lot" % amount, GREEN]
		"pay_per_lot": return ["-%dG/lot" % amount, RED]
		"pay_per_tier": return ["-%dG/tier" % amount, RED]
		"boost_lot", "boost_block": return ["+%d%%" % roundi((c.mult - 1.0) * 100), GREEN]
		"devalue": return ["-%d%%" % roundi((1.0 - c.mult) * 100), RED]
		"blackout", "blackout_block": return ["0G", RED]
		"bond_swing":
			var up: bool = c.swing > 0
			return ["%s%d%%" % ["+" if up else "-", roundi(absf(c.swing) * 100)], GREEN if up else RED]
		"free_bonds": return ["+%d" % c.count, GREEN]
		"bond_discount": return ["-%d%%" % roundi((1.0 - c.discount) * 100), GREEN]
		"bond_dividend": return ["+%dG" % amount, GREEN]
		"free_invest": return ["FREE", GREEN]
		"invest_rate": return ["-%d%%" % roundi((1.0 - c.rate) * 100), GREEN]
		"move_again": return ["x2", BLUE]
		"move_ahead": return ["+%d" % c.steps, BLUE]
		"to_random": return ["?", BLUE]
		"to_relay": return ["♠", BLUE]
		"to_depot": return ["B", BLUE]
		"skip", "skip_rival": return ["STOP", RED]
		"double_rent": return ["x2", GREEN]
		"commission": return ["+20%", GREEN]
		"any_suit": return ["♠♥♦♣", Color("#7a4ac0")]
		"free_suit": return ["+1", GREEN]
		"lose_suit": return ["-1", RED]
		"minigame": return ["PLAY", Color("#d4581a")]
		"charity": return ["%dG" % amount, Color("#d0406a")]
		"swap": return ["⇄", Color("#7a4ac0")]
		"warp_any": return ["WARP", Color("#7a4ac0")]
		"warp_bank": return ["B", BLUE]
		"warp_relay": return ["♠", BLUE]
		"reverse": return ["BACK", RED]
		"reverse_rival": return ["BACK", BLUE]
		"forced_sale": return ["x2", GREEN]
	return ["", INK]


## A newer card's scene, made from its effect and amounts: the scene of a
## bespoke card it shares a meaning with (BORROW), or a template.
static func _template(card: String) -> Node3D:
	var c := Wildcards.by_name(card)
	var fx: String = c.get("fx", "")
	if BORROW.has(fx):
		return build(BORROW[fx])
	var root := Node3D.new()
	root.add_child(_base(fx == "blackout_block"))
	var rng := RandomNumberGenerator.new()
	rng.seed = card.hash()
	var amount: int = c.get("amount", 0)
	match fx:
		"gain", "gain_cash_pct", "gain_net_pct":  # a pile of coins, bigger for more
			var count := clampi(amount / 20, 5, 16) if fx == "gain" else 9
			_add(root, _pile(count, 0.27), Vector3(-0.1, 0, 0.1))
			_add(root, _coin(0.12), Vector3(0.35, 0.3, 0.2))
			_add(root, _coin(0.1), Vector3(0.55, 0.18, 0.05))
			_sparkles(root, rng, 6, Vector3(1.3, 0.8, 0.4), 0.6)
		"pay_bank", "pay_cash_pct", "pay_net_pct", "all_pay":  # coins flying into the Bank
			var bank := B._bank_building()
			bank.scale = Vector3.ONE * 1.05
			_add(root, bank, Vector3(0.25, 0, -0.1))
			var coins := clampi(amount / 40, 2, 5) if fx == "pay_bank" else 4
			for i in coins:
				var t := float(i) / maxi(coins - 1, 1)
				_add(root, _coin(0.08), Vector3(-0.8 + t * 0.7, 0.35 + sin(t * PI) * 0.35, 0.3))
			if fx == "all_pay":
				for x in [-0.75, -0.45]:
					_add(root, _person(Color("#8a9ab0"), 1.4), Vector3(x, 0, -0.2))
		"pay_each", "all_gain":  # coins going out to everyone (or raining on everyone)
			_add(root, _person(RED, 1.8), Vector3(0, 0, 0.15))
			for at in [Vector3(-0.62, 0, -0.2), Vector3(0, 0, -0.55), Vector3(0.62, 0, -0.2)]:
				var who := _person(Color("#8a9ab0"), 1.5)
				_add(root, who, at)
				who.rotation.y = atan2(-at.x, -at.z)
				_add(root, _coin(0.08), at * (0.5 if fx == "pay_each" else 1.0) + Vector3(0, 0.85, 0.1))
			if fx == "all_gain":
				_add(root, _coin(0.08), Vector3(0, 0.95, 0.15))
		"gain_per_lot":  # a row of your lots, a coin over each
			for i in 3:
				var x := -0.55 + i * 0.55
				_add(root, _house(0.42, 0.32 + i * 0.08, Color("#fff8ee"), RED), Vector3(x, 0, -0.05))
				_add(root, _coin(0.09), Vector3(x, 0.85 + i * 0.08, 0.1))
		"boost_lot", "boost_block", "devalue":  # lots with a big arrow up or down
			var up := fx != "devalue"
			var count := 3 if fx == "boost_block" else 1
			for i in count:
				var x := -0.2 if count == 1 else -0.5 + i * 0.5
				var size := 0.85 if count == 1 else 0.42
				_add(root, _house(size, size * 0.75, Color("#fff8ee"), BLUE if up else Color("#8a8a96")),
						Vector3(x, 0, -0.1))
			var colour := GREEN if up else RED
			var arrow_at := Vector3(0.55, 0.15 if up else 0.85, 0.3)
			_arrow(root, arrow_at, arrow_at + Vector3(0, 0.7 if up else -0.7, 0), colour)
			if up:
				_sparkles(root, rng, 5, Vector3(1.3, 0.6, 0.3), 0.75)
		"blackout_block":  # a whole row of dark shops
			for i in 3:
				var house := _house(0.42, 0.4, Color("#6a6a80"), Color("#4a4a60"))
				_unlight(house)
				_add(root, house, Vector3(-0.55 + i * 0.55, 0, -0.1))
			for angle in [PI / 4, -PI / 4]:
				var bar := B._box(Vector3(0.45, 0.06, 0.04), RED)
				bar.material_override = B._material(RED, 0.5)
				bar.rotation.z = angle
				_add(root, bar, Vector3(0.1, 0.85, 0.35))
		"bond_swing":
			_add(root, _whiteboard(c.swing > 0, "%s%d%%" % ["+" if c.swing > 0 else "-",
					roundi(absf(c.swing) * 100)]), Vector3(0, 0, -0.05))
		"free_bonds", "bond_dividend":  # a bond tied with a bow (or paying out coins)
			var bond := _plate(Vector2(0.8, 0.55), Color.WHITE, "BOND", 0.35, Color("#2e8b80"))
			bond.rotation.x = -0.2
			_add(root, bond, Vector3(0, 0.42, -0.05))
			if fx == "free_bonds":
				_add(root, B._box(Vector3(0.06, 0.58, 0.05), RED), Vector3(0, 0.42, 0.0))
				_add(root, B._box(Vector3(0.83, 0.06, 0.05), RED), Vector3(0, 0.42, 0.0))
				for side in [-1, 1]:
					var loop := _ball(0.08, RED.darkened(0.1))
					loop.scale = Vector3(1.3, 0.9, 0.5)
					_add(root, loop, Vector3(side * 0.09, 0.72, 0.0))
			else:
				for i in 3:
					_add(root, _coin(0.1), Vector3(-0.35 + i * 0.35, 0.9 + (i % 2) * 0.08, 0.15))
		"bond_discount":
			var bond := _plate(Vector2(0.8, 0.55), Color.WHITE, "BOND", 0.35, Color("#2e8b80"))
			bond.rotation.x = -0.2
			_add(root, bond, Vector3(-0.15, 0.4, -0.05))
			var tag := _plate(Vector2(0.36, 0.2), RED, "-%d%%" % roundi((1.0 - c.discount) * 100), 0.5,
					Color.WHITE)
			tag.rotation.z = 0.25
			_add(root, tag, Vector3(0.4, 0.3, 0.2))
		"move_ahead", "to_random":  # a ride along the road, or a bus to who knows where
			for i in 7:
				_add(root, B._box(Vector3(0.24, 0.02, 0.3), Color("#8a8a96")), Vector3(-0.8 + i * 0.27, 0.01, 0.05))
			var ride := _car(Color("#ffd84a") if fx == "move_ahead" else Color("#3fb6c9"))
			ride.scale = Vector3.ONE * (1.3 if fx == "move_ahead" else 1.6)
			_add(root, ride, Vector3(-0.3, 0.02, 0.05))
			if fx == "move_ahead":
				_arrow(root, Vector3(0.15, 0.55, 0.05), Vector3(0.8, 0.55, 0.05), BLUE)
				_add(root, _word(str(c.steps), 150, BLUE, true), Vector3(0.5, 0.9, 0))
			else:
				_add(root, _word("?", 220, Color("#7a4ac0"), true), Vector3(0.45, 0.85, 0))
		"commission":  # the Star's smiling star, coins round it
			var star := B._smiling_star()
			star.rotation.x = 1.1
			star.scale = Vector3.ONE * 2.2
			_add(root, star, Vector3(0, 0.6, 0))
			for at in [Vector3(-0.6, 0.35, 0.1), Vector3(0.6, 0.4, 0.1), Vector3(0.45, 0.95, 0)]:
				_add(root, _coin(0.09), at)
		"free_suit", "lose_suit":  # a suit, sparkling or crossed out
			var suit := B._suit("Heart", Color("#e0405a"))
			suit.scale = Vector3.ONE * 3.0
			_add(root, suit, Vector3(0, 0.55, 0))
			if fx == "free_suit":
				_sparkles(root, rng, 7, Vector3(1.3, 0.8, 0.4), 0.6)
			else:
				for angle in [PI / 4, -PI / 4]:
					var bar := B._box(Vector3(0.8, 0.08, 0.05), RED)
					bar.rotation.z = angle
					_add(root, bar, Vector3(0, 0.55, 0.3))
		"warp_any":  # a glowing portal, a figure stepping in
			for i in 4:
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 0.34 - i * 0.07
				torus.outer_radius = 0.38 - i * 0.07
				ring.mesh = torus
				ring.material_override = B._material([Color("#a46aff"), Color("#6a8aff"), Color("#4ae0ff"), Color.WHITE][i], 0.9)
				ring.rotation.x = PI / 2
				_add(root, ring, Vector3(0.15, 0.48, -0.1))
			var who := _person(RED, 1.6)
			who.rotation.y = 0.8
			_add(root, who, Vector3(-0.35, 0, 0.15))
			_sparkles(root, rng, 8, Vector3(1.2, 0.8, 0.3), 0.5)
		"reverse", "reverse_rival":  # a car on the road, a big arrow pointing back
			for i in 7:
				_add(root, B._box(Vector3(0.24, 0.02, 0.3), Color("#8a8a96")), Vector3(-0.8 + i * 0.27, 0.01, 0.05))
			var car := _car(RED if fx == "reverse" else BLUE)
			car.scale = Vector3.ONE * 1.3
			car.rotation.y = PI  # facing back the way it came
			_add(root, car, Vector3(0.25, 0.02, 0.05))
			_arrow(root, Vector3(0.0, 0.6, 0.05), Vector3(-0.75, 0.6, 0.05), RED)
		"forced_sale":  # a lot sold off: a SOLD board, twice the coins, a gavel
			_add(root, _house(0.6, 0.45, Color("#fff8ee"), Color("#8a8a96")), Vector3(-0.3, 0, -0.1))
			var sold := _plate(Vector2(0.4, 0.18), RED, "SOLD", 0.5, Color.WHITE)
			sold.rotation.z = -0.15
			_add(root, sold, Vector3(-0.3, 0.75, 0.15))
			_add(root, _coin(0.13), Vector3(0.35, 0.32, 0.2))
			_add(root, _coin(0.13), Vector3(0.58, 0.45, 0.1))
			var gavel := Node3D.new()
			_add(root, gavel, Vector3(0.35, 0.75, 0.0))
			gavel.rotation.z = 0.7
			gavel.add_child(B._box(Vector3(0.04, 0.32, 0.04), Color("#8a5a2a")))
			var head := B._cyl(0.06, 0.06, 0.16, Color("#6a4020"))
			head.rotation.z = PI / 2
			head.position.y = 0.17
			gavel.add_child(head)
		"minigame":
			var cabinet := B._arcade_cabinet()
			cabinet.scale = Vector3.ONE * 1.35
			_add(root, cabinet, Vector3(0.1, 0, -0.1))
			var ticket := _plate(Vector2(0.5, 0.2), Color("#ff8c3a"), TICKETS.get(c.game, "PLAY!"), 0.45)
			ticket.rotation = Vector3(-0.2, 0.3, 0.2)
			_add(root, ticket, Vector3(-0.5, 0.55, 0.25))
	return root


# --- pieces -------------------------------------------------------------

static func _add(root: Node3D, node: Node3D, at: Vector3) -> Node3D:
	node.position = at
	root.add_child(node)
	return node


## The round patch of grass the scene stands on (dusk-dark for a night card).
static func _base(dark: bool) -> Node3D:
	var disc := B._cyl(1.0, 1.0, 0.08, Color("#2e4a36") if dark else Color("#74d64a"))
	disc.position.y = -0.04
	return disc


static func _ball(r: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2
	mi.mesh = mesh
	mi.material_override = B._material(colour)
	return mi


## A coin standing on its edge, facing the camera, with a G.
static func _coin(r: float) -> Node3D:
	var root := Node3D.new()
	var disc := B._cyl(r, r, r * 0.25, GOLD)
	disc.material_override = B._material(GOLD, 0.25)
	disc.rotation.x = PI / 2
	root.add_child(disc)
	var g := _word("G", int(r * 900), GOLD_DARK)
	g.position.z = r * 0.13
	root.add_child(g)
	return root


## A stack of `count` coins lying flat, each a little out of line.
static func _pile(count: int, r: float) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = count
	for i in count:
		var coin := B._cyl(r, r, r * 0.22, GOLD)
		coin.material_override = B._material(GOLD if i % 2 == 0 else GOLD.lightened(0.15), 0.2)
		coin.position = Vector3(rng.randf_range(-0.02, 0.02), r * 0.11 + i * r * 0.23, rng.randf_range(-0.02, 0.02))
		root.add_child(coin)
	return root


## A board-style house, `w` wide and `h` tall.
static func _house(w: float, h: float, wall: Color, roof: Color) -> Node3D:
	var t := {"building": Node3D.new(), "body_mat": B._material(wall), "roof_mat": B._material(roof)}
	B._build_house(t, w, h)
	return t.building


## Puts a house's lights out.
static func _unlight(house: Node3D) -> void:
	for child in house.get_children():
		var mi := child as MeshInstance3D
		if mi and (mi.material_override as StandardMaterial3D).albedo_color == B.HOUSE_WINDOW:
			mi.material_override = B._material(Color("#30303e"))


static func _person(colour: Color, s: float) -> Node3D:
	var figure := Character.new()
	figure.setup(colour)
	figure.scale = Vector3.ONE * s
	return figure


## A little car: body, cabin with glass, four wheels and headlights; it faces +x.
static func _car(colour: Color) -> Node3D:
	var root := Node3D.new()
	_add(root, B._box(Vector3(0.6, 0.16, 0.3), colour), Vector3(0, 0.15, 0))
	_add(root, B._box(Vector3(0.34, 0.15, 0.28), colour.lightened(0.1)), Vector3(-0.03, 0.3, 0))
	var glass := B._box(Vector3(0.35, 0.1, 0.285), Color.WHITE)
	glass.material_override = B._material(Color("#cfeaff"))
	_add(root, glass, Vector3(-0.03, 0.31, 0))
	for x in [-0.19, 0.19]:
		for z in [-0.15, 0.15]:
			var wheel := B._cyl(0.075, 0.075, 0.05, Color("#26262a"))
			wheel.rotation.x = PI / 2
			_add(root, wheel, Vector3(x, 0.075, z))
	for z in [-0.09, 0.09]:
		var lamp := B._box(Vector3(0.01, 0.04, 0.06), Color("#fff2b0"))
		lamp.material_override = B._material(Color("#fff2b0"), 0.8)
		_add(root, lamp, Vector3(0.305, 0.17, z))
	return root


## A white die `side` across, its top showing `top` (1, 3 or 5) and the front 2.
static func _die(side: float, top: int) -> Node3D:
	var root := Node3D.new()
	root.add_child(B._box(Vector3.ONE * side, Color("#fbfbf6")))
	root.add_child(B._outline(Vector3.ONE * side, side * 0.05))
	root.add_child(B._edges(Vector3.ONE * side, side * 0.045))
	var o := side * 0.26
	var spots := {1: [Vector2.ZERO], 3: [Vector2(-o, -o), Vector2.ZERO, Vector2(o, o)],
			5: [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)]}
	for p: Vector2 in spots[top]:
		var pip := B._cyl(side * 0.09, side * 0.09, 0.01, Color("#202028"))
		pip.position = Vector3(p.x, side / 2, p.y)
		root.add_child(pip)
	for p in [Vector2(-o, -o), Vector2(o, o)]:
		var pip := B._cyl(side * 0.09, side * 0.09, 0.01, Color("#202028"))
		pip.rotation.x = PI / 2
		pip.position = Vector3(p.x, p.y, side / 2)
		root.add_child(pip)
	return root


## A whiteboard on an easel with a bond chart on it: grid lines, a line
## climbing (green) or diving (red) to an arrowhead, and the change written in
## the corner.
static func _whiteboard(up: bool, figure_text := "") -> Node3D:
	var root := Node3D.new()
	for side in [-1, 1]:  # the easel's front legs, and one behind
		var leg := B._box(Vector3(0.04, 1.0, 0.04), B.WOOD)
		leg.rotation.z = side * 0.12
		_add(root, leg, Vector3(side * 0.42, 0.48, 0.02))
	var back := B._box(Vector3(0.04, 0.95, 0.04), B.WOOD)
	back.rotation.x = -0.35
	_add(root, back, Vector3(0, 0.45, -0.18))
	var board := Node3D.new()
	board.rotation.x = -0.12  # leaning back on the easel
	_add(root, board, Vector3(0, 0.62, 0.05))
	board.add_child(B._box(Vector3(1.12, 0.74, 0.05), Color("#9aa0aa")))  # frame
	var face := B._box(Vector3(1.04, 0.66, 0.02), Color.WHITE)
	face.position.z = 0.02
	board.add_child(face)
	var tray := B._box(Vector3(0.8, 0.03, 0.06), Color("#9aa0aa"))
	tray.position = Vector3(0, -0.38, 0.04)
	board.add_child(tray)
	for i in 3:
		var line := B._box(Vector3(0.96, 0.008, 0.004), Color("#dde6ea"))
		line.position = Vector3(0, -0.2 + i * 0.2, 0.032)
		board.add_child(line)
	var colour := GREEN if up else RED
	var ys := [-0.18, -0.1, -0.14, 0.0, 0.05, 0.14, 0.22]
	var pts: Array[Vector3] = []
	for i in ys.size():
		var y: float = ys[i] if up else -ys[i]
		pts.append(Vector3(-0.42 + i * 0.13, y, 0.036))
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := B._box(Vector3(a.distance_to(b) + 0.02, 0.035, 0.008), colour)
		seg.position = (a + b) / 2
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x)
		board.add_child(seg)
	var dir := (pts[-1] - pts[-2]).normalized()
	var head := MeshInstance3D.new()
	var tri := PrismMesh.new()
	tri.size = Vector3(0.1, 0.1, 0.01)
	head.mesh = tri
	head.material_override = B._material(colour)
	head.position = pts[-1] + dir * 0.04
	head.rotation.z = atan2(dir.y, dir.x) - PI / 2
	board.add_child(head)
	if figure_text == "":
		figure_text = "+15%" if up else "-15%"
	var figure := _word(figure_text, 90, colour)
	figure.position = Vector3(-0.3, 0.2 if up else -0.2, 0.04)
	board.add_child(figure)
	return root


## A flat panel (a ticket, a bond, a price tag) with a word on it.
static func _plate(dims: Vector2, colour: Color, text: String, text_scale: float,
		ink := INK) -> Node3D:
	var root := Node3D.new()
	root.add_child(B._box(Vector3(dims.x, dims.y, 0.025), colour))
	var edge := B._box(Vector3(dims.x + 0.03, dims.y + 0.03, 0.02), colour.darkened(0.3))
	edge.position.z = -0.005
	root.add_child(edge)
	var word := _word(text, int(dims.y * 600 * text_scale), ink)
	word.position.z = 0.014
	root.add_child(word)
	return root


## Upright text, or a billboard that always faces the camera.
static func _word(text: String, font_size: int, colour: Color, billboard := false) -> Label3D:
	var l := B._label(text, font_size, colour, billboard)
	if not billboard:
		l.rotation_degrees.x = 0
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.width = 0
	l.outline_size = 10
	l.outline_modulate = Color(1, 1, 1, 0.9) if colour.v < 0.8 else colour.darkened(0.5)
	l.pixel_size = 0.0025
	return l


## A thick arrow from `from` to `to`: a bar and a cone at the tip.
static func _arrow(root: Node3D, from: Vector3, to: Vector3, colour: Color) -> void:
	var dir := (to - from).normalized()
	var shaft_len := from.distance_to(to) - 0.16
	var shaft := B._box(Vector3(0.07, 0.07, shaft_len), colour)
	shaft.position = from + dir * shaft_len / 2
	shaft.basis = Basis.looking_at(dir, Vector3.UP)
	root.add_child(shaft)
	var tip := B._cyl(0.0, 0.12, 0.2, colour)
	tip.position = to - dir * 0.1
	tip.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
	root.add_child(tip)


## An arrow bowing `bow` up (or down, negative) on its way from `from` to `to`:
## a chain of short pieces, then a cone.
static func _arc_arrow(root: Node3D, from: Vector3, to: Vector3, bow: float, colour: Color) -> void:
	var pts: Array[Vector3] = []
	for i in 13:
		var t := i / 12.0
		pts.append(from.lerp(to, t) + Vector3(0, sin(t * PI) * bow, 0))
	for i in 10:
		var a := pts[i]
		var b := pts[i + 1]
		var piece := B._box(Vector3(0.06, 0.06, a.distance_to(b) + 0.02), colour)
		piece.position = (a + b) / 2
		piece.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
		root.add_child(piece)
	var dir := (pts[12] - pts[10]).normalized()
	var tip := B._cyl(0.0, 0.11, 0.18, colour)
	tip.position = pts[11] + dir * 0.05
	tip.basis = Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
	root.add_child(tip)


static func _confetti(root: Node3D, rng: RandomNumberGenerator, count: int, spread: Vector3, y: float) -> void:
	var colours := [Color("#ff5a5a"), Color("#ffd84a"), Color("#4aa8ff"), Color("#5ad86a"), Color("#ff7ae8")]
	for i in count:
		var bit := B._box(Vector3(0.05, 0.015, 0.03), colours[i % colours.size()])
		bit.position = Vector3(rng.randf_range(-0.5, 0.5) * spread.x, y + rng.randf_range(-0.5, 0.5) * spread.y,
				rng.randf_range(-0.5, 0.5) * spread.z)
		bit.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		root.add_child(bit)


static func _sparkles(root: Node3D, rng: RandomNumberGenerator, count: int, spread: Vector3, y: float) -> void:
	for i in count:
		var s := _word("✦", rng.randi_range(70, 120), Color("#ffd84a"), true)
		s.outline_size = 0
		s.position = Vector3(rng.randf_range(-0.5, 0.5) * spread.x, y + rng.randf_range(-0.5, 0.5) * spread.y,
				rng.randf_range(-0.5, 0.5) * spread.z)
		root.add_child(s)
