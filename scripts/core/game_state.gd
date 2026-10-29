class_name GameState
extends RefCounted
## The whole game's rules and state, with no UI. Rules are in docs/DESIGN.md.
##
## A controller (UI, CPU or network host) drives a turn:
##   start_turn() -> roll() -> options()/step() until moves run out -> land()
##   -> act on the returned offers (buy_lot, renovate, buy_bonds, ...) -> end_turn()
## Everything that happens is appended to `events` as
## {text, kind, player, space}; kind is info, gain, loss, own, relay or win.

const TIER_NAMES := ["Shack", "Shop", "Store", "Megamart"]
const TIER_VALUE := [1.0, 1.6, 2.6, 4.2]   # value = base price x this
const TIER_RENT := [0.10, 0.14, 0.18, 0.24] # rent = value x this
const TIER_COST := [0.0, 0.6, 1.0, 1.6]    # cost to reach tier i = base x this
const MAX_TIER := 3
const RELAY_LAND_BONUS := 50
const TOLL_RATE := 0.08
const BANK_SELL_RATE := 0.7
const DIVIDEND_RATE := 0.01
const BOND_DIVISOR := 40.0
const MIN_BOND_PRICE := 5
const MAX_BOND_TRADE := 20
const BIG_BOND_TRADE := 10
const BOND_PRESSURE := 0.10

var board: Board
var players: Array[PlayerState] = []
var lots := {}           # lot space id -> {owner, tier, boost: float, blackout: bool}
var bond_pressure := {}  # block id -> price multiplier until its value next changes
var pot := 0
var current := 0
var turn := 1
var moves_left := 0
var winner := -1
var game_over := false
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var heap: Array[int] = []  # Scrap Heap: a Wildcard id per slot, -1 once taken


func setup(p_board: Board, names: Array, cpu: Array = [], seed := -1) -> void:
	board = p_board
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	players.clear()
	for i in names.size():
		var p := PlayerState.new()
		p.index = i
		p.name = str(names[i])
		p.is_cpu = i < cpu.size() and cpu[i]
		p.cash = board.start_cash
		p.position = board.depot
		players.append(p)
	lots.clear()
	for id in board.lot_ids():
		lots[id] = _new_lot()
	bond_pressure.clear()
	pot = 0
	_refill_heap()
	current = 0
	turn = 1
	winner = -1
	game_over = false
	events.clear()


# --- values -------------------------------------------------------------

func space(id: int) -> Dictionary:
	return board.spaces[id]


func lot_value(id: int) -> int:
	var lot: Dictionary = lots[id]
	return roundi(space(id).price * TIER_VALUE[lot.tier] * lot.boost)


func owned_in_block(owner: int, block: String) -> int:
	var n := 0
	for id in board.lots_in_block(block):
		if lots[id].owner == owner:
			n += 1
	return n


## Rent multiplier for the owner's share of the lot's block.
func block_multiplier(id: int) -> float:
	var owner: int = lots[id].owner
	if owner < 0:
		return 1.0
	var block: String = space(id).block
	var total := board.lots_in_block(block).size()
	var held := owned_in_block(owner, block)
	if held == total:
		return 3.0
	if total >= 3 and held == total - 1:
		return 2.0
	if held * 2 >= total:
		return 1.5
	return 1.0


func rent(id: int) -> int:
	var lot: Dictionary = lots[id]
	if lot.owner < 0 or lot.blackout:
		return 0
	return roundi(lot_value(id) * TIER_RENT[lot.tier] * block_multiplier(id))


## Cost to take the lot up one tier, or -1 if it is already at the top.
func renovate_cost(id: int) -> int:
	var lot: Dictionary = lots[id]
	if lot.tier >= MAX_TIER:
		return -1
	var cost: float = space(id).price * TIER_COST[lot.tier + 1]
	var block: String = space(id).block
	if lot.owner >= 0 and owned_in_block(lot.owner, block) == board.lots_in_block(block).size():
		cost *= 0.75
	return roundi(cost)


