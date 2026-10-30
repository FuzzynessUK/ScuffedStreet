class_name GameState
extends RefCounted
## The whole game's rules and state, with no UI. Rules are in docs/DESIGN.md.
##
## A controller (UI, CPU or network host) drives a turn:
##   start_turn() -> roll() -> options()/step() until moves run out -> land()
##   -> act on the returned offers (buy_lot, invest, buy_bonds, ...) -> end_turn()
## Everything that happens is appended to `events` as
## {text, kind, player, space}; kind is info, gain, loss, own, relay, card,
## payday (which also carries "amount") or win.

const DIE_SIDES := 4  # a roll is two of these dice added up

## A lot's building is named by the capital invested in it, as a share of its
## base price: a Shack below 0.6, a Shop from 0.6, a Store from 1.6, and a
## Megamart once it is full (MAX_CAPITAL).
const TIER_NAMES := ["Shack", "Shop", "Store", "Megamart"]
const TIER_AT := [0.0, 0.6, 1.6, 3.2]
const MAX_TIER := 3
const MAX_CAPITAL := 3.2  # most capital a lot takes, x its base price
const RENT_MIN := 0.10  # rent = value x this with nothing invested,
const RENT_MAX := 0.24  # rising evenly to this at full capital
const INVEST_LIMIT := 1.0  # most capital one lot takes in a turn, x its base price
const WHOLE_BLOCK_LIMIT := 2.0  # that limit's multiplier when one player owns the block
const WHOLE_BLOCK_VALUE := 1.25  # lot values in a block one player owns outright
const MAX_ANY_SUITS := 2  # Any Suit cards a player may hold at once
const COMMISSION_RATE := 0.2  # Star space: share of others' profits, paid by the bank
const TOLL_RATE := 0.08
const BANK_SELL_RATE := 0.7
const DIVIDEND_RATE := 0.01
const BOND_DIVISOR := 40.0
const MIN_BOND_PRICE := 5
const MAX_BOND_TRADE := 20
const BIG_BOND_TRADE := 10
const BOND_PRESSURE := 0.10
const HEAP_COLS := 8
const HEAP_ROWS := 8
const PATCH_BONUS := 40  # per card in the patch beyond the first

var board: Board
var players: Array[PlayerState] = []
var lots := {}           # lot space id -> {owner, capital: G invested, boost: float, blackout: bool}
var invested := {}       # lot id -> capital put in this turn (INVEST_LIMIT)
var bond_pressure := {}  # block id -> price multiplier until its value next changes
var bond_round_start := {}  # block id -> bond price when this round began
var current := 0
var turn := 1
var moves_left := 0
var winner := -1
var game_over := false
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var heap: Array[int] = []        # Scrap Heap: the Wildcard id in each slot
var heap_owner: Array[int] = []  # who took each slot, -1 while face down
## When true a human left owing (negative cash) stays that way until
## settle_debt(), so the UI can let them choose which bonds to sell. CPUs, and
## everyone while this is false, settle at once.
var defer_debts := false
## Lots sold back to the bank waiting to be auctioned: [{"lot", "seller"}].
## The UI (or the sim) runs them; see Auction.
var pending_auctions: Array[Dictionary] = []
var plots := {}  # plot space id -> Plots.new_plot() (see Plots)


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
	invested.clear()
	bond_pressure.clear()
	pending_auctions.clear()
	plots.clear()
	for s in board.spaces:
		if s.type == "plot":
			plots[s.id] = Plots.new_plot()
	_refill_heap()
	snapshot_bond_prices()
	current = 0
	turn = 1
	winner = -1
	game_over = false
	events.clear()


# --- values -------------------------------------------------------------

func space(id: int) -> Dictionary:
	return board.spaces[id]


## Every G invested adds a G of value; a whole block adds WHOLE_BLOCK_VALUE on top.
func lot_value(id: int) -> int:
	var lot: Dictionary = lots[id]
	var whole := WHOLE_BLOCK_VALUE if whole_block_owner(space(id).block) >= 0 else 1.0
	return roundi((space(id).price + lot.capital) * lot.boost * whole)


