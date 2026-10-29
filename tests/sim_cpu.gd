extends SceneTree
## Plays whole 4-CPU games headless and prints how they end. Run:
##   godot --headless --path . -s tests/sim_cpu.gd

const GAMES := 200
const TURN_LIMIT := 400


func _init() -> void:
	var board := Board.load_file("res://boards/scrapyard_loop.json")
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
	quit()


func play_turn(g: GameState) -> void:
	var p := g.current_player()
	g.start_turn()
	if p.position == g.board.depot:
		Cpu.trade(g, p)
	g.roll()
	while g.moves_left > 0 and not g.game_over:
		var opts := g.options()
		g.step(opts[0] if opts.size() == 1 else Cpu.pick_branch(g, p, opts))
	if g.game_over:
		return
	var renovated := false
	for o in g.land():
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
