extends SceneTree
## Headless rules tests. Run:
##   godot --headless --path . -s tests/test_core.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_board_loads()
	test_all_boards()
	test_board_validation()
	test_rent_and_blocks()
	test_renovation()
	test_salary_and_relays()
	test_branching()
	test_bonds()
	test_bankruptcy()
	test_deferred_debt()
	test_goal_win()
	test_wildcards()
	test_card_pool()
	test_board_cards()
	test_minigames()
	test_pick_a_card()
	test_chance_wheel()
	test_critter_race()
	test_race_pick_order()
	test_selling_and_trading()
	test_auctions()
	test_star_and_moon()
	test_plots()
	test_plot_rules()
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: " + what)


func new_game(n := 2) -> GameState:
	var g := GameState.new()
	var names := []
	for i in n:
		names.append("P%d" % (i + 1))
	g.setup(Board.load_file("res://boards/scrapyard_loop.json"), names, [], 1)
	return g


func test_board_loads() -> void:
	var b := Board.load_file("res://boards/scrapyard_loop.json")
	check(b != null, "board loads")
	check(b.spaces.size() == 33, "33 spaces")
	check(b.depot == 0, "depot is space 0")
	check(b.relay_ids().size() == 4, "four relays")
	check(b.spaces[9].mark == "Heart", "relay suit loaded")
	check(b.lots_in_block("F").size() == 4, "block F has four lots")


func test_board_validation() -> void:
	var b := Board.new()
	check(b.load_data({"spaces": [{"id": 0, "type": "lot", "next": [0]}]}) != "",
			"lot without block rejected")
	b = Board.new()
	check(b.load_data({"spaces": [{"id": 0, "type": "relay", "next": [0]}]}) == "no depot",
			"missing depot rejected")
	b = Board.new()
	check(b.load_data({"spaces": [{"id": 0, "type": "depot", "next": [5]}]}) != "",
			"dangling next rejected")


func test_rent_and_blocks() -> void:
	var g := new_game()
	var p := g.players[0]
	# Block A = 1, 2, 3 (120, 140, 160).
	g.buy_lot(p, 1)
	check(g.rent(1) == 12, "one lot: 10% of 120")
	g.buy_lot(p, 2)
	check(is_equal_approx(g.block_multiplier(1), 2.0), "2 of 3 = all but one, x2")
	check(g.rent(1) == 24, "x2 rent")
	g.buy_lot(p, 3)
	check(is_equal_approx(g.block_multiplier(1), 3.0), "whole block x3")
	# Block F has 4 lots: 2 of 4 = half.
	g.buy_lot(p, 26)
	g.buy_lot(p, 27)
	check(is_equal_approx(g.block_multiplier(26), 1.5), "2 of 4 = half, x1.5")


func test_renovation() -> void:
	var g := new_game()
	var p := g.players[0]
	# Block B has 3 lots (5, 6, 8); lot 5's base price is 200. What a lot can
	# take grows with the owner's share of its block.
	g.buy_lot(p, 5)
	check(g.max_capital(5) == 213, "1 of 3: room for a third of 3.2 x base")
	check(g.invest_limit(5) == 67, "1 of 3: a turn's limit is a third of the base")
	check(not g.invest(p, 5, 68), "no more than the limit")
	var bond := g.bond_price("B")
	var cash := p.cash
	check(g.invest(p, 5, 60) and p.cash == cash - 60, "invest 60 G")
	check(g.lot_value(5) == 260 and g.tier(5) == 0, "each G adds a G of value; still a Shack")
	check(g.rent(5) == roundi(260 * lerpf(0.10, 0.24, 60.0 / 640)), "rent rate rises with capital")
	check(g.invest_limit(5) == 7, "what is left of this turn's limit")
	g.invest(p, 5, 7)
	check(g.bond_price("B") > bond, "investing raises the block's bond price")
	g.start_turn()
	check(g.invest_limit(5) == 67, "a new turn, a new limit")
	g.buy_lot(p, 6)
	check(g.max_capital(5) == 427 - 67 and g.invest_limit(5) == 133, "2 of 3: more room, a bigger limit")
	var value := g.lot_value(5)
	g.buy_lot(p, 8)
	check(g.whole_block_owner("B") == p.index, "whole block")
	check(g.lot_value(5) == roundi(value * 1.25), "whole block: values x1.25")
	check(g.invest_limit(5) == 400, "whole block: the limit doubles")
	check(g.invest(p, 5, 400) and g.max_capital(5) == 640 - 467, "up to max capital")
	check(g.invest_limit(5) == 0, "limit used up")
	g.start_turn()
	check(g.invest_limit(5) == 173 and g.invest(p, 5, 173) and g.tier(5) == 3, "full: a Megamart")
	check(g.invest_limit(5) == 0, "nothing more fits")
	p.position = 6
	check(g.land().any(func(o): return o.kind == "invest"), "landing on your own lot offers investing")
	check(not g.invest(p, 5, 10, 0.5), "still capped at a Megamart")
	check(g.invest(p, 6, 100, 0.5) and GameState.invest_cost(100, 0.5) == 50, "discounts halve the cost")
	# One lot of a block can never grow past a Shop.
	var h := new_game()
	var q := h.players[0]
	h.buy_lot(q, 5)
	for i in 10:
		h.start_turn()
		h.invest(q, 5, h.invest_limit(5))
	check(h.tier(5) == 1 and h.max_capital(5) == 0, "a lone lot stops at a Shop")


