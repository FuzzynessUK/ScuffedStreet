class_name Minigames
extends RefCounted
## Minigame rules (docs/DESIGN.md, "Minigames"). Everything random is drawn
## here from the game's rng; the UI only shows it, so a minigame plays the same
## for CPUs and in headless tests.
##
## A minigame starts from an Arcade space or the Arcade Ticket card.

const LIST := ["slots", "pick_a_card", "wheel", "race"]  # an Arcade space or ticket picks one at random
const NAMES := {"slots": "Scrap Slots", "pick_a_card": "Pick a Card", "wheel": "Chance Wheel",
		"race": "Critter Race"}


static func pick_minigame(g: GameState) -> String:
	return LIST[g.rng.randi_range(0, LIST.size() - 1)]

# --- Scrap Slots --------------------------------------------------------
# A 3x3 grid. All three rows spin and are stopped one at a time, top to
# bottom. Stop is not a timing test: a row's three symbols are drawn when its
# Stop is pressed and the row then slows onto them. Only three in a line pays
# (any row, column or diagonal), and every winning line pays.

## name, label on the reel, colour, weight (how often a draw picks it)
const SLOT_SYMBOLS := [
	{"name": "Gold", "label": "G", "color": "#ffd84a", "weight": 1},
	{"name": "Bolt", "label": "BOLT", "color": "#9aa7b8", "weight": 3},
	{"name": "Warp", "label": "WARP", "color": "#9a8fe0", "weight": 2},
	{"name": "Bond", "label": "BOND", "color": "#2e8b80", "weight": 2},
	{"name": "Card", "label": "★", "color": "#f29bd0", "weight": 2},
]
const SLOT_GOLD := 400   # a line of Gold
const SLOT_BOLT := 120   # a line of Bolts
const SLOT_BONDS := 10   # a line of Bonds: free bonds in a random block
## The eight lines through the grid (cells 0-8, row by row): three rows,
## three columns and the two diagonals.
const SLOT_LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8],
		[0, 4, 8], [2, 4, 6]]


## One cell's symbol (index into SLOT_SYMBOLS), drawn by weight.
static func slot_symbol(g: GameState) -> int:
	var total := 0
	for s in SLOT_SYMBOLS:
		total += s.weight
	var roll := g.rng.randi_range(1, total)
	for i in SLOT_SYMBOLS.size():
		roll -= SLOT_SYMBOLS[i].weight
		if roll <= 0:
			return i
	return 0


## A stopped row: three symbols, left to right.
static func slot_row(g: GameState) -> Array:
	return [slot_symbol(g), slot_symbol(g), slot_symbol(g)]


## Every line of three alike in a finished grid (9 symbols):
## [{"cells": [a, b, c], "symbol": s}, ...].
static func slot_lines(grid: Array) -> Array:
	var out := []
	for line in SLOT_LINES:
		if grid[line[0]] == grid[line[1]] and grid[line[1]] == grid[line[2]]:
			out.append({"cells": line, "symbol": grid[line[0]]})
	return out


## What a finished grid pays, all its lines together: {"cash", "cards",
## "bonds" (lines of Bonds), "warp", "lines", "text"}. A Warp happens once
## however many Warp lines there are.
static func slot_result(grid: Array) -> Dictionary:
	var res := {"cash": 0, "cards": 0, "bonds": 0, "warp": false, "lines": slot_lines(grid)}
	var paying := 0
	for l in res.lines:
		match SLOT_SYMBOLS[l.symbol].name:
			"Gold":
				res.cash += SLOT_GOLD
			"Bolt":
				res.cash += SLOT_BOLT
			"Warp":
				res.warp = true
			"Bond":
				res.bonds += 1
			"Card":
				res.cards += 1
			_:
				continue
		paying += 1
	var parts := PackedStringArray()
	if res.cash > 0:
		parts.append("+%d G" % res.cash)
	if res.bonds > 0:
		parts.append("%d free bonds" % (SLOT_BONDS * res.bonds))
	if res.cards > 0:
		parts.append("an Any Suit card" if res.cards == 1 else "%d Any Suit cards" % res.cards)
	if res.warp:
		parts.append("a WARP")
	if paying == 0:
		res.text = "No line this time"
	else:
		res.text = ("%d lines! " % paying if paying > 1 else "A line! ") + ", ".join(parts)
	return res


