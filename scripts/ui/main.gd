extends Control
## Hot-seat game screen: board on the left, players / prompt / buttons / log on
## the right. Drives GameState one turn at a time; CPU players decide via Cpu.

signal chosen(value)
signal heap_picked(slot: int)
signal market_action(act: Array)
signal trade_action(act: Array)

const BOARD_PATH := "res://boards/scrapyard_loop.json"  # the board a new game starts on
const BOARD_DIR := "res://boards"
const STEP_DELAY := 0.26
const CPU_DELAY := 0.6
const TURN_OVERVIEW := 1.4  # between turns: the whole board for this long,
const TURN_ZOOM_IN := 1.4   # then "X's turn!" while the camera moves in on them
const STAR_RISE := 1.8      # the star rising over someone landing on the Star
const MAP_ALPHA := 0.8  # the corner map's opacity
const BOND_LOT := 5  # bonds per market button press
const PAYDAY_PAUSE := BoardView.PAYDAY_SECONDS  # the bond menu waits for the show
const TICKER_SPIN := 1.2  # seconds a moved bond price spins before settling
const TICKER_HOLD := 1.6  # seconds the ticker stays up afterwards
const RENOVATION_SHOW := 1.6  # seconds the camera pulls back for a renovation
const CARD_SIZE := Vector2(250, 330)  # a playing card's shape
const CARD_ART_SIZE := Vector2(206, 206)  # the picture is square
const CARD_TEXT_WIDTH := 330  # the text box under the card
const CAPTION_SIZE := 54  # the card's "+60G"
const LOT_ROWS := ["Lot value", "Rent", "Max capital", "Block"]
const TILE_SPIN := 3.0       # seconds the picked tile and its combo spin
const TILE_HALF_TURNS := 11  # odd, so the picked tile lands face up
const SLOT_STEP := 0.02    # seconds per block while the Bond Bump / Slump reel spins freely (a blur)
const SLOT_SETTLE := 0.42  # seconds on the last block as the reel stops
const LONG_LIST := 7  # more choices than this go in two columns
const RACE_PAYOUT := 3.0  # seconds each player's Critter Race winnings stay up
const HEAP_BACK := Color("#f29bd0")  # card backs: the Wildcard space colour
const MARKET_HEADERS := ["Block", "Price", "This round", "Block value"]  # + a column per player, + Your worth
const VIEW_MAP := "View Map / Check Properties"
const SETUPS := [
	["1 player vs 3 CPUs", [false, true, true, true]],
	["2 players vs 2 CPUs", [false, false, true, true]],
	["4 players (hot-seat)", [false, false, false, false]],
	["Watch 4 CPUs", [true, true, true, true]],
]

const GOALS := [8000, 10000, 15000, 20000, 30000]  # net worth goals offered on the home menu
const BLOCK_SHOW := 2.8  # seconds the camera stays on a block just completed
const KIND_COLORS := {
	"info": Color("#c8c8d0"), "gain": Color("#5be37a"), "loss": Color("#ff6464"),
	"win": Color("#ffd84a"),
	"card": Color("#f29bd0"),
	"payday": Color("#ffd84a"),
	"break": Color("#ffa060"),
}

var game := GameState.new()
var board_view: BoardView
var banner: Label
var turn_label: Label  # "X's turn!" in the middle of the board
var board_map: Minimap  # the board in the bottom-left corner, shown all through play
var players_label: RichTextLabel
var prompt_label: Label
var buttons: GridContainer  # one column, or two for a long list (_ask)
var log_box: RichTextLabel
var _shown_events := 0
var _last_cash: Array[int] = []
var _payday_shown := false  # a PAYDAY played since the last _hold_for_shows()
var _ticker_shown := false
var _ticker_serial := 0
var _last_bond := {}  # block id -> bond price at the last _refresh()
var _bond_change := {}  # player index -> what their bonds gained/lost, shown with the ticker
var _board_path := BOARD_PATH  # the board picked on the home menu
## Kept across a return to the Main Menu, which reloads the scene; the dev
## switches only apply to the first load.
static var _kept := {}
var pause_panel: Control  # Escape: Keep playing / Main Menu / Quit
var pause_menu_button: Button
var _goal := 15000  # the net worth goal picked on the home menu (GOALS)
var _last_whole := {}  # block id -> who owned all of it at the last _refresh() (-1: nobody)
var _block_shown := false  # a whole-block show played since the last _hold_for_shows()
var _payday_undo := {}  # while planning: state before the PAYDAY's Bond Market, to undo it
var _payday_mark := 0  # events before this index have had their PAYDAY Bond Market
var music: Music
var sfx: Sfx
var _ask_hover := Callable()  # if set, _ask calls it with a choice's value on hover
var props_scroll: ScrollContainer  # View Map / Check Properties list, in place of the log
var props_box: VBoxContainer
var overlays: Control  # the panels over the board (market, minigames...), hidden by View Map
var map_button: Button
var _map_open := false
var _map_saved: Array[int] = []  # board highlight when the map was opened
var _map_lit: Array[int] = []    # what the map itself last highlighted
var _last_tiers := {}  # lot id -> renovation tier at the last _refresh()
var _keys := {}  # while planning a route: "ui_up"/... or "back" -> value to choose
var _planning := false     # a human is planning a route
var _confirming := false   # playing a confirmed route through the rules
var _route_suits: Array = []  # suits the current player would hold at the route's end
var _route_any := 0           # and their Any Suit cards then
var _route_payday := 0        # PAYDAY the planned route collects (0: none), shown as it is planned
var ticker_panel: PanelContainer
var ticker_grid: GridContainer
var card_view: Control
var card_pop: VBoxContainer  # the card and its text box
var card_box: PanelContainer
var card_caption: Label  # the card's few words across its top
var card_name: Label
var card_art: CardArt
var card_text: Label
var card_bonus: Label
var lot_panel: PanelContainer
var lot_ribbon: Label
var lot_name: Label
var lot_values := {}  # LOT_ROWS caption -> value label
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
var _market_owing := false  # the market was opened to pay off a debt
var _market_sell_only := false  # opened from the turn menu: selling only
var _market_view_only := false  # View bonds: no buying or selling
var market_done: Button
var trade_panel: Control  # the trade builder
var trade_title: Label
var trade_sides: Array[VBoxContainer] = []  # what you give, what you get
var trade_summary: Label
var trade_propose: Button
var _offer := {}  # the offer being built: give_lots, give_g, get_lots, get_g
var slots: ScrapSlots  # the Scrap Slots minigame
var card_game: PickACard  # the Pick a Card minigame
var wheel_game: ChanceWheel  # the Chance Wheel minigame
var race_game: CritterRace  # the Critter Race minigame
var auction_panel: AuctionPanel  # lot auctions
var slot_panel: Control  # Bond Bump / Bond Slump reel
var slot_title: Label
var slot_cells: Array[Label] = []  # the reel window: above, centre, below
var slot_result: Label
var _slot_index := 0
var _slot_serial := 0  # bumped to stop a running free spin
var market_map: Minimap
var market_lots_title: Label
var market_lots: GridContainer  # the shown block's lots beside the minimap


func _ready() -> void:
	Settings.start()  # the audio buses and saved sound options, before any player
	_build_ui()
	_build_pause(self)
	music = Music.new()
	add_child(music)
	sfx = Sfx.new()
	add_child(sfx)
	# Dev switches after "--": --watch starts a 4-CPU game, --shot=<png> saves
	# a screenshot after a few seconds (or <png>@<seconds>) and quits,
	# --board=<name> plays boards/<name>.json.
	var args := OS.get_cmdline_user_args()
	if not _kept.is_empty():  # back from a game: no dev switches, same choices
		_board_path = _kept.board
		_goal = _kept.goal
		args = PackedStringArray()
	for arg in args:
		if arg.begins_with("--board="):
			_board_path = "res://boards/%s.json" % arg.substr(8)
		if arg.begins_with("--shot="):
			var parts := arg.substr(7).split("@")
			_screenshot_later(parts[0], float(parts[1]) if parts.size() > 1 else 8.0)
	_start_menu()
	if "--watch" in args:
		chosen.emit(SETUPS[3][1])