func test_salary_and_relays() -> void:
	var g := new_game()
	var p := g.players[0]
	g.start_turn()
	check(g.salary(p) == 200, "base salary")
	p.position = 3
	p.came_from = 2
	g.moves_left = 1
	g.step(4)
	check(p.punches == [4], "relay punched on entry")
	check(g.land().any(func(o): return o.kind == "wildcard"), "landing on a suit opens the Scrap Heap")
	p.position = 25
	p.came_from = 24
	p.punches.append(24)
	var before := p.cash
	g.step(0)
	check(p.cash == before, "no PAYDAY without every suit")
	check(p.punches.size() == 2, "suits are kept when there is no PAYDAY")
	p.punches.append(9)
	p.punches.append(17)
	p.position = 25
	p.came_from = 24
	before = p.cash
	g.step(0)
	check(p.cash == before + 200 + 4 * g.board.relay_bonus, "PAYDAY with all four suits")
	check(p.punches.is_empty(), "suits reset after PAYDAY")
	check(g.land().any(func(o): return o.kind == "market"), "landing on the Depot opens the market")

	# Any Suit cards: one fills the gap of a 3-suit lap and is spent, the other
	# is kept; one held with all four real suits is kept too.
	p.punches.assign([4, 9, 17])
	p.any_suits = 2
	p.position = 25
	p.came_from = 24
	before = p.cash
	g.step(0)
	check(p.cash == before + 200 + 4 * g.board.relay_bonus, "Any Suit cards complete a PAYDAY")
	check(p.any_suits == 1, "only the cards filling a gap are spent")
	p.punches.assign([4, 9, 17, 24])
	p.position = 25
	p.came_from = 24
	g.step(0)
	check(p.any_suits == 1, "with all four suits the bank leaves the card")
	Wildcards.apply(g, p, Wildcards.ANY_SUIT)
	check(p.any_suits == 2, "drawing Any Suit keeps it")
	# Two at most, however they are won.
	Wildcards.apply(g, p, Wildcards.ANY_SUIT)
	Minigames.apply_prize(g, p, {"kind": "card"})
	Minigames.wheel_apply(g, p, p.index, 2)
	check(p.any_suits == GameState.MAX_ANY_SUITS, "no more than %d Any Suit cards" % GameState.MAX_ANY_SUITS)

	# Dice spaces: two on the board, landing on one rolls again.
	var dice: Array = g.board.spaces.filter(func(s): return s.type == "dice")
	check(dice.size() == 2, "two Dice spaces on the board")
	p.position = dice[0].id
	check(g.land().any(func(o): return o.kind == "reroll"), "a Dice space rolls again")


func test_branching() -> void:
	var g := new_game()
	var p := g.players[0]
	p.position = 11
	p.came_from = 10
	check(g.options() == [12, 26], "junction offers both ways")
	p.position = 32
	p.came_from = 31
	check(g.options() == [23], "shortcut rejoins at 23")


func test_bonds() -> void:
	var g := new_game()
	var p := g.players[0]
	var q := g.players[1]
	g.buy_lot(p, 26)
	var price := g.bond_price("F")
	check(price == maxi(5, roundi(1650 / 40.0)), "bond price from block value")
	check(g.buy_bonds(q, "F", 10), "buy 10 bonds")
	check(g.bond_price("F") > price, "big purchase raises the price")
	var before := q.cash
	g.pay_rent(q, 26)
	check(q.cash == before - g.rent(26) + roundi(g.rent(26) * 0.01 * 10),
			"rent paid minus dividend")


func test_bankruptcy() -> void:
	var g := new_game()
	var p := g.players[0]
	var q := g.players[1]
	g.buy_lot(p, 1)
	p.cash = 10
	g.charge(p, 50, q.index)
	check(g.lots[1].owner == -1, "lot sold to bank")
	check(p.cash == 10 + 84 - 50, "sold at 70%")
	check(not p.broke, "survived")
	var q_before := q.cash
	g.charge(p, 1000, q.index)
	check(p.broke and g.game_over and g.winner == 1, "broke ends the game")
	check(q.cash == q_before + 44 and p.cash == 0, "creditor keeps only what was paid")

	# With more players the richest survivor wins, not the creditor.
	g = new_game(3)
	p = g.players[0]
	g.players[2].cash = 5000
	g.charge(p, 9000, 1)
	check(p.broke and g.game_over and g.winner == 2, "richest survivor wins")


func test_deferred_debt() -> void:
	var g := new_game()
	g.defer_debts = true
	var p := g.players[0]
	var q := g.players[1]
	g.buy_bonds(p, "A", 20)
	var worth := g.bond_worth(p)
	p.cash = 20
	check(g.can_cover(p, 20 + worth) and not g.can_cover(p, 21 + worth), "bonds count towards cover")
	g.charge(p, 50, q.index)
	check(p.cash == -30 and p.bonds_in("A") == 20 and q.cash == 1550, "debt left for the player")
	g.sell_bonds(p, "A", 5)
	g.settle_debt(p)
	check(p.cash >= 0 and p.bonds_in("A") == 15 and not p.broke, "sold bonds clear the debt")
	check(g.buy_lot(p, 1), "a lot can be bought on bonds")
	check(p.cash < 0 and g.lots[1].owner == 0, "buying leaves a debt to sell bonds for")
	g.settle_debt(p)
	check(p.cash >= 0 and not p.broke, "settling sells the rest")


func test_goal_win() -> void:
	var g := new_game()
	var p := g.players[0]
	p.cash = 9000
	g.start_turn()
	check(p.at_goal, "at goal at turn start")
	p.position = 25
	p.came_from = 24
	g.moves_left = 3
	g.step(0)
	check(g.game_over and g.winner == 0, "passing depot at goal wins")