## Where a Warp may go: the Depot, every suit (and any Market a board has).
static func warp_targets(g: GameState) -> Array[int]:
	var out: Array[int] = [g.board.depot]
	for s in g.board.spaces:
		if s.type == "relay" or s.type == "market":
			out.append(s.id)
	return out


## CPU Warp: the Depot with every suit (PAYDAY), else a suit it still needs.
static func cpu_warp(g: GameState, p: PlayerState) -> int:
	if g.has_all_suits(p):
		return g.board.depot
	for r in g.board.relay_ids():
		if r not in p.punches:
			return r
	return g.board.depot


## Pays a minigame prize won at `where`. Returns {"land_again": true} after a Warp.
static func apply_prize(g: GameState, p: PlayerState, prize: Dictionary, pick = null,
		where := "Scrap Slots") -> Dictionary:
	match prize.kind:
		"cash":
			g.earn(p, prize.amount)
			g._note("%s wins %d G at %s" % [p.name, prize.amount, where], "gain", p.index)
		"card":
			g.give_any_suit(p, "wins", " at %s" % where)
		"bonds":
			p.bonds[pick] = p.bonds_in(pick) + SLOT_BONDS
			g._note("%s wins %d Block %s bonds at %s" % [p.name, SLOT_BONDS,
					g.board.blocks[pick].name, where], "gain", p.index)
		"warp":
			g.warp(p, pick)
			return {"land_again": true}
		_:
			g._note("%s wins nothing at %s" % [p.name, where], "info", p.index)
	return {}


## A whole Scrap Slots game for a CPU (the sim and tests): spin, pay, pick.
static func cpu_slots(g: GameState, p: PlayerState) -> Dictionary:
	var grid := slot_row(g) + slot_row(g) + slot_row(g)
	var res := slot_result(grid)
	return slot_apply(g, p, res, cpu_warp(g, p) if res.warp else -1,
			Wildcards.draw_block(g) if res.bonds > 0 else "")


## Pays a slot_result: G, Any Suit cards (still two at most), SLOT_BONDS free
## bonds per Bond line in `block`, then the Warp to `warp_to` last. Returns
## {"land_again": true} after a Warp.
static func slot_apply(g: GameState, p: PlayerState, res: Dictionary, warp_to := -1,
		block := "") -> Dictionary:
	var where := NAMES.slots
	if res.cash > 0:
		apply_prize(g, p, {"kind": "cash", "amount": res.cash}, null, where)
	for i in res.cards:
		apply_prize(g, p, {"kind": "card"}, null, where)
	if res.bonds > 0:
		var n: int = SLOT_BONDS * res.bonds
		p.bonds[block] = p.bonds_in(block) + n
		g._note("%s wins %d Block %s bonds at %s" % [p.name, n, g.board.blocks[block].name, where],
				"gain", p.index)
	if res.warp:
		return apply_prize(g, p, {"kind": "warp"}, warp_to, where)
	if res.cash == 0 and res.cards == 0 and res.bonds == 0:
		apply_prize(g, p, {"kind": "none"}, null, where)
	return {}


# --- Pick a Card --------------------------------------------------------
# Four cards are shown face up with their prizes, gathered into one
# stack, shuffled and dealt back face down. Where each prize lands is a fresh
# draw that nothing on screen gives away, so the pick is pure luck.

## Each card: its prize, and the short caption under its picture.
const CARD_PRIZES := [
	{"kind": "cash", "amount": 300, "text": "300 G!", "caption": "300 G"},
	{"kind": "cash", "amount": 100, "text": "100 G", "caption": "100 G"},
	{"kind": "card", "text": "An Any Suit card!", "caption": "Any Suit"},
	{"kind": "none", "text": "Nothing this time...", "caption": "Nothing"},
]


## A deal: which prize (index into CARD_PRIZES) lies at each table position.
## Drawn once for the cards shown face up and again for the deal back.
static func card_deal(g: GameState) -> Array:
	var order := range(CARD_PRIZES.size())
	for i in range(order.size() - 1, 0, -1):
		var j := g.rng.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	return order


## The position a CPU picks: a guess, like everyone's.
static func cpu_card(g: GameState) -> int:
	return g.rng.randi_range(0, CARD_PRIZES.size() - 1)


