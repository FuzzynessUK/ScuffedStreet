class_name BoardView
extends Node3D
## Basic 3D board built from placeholder meshes: box tiles, a building on each
## lot sized by its value with a signpost showing the price (or rent once owned),
## suit beacons on the Relays, walking figures and floating text popups. Call build() for a new game and sync() after every change.

const SPACING := 1.15
const TILE := 1.0
const TILE_H := 0.16
const MOVE_TIME := 0.3
const VALUE_FOR_FULL_SIZE := 2000.0  # lot value whose building reaches full size
const BUILDING_MIN_H := 0.06
const BUILDING_MAX_H := 1.0
const UNOWNED_BUILDING := Color("#d8d8de")
const FIGURE_SCALE := 1.35
const SIGN_HEIGHT := 0.32
const SUIT_HEIGHT := 0.65
const CAMERA_DIR := Vector3(0, 0.85, 0.55)  # from the look point towards the camera
const FOLLOW_DIST := 7.5   # camera distance when following a player
const CAMERA_EASE := 4.0   # how quickly the camera glides to where it should be
const FIREWORKS := 6
const FIREWORK_COLORS := [Color("#ff4a5a"), Color("#ffd84a"), Color("#4ae0ff"), Color("#7dff6a"), Color("#ff7ae8"), Color("#ffffff")]
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
const SUIT_SYMBOLS := {"Spade": "♠", "Heart": "♥", "Diamond": "♦", "Club": "♣"}

var game: GameState
var highlight: Array[int] = []  # spaces offered as a branch choice
var zoom_for_highlight := true  # pull back to the whole board while highlighting

var _camera: Camera3D
var _root: Node3D
var _tiles := {}                     # space id -> {mesh, base, sub, building}
var _tokens: Array[Node3D] = []      # holders; tweened between spaces
var _token_space: Array[int] = []
var _ring: MeshInstance3D
var _arrows: Array[Node3D] = []
var _popups: Array[Label3D] = []
var _spinners: Array[Node3D] = []  # suit symbols swaying above the Relays
var _time := 0.0
var _center := Vector3.ZERO  # middle of the board
var _preview := {}  # player index -> space shown while planning a route
var _overview_pos := Vector3.ZERO
var _overview_look := Vector3.ZERO
var _overview_until := 0.0  # show the whole board until this _time
var _cam_look := Vector3.ZERO


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
	_preview.clear()
	_tokens.clear()
	_token_space.clear()
	_arrows.clear()
	_spinners.clear()
	highlight = []
	if g == null:
		return

	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for s in g.board.spaces:
		lo = lo.min(_pos(s.id))
		hi = hi.max(_pos(s.id))
	var table := _box(Vector3(hi.x - lo.x + 2.0, 0.1, hi.z - lo.z + 2.0), Color("#34343f"))
	_center = (lo + hi) / 2
	table.position = (lo + hi) / 2 - Vector3(0, 0.05, 0)
	_root.add_child(table)

	for s in g.board.spaces:
		for n in s.next:
			_add_link(_pos(s.id), _pos(n))
	for s in g.board.spaces:
		_add_space(s)

	for p in g.players:
		var figure := Character.new()
		_root.add_child(figure)
		figure.setup(PLAYER_COLORS[p.index])
		figure.scale = Vector3.ONE * FIGURE_SCALE
		_tokens.append(figure)
		_token_space.append(-1)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.14
	torus.outer_radius = 0.19
	_ring.mesh = torus
	_ring.material_override = _material(Color.WHITE, 0.8)
	_root.add_child(_ring)

	_frame_camera()
	_camera.position = _overview_pos
	_cam_look = _overview_look
	_camera.look_at(_cam_look, Vector3.UP)
	overview(1.5)
	sync(true)


## Brings every mesh in line with the game state. Tokens glide unless `instant`.
func sync(instant := false) -> void:
	if game == null:
		return
	for id in game.lots:
		var t: Dictionary = _tiles[id]
		var lot: Dictionary = game.lots[id]
		var mat: StandardMaterial3D = t.mesh.material_override
		# The building's size follows the lot's value; the sign shows the price
		# while it is for sale and the rent once owned, in the owner's colour.
		var building: MeshInstance3D = t.building
		var size := sqrt(game.lot_value(id) / VALUE_FOR_FULL_SIZE)
		var h := BUILDING_MIN_H + BUILDING_MAX_H * size
		var w := 0.2 + 0.3 * minf(size, 1.0)
		building.scale = Vector3(w, h, w * 0.85)
		building.position.y = TILE_H + h / 2
		var sign_mat: StandardMaterial3D = t.sign_board.material_override
		var bmat: StandardMaterial3D = building.material_override
		if lot.owner < 0:
			mat.albedo_color = t.base.darkened(UNOWNED_DIM)
			bmat.albedo_color = UNOWNED_BUILDING.lerp(t.base, 0.25)
			sign_mat.albedo_color = Color("#f4f1e6")
			t.sign_label.modulate = Color("#202020")
			t.sign_label.text = "%d" % game.lot_value(id)
		else:
			mat.albedo_color = t.base
			bmat.albedo_color = PLAYER_COLORS[lot.owner]
			sign_mat.albedo_color = PLAYER_COLORS[lot.owner]
			t.sign_label.modulate = Color.WHITE
			t.sign_label.text = "%d" % game.rent(id)

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
		var shown: int = _preview.get(p.index, p.position)
		var target := _token_spot(p.index)
		if _token_space[p.index] == shown:
			continue
		_token_space[p.index] = shown
		if instant:
			holder.position = target
			holder.rotation.y = 0.0  # face the camera
		else:
			(holder as Character).walk_to(target, MOVE_TIME)