## The pause box Escape brings up: Keep playing, Main Menu (only during a
## game) and Quit, the sound options (music and sound effects each on or off
## with a volume slider) and the camera option (always zoomed out); Settings
## saves them as they change. While it is up the game stands still (time scale 0, so
## every wait, tween and CPU move holds) and the board can't be clicked.
func _build_pause(parent: Control) -> void:
	pause_panel = Control.new()
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.visible = false
	parent.add_child(pause_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_panel.add_child(centre)
	var box := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#24242c")
	bg.border_color = Color("#ffd84a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(12)
	bg.set_content_margin_all(22)
	box.add_theme_stylebox_override("panel", bg)
	centre.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	col.add_child(title)
	for entry in [["Keep playing", _set_paused.bind(false)], ["Main Menu", _to_main_menu],
			["Quit", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(240, 44)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(entry[1])
		col.add_child(b)
		if entry[0] == "Main Menu":
			pause_menu_button = b
	col.add_child(HSeparator.new())
	var sound := Label.new()
	sound.text = "Sound"
	sound.add_theme_font_size_override("font_size", 20)
	col.add_child(sound)
	col.add_child(_sound_row("Music", "music"))
	col.add_child(_sound_row("Sound effects", "sfx"))
	var camera := Label.new()
	camera.text = "Camera"
	camera.add_theme_font_size_override("font_size", 20)
	col.add_child(camera)
	var zoomed := CheckButton.new()
	zoomed.text = "Always zoomed out (whole board)"
	zoomed.button_pressed = Settings.get_value("zoomed_out")
	zoomed.toggled.connect(func(on: bool):
		Settings.set_value("zoomed_out", on)
		board_view.always_overview = on)
	col.add_child(zoomed)


## One sound option: an on/off switch, a volume slider (greyed while off) and
## the volume in %. `kind` is "music" or "sfx" (Settings).
func _sound_row(title: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var on := CheckButton.new()
	on.text = title
	on.custom_minimum_size = Vector2(170, 0)
	on.button_pressed = Settings.get_value(kind + "_on")
	row.add_child(on)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = Settings.get_value(kind + "_volume")
	slider.custom_minimum_size = Vector2(150, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.editable = on.button_pressed
	row.add_child(slider)
	var shown := Label.new()
	shown.custom_minimum_size = Vector2(48, 0)
	shown.text = "%d%%" % slider.value
	row.add_child(shown)
	on.toggled.connect(func(pressed: bool):
		Settings.set_value(kind + "_on", pressed)
		slider.editable = pressed)
	slider.value_changed.connect(func(v: float):
		Settings.set_value(kind + "_volume", int(v))
		shown.text = "%d%%" % v)
	if kind == "sfx":  # a step sound on letting go, to hear the new level
		slider.drag_ended.connect(func(_changed: bool): sfx.step(0))
	return row


func _set_paused(on: bool) -> void:
	pause_panel.visible = on
	pause_panel.move_to_front()
	pause_menu_button.visible = not map_button.disabled  # only while a game is on
	Engine.time_scale = 0.0 if on else 1.0


## Back to the home menu: the scene starts afresh (so nothing of the game
## left waiting carries on), keeping the board and goal picked.
func _to_main_menu() -> void:
	Engine.time_scale = 1.0
	_kept = {"board": _board_path, "goal": _goal}
	get_tree().reload_current_scene()


func _screenshot_later(path: String, seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout  # real time, even paused
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
	board_view.always_overview = Settings.get_value("zoomed_out")
	board_view.block_hit.connect(func(): sfx.play("dice_hit"))
	board_view.block_bounce.connect(func(): sfx.play("dice_bounce"))
	board_view.block_landed.connect(func(): sfx.play("dice_land"))

	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.offset_top = 12
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 26)
	banner.add_theme_constant_override("outline_size", 8)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	board_area.add_child(banner)
	turn_label = Label.new()
	turn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 72)
	turn_label.add_theme_constant_override("outline_size", 16)
	turn_label.add_theme_color_override("font_outline_color", Color.BLACK)
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_label.visible = false
	board_area.add_child(turn_label)
	board_map = Minimap.new()
	board_map.overlay = true
	board_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_map.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	board_map.grow_vertical = Control.GROW_DIRECTION_BEGIN
	board_map.position += Vector2(12, -12)
	board_map.modulate.a = MAP_ALPHA  # the board shows through a little
	board_map.visible = false
	board_area.add_child(board_map)
	# Every panel shown over the board lives in one layer, so View Map can
	# hide them all at once without touching their own visibility.
	overlays = Control.new()
	overlays.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(overlays)
	_build_heap(overlays)
	_build_market(overlays)
	_build_trade(overlays)
	_build_ticker(overlays)
	_build_card_view(overlays)
	_build_slot(overlays)
	slots = ScrapSlots.new()
	overlays.add_child(slots)
	card_game = PickACard.new()
	overlays.add_child(card_game)
	wheel_game = ChanceWheel.new()
	overlays.add_child(wheel_game)
	race_game = CritterRace.new()
	overlays.add_child(race_game)
	auction_panel = AuctionPanel.new()
	overlays.add_child(auction_panel)
	_build_lot_panel(overlays)

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

	map_button = Button.new()
	map_button.text = VIEW_MAP
	map_button.tooltip_text = "Shortcut: M"
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.disabled = true
	map_button.pressed.connect(_toggle_map)
	col.add_child(map_button)

	prompt_label = Label.new()
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.add_theme_font_size_override("font_size", 18)
	col.add_child(prompt_label)

	buttons = GridContainer.new()
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
	col.add_child(buttons)

	props_scroll = ScrollContainer.new()
	props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	props_scroll.visible = false
	col.add_child(props_scroll)
	props_box = VBoxContainer.new()
	props_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	props_box.add_theme_constant_override("separation", 2)
	props_scroll.add_child(props_box)

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
	_close_map()
	map_button.disabled = true
	board_view.build(null)
	board_map.visible = false
	banner.text = ""
	players_label.text = "[b]Scuffed Street[/b]"
	log_box.clear()
	var board := Board.load_file(_board_path)
	var opts := []
	for s in SETUPS:
		opts.append([s[0], s[1]])
	opts.append(["Net worth goal (now: %d G)" % _goal, "goal"])
	opts.append(["Choose a board (now: %s)" % board.name, "boards"])
	opts.append(["Test Lab: try minigames and features", "lab"])
	music.intense = false
	music.bonus = false
	music.minigame = ""
	var choice = await _ask(null, "Home — new game on %s, goal %d G:" % [board.name, _goal], opts)
	if choice is String:
		if choice == "boards":
			await _pick_board()
			_start_menu()
		elif choice == "goal":
			var goals := []
			for gl in GOALS:
				goals.append(["%d G%s" % [gl, "  (now)" if gl == _goal else ""], gl])
			_goal = await _ask(null, "Net worth goal: reach it, then get to the Depot, to win.", goals)
			_start_menu()
		else:
			_test_lab()
		return
	_new_game(choice)
	_run()


## Every board in the boards folder, by name: [[name, path], ...].
func _boards() -> Array:
	var out := []
	for file in DirAccess.get_files_at(BOARD_DIR):
		if file.ends_with(".json"):
			var path := "%s/%s" % [BOARD_DIR, file]
			var b := Board.load_file(path)
			if b:
				out.append([b.name, path, b])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


## The board picker: each board with its size and goal. Hovering a choice
## shows that board behind the menu; picking it makes it the home board.
func _pick_board() -> void:
	var boards := _boards()
	var choices := []
	for entry in boards:
		var b: Board = entry[2]
		choices.append(["%s — %d spaces, %d lots" % [b.name, b.spaces.size(),
				b.lot_ids().size()], entry[1]])
	choices.append(["Back", ""])
	_preview_board(_board_path)
	_ask_hover = func(path): if path != "": _preview_board(path)
	var path: String = await _ask(null, "Choose a board (hover to preview):", choices)
	_ask_hover = Callable()
	if path != "":
		_board_path = path
	board_view.hold_overview = false
	board_view.build(null)
	board_map.visible = false


## Shows a board on its own (no players), the whole of it, for the picker.
func _preview_board(path: String) -> void:
	var g := GameState.new()
	g.setup(Board.load_file(path), [], [])
	board_view.build(g)
	board_view.hold_overview = true


## Sets up a fresh game on the board; `cpu[i]` says whether seat i is a CPU.
func _new_game(cpu: Array) -> void:
	var names := []
	var humans := 0
	for i in cpu.size():
		if cpu[i]:
			names.append("CPU %d" % (i + 1))
		else:
			humans += 1
			names.append("Player %d" % humans)
	game.setup(Board.load_file(_board_path), names, cpu)
	game.board.goal = _goal
	game.defer_debts = true  # humans pick which bonds to sell (_settle_debts)
	board_view.build(game)
	map_button.disabled = false
	board_map.show_board(game)
	board_map.preview.clear()
	board_map.visible = true
	_shown_events = 0
	_last_cash.clear()
	for p in game.players:
		_last_cash.append(p.cash)
	_last_tiers.clear()
	for id in game.lots:
		_last_tiers[id] = game.tier(id)
	_last_bond.clear()
	for block in game.board.blocks:
		_last_bond[block] = game.bond_price(block)
	_last_whole.clear()
	_payday_mark = 0
	_refresh()


## The Test Lab's features in groups, so each menu fits on the screen.
const LAB_GROUPS := [
	["Minigames", [["Scrap Slots", "slots"], ["Pick a Card", "pick_a_card"],
		["Random minigame", "arcade"], ["Chance Wheel", "wheel"], ["Critter Race", "race"]]],
	["CPU minigames", [["CPU plays Slots", "cpu_slots"], ["CPU plays Pick a Card", "cpu_cards"],
		["CPU plays Chance Wheel", "cpu_wheel"], ["CPU plays Critter Race", "cpu_race"]]],
	["Spaces and moving", [["Roll the dice block", "roll"], ["Land on a Dice space", "dice"],
		["Land on the Star", "star"], ["Land on the Moon", "moon"], ["Land on a plot", "plot"],
		["Invest (land on your lot)", "invest"], ["Buy the last lot of a block", "whole"],
		["PAYDAY on the way (walk 4)", "payday"]]],
	["Bonds and money", [["Bond Market", "market"], ["Bond Bump reel", "bump"],
		["Bond Slump reel", "slump"], ["Owe 300 G (sell bonds)", "debt"], ["+1000 G", "cash"],
		["Reach the goal (glow, music)", "goal"]]],
	["Auctions and Wildcards", [["Auction a lot", "auction"], ["Bid at an auction", "bid"],
		["Draw a Wildcard", "heap"]]],
]


## A Test Lab pick: a group, then a feature in it ("back" to the groups, or
## "home").
func _lab_pick(p: PlayerState) -> String:
	var groups := []
	for g in LAB_GROUPS:
		groups.append([g[0], g[1]])
	groups.append(["Home menu", "home"])
	var group = await _ask(p, "Test Lab: pick a feature to try. Nothing here counts.", groups)
	if group is String:
		return group
	var choices: Array = (group as Array).duplicate()
	choices.append(["Back", "back"])
	return await _ask(p, "Test Lab: pick a feature to try.", choices)


## Test Lab, from the home menu: a throwaway game (you and three CPUs) where
## any feature can be played on demand. Nothing here carries over.
func _test_lab() -> void:
	_new_game(SETUPS[0][1])
	var p := game.current_player()
	while true:
		if game.game_over or p.broke:
			_new_game(SETUPS[0][1])  # start the lab afresh
			p = game.current_player()
		var pick = await _lab_pick(p)
		match pick:
			"back":
				continue
			"slots":
				await _scrap_slots(p)
			"pick_a_card":
				await _pick_a_card(p)
			"arcade":
				await _minigame(p)
			"cpu_slots":
				await _scrap_slots(game.players[1])
			"cpu_cards":
				await _pick_a_card(game.players[1])
			"wheel":
				await _chance_wheel(p)
			"cpu_wheel":
				await _chance_wheel(game.players[1])
			"race":
				await _critter_race(p)
			"cpu_race":
				await _critter_race(game.players[1])
			"bump", "slump":
				var id := 7 if pick == "bump" else 8
				var block := await _slot_machine(p, Wildcards.card(id))
				Wildcards.apply(game, p, id, block)
			"heap":
				await _wildcard(p)
			"market":
				await _market(p, "Test Lab: trade bonds.")
			"debt":
				if game.bond_worth(p) < 600:  # enough to sell off the debt
					var dear: String = game.board.blocks.keys()[0]
					for b in game.board.blocks:
						if game.bond_price(b) > game.bond_price(dear):
							dear = b
					p.cash += 1000
					game.buy_bonds(p, dear, 20)
				game.charge(p, p.cash + 300, -1)
				await _settle_debts()
			"plot":  # the first plot that is empty or yours (to build, or use its perk)
				for id in game.plots:
					if game.plots[id].owner in [-1, p.index]:
						p.position = id
						break
				board_view.sync()
				await _land(p)
			"roll":
				await _move_and_land(p, "Test Lab: roll the dice block.")
			"dice":  # stand on a Dice space and land: it rolls again
				for s in game.board.spaces:
					if s.type == "dice":
						p.position = s.id
						break
				board_view.sync()
				await _land(p)
			"star", "moon":  # stand on it and land, as at the end of a move
				var kind := "interest" if pick == "star" else "break"
				for s in game.board.spaces:
					if s.type == kind:
						p.position = s.id
				if kind == "break" and not game.lots.values().any(func(l): return l.owner == p.index):
					for id in game.lots.keys().slice(0, 3):  # a few lots to see closed
						if game.lots[id].owner < 0:
							game.lots[id].owner = p.index
				board_view.sync()
				await _land(p)
			"bid":  # CPU 2 sells a lot, so you bid against CPU 3 and CPU 4
				var spare: Array = game.lots.keys().filter(func(id): return game.lots[id].owner < 0)
				if spare.size() >= 2:
					var seller := game.players[1]
					# CPU 3 holds the next lot along, so it wants this block and bids keenly.
					var lot: int = spare[0]
					var block: String = game.space(lot).block
					for id in spare:
						if id != lot and game.space(id).block == block:
							game.lots[id].owner = 2
							break
					game.lots[lot].owner = seller.index
					game.sell_lot_to_bank(seller, lot)
					_refresh()
					await _run_auctions()
			"auction":  # give Player 1 a lot, then sell it back to the bank
				var free: Array = game.lots.keys().filter(func(id): return game.lots[id].owner < 0)
				if not free.is_empty():
					game.lots[free[0]].owner = p.index
					game.sell_lot_to_bank(p, free[0])
					_refresh()
					await _run_auctions()
			"whole":  # all of a free block but one is yours; stand on the last
				for block in game.board.blocks:
					var ids := game.board.lots_in_block(block)
					if ids.all(func(id): return game.lots[id].owner in [-1, p.index]):
						for id in ids.slice(0, ids.size() - 1):
							game.lots[id].owner = p.index
						p.position = ids[-1]
						game.lots[ids[-1]].owner = -1
						p.cash = maxi(p.cash, game.lot_value(ids[-1]) + 500)
						_refresh()
						await _land(p)
						break
			"invest":
				var mine: Array = game.lots.keys().filter(func(id): return game.lots[id].owner == p.index)
				if mine.is_empty():
					var free: Array = game.lots.keys().filter(func(id): return game.lots[id].owner < 0)
					game.lots[free[0]].owner = p.index
					mine = [free[0]]
				p.position = mine[0]
				game.invested.clear()
				_refresh()
				await _land(p)
			"payday":  # every suit, three steps short of the Depot, then walk 4
				p.punches.assign(game.board.relay_ids())
				var at := game.board.depot
				for k in 3:
					for s in game.board.spaces:
						if at in s.next and s.type != "detour":
							at = s.id
							break
				p.position = at
				p.came_from = -1
				game.moves_left = 4
				_refresh()
				await _plan_route(p)
				if not game.game_over:
					await _land(p)
			"goal":
				p.cash += maxi(0, game.board.goal - game.net_worth(p)) + 100
			"cash":
				p.cash += 1000
			"home":
				break
		_refresh()
		await _hold_for_shows()
	_start_menu()


func _run() -> void:
	while not game.game_over:
		await _play_turn()
		game.end_turn()
	_refresh()
	await _ask(null, _final_standings(), [["New game", true]])
	_start_menu()


## Who won and why, then every player by net worth.
func _final_standings() -> String:
	var w := game.players[game.winner].name if game.winner >= 0 else "Nobody"
	var lines := PackedStringArray()
	var broke := game.players.filter(func(q): return q.broke)
	if broke.is_empty():
		lines.append("Game over: %s wins!" % w)
	else:
		lines.append("Game over: %s went bankrupt." % broke[0].name)
		lines.append("%s wins with the highest net worth." % w)
	var order := game.players.duplicate()
	order.sort_custom(func(a, b): return game.net_worth(a) > game.net_worth(b))
	for q in order:
		lines.append("   %s  %s" % [q.name, "BANKRUPT" if q.broke else "net %d G" % game.net_worth(q)])
	return "\n".join(lines)


func _play_turn() -> void:
	var p := game.current_player()
	game.start_turn()
	_refresh()
	lot_panel.visible = false
	await _turn_intro(p)
	if game.take_skip():
		_refresh()
		await _wait(CPU_DELAY)
		return
	var goal_note := "  (at goal: reach the Depot to win!)" if p.at_goal else ""
	await _move_and_land(p, "%s's turn.%s" % [p.name, goal_note])


## Between turns: the whole board for TURN_OVERVIEW seconds, then "X's turn!"
## pops up in the middle in their colour while the camera moves in on them,
## and they play TURN_ZOOM_IN seconds later.
func _turn_intro(p: PlayerState) -> void:
	board_view.overview(TURN_OVERVIEW)
	await _wait(TURN_OVERVIEW)
	turn_label.text = "%s's turn!" % p.name
	turn_label.add_theme_color_override("font_color", BoardView.PLAYER_COLORS[p.index].lightened(0.25))
	turn_label.pivot_offset = turn_label.size / 2
	turn_label.scale = Vector2.ONE * 0.3
	turn_label.modulate.a = 1.0
	turn_label.visible = true
	create_tween().tween_property(turn_label, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(TURN_ZOOM_IN - 0.3)
	var tw := create_tween()
	tw.tween_property(turn_label, "modulate:a", 0.0, 0.3)
	await tw.finished
	turn_label.visible = false


## Before rolling a human may sell bonds, sell lots to the bank and trade with
## other players, as often as they like; Roll ends the menu. CPUs just roll.
func _turn_menu(p: PlayerState, prompt: String) -> void:
	while true:
		var choices := [["Roll", "roll"], ["View bonds", "view"]]
		if not p.bonds.is_empty():
			choices.append(["Sell bonds", "bonds"])
		if game.lots.values().any(func(l): return l.owner == p.index):
			choices.append(["Sell a lot to the bank", "lot"])
		if game.players.any(func(q): return q != p and not q.broke):
			choices.append(["Trade with a player", "trade"])
		var pick = await _ask(p, prompt, choices, "roll")
		match pick:
			"roll":
				return
			"view":
				await _market(p, "Bonds: every block's price and who holds what.", false, false, true)
			"bonds":
				await _market(p, "Sell bonds: pick a block and how many.", false, true)
			"lot":
				await _sell_lot(p)
				await _run_auctions()
			"trade":
				await _trade(p)
		_refresh()
		await _hold_for_shows()
		if game.game_over or p.broke:
			return


## Sell one of p's lots back to the bank (or go back).
func _sell_lot(p: PlayerState) -> void:
	var choices := []
	for id in game.lots:
		if game.lots[id].owner == p.index:
			choices.append(["%s (%s): %d G" % [game._label(id), GameState.TIER_NAMES[game.tier(id)],
					game.bank_price(id)], id])
	choices.append(["Back", -1])
	var id: int = await _ask(p, "Sell which lot to the bank? It pays %d%% of the lot's value." %
			roundi(GameState.BANK_SELL_RATE * 100), choices)
	if id < 0:
		return
	var yes: bool = await _ask(p, "Sell %s for %d G? It goes back on sale with no building." % [
			game._label(id), game.bank_price(id)], [["Sell", true], ["Keep it", false]])
	if yes:
		game.sell_lot_to_bank(p, id)


## p offers another player a trade of lots and/or G; they accept or decline
## (a human on this screen, a CPU by Cpu.accepts_trade).
func _trade(p: PlayerState) -> void:
	var choices := []
	for q in game.players:
		if q != p and not q.broke:
			choices.append([q.name, q.index])
	choices.append(["Back", -1])
	var other: int = await _ask(p, "Trade with whom?", choices)
	if other < 0:
		return
	var q := game.players[other]
	var offer = await _build_offer(p, q)
	if offer == null:
		return
	var gives := game._trade_text(offer.give_lots, offer.give_g)
	var gets := game._trade_text(offer.get_lots, offer.get_g)
	var yes: bool
	if q.is_cpu:
		prompt_label.text = "%s is thinking about it..." % q.name
		await _wait(CPU_DELAY * 1.5)
		yes = Cpu.accepts_trade(game, q, offer.get_lots, offer.get_g, offer.give_lots, offer.give_g)
	else:
		yes = await _ask(q, "%s: %s offers you %s for %s. Accept?" % [q.name, p.name, gives, gets],
				[["Accept", true], ["Decline", false]])
	if yes:
		game.trade(p, q, offer.give_lots, offer.give_g, offer.get_lots, offer.get_g)
		_refresh()
		await _settle_debts()  # G past someone's cash is paid by selling bonds
	else:
		game._note("%s turns down %s's trade" % [q.name, p.name], "info", q.index)
	_refresh()
	await _ask(p, "%s %s the trade." % [q.name, "accepts" if yes else "declines"], [["OK", true]])


## The trade builder: p ticks lots and sets G on both sides. Returns the offer
## {"give_lots", "give_g", "get_lots", "get_g"}, or null if cancelled.
func _build_offer(p: PlayerState, q: PlayerState):
	_offer = {"give_lots": [], "give_g": 0, "get_lots": [], "get_g": 0}
	lot_panel.visible = false
	trade_panel.visible = true
	for c in buttons.get_children():
		c.queue_free()
	prompt_label.text = "Build your offer to %s, then Propose." % q.name
	var result = null
	while true:
		_fill_trade(p, q)
		var act: Array = await trade_action
		match act[0]:
			"give_lot", "get_lot":
				var list: Array = _offer.give_lots if act[0] == "give_lot" else _offer.get_lots
				if act[1] in list:
					list.erase(act[1])
				else:
					list.append(act[1])
			"give_g":
				_offer.give_g = clampi(_offer.give_g + act[1], 0, maxi(0, p.cash + game.bond_worth(p)))
			"get_g":
				_offer.get_g = clampi(_offer.get_g + act[1], 0, maxi(0, q.cash + game.bond_worth(q)))
			"propose":
				result = _offer
				break
			"cancel":
				break
	trade_panel.visible = false
	return result


## The dice block spins over p's head through the turn menu; Roll (or, for a
## CPU, a moment's pause) punches it and it shows the roll before p moves.
func _move_and_land(p: PlayerState, prompt: String) -> void:
	board_view.show_block(p.index)
	await _turn_menu(p, prompt)
	if game.game_over or p.broke:
		board_view.clear_block()
		return
	if p.is_cpu:
		await _wait(CPU_DELAY)
	var rolled := game.roll()
	await board_view.hit_block(p.index, rolled)
	_refresh()
	if p.is_cpu:
		var walked := 0
		while game.moves_left > 0 and not game.game_over:
			var opts := game.options()
			var to := opts[0]
			if opts.size() > 1:
				to = await _choose_branch(p, opts)
			game.step(to)
			sfx.step(walked)
			walked += 1
			_refresh()
			_show_space_info(p.position)
			await _hold_for_shows()
			await _wait(STEP_DELAY)
	else:
		await _plan_route(p)
	if game.game_over:
		return
	await _land(p)


## A human walks their roll one space at a time: Back undoes a step, and the
## last step asks "Go here?". Nothing on the way counts until it is confirmed;
## then the route is played through the rules (suits, PAYDAY, ...).
func _plan_route(p: PlayerState) -> void:
	var total := game.moves_left
	var path: Array[int] = []
	_planning = true
	_route_suits = p.punches.duplicate()
	_route_any = p.any_suits
	_route_payday = 0
	_payday_undo = {}
	board_view.zoom_for_highlight = false
	while true:
		var here: int = path[-1] if not path.is_empty() else p.position
		var prev: int = p.came_from
		if path.size() >= 2:
			prev = path[-2]
		elif path.size() == 1:
			prev = p.position
		board_view.preview(p.index, here)
		board_map.preview[p.index] = here
		board_map.queue_redraw()
		_show_space_info(here)
		await _update_route_suits(p, path, path.size() == total)
		if path.size() == total:
			board_view.highlight = []
			board_view.sync()
			_keys = {"ui_accept": true, "back": false, _dir(here, prev): false}
			var go: bool = await _ask(p, "Go here? (%s)" % _space_title(here),
					[["Go here", true], ["Back", false]])
			if go:
				break
			path.pop_back()
			sfx.back()
			continue
		var opts := game.options_from(here, prev, p.reverse_move, p.reverse_first and path.is_empty())
		board_view.highlight = opts
		board_view.sync()
		var choices := []
		for o in opts:
			choices.append(["Step to %s" % _space_title(o), o])
		if not path.is_empty():
			choices.append(["Back", -1])
		_keys = {}
		if not path.is_empty():
			_keys[_dir(here, prev)] = -1
			_keys["back"] = -1
		for o in opts:
			_keys[_dir(here, o)] = o
		if opts.size() == 1:
			_keys["ui_accept"] = opts[0]
		var pick: int = await _ask(p, "%d of %d moves left." % [total - path.size(), total], choices)
		if pick == -1:
			path.pop_back()
			sfx.back()
		else:
			path.append(pick)
			sfx.step(path.size() - 1)
	_keys = {}
	board_view.highlight = []
	board_view.zoom_for_highlight = true
	board_view.clear_preview(p.index)
	board_map.preview.erase(p.index)
	_planning = false
	_confirming = true  # suits and a PAYDAY already showed while planning
	for to in path:
		game.step(to)
		_refresh()
		await _hold_for_shows()
		if game.game_over:
			break
	_confirming = false
	_route_payday = 0
	if not _payday_undo.is_empty():
		_payday_mark = game.events.size()  # its Bond Market already opened while planning
	_payday_undo = {}


## Suits the player would hold after walking `path`, by the rules: each new
## suit is collected, and passing the Depot with all of them is a PAYDAY that
## resets them. Shows gains and losses as they happen. A PAYDAY passed on the
## way opens the Bond Market there and then (`at_end`: the route ends here, so
## landing will open it instead); backing off the Depot undoes those trades.
func _update_route_suits(p: PlayerState, path: Array[int], at_end := false) -> void:
	var suits: Array = p.punches.duplicate()
	var any := p.any_suits
	var four := game.board.relay_ids().size()
	var payday := 0
	for id in path:
		var s := game.space(id)
		if s.type == "relay" and id not in suits:
			suits.append(id)
		elif s.type == "depot" and suits.size() + any >= four:
			any -= maxi(0, four - suits.size())  # only the cards filling a gap
			suits.clear()
			if payday == 0:
				payday = game.payday_amount(p)
	_route_any = any
	# PAYDAY as the Depot is passed, taken back if the route backs off it.
	if payday > 0 and _route_payday == 0:
		board_view.payday(p.index, payday)
		music.payday()
		_payday_shown = true  # the bond menu waits for it (_payday_market)
	elif payday == 0 and _route_payday > 0:
		board_view.popup_at_space(game.board.depot, "-%d G" % _route_payday, Color("#8a8a96"))
	var was := _route_payday
	_route_payday = payday
	if payday == 0 and not _payday_undo.is_empty():
		_undo_payday_market(p)
	elif payday > 0 and was == 0 and not (at_end and path[-1] == game.board.depot):
		await _payday_market(p, payday)
	for r in suits:
		if r not in _route_suits:
			var m: String = game.space(r).mark
			board_view.popup_at_space(r, "%s %s!" % [BoardView.SUIT_SYMBOLS.get(m, ""), m.to_upper()],
					game.space(r).color)
	for r in _route_suits:
		if r not in suits:
			board_view.popup_at_space(r, "-%s" % BoardView.SUIT_SYMBOLS.get(game.space(r).mark, ""),
					Color("#8a8a96"))
	_route_suits = suits
	_refresh()

## Which arrow (as a ui_* action) points from space `a` to space `b` on screen;
## the camera always looks the same way, so board up is screen up.
func _dir(a: int, b: int) -> String:
	var dx: float = game.space(b).x - game.space(a).x
	var dy: float = game.space(b).y - game.space(a).y
	if absf(dx) >= absf(dy):
		return "ui_right" if dx > 0 else "ui_left"
	return "ui_down" if dy > 0 else "ui_up"


## While paused, keys other than Escape do nothing (not even a minigame's Enter).
func _input(event: InputEvent) -> void:
	if pause_panel.visible and event is InputEventKey and event.keycode != KEY_ESCAPE:
		get_viewport().set_input_as_handled()


## Escape opens (or closes) the pause box. M opens the map. Arrow keys (or
## d-pad) step while planning a route; the arrow back the way you came,
## Backspace or the pad's B undo a step; Enter confirms "Go here?".
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_set_paused(not pause_panel.visible)
		return
	if pause_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M \
			and not map_button.disabled:
		get_viewport().set_input_as_handled()
		_toggle_map()
		return
	if _keys.is_empty() or (_map_open and slot_panel.visible):
		return  # no stopping the Bond reel while the map hides it
	var key := ""
	for action in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept"]:
		if event.is_action_pressed(action):
			key = action
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed
			and not event.echo and event.keycode == KEY_BACKSPACE):
		key = "back"
	if key != "" and _keys.has(key):
		get_viewport().set_input_as_handled()
		chosen.emit(_keys[key])

## A short name for a space on buttons: the lot's name, the suit, or the type.
func _space_title(id: int) -> String:
	var s := game.space(id)
	match s.type:
		"lot":
			return s.name
		"relay":
			return "%s %s" % [BoardView.SUIT_SYMBOLS.get(s.mark, ""), s.mark]
		"wildcard":
			return "Wildcard ?"
	return s.type.capitalize()


## Lot details shown while a figure stands on (or walks over) a lot.
func _build_lot_panel(parent: Control) -> void:
	lot_panel = PanelContainer.new()
	lot_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)  # up out of the minimap's way
	lot_panel.offset_left = 12
	lot_panel.offset_top = 12
	lot_panel.offset_right = 232
	lot_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2a2f3a", 0.95)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(12)
	lot_panel.add_theme_stylebox_override("panel", bg)
	parent.add_child(lot_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	lot_panel.add_child(col)
	lot_ribbon = Label.new()
	lot_ribbon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lot_ribbon.add_theme_font_size_override("font_size", 16)
	col.add_child(lot_ribbon)
	lot_name = Label.new()
	lot_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lot_name.add_theme_font_size_override("font_size", 20)
	col.add_child(lot_name)
	for key in LOT_ROWS:
		var caption := Label.new()
		caption.text = key
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		caption.add_theme_font_size_override("font_size", 15)
		caption.add_theme_color_override("font_color", Color("#dfe3ea"))
		col.add_child(caption)
		var value := Label.new()
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override("font_size", 22)
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color("#0d0f14")
		bar.set_content_margin_all(3)
		bar.content_margin_right = 10
		value.add_theme_stylebox_override("normal", bar)
		col.add_child(value)
		lot_values[key] = value


func _show_space_info(id: int) -> void:
	var s := game.space(id)
	if s.type != "lot":
		lot_panel.visible = false
		return
	var lot: Dictionary = game.lots[id]
	var owner: int = lot.owner
	var ribbon := StyleBoxFlat.new()
	ribbon.set_corner_radius_all(6)
	ribbon.set_content_margin_all(4)
	if owner >= 0:
		ribbon.bg_color = BoardView.PLAYER_COLORS[owner]
		lot_ribbon.text = "%s  ·  %s" % [game.players[owner].name, GameState.TIER_NAMES[game.tier(id)]]
	else:
		ribbon.bg_color = game.board.blocks[s.block].color
		lot_ribbon.text = "For sale"
	lot_ribbon.add_theme_stylebox_override("normal", ribbon)
	lot_name.text = s.name
	var block: String = s.block
	var total := game.board.lots_in_block(block).size()
	var held := game.owned_in_block(owner, block) if owner >= 0 else 0
	var capital := game.max_capital(id)
	lot_values["Lot value"].text = "%d G" % game.lot_value(id)
	lot_values["Rent"].text = "%d G" % game.rent(id) if owner >= 0 \
			else "%d G" % roundi(game.lot_value(id) * GameState.RENT_MIN)
	var full: bool = game.lots[id].capital >= roundi(game.space(id).price * GameState.MAX_CAPITAL)
	lot_values["Max capital"].text = "Max" if full else "%d G" % capital  # 0: own more of the block
	lot_values["Block"].text = "%s  %d/%d" % [game.board.blocks[block].name, held, total]
	lot_panel.visible = true


## The Bond Market after a PAYDAY not yet traded on (a CPU's walk, a warp, a
## Shortcut...). Landing on the Depot opens it anyway, so not then.
func _payday_since_mark(p: PlayerState) -> bool:
	var found := false
	for i in range(_payday_mark, game.events.size()):
		if game.events[i].kind == "payday" and game.events[i].player == p.index:
			found = true
	_payday_mark = game.events.size()
	return found and p.position != game.board.depot


## While planning: the PAYDAY is not banked until the route is confirmed, so
## its G is lent for the Bond Market and taken back after. Remembers what to
## restore if the route backs off the Depot (_undo_payday_market).
func _payday_market(p: PlayerState, pay: int) -> void:
	_keys = {}
	_payday_undo = {"cash": p.cash, "bonds": p.bonds.duplicate(),
			"pressure": game.bond_pressure.duplicate()}
	p.cash += pay
	_last_cash[p.index] = p.cash  # the PAYDAY popup already showed it
	_route_payday = 0
	await _hold_for_shows()
	await _market(p, "PAYDAY! Trade bonds with your %d G salary." % pay)
	_route_payday = pay
	p.cash -= pay
	_last_cash[p.index] = p.cash
	_refresh()


func _undo_payday_market(p: PlayerState) -> void:
	var changed: bool = p.cash != _payday_undo.cash or p.bonds != _payday_undo.bonds
	p.cash = _payday_undo.cash
	p.bonds = _payday_undo.bonds
	game.bond_pressure = _payday_undo.pressure
	_last_cash[p.index] = p.cash
	_payday_undo = {}
	if changed:
		game._note("%s backs off the Depot: the PAYDAY bond trades are undone" % p.name, "info", p.index)
	_refresh()


func _land(p: PlayerState) -> void:
	if _payday_since_mark(p):
		await _hold_for_shows()  # let the PAYDAY show finish first
		await _market(p, "PAYDAY! Trade bonds?")
		_refresh()
		await _hold_for_shows()
	_show_space_info(p.position)
	var offers := game.land()
	if game.space(p.position).type == "interest":
		board_view.star_rise(p.index, STAR_RISE)
		sfx.play("sparkle")
		await _wait(STAR_RISE * 0.6)
	_refresh()
	await _settle_debts()  # rent or a toll may have left them owing
	if game.game_over:
		return
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
	var invest_offer := {}
	for o in offers:
		match o.kind:
			"buy":
				if await _affordable(p, "%s costs %d G" % [game._label(o.lot), o.cost], o.cost):
					var yes: bool = await _ask(p, "Buy %s for %d G?%s" % [game._label(o.lot), o.cost,
							_on_bonds(p, o.cost)], [["Buy", true], ["Pass", false]],
							Cpu.wants_buy(game, p, o.cost))
					if yes:
						game.buy_lot(p, o.lot)
			"buyout":
				var owner := game.players[o.owner].name
				if await _affordable(p, "Buying %s out costs %d G" % [game._label(o.lot), o.cost], o.cost):
					var yes: bool = await _ask(p, "Buy %s out from %s for %d G?%s" % [game._label(o.lot),
							owner, o.cost, _on_bonds(p, o.cost)], [["Buy out", true], ["Pass", false]],
							Cpu.wants_buyout(game, p, o.lot, o.cost))
					if yes:
						game.buyout(p, o.lot)
			"invest":
				if invest_offer.is_empty():
					invest_offer = o
			"market":
				await _market(p, "Market: trade bonds?")
			"wildcard":
				await _wildcard(p)
			"reroll":
				await _move_and_land(p, "Dice space! %s rolls again." % p.name)
			"minigame":
				await _minigame(p)
			"build":
				await _build_on_plot(p, o.plot)
			"expand":
				board_view.highlight = [o.plot]  # which Shopping Centre (it may be elsewhere)
				board_view.sync()
				var go: bool = await _ask(p, "Expand your Shopping Centre (lit up) for %d G%s? Its fee goes from %d G to %d G." % [
						o.cost, _on_bonds(p, o.cost), Plots.CENTRE_FEES[game.plots[o.plot].level],
						Plots.CENTRE_FEES[game.plots[o.plot].level + 1]],
						[["Expand", true], ["Not now", false]], Plots.cpu_expands(game, p, o.cost))
				board_view.highlight = []
				board_view.sync()
				if go:
					Plots.expand(game, p, o.plot)
			"fly":
				var choices := []
				for id in Plots.fly_targets(game, p.position):
					choices.append([_space_title(id), id])
				var to: int = await _ask(p, "Your Airport: fly where? (free, and you land there)", choices,
						Plots.cpu_fly(game, p))
				game.warp(p, to)
				_refresh()
				await _hold_for_shows()
				if not game.game_over:
					await _land(p)
		_refresh()
		await _hold_for_shows()
		await _settle_debts()
		if game.game_over:
			return
	if not invest_offer.is_empty():
		await _invest(p, invest_offer)


## An empty plot: pick a building (each listed with what it does) or leave it.
func _build_on_plot(p: PlayerState, id: int) -> void:
	# Building is compulsory, unless even cash and bonds can't pay for it.
	if not await _affordable(p, "Building here costs %d G" % Plots.BUILD_COST, Plots.BUILD_COST):
		return
	var choices := []
	for kind in Plots.ORDER:
		var k: Dictionary = Plots.KINDS[kind]
		choices.append(["%s %s\n%s" % [k.icon, k.name, k.line], kind])  # two lines a button
	var kind: String = await _ask(p, "Empty plot! You must build here (%d G%s). What will it be?" % [
			Plots.BUILD_COST, _on_bonds(p, Plots.BUILD_COST)], choices, Plots.cpu_build(game, p))
	if kind != "":
		Plots.build(game, p, id, kind)
		_refresh()
		await _settle_debts()


## False (after telling a human why) if cash and bonds together can't pay `cost`.
func _affordable(p: PlayerState, what: String, cost: int) -> bool:
	if game.can_cover(p, cost):
		return true
	if not p.is_cpu:
		await _ask(p, "%s: more than your cash and bonds together." % what, [["OK", true]])
	return false


## A note for a price only bonds can make up.
func _on_bonds(p: PlayerState, cost: int) -> String:
	return " (you'll sell bonds to cover %d G)" % (cost - p.cash) if p.cash < cost else ""


## Everyone left owing (negative cash) clears it: a human with bonds chooses
## which to sell in the Bond Market, then settle_debt sells lots to the bank
## for anything still owed, or the player is broke.
func _settle_debts() -> void:
	for q in game.players:
		if q.cash >= 0 or q.broke or game.game_over:
			continue
		_refresh()
		await _hold_for_shows()
		if not q.is_cpu and not q.bonds.is_empty():
			await _market(q, "%s owes %d G: sell bonds to pay it." % [q.name, -q.cash], true)
		game.settle_debt(q)
		_refresh()
		await _hold_for_shows()
	await _run_auctions()  # lots sold to the bank to pay up go under the hammer


## Auctions every lot sold back to the bank, one at a time. The winner pays
## from Ready Cash and, if that is short, sells bonds (_settle_debts).
func _run_auctions() -> void:
	while not game.pending_auctions.is_empty() and not game.game_over:
		var a: Dictionary = game.pending_auctions.pop_front()
		if game.lots[a.lot].owner >= 0 or Auction.bidders(game, a.seller).is_empty():
			continue
		lot_panel.visible = false
		var res := await auction_panel.run(game, a.lot, a.seller)
		auction_panel.visible = false
		if res[0] >= 0:
			Auction.settle(game, game.players[res[0]], a.lot, res[1])
		else:
			game._note("No one bids on %s; it stays on sale" % game._label(a.lot), "info", -1, a.lot)
		_refresh()
		await _hold_for_shows()
		await _settle_debts()


## Investing (landing on one of your own lots, a Workshop or your Repair Shop):
## pick any of your lots, then how much to put in, up to what it can take this
## turn; then another lot, until Done. `o.rate` is the price per G of capital.
func _invest(p: PlayerState, o: Dictionary) -> void:
	var rate: float = o.rate
	if p.is_cpu:
		for step in Cpu.invest_plan(game, p, rate):
			game.invest(p, step[0], step[1], rate)
			_refresh()
			await _hold_for_shows()
			await _settle_debts()
		return
	var deal := "" if is_equal_approx(rate, 1.0) else " at %d%% of the price" % roundi(rate * 100)
	while not game.game_over and not p.broke:
		var choices := []
		var lit: Array[int] = []
		for id in game.lots:
			if game.lots[id].owner == p.index and game.invest_limit(id) > 0:
				choices.append(["%s: %s, %d G — up to %d G more" % [game._label(id),
						GameState.TIER_NAMES[game.tier(id)], game.lot_value(id), game.invest_limit(id)], id])
				lit.append(id)
		if choices.is_empty():
			break
		choices.append(["Done", -1])
		board_view.highlight = lit
		board_view.sync()
		var id: int = await _ask(p, "Invest%s in one of your lots (lit up): which? Capital adds to its value and rent, and to its block's bond price. Own more of a block to invest more." % deal, choices)
		if id < 0:
			break
		board_view.highlight = [id]
		board_view.sync()
		_show_space_info(id)
		var limit := game.invest_limit(id)
		var can := floori((p.cash + game.bond_worth(p)) / rate)
		var amounts := []
		for share in [0.25, 0.5, 0.75, 1.0]:
			var a := mini(can, limit if share == 1.0 else roundi(limit * share / 10.0) * 10)
			if a > 0 and a not in amounts:
				amounts.append(a)
		choices = []
		for a in amounts:
			var cost := GameState.invest_cost(a, rate)
			choices.append(["Invest %d G%s%s" % [a, "" if cost == a else " (pay %d G)" % cost,
					_on_bonds(p, cost)], a])
		choices.append(["Back", 0])
		var whole := game.whole_block_owner(game.space(id).block) == p.index
		var amount: int = await _ask(p, "Invest in %s: up to %d G this turn%s (max capital %d G)." % [
				game._label(id), limit, " — whole block, twice the usual" if whole else "",
				game.max_capital(id)], choices)
		if amount > 0:  # one lot and one amount, then done
			game.invest(p, id, amount, rate)
			_refresh()
			await _hold_for_shows()
			await _settle_debts()
			break
	board_view.highlight = []
	board_view.sync()


func _wildcard(p: PlayerState) -> void:
	var slot := await _pick_from_heap(p)
	var cash_before := p.cash
	var patch := game.patch_slots(slot, p.index)  # before taking: a full heap refills
	var id := game.take_from_heap(slot)
	var bonus := p.cash - cash_before
	var c := Wildcards.card(id)
	var color: Color = BoardView.PLAYER_COLORS[p.index]
	_refresh()
	await _spin_tiles(patch, c, bonus, color)
	await _pop_card(c, bonus, patch.size(), color)
	await _ask(p, "%s drew %s." % [p.name, c.name], [["OK", true]], true)
	card_view.visible = false
	heap_panel.visible = false
	music.bonus = false

	var pick = null
	if c.pick != "none":
		pick = await _card_choice(p, id)
	var result := Wildcards.apply(game, p, id, pick)
	_refresh()
	await _hold_for_shows()
	await _settle_debts()
	if game.game_over:
		return
	if result.get("move_again", false):
		await _move_and_land(p, "Rush Hour! %s rolls again." % p.name)
	elif result.get("land_again", false):
		await _land(p)
	elif result.get("minigame", false):
		await _minigame(p, result.get("game", ""))
	elif result.has("invest"):
		await _invest(p, {"rate": result.invest})


## A minigame from an Arcade space or an Arcade Ticket, picked at random, or
## `kind` (a card that names one).
func _minigame(p: PlayerState, kind := "") -> void:
	lot_panel.visible = false
	match kind if kind != "" else Minigames.pick_minigame(game):
		"pick_a_card":
			await _pick_a_card(p)
		"wheel":
			await _chance_wheel(p)
		"race":
			await _critter_race(p)
		_:
			await _scrap_slots(p)


## Critter Race: everyone backs an animal and watches the race; on the podium
## each player's winnings are shown and paid in turn, RACE_PAYOUT apart.
func _critter_race(_p: PlayerState) -> void:  # everyone takes part, in pick order
	music.minigame = "race"
	var picks := await race_game.choose(game)
	var plan := Minigames.race_plan(game)
	await race_game.run(plan, picks)
	for pk in picks:
		var q := game.players[pk[0]]
		var prize := Minigames.race_prize(Minigames.race_place(plan, pk[1]), q.level)
		race_game.show_result(q, pk[1], prize)
		Minigames.apply_prize(game, q, prize, null, Minigames.NAMES.race)
		_refresh()  # the stats and a +G popup show it straight away
		await _wait(RACE_PAYOUT)
	race_game.visible = false
	music.minigame = ""
	await _hold_for_shows()


## Chance Wheel: the dart picks a player and what happens to them.
func _chance_wheel(p: PlayerState) -> void:
	music.minigame = "casino"
	var res := await wheel_game.play(game, p)
	await _wait(2.0)
	wheel_game.visible = false
	music.minigame = ""
	Minigames.wheel_apply(game, p, res[0], res[1], res[2])
	_refresh()
	await _hold_for_shows()
	await _settle_debts()  # a loss can leave them owing


func _pick_a_card(p: PlayerState) -> void:
	var shown := Minigames.card_deal(game)  # the order the prizes are shown in
	var order := Minigames.card_deal(game)  # where they really end up
	music.minigame = "casino"
	var pos := await card_game.play(game, p, shown, order)
	var prize: Dictionary = Minigames.CARD_PRIZES[order[pos]]
	card_game.show_result(prize)
	await _wait(1.8)
	card_game.visible = false
	music.minigame = ""
	Minigames.apply_prize(game, p, prize, null, Minigames.NAMES.pick_a_card)
	_refresh()
	await _hold_for_shows()


func _scrap_slots(p: PlayerState) -> void:
	music.minigame = "casino"
	var grid := await slots.play(game, p)
	var res := Minigames.slot_result(grid)
	slots.show_result(grid, res)
	await _wait(1.8)
	var block := ""
	var warp_to := -1
	var choices := []
	if res.bonds > 0:  # the reel picks the block
		var n: int = Minigames.SLOT_BONDS * res.bonds
		slots.visible = false
		block = await _slot_machine(p, {"name": "Free Bonds", "text": "%d bonds in a random block" % n}, n)
	if res.warp:
		choices = []
		for id in Minigames.warp_targets(game):
			choices.append([_space_title(id), id])
		warp_to = await _ask(p, "Warp where?", choices, Minigames.cpu_warp(game, p))
	slots.visible = false
	music.minigame = ""
	var result := Minigames.slot_apply(game, p, res, warp_to, block)
	_refresh()
	await _hold_for_shows()
	if result.get("land_again", false) and not game.game_over:
		await _land(p)


func _pick_from_heap(p: PlayerState) -> int:
	lot_panel.visible = false
	heap_panel.visible = true
	music.bonus = true  # until the card has been shown (_wildcard)
	heap_title.text = "%s: pick a card from the Scrap Heap" % p.name
	heap_hint.text = "Combo: a straight line of your cards (across or down) pays %d G for each card after the first." % GameState.PATCH_BONUS
	heap_reveal.text = ""
	heap_reveal.add_theme_font_size_override("font_size", 18)
	for i in heap_buttons.size():
		var b := heap_buttons[i]
		var owner := game.heap_owner[i]
		b.disabled = owner >= 0 or p.is_cpu
		b.tooltip_text = ""
		if owner >= 0:
			b.text = _card_no(game.heap[i])  # its number; the name shows on the big card
			_style_card(b, "owned", BoardView.PLAYER_COLORS[owner])
		else:
			b.text = "?"
			_style_card(b, "back")
			var bonus := game.patch_bonus(game.patch_size(i, p.index))
			if bonus > 0:
				b.text = "?
+%d G" % bonus
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
	if c.pick == "slot":
		return await _slot_machine(p, c)
	var opts := Wildcards.choices(game, p, id)
	if opts.is_empty():
		return null
	var cpu = Wildcards.cpu_pick(game, p, id)
	match c.pick:
		"space":
			return await _pick_space(p, c, opts, cpu)
		"optional":
			return await _ask(p, "%s: %s" % [c.name, c.text], [["Go to the Bank", true], ["Stay here", null]], cpu)
		"relay":
			var suits := []
			for r in opts:
				var mark: String = game.space(r).mark
				suits.append(["%s %s%s" % [BoardView.SUIT_SYMBOLS.get(mark, ""), mark,
						" (already punched)" if r in p.punches else ""], r])
			board_view.highlight.assign(opts)
			board_view.sync()
			var r = await _ask(p, "%s: jump to which suit space?" % c.name, suits, cpu)
			board_view.highlight = []
			return r
	var choices := []
	var lots_shown: Array[int] = []
	if c.pick not in ["block", "swap", "rival_player"]:  # lots, listed block by block
		opts.sort_custom(func(a, b): return [game.space(a).block, a] < [game.space(b).block, b])
	for o in opts:
		match c.pick:
			"rival_player":
				var q := game.players[o]
				choices.append(["%s (net worth %d G)" % [q.name, game.net_worth(q)], o])
			"block":
				choices.append(["Block %s (bonds %d G, you hold %d)" % [game.board.blocks[o].name,
						game.bond_price(o), p.bonds_in(o)], o])
			"swap":
				choices.append(["Give %s (Block %s), get %s (Block %s)" % [game._label(o[0]),
						game.board.blocks[game.space(o[0]).block].name, game._label(o[1]),
						game.board.blocks[game.space(o[1]).block].name], o])
				lots_shown.append(o[1])
			_:
				var owner := ""
				if game.lots[o].owner != p.index:
					owner = " (%s, rent %d G)" % [game.players[game.lots[o].owner].name, game.rent(o)]
				choices.append(["Block %s · %s%s" % [game.board.blocks[game.space(o).block].name,
						game._label(o), owner], o])
				lots_shown.append(o)
	if c.pick == "swap":
		choices.append(["Don't swap", null])
	board_view.highlight = lots_shown
	board_view.sync()
	var pick = await _ask(p, "%s: choose." % c.name, choices, Wildcards.cpu_pick(game, p, id))
	board_view.highlight = []
	return pick


## Warp Gate: p picks any space but their own by clicking it on the board
## (which pulls back to show it all), or the Bank by its button.
func _pick_space(p: PlayerState, c: Dictionary, opts: Array, cpu) -> int:
	var on_click := func(sid: int):
		if sid in opts:
			chosen.emit(sid)
	board_view.space_clicked.connect(on_click)
	var was := board_view.hold_overview
	board_view.hold_overview = true
	var shortcuts := []
	if game.board.depot in opts:
		shortcuts.append(["The Bank", game.board.depot])
	var pick = await _ask(p, "%s: click any space on the board to warp there." % c.name, shortcuts, cpu)
	board_view.space_clicked.disconnect(on_click)
	board_view.hold_overview = was
	return pick


## View Map / Check Properties, open or closed at any time (button or M): the
## whole board, with every block and its lots listed in the side panel in
## place of the log; clicking a block lights its lots up on the board.
func _toggle_map() -> void:
	if game.board == null:
		return
	_map_open = not _map_open
	map_button.text = "Close Map" if _map_open else VIEW_MAP
	props_scroll.visible = _map_open
	log_box.visible = not _map_open
	board_view.hold_overview = _map_open
	board_map.visible = not _map_open
	overlays.visible = not _map_open
	if _map_open:
		_map_saved = board_view.highlight
		_map_lit = board_view.highlight
		_fill_props()
	elif board_view.highlight == _map_lit:
		board_view.highlight = _map_saved  # nothing else has changed it meanwhile
	board_view.sync()


func _close_map() -> void:
	if _map_open:
		_toggle_map()


func _fill_props() -> void:
	var p := game.current_player()
	for c in props_box.get_children():
		c.queue_free()
	for block in game.board.blocks:
		var info: Dictionary = game.board.blocks[block]
		var lots := game.board.lots_in_block(block)
		var head := Button.new()
		head.text = "■ Block %s   bonds %d G   %s holds %d" % [info.name, game.bond_price(block),
				p.name, p.bonds_in(block)]
		head.alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.focus_mode = Control.FOCUS_NONE
		head.add_theme_color_override("font_color", info.color.lightened(0.35))
		head.add_theme_color_override("font_hover_color", info.color.lightened(0.6))
		head.pressed.connect(func():
			_map_lit = lots
			board_view.highlight = lots
			board_view.sync())
		props_box.add_child(head)
		for lot in lots:
			var l: Dictionary = game.lots[lot]
			var line := _cell("", Color("#9a9aa6"), 14)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			if l.owner >= 0:
				line.text = "      %s: %s's %s, rent %d G" % [game.space(lot).name,
						game.players[l.owner].name, GameState.TIER_NAMES[game.tier(lot)], game.rent(lot)]
				line.add_theme_color_override("font_color", BoardView.PLAYER_COLORS[l.owner])
			else:
				line.text = "      %s: for sale, %d G" % [game.space(lot).name, game.lot_value(lot)]
			props_box.add_child(line)


## The Bond Market. `owing`: opened to clear a debt, so buying is off and Done
## stays locked while cash is negative and there are bonds left to sell.
## `sell_only`: opened from the turn menu, so only selling is allowed.
## `view_only`: View bonds from the turn menu, to look and not trade.
func _market(p: PlayerState, prompt: String, owing := false, sell_only := false,
		view_only := false) -> void:
	if p.is_cpu:
		if view_only:
			return
		Cpu.trade(game, p)
		_refresh()
		await _hold_for_shows()
		return
	prompt_label.text = prompt
	for c in buttons.get_children():
		c.queue_free()
	if _market_block == "" or not game.board.blocks.has(_market_block):
		_market_block = game.board.blocks.keys()[0]
	if owing and p.bonds_in(_market_block) == 0:
		_market_block = p.bonds.keys()[0]
	_market_qty = BOND_LOT
	_market_owing = owing
	_market_sell_only = sell_only
	_market_view_only = view_only
	if sell_only and p.bonds_in(_market_block) == 0 and not p.bonds.is_empty():
		_market_block = p.bonds.keys()[0]
	lot_panel.visible = false
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
				if not market_done.disabled:
					break
		_refresh()
	market_panel.visible = false
	_market_owing = false
	_market_sell_only = false
	_market_view_only = false


## The Bond Bump / Bond Slump reel, shown in the middle of the board.
func _build_slot(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	slot_panel = center
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2a1c28")
	bg.border_color = HEAP_BACK
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", bg)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	slot_title = Label.new()
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_title.add_theme_font_size_override("font_size", 20)
	col.add_child(slot_title)
	for i in 3:
		var cell := Label.new()
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(240, 96 if i == 1 else 44)
		cell.add_theme_font_size_override("font_size", 64 if i == 1 else 28)
		col.add_child(cell)
		slot_cells.append(cell)
	slot_result = Label.new()
	slot_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_result.custom_minimum_size = Vector2(0, 30)
	slot_result.add_theme_font_size_override("font_size", 20)
	col.add_child(slot_result)


## Shows block `i` in the reel window's centre with its neighbours around it.
func _slot_show(blocks: Array, i: int) -> void:
	_slot_index = posmod(i, blocks.size())
	for k in 3:
		var block: String = blocks[posmod(_slot_index + k - 1, blocks.size())]
		var cell := slot_cells[k]
		var box := StyleBoxFlat.new()
		box.bg_color = game.board.blocks[block].color.darkened(0.0 if k == 1 else 0.55)
		box.set_corner_radius_all(6)
		if k == 1:
			box.set_border_width_all(3)
			box.border_color = Color.WHITE
		cell.add_theme_stylebox_override("normal", box)
		cell.text = game.board.blocks[block].name
		cell.add_theme_color_override("font_color", Color.WHITE if k == 1 else Color(1, 1, 1, 0.45))


## Spins freely until _slot_serial moves on.
func _slot_spin(blocks: Array, serial: int) -> void:
	while serial == _slot_serial:
		_slot_show(blocks, _slot_index + 1)
		await _wait(SLOT_STEP)


## Bond Bump / Bond Slump: the reel spins until Stop. Stop is not a timing
## test: the block is drawn at random when it is pressed, and the reel then
## slows down onto that block whatever it was showing.
## `free` > 0: Scrap Slots' free bonds, not a Bump or Slump.
func _slot_machine(p: PlayerState, c: Dictionary, free := 0) -> String:
	var blocks: Array = game.board.blocks.keys()
	slot_title.text = "%s: %s" % [c.name, c.text]
	slot_result.text = ""
	_slot_index = randi() % blocks.size()  # where the reel starts is only for show
	_slot_show(blocks, _slot_index)
	slot_panel.visible = true
	_slot_serial += 1
	_slot_spin(blocks, _slot_serial)
	_keys = {"ui_accept": true}
	await _ask(p, "%s: press Stop to pick the block." % c.name, [["Stop", true]], true)
	_keys = {}
	_slot_serial += 1  # ends the free spin
	var result := Wildcards.draw_block(game)
	var target := blocks.find(result)
	# At least three more turns of the reel, slowing down, ending on the result.
	var steps := posmod(target - _slot_index, blocks.size()) + blocks.size() * 3
	for k in steps:
		_slot_show(blocks, _slot_index + 1)
		await _wait(lerpf(SLOT_STEP, SLOT_SETTLE, pow(float(k + 1) / steps, 2.5)))
	var up: bool = c.name == "Bond Bump" or free > 0
	slot_result.text = "Block %s bonds %s!" % [game.board.blocks[result].name,
			"rise" if up else "fall"]
	if free > 0:
		slot_result.text = "%d Block %s bonds!" % [free, game.board.blocks[result].name]
	slot_result.add_theme_color_override("font_color", KIND_COLORS.gain if up else KIND_COLORS.loss)
	await _wait(1.2)
	slot_panel.visible = false
	return result


## The drawn card, shaped like a playing card on a bright background for its
## kind (CardArt.CARD_COLOURS): just a few characters across the top ("+60G")
## and the picture in a white-framed square. Under the card, a text box with
## its name, what it does and the combo money.
func _build_card_view(parent: Control) -> void:
	card_view = CenterContainer.new()
	card_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_view.visible = false
	parent.add_child(card_view)
	card_pop = VBoxContainer.new()  # the card and the text box under it, popping in together
	card_pop.add_theme_constant_override("separation", 12)
	card_view.add_child(card_pop)
	card_box = PanelContainer.new()
	card_box.custom_minimum_size = CARD_SIZE
	card_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_pop.add_child(card_box)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	card_box.add_child(col)
	card_caption = Label.new()  # big, chunky, cartoony numbers
	var chunky := FontVariation.new()
	chunky.base_font = ThemeDB.fallback_font
	chunky.variation_embolden = 1.1
	card_caption.add_theme_font_override("font", chunky)
	card_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	card_caption.add_theme_color_override("font_color", Color.WHITE)
	card_caption.add_theme_constant_override("outline_size", 18)
	card_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	card_caption.add_theme_constant_override("shadow_offset_x", 3)
	card_caption.add_theme_constant_override("shadow_offset_y", 5)
	card_caption.add_theme_constant_override("shadow_outline_size", 18)
	col.add_child(card_caption)
	var frame := PanelContainer.new()  # the picture's white frame
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color.WHITE
	rim.set_corner_radius_all(12)
	rim.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", rim)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(frame)
	card_art = CardArt.new()
	card_art.with_caption = false
	card_art.custom_minimum_size = CARD_ART_SIZE
	frame.add_child(card_art)
	var text_box := PanelContainer.new()  # under the card: its name and what it does
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#fffdf6")
	box.border_color = Color("#3a1030")
	box.set_border_width_all(3)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12)
	text_box.add_theme_stylebox_override("panel", box)
	text_box.custom_minimum_size = Vector2(CARD_TEXT_WIDTH, 0)
	card_pop.add_child(text_box)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	text_box.add_child(lines)
	card_name = _card_text(22)
	lines.add_child(card_name)
	card_text = _card_text(17)
	lines.add_child(card_text)
	card_bonus = _card_text(16)
	lines.add_child(card_bonus)


## A card's unique number, 1 to 128 (its place in Wildcards.CARDS).
func _card_no(id: int) -> String:
	return str(id + 1)


func _card_text(font_size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("#3a1030"))
	return l


## The picked tile and every card in the patch it joins spin in the grid while
## the combo money counts up; then the picked tile lands face up.
func _spin_tiles(slots: Array[int], c: Dictionary, bonus: int, color: Color) -> void:
	var picked: Button = heap_buttons[slots[0]]
	picked.set_meta("face_up", false)
	for s in slots:
		heap_buttons[s].pivot_offset = heap_buttons[s].size / 2
	heap_reveal.add_theme_font_size_override("font_size", 26)
	var combo := slots.size() > 1
	heap_reveal.add_theme_color_override("font_color", KIND_COLORS.gain if combo else Color("#c9a6bd"))
	heap_reveal.text = "" if combo else "No combo"
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var angle := t * TILE_HALF_TURNS * PI
		var sx := maxf(0.05, absf(cos(angle)))
		for s in slots:
			heap_buttons[s].scale.x = sx
		# The picked tile shows its face for the final half-turn.
		if angle >= (TILE_HALF_TURNS - 0.5) * PI and not picked.get_meta("face_up", false):
			picked.set_meta("face_up", true)
			picked.text = _card_no(Wildcards.CARDS.find(c))  # it lands showing its number
			_style_card(picked, "face", color)
		if combo:
			heap_reveal.text = "+%d G COMBO! (%d cards)" % [roundi(bonus * minf(1.0, t * 1.4)), slots.size()],
		0.0, 1.0, TILE_SPIN).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw.finished
	for s in slots:
		heap_buttons[s].scale = Vector2.ONE


## The drawn card pops up big in the middle of the board, face up, with its
## caption, picture, effect and the combo money earned.
func _pop_card(c: Dictionary, bonus: int, patch: int, color: Color) -> void:
	card_view.visible = true
	_card_face(c.name, color)
	var said: Array = CardScene.caption(c.name)
	card_caption.text = said[0]
	card_caption.add_theme_color_override("font_outline_color", (said[1] as Color).darkened(0.25))
	# Long ones (four suits, "+15G/tier") shrink to fit across the card.
	card_caption.add_theme_font_size_override("font_size", CAPTION_SIZE if said[0].length() <= 5 else roundi(CAPTION_SIZE * 5.5 / said[0].length()))
	card_name.text = "%s  %s" % [_card_no(Wildcards.CARDS.find(c)), c.name.to_upper()]
	card_art.card = c.name
	card_text.text = c.text
	if bonus > 0:
		card_bonus.text = "+%d G combo bonus (%d cards)" % [bonus, patch]
		card_bonus.add_theme_color_override("font_color", Color("#1f9a45"))
	else:
		card_bonus.text = "No combo"
		card_bonus.add_theme_color_override("font_color", Color("#9a7a90"))
	card_pop.pivot_offset = card_pop.get_combined_minimum_size() / 2
	var tw := create_tween()
	tw.tween_property(card_pop, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


## The card's background in its kind's bright colour, a white rim, and a glow
## in the colour of the player who drew it.
func _card_face(card: String, color: Color) -> void:
	var box := StyleBoxFlat.new()
	var bright: Color = CardArt.CARD_COLOURS[CardScene.mood(card)]
	box.bg_color = bright
	box.border_color = Color.WHITE
	box.set_border_width_all(7)
	box.set_corner_radius_all(18)
	box.set_content_margin_all(16)
	box.shadow_color = Color(color, 0.75)
	box.shadow_size = 14
	card_box.add_theme_stylebox_override("panel", box)


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

	# Minimap: hovering a block's name lights up its lots (else the selected block).
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 16)
	col.add_child(map_row)
	market_map = Minimap.new()
	map_row.add_child(market_map)
	var lots_col := VBoxContainer.new()
	lots_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_row.add_child(lots_col)
	market_lots_title = Label.new()
	market_lots_title.add_theme_font_size_override("font_size", 18)
	lots_col.add_child(market_lots_title)
	market_lots = GridContainer.new()
	market_lots.add_theme_constant_override("h_separation", 14)
	market_lots.add_theme_constant_override("v_separation", 2)
	lots_col.add_child(market_lots)

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
	market_done = _market_button("Done", ["done"])
	trade.add_child(market_done)

	var note := Label.new()
	note.text = ("Each bond pays %d%% of every rent paid in its block. " +
			"Trading %d or more at once moves the price %d%%.") % [
			roundi(GameState.DIVIDEND_RATE * 100), GameState.BIG_BOND_TRADE,
			roundi(GameState.BOND_PRESSURE * 100)]
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("#8fb0ab"))
	col.add_child(note)


## The trade builder: what you give on the left, what you ask for on the
## right (lots to tick, G to set), then Propose or Cancel.
func _build_trade(parent: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	parent.add_child(center)
	trade_panel = center
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1c2230")
	bg.border_color = Color("#6f8fe8")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	trade_title = Label.new()
	trade_title.add_theme_font_size_override("font_size", 22)
	col.add_child(trade_title)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 24)
	col.add_child(sides)
	for side in 2:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(300, 0)
		box.add_theme_constant_override("separation", 4)
		sides.add_child(box)
		trade_sides.append(box)
	trade_summary = Label.new()
	trade_summary.add_theme_color_override("font_color", Color("#bcc8e8"))
	col.add_child(trade_summary)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	trade_propose = _trade_button("Propose", ["propose"])
	trade_propose.custom_minimum_size = Vector2(140, 0)
	row.add_child(trade_propose)
	row.add_child(_trade_button("Cancel", ["cancel"]))


func _trade_button(text: String, act: Array) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): trade_action.emit(act))
	return b


## Redraws both sides of the offer: whose lots, which are ticked, how much G.
func _fill_trade(p: PlayerState, q: PlayerState) -> void:
	trade_title.text = "Trade — %s with %s" % [p.name, q.name]
	var sides := [[p, "You give", "give"], [q, "You get from %s" % q.name, "get"]]
	for side in 2:
		var box: VBoxContainer = trade_sides[side]
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
		var who: PlayerState = sides[side][0]
		var kind: String = sides[side][2]
		var chosen: Array = _offer.give_lots if kind == "give" else _offer.get_lots
		var head := _cell(sides[side][1], BoardView.PLAYER_COLORS[who.index].lightened(0.3), 18)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(head)
		var owned: Array = game.lots.keys().filter(func(id): return game.lots[id].owner == who.index)
		if owned.is_empty():
			var none := _cell("No lots", Color("#7a8299"), 14)
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			box.add_child(none)
		for id in owned:
			var cb := CheckBox.new()
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = id in chosen
			cb.text = "%s  Block %s, %s, %d G" % [game.space(id).name,
					game.board.blocks[game.space(id).block].name,
					GameState.TIER_NAMES[game.tier(id)], game.lot_value(id)]
			cb.add_theme_color_override("font_color",
					game.board.blocks[game.space(id).block].color.lightened(0.4))
			cb.toggled.connect(func(_on): trade_action.emit(["%s_lot" % kind, id]))
			box.add_child(cb)
		var g_row := HBoxContainer.new()
		g_row.add_theme_constant_override("separation", 4)
		box.add_child(g_row)
		var amount: int = _offer.give_g if kind == "give" else _offer.get_g
		var label := _cell("G: %d" % amount, Color("#ffe48a"), 18)
		label.custom_minimum_size = Vector2(90, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		g_row.add_child(label)
		for d in [-100, -10, 10, 100]:
			g_row.add_child(_trade_button("%+d" % d, ["%s_g" % kind, d]))
		var cash := _cell("(cash %d G, with bonds %d G)" % [who.cash, who.cash + game.bond_worth(who)],
				Color("#7a8299"), 13)
		g_row.add_child(cash)
	var give_v: int = _offer.give_g
	for id in _offer.give_lots:
		give_v += game.lot_value(id)
	var get_v: int = _offer.get_g
	for id in _offer.get_lots:
		get_v += game.lot_value(id)
	trade_summary.text = "You give %d G of value · you get %d G of value" % [give_v, get_v]
	trade_propose.disabled = give_v == 0 and get_v == 0


func _market_button(text: String, act: Array) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): market_action.emit(act))
	return b


