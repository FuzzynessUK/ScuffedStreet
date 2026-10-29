extends Control
## Hot-seat game screen: board on the left, players / prompt / buttons / log on
## the right. Drives GameState one turn at a time; CPU players decide via Cpu.

signal chosen(value)

const BOARD_PATH := "res://boards/scrapyard_loop.json"
const STEP_DELAY := 0.15
const CPU_DELAY := 0.6
const BOND_LOT := 5  # bonds per market button press
const SETUPS := [
	["1 player vs 3 CPUs", [false, true, true, true]],
	["2 players vs 2 CPUs", [false, false, true, true]],
	["4 players (hot-seat)", [false, false, false, false]],
	["Watch 4 CPUs", [true, true, true, true]],
]

var game := GameState.new()
var board_view: BoardView
var players_label: RichTextLabel
var prompt_label: Label
var buttons: VBoxContainer
var log_box: RichTextLabel
var _shown_events := 0


func _ready() -> void:
	_build_ui()
	_start_menu()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	board_view = BoardView.new()
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.game = game
	row.add_child(board_view)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	row.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	players_label = RichTextLabel.new()
	players_label.bbcode_enabled = true
	players_label.fit_content = true
	col.add_child(players_label)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 18)
	col.add_child(prompt_label)

	buttons = VBoxContainer.new()
	col.add_child(buttons)

	log_box = RichTextLabel.new()
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	col.add_child(log_box)


func _start_menu() -> void:
	board_view.game = null
	board_view.queue_redraw()
	players_label.text = "[b]Scuffed Street[/b]"
	log_box.clear()
	var opts := []
	for s in SETUPS:
		opts.append([s[0], s[1]])
	var cpu: Array = await _ask(null, "New game on Scrapyard Loop:", opts)
	var names := []
	var humans := 0
	for i in cpu.size():
		if cpu[i]:
			names.append("CPU %d" % (i + 1))
		else:
			humans += 1
			names.append("Player %d" % humans)
	game.setup(Board.load_file(BOARD_PATH), names, cpu)
	board_view.game = game
	_shown_events = 0
	_run()


func _run() -> void:
	while not game.game_over:
		await _play_turn()
		game.end_turn()
	_refresh()
	var w := game.players[game.winner].name if game.winner >= 0 else "Nobody"
	await _ask(null, "Game over: %s wins!" % w, [["New game", true]])
	_start_menu()


func _play_turn() -> void:
	var p := game.current_player()
	game.start_turn()
	_refresh()
	if p.position == game.board.depot:
		await _market(p, "Start of turn at the Depot: trade bonds?")
	var goal_note := "  (at goal: reach the Depot to win!)" if p.at_goal else ""
	await _ask(p, "%s's turn.%s" % [p.name, goal_note], [["Roll", true]], true)
	game.roll()
	_refresh()
	while game.moves_left > 0 and not game.game_over:
		var opts := game.options()
		var to := opts[0]
		if opts.size() > 1:
			to = await _choose_branch(p, opts)
		game.step(to)
		_refresh()
		await _wait(STEP_DELAY)
	if game.game_over:
		return
	var offers := game.land()
	_refresh()
	await _resolve(p, offers)


func _choose_branch(p: PlayerState, opts: Array[int]) -> int:
	board_view.highlight = opts
	board_view.queue_redraw()
	var choices := []
	for o in opts:
		choices.append(["Go to %s" % game._label(o), o])
	var to: int = await _ask(p, "%d moves left. Which way?" % game.moves_left, choices,
			Cpu.pick_branch(game, p, opts))
	board_view.highlight = []
	return to