## The building's tier (TIER_NAMES), from the capital invested.
func tier(id: int) -> int:
	var t := 0
	for i in TIER_AT.size():
		if lots[id].capital >= roundi(space(id).price * TIER_AT[i]):
			t = i
	return t


## The player who owns every lot in the block, or -1.
func whole_block_owner(block: String) -> int:
	var owner := -2
	for id in board.lots_in_block(block):
		if owner == -2:
			owner = lots[id].owner
		elif lots[id].owner != owner:
			return -1
	return maxi(-1, owner)


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
	if lot.owner < 0 or lot.blackout or players[lot.owner].on_break:
		return 0
	return roundi(lot_value(id) * rent_rate(id) * block_multiplier(id))


## Rent as a share of value: RENT_MIN empty, rising evenly to RENT_MAX when full.
func rent_rate(id: int) -> float:
	var full: float = space(id).price * MAX_CAPITAL
	return lerpf(RENT_MIN, RENT_MAX, clampf(lots[id].capital / full, 0.0, 1.0))


## The owner's share of the lot's block: lots they own in it / lots in it.
## For a lot for sale, the share one lot of the block would be.
func block_share(id: int) -> float:
	var block: String = space(id).block
	var size := board.lots_in_block(block).size()
	var owner: int = lots[id].owner
	return (owned_in_block(owner, block) if owner >= 0 else 1) / float(size)


## Max capital: how much more the lot can take. Its room is MAX_CAPITAL x
## base scaled by the owner's share of the block, so one lot of three can only
## grow to a Shop, two to a Store, and only the whole block makes a Megamart.
func max_capital(id: int) -> int:
	return maxi(0, roundi(space(id).price * MAX_CAPITAL * block_share(id)) - lots[id].capital)


## The most that can be invested in the lot now: what is left of this turn's
## limit (INVEST_LIMIT x base x the owner's share of the block, doubled with
## the whole block), up to max capital.
func invest_limit(id: int) -> int:
	var limit: float = space(id).price * INVEST_LIMIT * block_share(id)
	var owner: int = lots[id].owner
	if owner >= 0 and whole_block_owner(space(id).block) == owner:
		limit *= WHOLE_BLOCK_LIMIT
	return clampi(roundi(limit) - invested.get(id, 0), 0, max_capital(id))


## Whether p has a lot that can take any investment now.
func can_invest(p: PlayerState) -> bool:
	for id in lots:
		if lots[id].owner == p.index and invest_limit(id) > 0:
			return true
	return false


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
	return p.cash + lot_worth(p) + bond_worth(p) + Plots.worth(self, p)


## What p's bonds would fetch at today's prices.
func bond_worth(p: PlayerState) -> int:
	var v := 0
	for block in p.bonds:
		v += p.bonds[block] * bond_price(block)
	return v


## Whether p can pay `cost` from cash plus the bonds they could sell.
func can_cover(p: PlayerState, cost: int) -> bool:
	return p.cash + bond_worth(p) >= cost


## Gives p an Any Suit card ("P1 <verb> an Any Suit card<where>"), unless they
## already hold MAX_ANY_SUITS. Returns whether it did.
func give_any_suit(p: PlayerState, verb: String, where := "") -> bool:
	if p.any_suits >= MAX_ANY_SUITS:
		_note("%s %s an Any Suit card%s, but already holds the most allowed (%d)" % [p.name,
				verb, where, MAX_ANY_SUITS], "info", p.index)
		return false
	p.any_suits += 1
	_note("%s %s an Any Suit card%s (%d held)" % [p.name, verb, where, p.any_suits], "gain", p.index)
	return true


## Every suit, counting held Any Suit cards in for missing ones.
func has_all_suits(p: PlayerState) -> bool:
	return suit_count(p) >= board.relay_ids().size()