## Points the market's minimap at `block` and lists its lots beside it.
func _map_block(block: String) -> void:
	if market_map.game != game:
		market_map.show_board(game)
	market_map.set_focus(block)
	market_map.queue_redraw()  # owners and positions may have changed
	var info: Dictionary = game.board.blocks[block]
	market_lots_title.text = "Block %s" % info.name
	market_lots_title.add_theme_color_override("font_color", info.color.lightened(0.35))
	for c in market_lots.get_children():
		market_lots.remove_child(c)
		c.queue_free()
	var lots := game.board.lots_in_block(block)
	market_lots.columns = lots.size() + 1
	var grey := Color("#8fb0ab")
	market_lots.add_child(_cell("", grey, 14))
	for lot in lots:
		var owner: int = game.lots[lot].owner
		market_lots.add_child(_cell(game.space(lot).name,
				BoardView.PLAYER_COLORS[owner] if owner >= 0 else Color("#c9c9d2"), 14))
	for row in ["Owner", "Building", "Lot value", "Rent", "Max capital"]:
		market_lots.add_child(_cell(row, grey, 14))
		for lot in lots:
			var l: Dictionary = game.lots[lot]
			var text := ""
			match row:
				"Owner":
					text = game.players[l.owner].name if l.owner >= 0 else "for sale"
				"Building":
					text = GameState.TIER_NAMES[game.tier(lot)] if l.owner >= 0 else "–"
				"Lot value":
					text = "%d G" % game.lot_value(lot)
				"Rent":
					text = "%d G" % (game.rent(lot) if l.owner >= 0
							else roundi(game.lot_value(lot) * GameState.RENT_MIN))
				"Max capital":
					var cap := game.max_capital(lot)
					text = "%d G" % cap if cap > 0 else "Max"
			market_lots.add_child(_cell(text, Color.WHITE, 14))