func block_value(block: String) -> int:
	var v := 0
	for id in board.lots_in_block(block):
		v += lot_value(id)
	return v


func bond_price(block: String) -> int:
	var price: float = block_value(block) / BOND_DIVISOR * bond_pressure.get(block, 1.0)
	return maxi(MIN_BOND_PRICE, roundi(price))


func lot_worth(p: PlayerState) -> int:
	var v := 0
	for id in lots:
		if lots[id].owner == p.index:
			v += lot_value(id)
	return v


func net_worth(p: PlayerState) -> int:
	var v := p.cash + lot_worth(p)
	for block in p.bonds:
		v += p.bonds[block] * bond_price(block)
	return v


func salary(p: PlayerState) -> int:
	return board.base_salary + p.punches.size() * board.relay_bonus + roundi(lot_worth(p) * 0.05)


# --- turn flow ----------------------------------------------------------

func current_player() -> PlayerState:
	return players[current]


func start_turn() -> void:
	var p := current_player()
	p.at_goal = net_worth(p) >= board.goal
	for id in lots:
		if lots[id].owner == p.index:
			lots[id].blackout = false
	_note("Turn %d: %s (net worth %d)" % [turn, p.name, net_worth(p)], "info", current)


## Rolls 2d4 and sets the moves to walk.
func roll() -> int:
	moves_left = rng.randi_range(1, 4) + rng.randi_range(1, 4)
	_note("%s rolls %d" % [current_player().name, moves_left], "info", current)
	return moves_left


## Spaces the current player may step to next.
func options() -> Array[int]:
	var p := current_player()
	var out: Array[int] = []
	for n in space(p.position).next:
		if n != p.came_from:
			out.append(n)
	if out.is_empty():
		out.assign(space(p.position).next)
	return out


## Moves the current player one space and applies pass-through effects.
func step(to: int) -> void:
	assert(to in options(), "illegal step")
	var p := current_player()
	p.came_from = p.position
	p.position = to
	moves_left -= 1
	_pass(p, to)


## Pass effects apply on every space entered, including the final one.
func _pass(p: PlayerState, id: int) -> void:
	match space(id).type:
		"depot":
			var pay := salary(p)
			p.cash += pay
			_note("%s collects %d salary (%d relays)" % [p.name, pay, p.punches.size()], "gain", p.index, id)
			p.punches.clear()
			if p.at_goal:
				winner = p.index
				game_over = true
				_note("%s reaches the Depot at goal and wins!" % p.name, "win", p.index, id)
		"relay":
			if id not in p.punches:
				p.punches.append(id)
				_note("%s collects the %s" % [p.name, _label(id)], "relay", p.index, id)


## Resolves the space the current player stopped on. Automatic effects happen
## here; choices come back as offers, e.g. {"kind": "buy", "lot": 5, "cost": 200}.
func land() -> Array[Dictionary]:
	var p := current_player()
	var id := p.position
	var s := space(id)
	var offers: Array[Dictionary] = []
	match s.type:
		"relay":
			p.cash += RELAY_LAND_BONUS
			_note("%s lands on %s: +%d" % [p.name, _label(id), RELAY_LAND_BONUS], "gain", p.index, id)
		"lot":
			var lot: Dictionary = lots[id]
			if lot.owner < 0:
				offers.append({"kind": "buy", "lot": id, "cost": lot_value(id)})
			elif lot.owner == p.index:
				var cost := renovate_cost(id)
				if cost > 0:
					offers.append({"kind": "renovate", "lot": id, "cost": cost})
			else:
				pay_rent(p, id)
				if not game_over and lots[id].owner >= 0 and lots[id].tier < MAX_TIER:
					offers.append({"kind": "buyout", "lot": id, "cost": lot_value(id) * 2,
							"owner": lots[id].owner})
		"market":
			offers.append({"kind": "market"})
		"workshop":
			for lot_id in lots:
				if lots[lot_id].owner == p.index and renovate_cost(lot_id) > 0:
					offers.append({"kind": "renovate", "lot": lot_id,
							"cost": roundi(renovate_cost(lot_id) * 0.8)})
		"toll":
			var fee := roundi(p.cash * TOLL_RATE)
			if fee > 0:
				charge(p, fee, -2)
				_note("%s pays %d toll into the Pot" % [p.name, fee], "loss", p.index, id)
		"jackpot":
			_note("%s takes the Pot: %d" % [p.name, pot], "gain", p.index, id)
			p.cash += pot
			pot = 0
		"detour":
			p.came_from = id
			p.position = s.pair
			_note("%s takes the detour to %s" % [p.name, _label(s.pair)], "info", p.index, s.pair)
		"wildcard":
			offers.append({"kind": "wildcard"})
	return offers


