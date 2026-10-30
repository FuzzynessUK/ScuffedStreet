class_name Plots
extends RefCounted
## Building plots (docs/DESIGN.md, "Building plots"). A plot is an empty space
## until someone lands on it and builds: one building per plot, BUILD_COST
## each. Rivals then pay when they land (a Toll Bridge also when they pass),
## and the owner gets the building's own perk when they land.
##
## To add a building: an entry in KINDS (and ORDER), then its rival charge in
## rival_charge() and its owner perk in on_land().

const BUILD_COST := 200

## name, short name for the tile, icon, and one line on what it does
const KINDS := {
	"bridge": {"name": "Toll Bridge", "short": "BRIDGE", "icon": "⇆",
		"line": "Rivals pay a toll passing (+10 G each time) · you empty the jar"},
	"airport": {"name": "Airport", "short": "AIRPORT", "icon": "✈",
		"line": "Rivals pay 50 G · you fly anywhere free"},
	"tax": {"name": "Tax Office", "short": "TAX", "icon": "%",
		"line": "Rivals pay 10% of net worth · you get a 5% bonus"},
	"repair": {"name": "Repair Shop", "short": "REPAIR", "icon": "⚒",
		"line": "Rivals pay 50 G · you invest at half price"},
	"centre": {"name": "Shopping Centre", "short": "CENTRE", "icon": "⌂",
		"line": "Rivals pay 100 G, up to 2000 G · you expand it"},
}
const ORDER := ["bridge", "airport", "tax", "repair", "centre"]

const TOLL_START := 20      # Toll Bridge: the first toll...
const TOLL_STEP := 10       # ...and how much it rises each time a rival pays
const AIRPORT_FEE := 50
const TAX_RATE := 0.10      # of a rival's net worth
const TAX_BONUS := 0.05     # of the owner's own net worth
const REPAIR_FEE := 50
const REPAIR_DISCOUNT := 0.5
const CENTRE_FEES := [100, 500, 1000, 2000]  # by level 0-3
const CENTRE_COSTS := [300, 500, 1000]       # to expand from level 0, 1, 2


static func new_plot() -> Dictionary:
	return {"owner": -1, "kind": "", "jar": 0, "toll": TOLL_START, "level": 0, "worth": 0}


static func name_of(g: GameState, id: int) -> String:
	var kind: String = g.plots[id].kind
	return KINDS[kind].name if kind != "" else "Empty plot"


## Builds `kind` on empty plot `id` for p (cash, or bonds if short, as for a lot).
static func build(g: GameState, p: PlayerState, id: int, kind: String) -> bool:
	var plot: Dictionary = g.plots[id]
	if plot.owner >= 0 or not KINDS.has(kind) or not g.can_cover(p, BUILD_COST):
		return false
	plot.owner = p.index
	plot.kind = kind
	plot.worth = BUILD_COST
	p.cash -= BUILD_COST
	g._note("%s builds a %s for %d G" % [p.name, KINDS[kind].name, BUILD_COST], "own", p.index, id)
	g._sound("build")
	g._owe(p, -1)
	return true


## What a rival landing on plot `id` pays now (a Toll Bridge's toll is taken
## on passing, so it shows here only for the sign).
static func rival_charge(g: GameState, id: int, payer: PlayerState) -> int:
	var plot: Dictionary = g.plots[id]
	match plot.kind:
		"bridge":
			return plot.toll
		"airport":
			return AIRPORT_FEE
		"tax":
			return roundi(maxi(0, g.net_worth(payer)) * TAX_RATE) if payer else 0
		"repair":
			return REPAIR_FEE
		"centre":
			return CENTRE_FEES[plot.level]
	return 0


## Passing (or landing on) a rival's Toll Bridge: the toll goes into its jar,
## and the next toll is TOLL_STEP higher.
static func on_pass(g: GameState, p: PlayerState, id: int) -> void:
	var plot: Dictionary = g.plots[id]
	if plot.kind != "bridge" or plot.owner < 0 or plot.owner == p.index or p.broke:
		return
	var toll: int = plot.toll
	g._note("%s pays a %d G toll at %s's Toll Bridge" % [p.name, toll,
			g.players[plot.owner].name], "loss", p.index, id)
	g.charge(p, toll, -1)
	plot.jar += toll
	plot.toll += TOLL_STEP