## Suits p holds for PAYDAY: punched Relays plus Any Suit cards, up to four.
func suit_count(p: PlayerState) -> int:
	return mini(p.punches.size() + p.any_suits, board.relay_ids().size())


## Any Suit cards a PAYDAY would spend now: only the ones filling missing suits.
func any_suits_needed(p: PlayerState) -> int:
	return maxi(0, board.relay_ids().size() - p.punches.size())


func salary(p: PlayerState) -> int:
	return board.base_salary + suit_count(p) * board.relay_bonus + roundi(lot_worth(p) * 0.05)


## What a PAYDAY pays p (every suit held by then), for previewing a route.
func payday_amount(p: PlayerState) -> int:
	return board.base_salary + board.relay_ids().size() * board.relay_bonus \
			+ roundi(lot_worth(p) * 0.05)


# --- turn flow ----------------------------------------------------------

func current_player() -> PlayerState:
	return players[current]


func start_turn() -> void:
	var p := current_player()
	p.at_goal = net_worth(p) >= board.goal
	invested.clear()
	if p.commission:
		p.commission = false
		_note("%s's commission ends" % p.name, "info", current)
	if p.on_break:
		p.on_break = false
		_note("%s's lots open again" % p.name, "info", current)
	for id in lots:
		if lots[id].owner == p.index:
			lots[id].blackout = false
	_note("Turn %d: %s (net worth %d G)" % [turn, p.name, net_worth(p)], "info", current)
	p.reverse_move = p.reverse_next
	p.reverse_first = p.reverse_next
	p.reverse_next = false
	if p.reverse_move:
		_note("%s walks backwards this turn!" % p.name, "loss", current)


## Rolls 2d4 and sets the moves to walk.
func roll() -> int:
	moves_left = rng.randi_range(1, DIE_SIDES) + rng.randi_range(1, DIE_SIDES)
	_note("%s rolls %d" % [current_player().name, moves_left], "info", current)
	return moves_left


## Spaces the current player may step to next (backwards this turn after a
## Reverse Gear or U-Turn).
func options() -> Array[int]:
	var p := current_player()
	return options_from(p.position, p.came_from, p.reverse_move, p.reverse_first)


## Spaces reachable in one step from `at` having arrived from `came_from`
## (used to plan a route before committing to it). `backwards`: walking the
## board in reverse, along the links that lead *to* `at`; on the move's
## `first` step that means turning round (anything but the way on), after it
## anything but straight back.
func options_from(at: int, came_from: int, backwards := false, first := false) -> Array[int]:
	if backwards:
		var ahead: Array[int] = []
		if first:
			ahead = options_from(at, came_from)
		var back: Array[int] = []
		for s in board.spaces:
			if at in s.next and not (s.id in ahead if first else s.id == came_from):
				back.append(s.id)
		if not back.is_empty():
			return back
	var out: Array[int] = []
	for n in space(at).next:
		if n != came_from:
			out.append(n)
	if out.is_empty():
		out.assign(space(at).next)
	return out


## Moves p straight to `to` (Scrap Slots' Warp). Arriving counts as entering
## the space (a suit, a PAYDAY); the caller then resolves the landing.
func warp(p: PlayerState, to: int) -> void:
	p.came_from = -1
	for s in board.spaces:
		if to in s.next:
			p.came_from = s.id  # face on along the board from there
			break
	p.position = to
	_note("%s warps to %s" % [p.name, _label(to)], "info", p.index, to)
	_pass(p, to)


## Moves the current player one space and applies pass-through effects.
func step(to: int) -> void:
	assert(to in options(), "illegal step")
	var p := current_player()
	p.came_from = p.position
	p.position = to
	moves_left -= 1
	p.reverse_first = false
	_pass(p, to)


