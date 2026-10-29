class_name Wildcards
extends RefCounted
## The Wildcard deck and its effects (docs/DESIGN.md, "Wildcards").
##
## A card's `pick` says what the player must choose before it resolves:
##   none, own_lot, own_lot_upgradable, rival_lot, block, swap
## choices() lists the valid picks (an empty list for a picking card means it
## fizzles); apply() resolves the card and returns follow-ups for the
## controller: {"move_again": true} or {"land_again": true}.

const CARDS := [
	{"name": "Scrap Drive", "text": "Every other player pays you 40.", "pick": "none"},
	{"name": "Parking Ticket", "text": "Pay 100 into the Pot.", "pick": "none"},
	{"name": "Rush Hour", "text": "Roll again and move.", "pick": "none"},
	{"name": "Inspection", "text": "Pay 25 for every renovation tier you own.", "pick": "none"},
	{"name": "Grand Opening", "text": "One of your lots gains +20% value for good.", "pick": "own_lot"},
	{"name": "Power Cut", "text": "A rival's lot charges no rent until their next turn.", "pick": "rival_lot"},
	{"name": "Lucky Find", "text": "Gain 150.", "pick": "none"},
	{"name": "Bond Bump", "text": "A block's bond price rises 15%.", "pick": "block"},
	{"name": "Bond Slump", "text": "A block's bond price falls 15%.", "pick": "block"},
	{"name": "Shortcut", "text": "Jump to the nearest Relay you haven't punched.", "pick": "none"},
	{"name": "Tax Refund", "text": "Gain 5% of your lot value.", "pick": "none"},
	{"name": "Swap Meet", "text": "Swap one of your Shacks for a rival's Shack, paying the difference if theirs is worth more.", "pick": "swap"},
	{"name": "Charity", "text": "The richest player gives 100 to the poorest.", "pick": "none"},
	{"name": "Back to Base", "text": "Go straight to the Depot (PAYDAY if you hold every suit).", "pick": "none"},
	{"name": "Free Renovation", "text": "Renovate one of your lots by one tier for free.", "pick": "own_lot_upgradable"},
	{"name": "Pot Luck", "text": "Take half the Pot.", "pick": "none"},
	{"name": "Heavy Traffic", "text": "You don't move on your next turn.", "pick": "none"},
	{"name": "Double Rent", "text": "The next rent you collect is doubled.", "pick": "none"},
	{"name": "Market Tip", "text": "Buy up to 10 bonds in a block at 10% off.", "pick": "block"},
	{"name": "Scrap Tax", "text": "Pay 10% of your cash to the bank.", "pick": "none"},
]
const BOND_SWING := 0.15
const MARKET_TIP_BONDS := 10
const MARKET_TIP_DISCOUNT := 0.9


static func card(id: int) -> Dictionary:
	return CARDS[id]


## Valid picks for the card: lot ids, block ids, or [mine, theirs] pairs for swap.
static func choices(g: GameState, p: PlayerState, id: int) -> Array:
	var out := []
	match CARDS[id].pick:
		"own_lot":
			for lot in g.lots:
				if g.lots[lot].owner == p.index:
					out.append(lot)
		"own_lot_upgradable":
			for lot in g.lots:
				if g.lots[lot].owner == p.index and g.lots[lot].tier < GameState.MAX_TIER:
					out.append(lot)
		"rival_lot":
			for lot in g.lots:
				if g.lots[lot].owner >= 0 and g.lots[lot].owner != p.index:
					out.append(lot)
		"block":
			out.assign(g.board.blocks.keys())
		"swap":
			for mine in g.lots:
				if g.lots[mine].owner != p.index or g.lots[mine].tier != 0:
					continue
				for theirs in g.lots:
					var o: int = g.lots[theirs].owner
					if o >= 0 and o != p.index and g.lots[theirs].tier == 0:
						out.append([mine, theirs])
	return out


