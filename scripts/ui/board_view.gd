class_name BoardView
extends Control
## Draws the board with placeholder shapes: coloured tiles, link lines, circle tokens.

const TYPE_COLORS := {
	"depot": Color("#f0f0f0"), "relay": Color("#7fd6e0"), "market": Color("#a6e07f"),
	"wildcard": Color("#e0d07f"), "workshop": Color("#c8a07a"), "toll": Color("#e08a7f"),
	"jackpot": Color("#ffd84a"), "detour": Color("#b0b0e0"), "junction": Color("#9a9a9a"),
}
const TYPE_LABELS := {
	"depot": "DEPOT", "relay": "RELAY", "market": "MARKET", "wildcard": "?",
	"workshop": "WORKSHOP", "toll": "TOLL", "jackpot": "POT", "detour": "DETOUR",
	"junction": "",
}
const PLAYER_COLORS := [Color("#e84a4a"), Color("#4a7fe8"), Color("#48b860"), Color("#e8a02a")]

var game: GameState
var highlight: Array[int] = []  # spaces offered as a branch choice

var _cell := 80.0
var _origin := Vector2.ZERO


func _draw() -> void:
	if game == null:
		return
	_fit()
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), Color("#2b2b33"))

	for s in game.board.spaces:
		for n in s.next:
			draw_line(_center(s.id), _center(n), Color("#55555f"), 4.0)

	var tile := _cell * 0.86
	for s in game.board.spaces:
		var rect := Rect2(_center(s.id) - Vector2(tile, tile) / 2, Vector2(tile, tile))
		var fill: Color = TYPE_COLORS.get(s.type, Color.GRAY)
		var text: String = TYPE_LABELS.get(s.type, "")
		var sub := ""
		if s.type == "lot":
			var lot: Dictionary = game.lots[s.id]
			fill = game.board.blocks[s.block].color
			if lot.owner < 0:
				fill = fill.lerp(Color("#3a3a44"), 0.55)
			text = s.name
			sub = "%d" % game.lot_value(s.id)
			if lot.owner >= 0:
				sub = "%s  rent %d" % [GameState.TIER_NAMES[lot.tier], game.rent(s.id)]
		draw_rect(rect, fill)
		if s.type == "lot" and game.lots[s.id].owner >= 0:
			draw_rect(rect, PLAYER_COLORS[game.lots[s.id].owner], false, 5.0)
		if s.id in highlight:
			draw_rect(rect.grow(4), Color.WHITE, false, 3.0)
		var fs := int(_cell * 0.14)
		draw_string(font, rect.position + Vector2(0, tile * 0.42), text,
				HORIZONTAL_ALIGNMENT_CENTER, tile, fs, Color.BLACK)
		if sub != "":
			draw_string(font, rect.position + Vector2(0, tile * 0.72), sub,
					HORIZONTAL_ALIGNMENT_CENTER, tile, int(fs * 0.85), Color.BLACK)

	for p in game.players:
		if p.broke:
			continue
		var offset := Vector2(-1 if p.index % 2 == 0 else 1, -1 if p.index < 2 else 1) * _cell * 0.22
		var pos := _center(p.position) + offset
		draw_circle(pos, _cell * 0.13, PLAYER_COLORS[p.index])
		draw_arc(pos, _cell * 0.13, 0, TAU, 24, Color.BLACK, 2.0)
		if p.index == game.current:
			draw_arc(pos, _cell * 0.19, 0, TAU, 24, Color.WHITE, 2.0)


## Scales the board's grid to fill the control.
func _fit() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in game.board.spaces:
		lo = lo.min(Vector2(s.x, s.y))
		hi = hi.max(Vector2(s.x, s.y))
	var span := hi - lo + Vector2.ONE
	_cell = minf(size.x / span.x, size.y / span.y)
	_origin = (size - span * _cell) / 2 - lo * _cell


func _center(id: int) -> Vector2:
	var s := game.board.spaces[id]
	return _origin + (Vector2(s.x, s.y) + Vector2(0.5, 0.5)) * _cell