## Pass effects apply on every space entered, including the final one.
func _pass(p: PlayerState, id: int) -> void:
	match space(id).type:
		"depot":
			# PAYDAY only with every suit; otherwise the Depot pays nothing and
			# the suits collected so far are kept. The bank takes only the Any
			# Suit cards that filled a gap: with four real suits it takes none.
			if has_all_suits(p):
				var pay := salary(p)
				p.cash += pay
				var used := any_suits_needed(p)
				_note("PAYDAY! %s collects %d G salary" % [p.name, pay], "payday", p.index, id)
				events[-1]["amount"] = pay
				_commission(p, pay)
				if used > 0:
					p.any_suits -= used
					_note("%s hands in %d Any Suit card%s" % [p.name, used, "" if used == 1 else "s"],
							"info", p.index, id)
				p.punches.clear()
				p.level += 1
				_note("%s reaches level %d" % [p.name, p.level], "info", p.index, id)
			else:
				_note("%s has %d of %d suits: no PAYDAY yet" % [p.name, suit_count(p),
						board.relay_ids().size()], "info", p.index, id)
			if p.at_goal:
				winner = p.index
				game_over = true
				_note("%s reaches the Depot at goal and wins!" % p.name, "win", p.index, id)
		"relay":
			if id not in p.punches:
				p.punches.append(id)
				_note("%s collects the %s" % [p.name, _label(id)], "relay", p.index, id)
		"plot":
			Plots.on_pass(self, p, id)  # a rival's Toll Bridge takes its toll


## Resolves the space the current player stopped on. Automatic effects happen
## here; choices come back as offers, e.g. {"kind": "buy", "lot": 5, "cost": 200}.
func land() -> Array[Dictionary]:
	var p := current_player()
	var id := p.position
	var s := space(id)
	var offers: Array[Dictionary] = []
	match s.type:
		"depot":
			offers.append({"kind": "market"})
		"relay", "wildcard":
			offers.append({"kind": "wildcard"})
		"lot":
			var lot: Dictionary = lots[id]
			if lot.owner < 0:
				offers.append({"kind": "buy", "lot": id, "cost": lot_value(id)})
			elif lot.owner == p.index:
				# Landing on any of your own lots: invest in any lot you own.
				if can_invest(p):
					offers.append({"kind": "invest", "lot": id, "rate": 1.0})
			else:
				pay_rent(p, id)
				if not game_over and lots[id].owner >= 0 and tier(id) < MAX_TIER:
					offers.append({"kind": "buyout", "lot": id, "cost": lot_value(id) * 2,
							"owner": lots[id].owner})
		"market":
			offers.append({"kind": "market"})
		"workshop":
			if can_invest(p):
				offers.append({"kind": "invest", "lot": -1, "rate": 0.8})
		"toll":
			var fee := roundi(p.cash * TOLL_RATE)
			if fee > 0:
				charge(p, fee, -1)
				_note("%s pays %d G toll" % [p.name, fee], "loss", p.index, id)
		"dice":
			offers.append({"kind": "reroll"})
			_note("%s lands on a Dice space and rolls again" % p.name, "info", p.index, id)
		"arcade":
			offers.append({"kind": "minigame"})
		"plot":
			offers.append_array(Plots.on_land(self, p, id))
		"interest":
			p.commission = true
			_note("%s Receives %d%% commission until their next turn" % [
					p.name, roundi(COMMISSION_RATE * 100)], "gain", p.index, id)
		"break":
			p.on_break = true
			_note("%s's Shops are closed for the day" % p.name,
					"break", p.index, id)
		"detour":
			p.came_from = id
			p.position = s.pair
			_note("%s takes the detour to %s" % [p.name, _label(s.pair)], "info", p.index, s.pair)
	return offers


func end_turn() -> void:
	if game_over:
		return
	current_player().reverse_move = false
	var n := players.size()
	for i in n:
		current = (current + 1) % n
		if current == 0:
			turn += 1
			snapshot_bond_prices()
		if not players[current].broke:
			return


# --- actions ------------------------------------------------------------

func buy_lot(p: PlayerState, id: int) -> bool:
	var lot: Dictionary = lots[id]
	var cost := lot_value(id)
	if lot.owner >= 0 or not can_cover(p, cost):
		return false
	p.cash -= cost
	lot.owner = p.index
	_note("%s buys %s for %d G" % [p.name, _label(id), cost], "own", p.index, id)
	_sound("purchase")
	_owe(p, -1)
	return true


