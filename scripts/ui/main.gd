extends Control
## Hot-seat game screen: board on the left, players / prompt / buttons / log on
## the right. Drives GameState one turn at a time; CPU players decide via Cpu.

signal chosen(value)
signal heap_picked(slot: int)
signal market_action(act: Array)

const BOARD_PATH := "res://boards/scrapyard_loop.json"
const STEP_DELAY := 0.32
const CPU_DELAY := 0.6
const BOND_LOT := 5  # bonds per market button press
const PAYDAY_PAUSE := 1.8
const TICKER_SPIN := 1.2  # seconds a moved bond price spins before settling
const TICKER_HOLD := 1.6  # seconds the ticker stays up afterwards
const RENOVATION_SHOW := 1.6  # seconds the camera pulls back for a renovation
const HEAP_BACK := Color("#f29bd0")  # card backs: the Wildcard space colour
const MARKET_HEADERS := ["Block", "Price", "This round", "Block value", "Holders", "Yours", "Worth"]
const SETUPS := [
	["1 player vs 3 CPUs", [false, true, true, true]],
	["2 players vs 2 CPUs", [false, false, true, true]],
	["4 players (hot-seat)", [false, false, false, false]],
	["Watch 4 CPUs", [true, true, true, true]],
]

const KIND_COLORS := {
	"info": Color("#c8c8d0"), "gain": Color("#5be37a"), "loss": Color("#ff6464"),
	"win": Color("#ffd84a"),
	"card": Color("#f29bd0"),
	"payday": Color("#ffd84a"),
}

var game := GameState.new()
var board_view: BoardView
var banner: Label
var players_label: RichTextLabel
var prompt_label: Label
var buttons: VBoxContainer
var log_box: RichTextLabel
var _shown_events := 0
var _last_cash: Array[int] = []
var _payday_shown := false  # a PAYDAY played since the last _hold_for_shows()
var _ticker_shown := false
var _ticker_serial := 0
var _last_bond := {}  # block id -> bond price at the last _refresh()
var _last_tiers := {}  # lot id -> renovation tier at the last _refresh()
var ticker_panel: PanelContainer
var ticker_grid: GridContainer
var heap_panel: Control
var heap_title: Label
var heap_reveal: Label
var heap_hint: Label
var heap_buttons: Array[Button] = []
var market_panel: Control
var market_title: Label
var market_grid: GridContainer
var market_total: Label
var market_selected: Label
var market_qty_label: Label
var market_buy: Button
var market_sell: Button
var _market_block := ""
var _market_qty := 5


func _ready() -> void:
	_build_ui()
	# Dev switches after "--": --watch starts a 4-CPU game, --shot=<png> saves
	# a screenshot after a few seconds (or <png>@<seconds>) and quits.
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--shot="):
			var parts := arg.substr(7).split("@")
			_screenshot_later(parts[0], float(parts[1]) if parts.size() > 1 else 8.0)
	_start_menu()
	if "--watch" in args:
		chosen.emit(SETUPS[3][1])


func _screenshot_later(path: String, seconds: float) -> void:
	await _wait(seconds)
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(row)

	var board_area := Control.new()
	board_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(board_area)
	var view_box := SubViewportContainer.new()
	view_box.stretch = true
	view_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_area.add_child(view_box)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_box.add_child(viewport)
	board_view = BoardView.new()
	viewport.add_child(board_view)

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 12
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	board_area.add_child(banner)
	_build_heap(board_area)
	_build_market(board_area)
	_build_ticker(board_area)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
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


