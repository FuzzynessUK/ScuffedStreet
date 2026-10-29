class_name Cpu
extends RefCounted
## Simple rule-driven computer player (docs/DESIGN.md, "Computer players").


## Cash a CPU tries to keep in hand to survive rent.
static func reserve(g: GameState, p: PlayerState) -> int:
	var worst := 0
	for id in g.lots:
		if g.lots[id].owner >= 0 and g.lots[id].owner != p.index:
			worst = maxi(worst, g.rent(id))
	return 300 + roundi(worst * 0.5)


static func wants_buy(g: GameState, p: PlayerState, cost: int) -> bool:
	return p.cash - cost >= reserve(g, p)


static func wants_renovate(g: GameState, p: PlayerState, cost: int) -> bool:
	return p.cash - cost >= reserve(g, p) * 3 / 2


static func wants_buyout(g: GameState, p: PlayerState, id: int, cost: int) -> bool:
	var block: String = g.space(id).block
	var completes := g.owned_in_block(p.index, block) + 1 == g.board.lots_in_block(block).size()
	return completes and p.cash - cost >= reserve(g, p) * 2


## Picks the branch closest to the Depot when at goal, else to an unpunched Relay.
static func pick_branch(g: GameState, p: PlayerState, opts: Array[int]) -> int:
	var targets: Array[int] = []
	if p.at_goal:
		targets.append(g.board.depot)
	else:
		for r in g.board.relay_ids():
			if r not in p.punches:
				targets.append(r)
		if targets.is_empty():
			targets.append(g.board.depot)
	var best := opts[0]
	var best_dist := 1 << 30
	for o in opts:
		var d := distance(g.board, o, targets)
		if d < best_dist:
			best_dist = d
			best = o
	return best


## Steps from `from` to the nearest of `targets` following `next` links.
static func distance(b: Board, from: int, targets: Array[int]) -> int:
	var seen := {from: 0}
	var queue: Array[int] = [from]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if id in targets:
			return seen[id]
		for n in b.spaces[id].next:
			if not seen.has(n):
				seen[n] = seen[id] + 1
				queue.append(n)
	return 1 << 30


## One market visit: buy bonds in the block it owns most of, sell when short.
static func trade(g: GameState, p: PlayerState) -> void:
	var res := reserve(g, p)
	if p.cash < res:
		for block in p.bonds.keys():
			g.sell_bonds(p, block, p.bonds_in(block))
		return
	var best_block := ""
	var best_held := 0
	for block in g.board.blocks:
		var held := g.owned_in_block(p.index, block)
		if held > best_held:
			best_held = held
			best_block = block
	if best_block == "":
		return
	var price := g.bond_price(best_block)
	var count := mini(GameState.MAX_BOND_TRADE, (p.cash - res * 2) / price)
	if count >= 1:
		g.buy_bonds(p, best_block, count)


## Scrap Heap slot: the one that makes its biggest patch (random among ties).
static func pick_heap_slot(g: GameState, p: PlayerState) -> int:
	var best: Array[int] = []
	var best_size := 0
	for s in g.heap_slots_left():
		var size := g.patch_size(s, p.index)
		if size > best_size:
			best_size = size
			best = [s]
		elif size == best_size:
			best.append(s)
	return best[g.rng.randi() % best.size()]