## What investing `amount` costs at `rate` (1.0, or a Workshop / Repair Shop discount).
static func invest_cost(amount: int, rate: float) -> int:
	return roundi(amount * rate)


## Puts `amount` of capital into p's lot `id` (up to invest_limit), paying
## invest_cost(amount, rate). The lot's value, rent and bond price go up.
func invest(p: PlayerState, id: int, amount: int, rate := 1.0) -> bool:
	var lot: Dictionary = lots[id]
	var cost := invest_cost(amount, rate)
	if lot.owner != p.index or amount <= 0 or amount > invest_limit(id) or not can_cover(p, cost):
		return false
	p.cash -= cost
	add_capital(id, amount)
	invested[id] = invested.get(id, 0) + amount
	_note("%s invests %d G in %s (now a %s worth %d G)%s" % [p.name, amount, _label(id),
			TIER_NAMES[tier(id)], lot_value(id), "" if cost == amount else " for %d G" % cost],
			"own", p.index, id)
	_sound("build")
	_owe(p, -1)
	return true


## Adds capital to a lot (up to max capital) without paying for it.
func add_capital(id: int, amount: int) -> void:
	lots[id].capital += mini(amount, max_capital(id))
	bond_pressure.erase(space(id).block)


func buyout(p: PlayerState, id: int) -> bool:
	var lot: Dictionary = lots[id]
	var cost := lot_value(id) * 2
	if lot.owner < 0 or lot.owner == p.index or tier(id) >= MAX_TIER or not can_cover(p, cost):
		return false
	var seller := players[lot.owner]
	p.cash -= cost
	seller.cash += cost
	lot.owner = p.index
	_note("%s buys %s out from %s for %d G" % [p.name, _label(id), seller.name, cost], "own", p.index, id)
	_sound("takeover")
	_owe(p, seller.index)
	return true


func pay_rent(p: PlayerState, id: int) -> void:
	var amount := rent(id)
	if amount <= 0:
		return
	var owner := players[lots[id].owner]
	if owner.double_rent:
		amount *= 2
		owner.double_rent = false
	_note("%s pays %d G rent to %s" % [p.name, amount, owner.name], "loss", p.index, id)
	charge(p, amount, owner.index)
	_commission(owner, amount)
	var block: String = space(id).block
	for q in players:
		var held := q.bonds_in(block)
		if held > 0:
			var div := roundi(amount * DIVIDEND_RATE * held)
			if div > 0:
				_note("%s earns %d G in dividends" % [q.name, div], "gain", q.index)
				earn(q, div)


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
	_note("%s buys %d Block %s bonds at %d G" % [p.name, count, board.blocks[block].name, price], "own", p.index)
	_sound("bond_buy")
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
	_note("%s sells %d Block %s bonds at %d G" % [p.name, count, board.blocks[block].name, price], "info", p.index)
	_sound("bond_sell")
	return true


## Takes `amount` from p and gives it to player index `to`, or -1 the bank.
## Cash may go negative; see _owe for how the debt is then settled.
func charge(p: PlayerState, amount: int, to: int) -> void:
	p.cash -= amount
	if to >= 0:
		players[to].cash += amount
	_owe(p, to)


## After a payment: a negative balance is settled now, or left for the UI
## (defer_debts, human players) to call settle_debt() once bonds are sold.
func _owe(p: PlayerState, to: int) -> void:
	if p.cash >= 0:
		return
	p.creditor = to
	if not defer_debts or p.is_cpu:
		settle_debt(p)


## Clears a negative balance by selling (raise_cash). If that still falls
## short, the creditor hands back what was never really paid and p is broke.
func settle_debt(p: PlayerState) -> void:
	if p.cash >= 0:
		return
	raise_cash(p, -p.cash)
	if p.cash >= 0:
		return
	var unpaid := -p.cash
	if p.creditor >= 0:
		players[p.creditor].cash -= unpaid
	p.cash = 0
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
		raised += sell_lot_to_bank(p, id)