func end_turn() -> void:
	if game_over:
		return
	var n := players.size()
	for i in n:
		current = (current + 1) % n
		if current == 0:
			turn += 1
		if not players[current].broke:
			return


# --- actions ------------------------------------------------------------

func buy_lot(p: PlayerState, id: int) -> bool:
	var lot: Dictionary = lots[id]
	var cost := lot_value(id)
	if lot.owner >= 0 or p.cash < cost:
		return false
	p.cash -= cost
	lot.owner = p.index
	_note("%s buys %s for %d" % [p.name, _label(id), cost], "own", p.index, id)
	return true


## Renovates by one tier at `cost` (pass the offer's cost; workshop prices differ).
func renovate(p: PlayerState, id: int, cost: int) -> bool:
	var lot: Dictionary = lots[id]
	if lot.owner != p.index or lot.tier >= MAX_TIER or p.cash < cost:
		return false
	p.cash -= cost
	lot.tier += 1
	bond_pressure.erase(space(id).block)
	_note("%s renovates %s to a %s for %d" % [p.name, _label(id), TIER_NAMES[lot.tier], cost], "own", p.index, id)
	return true


func buyout(p: PlayerState, id: int) -> bool:
	var lot: Dictionary = lots[id]
	var cost := lot_value(id) * 2
	if lot.owner < 0 or lot.owner == p.index or lot.tier >= MAX_TIER or p.cash < cost:
		return false
	var seller := players[lot.owner]
	p.cash -= cost
	seller.cash += cost
	lot.owner = p.index
	_note("%s buys %s out from %s for %d" % [p.name, _label(id), seller.name, cost], "own", p.index, id)
	return true


func pay_rent(p: PlayerState, id: int) -> void:
	var amount := rent(id)
	if amount <= 0:
		return
	var owner := players[lots[id].owner]
	if owner.double_rent:
		amount *= 2
		owner.double_rent = false
	_note("%s pays %d rent to %s" % [p.name, amount, owner.name], "loss", p.index, id)
	charge(p, amount, owner.index)
	var block: String = space(id).block
	for q in players:
		var held := q.bonds_in(block)
		if held > 0:
			var div := roundi(amount * DIVIDEND_RATE * held)
			if div > 0:
				q.cash += div
				_note("%s earns %d in dividends" % [q.name, div], "gain", q.index)


func buy_bonds(p: PlayerState, block: String, count: int) -> bool:
	if count <= 0 or count > MAX_BOND_TRADE:
		return false
	var price := bond_price(block)
	if p.cash < price * count:
		return false
	p.cash -= price * count
	p.bonds[block] = p.bonds_in(block) + count
	if count >= BIG_BOND_TRADE:
		bond_pressure[block] = bond_pressure.get(block, 1.0) * (1.0 + BOND_PRESSURE)
	_note("%s buys %d %s bonds at %d" % [p.name, count, board.blocks[block].name, price], "own", p.index)
	return true


