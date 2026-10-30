class_name ScrapSlots
extends CenterContainer
## Scrap Slots on screen: a 3x3 grid whose three rows spin and are stopped one
## at a time, top to bottom, with Stop (or Enter). A row's symbols come from
## Minigames.slot_row, drawn when Stop is pressed; the row then slows onto them,
## so there is nothing to time. Winning lines are drawn across the grid.

signal stop_pressed

const STEP := 0.03     # seconds per symbol while a cell spins freely
const SETTLE := 0.9    # seconds a row takes to slow to a stop
const CELL := Vector2(96, 78)
const GAP := 8.0
const CPU_STOP := 0.7  # how long a CPU lets each row spin

var _cells: Array[Label] = []   # 9 cells, row by row
var _index: Array[int] = []      # symbol each cell shows
var _row_serial := [0, 0, 0]     # a new game (or a stop) ends a row's free spin
var _serial := 0
var _waiting := false            # Stop/Enter is live
var _lines: Array = []           # winning lines to draw: [[cell, cell, cell], ...]
var _grid_box: Control
var _layer: Control
var _title: Label
var _stop: Button
var result: Label


## Draws the winning lines over the grid.
class LineLayer extends Control:
	var slots: ScrapSlots

	func _draw() -> void:
		for line in slots._lines:
			var a: Vector2 = slots._centre(line[0])
			var b: Vector2 = slots._centre(line[2])
			var d := (b - a).normalized() * 30.0
			draw_line(a - d, b + d, Color(1, 1, 1, 0.5), 7.0, true)
			draw_line(a - d, b + d, Color(1.0, 0.85, 0.29, 0.75), 3.5, true)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#22202c")
	bg.border_color = Color("#ff8c3a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	col.add_child(_title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	# The grid is placed by hand so the line layer can sit on top of it.
	_grid_box = Control.new()
	_grid_box.custom_minimum_size = CELL * 3 + Vector2(GAP, GAP) * 2
	row.add_child(_grid_box)
	for k in 9:
		var cell := Label.new()
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.size = CELL
		cell.position = Vector2(k % 3, k / 3) * (CELL + Vector2(GAP, GAP))
		cell.add_theme_font_size_override("font_size", 28)
		_grid_box.add_child(cell)
		_cells.append(cell)
		_index.append(0)
	var layer := LineLayer.new()
	layer.slots = self
	layer.size = _grid_box.custom_minimum_size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_box.add_child(layer)
	_layer = layer
	row.add_child(_prize_table())

	result = Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.custom_minimum_size = Vector2(0, 34)
	result.add_theme_font_size_override("font_size", 22)
	col.add_child(result)
	_stop = Button.new()
	_stop.custom_minimum_size = Vector2(0, 40)
	_stop.focus_mode = Control.FOCUS_NONE
	_stop.pressed.connect(_on_stop)
	col.add_child(_stop)


func _centre(cell: int) -> Vector2:
	return _cells[cell].position + CELL / 2


func _prize_table() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head := Label.new()
	head.text = "3 in a line: across, down\nor diagonal. Every line pays."
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", Color("#c9c3d8"))
	col.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	var rows := [
		["Gold", "%d G" % Minigames.SLOT_GOLD],
		["Bolt", "%d G" % Minigames.SLOT_BOLT],
		["Warp", "Warp to the Depot\nor a suit"],
		["Bond", "%d free bonds" % Minigames.SLOT_BONDS],
		["Card", "Any Suit card"],
	]
	for r in rows:
		var sym := _symbol(r[0])
		var key := Label.new()
		key.text = "%s %s %s" % [sym.label, sym.label, sym.label]
		key.add_theme_font_size_override("font_size", 15)
		key.add_theme_color_override("font_color", Color.html(sym.color).lightened(0.2))
		grid.add_child(key)
		var prize := Label.new()
		prize.text = r[1]
		prize.add_theme_font_size_override("font_size", 15)
		grid.add_child(prize)
	return col


static func _symbol(name: String) -> Dictionary:
	for s in Minigames.SLOT_SYMBOLS:
		if s.name == name:
			return s
	return {}


## Shows symbol i in cell k (lit up when it is part of a winning line).
func _show(k: int, i: int, lit := false) -> void:
	var n := Minigames.SLOT_SYMBOLS.size()
	_index[k] = posmod(i, n)
	var sym: Dictionary = Minigames.SLOT_SYMBOLS[_index[k]]
	var box := StyleBoxFlat.new()
	box.bg_color = Color.html(sym.color)
	box.set_corner_radius_all(8)
	box.set_border_width_all(4 if lit else 2)
	box.border_color = Color("#ffd84a") if lit else Color(1, 1, 1, 0.6)
	_cells[k].add_theme_stylebox_override("normal", box)
	_cells[k].text = sym.label
	_cells[k].add_theme_color_override("font_color", Color.BLACK)


func _spin_row(r: int, serial: int) -> void:
	while serial == _row_serial[r]:
		for c in 3:
			_show(r * 3 + c, _index[r * 3 + c] + 1)
		await get_tree().create_timer(STEP).timeout


## Slows row r onto `symbols` (one per cell); every cell turns at least twice
## more round and all three stop together.
func _settle_row(r: int, symbols: Array) -> void:
	var n := Minigames.SLOT_SYMBOLS.size()
	var start := []
	var steps := []
	for c in 3:
		var k := r * 3 + c
		start.append(_index[k])
		steps.append(posmod(symbols[c] - _index[k], n) + n * (2 + c))
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := 1.0 - pow(1.0 - t, 3.0)
		for c in 3:
			_show(r * 3 + c, start[c] + roundi(steps[c] * e)), 0.0, 1.0, SETTLE)
	await tw.finished


func _on_stop() -> void:
	if _waiting:
		_waiting = false
		stop_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _waiting and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_stop()


## Plays the grid for p and returns its 9 symbols, row by row. The caller
## shows the result (show_result) and hides the panel.
func play(g: GameState, p: PlayerState) -> Array:
	_title.text = "Scrap Slots — %s" % p.name
	result.text = ""
	_lines = []
	_layer.queue_redraw()
	_stop.visible = true
	visible = true
	_serial += 1
	for k in 9:
		_show(k, randi())  # where each cell starts is only for show
	for r in 3:
		_row_serial[r] = _serial
		_spin_row(r, _serial)
	var grid := []
	for r in 3:
		_stop.text = ["Stop the top row", "Stop the middle row", "Stop the bottom row"][r]
		_stop.disabled = p.is_cpu
		if p.is_cpu:
			await get_tree().create_timer(CPU_STOP).timeout
		else:
			_waiting = true
			await stop_pressed
		var symbols := Minigames.slot_row(g)  # drawn now, whatever is showing
		grid.append_array(symbols)
		_row_serial[r] = -1  # ends this row's free spin
		_stop.disabled = true
		await _settle_row(r, symbols)
	_stop.visible = false
	return grid


## Shows what the grid pays: winning lines drawn across it, the text below.
func show_result(grid: Array, res: Dictionary) -> void:
	_lines = res.lines.map(func(l): return l.cells)
	for k in 9:
		var lit := false
		for l in _lines:
			lit = lit or k in l
		_show(k, grid[k], lit)
	_layer.queue_redraw()
	result.text = res.text
	var paid: bool = res.cash > 0 or res.cards > 0 or res.bonds > 0 or res.warp
	result.add_theme_color_override("font_color", Color("#7dff6a") if paid else Color("#9a9aa6"))
