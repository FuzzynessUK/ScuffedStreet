extends SceneTree
## Headless rules tests. Run:
##   godot --headless --path . -s tests/test_core.gd

var failures := 0
var checks := 0


func _init() -> void:
	test_board_loads()
	test_board_validation()
	test_rent_and_blocks()
	test_renovation()
	test_salary_and_relays()
	test_branching()
	test_bonds()
	test_bankruptcy()
	test_goal_win()
	test_wildcards()
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
	g.buy_lot(p, 5)  # B, 200
	check(g.max_capital(5) == 200 * (0.6 + 1.0 + 1.6), "max capital: every tier still to go")
	check(g.renovate_cost(5) == 120, "shop costs 0.6 x base")
	g.renovate(p, 5, g.renovate_cost(5))
	check(g.lot_value(5) == 320, "shop value 1.6 x base")
	check(g.rent(5) == roundi(320 * 0.14), "shop rent 14%")
	g.buy_lot(p, 6)
	g.buy_lot(p, 8)
	check(g.renovate_cost(5) == 150, "whole block: store 200 x 0.75")


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
	var before := p.cash
	g.land()
	check(p.cash == before + 50, "relay landing bonus")
	p.position = 25
	p.came_from = 24
	p.punches.append(24)
	before = p.cash
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
	g.charge(p, 1000, q.index)
	check(p.broke and g.game_over and g.winner == 1, "broke ends the game")


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
	var slots := GameState.HEAP_COLS * GameState.HEAP_ROWS
	check(g.heap.size() == slots and g.heap_slots_left().size() == slots, "heap starts full")
	var seen := {}
	for id in g.heap:
		seen[id] = true
	check(seen.size() == Wildcards.CARDS.size(), "heap holds every card at least once")

	# Patches: player 0 takes slot 0 then 1 (neighbours), then 9 (below 1).
	var cash := p.cash
	g.take_from_heap(0)
	check(p.cash == cash, "a lone card pays nothing")
	g.take_from_heap(1)
	check(p.cash == cash + GameState.PATCH_BONUS, "patch of 2 pays one bonus")
	g.take_from_heap(GameState.HEAP_COLS + 1)
	check(p.cash == cash + GameState.PATCH_BONUS * 3, "patch of 3 pays two more")
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