func _fill_market(p: PlayerState) -> void:
	_map_block(_market_block)
	market_title.text = ("Sell Bonds — %s  (cash %d G)" if _market_sell_only
			else "Bonds — %s  (cash %d G)" if _market_view_only
			else "Bond Market — %s  (cash %d G)") % [p.name, p.cash]
	for c in market_grid.get_children():
		market_grid.remove_child(c)
		c.queue_free()
	# Fixed columns, then one per player (bonds held), then what yours are worth.
	market_grid.columns = MARKET_HEADERS.size() + game.players.size() + 1
	for h in MARKET_HEADERS:
		var l := Label.new()
		l.text = h
		l.add_theme_color_override("font_color", Color("#8fb0ab"))
		market_grid.add_child(l)
	for q in game.players:
		var l := _cell(q.name, BoardView.PLAYER_COLORS[q.index], 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if q == p:
			l.text = "▸ " + q.name
		market_grid.add_child(l)
	var worth := Label.new()
	worth.text = "Your worth"
	worth.add_theme_color_override("font_color", Color("#8fb0ab"))
	market_grid.add_child(worth)

	var my_total := 0
	for block in game.board.blocks:
		var info: Dictionary = game.board.blocks[block]
		var price := game.bond_price(block)
		var change := game.bond_change(block)
		var mine := p.bonds_in(block)
		my_total += mine * price

		var name_btn := Button.new()
		name_btn.text = info.name
		name_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_btn.custom_minimum_size = Vector2(64, 0)
		var swatch := StyleBoxFlat.new()
		swatch.bg_color = info.color.darkened(0.15 if block == _market_block else 0.55)
		swatch.set_corner_radius_all(4)
		swatch.set_content_margin_all(5)
		if block == _market_block:
			swatch.set_border_width_all(2)
			swatch.border_color = Color.WHITE
		for state in ["normal", "pressed", "focus"]:
			name_btn.add_theme_stylebox_override(state, swatch)
		var hover := swatch.duplicate() as StyleBoxFlat
		hover.bg_color = info.color.darkened(0.05)
		name_btn.add_theme_stylebox_override("hover", hover)
		name_btn.pressed.connect(func(): market_action.emit(["select", block]))
		name_btn.mouse_entered.connect(func(): _map_block(block))
		name_btn.mouse_exited.connect(func(): _map_block(_market_block))
		market_grid.add_child(name_btn)

		market_grid.add_child(_cell("%d G" % price, Color.WHITE, 20))
		if change > 0:
			market_grid.add_child(_cell("▲ %d G" % change, KIND_COLORS.gain))
		elif change < 0:
			market_grid.add_child(_cell("▼ %d G" % -change, KIND_COLORS.loss))
		else:
			market_grid.add_child(_cell("–", KIND_COLORS.info))
		market_grid.add_child(_cell("%d G" % game.block_value(block), KIND_COLORS.info))

		for q in game.players:
			var n := q.bonds_in(block)
			var cell := _cell("%d" % n if n > 0 else "–",
					BoardView.PLAYER_COLORS[q.index].lightened(0.3) if n > 0 else Color("#666666"))
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			market_grid.add_child(cell)
		market_grid.add_child(_cell("%d G" % (mine * price) if mine > 0 else "–", Color("#ffe48a")))

	market_total.text = "Your bonds are worth %d G in total." % my_total
	var price := game.bond_price(_market_block)
	var held := p.bonds_in(_market_block)
	var sell_n := mini(_market_qty, held)
	market_selected.text = "Block %s" % game.board.blocks[_market_block].name
	market_qty_label.text = "%d" % _market_qty
	market_buy.text = "Buy for %d G" % (price * _market_qty)
	market_buy.disabled = _market_owing or _market_sell_only or _market_view_only \
			or p.cash < price * _market_qty
	market_sell.text = "Sell %d for %d G" % [sell_n, price * sell_n] if held > 0 else "Sell"
	market_sell.disabled = held == 0 or _market_view_only
	market_done.disabled = _market_owing and p.cash < 0 and not p.bonds.is_empty()
	if _market_owing:
		if p.cash < 0:
			market_title.text = "Pay your debt — %s owes %d G: sell bonds" % [p.name, -p.cash]
			prompt_label.text = "%s owes %d G: sell bonds to pay it." % [p.name, -p.cash]
			if p.bonds.is_empty():
				prompt_label.text += " No bonds left: lots go to the bank."
		else:
			market_title.text = "Debt paid — %s  (cash %d G)" % [p.name, p.cash]
			prompt_label.text = "Debt paid. Press Done to carry on."


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
	buttons.columns = 2 if choices.size() > LONG_LIST else 1
	for c in choices:
		var b := Button.new()
		b.text = c[0]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = choices.size() > LONG_LIST
		if choices.size() <= LONG_LIST:  # a long label wraps instead of widening the panel
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func(): chosen.emit(c[1]))
		if _ask_hover.is_valid():
			var hover := _ask_hover
			b.mouse_entered.connect(func(): hover.call(c[1]))
		buttons.add_child(b)
	var value = await chosen
	for c in buttons.get_children():
		c.queue_free()
	return value