## A whole minigame for a CPU (the sim and tests): `which` from LIST.
static func cpu_minigame(g: GameState, p: PlayerState, which: String) -> Dictionary:
	if which == "slots":
		return cpu_slots(g, p)
	if which == "race":  # everyone backs a racer and is paid by its place
		var plan := race_plan(g)
		for seat in race_pick_order(g):
			var q := g.players[seat]
			apply_prize(g, q, race_prize(race_place(plan, cpu_racer(g)), q.level), null, NAMES[which])
		return {}
	if which == "wheel":
		var target := wheel_player(g)
		var action := wheel_action(g)
		var blocks := wheel_blocks(g, target, action)
		var block := wheel_block(g, blocks) if not blocks.is_empty() else ""
		wheel_apply(g, p, target, action, block)
		return {}
	var order := card_deal(g)
	var prize: Dictionary = CARD_PRIZES[order[cpu_card(g)]]
	return apply_prize(g, p, prize, null, NAMES[which])


# --- Chance Wheel -------------------------------------------------------
# Two spinning wheels: one picks a player (anyone still in, the thrower too),
# the other what happens to them, good or bad. A bond action brings out a
# third wheel for the block. The player throws a dart at each. Like the
# reels, the throw is not a timing test: the result is drawn when the dart is
# thrown and the wheel then slows to stop under it.

## What the action wheel can land on. `bonds`: needs the block wheel.
const WHEEL_ACTIONS := [
	{"label": "+300 G", "good": true},
	{"label": "−200 G", "good": false},
	{"label": "Any Suit", "good": true},
	{"label": "−5 bonds", "good": false, "bonds": -5},
	{"label": "+100 G", "good": true},
	{"label": "Skip move", "good": false},
	{"label": "+5 bonds", "good": true, "bonds": 5},
]


## The blocks the block wheel shows for `action` on player `target`: every
## block for a gain, only those they hold bonds in for a loss (empty: no
## block wheel, because there is nothing to win or lose with).
static func wheel_blocks(g: GameState, target: int, action: int) -> Array[String]:
	var out: Array[String] = []
	var change: int = WHEEL_ACTIONS[action].get("bonds", 0)
	if change == 0:
		return out
	for b in g.board.blocks:
		if change > 0 or g.players[target].bonds_in(b) > 0:
			out.append(b)
	return out


## The block wheel's result.
static func wheel_block(g: GameState, blocks: Array[String]) -> String:
	return blocks[g.rng.randi_range(0, blocks.size() - 1)]


## The players on the player wheel, in seat order.
static func wheel_players(g: GameState) -> Array[int]:
	var out: Array[int] = []
	for q in g.players:
		if not q.broke:
			out.append(q.index)
	return out


## The player wheel's result: a player index.
static func wheel_player(g: GameState) -> int:
	var seats := wheel_players(g)
	return seats[g.rng.randi_range(0, seats.size() - 1)]


## The action wheel's result: an index into WHEEL_ACTIONS.
static func wheel_action(g: GameState) -> int:
	return g.rng.randi_range(0, WHEEL_ACTIONS.size() - 1)


## Does `action` to player `target`, in `block` for a bond action. A loss of
## G can leave them owing (charge); lost bonds are simply taken away.
static func wheel_apply(g: GameState, thrower: PlayerState, target: int, action: int,
		block := "") -> void:
	var q := g.players[target]
	var what := ""
	match action:
		0:
			g.earn(q, 300)
			what = "gets 300 G"
		1:
			what = "pays 200 G into the Pot"
		2:
			if q.any_suits < GameState.MAX_ANY_SUITS:
				q.any_suits += 1
				what = "gets an Any Suit card (%d held)" % q.any_suits
			else:
				what = "would get an Any Suit card, but already holds the most allowed (%d)" \
						% GameState.MAX_ANY_SUITS
		3:
			if block == "":
				what = "would lose 5 bonds, but has none"
			else:
				var lost := mini(5, q.bonds_in(block))
				q.bonds[block] = q.bonds_in(block) - lost
				if q.bonds[block] == 0:
					q.bonds.erase(block)
				what = "loses %d Block %s bonds" % [lost, g.board.blocks[block].name]
		4:
			g.earn(q, 100)
			what = "gets 100 G"
		5:
			q.skip_move = true
			what = "skips their next move"
		6:
			q.bonds[block] = q.bonds_in(block) + 5
			what = "gets 5 Block %s bonds" % g.board.blocks[block].name
	g._note("Chance Wheel (%s's dart): %s %s" % [thrower.name, q.name, what],
			"gain" if WHEEL_ACTIONS[action].good else "loss", q.index)
	if action == 1:
		g.charge(q, 200, -1)