func test_wildcards() -> void:
	var g := new_game()
	var p := g.players[0]
	var q := g.players[1]

	# Bond Bump / Slump: the block is a random draw, the same for CPUs, and
	# every block can come up.
	check(Wildcards.card(7).pick == "slot" and Wildcards.card(8).pick == "slot", "Bump/Slump use the reel")
	var drawn := {}
	for i in 200:
		drawn[Wildcards.cpu_pick(g, p, 7)] = true
	check(drawn.size() == g.board.blocks.size(), "the reel can land on every block")

	var slots := GameState.HEAP_COLS * GameState.HEAP_ROWS
	check(g.heap.size() == slots and g.heap_slots_left().size() == slots, "heap starts full")
	var seen := {}
	for id in g.heap:
		seen[id] = true
	check(Wildcards.CARDS.size() == 135, "the pool has 135 cards")
	for id in Wildcards.ANY_SUITS:
		check(Wildcards.card(id).fx == "any_suit" and g.heap.has(id), "Any Suit no. %d is in every table" % (id + 1))
	check(Wildcards.ANY_SUITS == [20, 21, 22] and Wildcards.card(Wildcards.ARCADE_TICKET).name == "Arcade Ticket",
			"Any Suit is cards 21, 22 and 23")
	var copies := 0
	for id in Wildcards.COPIES:
		copies += Wildcards.COPIES[id] - 1
	check(seen.size() == slots - copies, "a table's cards are all different, bar the extra copies")
	g._refill_heap()
	var again := {}
	for id in g.heap:
		again[id] = true
	check(again.keys() != seen.keys(), "a new table brings a different mix")
	for id in Wildcards.COPIES:
		check(g.heap.count(id) >= Wildcards.COPIES[id], "%s at least %d times in the heap" % [
				Wildcards.card(id).name, Wildcards.COPIES[id]])

	# Patches: player 0 takes slot 0 then 1 (neighbours), then 9 (below 1:
	# an L, so only the straight 1-9 counts), then 17 (a column of three).
	var cash := p.cash
	g.take_from_heap(0)
	check(p.cash == cash, "a lone card pays nothing")
	g.take_from_heap(1)
	check(p.cash == cash + GameState.PATCH_BONUS, "patch of 2 pays one bonus")
	g.take_from_heap(GameState.HEAP_COLS + 1)
	check(p.cash == cash + GameState.PATCH_BONUS * 2, "an L counts only its straight line")
	g.take_from_heap(GameState.HEAP_COLS * 2 + 1)
	check(p.cash == cash + GameState.PATCH_BONUS * 4, "a column of 3 pays two")
	check(g.heap_owner[1] == 0, "slot remembers its taker")
	check(g.patch_size(GameState.HEAP_COLS + 2, 1) == 1, "another player's cards don't count")
	g.current = 1
	cash = q.cash
	g.take_from_heap(2)
	check(q.cash == cash, "touching a rival's patch pays nothing")
	g.current = 0
	while not g.heap_slots_left().is_empty() and g.heap_slots_left().size() < slots:
		g.take_from_heap(g.heap_slots_left()[0])
	check(g.heap_slots_left().size() == slots and g.heap_owner.all(func(o): return o < 0),
			"heap refills and clears colours when empty")
	p.cash = 1500
	q.cash = 1500


	g.buy_lot(q, 5)
	Wildcards.apply(g, p, 5, 5)  # Power Cut
	check(g.rent(5) == 0, "power cut: no rent")
	g.current = 1
	g.start_turn()
	check(g.rent(5) > 0, "power back on the owner's turn")

	Wildcards.apply(g, q, 17)  # Double Rent
	var before := q.cash
	var rent := g.rent(5)
	g.pay_rent(p, 5)
	check(q.cash == before + rent * 2, "double rent")
	check(not q.double_rent, "double rent used up")

	g.buy_lot(p, 1)
	check(Wildcards.choices(g, p, 11).has([1, 5]), "swap offers shack for shack")
	Wildcards.apply(g, p, 11, [1, 5])  # Swap Meet
	check(g.lots[5].owner == 0 and g.lots[1].owner == 1, "swap meet swaps owners")

	g.current = 0
	p.position = 10
	p.punches.assign(g.board.relay_ids())
	before = p.cash
	var r := Wildcards.apply(g, p, 13)  # Back to Base
	check(p.position == 0 and r.get("land_again", false), "back to base")
	check(p.cash > before, "back to base pays salary with every suit")

	p.position = 1
	p.punches.clear()
	Wildcards.apply(g, p, 9)  # Shortcut
	check(p.position == 4 and 4 in p.punches, "shortcut to the next relay")

	check(Wildcards.apply(g, p, 2).get("move_again", false), "rush hour moves again")
	Wildcards.apply(g, p, 16)
	check(g.take_skip() and not g.take_skip(), "heavy traffic skips once")
	check(Wildcards.choices(g, g.players[1], 14).size() > 0, "free renovation needs a lot")
	check(Wildcards.apply(g, p, 4).is_empty(), "picking card with no pick fizzles")