## A block that has just come into one player's hands: its buildings change
## (gold roofs) one by one with the camera on the block, and a note says so.
func _check_whole_blocks() -> void:
	if game.board == null:
		return
	for block in game.board.blocks:
		var owner := game.whole_block_owner(block)
		if owner >= 0 and _last_whole.get(block, -1) != owner:
			game._note("%s owns all of Block %s! Its lots are worth %d%% more and take twice the investment" % [
					game.players[owner].name, game.board.blocks[block].name,
					roundi((GameState.WHOLE_BLOCK_VALUE - 1.0) * 100)], "own", owner)
			board_view.whole_block(game.board.lots_in_block(block), BLOCK_SHOW)
			music.fanfare(game.board.lots_in_block(block).size())
			_block_shown = true
		_last_whole[block] = owner


## Lets a PAYDAY celebration or a bond ticker spin play out before moving on.
func _hold_for_shows() -> void:
	var seconds := 0.0
	if _payday_shown:
		seconds = PAYDAY_PAUSE
	if _block_shown:
		seconds = maxf(seconds, BLOCK_SHOW)
	_block_shown = false
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
		var price_label := _cell("%d G" % price, Color.WHITE, 20)
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
	_bond_change.clear()
	for p in game.players:
		var d := 0
		for block in changed:
			d += p.bonds_in(block) * (game.bond_price(block) - changed[block])
		if d != 0:
			_bond_change[p.index] = d
	_draw_players()
	await _wait(TICKER_SPIN + TICKER_HOLD)
	if serial == _ticker_serial:
		ticker_panel.visible = false
		_bond_change.clear()
		_draw_players()


