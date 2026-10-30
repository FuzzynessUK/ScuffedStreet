class_name PickACard
extends CenterContainer
## Pick a Card on screen: four cards shown face up with their prizes (a
## picture and a caption each, PrizeArt), turned over, gathered into one stack, shuffled and dealt back out. The prize
## at each table position comes from Minigames.card_deal and is only looked up
## when a card is turned over, so following the cards tells you nothing.

signal picked(pos: int)

const CARD := Vector2(116, 164)
const GAP := 28.0
const LIFT := 46.0        # room above and below the row for the shuffle
const SHOW := 2.0         # seconds the prizes stay face up
const FLIP := 0.14        # half a card turn
const GATHER := 0.35      # cards sliding into one stack
const RIFFLES := 9        # cards pulled out of the stack and put back on top
const RIFFLE := 0.09      # each half of a riffle
const DEAL := 0.2         # each card dealt back to the table
const CPU_THINK := 0.9
const BACK := Color("#f29bd0")  # the Wildcard pink

var _cards: Array[Button] = []  # four card visuals; they carry no prize
var _pos_of: Array[int] = []    # card -> table position it is dealt to
var _picking := false
var _title: Label
var _hint: Label
var result: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1d2a22")
	bg.border_color = Color("#ff8c3a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(10)
	bg.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	col.add_child(_title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("#bfe8c8"))
	col.add_child(_hint)

	var n := Minigames.CARD_PRIZES.size()
	var table := Control.new()  # cards are placed by hand so they can move
	table.custom_minimum_size = Vector2(n * CARD.x + (n - 1) * GAP, CARD.y + LIFT * 2)
	col.add_child(table)
	for i in n:
		var b := Button.new()
		b.size = CARD
		b.pivot_offset = CARD / 2
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		var art := PrizeArt.new()
		art.size = CARD
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(art)
		b.pressed.connect(func(): _on_card(i))
		table.add_child(b)
		_cards.append(b)
		_pos_of.append(i)

	result = Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.custom_minimum_size = Vector2(0, 34)
	result.add_theme_font_size_override("font_size", 24)
	col.add_child(result)


func _at(pos: int) -> Vector2:
	return Vector2(pos * (CARD.x + GAP), LIFT)


func _centre() -> Vector2:
	return (_at(0) + _at(_cards.size() - 1)) / 2


## Draws card k face up showing `prize` (index into CARD_PRIZES), or face down.
## Face up a card is only its prize: a picture (PrizeArt) and a caption.
func _face(k: int, prize: int, up: bool) -> void:
	var b := _cards[k]
	var art: PrizeArt = b.get_child(0)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(10)
	box.set_border_width_all(3)
	art.visible = up
	if up:
		var c: Dictionary = Minigames.CARD_PRIZES[prize]
		art.prize = c
		art.queue_redraw()
		box.bg_color = PrizeArt.BACKGROUNDS[c.kind]
		box.border_color = PrizeArt.BACKGROUNDS[c.kind].darkened(0.25)
		b.text = ""
	else:
		box.bg_color = BACK
		box.border_color = Color.WHITE
		b.text = "?"
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	var hover := box.duplicate() as StyleBoxFlat
	hover.border_color = Color("#ffd84a")
	for state in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_stylebox_override("hover", hover if not up else box)


## Turns card k over to show `prize` face up, or face down.
func _flip(k: int, prize: int, up: bool) -> void:
	var b := _cards[k]
	var tw := create_tween()
	tw.tween_property(b, "scale:x", 0.0, FLIP)
	tw.tween_callback(func(): _face(k, prize, up))
	tw.tween_property(b, "scale:x", 1.0, FLIP)
	await tw.finished


func _move(k: int, to: Vector2, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_cards[k], "position", to, seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tw


## All four cards slide into one stack in the middle, then a few at a time are
## pulled out and put back on top, then they are dealt to the table again.
## Only for show: which card goes where says nothing about the prizes.
func _shuffle() -> void:
	var stack: Array[int] = []
	for k in _cards.size():
		_move(k, _centre(), GATHER)
		stack.append(k)
	await get_tree().create_timer(GATHER + 0.1).timeout
	for r in RIFFLES:
		var k: int = stack[randi() % (stack.size() - 1)]  # never the top card
		var side := Vector2(CARD.x * 0.75 * (1 if r % 2 == 0 else -1), -14)
		await _move(k, _centre() + side, RIFFLE).finished
		_cards[k].move_to_front()
		stack.erase(k)
		stack.append(k)
		await _move(k, _centre(), RIFFLE).finished
	for pos in _cards.size():
		var k: int = stack.pop_back()  # deal from the top
		_pos_of[k] = pos
		await _move(k, _at(pos), DEAL).finished


func _on_card(k: int) -> void:
	if _picking:
		_picking = false
		picked.emit(_pos_of[k])


## Plays the show, shuffle and pick for p. `shown` is the order the prizes
## are shown in, `order` where they really end up (both from card_deal).
## Returns the position picked; the caller shows the prize (show_result) and
## hides the panel.
func play(g: GameState, p: PlayerState, shown: Array, order: Array) -> int:
	_title.text = "Pick a Card — %s" % p.name
	result.text = ""
	visible = true
	for k in _cards.size():
		_cards[k].position = _at(k)
		_cards[k].modulate = Color.WHITE
		_cards[k].scale = Vector2.ONE
		_cards[k].disabled = true
		_face(k, shown[k], true)
	_hint.text = "Here are the prizes..."
	await get_tree().create_timer(SHOW).timeout
	for k in _cards.size():
		_flip(k, 0, false)
	await get_tree().create_timer(FLIP * 2 + 0.25).timeout
	_hint.text = "Shuffling!"
	await _shuffle()
	var pos: int
	if p.is_cpu:
		_hint.text = "%s is picking..." % p.name
		await get_tree().create_timer(CPU_THINK).timeout
		pos = Minigames.cpu_card(g)
	else:
		_hint.text = "Pick a card!"
		for b in _cards:
			b.disabled = false
		_picking = true
		pos = await picked
		for b in _cards:
			b.disabled = true
	var chosen := _pos_of.find(pos)
	_cards[chosen].scale = Vector2.ONE * 1.08
	await _flip(chosen, order[pos], true)
	for k in _cards.size():
		if k != chosen:
			_cards[k].modulate = Color(1, 1, 1, 0.55)
			_flip(k, order[_pos_of[k]], true)
	_hint.text = ""
	return pos


func show_result(prize: Dictionary) -> void:
	result.text = prize.text
	result.add_theme_color_override("font_color",
			Color("#7dff6a") if prize.kind != "none" else Color("#9a9aa6"))


## A prize card's face: a soft picture of the prize and its caption.
##   cash      a pile of gold coins (three stacks for the big prize, one for the
##             small), with twinkles
##   card      the four suits round a rainbow ring
##   none      a grey puff of smoke
class PrizeArt extends Control:
	const BACKGROUNDS := {"cash": Color("#fff4d6"), "card": Color("#f1e8ff"), "none": Color("#e9edf2")}
	const GOLD := Color("#f4c430")
	const GOLD_DARK := Color("#c8901a")
	const GOLD_LIGHT := Color("#ffe58a")
	const SUITS := [["♠", Color("#2f3a8a")], ["♥", Color("#e0405a")], ["♦", Color("#f08a24")],
			["♣", Color("#2f9a4a")]]
	const RAINBOW := [Color("#ff5a5a"), Color("#ffa64a"), Color("#ffe04a"), Color("#5ad86a"),
			Color("#4aa8ff"), Color("#a46aff")]

	var prize := {}

	func _draw() -> void:
		if prize.is_empty():
			return
		var mid := Vector2(size.x / 2, size.y * 0.42)
		match prize.kind:
			"cash":
				if prize.amount >= 300:
					_stack(mid + Vector2(-28, 22), 3)
					_stack(mid + Vector2(28, 22), 4)
					_stack(mid + Vector2(0, 32), 6)
					_twinkle(mid + Vector2(-34, -34), 8)
					_twinkle(mid + Vector2(36, -20), 6)
					_twinkle(mid + Vector2(8, -44), 5)
				else:
					_stack(mid + Vector2(-6, 26), 3)
					_coin(mid + Vector2(26, 34))
					_twinkle(mid + Vector2(28, -12), 6)
			"card":
				for i in RAINBOW.size():
					draw_arc(mid, 38.0 - i * 3.0, 0, TAU, 48, RAINBOW[i], 3.0, true)
				var at := [Vector2(-14, -12), Vector2(14, -12), Vector2(-14, 16), Vector2(14, 16)]
				for i in SUITS.size():
					_text(SUITS[i][0], mid + at[i], 26, SUITS[i][1])
			_:
				var grey := Color("#b4bac4")
				for puff in [[Vector2(-18, 6), 16], [Vector2(0, -6), 20], [Vector2(20, 4), 15],
						[Vector2(4, 14), 16]]:
					draw_circle(mid + puff[0], puff[1], grey)
				for puff in [[Vector2(-4, -10), 9], [Vector2(-20, 2), 7]]:  # highlights
					draw_circle(mid + puff[0], puff[1], Color("#d6dbe2"))
				for a in [-0.9, 0.0, 0.9]:  # little "poof" lines
					var dir := Vector2.UP.rotated(a)
					draw_line(mid + dir * 34, mid + dir * 44, grey, 3.0, true)
		_text(prize.caption, Vector2(size.x / 2, size.y - 24), 20, Color("#3a3446"))

	## A stack of `count` coins standing on `base`.
	func _stack(base: Vector2, count: int) -> void:
		for i in count:
			_coin(base - Vector2(0, i * 7))

	## One coin lying flat: an edge in dark gold, the face lighter, a shine.
	func _coin(at: Vector2) -> void:
		draw_set_transform(at + Vector2(0, 3), 0, Vector2(1, 0.42))
		draw_circle(Vector2.ZERO, 16, GOLD_DARK)
		draw_set_transform(at, 0, Vector2(1, 0.42))
		draw_circle(Vector2.ZERO, 16, GOLD)
		draw_circle(Vector2.ZERO, 11, GOLD_LIGHT)
		draw_circle(Vector2(-4, -3), 4, Color(1, 1, 1, 0.7))
		draw_set_transform(Vector2.ZERO)

	## A four-pointed twinkle `r` across.
	func _twinkle(at: Vector2, r: float) -> void:
		var pts := PackedVector2Array()
		for k in 8:
			var d := r if k % 2 == 0 else r * 0.3
			pts.append(at + Vector2.UP.rotated(k * PI / 4) * d)
		draw_colored_polygon(pts, Color("#ffd84a"))

	func _text(s: String, centre: Vector2, font_size: int, colour: Color) -> void:
		var font := get_theme_default_font()
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, centre + Vector2(-w / 2, font_size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size, colour)