func test_minigames() -> void:
	var g := new_game()
	var p := g.players[0]

	# Arcade space and Arcade Ticket both start a minigame.
	var arcade: Array = g.board.spaces.filter(func(s): return s.type == "arcade")
	check(arcade.size() >= 1, "the board has an Arcade space")
	p.position = arcade[0].id
	check(g.land().any(func(o): return o.kind == "minigame"), "an Arcade space starts a minigame")
	check(Wildcards.apply(g, p, Wildcards.ARCADE_TICKET).get("minigame", false),
			"an Arcade Ticket starts a minigame")

	# Scrap Slots: a 3x3 grid, row by row (symbols: 0 Gold, 1 Bolt, 2 Warp,
	# 3 Bond, 4 Card). Only three in a line pays: rows, columns, diagonals.
	check(Minigames.SLOT_SYMBOLS.size() == 5, "five symbols, no Rust")
	var none := Minigames.slot_result([0, 1, 2, 3, 4, 0, 1, 2, 3])
	check(none.lines.is_empty() and none.cash == 0, "no line pays nothing")
	check(Minigames.slot_result([0, 0, 0, 1, 2, 3, 4, 3, 1]).cash == Minigames.SLOT_GOLD,
			"a row of Gold pays the jackpot")
	check(Minigames.slot_result([1, 2, 3, 1, 4, 0, 1, 0, 2]).cash == Minigames.SLOT_BOLT,
			"a column counts")
	check(Minigames.slot_result([4, 1, 2, 3, 4, 0, 0, 1, 4]).cards == 1, "a diagonal counts")
	check(Minigames.slot_result([1, 3, 2, 3, 2, 0, 2, 0, 1]).warp, "the other diagonal counts")
	check(Minigames.slot_result([0, 0, 1, 2, 3, 4, 3, 2, 1]).lines.is_empty(),
			"two in a row pays nothing")
	var two := Minigames.slot_result([1, 1, 1, 1, 2, 3, 1, 4, 0])
	check(two.lines.size() == 2 and two.cash == Minigames.SLOT_BOLT * 2, "every winning line pays")
	var all_bolts := Minigames.slot_result([1, 1, 1, 1, 1, 1, 1, 1, 1])
	check(all_bolts.lines.size() == 8, "a full grid makes all eight lines")
	var warps := Minigames.slot_result([2, 2, 2, 2, 2, 2, 0, 1, 3])
	check(warps.lines.size() == 2 and warps.warp, "two Warp lines still warp once")

	# Prizes are paid.
	var cash := p.cash
	Minigames.slot_apply(g, p, Minigames.slot_result([0, 0, 0, 1, 2, 3, 4, 3, 1]))
	check(p.cash == cash + Minigames.SLOT_GOLD, "jackpot paid")
	Minigames.slot_apply(g, p, Minigames.slot_result([3, 3, 3, 3, 1, 2, 3, 0, 1]), -1, "B")
	check(p.bonds_in("B") == Minigames.SLOT_BONDS * 2, "free bonds for each Bond line, in the chosen block")
	var cards := p.any_suits
	Minigames.slot_apply(g, p, Minigames.slot_result([4, 4, 4, 1, 2, 3, 3, 0, 1]))
	check(p.any_suits == cards + 1, "Any Suit card won")
	var relay: int = g.board.relay_ids()[1]
	var res := Minigames.slot_apply(g, p, Minigames.slot_result([2, 2, 2, 1, 3, 4, 3, 0, 1]), relay)
	check(p.position == relay and relay in p.punches and res.get("land_again", false),
			"Warp moves there, collects the suit and lands")
	check(relay in g.options_from(g.space(p.came_from).id, -1), "Warp faces along the board")

	# Odds: every symbol turns up, and a paying line comes up now and then.
	var seen := {}
	var paying := 0
	for i in 3000:
		var grid := Minigames.slot_row(g) + Minigames.slot_row(g) + Minigames.slot_row(g)
		for s in grid:
			seen[s] = true
		var r := Minigames.slot_result(grid)
		if r.cash > 0 or r.cards > 0 or r.bonds > 0 or r.warp:
			paying += 1
	check(seen.size() == Minigames.SLOT_SYMBOLS.size(), "every symbol can come up")
	check(paying > 600 and paying < 1500, "a paying line in %d of 3000 spins" % paying)


func test_pick_a_card() -> void:
	var g := new_game()
	var p := g.players[0]
	var n := Minigames.CARD_PRIZES.size()
	var deal := Minigames.card_deal(g)
	var sorted := deal.duplicate()
	sorted.sort()
	check(sorted == range(n), "the deal holds every prize once")
	# The deal back is a fresh draw: where the 300 G card was shown says
	# nothing about where it ends up, and every position can hold it.
	var ends := {}
	for i in 400:
		var shown := Minigames.card_deal(g)
		var order := Minigames.card_deal(g)
		if shown.find(0) == 0:
			ends[order.find(0)] = true
	check(ends.size() == n, "the 300 G card can end up anywhere, wherever it was shown")
	var picks := {}
	for i in 200:
		picks[Minigames.cpu_card(g)] = true
	check(picks.size() == n, "CPUs guess any card")

	var cash := p.cash
	Minigames.apply_prize(g, p, Minigames.CARD_PRIZES[0], null, "Pick a Card")
	check(p.cash == cash + Minigames.CARD_PRIZES[0].amount, "the top card pays")
	var games := {}
	for i in 100:
		games[Minigames.pick_minigame(g)] = true
	check(games.size() == Minigames.LIST.size(), "an Arcade can start every minigame")


