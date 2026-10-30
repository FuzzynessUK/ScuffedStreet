class_name Minimap
extends Control
## A flat map of the board: every space as a tile at its grid position, lots
## in their block colour with the owner's colour as a border, and a dot for
## each player. `focus` names a block whose lots stand out while the rest of
## the board dims (the Bond Market).
##
## As an `overlay` (the map always shown in a corner while playing) it sits on
## a dark panel, a bought lot is filled with its owner's colour, and special
## spaces carry a letter: B the Bank (Depot), ? a Wildcard, M a minigame
## (Arcade), a star and a moon, V a vacant plot, and the Relays' suits.

const CELL := 26.0              # a space's size on a small board...
const MAX_SIZE := Vector2(290, 200)  # ...shrunk so a big board still fits this
const GAP := 5.0
const PAD := 6.0
const OVERLAY_SIZE := Vector2(240, 170)  # the corner map stays this small
## Letters on special spaces in the overlay.
const LETTERS := {"depot": "B", "wildcard": "?", "arcade": "M", "interest": "★", "break": "☾",
		"dice": "D", "market": "$"}

var game: GameState
var focus := ""
var mark := -1  # one space ringed in pink (the lot up for auction), -1 for none
var overlay := false
var preview := {}  # player index -> space shown while they plan a route
var _cell := CELL
var _gap := GAP


func show_board(g: GameState) -> void:
	game = g
	var extent := Vector2.ZERO
	for s in game.board.spaces:
		extent = extent.max(Vector2(s.x, s.y))
	var spaces := extent + Vector2.ONE
	var most := OVERLAY_SIZE if overlay else MAX_SIZE
	var fit := minf(most.x / spaces.x, most.y / spaces.y)  # cell plus gap
	_cell = minf(CELL, fit * 0.84)
	_gap = minf(GAP, fit * 0.16)
	custom_minimum_size = spaces * (_cell + _gap) - Vector2(_gap, _gap) + Vector2(PAD, PAD) * 2
	queue_redraw()


func set_focus(block: String) -> void:
	if block != focus:
		focus = block
		queue_redraw()


func _corner(s: Dictionary) -> Vector2:
	return Vector2(PAD, PAD) + Vector2(s.x, s.y) * (_cell + _gap)


func _centre(s: Dictionary) -> Vector2:
	return _corner(s) + Vector2(_cell, _cell) / 2


func _draw() -> void:
	if game == null:
		return
	if overlay:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.08, 0.08, 0.12, 0.55)
		panel.set_corner_radius_all(10)
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var spaces := game.board.spaces
	for s in spaces:
		for n in s.next:
			draw_line(_centre(s), _centre(spaces[n]), Color(1, 1, 1, 0.12), 3.0)
	var font := ThemeDB.fallback_font
	for s in spaces:
		var rect := Rect2(_corner(s), Vector2(_cell, _cell))
		var lit: bool = s.type == "lot" and s.block == focus
		var col: Color
		match s.type:
			"lot":
				col = game.board.blocks[s.block].color
			"relay":
				col = s.color
			_:
				col = BoardView.TYPE_COLORS.get(s.type, Color("#6c6c78"))
		if focus != "" and not lit:
			col = col.darkened(0.65)
		if overlay:
			col = _overlay_colour(s, col)
		draw_rect(rect, col)
		if overlay:
			_overlay_mark(s, rect, font)
		elif s.type == "lot" and game.lots[s.id].owner >= 0:
			var owner_col: Color = BoardView.PLAYER_COLORS[game.lots[s.id].owner]
			if focus != "" and not lit:
				owner_col = owner_col.darkened(0.5)
			draw_rect(rect.grow(-2), owner_col, false, 3.0)
		if lit:
			draw_rect(rect.grow(3), Color.WHITE, false, 2.0)
		if s.id == mark:
			draw_rect(rect.grow(5), Color("#ff4fa3"), false, 4.0)
		if s.type == "relay" and not overlay:
			var sym: String = BoardView.SUIT_SYMBOLS.get(s.mark, "")
			draw_string(font, rect.position + Vector2(0, _cell * 0.72), sym,
					HORIZONTAL_ALIGNMENT_CENTER, _cell, roundi(_cell * 0.62), Color(1, 1, 1, 0.9))
	for p in game.players:
		if p.broke:
			continue
		var at := _centre(spaces[preview.get(p.index, p.position)]) + Vector2((p.index % 2) * 8 - 4, (p.index / 2) * 8 - 4)
		var r := 5.5 if overlay else 4.0
		draw_circle(at, r, Color.BLACK)
		draw_circle(at, r - 1.0, BoardView.PLAYER_COLORS[p.index])


## A tile's colour on the overlay: a bought lot (or a built plot) in its owner's
## colour, a lot for sale in its block's colour, dimmed.
func _overlay_colour(s: Dictionary, col: Color) -> Color:
	match s.type:
		"lot":
			var owner: int = game.lots[s.id].owner
			return BoardView.PLAYER_COLORS[owner] if owner >= 0 else col.darkened(0.35)
		"plot":
			var owner: int = game.plots[s.id].owner
			return BoardView.PLAYER_COLORS[owner].darkened(0.2) if owner >= 0 else Color("#6a5034")
		"depot":
			return Color("#f2bf2a")
	return col


## The overlay's letter or symbol on a special space.
func _overlay_mark(s: Dictionary, rect: Rect2, font: Font) -> void:
	var text: String = LETTERS.get(s.type, "")
	if s.type == "relay":
		text = BoardView.SUIT_SYMBOLS.get(s.mark, "")
	elif s.type == "plot":
		text = "V" if game.plots[s.id].owner < 0 else Plots.KINDS[game.plots[s.id].kind].short.left(1)
	if s.type == "lot":
		draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0)
	if text == "":
		return
	var font_size := roundi(_cell * 0.78)
	var at := rect.position + Vector2(0, _cell * 0.5 + font_size * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, _cell, font_size, 3, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, _cell, font_size, Color.WHITE)