func _resolve(p: PlayerState, offers: Array[Dictionary]) -> void:
	var renovations: Array[Dictionary] = []
	for o in offers:
		match o.kind:
			"buy":
				var yes: bool = await _ask(p, "Buy %s for %d?" % [game._label(o.lot), o.cost],
						[["Buy", true], ["Pass", false]], Cpu.wants_buy(game, p, o.cost))
				if yes:
					game.buy_lot(p, o.lot)
			"buyout":
				var owner := game.players[o.owner].name
				var yes: bool = await _ask(p, "Buy %s out from %s for %d?" % [game._label(o.lot),
						owner, o.cost], [["Buy out", true], ["Pass", false]],
						Cpu.wants_buyout(game, p, o.lot, o.cost))
				if yes:
					game.buyout(p, o.lot)
			"renovate":
				renovations.append(o)
			"market":
				await _market(p, "Market: trade bonds?")
		_refresh()
	if not renovations.is_empty():
		await _renovate(p, renovations)


func _renovate(p: PlayerState, offers: Array[Dictionary]) -> void:
	var choices := []
	var cpu_pick = null
	for o in offers:
		if p.cash >= o.cost:
			var tier: int = game.lots[o.lot].tier + 1
			choices.append(["%s -> %s (%d)" % [game._label(o.lot), GameState.TIER_NAMES[tier], o.cost], o])
			if cpu_pick == null and Cpu.wants_renovate(game, p, o.cost):
				cpu_pick = o
	if choices.is_empty():
		return
	choices.append(["Skip", null])
	var pick = await _ask(p, "Renovate?", choices, cpu_pick)
	if pick != null:
		game.renovate(p, pick.lot, pick.cost)
		_refresh()


func _market(p: PlayerState, prompt: String) -> void:
	if p.is_cpu:
		Cpu.trade(game, p)
		_refresh()
		return
	while true:
		var choices := []
		for block in game.board.blocks:
			var price := game.bond_price(block)
			var bname: String = game.board.blocks[block].name
			if p.cash >= price * BOND_LOT:
				choices.append(["Buy %d %s @ %d" % [BOND_LOT, bname, price], ["buy", block]])
			if p.bonds_in(block) > 0:
				var n := mini(BOND_LOT, p.bonds_in(block))
				choices.append(["Sell %d %s @ %d" % [n, bname, price], ["sell", block, n]])
		choices.append(["Done", null])
		var pick = await _ask(p, prompt, choices)
		if pick == null:
			return
		if pick[0] == "buy":
			game.buy_bonds(p, pick[1], BOND_LOT)
		else:
			game.sell_bonds(p, pick[1], pick[2])
		_refresh()


## Shows buttons and waits for a pick. CPU players (and only they) get
## `cpu_value` after a short pause instead.
func _ask(p: PlayerState, prompt: String, choices: Array, cpu_value = null):
	prompt_label.text = prompt
	for c in buttons.get_children():
		c.queue_free()
	if p != null and p.is_cpu:
		await _wait(CPU_DELAY)
		return cpu_value
	for c in choices:
		var b := Button.new()
		b.text = c[0]
		b.pressed.connect(func(): chosen.emit(c[1]))
		buttons.add_child(b)
	var value = await chosen
	for c in buttons.get_children():
		c.queue_free()
	return value


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _refresh() -> void:
	var lines := PackedStringArray()
	lines.append("[b]Goal %d[/b]   Pot %d   Turn %d" % [game.board.goal, game.pot, game.turn])
	for p in game.players:
		var col: String = BoardView.PLAYER_COLORS[p.index].to_html(false)
		var mark := "> " if p.index == game.current else "   "
		var bonds := 0
		for b in p.bonds:
			bonds += p.bonds[b]
		lines.append("%s[color=#%s]■[/color] [b]%s[/b]  cash %d  worth %d  relays %d/%d  bonds %d%s" % [
				mark, col, p.name, p.cash, game.net_worth(p), p.punches.size(),
				game.board.relay_ids().size(), bonds, "  BROKE" if p.broke else ""])
	players_label.text = "\n".join(lines)
	while _shown_events < game.events.size():
		log_box.add_text(game.events[_shown_events] + "\n")
		_shown_events += 1
	board_view.queue_redraw()