func test_chance_wheel() -> void:
	var g := new_game(3)
	var p := g.players[0]
	var q := g.players[1]
	check(Minigames.wheel_players(g) == [0, 1, 2], "every player is on the wheel")
	g.players[2].broke = true
	check(Minigames.wheel_players(g) == [0, 1], "a bankrupt player is not")
	g.players[2].broke = false
	var who := {}
	var what := {}
	for i in 400:
		who[Minigames.wheel_player(g)] = true
		what[Minigames.wheel_action(g)] = true
	check(who.size() == 3 and what.size() == Minigames.WHEEL_ACTIONS.size(), "both wheels can land anywhere")

	var cash := q.cash
	Minigames.wheel_apply(g, p, q.index, 0)
	check(q.cash == cash + 300, "+300 G goes to the chosen player, not the thrower")
	Minigames.wheel_apply(g, p, q.index, 1)
	check(q.cash == cash + 100, "−200 G goes to the bank")
	# Bond actions: +5 in any block; −5 only from blocks they hold, all if fewer.
	var lose := 3
	var gain := 6
	check(Minigames.WHEEL_ACTIONS[lose].bonds == -5 and Minigames.WHEEL_ACTIONS[gain].bonds == 5,
			"the wheel has −5 and +5 bonds")
	check(Minigames.wheel_blocks(g, q.index, lose).is_empty(), "no block wheel with no bonds to lose")
	check(Minigames.wheel_blocks(g, q.index, gain).size() == g.board.blocks.size(),
			"+5 bonds can land on any block")
	check(Minigames.wheel_blocks(g, q.index, 0).is_empty(), "no block wheel for a G action")
	Minigames.wheel_apply(g, p, q.index, gain, "C")
	check(q.bonds_in("C") == 5, "+5 bonds in the block the wheel picked")
	q.bonds["D"] = 3
	check(Minigames.wheel_blocks(g, q.index, lose) == ["C", "D"], "−5 bonds only offers held blocks")
	Minigames.wheel_apply(g, p, q.index, lose, "D")
	check(q.bonds_in("D") == 0 and not q.bonds.has("D"), "fewer than 5 held: all of them go")
	Minigames.wheel_apply(g, p, q.index, lose, "C")
	check(q.bonds.is_empty(), "five held: all five go")
	Minigames.wheel_apply(g, p, q.index, 5)
	check(q.skip_move, "Skip a move")
	Minigames.wheel_apply(g, p, p.index, 2)
	check(p.any_suits == 1, "the thrower can land on themselves")


func test_critter_race() -> void:
	var g := new_game()
	var p := g.players[0]
	var plan := Minigames.race_plan(g)
	check(plan.size() == Minigames.RACERS.size(), "a plan for every racer")
	var ok := true
	for e in plan:
		var total: float = e.legs.reduce(func(a, b): return a + b, 0.0)
		ok = ok and absf(total - 1.0) < 0.001
		var last := -1.0
		for k in 50:
			var x := Minigames.race_progress(e, e.time * k / 49.0)
			ok = ok and x >= last - 0.0001 and x <= 1.0001
			last = x
		ok = ok and Minigames.race_progress(e, e.time) == 1.0 and Minigames.race_progress(e, 0.0) == 0.0
	check(ok, "every racer moves forward from start to finish")
	var order := Minigames.race_order(plan)
	check(plan[order[0]].time <= plan[order[1]].time and plan[order[2]].time <= plan[order[3]].time,
			"the order follows the finishing times")
	var wins := {}
	for i in 400:
		wins[Minigames.race_order(Minigames.race_plan(g))[0]] = true
	check(wins.size() == Minigames.RACERS.size(), "every animal can win")
	check(Minigames.race_prize(0, 1).amount == 200 and Minigames.race_prize(0, 2).amount == 200
			and Minigames.race_prize(0, 4).amount == 400,
			"1st pays 100 G x level, 200 G at level 1")
	check(Minigames.race_prize(1, 4).amount == 120 and Minigames.race_prize(2, 4).amount == 40,
			"2nd and 3rd are fixed")
	check(Minigames.race_prize(3, 4).kind == "none", "4th gets nothing")
	var cash := p.cash
	Minigames.apply_prize(g, p, Minigames.race_prize(1, p.level), null, "Critter Race")
	check(p.cash == cash + 120, "2nd place pays")

	# Level: 1 to start, +1 at every PAYDAY.
	check(p.level == 1, "everyone starts at level 1")
	p.punches.assign(g.board.relay_ids())
	p.position = 25
	p.came_from = 24
	g.current = 0
	g.moves_left = 1
	g.step(0)
	check(p.level == 2, "a PAYDAY raises the level")


func test_race_pick_order() -> void:
	var g := new_game(4)
	g.players[0].cash = 3000
	g.players[1].cash = 500
	g.players[2].cash = 1500
	g.players[3].cash = 500
	check(Minigames.race_pick_order(g) == [1, 3, 2, 0], "poorest picks first, ties by seat, leader last")
	g.players[1].broke = true
	check(Minigames.race_pick_order(g) == [3, 2, 0], "a bankrupt player does not pick")