## The Scrap Heap: a grid of face-down Wildcards shown over the board.
func _build_heap(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	heap_panel = center
	var panel := PanelContainer.new()
	center.add_child(panel)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#24242c")
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	heap_title = Label.new()
	heap_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heap_title.add_theme_font_size_override("font_size", 20)
	col.add_child(heap_title)
	heap_hint = Label.new()
	heap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heap_hint.add_theme_font_size_override("font_size", 13)
	heap_hint.add_theme_color_override("font_color", Color("#c9a6bd"))
	col.add_child(heap_hint)
	var grid := GridContainer.new()
	grid.columns = GameState.HEAP_COLS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	col.add_child(grid)
	for i in GameState.HEAP_COLS * GameState.HEAP_ROWS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 50)
		b.add_theme_font_size_override("font_size", 13)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): heap_picked.emit(i))
		grid.add_child(b)
		heap_buttons.append(b)
	heap_reveal = Label.new()
	heap_reveal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heap_reveal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heap_reveal.custom_minimum_size = Vector2(0, 56)
	heap_reveal.add_theme_font_size_override("font_size", 18)
	heap_reveal.add_theme_color_override("font_color", HEAP_BACK)
	col.add_child(heap_reveal)


func _start_menu() -> void:
	board_view.build(null)
	banner.text = ""
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
	board_view.build(game)
	_shown_events = 0
	_last_cash.clear()
	for p in game.players:
		_last_cash.append(p.cash)
	_last_tiers.clear()
	for id in game.lots:
		_last_tiers[id] = game.lots[id].tier
	_last_bond.clear()
	for block in game.board.blocks:
		_last_bond[block] = game.bond_price(block)
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
	if game.take_skip():
		_refresh()
		await _wait(CPU_DELAY)
		return
	var goal_note := "  (at goal: reach the Depot to win!)" if p.at_goal else ""
	await _move_and_land(p, "%s's turn.%s" % [p.name, goal_note])


func _move_and_land(p: PlayerState, prompt: String) -> void:
	await _ask(p, prompt, [["Roll", true]], true)
	game.roll()
	_refresh()
	while game.moves_left > 0 and not game.game_over:
		var opts := game.options()
		var to := opts[0]
		if opts.size() > 1:
			to = await _choose_branch(p, opts)
		game.step(to)
		_refresh()
		await _hold_for_shows()
		await _wait(STEP_DELAY)
	if game.game_over:
		return
	await _land(p)


func _land(p: PlayerState) -> void:
	var offers := game.land()
	_refresh()
	await _resolve(p, offers)


func _choose_branch(p: PlayerState, opts: Array[int]) -> int:
	board_view.highlight = opts
	board_view.sync()
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
			"wildcard":
				await _wildcard(p)
		_refresh()
		await _hold_for_shows()
		if game.game_over:
			return
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
		await _hold_for_shows()


func _wildcard(p: PlayerState) -> void:
	var slot := await _pick_from_heap(p)
	var id := game.take_from_heap(slot)
	var c := Wildcards.card(id)
	heap_buttons[slot].text = c.name
	_style_card(heap_buttons[slot], "face", BoardView.PLAYER_COLORS[p.index])
	heap_reveal.text = "%s\n%s" % [c.name.to_upper(), c.text]
	await _ask(p, "%s drew %s." % [p.name, c.name], [["OK", true]], true)
	heap_panel.visible = false

	var pick = null
	if c.pick != "none":
		pick = await _card_choice(p, id)
	var result := Wildcards.apply(game, p, id, pick)
	_refresh()
	await _hold_for_shows()
	if game.game_over:
		return
	if result.get("move_again", false):
		await _move_and_land(p, "Rush Hour! %s rolls again." % p.name)
	elif result.get("land_again", false):
		await _land(p)


func _pick_from_heap(p: PlayerState) -> int:
	heap_panel.visible = true
	heap_title.text = "%s: pick a card from the Scrap Heap" % p.name
	heap_hint.text = "Cards next to your own (up, down, left, right) pay %d for each card in the patch after the first." % GameState.PATCH_BONUS
	heap_reveal.text = ""
	for i in heap_buttons.size():
		var b := heap_buttons[i]
		var owner := game.heap_owner[i]
		b.disabled = owner >= 0 or p.is_cpu
		b.tooltip_text = ""
		if owner >= 0:
			b.text = Wildcards.card(game.heap[i]).name
			_style_card(b, "owned", BoardView.PLAYER_COLORS[owner])
		else:
			b.text = "?"
			_style_card(b, "back")
			var bonus := game.patch_bonus(game.patch_size(i, p.index))
			if bonus > 0:
				b.text = "?