# --- Critter Race -------------------------------------------------------
# Four animals race down a meadow track; the player backs one. Each race is
# planned here: every racer gets a finishing time (all drawn the same way, so
# every animal is equally likely to win) and a pace for each stretch of the
# race in its own style, different every time. The 3D race just plays the plan.

const RACERS := [
	{"name": "Bunny", "style": "hop", "blurb": "Hops in bursts", "color": "#f4f0ff"},
	{"name": "Turtle", "style": "steady", "blurb": "Slow and steady", "color": "#4fae5a"},
	{"name": "Fox", "style": "dash", "blurb": "Sprints, then puffs", "color": "#f08a3a"},
	{"name": "Duck", "style": "waddle", "blurb": "Waddles, then flaps", "color": "#ffd23f"},
]
const RACE_WIN_PER_LEVEL := 100  # 1st place: 100 G x the player's level...
const RACE_WIN_MIN := 200        # ...but never less than this (level 1 wins 200 G)
const RACE_PRIZES := [0, 120, 40, 0]  # G for 2nd, 3rd, 4th (1st: see above)
const RACE_TIME_MIN := 8.0   # seconds the winner might take...
const RACE_TIME_MAX := 11.0  # ...and the slowest
const RACE_LEGS := 8         # stretches of equal time, each with its own pace


## A race plan: for each racer {"time": seconds to finish, "legs": share of the
## track covered in each of RACE_LEGS equal stretches of its time (sums to 1)}.
static func race_plan(g: GameState) -> Array:
	var plan := []
	for r in RACERS:
		var legs := []
		var phase := g.rng.randi_range(0, 1)
		var flap := g.rng.randi_range(0, RACE_LEGS - 1)
		for k in RACE_LEGS:
			var pace := 1.0
			match r.style:
				"steady":
					pace = g.rng.randf_range(0.88, 1.12)
				"hop":
					pace = g.rng.randf_range(0.4, 1.6)
				"dash":
					pace = (1.7 if k % 2 == phase else 0.35) * g.rng.randf_range(0.8, 1.2)
				"waddle":
					pace = g.rng.randf_range(0.65, 1.35) * (2.2 if k == flap else 1.0)
			legs.append(pace)
		var total: float = legs.reduce(func(a, b): return a + b, 0.0)
		plan.append({"time": g.rng.randf_range(RACE_TIME_MIN, RACE_TIME_MAX),
				"legs": legs.map(func(x): return x / total)})
	return plan


## How far along the track (0..1) a racer is `t` seconds into the race.
static func race_progress(entry: Dictionary, t: float) -> float:
	if t >= entry.time:
		return 1.0
	var at: float = t / entry.time * RACE_LEGS
	var leg := int(at)
	var done := 0.0
	for k in leg:
		done += float(entry.legs[k])
	return done + float(entry.legs[leg]) * (at - leg)


## Racer indices from first to last.
static func race_order(plan: Array) -> Array:
	var order := range(plan.size())
	order.sort_custom(func(a, b): return plan[a].time < plan[b].time)
	return order


## Where racer `pick` finishes: 0 for first.
static func race_place(plan: Array, pick: int) -> int:
	return race_order(plan).find(pick)


## The prize (as apply_prize takes it) for finishing in `place`.
static func race_prize(place: int, level: int) -> Dictionary:
	var names := ["1st", "2nd", "3rd", "4th"]
	var amount := race_amount(place, level)
	if amount > 0:
		return {"kind": "cash", "amount": amount,
				"text": "%s place! +%d G" % [names[place], amount]}
	return {"kind": "none", "text": "%s place... no prize" % names[place]}


## G for finishing in `place` at player level `level`: the winner gets 100 G
## x level (200 G at level 1), 2nd and 3rd are fixed, 4th gets nothing.
static func race_amount(place: int, level: int) -> int:
	return maxi(RACE_WIN_MIN, RACE_WIN_PER_LEVEL * level) if place == 0 else RACE_PRIZES[place]


## Who picks a racer first: the player furthest behind (lowest net worth),
## up to the leader; ties keep seat order. Winnings are paid in this order too.
static func race_pick_order(g: GameState) -> Array[int]:
	var order := wheel_players(g)
	order.sort_custom(func(a, b):
		var wa := g.net_worth(g.players[a])
		var wb := g.net_worth(g.players[b])
		return wa < wb or (wa == wb and a < b))
	return order


static func cpu_racer(g: GameState) -> int:
	return g.rng.randi_range(0, RACERS.size() - 1)