func test_selling_and_trading() -> void:
	var g := new_game()
	var p := g.players[0]
	var q := g.players[1]
	g.buy_lot(p, 1)
	g.invest(p, 1, 100)
	var cash := p.cash
	var price := g.bank_price(1)
	check(g.sell_lot_to_bank(p, 1) == price and p.cash == cash + price, "a lot sells to the bank")
	check(g.lots[1].owner == -1 and g.lots[1].capital == 0, "it goes back on sale with no building")
	check(g.sell_lot_to_bank(p, 1) == 0, "you can only sell your own lots")

	# Trades: lots keep their buildings; G changes hands both ways.
	g.buy_lot(p, 2)
	g.lots[2].capital = 100  # a building on it
	g.buy_lot(q, 5)
	var pc := p.cash
	var qc := q.cash
	check(g.trade(p, q, [2], 50, [5], 0), "a trade goes through")
	check(g.lots[2].owner == q.index and g.lots[5].owner == p.index and g.lots[2].capital == 100,
			"lots swap owners and keep their buildings")
	check(p.cash == pc - 50 and q.cash == qc + 50, "G changes hands")
	check(not g.trade(p, q, [2], 0, [], 0), "you cannot trade away a lot you no longer own")
	check(not g.trade(p, q, [], p.cash + g.bond_worth(p) + 1, [], 0), "or more G than cash and bonds")
	check(not g.trade(p, q, [], 0, [], 0), "an empty trade is no trade")
	p.bonds["A"] = 10
	check(g.trade(p, q, [], p.cash + 20, [], 0) and p.cash >= 0 and p.bonds_in("A") == 0,
			"G past cash is covered by selling bonds")

	# CPUs want to come out clearly ahead, more so for a block they are building.
	var cpu := q
	check(Cpu.accepts_trade(g, cpu, [], 0, [], 100), "a CPU takes free G")
	check(not Cpu.accepts_trade(g, cpu, [2], 0, [], g.lot_value(2)), "but not an even swap")
	check(Cpu.accepts_trade(g, cpu, [2], 0, [], roundi(g.lot_value(2) * 1.3)), "a good price is accepted")
	g.buy_lot(cpu, 3)  # now it holds 2 (from the trade) and 3 in Block A
	check(not Cpu.accepts_trade(g, cpu, [2], 0, [], roundi(g.lot_value(2) * 1.3)),
			"a lot in a block it is building costs more")


func test_auctions() -> void:
	var g := new_game(4)
	var p := g.players[0]
	g.buy_lot(p, 5)
	g.sell_lot_to_bank(p, 5)
	check(g.pending_auctions.size() == 1 and g.pending_auctions[0].lot == 5
			and g.pending_auctions[0].seller == 0, "a lot sold to the bank goes to auction")
	check(Auction.bidders(g, 0) == [1, 2, 3], "everyone but the seller bids")
	check(Auction.start_price(g, 5) == g.lot_value(5), "bidding opens at the lot's value")
	check(Auction.next_bid(g, 5, 0) == g.lot_value(5) and Auction.next_bid(g, 5, 250) == 260,
			"the first bid is the opening price, then +10")
	var q := g.players[1]
	g.buy_bonds(q, "A", 20)
	check(Auction.total_money(g, q) == q.cash + g.bond_worth(q), "total money is cash plus bonds")

	# Winning: the lot is theirs and the price comes out of cash, or bonds.
	g.defer_debts = true
	q.cash = 100
	Auction.settle(g, q, 5, 300)
	check(g.lots[5].owner == 1 and q.cash == -200, "the winner owns it and owes what cash can't pay")
	g.settle_debt(q)
	check(q.cash >= 0 and q.bonds_in("A") < 20 and g.lots[5].owner == 1, "bonds are sold to pay")

	# All-CPU bidding: someone wins at or above the opening price, or no one does.
	g.defer_debts = false
	var r := g.players[2]
	g.buy_lot(r, 6)
	g.sell_lot_to_bank(r, 6)
	var before := g.players.map(func(x): return x.cash)
	var winner := Auction.resolve_cpu(g, 6, 2)
	if winner >= 0:
		var paid: int = before[winner] - g.players[winner].cash
		check(g.lots[6].owner == winner and winner != 2 and paid >= g.lot_value(6),
				"a CPU auction sells at the opening price or more, never to the seller")
	else:
		check(g.lots[6].owner == -1, "with no bids the lot stays on sale")


func test_star_and_moon() -> void:
	var g := new_game(3)
	var p := g.players[0]
	var q := g.players[1]
	var r := g.players[2]
	var star: Array = g.board.spaces.filter(func(s): return s.type == "interest")
	var moon: Array = g.board.spaces.filter(func(s): return s.type == "break")
	check(star.size() == 1 and moon.size() == 1, "one Star and one Moon on the board")
	check(g.options_from(star[0].id, 10) == [12, 26], "the Star still branches both ways")

	# Star: 20% of everyone else's profits, from the bank, until your next turn.
	g.current = 0
	p.position = star[0].id
	g.land()
	check(p.commission, "landing on the Star starts a commission")
	g.buy_lot(q, 5)
	var pc := p.cash
	var qc := q.cash
	g.pay_rent(r, 5)
	var rent := g.rent(5)
	check(q.cash == qc + rent and p.cash == pc + roundi(rent * GameState.COMMISSION_RATE),
			"the Star holder gets 20% of rent others collect; the earner keeps it all")
	pc = p.cash
	g.earn(p, 100)
	check(p.cash == pc + 100, "no commission on your own profits")
	pc = p.cash
	Minigames.apply_prize(g, q, {"kind": "cash", "amount": 200})
	check(p.cash == pc + 40, "prizes count as profit too")
	g.current = 0
	g.start_turn()
	check(not p.commission, "the commission ends at your next turn")

	# Moon: your lots are closed (no rent) until your next turn.
	g.buy_lot(p, 1)
	var open_rent := g.rent(1)
	p.position = moon[0].id
	g.land()
	check(p.on_break and g.rent(1) == 0 and open_rent > 0, "the Moon closes your lots")
	var qc2 := q.cash
	g.pay_rent(q, 1)
	check(q.cash == qc2, "nobody pays rent at a closed lot")
	check(g.events.any(func(e): return e.kind == "break"), "the UI is told to play the sunset")
	g.current = 0
	g.start_turn()
	check(not p.on_break and g.rent(1) == open_rent, "they open again at your next turn")


