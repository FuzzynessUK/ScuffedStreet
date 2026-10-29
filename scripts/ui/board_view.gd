class_name BoardView
extends Node3D
## Basic 3D board built from placeholder meshes: box tiles, block buildings that
## grow with renovation tier, beacons on Relays, capsule tokens and floating
## text popups. Call build() for a new game and sync() after every change.

const SPACING := 1.15
const TILE := 1.0
const TILE_H := 0.16
const MOVE_TIME := 0.15
const BUILDING_H := [0.22, 0.45, 0.75, 1.15]  # by renovation tier
const UNOWNED_DIM := 0.6
const TYPE_COLORS := {
	"depot": Color("#f2f2f2"), "market": Color("#2e8b80"), "wildcard": Color("#f29bd0"),
	"workshop": Color("#b07a4a"), "toll": Color("#d9534f"), "jackpot": Color("#7a5c1a"),
	"detour": Color("#9a8fe0"), "junction": Color("#6c6c78"),
}
const TYPE_LABELS := {
	"depot": "DEPOT", "market": "MARKET", "wildcard": "?", "workshop": "WORKSHOP",
	"toll": "TOLL", "jackpot": "POT", "detour": "DETOUR", "junction": "",
}
const PLAYER_COLORS := [Color("#e84a4a"), Color("#4a7fe8"), Color("#48b860"), Color("#e8a02a")]

var game: GameState
var highlight: Array[int] = []  # spaces offered as a branch choice

var _camera: Camera3D
var _root: Node3D
var _tiles := {}                     # space id -> {mesh, base, sub, building}
var _tokens: Array[Node3D] = []      # holders; tweened between spaces
var _token_space: Array[int] = []
var _ring: MeshInstance3D
var _arrows: Array[Node3D] = []
var _popups: Array[Label3D] = []
var _time := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1e1e26")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.3
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 40
	add_child(_camera)
	get_viewport().size_changed.connect(_frame_camera)


func build(g: GameState) -> void:
	game = g
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	add_child(_root)
	_tiles.clear()
	_tokens.clear()
	_token_space.clear()
	_arrows.clear()
	highlight = []
	if g == null:
		return

	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for s in g.board.spaces:
		lo = lo.min(_pos(s.id))
		hi = hi.max(_pos(s.id))
	var table := _box(Vector3(hi.x - lo.x + 2.0, 0.1, hi.z - lo.z + 2.0), Color("#34343f"))
	table.position = (lo + hi) / 2 - Vector3(0, 0.05, 0)
	_root.add_child(table)

	for s in g.board.spaces:
		for n in s.next:
			_add_link(_pos(s.id), _pos(n))
	for s in g.board.spaces:
		_add_space(s)

	for p in g.players:
		var holder := Node3D.new()
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.11
		capsule.height = 0.42
		body.mesh = capsule
		body.material_override = _material(PLAYER_COLORS[p.index])
		body.position.y = 0.21
		holder.add_child(body)
		_root.add_child(holder)
		_tokens.append(holder)
		_token_space.append(-1)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.19
	_ring.mesh = torus
	_ring.material_override = _material(Color.WHITE, 0.8)
	_root.add_child(_ring)

	_frame_camera()
	sync(true)


## Brings every mesh in line with the game state. Tokens glide unless `instant`.
func sync(instant := false) -> void:
	if game == null:
		return
	for id in game.lots:
		var t: Dictionary = _tiles[id]
		var lot: Dictionary = game.lots[id]
		var mat: StandardMaterial3D = t.mesh.material_override
		var building: MeshInstance3D = t.building
		if lot.owner < 0:
			mat.albedo_color = t.base.darkened(UNOWNED_DIM)
			building.visible = false
			t.sub.text = "S %d" % game.lot_value(id)
		else:
			mat.albedo_color = t.base
			var h: float = BUILDING_H[lot.tier]
			building.visible = true
			building.scale = Vector3(1, h, 1)
			building.position.y = TILE_H + h / 2
			(building.material_override as StandardMaterial3D).albedo_color = PLAYER_COLORS[lot.owner]
			t.sub.text = "%s  %d" % [GameState.TIER_NAMES[lot.tier], game.rent(id)]

	for id in _tiles:
		var mat: StandardMaterial3D = _tiles[id].mesh.material_override
		mat.emission_enabled = id in highlight
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = 0.5
	for a in _arrows:
		a.queue_free()
	_arrows.clear()
	for id in highlight:
		var arrow := _label("▼", 96, Color.WHITE, true)
		arrow.position = _pos(id) + Vector3(0, 1.0, 0)
		_root.add_child(arrow)
		_arrows.append(arrow)

	for p in game.players:
		var holder := _tokens[p.index]
		holder.visible = not p.broke
		var target := _token_spot(p.index)
		if _token_space[p.index] == p.position:
			continue
		_token_space[p.index] = p.position
		if instant:
			holder.position = target
		else:
			create_tween().tween_property(holder, "position", target, MOVE_TIME) \
					.set_trans(Tween.TRANS_SINE)


func popup_at_player(index: int, text: String, color: Color) -> void:
	_popup(_tokens[index].position + Vector3(0, 0.6, 0), text, color)


func popup_at_space(id: int, text: String, color: Color) -> void:
	_popup(_pos(id) + Vector3(0, 0.9, 0), text, color)


func _process(delta: float) -> void:
	_time += delta
	if game == null or _tokens.is_empty():
		return
	var cur := _tokens[game.current]
	cur.get_child(0).position.y = 0.21 + absf(sin(_time * 5.0)) * 0.12
	_ring.position = cur.position + Vector3(0, 0.03, 0)
	for a in _arrows:
		a.position.y = 1.0 + sin(_time * 6.0) * 0.08


