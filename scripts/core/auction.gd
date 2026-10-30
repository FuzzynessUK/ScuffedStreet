class_name Auction
extends RefCounted
## Lot auctions (docs/DESIGN.md, "Auctions"). A lot sold back to the bank
## (from the turn menu, or to pay off a debt) is auctioned to everyone else.
## Bidding opens at the lot's value, goes up STEP at a time, and is limited by
## a bidder's total money (cash plus bonds). The winner pays from cash, selling
## bonds if they must (a charge to the bank, so debts work as usual).

const STEP := 10
const TIMER := 5.0  # seconds without a new bid before the hammer falls


## Who may bid: everyone still in except the seller.
static func bidders(g: GameState, seller: int) -> Array[int]:
	var out: Array[int] = []
	for q in g.players:
		if not q.broke and q.index != seller:
			out.append(q.index)
	return out


## Where bidding opens: the lot's value as it is now (no building).
static func start_price(g: GameState, id: int) -> int:
	return g.lot_value(id)


## The most player p could pay: cash plus bonds at today's prices.
static func total_money(g: GameState, p: PlayerState) -> int:
	return maxi(0, p.cash) + g.bond_worth(p)


## The next bid: the opening price, or STEP more than the current one.
static func next_bid(g: GameState, id: int, bid: int) -> int:
	return start_price(g, id) if bid <= 0 else bid + STEP


## The most CPU p will bid: around the lot's value (more for a block it is
## building), never so much that it falls below half its cash reserve.
static func cpu_limit(g: GameState, p: PlayerState, id: int) -> int:
	var block: String = g.space(id).block
	var keen := 1.25 if g.owned_in_block(p.index, block) > 0 else 1.0
	var want := roundi(g.lot_value(id) * keen * g.rng.randf_range(0.9, 1.2))
	return mini(want, total_money(g, p) - Cpu.reserve(g, p) / 2)


## The lot goes to `winner` for `price`: charged to the bank, so a human may
## be left owing (and sells bonds), a CPU settles at once.
static func settle(g: GameState, winner: PlayerState, id: int, price: int) -> void:
	g.lots[id].owner = winner.index
	g._note("%s wins the auction for %s at %d G" % [winner.name, g._label(id), price], "own",
			winner.index, id)
	g._sound("purchase")
	g.charge(winner, price, -1)


## An auction with no human in it (the sim, and all-CPU bidding): the CPU with
## the highest limit wins at one STEP over the next highest (or the opening
## price), as live bidding would end. Returns the winner's index or -1.
static func resolve_cpu(g: GameState, id: int, seller: int) -> int:
	var start := start_price(g, id)
	var best := -1
	var top := -1
	var second := -1
	for i in bidders(g, seller):
		var limit := cpu_limit(g, g.players[i], id)
		if limit < start:
			continue
		if limit > top:
			second = top
			top = limit
			best = i
		elif limit > second:
			second = limit
	if best < 0:
		g._note("No one bids on %s; it stays on sale" % g._label(id), "info", -1, id)
		return -1
	var price := start if second < start else mini(top, second + STEP)
	settle(g, g.players[best], id, price)
	return best