func test_plots() -> void:
	var g := new_game(3)
	var p := g.players[0]
	var q := g.players[1]
	var r := g.players[2]
	check(g.plots.size() == 3, "three building plots on the board")
	var ids: Array = g.plots.keys()
	var a: int = ids[0]
	var b: int = ids[1]
	var c: int = ids[2]
	p.position = a
	check(g.land().any(func(o): return o.kind == "build"), "an empty plot offers a build")
	var cash := p.cash
	check(Plots.build(g, p, a, "bridge") and p.cash == cash - Plots.BUILD_COST, "building costs 200 G")
	check(g.net_worth(p) == cash, "a building counts in net worth at what it cost")
	check(not Plots.build(g, q, a, "tax"), "one building per plot")

	# Toll Bridge: rivals pay as they pass, into the jar; the toll rises 10 G a time.
	q.position = a - 1
	q.came_from = a - 2
	g.current = 1
	g.moves_left = 2
	var qc := q.cash
	g.step(a)
	check(q.cash == qc - Plots.TOLL_START and g.plots[a].jar == Plots.TOLL_START,
			"passing pays the toll into the jar")
	check(g.plots[a].toll == Plots.TOLL_START + Plots.TOLL_STEP, "the next toll is 10 G more")
	p.position = a
	cash = p.cash
	g.current = 0
	g.land()
	check(p.cash == cash + Plots.TOLL_START and g.plots[a].jar == 0, "the owner empties the jar")

	# Tax Office: rivals pay 10% of their net worth; the owner gets a 5% bonus.
	Plots.build(g, q, b, "tax")
	r.position = b
	g.current = 2
	var worth := g.net_worth(r)
	qc = q.cash
	g.land()
	check(q.cash == qc + roundi(worth * Plots.TAX_RATE), "Tax Office: 10% of the rival's net worth")
	q.position = b
	g.current = 1
	var qw := g.net_worth(q)
	qc = q.cash
	g.land()
	check(q.cash == qc + roundi(qw * Plots.TAX_BONUS), "the owner's 5% bonus")

	# Shopping Centre: the fee grows as the owner expands it, three times at most.
	Plots.build(g, r, c, "centre")
	check(Plots.rival_charge(g, c, p) == 100, "a new Shopping Centre charges 100 G")
	r.cash += 3000  # enough for every expansion
	for i in 3:
		check(Plots.expand(g, r, c), "expand %d" % (i + 1))
	check(Plots.rival_charge(g, c, p) == 2000 and not Plots.expand(g, r, c), "2000 G at most")
	r.position = c
	g.current = 2
	check(not g.land().any(func(o): return o.kind == "expand"), "no more expanding when full")

	# Airport and Repair Shop perks are offers for the owner.
	var g2 := new_game(2)
	var ids2: Array = g2.plots.keys()
	var o := g2.players[0]
	Plots.build(g2, o, ids2[0], "airport")
	o.position = ids2[0]
	check(g2.land().any(func(x): return x.kind == "fly"), "the Airport owner may fly")
	g2.buy_lot(o, 1)
	Plots.build(g2, o, ids2[1], "repair")
	o.position = ids2[1]
	var reno: Array = g2.land().filter(func(x): return x.kind == "invest")
	check(reno.size() == 1 and is_equal_approx(reno[0].rate, Plots.REPAIR_DISCOUNT),
			"the Repair Shop invests at half price")
	var rival := g2.players[1]
	rival.position = ids2[1]
	g2.current = 1
	var rc := rival.cash
	g2.land()
	check(rival.cash == rc - Plots.REPAIR_FEE, "rivals pay the Repair Shop 40 G")


func test_plot_rules() -> void:
	var g := new_game(2)
	var p := g.players[0]
	var ids: Array = g.plots.keys()
	check(Plots.CENTRE_FEES == [100, 500, 1000, 2000] and Plots.REPAIR_FEE == 50,
			"Shopping Centre 100/500/1000/2000 G, Repair Shop 50 G")
	# Building is compulsory: there is no "leave it" offer, only build.
	p.position = ids[0]
	var offers := g.land()
	check(offers.size() == 1 and offers[0].kind == "build", "an empty plot means you build")
	check(Plots.cpu_build(g, p) != "", "a CPU that can pay always builds")
	p.cash = 0
	check(Plots.cpu_build(g, p) == "", "unless it can't pay at all")
	p.cash = 5000
	# Expanding: only when you land on one of your own plots, but then any of
	# your Shopping Centres can be expanded.
	Plots.build(g, p, ids[0], "centre")
	Plots.build(g, p, ids[1], "airport")
	p.position = ids[1]
	var exp: Array = g.land().filter(func(o): return o.kind == "expand")
	check(exp.size() == 1 and exp[0].plot == ids[0], "landing on your Airport offers to expand your Centre")
	var q := g.players[1]
	q.position = ids[0]
	g.current = 1
	check(not g.land().any(func(o): return o.kind == "expand"), "a rival landing there can't expand it")


func test_all_boards() -> void:
	var files := Array(DirAccess.get_files_at("res://boards")).filter(func(f): return f.ends_with(".json"))
	check(files.size() >= 6, "the boards folder holds every board (%d)" % files.size())
	for file in files:
		var b := Board.load_file("res://boards/%s" % file)
		if b == null:
			check(false, "%s loads" % file)
			continue
		var count := {}
		for s in b.spaces:
			count[s.type] = count.get(s.type, 0) + 1
		var ok: bool = count.get("depot", 0) == 1 and b.relay_ids().size() == 4 \
				and count.get("interest", 0) == 1 and count.get("break", 0) == 1 \
				and count.get("plot", 0) == 3 and count.get("dice", 0) == 2 \
				and count.get("arcade", 0) == 1 and b.lot_ids().size() >= 12
		var reached := {b.depot: true}
		var queue: Array = [b.depot]
		while not queue.is_empty():
			for n in b.spaces[queue.pop_front()].next:
				if not reached.has(n):
					reached[n] = true
					queue.append(n)
		check(ok and reached.size() == b.spaces.size(),
				"%s: one Depot, four suits, Star, Moon, 3 plots, 2 Dice, Arcade, all reachable" % b.name)