static func apply(g: GameState, p: PlayerState, id: int, pick = null) -> Dictionary:
	var c: Dictionary = CARDS[id]
	g._note("%s draws %s: %s" % [p.name, c.name, c.text], "card", p.index, p.position)
	if c.pick != "none" and pick == null:
		g._note("...but there is nothing to choose, so nothing happens.", "info", p.index)
		return {}
	match id:
		0:  # Scrap Drive
			for q in g.players:
				if q != p and not q.broke and not g.game_over:
					g.charge(q, 40, p.index)
		1:  # Parking Ticket
			g.charge(p, 100, -2)
		2:  # Rush Hour
			return {"move_again": true}
		3:  # Inspection
			var tiers := 0
			for lot in g.lots:
				if g.lots[lot].owner == p.index:
					tiers += g.lots[lot].tier
			if tiers > 0:
				g.charge(p, tiers * 25, -1)
		4:  # Grand Opening
			g.lots[pick].boost *= 1.2
			g.bond_pressure.erase(g.space(pick).block)
			g._note("%s is worth %d now" % [g._label(pick), g.lot_value(pick)], "own", p.index, pick)
		5:  # Power Cut
			g.lots[pick].blackout = true
			g._note("%s loses power" % g._label(pick), "loss", g.lots[pick].owner, pick)
		6:  # Lucky Find
			p.cash += 150
		7, 8:  # Bond Bump / Bond Slump
			var swing := 1.0 + BOND_SWING if id == 7 else 1.0 - BOND_SWING
			g.bond_pressure[pick] = g.bond_pressure.get(pick, 1.0) * swing
			g._note("%s bonds now %d" % [g.board.blocks[pick].name, g.bond_price(pick)], "info", p.index)
		9:  # Shortcut
			var target := _nearest_unpunched_relay(g, p)
			if target < 0:
				g._note("Every Relay is already punched.", "info", p.index)
				return {}
			_teleport(g, p, target, false)
			return {"land_again": true}
		10:  # Tax Refund
			p.cash += roundi(g.lot_worth(p) * 0.05)
		11:  # Swap Meet
			var mine: int = pick[0]
			var theirs: int = pick[1]
			var rival := g.players[g.lots[theirs].owner]
			var diff := g.lot_value(theirs) - g.lot_value(mine)
			if diff > 0:
				g.charge(p, diff, rival.index)
			if not p.broke:
				g.lots[mine].owner = rival.index
				g.lots[theirs].owner = p.index
				g._note("%s swaps %s for %s's %s" % [p.name, g._label(mine), rival.name,
						g._label(theirs)], "own", p.index, theirs)
		12:  # Charity
			var rich: PlayerState = null
			var poor: PlayerState = null
			for q in g.players:
				if q.broke:
					continue
				if rich == null or g.net_worth(q) > g.net_worth(rich):
					rich = q
				if poor == null or g.net_worth(q) < g.net_worth(poor):
					poor = q
			if rich != poor:
				g._note("%s gives 100 to %s" % [rich.name, poor.name], "info", rich.index)
				g.charge(rich, 100, poor.index)
		13:  # Back to Base
			_teleport(g, p, g.board.depot, true)
			return {"land_again": true}
		14:  # Free Renovation
			g.lots[pick].tier += 1
			g.bond_pressure.erase(g.space(pick).block)
			g._note("%s becomes a %s" % [g._label(pick), GameState.TIER_NAMES[g.lots[pick].tier]],
					"own", p.index, pick)
		15:  # Pot Luck
			var half := g.pot / 2
			g.pot -= half
			p.cash += half
		16:  # Heavy Traffic
			p.skip_move = true
		17:  # Double Rent
			p.double_rent = true
		18:  # Market Tip
			var price := roundi(g.bond_price(pick) * MARKET_TIP_DISCOUNT)
			var count := mini(MARKET_TIP_BONDS, p.cash / maxi(price, 1))
			if count > 0:
				p.cash -= price * count
				p.bonds[pick] = p.bonds_in(pick) + count
				g._note("%s buys %d %s bonds at %d" % [p.name, count, g.board.blocks[pick].name,
						price], "own", p.index)
		19:  # Scrap Tax
			var tax := roundi(p.cash * 0.1)
			if tax > 0:
				g.charge(p, tax, -1)
	return {}


## The CPU's pick for a card, or null to pass (only Swap Meet may be passed).
static func cpu_pick(g: GameState, p: PlayerState, id: int):
	var opts := choices(g, p, id)
	if opts.is_empty():
		return null
	match id:
		4:  # Grand Opening: the most valuable lot
			return _best(opts, func(lot): return g.lot_value(lot))
		5:  # Power Cut: the rival lot with the highest rent
			return _best(opts, func(lot): return g.rent(lot))
		7, 18:  # Bond Bump / Market Tip: where it owns most lots
			return _best(opts, func(b): return g.owned_in_block(p.index, b) * 10 + p.bonds_in(b))
		8:  # Bond Slump: hurt the block it has least stake in
			return _best(opts, func(b): return -p.bonds_in(b) * 10 - g.owned_in_block(p.index, b))
		11:  # Swap Meet: only if it strengthens a block it is building
			var best = null
			var gain := 0
			for pair in opts:
				var get_block: String = g.space(pair[1]).block
				var give_block: String = g.space(pair[0]).block
				var delta := g.owned_in_block(p.index, get_block) - g.owned_in_block(p.index, give_block) + 1
				if get_block != give_block and delta > gain:
					gain = delta
					best = pair
			return best
		14:  # Free Renovation: the dearest base price
			return _best(opts, func(lot): return g.space(lot).price)
	return opts[0]


static func _best(opts: Array, score: Callable):
	var best = opts[0]
	for o in opts:
		if score.call(o) > score.call(best):
			best = o
	return best


static func _nearest_unpunched_relay(g: GameState, p: PlayerState) -> int:
	var targets: Array[int] = []
	for r in g.board.relay_ids():
		if r not in p.punches:
			targets.append(r)
	if targets.is_empty():
		return -1
	# Walk forward from the current space and take the first one reached.
	var seen := {p.position: true}
	var queue: Array[int] = [p.position]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		for n in g.space(id).next:
			if n in targets:
				return n
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return targets[0]


## Moves straight to `to`; entering it applies its pass effect (relay punch, or
## Depot salary when `salary`), but nothing on the way.
static func _teleport(g: GameState, p: PlayerState, to: int, salary: bool) -> void:
	p.came_from = -1
	p.position = to
	g._note("%s jumps to %s" % [p.name, g._label(to)], "info", p.index, to)
	if g.space(to).type != "depot" or salary:
		g._pass(p, to)
