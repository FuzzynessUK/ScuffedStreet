extends SceneTree
## Plays whole 4-CPU games headless and prints how they end. Run:
##   godot --headless --path . -s tests/sim_cpu.gd

const GAMES := 200
const TURN_LIMIT := 400

var cards_drawn := []
var auctions := 0
var built := 0


func _init() -> void:
	# Optional: the board file, how many games and a goal, after "--" on the command line.
	var args := OS.get_cmdline_user_args()
	var path := "res://boards/%s" % args[0] if args.size() > 0 else "res://boards/scrapyard_loop.json"
	var games: int = int(args[1]) if args.size() > 1 else GAMES
	var board := Board.load_file(path)
	if args.size() > 2:
		board.goal = int(args[2])
	cards_drawn.resize(Wildcards.CARDS.size())
	cards_drawn.fill(0)
	var turns_total := 0
	var by_goal := 0
	var by_broke := 0
	var stalled := 0
	for i in games:
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
	print("%s, %d games: %d goal wins, %d bankruptcies, %d hit the turn limit, avg %.1f rounds" % [
			board.name, games, by_goal, by_broke, stalled, float(turns_total) / games])
	var never := []
	for i in cards_drawn.size():
		if cards_drawn[i] == 0:
			never.append(Wildcards.CARDS[i].name)
	print("Wildcards drawn: %d; never drawn: %s" % [cards_drawn.reduce(func(a, b): return a + b, 0), never])
	print("Auctions held: %d" % auctions)
	print("Plots built: %d" % built)
	quit()


func play_turn(g: GameState) -> void:
	var p := g.current_player()
	g.start_turn()
	if g.take_skip():
		return
	move_and_land(g, p)
	# Lots sold to the bank during the turn go to auction (all CPU bidders).
	while not g.pending_auctions.is_empty() and not g.game_over:
		var a: Dictionary = g.pending_auctions.pop_front()
		if g.lots[a.lot].owner < 0:
			Auction.resolve_cpu(g, a.lot, a.seller)
			auctions += 1


func move_and_land(g: GameState, p: PlayerState) -> void:
	g.roll()
	while g.moves_left > 0 and not g.game_over:
		var opts := g.options()
		g.step(opts[0] if opts.size() == 1 else Cpu.pick_branch(g, p, opts))
	if not g.game_over:
		land(g, p)


func land(g: GameState, p: PlayerState) -> void:
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
			"invest":
				for step in Cpu.invest_plan(g, p, o.rate):
					g.invest(p, step[0], step[1], o.rate)
			"market":
				Cpu.trade(g, p)
			"reroll":
				move_and_land(g, p)
			"build":
				var kind := Plots.cpu_build(g, p)
				if kind != "":
					Plots.build(g, p, o.plot, kind)
					built += 1
			"expand":
				if Plots.cpu_expands(g, p, o.cost):
					Plots.expand(g, p, o.plot)
			"fly":
				g.warp(p, Plots.cpu_fly(g, p))
				if not g.game_over:
					land(g, p)
			"minigame":
				if Minigames.cpu_minigame(g, p, Minigames.pick_minigame(g)).get("land_again", false) and not g.game_over:
					land(g, p)
			"wildcard":
				var id := g.take_from_heap(Cpu.pick_heap_slot(g, p))
				cards_drawn[id] += 1
				var result := Wildcards.apply(g, p, id, Wildcards.cpu_pick(g, p, id))
				if g.game_over:
					return
				if result.get("move_again", false):
					move_and_land(g, p)
				elif result.get("land_again", false):
					land(g, p)
				elif result.get("minigame", false):
					var kind: String = result.get("game", "")
					if kind == "":
						kind = Minigames.pick_minigame(g)
					if Minigames.cpu_minigame(g, p, kind).get("land_again", false) and not g.game_over:
						land(g, p)
				elif result.has("invest"):
					for step in Cpu.invest_plan(g, p, result.invest):
						g.invest(p, step[0], step[1], result.invest)
