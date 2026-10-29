extends SceneTree
## Plays whole 4-CPU games headless and prints how they end. Run:
##   godot --headless --path . -s tests/sim_cpu.gd

const GAMES := 200
const TURN_LIMIT := 400

var cards_drawn := []


func _init() -> void:
	var board := Board.load_file("res://boards/scrapyard_loop.json")
	cards_drawn.resize(Wildcards.CARDS.size())
	cards_drawn.fill(0)
	var turns_total := 0
	var by_goal := 0
	var by_broke := 0
	var stalled := 0
	for i in GAMES:
		var g := GameState.new()
		g.setup(board, ["A", "B", "C", "D"], [true, true, true, true], i)
		while not g.game_over and g.turn <= TURN_LIMIT:
			play_turn(g)
			g.end_turn()
		turns_total += g.turn
		if not g.game_over:
			stalled += 1
		elif g.players.any(func(p): return p.broke):
			by_broke += 1
		else:
			by_goal += 1
	print("%d games: %d goal wins, %d bankruptcies, %d hit the turn limit, avg %.1f rounds" % [
			GAMES, by_goal, by_broke, stalled, float(turns_total) / GAMES])
	var never := []
	for i in cards_drawn.size():
		if cards_drawn[i] == 0:
			never.append(Wildcards.CARDS[i].name)
	print("Wildcards drawn: %d; never drawn: %s" % [cards_drawn.reduce(func(a, b): return a + b, 0), never])
	quit()


func play_turn(g: GameState) -> void:
	var p := g.current_player()
	g.start_turn()
	if p.position == g.board.depot:
		Cpu.trade(g, p)
	if g.take_skip():
		return
	move_and_land(g, p)


func move_and_land(g: GameState, p: PlayerState) -> void:
	g.roll()
	while g.moves_left > 0 and not g.game_over:
		var opts := g.options()
		g.step(opts[0] if opts.size() == 1 else Cpu.pick_branch(g, p, opts))
	if not g.game_over:
		land(g, p)


func land(g: GameState, p: PlayerState) -> void:
	var renovated := false
	for o in g.land():
		if g.game_over:
			return
		match o.kind:
			"buy":
				if Cpu.wants_buy(g, p, o.cost):
					g.buy_lot(p, o.lot)
			"buyout":
				if Cpu.wants_buyout(g, p, o.lot, o.cost):
					g.buyout(p, o.lot)
			"renovate":
				if not renovated and p.cash >= o.cost and Cpu.wants_renovate(g, p, o.cost):
					renovated = g.renovate(p, o.lot, o.cost)
			"market":
				Cpu.trade(g, p)
			"wildcard":
				var left := g.heap_slots_left()
				var id := g.take_from_heap(left[g.rng.randi() % left.size()])
				cards_drawn[id] += 1
				var result := Wildcards.apply(g, p, id, Wildcards.cpu_pick(g, p, id))
				if g.game_over:
					return
				if result.get("move_again", false):
					move_and_land(g, p)
				elif result.get("land_again", false):
					land(g, p)