+%d" % bonus
	prompt_label.text = "Pick a card." if not p.is_cpu else "%s is picking a card..." % p.name
	for c in buttons.get_children():
		c.queue_free()
	var slot: int
	if p.is_cpu:
		await _wait(CPU_DELAY)
		slot = Cpu.pick_heap_slot(game, p)
		_style_card(heap_buttons[slot], "face", BoardView.PLAYER_COLORS[p.index])
		await _wait(CPU_DELAY)
	else:
		slot = await heap_picked
	for b in heap_buttons:
		b.disabled = true
	return slot


func _card_choice(p: PlayerState, id: int):
	var c := Wildcards.card(id)
	var opts := Wildcards.choices(game, p, id)
	if opts.is_empty():
		return null
	var choices := []
	var lots_shown: Array[int] = []
	for o in opts:
		match c.pick:
			"block":
				choices.append(["%s (bonds %d)" % [game.board.blocks[o].name, game.bond_price(o)], o])
			"swap":
				choices.append(["Give %s, get %s" % [game._label(o[0]), game._label(o[1])], o])
				lots_shown.append(o[1])
			_:
				var owner := ""
				if game.lots[o].owner != p.index:
					owner = " (%s)" % game.players[game.lots[o].owner].name
				choices.append(["%s%s" % [game._label(o), owner], o])
				lots_shown.append(o)
	if c.pick == "swap":
		choices.append(["Don't swap", null])
	board_view.highlight = lots_shown
	board_view.sync()
	var pick = await _ask(p, "%s: choose." % c.name, choices, Wildcards.cpu_pick(game, p, id))
	board_view.highlight = []
	return pick


func _market(p: PlayerState, prompt: String) -> void:
	if p.is_cpu:
		Cpu.trade(game, p)
		_refresh()
		await _hold_for_shows()
		return
	prompt_label.text = prompt
	for c in buttons.get_children():
		c.queue_free()
	if _market_block == "" or not game.board.blocks.has(_market_block):
		_market_block = game.board.blocks.keys()[0]
	_market_qty = BOND_LOT
	market_panel.visible = true
	while true:
		_fill_market(p)
		var act: Array = await market_action
		match act[0]:
			"select":
				_market_block = act[1]
			"qty":
				_market_qty = clampi(_market_qty + act[1], 1, GameState.MAX_BOND_TRADE)
			"buy":
				game.buy_bonds(p, _market_block, _market_qty)
			"sell":
				game.sell_bonds(p, _market_block, mini(_market_qty, p.bonds_in(_market_block)))
			"done":
				break
		_refresh()
	market_panel.visible = false