## Landing on plot `id`: build on an empty one, pay a rival's, or use your own.
## Returns offers for the UI (build, fly, expand, invest).
static func on_land(g: GameState, p: PlayerState, id: int) -> Array[Dictionary]:
	var plot: Dictionary = g.plots[id]
	var offers: Array[Dictionary] = []
	if plot.owner < 0:
		offers.append({"kind": "build", "plot": id, "cost": BUILD_COST})
		return offers
	if plot.owner != p.index:
		if plot.kind != "bridge":  # the toll was taken as they arrived
			var owner := g.players[plot.owner]
			var amount := rival_charge(g, id, p)
			if amount > 0:
				g._note("%s pays %d G at %s's %s" % [p.name, amount, owner.name, KINDS[plot.kind].name],
						"loss", p.index, id)
				g.charge(p, amount, owner.index)
				g._commission(owner, amount)
		return offers
	match plot.kind:
		"bridge":
			if plot.jar > 0:
				g._note("%s empties the Toll Bridge jar: %d G" % [p.name, plot.jar], "gain", p.index, id)
				g.earn(p, plot.jar)
				plot.jar = 0
		"airport":
			offers.append({"kind": "fly", "plot": id})
		"tax":
			var bonus := roundi(maxi(0, g.net_worth(p)) * TAX_BONUS)
			if bonus > 0:
				g._note("%s's Tax Office pays a %d G bonus" % [p.name, bonus], "gain", p.index, id)
				g.earn(p, bonus)
		"repair":
			if g.can_invest(p):
				offers.append({"kind": "invest", "lot": -1, "rate": REPAIR_DISCOUNT})
	# Landing on any of your own plots lets you expand any of your Shopping
	# Centres, wherever they are on the board.
	for other in g.plots:
		var c: Dictionary = g.plots[other]
		if c.owner == p.index and c.kind == "centre" and c.level < CENTRE_COSTS.size():
			offers.append({"kind": "expand", "plot": other, "cost": CENTRE_COSTS[c.level]})
	return offers


## Expands p's Shopping Centre one level (its fee goes up).
static func expand(g: GameState, p: PlayerState, id: int) -> bool:
	var plot: Dictionary = g.plots[id]
	if plot.owner != p.index or plot.kind != "centre" or plot.level >= CENTRE_COSTS.size():
		return false
	var cost: int = CENTRE_COSTS[plot.level]
	if not g.can_cover(p, cost):
		return false
	p.cash -= cost
	plot.level += 1
	plot.worth += cost
	g._note("%s expands the Shopping Centre: its fee is now %d G" % [p.name,
			CENTRE_FEES[plot.level]], "own", p.index, id)
	g._sound("build")
	g._owe(p, -1)
	return true


## What p's plots count for in net worth: what was spent on them.
static func worth(g: GameState, p: PlayerState) -> int:
	var v := 0
	for id in g.plots:
		if g.plots[id].owner == p.index:
			v += g.plots[id].worth
	return v


## Where an Airport can fly to: every space but lots and plots (and the airport).
static func fly_targets(g: GameState, from: int) -> Array[int]:
	var out: Array[int] = []
	for s in g.board.spaces:
		if s.type != "lot" and s.type != "plot" and s.id != from:
			out.append(s.id)
	return out


# --- CPUs ----------------------------------------------------------------

## What a CPU builds on an empty plot (building is compulsory when it can
## pay, with bonds if need be): picked at random, "" if it cannot pay at all.
static func cpu_build(g: GameState, p: PlayerState) -> String:
	if not g.can_cover(p, BUILD_COST):
		return ""
	return ORDER[g.rng.randi_range(0, ORDER.size() - 1)]


static func cpu_expands(g: GameState, p: PlayerState, cost: int) -> bool:
	return p.cash - cost >= Cpu.reserve(g, p)


## Where a CPU flies: the Depot with every suit, else a suit it still needs.
static func cpu_fly(g: GameState, p: PlayerState) -> int:
	return Minigames.cpu_warp(g, p)