func popup_at_player(index: int, text: String, color: Color) -> void:
	_popup(_tokens[index].position + Vector3(0, 0.75, 0), text, color)


func popup_at_space(id: int, text: String, color: Color) -> void:
	_popup(_pos(id) + Vector3(0, 0.9, 0), text, color)


## Shows player `index` standing on `id` while they plan a route (the game
## state only changes once the route is confirmed).
func preview(index: int, id: int) -> void:
	_preview[index] = id
	sync()


func clear_preview(index: int) -> void:
	_preview.erase(index)

## Pulls the camera back to show the whole board for `seconds`.
func overview(seconds: float) -> void:
	_overview_until = maxf(_overview_until, _time + seconds)


## Whole board during an overview or while choices are highlighted, else close
## behind the current player.
func _move_camera(delta: float) -> void:
	var look := _overview_look
	var pos := _overview_pos
	if _time >= _overview_until and (highlight.is_empty() or not zoom_for_highlight):
		look = _tokens[game.current].position
		pos = look + CAMERA_DIR.normalized() * FOLLOW_DIST
	var k := minf(1.0, delta * CAMERA_EASE)
	_camera.position = _camera.position.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	_camera.look_at(_cam_look, Vector3.UP)

## PAYDAY: fireworks over the Depot, a big gold banner and the player celebrating.
func payday(index: int, amount: int) -> void:
	var at := _pos(game.board.depot)
	# Aim the show in over the board: the Depot may sit at an edge or corner.
	var inward := (_center - at).normalized()
	overview(2.4)
	var label := _label("PAYDAY!\n+%d" % amount, 110, Color("#ffd84a"), true)
	label.no_depth_test = true
	label.outline_size = 16
	label.position = at + inward * 1.2 + Vector3(0, 1.3, 0)
	label.scale = Vector3.ONE * 0.2
	_root.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)
	for i in FIREWORKS:
		var side := Vector3(-inward.z, 0, inward.x) * randf_range(-1.5, 1.5)
		var burst_at := at + inward * randf_range(1.0, 3.0) + side + Vector3(0, randf_range(1.2, 2.0), 0)
		get_tree().create_timer(i * 0.25).timeout.connect(_launch_firework.bind(at, burst_at, _root))
	(_tokens[index] as Character).celebrate()


## A glowing rocket rises from `from` and bursts into sparks at `to`.
func _launch_firework(from: Vector3, to: Vector3, root: Node3D) -> void:
	if not is_instance_valid(root):
		return
	var color: Color = FIREWORK_COLORS[randi() % FIREWORK_COLORS.size()]
	var rocket := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.04
	ball.height = 0.08
	rocket.mesh = ball
	rocket.material_override = _glow_material(color)
	rocket.position = from + Vector3(0, 0.3, 0)
	root.add_child(rocket)
	var tw := create_tween()
	tw.tween_property(rocket, "position", to, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		rocket.queue_free()
		_burst(to, color, root))