## The Bond Market: a table of every block's bond price, its move this round,
## who holds what, and buy/sell controls for the selected block.
func _build_market(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	market_panel = center
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1c2a2a")
	bg.border_color = Color("#2e8b80")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	market_title = Label.new()
	market_title.add_theme_font_size_override("font_size", 22)
	col.add_child(market_title)
	market_grid = GridContainer.new()
	market_grid.columns = MARKET_HEADERS.size()
	market_grid.add_theme_constant_override("h_separation", 16)
	market_grid.add_theme_constant_override("v_separation", 4)
	col.add_child(market_grid)
	market_total = Label.new()
	market_total.add_theme_color_override("font_color", Color("#bfe8e2"))
	col.add_child(market_total)

	var trade := HBoxContainer.new()
	trade.add_theme_constant_override("separation", 6)
	col.add_child(trade)
	market_selected = Label.new()
	market_selected.custom_minimum_size = Vector2(130, 0)
	trade.add_child(market_selected)
	for d in [-10, -1]:
		trade.add_child(_market_button("%d" % d, ["qty", d]))
	market_qty_label = Label.new()
	market_qty_label.custom_minimum_size = Vector2(40, 0)
	market_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market_qty_label.add_theme_font_size_override("font_size", 20)
	trade.add_child(market_qty_label)
	for d in [1, 10]:
		trade.add_child(_market_button("+%d" % d, ["qty", d]))
	market_buy = _market_button("Buy", ["buy"])
	market_buy.custom_minimum_size = Vector2(120, 0)
	trade.add_child(market_buy)
	market_sell = _market_button("Sell", ["sell"])
	market_sell.custom_minimum_size = Vector2(130, 0)
	trade.add_child(market_sell)
	trade.add_child(_market_button("Done", ["done"]))

	var note := Label.new()
	note.text = ("Each bond pays %d%% of every rent paid in its block. " +
			"Trading %d or more at once moves the price %d%%.") % [
			roundi(GameState.DIVIDEND_RATE * 100), GameState.BIG_BOND_TRADE,
			roundi(GameState.BOND_PRESSURE * 100)]
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("#8fb0ab"))
	col.add_child(note)


func _market_button(text: String, act: Array) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): market_action.emit(act))
	return b


func _fill_market(p: PlayerState) -> void:
	market_title.text = "Bond Market — %s  (cash %d)" % [p.name, p.cash]
	for c in market_grid.get_children():
		market_grid.remove_child(c)
		c.queue_free()
	for h in MARKET_HEADERS:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", Color("#8fb0ab"))
		market_grid.add_child(l)

	var my_total := 0
	for block in game.board.blocks:
		var info: Dictionary = game.board.blocks[block]
		var price := game.bond_price(block)
		var change := game.bond_change(block)
		var mine := p.bonds_in(block)
		my_total += mine * price

		var name_btn := Button.new()
		name_btn.text = info.name
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.custom_minimum_size = Vector2(160, 0)
		var swatch := StyleBoxFlat.new()
		swatch.bg_color = info.color.darkened(0.15 if block == _market_block else 0.55)
		swatch.set_corner_radius_all(4)
		swatch.set_content_margin_all(5)
		if block == _market_block:
			swatch.set_border_width_all(2)
			swatch.border_color = Color.WHITE
		for state in ["normal", "hover", "pressed", "focus"]:
			name_btn.add_theme_stylebox_override(state, swatch)
		name_btn.pressed.connect(func(): market_action.emit(["select", block]))
		market_grid.add_child(name_btn)

		market_grid.add_child(_cell("%d" % price, Color.WHITE, 20))
		if change > 0:
			market_grid.add_child(_cell("▲ %d" % change, KIND_COLORS.gain))
		elif change < 0:
			market_grid.add_child(_cell("▼ %d" % -change, KIND_COLORS.loss))
		else:
			market_grid.add_child(_cell("–", KIND_COLORS.info))
		market_grid.add_child(_cell("%d" % game.block_value(block), KIND_COLORS.info))

		var holders := RichTextLabel.new()
		holders.bbcode_enabled = true
		holders.fit_content = true
		holders.autowrap_mode = TextServer.AUTOWRAP_OFF
		holders.custom_minimum_size = Vector2(150, 0)
		var parts := PackedStringArray()
		for q in game.players:
			if q.bonds_in(block) > 0:
				parts.append("[color=#%s]■[/color]%d" % [
						BoardView.PLAYER_COLORS[q.index].to_html(false), q.bonds_in(block)])
		holders.text = " ".join(parts) if not parts.is_empty() else "[color=#666666]none[/color]"
		market_grid.add_child(holders)

		market_grid.add_child(_cell("%d" % mine if mine > 0 else "–", Color.WHITE))
		market_grid.add_child(_cell("%d" % (mine * price) if mine > 0 else "–", Color("#ffe48a")))

	market_total.text = "Your bonds are worth %d in total." % my_total
	var price := game.bond_price(_market_block)
	var held := p.bonds_in(_market_block)
	var sell_n := mini(_market_qty, held)
	market_selected.text = game.board.blocks[_market_block].name
	market_qty_label.text = "%d" % _market_qty
	market_buy.text = "Buy for %d" % (price * _market_qty)
	market_buy.disabled = p.cash < price * _market_qty
	market_sell.text = "Sell %d for %d" % [sell_n, price * sell_n] if held > 0 else "Sell"
	market_sell.disabled = held == 0


