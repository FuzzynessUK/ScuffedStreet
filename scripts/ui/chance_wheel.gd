class_name ChanceWheel
extends CenterContainer
## Chance Wheel on screen: a player wheel and an action wheel, spinning very
## fast, seen face on as if you stood in front of them. Throw (or Enter) sends
## a dart at each, always at the 12 o'clock mark; it flies in from in front of
## you, sticks there and rides round as the wheel slows. The segment it sticks
## in is the result.
##
## There is nothing to react to: the result is drawn by Minigames when the
## dart is thrown, and the wheel's turn during the dart's short flight is
## adjusted (unseeable at that speed) so the dart lands in that segment.

signal throw_pressed

const CPU_THROW := 0.9  # how long a CPU lets a wheel spin
const SPIN_WHO := 7.0   # turns a second: far too fast to pick a name
const SPIN_WHAT := 5.0
const TOP := Vector2(0, -0.72 * 104.0)  # the 12 o'clock mark, inside the rim (Wheel.RADIUS)


## One wheel: coloured segments with labels, spinning, and a dart thrown at it.
class Wheel extends Control:
	const RADIUS := 104.0
	const FLIGHT := 0.32      # seconds the dart flies
	const SLOW := 2.6         # seconds the wheel takes to stop after a hit
	var segments: Array = []  # [{"label", "color"}]
	var angle := 0.0          # radians; the wheel turns clockwise as it grows
	var speed := 0.0          # radians a second while spinning freely
	var spinning := false
	var dart_r := -1.0        # where the dart is stuck: distance from centre...
	var dart_theta := 0.0     # ...and angle on the wheel (clockwise from its top)
	var flight := -1.0        # 0..1 while the dart flies, else -1
	var fly_to := Vector2.ZERO

	func _init() -> void:
		custom_minimum_size = Vector2(RADIUS * 2 + 24, RADIUS * 2 + 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if spinning:
			angle += speed * delta
			queue_redraw()

	func centre() -> Vector2:
		return size / 2

	## The segment the dart is stuck in.
	func dart_segment() -> int:
		var seg := TAU / segments.size()
		return int(fposmod(dart_theta, TAU) / seg) % segments.size()

	## Throws a dart at `at` (relative to the centre) so that it sticks in
	## segment i, then slows the wheel to a stop with the dart riding on it.
	func throw_at(at: Vector2, i: int) -> void:
		var seg := TAU / segments.size()
		# The dart's spot on the wheel: in segment i, away from its edges.
		var theta := (i + randf_range(0.2, 0.8)) * seg
		# A screen angle phi shows wheel angle phi - angle + PI/2, so for the
		# point `at` to show theta the wheel must be at phi + PI/2 - theta.
		var impact := at.angle() + PI / 2 - theta
		var a0 := angle
		var free := speed * FLIGHT  # how far it would turn anyway
		var turn := free + fposmod(impact - (a0 + free), TAU)
		spinning = false
		fly_to = at
		var tw := create_tween()
		tw.tween_method(func(t: float):
			angle = a0 + turn * t
			flight = t
			queue_redraw(), 0.0, 1.0, FLIGHT)
		await tw.finished
		flight = -1.0
		dart_r = at.length()
		dart_theta = theta
		# Slow down from (about) the speed it was turning at the hit.
		var from := angle
		var hit_speed := turn / FLIGHT
		var coast := hit_speed * SLOW / 3.0  # ease-out cubic starts at 3 × coast / SLOW
		var stop := create_tween()
		stop.tween_method(func(t: float):
			angle = from + coast * (1.0 - pow(1.0 - t, 3.0))
			queue_redraw(), 0.0, 1.0, SLOW)
		await stop.finished

	func _draw() -> void:
		if segments.is_empty():
			return
		var c := centre()
		var n := segments.size()
		var seg := TAU / n
		var font := ThemeDB.fallback_font
		draw_circle(c, RADIUS + 6, Color("#f2e6c8"))
		for i in n:
			# Segment i spans i*seg..(i+1)*seg clockwise from the wheel's top.
			var a0 := i * seg + angle - PI / 2
			var pts := PackedVector2Array([c])
			for k in 17:
				pts.append(c + Vector2.from_angle(a0 + seg * k / 16.0) * RADIUS)
			draw_colored_polygon(pts, segments[i].color)
			draw_line(c, c + Vector2.from_angle(a0) * RADIUS, Color(0, 0, 0, 0.35), 2.0)
			var mid := c + Vector2.from_angle(a0 + seg / 2) * RADIUS * 0.62
			var text: String = segments[i].label
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string_outline(font, mid + Vector2(-w / 2, 5), text, HORIZONTAL_ALIGNMENT_LEFT,
					-1, 15, 4, Color(0, 0, 0, 0.7))
			draw_string(font, mid + Vector2(-w / 2, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
					Color.WHITE)
		draw_circle(c, 12, Color("#f2e6c8"))
		if dart_r >= 0.0:
			# Stuck in the board: seen from the thrower, the flights face you.
			var at := c + Vector2.from_angle(dart_theta + angle - PI / 2) * dart_r
			_dart(at, 1.0)
		elif flight >= 0.0:
			# Flying in from in front of you: big and low, shrinking as it goes.
			var start := c + Vector2(0, RADIUS * 2.2)
			var t := ease(flight, 0.6)
			_dart(start.lerp(c + fly_to, t), lerpf(3.0, 1.0, t))
		else:
			# The mark at 12 o'clock where the dart will hit.
			var top := c + Vector2(0, -RADIUS - 4)
			draw_colored_polygon(PackedVector2Array([top, top + Vector2(-10, -16),
					top + Vector2(10, -16)]), Color.WHITE)

	## A dart seen from behind: four red flights round the shaft's end.
	func _dart(at: Vector2, s: float) -> void:
		for k in 4:
			var d := Vector2.from_angle(PI / 4 + k * PI / 2)
			draw_colored_polygon(PackedVector2Array([at, at + d.rotated(0.35) * 13 * s,
					at + d.rotated(-0.35) * 13 * s]), Color("#e84a4a"))
		draw_circle(at, 4 * s, Color("#3a2a1a"))
		draw_circle(at, 1.6 * s, Color("#d8d8e0"))


var _who: Wheel
var _what: Wheel
var _where: Wheel        # the block wheel, for a bond action
var _where_box: Control
var _title: Label
var _hint: Label
var _button: Button
var _waiting := false
var result: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#2a2030")
	bg.border_color = Color("#ff8c3a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	col.add_child(_title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("#e8cfe0"))
	col.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for caption in ["WHO?", "WHAT?", "WHERE?"]:
		var box := VBoxContainer.new()
		row.add_child(box)
		var cap := Label.new()
		cap.text = caption
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.add_theme_font_size_override("font_size", 20)
		box.add_child(cap)
		var w := Wheel.new()
		box.add_child(w)
		match caption:
			"WHO?":
				_who = w
			"WHAT?":
				_what = w
			_:
				_where = w
				_where_box = box  # only shown for a bond action
	result = Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(0, 34)
	result.add_theme_font_size_override("font_size", 22)
	col.add_child(result)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(0, 40)
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_throw)
	col.add_child(_button)


func _on_throw() -> void:
	if _waiting:
		_waiting = false
		throw_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _waiting and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_throw()


## Waits for p to throw (Throw or Enter; a CPU throws by itself).
func _throw(p: PlayerState, label: String) -> void:
	_button.text = label
	_button.disabled = p.is_cpu
	if p.is_cpu:
		await get_tree().create_timer(CPU_THROW).timeout
	else:
		_waiting = true
		await throw_pressed
	_button.disabled = true


## Plays the wheels for thrower p; returns [player index, action index, block]
## (block "" unless a bond action brought out the WHERE? wheel). The caller
## applies it (Minigames.wheel_apply) and hides the panel.
func play(g: GameState, p: PlayerState) -> Array:
	_title.text = "Chance Wheel — %s throws" % p.name
	result.text = ""
	result.remove_theme_color_override("font_color")
	_where_box.visible = false
	var seats := Minigames.wheel_players(g)
	_who.segments = seats.map(func(i): return {"label": g.players[i].name,
			"color": BoardView.PLAYER_COLORS[i].darkened(0.1)})
	_what.segments = Minigames.WHEEL_ACTIONS.map(func(a): return {"label": a.label,
			"color": Color("#3f9a52") if a.good else Color("#b8383f")})
	for w in [_who, _what, _where]:
		w.dart_r = -1.0
		w.flight = -1.0
		w.angle = randf() * TAU  # where it starts is only for show
		w.spinning = true
	_who.speed = TAU * SPIN_WHO
	_what.speed = TAU * SPIN_WHAT
	_where.speed = TAU * SPIN_WHAT
	_button.visible = true
	visible = true

	_hint.text = "The dart hits the mark at 12 o'clock." if not p.is_cpu \
			else "%s is taking aim..." % p.name
	await _throw(p, "Throw a dart: WHO?")
	var target := Minigames.wheel_player(g)  # drawn as the dart leaves the hand
	await _who.throw_at(TOP, seats.find(target))
	result.text = "%s..." % g.players[target].name
	await _throw(p, "Throw a dart: WHAT?")
	var action := Minigames.wheel_action(g)
	await _what.throw_at(TOP, action)
	var a: Dictionary = Minigames.WHEEL_ACTIONS[action]
	var who: String = g.players[target].name
	var block := ""
	var blocks := Minigames.wheel_blocks(g, target, action)
	if a.has("bonds") and blocks.is_empty():
		result.text = "%s: %s... but has no bonds to lose!" % [who, a.label]
		_button.visible = false
		_hint.text = ""
		return [target, action, ""]
	if not blocks.is_empty():
		result.text = "%s: %s... in which block?" % [who, a.label]
		_where.segments = blocks.map(func(b): return {"label": "Block %s" % g.board.blocks[b].name,
				"color": g.board.blocks[b].color.darkened(0.15)})
		_where_box.visible = true
		await _throw(p, "Throw a dart: WHERE?")
		block = Minigames.wheel_block(g, blocks)
		await _where.throw_at(TOP, blocks.find(block))
	_button.visible = false
	_hint.text = ""
	result.text = "%s: %s!" % [who, a.label] if block == "" \
			else "%s: %s in Block %s!" % [who, a.label, g.board.blocks[block].name]
	result.add_theme_color_override("font_color", Color("#7dff6a") if a.good else Color("#ff6a6a"))
	return [target, action, block]