func _burst(at: Vector3, color: Color, root: Node3D) -> void:
	if not is_instance_valid(root):
		return
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 90
	sparks.lifetime = 1.2
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = 1.4
	sparks.initial_velocity_max = 2.2
	sparks.gravity = Vector3(0, -2.0, 0)
	sparks.damping_min = 1.0
	sparks.damping_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, color.lightened(0.3))
	fade.set_color(1, Color(color, 0.0))
	sparks.color_ramp = fade
	var dot := SphereMesh.new()
	dot.radius = 0.045
	dot.height = 0.09
	dot.radial_segments = 6
	dot.rings = 3
	sparks.mesh = dot
	var m := _glow_material(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sparks.material_override = m
	sparks.position = at
	root.add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(sparks.lifetime + 0.3).timeout.connect(sparks.queue_free)


func _glow_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func _process(delta: float) -> void:
	_time += delta
	if game == null or _tokens.is_empty():
		return
	_move_camera(delta)
	_ring.position = _tokens[game.current].position + Vector3(0, 0.03, 0)
	for i in _spinners.size():
		var s := _spinners[i]
		s.rotation.y = sin(_time * 1.2 + i) * 0.45
		s.position.y = SUIT_HEIGHT + sin(_time * 2.0 + i) * 0.05
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
	var entry := {"mesh": tile, "base": base}

	var title: String = TYPE_LABELS.get(s.type, "")
	match s.type:
		"lot":
			title = ""
			var building := _box(Vector3.ONE, Color.WHITE)
			building.position = _pos(s.id) + Vector3(0, 0, -0.12)
			_root.add_child(building)
			entry.building = building
			var post := _box(Vector3(0.03, SIGN_HEIGHT, 0.03), Color("#7a5a3a"))
			post.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT / 2, 0.34)
			_root.add_child(post)
			var board := _box(Vector3(0.56, 0.24, 0.03), Color.WHITE)
			board.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT, 0.34)
			board.rotation_degrees.x = -35  # tilted back towards the camera
			_root.add_child(board)
			entry.sign_board = board
			var amount := _label("", 64, Color.BLACK)
			amount.rotation_degrees.x = -35
			amount.outline_size = 0
			amount.pixel_size = 0.0035
			amount.position = board.position + board.basis.z * 0.02
			_root.add_child(amount)
			entry.sign_label = amount
		"relay":
			title = "%s %s" % [SUIT_SYMBOLS.get(s.mark, ""), s.mark.to_upper()]
			var suit := _suit(s.mark, s.color)
			suit.scale = Vector3.ONE * 2.6
			suit.position = _pos(s.id) + Vector3(0, SUIT_HEIGHT, -0.15)
			_root.add_child(suit)
			_spinners.append(suit)
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

	if title != "":
		var label := _label(title, 48 if s.type == "wildcard" else 30, Color.WHITE)
		label.position = _pos(s.id) + Vector3(0, TILE_H + 0.01, 0.12)
		_root.add_child(label)
	_tiles[s.id] = entry


## A suit symbol modelled from primitives, standing upright (it sways in _process).
func _suit(mark: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var shape := Node3D.new()
	shape.scale = Vector3(1, 1, 0.35)  # flatten into a thick badge
	root.add_child(shape)
	var m := _material(color, 0.5)
	match mark:
		"Diamond":
			var d := _shape_part(BoxMesh.new(), m, Vector3.ZERO, 0.16)
			d.rotation_degrees.z = 45
			shape.add_child(d)
			shape.scale.y = 1.35
		"Heart", "Spade":
			var lobes := Node3D.new()
			lobes.add_child(_shape_part(SphereMesh.new(), m, Vector3(-0.055, 0.035, 0), 0.13))
			lobes.add_child(_shape_part(SphereMesh.new(), m, Vector3(0.055, 0.035, 0), 0.13))
			var point := _shape_part(BoxMesh.new(), m, Vector3(0, -0.035, 0), 0.13)
			point.rotation_degrees.z = 45
			lobes.add_child(point)
			if mark == "Spade":
				lobes.rotation_degrees.z = 180
				lobes.position.y = 0.03
				shape.add_child(_stem(m))
			shape.add_child(lobes)
		"Club":
			shape.add_child(_shape_part(SphereMesh.new(), m, Vector3(0, 0.07, 0), 0.12))
			shape.add_child(_shape_part(SphereMesh.new(), m, Vector3(-0.065, -0.02, 0), 0.12))
			shape.add_child(_shape_part(SphereMesh.new(), m, Vector3(0.065, -0.02, 0), 0.12))
			shape.add_child(_stem(m))
		_:
			shape.add_child(_shape_part(SphereMesh.new(), m, Vector3.ZERO, 0.16))
	return root


func _stem(m: Material) -> MeshInstance3D:
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.012
	cyl.bottom_radius = 0.04
	cyl.height = 0.12
	stem.mesh = cyl
	stem.material_override = m
	stem.position.y = -0.09
	return stem


## A primitive of `size` (diameter, or edge for boxes) at `at`.
func _shape_part(mesh: PrimitiveMesh, m: Material, at: Vector3, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.scale = Vector3.ONE * size
	if mesh is SphereMesh:
		mesh.radius = 0.5
		mesh.height = 1.0
	return mi


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


## Works out the whole-board view; _process() moves the camera between it and
## the close follow view of the current player.
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
	_overview_look = center
	_overview_pos = center + CAMERA_DIR.normalized() * dist


# --- helpers ------------------------------------------------------------

func _pos(id: int) -> Vector3:
	var s := game.board.spaces[id]
	return Vector3(s.x * SPACING, 0, s.y * SPACING)


## Where a token stands on its space; up to four share a tile, one per corner.
func _token_spot(index: int) -> Vector3:
	var p := game.players[index]
	var off := Vector3(-0.3 if index % 2 == 0 else 0.3, TILE_H, -0.3 if index < 2 else 0.3)
	return _pos(_preview.get(index, p.position)) + off


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