func sell_bonds(p: PlayerState, block: String, count: int) -> bool:
	if count <= 0 or count > p.bonds_in(block):
		return false
	var price := bond_price(block)
	p.cash += price * count
	p.bonds[block] = p.bonds_in(block) - count
	if p.bonds[block] == 0:
		p.bonds.erase(block)
	if count >= BIG_BOND_TRADE:
		bond_pressure[block] = bond_pressure.get(block, 1.0) * (1.0 - BOND_PRESSURE)
	_note("%s sells %d %s bonds at %d" % [p.name, count, board.blocks[block].name, price], "info", p.index)
	return true


## Takes `amount` from p and gives it to player index `to`, or -1 bank, -2 pot.
## Raises cash by selling if needed; a player who still can't pay goes broke.
func charge(p: PlayerState, amount: int, to: int) -> void:
	if p.cash < amount:
		raise_cash(p, amount - p.cash)
	var paid := mini(amount, p.cash)
	p.cash -= paid
	if to >= 0:
		players[to].cash += paid
	elif to == -2:
		pot += paid
	if paid < amount:
		_go_broke(p)


## Default liquidation: bonds first, then cheapest lots to the bank at 70%.
## (The UI can offer the player a choice later; this is the fallback and CPU rule.)
func raise_cash(p: PlayerState, needed: int) -> void:
	var raised := 0
	for block in p.bonds.keys():
		if raised >= needed:
			return
		var before := p.cash
		sell_bonds(p, block, p.bonds_in(block))
		raised += p.cash - before
	var owned: Array = lots.keys().filter(func(id): return lots[id].owner == p.index)
	owned.sort_custom(func(a, b): return lot_value(a) < lot_value(b))
	for id in owned:
		if raised >= needed:
			return
		var price := roundi(lot_value(id) * BANK_SELL_RATE)
		p.cash += price
		raised += price
		lots[id] = _new_lot()
		bond_pressure.erase(space(id).block)
		_note("%s sells %s to the bank for %d" % [p.name, _label(id), price], "loss", p.index, id)


func _go_broke(p: PlayerState) -> void:
	p.broke = true
	game_over = true
	var best := -1
	for q in players:
		if not q.broke and (best < 0 or net_worth(q) > net_worth(players[best])):
			best = q.index
	winner = best
	_note("%s is broke! %s wins with the highest net worth." % [p.name,
			players[best].name if best >= 0 else "Nobody"], "win", best)


# --- helpers ------------------------------------------------------------

func _label(id: int) -> String:
	var s := space(id)
	return s.name if s.name != "" else "%s %d" % [s.type, id]


func _note(text: String, kind := "info", player := -1, at := -1) -> void:
	events.append({"text": text, "kind": kind, "player": player, "space": at})


func _new_lot() -> Dictionary:
	return {"owner": -1, "tier": 0, "boost": 1.0, "blackout": false}


# --- Scrap Heap -----------------------------------------------------------

func _refill_heap() -> void:
	heap.clear()
	for i in Wildcards.CARDS.size():
		heap.append(i)
	for i in range(heap.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := heap[i]
		heap[i] = heap[j]
		heap[j] = t


## Takes the card in `slot`; the heap refills once every card has been taken.
func take_from_heap(slot: int) -> int:
	var id := heap[slot]
	assert(id >= 0, "slot already taken")
	heap[slot] = -1
	_note("%s turns over card %d of the Scrap Heap" % [current_player().name, slot + 1],
			"info", current)
	if heap.all(func(c): return c < 0):
		_refill_heap()
		_note("The Scrap Heap is reshuffled", "info")
	return id


func heap_slots_left() -> Array[int]:
	var out: Array[int] = []
	for i in heap.size():
		if heap[i] >= 0:
			out.append(i)
	return out


## Heavy Traffic: true (and cleared) if the current player loses this move.
func take_skip() -> bool:
	var p := current_player()
	if not p.skip_move:
		return false
	p.skip_move = false
	_note("%s is stuck in traffic and doesn't move" % p.name, "loss", p.index, p.position)
	return true
