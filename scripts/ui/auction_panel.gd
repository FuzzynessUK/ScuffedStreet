class_name AuctionPanel
extends CenterContainer
## A live lot auction: the lot on a minimap with its value, rent and max
## capital, then a column for each player (the seller can't bid) showing their
## Stocks, Ready Cash and Total. Each bidder has a Bid +10 button (CPUs bid on
## their own); every bid restarts the 5 second timer, and when it runs out the
## highest bid wins. Rules live in Auction; this only runs the clock.

signal bid_pressed(player: int)

const CPU_REACT := Vector2(0.5, 2.6)  # how long a CPU takes to answer a bid
const COLUMN := 150      # width of a player's column
const GAP := 10
const STAGE_HEIGHT := 170.0  # pixels tall, the figures' stage
const STAGE_METRES := 1.12   # metres the stage camera shows top to bottom

var _game: GameState
var _lot := -1
var _seller := -1
var _bid := 0             # highest bid so far (0: none yet)
var _leader := -1         # who made it
var _left := 0.0          # seconds on the clock
var _running := false
var _limits := {}         # CPU player index -> the most it will bid
var _cpu_next := {}       # CPU player index -> seconds until it may bid again
var _title: Label
var _map: Minimap
var _info: GridContainer
var _cols: Array[VBoxContainer] = []
var _bid_label: Label
var _clock: ProgressBar
var _clock_label: Label
var _figures: Array[Character] = []
var _tags: Array[Label3D] = []  # each player's latest bid, over their head


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2a2418")
	bg.border_color = Color("#ffd84a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("#ffd84a"))
	col.add_child(_title)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(top)
	_map = Minimap.new()
	top.add_child(_map)
	_info = GridContainer.new()
	_info.columns = 2
	_info.add_theme_constant_override("h_separation", 16)
	_info.add_theme_constant_override("v_separation", 6)
	top.add_child(_info)
	_build_stage(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in 4:
		var c := VBoxContainer.new()
		c.custom_minimum_size = Vector2(COLUMN, 0)
		c.add_theme_constant_override("separation", 3)
		row.add_child(c)
		_cols.append(c)

	_bid_label = Label.new()
	_bid_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bid_label.add_theme_font_size_override("font_size", 22)
	col.add_child(_bid_label)
	var clock_row := HBoxContainer.new()
	clock_row.add_theme_constant_override("separation", 8)
	col.add_child(clock_row)
	_clock = ProgressBar.new()
	_clock.max_value = Auction.TIMER
	_clock.show_percentage = false
	_clock.custom_minimum_size = Vector2(0, 14)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_row.add_child(_clock)
	_clock_label = Label.new()
	_clock_label.custom_minimum_size = Vector2(50, 0)
	clock_row.add_child(_clock_label)
	bid_pressed.connect(_place_bid)


## The four players' figures on a little stage, each standing over its own
## column (a flat, straight-on camera keeps them lined up), with their latest
## bid above their heads.
func _build_stage(col: VBoxContainer) -> void:
	var centre := CenterContainer.new()
	col.add_child(centre)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(COLUMN * 4 + GAP * 3, STAGE_HEIGHT)
	centre.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#3a3020")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff0d0")
	env.ambient_light_energy = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	root.add_child(sun)
	var floor := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(5, 0.04, 0.8)
	floor.mesh = floor_mesh
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("#8a5a3a")
	floor.material_override = floor_mat
	floor.position = Vector3(0, -0.02, 0)
	root.add_child(floor)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = STAGE_METRES
	cam.position = Vector3(0, STAGE_METRES / 2 - 0.03, 3)
	root.add_child(cam)
	# One metre on stage is this many pixels, so column centres become x positions.
	var px_per_m := STAGE_HEIGHT / STAGE_METRES
	for i in 4:
		var fig := Character.new()
		fig.setup(BoardView.PLAYER_COLORS[i])
		var x_px := (i - 1.5) * (COLUMN + GAP)
		fig.position = Vector3(x_px / px_per_m, 0, 0)
		fig.scale = Vector3.ONE * 1.25
		root.add_child(fig)
		_figures.append(fig)
		var tag := Label3D.new()
		tag.font_size = 36
		tag.pixel_size = 0.004
		tag.outline_size = 10
		tag.position = Vector3(fig.position.x, 0.98, 0)  # clear of a raised hand
		root.add_child(tag)
		_tags.append(tag)


## Pops player i's bid up above their head; anyone outbid goes grey.
func _show_tag(i: int) -> void:
	for k in _tags.size():
		if k != i and _tags[k].text.ends_with(" G"):
			_tags[k].modulate = Color(0.6, 0.6, 0.6, 0.7)
	var tag := _tags[i]
	tag.text = "%d G" % _bid
	tag.modulate = BoardView.PLAYER_COLORS[i].lightened(0.35)
	tag.scale = Vector3.ONE * 1.7
	var tw := create_tween()
	tw.tween_property(tag, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _line(text: String, colour: Color, size := 15) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.add_theme_font_size_override("font_size", size)
	return l


## The lot's figures beside the minimap.
func _fill_info() -> void:
	for c in _info.get_children():
		_info.remove_child(c)
		c.queue_free()
	var g := _game
	var block: String = g.space(_lot).block
	var rows := [
		["Block", "Block %s" % g.board.blocks[block].name],
		["Lot value", "%d G" % g.lot_value(_lot)],
		["Rent", "%d G" % roundi(g.lot_value(_lot) * GameState.RENT_MIN)],
		["Max capital", "%d G" % g.max_capital(_lot)],
		["Opening bid", "%d G" % Auction.start_price(g, _lot)],
	]
	for r in rows:
		_info.add_child(_line(r[0], Color("#c9b98a")))
		_info.add_child(_line(r[1], Color.WHITE, 17))


## The player columns: name, a Bid button (or why not), Stocks, Ready Cash, Total.
func _fill_players() -> void:
	var g := _game
	for i in 4:
		var c := _cols[i]
		for x in c.get_children():
			c.remove_child(x)
			x.queue_free()
		if i >= g.players.size():
			continue
		var q := g.players[i]
		var colour: Color = BoardView.PLAYER_COLORS[i]
		var name := _line(("★ " if i == _leader else "") + q.name, colour.lightened(0.3), 18)
		c.add_child(name)
		var total := Auction.total_money(g, q)
		var next := Auction.next_bid(g, _lot, _bid)
		if i == _seller:
			c.add_child(_line("Selling", Color("#9a9aa6")))
		elif q.broke:
			c.add_child(_line("Bankrupt", Color("#9a9aa6")))
		elif q.is_cpu:
			c.add_child(_line("Leading!" if i == _leader else "CPU bidding", Color("#c9b98a")))
		else:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.text = "Leading!" if i == _leader else "Bid %d G" % next
			b.disabled = not _running or i == _leader or next > total
			b.pressed.connect(func(): bid_pressed.emit(i))
			c.add_child(b)
		c.add_child(_line("Stocks  %d G" % g.bond_worth(q), Color("#bfe8e2")))
		c.add_child(_line("Ready Cash  %d G" % q.cash, Color("#ffe48a")))
		c.add_child(_line("Total  %d G" % total, Color.WHITE, 16))


func _place_bid(i: int) -> void:
	if not _running or i == _leader or i == _seller:
		return
	var next := Auction.next_bid(_game, _lot, _bid)
	if next > Auction.total_money(_game, _game.players[i]):
		return
	_bid = next
	_leader = i
	_left = Auction.TIMER  # every bid restarts the clock
	for k in _cpu_next:
		_cpu_next[k] = randf_range(CPU_REACT.x, CPU_REACT.y)
	_figures[i].bid()
	_show_tag(i)
	_show_bid()
	_fill_players()


func _show_bid() -> void:
	if _leader < 0:
		_bid_label.text = "Opening bid %d G — no bids yet" % Auction.start_price(_game, _lot)
	else:
		_bid_label.text = "%d G — %s" % [_bid, _game.players[_leader].name]
		_bid_label.add_theme_color_override("font_color", BoardView.PLAYER_COLORS[_leader].lightened(0.3))


func _process(delta: float) -> void:
	if not _running:
		return
	_left -= delta
	# CPUs answer when their reaction time is up, if the price is still theirs.
	for i in _cpu_next.keys():
		if i == _leader:
			continue
		_cpu_next[i] -= delta
		if _cpu_next[i] <= 0.0:
			_cpu_next[i] = randf_range(CPU_REACT.x, CPU_REACT.y)
			if Auction.next_bid(_game, _lot, _bid) <= _limits[i]:
				_place_bid(i)
	_clock.value = maxf(0.0, _left)
	_clock_label.text = "%.1f s" % maxf(0.0, _left)
	if _left <= 0.0:
		_running = false


## Runs the auction for lot `id` sold by `seller`; returns [winner index or
## -1, price]. The caller settles it (Auction.settle) and hides the panel.
func run(g: GameState, id: int, seller: int) -> Array:
	_game = g
	_lot = id
	_seller = seller
	_bid = 0
	_leader = -1
	_left = Auction.TIMER
	_limits.clear()
	_cpu_next.clear()
	for i in Auction.bidders(g, seller):
		if g.players[i].is_cpu:
			_limits[i] = Auction.cpu_limit(g, g.players[i], id)
			_cpu_next[i] = randf_range(CPU_REACT.x, CPU_REACT.y)
	_title.text = "AUCTION — %s" % g._label(id)
	if not _map.game == g:
		_map.show_board(g)
	_map.set_focus(g.space(id).block)
	_map.mark = id
	_map.queue_redraw()
	_fill_info()
	_bid_label.remove_theme_color_override("font_color")
	for i in _figures.size():
		_figures[i].visible = i < g.players.size() and not g.players[i].broke
		_tags[i].text = "SELLING" if i == seller else ""
		_tags[i].modulate = Color(0.75, 0.75, 0.75)
		_tags[i].scale = Vector3.ONE
	_show_bid()
	visible = true
	_running = true
	_fill_players()
	while _running:  # bids arrive through bid_pressed and the CPUs' timers
		await get_tree().process_frame
	_fill_players()
	if _leader < 0:
		_bid_label.text = "No bids — %s stays on sale" % g._label(id)
	else:
		_bid_label.text = "SOLD to %s for %d G!" % [g.players[_leader].name, _bid]
		_figures[_leader].celebrate()
	await get_tree().create_timer(1.8).timeout
	return [_leader, _bid]