func _spin(price_label: Label, move_label: Label, from: int, to: int) -> void:
	var up := to > from
	var color: Color = KIND_COLORS.gain if up else KIND_COLORS.loss
	var digits := str(maxi(from, to)).length()
	price_label.add_theme_color_override("font_color", color.lightened(0.4))
	var tw := create_tween()
	# Reel phase: random numbers of the same width whirring past...
	tw.tween_method(func(_t: float):
		price_label.text = "%d G" % randi_range(int(pow(10, digits - 1)), int(pow(10, digits)) - 1),
		0.0, 1.0, TICKER_SPIN * 0.6)
	# ...then rolling from the old price to the new one, slowing down.
	tw.tween_method(func(t: float): price_label.text = "%d G" % roundi(lerpf(from, to, t)),
		0.0, 1.0, TICKER_SPIN * 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func():
		price_label.text = "%d G" % to
		price_label.add_theme_color_override("font_color", color)
		move_label.text = ("▲ +%d G" if up else "▼ %d G") % (to - from)
		move_label.add_theme_color_override("font_color", color)
		price_label.pivot_offset = price_label.size / 2)
	tw.tween_property(price_label, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(price_label, "scale", Vector2.ONE, 0.12)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The player stats panel; while the ticker is up each bondholder's line also
## shows what the price move made or cost them.
func _draw_players() -> void:
	var lines := PackedStringArray()
	lines.append("[b]Goal %d G[/b]   Turn %d" % [game.board.goal, game.turn])
	var anyone_at_goal := false
	for p in game.players:
		var col: String = BoardView.PLAYER_COLORS[p.index].to_html(false)
		var mark := "> " if p.index == game.current else "   "
		var bonds := 0
		for b in p.bonds:
			bonds += p.bonds[b]
		var held: Array = _route_suits if _planning and p.index == game.current else p.punches
		var pips := ""
		for r in game.board.relay_ids():
			var rc: String = game.space(r).color.to_html(false) if r in held else "4a4a55"
			pips += "[color=#%s]%s[/color]" % [rc, BoardView.SUIT_SYMBOLS.get(game.space(r).mark, "●")]
		var any: int = _route_any if _planning and p.index == game.current else p.any_suits
		if any > 0:
			pips += " [color=#ffd84a]★%s[/color]" % ("" if any == 1 else "×%d" % any)
		if p.commission:
			pips += " [color=#ffcf3a]Star %d%%[/color]" % roundi(GameState.COMMISSION_RATE * 100)
		if p.on_break:
			pips += " [color=#9ab0ff]☾ closed[/color]"
		var change := ""
		var d: int = _bond_change.get(p.index, 0)
		if d != 0:
			var cc: Color = KIND_COLORS.gain if d > 0 else KIND_COLORS.loss
			change = " [color=#%s][b]%s%+d G[/b][/color]" % [cc.to_html(false), "▲" if d > 0 else "▼", d]
		var cash := "%d G" % p.cash
		var pending := _route_payday if _planning and p.index == game.current else 0
		if pending > 0:  # a planned route's PAYDAY, not banked until "Go here"
			cash = "[color=#ffd84a]%d G[/color]" % (p.cash + pending)
		elif p.cash < 0:
			cash = "[color=#%s]%d G[/color]" % [KIND_COLORS.loss.to_html(false), p.cash]
		var net := "net %d G" % (game.net_worth(p) + pending)
		if _at_goal(p, pending):  # in reach of the win: a glowing rainbow
			anyone_at_goal = true
			net = "[outline_size=8][outline_color=#ffffff66][pulse freq=1.6 color=#ffffffb0 ease=-2.0][rainbow freq=0.6 sat=0.75 val=1.0 speed=1.2][b]★ %s ★[/b][/rainbow][/pulse][/outline_color][/outline_size]" % net
		lines.append("%s[color=#%s]■[/color] [b]%s[/b] %s  %s  %s%s" % [
				mark, col, p.name, pips, cash, net, "  BROKE" if p.broke else ""])
		lines.append("      [color=#ffd84a]Lv %d[/color]   [color=#9a9aa6]bonds %d   bonds value %d G[/color]%s" % [
				p.level, bonds, game.bond_worth(p), change])
	players_label.text = "\n".join(lines)
	music.intense = anyone_at_goal and not game.game_over


## Whether p wins on reaching the Depot: at the goal now (they will be at the
## start of their next turn), or at it when this turn of theirs began.
func _at_goal(p: PlayerState, pending := 0) -> bool:
	if p.broke or game.board == null:
		return false
	return game.net_worth(p) + pending >= game.board.goal or (p.index == game.current and p.at_goal)


func _refresh() -> void:
	_check_whole_blocks()
	board_map.queue_redraw()
	_draw_players()
	if _map_open:
		_fill_props()  # owners, rents and prices change while it is open

	var sounds := {}  # each sound once per refresh, however many events ask
	while _shown_events < game.events.size():
		var e: Dictionary = game.events[_shown_events]
		if e.has("sound"):
			sounds[e.sound] = true
		var color := _event_color(e)
		log_box.push_color(color)
		log_box.add_text(e.text + "\n")
		log_box.pop()
		if e.kind != "info":
			banner.text = e.text
			banner.add_theme_color_override("font_color", color)
		if e.kind == "break":  # the Moon: a sunset, then the closed signs show
			board_view.sunset()
			_ticker_shown = true  # hold the turn while it plays
		if e.kind == "payday":
			_last_cash[e.player] = game.players[e.player].cash  # the banner shows it
			if not (_confirming and _route_payday > 0):  # not again if planning showed it
				board_view.payday(e.player, e.get("amount", 0))
				music.payday()
				_payday_shown = true
		if e.kind == "relay" and not _confirming:
			var m: String = game.space(e.space).mark
			board_view.popup_at_space(e.space, "%s %s!" % [BoardView.SUIT_SYMBOLS.get(m, ""), m.to_upper()], color)
		_shown_events += 1

	for p in game.players:
		var diff := p.cash - _last_cash[p.index]
		if diff != 0:
			board_view.popup_at_player(p.index, "%+d G" % diff,
					KIND_COLORS.gain if diff > 0 else KIND_COLORS.loss)
			_last_cash[p.index] = p.cash
	for id in game.lots:
		var tier: int = game.tier(id)
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
	for s in sounds:
		sfx.play(s)
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