## Gives p `amount` of profit (salary, rent, dividends, prizes...); every
## other player holding a commission gets their share on top (_commission).
func earn(p: PlayerState, amount: int) -> void:
	p.cash += amount
	_commission(p, amount)


## Pays every other player on a commission (the Star space) COMMISSION_RATE
## of `earner`'s profit, from the bank; the earner keeps all of theirs.
func _commission(earner: PlayerState, amount: int) -> void:
	if amount <= 0:
		return
	for q in players:
		if q != earner and q.commission and not q.broke:
			var cut := roundi(amount * COMMISSION_RATE)
			if cut > 0:
				q.cash += cut
				_note("%s gets %d G commission on %s's profit" % [q.name, cut, earner.name], "gain",
						q.index)


## What the bank pays for lot `id`: BANK_SELL_RATE of its value.
func bank_price(id: int) -> int:
	return roundi(lot_value(id) * BANK_SELL_RATE)


## Sells p's lot `id` back to the bank for `rate` times its value (Fire Sale:
## twice); it becomes unowned with no building and goes to auction. Returns
## the G paid (0 if it is not p's).
func sell_lot_to_bank(p: PlayerState, id: int, rate := BANK_SELL_RATE) -> int:
	if lots[id].owner != p.index:
		return 0
	var price := roundi(lot_value(id) * rate)
	p.cash += price
	lots[id] = _new_lot()
	bond_pressure.erase(space(id).block)
	_note("%s sells %s to the bank for %d G" % [p.name, _label(id), price], "loss", p.index, id)
	pending_auctions.append({"lot": id, "seller": p.index})
	return price


## A trade: player a gives lots `a_lots` and `a_g` G to player b, who gives
## `b_lots` and `b_g` G back. Lots keep their buildings. Each side may offer G
## up to their cash plus bonds (as at an auction); one left owing then sells
## bonds (_owe). Nothing happens (and false comes back) unless every lot
## belongs to its giver and both can cover their G.
func trade(a: PlayerState, b: PlayerState, a_lots: Array, a_g: int, b_lots: Array,
		b_g: int) -> bool:
	if a == b or a_g < 0 or b_g < 0 or not can_cover(a, a_g) or not can_cover(b, b_g):
		return false
	if a_lots.is_empty() and b_lots.is_empty() and a_g == 0 and b_g == 0:
		return false
	for id in a_lots:
		if not lots.has(id) or lots[id].owner != a.index:
			return false
	for id in b_lots:
		if not lots.has(id) or lots[id].owner != b.index:
			return false
	for id in a_lots:
		lots[id].owner = b.index
	for id in b_lots:
		lots[id].owner = a.index
	a.cash += b_g - a_g
	b.cash += a_g - b_g
	_note("%s trades with %s: gives %s, gets %s" % [a.name, b.name,
			_trade_text(a_lots, a_g), _trade_text(b_lots, b_g)], "own", a.index)
	_owe(a, b.index)
	_owe(b, a.index)
	return true


## A side of a trade in words: "Nut Bar, Cog Cafe and 100 G", or "nothing".
func _trade_text(ids: Array, g: int) -> String:
	var parts := PackedStringArray()
	for id in ids:
		parts.append(_label(id))
	if g > 0:
		parts.append("%d G" % g)
	if parts.is_empty():
		return "nothing"
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


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


## Tags the last event with a sound for the UI to play (see Sfx): "purchase"
## (buying a lot, an auction win), "takeover" (buying out a rival's lot),
## "build" (investing, building), "bond_buy" or "bond_sell".
func _sound(name: String) -> void:
	events[-1]["sound"] = name


func _new_lot() -> Dictionary:
	return {"owner": -1, "capital": 0, "boost": 1.0, "blackout": false}