# --- construction -------------------------------------------------------

func _add_space(s: Dictionary) -> void:
	var base: Color = TYPE_COLORS.get(s.type, Color.GRAY)
	if s.type == "lot":
		base = game.board.blocks[s.block].color
	elif s.type == "relay":
		base = s.color
	var tile := _box(Vector3(TILE, TILE_H, TILE), base)
	tile.position = _pos(s.id) + Vector3(0, TILE_H / 2, 0)
	_root.add_child(tile)
	var entry := {"mesh": tile, "base": base, "sub": null, "building": null}

	var title: String = TYPE_LABELS.get(s.type, "")
	match s.type:
		"lot":
			title = s.name
			var building := _box(Vector3(0.46, 1.0, 0.4), Color.WHITE)
			building.position = _pos(s.id) + Vector3(0, 0, -0.22)
			building.visible = false
			_root.add_child(building)
			entry.building = building
		"relay":
			title = s.mark.to_upper()
			var beacon := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.16
			cyl.height = 0.55
			beacon.mesh = cyl
			beacon.material_override = _material(s.color, 0.6)
			beacon.position = _pos(s.id) + Vector3(0, TILE_H + 0.275, -0.2)
			_root.add_child(beacon)
			var badge := _label(s.mark.to_upper(), 56, s.color, true)
			badge.position = _pos(s.id) + Vector3(0, 0.95, -0.2)
			_root.add_child(badge)
		"jackpot":
			var coin := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.22
			cyl.bottom_radius = 0.22
			cyl.height = 0.06
			coin.mesh = cyl
			coin.material_override = _material(Color("#ffd84a"), 0.4)
			coin.position = _pos(s.id) + Vector3(0, TILE_H + 0.2, -0.15)
			coin.rotation_degrees.x = 70
			_root.add_child(coin)
		"depot":
			var flag := _box(Vector3(0.06, 0.8, 0.06), Color.WHITE)
			flag.position = _pos(s.id) + Vector3(-0.3, TILE_H + 0.4, -0.3)
			_root.add_child(flag)
			var cloth := _box(Vector3(0.32, 0.2, 0.03), Color("#e84a4a"))
			cloth.position = _pos(s.id) + Vector3(-0.12, TILE_H + 0.7, -0.3)
			_root.add_child(cloth)

	var label := _label(title, 48 if s.type == "wildcard" else 30, Color.WHITE)
	label.position = _pos(s.id) + Vector3(0, TILE_H + 0.01, 0.12)
	_root.add_child(label)
	if s.type == "lot":
		var sub := _label("", 26, Color("#fff3b0"))
		sub.position = _pos(s.id) + Vector3(0, TILE_H + 0.01, 0.36)
		_root.add_child(sub)
		entry.sub = sub
	_tiles[s.id] = entry


func _add_link(a: Vector3, b: Vector3) -> void:
	var link := _box(Vector3(0.12, 0.04, a.distance_to(b)), Color("#55556a"))
	link.position = (a + b) / 2 + Vector3(0, 0.02, 0)
	link.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
	_root.add_child(link)
	# A small cone halfway along shows the direction of travel.
	var cone := MeshInstance3D.new()
	var prism := CylinderMesh.new()
	prism.top_radius = 0.0
	prism.bottom_radius = 0.1
	prism.height = 0.2
	cone.mesh = prism
	cone.material_override = _material(Color("#8888a0"))
	cone.position = (a + b) / 2 + Vector3(0, 0.08, 0)
	cone.basis = Basis.looking_at((b - a).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2)
	_root.add_child(cone)


func _popup(pos: Vector3, text: String, color: Color) -> void:
	_popups = _popups.filter(func(p): return is_instance_valid(p))
	var stacked := 0
	for p in _popups:
		if Vector2(p.position.x, p.position.z).distance_to(Vector2(pos.x, pos.z)) < 0.5:
			stacked += 1
	var label := _label(text, 64, color, true)
	label.position = pos + Vector3(0, stacked * 0.3, 0)
	label.no_depth_test = true
	_root.add_child(label)
	_popups.append(label)
	var tw := create_tween().set_parallel()
	tw.tween_property(label, "position:y", label.position.y + 0.8, 1.6)
	tw.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.6)
	tw.chain().tween_callback(label.queue_free)


func _frame_camera() -> void:
	if game == null or _camera == null:
		return
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for s in game.board.spaces:
		lo = lo.min(_pos(s.id))
		hi = hi.max(_pos(s.id))
	var center := (lo + hi) / 2
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var need := maxf(hi.z - lo.z, (hi.x - lo.x) / aspect) + 2.6
	var dist := need * 0.5 / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.position = center + Vector3(0, 0.85, 0.55).normalized() * dist
	_camera.look_at(center, Vector3.UP)


# --- helpers ------------------------------------------------------------

func _pos(id: int) -> Vector3:
	var s := game.board.spaces[id]
	return Vector3(s.x * SPACING, 0, s.y * SPACING)


## Where a token stands on its space; up to four share a tile, one per corner.
func _token_spot(index: int) -> Vector3:
	var p := game.players[index]
	var off := Vector3(-0.27 if index % 2 == 0 else 0.27, TILE_H, -0.27 if index < 2 else 0.27)
	return _pos(p.position) + off


func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color)
	return mi


## Flat labels lie on the tile reading towards the camera; billboards face it.
func _label(text: String, font_size: int, color: Color, billboard := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color.BLACK
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	else:
		l.width = 190
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.rotation_degrees.x = -90
	return l