func _cell(text: String, color: Color, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l



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


## Lets a PAYDAY celebration or a bond ticker spin play out before moving on.
func _hold_for_shows() -> void:
	var seconds := 0.0
	if _payday_shown:
		seconds = PAYDAY_PAUSE
	if _ticker_shown:
		seconds = maxf(seconds, TICKER_SPIN + 0.7)
	_payday_shown = false
	_ticker_shown = false
	if seconds > 0.0:
		await _wait(seconds)


## Bond Ticker: every block's bond price, shown whenever any of them moves.
## Moved prices spin like a slot machine reel, then settle on the new value.
func _build_ticker(parent: Control) -> void:
	ticker_panel = PanelContainer.new()
	ticker_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ticker_panel.offset_left = -300
	ticker_panel.offset_top = 56
	ticker_panel.offset_right = -12
	ticker_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1c2a2a", 0.95)
	bg.border_color = Color("#2e8b80")
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(10)
	ticker_panel.add_theme_stylebox_override("panel", bg)
	parent.add_child(ticker_panel)
	var col := VBoxContainer.new()
	ticker_panel.add_child(col)
	var title := Label.new()
	title.text = "BOND TICKER"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#7fd8cc"))
	col.add_child(title)
	ticker_grid = GridContainer.new()
	ticker_grid.columns = 3
	ticker_grid.add_theme_constant_override("h_separation", 14)
	col.add_child(ticker_grid)


## `changed` maps each moved block to its old price.
func _show_ticker(changed: Dictionary) -> void:
	for c in ticker_grid.get_children():
		ticker_grid.remove_child(c)
		c.queue_free()
	for block in game.board.blocks:
		var info: Dictionary = game.board.blocks[block]
		var name_label := _cell(info.name, info.color.lightened(0.35))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ticker_grid.add_child(name_label)
		var price := game.bond_price(block)
		var price_label := _cell("%d" % price, Color.WHITE, 20)
		price_label.custom_minimum_size = Vector2(56, 0)
		ticker_grid.add_child(price_label)
		var move_label := _cell("", Color.WHITE)
		move_label.custom_minimum_size = Vector2(60, 0)
		ticker_grid.add_child(move_label)
		if changed.has(block):
			_spin(price_label, move_label, changed[block], price)
	ticker_panel.visible = true
	_ticker_shown = true
	board_view.overview(TICKER_SPIN + TICKER_HOLD)
	_ticker_serial += 1
	var serial := _ticker_serial
	await _wait(TICKER_SPIN + TICKER_HOLD)
	if serial == _ticker_serial:
		ticker_panel.visible = false


func _spin(price_label: Label, move_label: Label, from: int, to: int) -> void:
	var up := to > from
	var color: Color = KIND_COLORS.gain if up else KIND_COLORS.loss
	var digits := str(maxi(from, to)).length()
	price_label.add_theme_color_override("font_color", color.lightened(0.4))
	var tw := create_tween()
	# Reel phase: random numbers of the same width whirring past...
	tw.tween_method(func(_t: float):
		price_label.text = "%d" % randi_range(int(pow(10, digits - 1)), int(pow(10, digits)) - 1),
		0.0, 1.0, TICKER_SPIN * 0.6)
	# ...then rolling from the old price to the new one, slowing down.
	tw.tween_method(func(t: float): price_label.text = "%d" % roundi(lerpf(from, to, t)),
		0.0, 1.0, TICKER_SPIN * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func():
		price_label.text = "%d" % to
		price_label.add_theme_color_override("font_color", color)
		move_label.text = ("▲ +%d" if up else "▼ %d") % (to - from)
		move_label.add_theme_color_override("font_color", color)
		price_label.pivot_offset = price_label.size / 2)
	tw.tween_property(price_label, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(price_label, "scale", Vector2.ONE, 0.12)


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
		var pips := ""
		for r in game.board.relay_ids():
			var rc: String = game.space(r).color.to_html(false) if r in p.punches else "4a4a55"
			pips += "[color=#%s]%s[/color]" % [rc, BoardView.SUIT_SYMBOLS.get(game.space(r).mark, "●")]
		lines.append("%s[color=#%s]■[/color] [b]%s[/b] %s  S%d  net %d  bonds %d%s" % [
				mark, col, p.name, pips, p.cash, game.net_worth(p), bonds,
				"  BROKE" if p.broke else ""])
	players_label.text = "\n".join(lines)

	while _shown_events < game.events.size():
		var e: Dictionary = game.events[_shown_events]
		var color := _event_color(e)
		log_box.push_color(color)
		log_box.add_text(e.text + "\n")
		log_box.pop()
		if e.kind != "info":
			banner.text = e.text
			banner.add_theme_color_override("font_color", color)
		if e.kind == "payday":
			board_view.payday(e.player, e.get("amount", 0))
			_last_cash[e.player] = game.players[e.player].cash  # the banner shows it
			_payday_shown = true
		if e.kind == "relay":
			var m: String = game.space(e.space).mark
			board_view.popup_at_space(e.space, "%s %s!" % [BoardView.SUIT_SYMBOLS.get(m, ""), m.to_upper()], color)
		_shown_events += 1

	for p in game.players:
		var diff := p.cash - _last_cash[p.index]
		if diff != 0:
			board_view.popup_at_player(p.index, "%+d" % diff,
					KIND_COLORS.gain if diff > 0 else KIND_COLORS.loss)
			_last_cash[p.index] = p.cash
	for id in game.lots:
		var tier: int = game.lots[id].tier
		if tier > _last_tiers.get(id, tier) and game.lots[id].owner >= 0:
			board_view.overview(RENOVATION_SHOW)
			board_view.popup_at_space(id, GameState.TIER_NAMES[tier].to_upper() + "!",
					BoardView.PLAYER_COLORS[game.lots[id].owner])
			_ticker_shown = true  # hold the turn while it shows
		_last_tiers[id] = tier
	var moved := {}
	for block in game.board.blocks:
		var price := game.bond_price(block)
		if _last_bond.get(block, price) != price:
			moved[block] = _last_bond[block]
		_last_bond[block] = price
	if not moved.is_empty() and not market_panel.visible:
		_show_ticker(moved)
	board_view.sync()


## Money in/out are green/red, relay punches take the relay's colour and
## purchases/renovations the player's.
func _event_color(e: Dictionary) -> Color:
	match e.kind:
		"relay":
			return game.space(e.space).color
		"own":
			return BoardView.PLAYER_COLORS[e.player]
	return KIND_COLORS.get(e.kind, KIND_COLORS.info)


## Card looks: "back" (face down, pink), "face" (just turned over: white with
## the taker's colour round it) and "owned" (taken earlier: the taker's colour).
func _style_card(b: Button, look: String, player_color := HEAP_BACK) -> void:
	var fill: Color = {"back": HEAP_BACK, "face": Color("#fff8fc"), "owned": player_color.darkened(0.15)}[look]
	var text := Color.WHITE if look == "owned" else Color("#3a1030")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(c, text)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill.lightened(0.15) if state == "hover" and look == "back" else fill
		box.set_corner_radius_all(8)
		box.set_border_width_all(2 if look != "face" else 4)
		box.border_color = {"back": Color("#3a1030"), "face": player_color, "owned": player_color.darkened(0.5)}[look]
		b.add_theme_stylebox_override(state, box)