## Every card in the pool resolves (with a CPU's pick) without breaking the
## game, and a few of the newer effects do what they say.
func test_card_pool() -> void:
	var names := {}
	for id in Wildcards.CARDS.size():
		var c := Wildcards.card(id)
		names[c.name] = true
		var g := new_game(3)
		var p := g.players[0]
		for lot in g.lots.keys().slice(0, 4):  # something to boost, invest in or lose
			g.lots[lot].owner = 0
		for lot in g.lots.keys().slice(4, 8):
			g.lots[lot].owner = 1
		p.bonds[g.board.blocks.keys()[0]] = 5
		p.punches.append(g.board.relay_ids()[0])
		Wildcards.apply(g, p, id, Wildcards.cpu_pick(g, p, id))
		check(g.players.size() == 3 and p.cash is int, "%s resolves" % c.name)
	check(names.size() == Wildcards.CARDS.size() - 2, "every card has its own name (bar the three Any Suits)")

	var g := new_game(3)
	var p := g.players[0]
	var cash := [p.cash, g.players[1].cash]
	Wildcards.apply(g, p, _id("Round of Drinks"))
	check(p.cash == cash[0] - 40 and g.players[1].cash == cash[1] + 20, "Round of Drinks pays each rival 20")
	var block: String = g.board.blocks.keys()[1]
	Wildcards.apply(g, p, _id("Bond Hamper"), block)
	check(p.bonds_in(block) == 5, "Bond Hamper gives 5 free bonds")
	var lot: int = g.lots.keys()[0]
	g.lots[lot].owner = 1
	for i in 20:
		Wildcards.apply(g, p, _id("Bad Review"), lot)
	check(is_equal_approx(g.lots[lot].boost, Wildcards.MIN_BOOST), "devaluing stops at half")
	Wildcards.apply(g, p, _id("Gridlock"), 2)
	check(g.players[2].skip_move, "Gridlock stops a rival")
	var start := p.position
	var r := Wildcards.apply(g, p, _id("Taxi Ride"))
	check(r.get("land_again", false) and p.position != start, "Taxi Ride rides ahead and lands")
	p.punches.clear()
	Wildcards.apply(g, p, _id("Suit Up"))
	check(p.punches.size() == 1, "Suit Up punches a missing suit")
	Wildcards.apply(g, p, _id("Lost Stamp"))
	check(p.punches.is_empty(), "Lost Stamp takes it away")
	check(Wildcards.apply(g, p, _id("Wheel Spin")).get("game", "") == "wheel", "Wheel Spin names its minigame")
	for i in 30:
		cash = [p.cash]
		Wildcards.apply(g, p, _id("Treasure Chest"))
		var won: int = p.cash - cash[0]
		if won < 100 or won > 500 or won % 10 != 0:
			check(false, "Treasure Chest pays 100-500 G in tens, not %d" % won)
	check(Wildcards.by_name("Pot Luck").is_empty(), "no Pot cards are left")


func _id(name: String) -> int:
	return Wildcards.CARDS.find(Wildcards.by_name(name))


## The cards that move players about the board, and the Fire Sale.
func test_board_cards() -> void:
	var g := new_game(3)
	var p := g.players[0]
	# Walking backwards: next turn the first step turns round, then it keeps going.
	p.position = 10
	p.came_from = 9
	var ahead := g.options()
	Wildcards.apply(g, p, _id("Reverse Gear"))
	check(p.reverse_next and not p.reverse_move, "Reverse Gear waits for the next turn")
	g.start_turn()
	var back := g.options()
	check(p.reverse_move and not back.is_empty() and back.all(func(o): return o not in ahead),
			"backwards: never the way on")
	check(9 in back, "backwards: the way it came")
	g.moves_left = 2
	g.step(9)
	check(10 not in g.options(), "backwards: no turning round again")
	g.end_turn()
	check(not p.reverse_move, "it lasts one turn")
	Wildcards.apply(g, p, _id("U-Turn"), 1)
	check(g.players[1].reverse_next, "U-Turn sends a rival backwards")
	# Warp Gate, Bank Shuttle, Suit Hopper.
	var h := new_game(3)
	var q := h.players[0]
	var lot: int = h.lots.keys()[3]
	var r := Wildcards.apply(h, q, _id("Warp Gate"), lot)
	check(q.position == lot and r.get("land_again", false), "Warp Gate: there, and lands")
	Wildcards.apply(h, q, _id("Bank Shuttle"), null)
	check(q.position == lot, "Bank Shuttle can be declined")
	r = Wildcards.apply(h, q, _id("Bank Shuttle"), true)
	check(q.position == h.board.depot and r.get("land_again", false), "Bank Shuttle: to the Bank")
	var relay: int = h.board.relay_ids()[2]
	q.punches.clear()
	r = Wildcards.apply(h, q, _id("Suit Hopper"), relay)
	check(q.position == relay and relay in q.punches and not r.get("land_again", false),
			"Suit Hopper: punched, no landing (no card)")
	# Fire Sale: twice the value, then the lot goes to auction.
	h.lots[lot].owner = q.index
	var value := h.lot_value(lot)
	var cash := q.cash
	Wildcards.apply(h, q, _id("Fire Sale"), lot)
	check(q.cash == cash + 2 * value and h.lots[lot].owner < 0, "Fire Sale pays twice the value")
	check(h.pending_auctions.any(func(a): return a.lot == lot), "and the lot goes to auction")