# --- Scrap Heap -----------------------------------------------------------
# A HEAP_COLS x HEAP_ROWS grid of face-down Wildcards drawn from the pool:
# the cards in Wildcards.COPIES that many times, the rest all different, so
# each new table brings a fresh mix. A taken slot keeps its card and records
# who took it; lining up with your own earlier cards (across or down) pays a
# patch bonus. The heap reshuffles once every slot is taken.

func _refill_heap() -> void:
	var deck: Array[int] = []
	for id in Wildcards.COPIES:
		for i in Wildcards.COPIES[id]:
			deck.append(id)
	var pool: Array[int] = []
	for i in Wildcards.CARDS.size():
		if not Wildcards.COPIES.has(i):
			pool.append(i)
	while deck.size() < HEAP_COLS * HEAP_ROWS and not pool.is_empty():
		deck.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	while deck.size() < HEAP_COLS * HEAP_ROWS:  # a pool smaller than the table repeats
		deck.append(rng.randi_range(0, Wildcards.CARDS.size() - 1))
	for i in range(deck.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := deck[i]
		deck[i] = deck[j]
		deck[j] = t
	heap = deck
	heap_owner.clear()
	heap_owner.resize(deck.size())
	heap_owner.fill(-1)


## The current player takes the card in `slot`, earning any patch bonus.
func take_from_heap(slot: int) -> int:
	assert(heap_owner[slot] < 0, "slot already taken")
	var p := current_player()
	var id := heap[slot]
	heap_owner[slot] = p.index
	_note("%s turns over a card in the Scrap Heap" % p.name, "info", current)
	var bonus := patch_bonus(patch_size(slot, p.index))
	if bonus > 0:
		earn(p, bonus)
		_note("%s's patch of %d cards pays %d G" % [p.name, patch_size(slot, p.index), bonus],
				"gain", p.index)
	if heap_slots_left().is_empty():
		_refill_heap()
		_note("The Scrap Heap is reshuffled", "info")
	return id


func heap_slots_left() -> Array[int]:
	var out: Array[int] = []
	for i in heap_owner.size():
		if heap_owner[i] < 0:
			out.append(i)
	return out


func patch_bonus(size: int) -> int:
	return PATCH_BONUS * maxi(0, size - 1)


## Size of the patch `slot` belongs to (or would join) for `owner`: a straight
## line of their cards through the slot, across or down, whichever is longer
## (an L or a cross counts only its longest straight line).
func patch_size(slot: int, owner: int) -> int:
	return patch_slots(slot, owner).size()


## The slots in that patch, `slot` first.
func patch_slots(slot: int, owner: int) -> Array[int]:
	var across := _heap_line(slot, owner, 1)
	var down := _heap_line(slot, owner, HEAP_COLS)
	return down if down.size() > across.size() else across


## `slot` and the owner's cards running from it both ways in steps of `dx`
## (1 across, HEAP_COLS down), stopping at the grid edge.
func _heap_line(slot: int, owner: int, dx: int) -> Array[int]:
	var out: Array[int] = [slot]
	for dir in [-dx, dx]:
		var s := slot
		while true:
			var n: int = s + dir
			if n < 0 or n >= heap_owner.size() or (dx == 1 and n / HEAP_COLS != s / HEAP_COLS):
				break
			if heap_owner[n] != owner:
				break
			out.append(n)
			s = n
	return out


## Heavy Traffic: true (and cleared) if the current player loses this move.
func take_skip() -> bool:
	var p := current_player()
	if not p.skip_move:
		return false
	p.skip_move = false
	_note("%s is stuck in traffic and doesn't move" % p.name, "loss", p.index, p.position)
	return true


# --- bond prices over time --------------------------------------------------

func snapshot_bond_prices() -> void:
	for block in board.blocks:
		bond_round_start[block] = bond_price(block)


## How far the block's bond price has moved since this round began.
func bond_change(block: String) -> int:
	return bond_price(block) - bond_round_start.get(block, bond_price(block))


func bonds_held(block: String) -> int:
	var n := 0
	for q in players:
		n += q.bonds_in(block)
	return n
