class_name BoardView
extends Node3D
## Basic 3D board built from placeholder meshes: box tiles, a building on each
## lot sized by its value, a house framed in its block's colour, with a signpost
## showing the price (or rent once owned),
## suit beacons on the Relays, walking figures and floating text popups. Call build() for a new game and sync() after every change.

const SPACING := 1.15
const TILE := 1.0
const TILE_H := 0.16
const MOVE_TIME := 0.24
const VALUE_FOR_FULL_SIZE := 2000.0  # lot value whose building reaches full size
const BUILDING_MIN_H := 0.06
const BUILDING_MAX_H := 1.0
const UNOWNED_BUILDING := Color("#d8d8de")
const FIGURE_SCALE := 1.35
const SIGN_HEIGHT := 0.32
const SUIT_HEIGHT := 0.65
const CAMERA_DIR := Vector3(0, 0.85, 0.55)  # from the look point towards the camera
const FOLLOW_DIST := 7.5   # camera distance when following a player
const CAMERA_EASE := 5.0   # how quickly the camera glides to where it should be
const FIREWORKS := 6
const PAYDAY_SECONDS := 2.8  # the PAYDAY show, banner and fireworks, start to finish
const FIREWORK_COLORS := [Color("#ff4a5a"), Color("#ffd84a"), Color("#4ae0ff"), Color("#7dff6a"), Color("#ff7ae8"), Color("#ffffff")]
const ROOF_COLOR := Color("#ffd84a")  # whole-block buildings wear gold roofs
## A lot's tile is a frame in its block's colour round a panel: cream while for
## sale, the owner's colour once bought.
const FRAME := 0.08  # the border's width
const RELAY_FRAME := Color("#f3ecd9")  # the suit spaces' cream-white border
const WILDCARD_MARK := Color("#5ee05a")  # the Card space's green ?
const DICE_GREEN := Color("#22b84a")
const STAR_SQUARES := [Color("#1f6fb8"), Color("#1f9a5a"), Color("#4cc878")]  # blue edge, green middle
const STAR_YELLOW := Color("#ffd84a")
const STAR_RIM := Color("#d9841a")
const STAR_THICK := 0.02
const CABINET := Color("#2b3fa8")  # the arcade cabinet's body
const CABINET_STRIPE := Color("#ffd84a")
const ARCADE_FLOOR := [Color("#26262c"), Color("#2e2e35"), Color("#37373f")]
const DICE_BLOCK := 0.3  # the rolled dice block's size
const DICE_NUMBER := Color("#2450c8")
const INK_ALPHA := 0.1  # the dice outlines' opacity (90% see-through)
const DICE_DEPTH := 1.6  # how far in front of the camera the hit block bounces
const BLOCK_HEIGHT := 1.05  # the dice block over a head, above the token's feet
const BOUNCE_SECONDS := 1.1
const UNOWNED_ROOF := Color("#8e8e96")  # houses are all grey until bought
const EARTH := Color("#8a5a34")
const GRASS := Color("#4fb83c")
const SALE_RED := Color("#e8463a")
const STONE := Color("#9a958c")
const BANK_STONE := Color("#f1e6cc")
const BANK_GOLD := Color("#f2bf2a")
const BANK_CARPET := Color("#c8283c")
const WOOD := Color("#a0703c")
const HOUSE_WINDOW := Color("#fff2b0")
const HOUSE_DOOR := Color("#6b4a2e")
const HOUSE_TRIM := Color("#8a6a55")  # the chimney
const PANEL_FOR_SALE := Color("#ece6d4")
const TYPE_COLORS := {
	"depot": Color("#f2f2f2"), "market": Color("#2e8b80"), "wildcard": Color("#6a35b0"),
	"workshop": Color("#b07a4a"), "toll": Color("#d9534f"), "dice": Color("#3fb6c9"), "arcade": Color("#ff8c3a"), "interest": Color("#e8b630"), "break": Color("#2a3570"), "plot": Color("#8a8f99"),
	"detour": Color("#9a8fe0"), "junction": Color("#6c6c78"),
}
const TYPE_LABELS := {
	"depot": "", "market": "MARKET", "wildcard": "?", "workshop": "WORKSHOP",
	"toll": "TOLL", "dice": "DICE", "arcade": "ARCADE", "interest": "STAR", "break": "MOON", "plot": "", "detour": "DETOUR", "junction": "",
}
const PLAYER_COLORS := [Color("#e84a4a"), Color("#4a7fe8"), Color("#48b860"), Color("#e8a02a")]
const SUIT_SYMBOLS := {"Spade": "♠", "Heart": "♥", "Diamond": "♦", "Club": "♣"}

var game: GameState
var highlight: Array[int] = []  # spaces offered as a branch choice
var zoom_for_highlight := true  # pull back to the whole board while highlighting
var hold_overview := false  # whole board until switched off (View Map)
var always_overview := false  # the player's option: never follow, show the whole board

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
var _focus_pos := Vector3.ZERO  # a close look at one block (whole_block)
var _focus_look := Vector3.ZERO
var _focus_until := 0.0
var _cam_look := Vector3.ZERO
var _env: Environment  # tinted by sunset()
var _sun: DirectionalLight3D
var _block: Node3D  # the dice block (show_block / hit_block)
var _block_mode := ""  # "spin" over a head, "bounce" in front of the camera
var _block_vel := Vector3.ZERO  # while bouncing, in camera space
var _block_spin := Vector3.ZERO
var _block_flick := 0.0  # seconds until its numbers change
var _block_y := 0.0  # its height while spinning over a head
var _block_index := -1  # whose head it spins over

signal block_hit     # a player's fist meets the dice block
signal block_bounce  # it hits the bottom of the screen
signal block_landed  # it settles showing the roll
signal space_clicked(id: int)  # a click on a space on the board (Warp Gate)


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#8cc8f0")  # a clear sky over the golf course
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bcd4ee")  # sky-tinted fill, so shade looks cool
	env.ambient_light_energy = 0.34
	# A touch darker, with a little more contrast: a sunny day, not a glare.
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.92
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.95
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("#fff0d8")  # warm afternoon sun
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	add_child(sun)
	_env = env
	_sun = sun
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
	var table := _box(Vector3(hi.x - lo.x + 2.0, 0.1, hi.z - lo.z + 2.0), Color("#5fae48"))  # mown grass
	_center = (lo + hi) / 2
	table.position = (lo + hi) / 2 - Vector3(0, 0.05, 0)
	_root.add_child(table)
	_build_golf_course(lo, hi)

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
	# Dev switch --look=<space type>[@distance]: hold the camera on the first one.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--look="):
			var parts := arg.substr(7).split("@")
			for s in g.board.spaces:
				if s.type == parts[0]:
					_focus_look = _pos(s.id) + Vector3(0, 0.3, 0)
					_focus_pos = _focus_look + CAMERA_DIR.normalized() * (float(parts[1]) if parts.size() > 1 else 2.6)
					_focus_until = INF
					break


## Brings every mesh in line with the game state. Tokens glide unless `instant`.
func sync(instant := false) -> void:
	if game == null:
		return
	for id in game.plots:
		_sync_plot(id)
	for id in game.lots:
		var t: Dictionary = _tiles[id]
		var lot: Dictionary = game.lots[id]
		var mat: StandardMaterial3D = t.mesh.material_override
		# The house's size follows the lot's value; the sign shows the price
		# while it is for sale and the rent once owned, in the owner's colour.
		var building: Node3D = t.building
		var size := sqrt(game.lot_value(id) / VALUE_FOR_FULL_SIZE)
		var h := BUILDING_MIN_H + BUILDING_MAX_H * size
		var w := 0.2 + 0.3 * minf(size, 1.0)
		var key := Vector2(snappedf(w, 0.01), snappedf(h, 0.01))
		if t.get("house_size") != key:
			t.house_size = key
			_build_house(t, key.x, key.y)
		var roof_at: Node3D = t.roof_at
		roof_at.position = building.position + Vector3(0, t.house_top, 0)
		var whole: bool = lot.owner >= 0 and game.whole_block_owner(game.space(id).block) == lot.owner
		var sign_mat: StandardMaterial3D = t.sign_board.material_override
		var bmat: StandardMaterial3D = t.body_mat
		var rmat: StandardMaterial3D = t.roof_mat
		var pmat: StandardMaterial3D = t.panel.material_override
		mat.albedo_color = t.base  # the frame always shows the block
		rmat.emission_enabled = whole
		if lot.owner < 0:
			pmat.albedo_color = PANEL_FOR_SALE
			bmat.albedo_color = UNOWNED_BUILDING
			rmat.albedo_color = UNOWNED_ROOF
			sign_mat.albedo_color = Color("#f4f1e6")
			t.sign_label.modulate = Color("#202020")
			t.sign_label.text = "%d G" % game.lot_value(id)
			t.sign_label.font_size = 58
		elif game.players[lot.owner].on_break:  # the Moon: shut until their next turn
			pmat.albedo_color = PLAYER_COLORS[lot.owner].darkened(0.55)
			bmat.albedo_color = PLAYER_COLORS[lot.owner].lerp(Color.WHITE, 0.45).darkened(0.45)
			rmat.albedo_color = (ROOF_COLOR if whole else PLAYER_COLORS[lot.owner].darkened(0.25)).darkened(0.45)
			sign_mat.albedo_color = Color("#2a2a32")
			t.sign_label.modulate = Color("#ff5a5a")
			t.sign_label.text = "✕ CLOSED"
			t.sign_label.font_size = 38  # fits the sign on one line
		else:
			pmat.albedo_color = PLAYER_COLORS[lot.owner].lightened(0.2)
			bmat.albedo_color = PLAYER_COLORS[lot.owner].lerp(Color.WHITE, 0.45)
			rmat.albedo_color = ROOF_COLOR if whole else PLAYER_COLORS[lot.owner].darkened(0.25)
			sign_mat.albedo_color = PLAYER_COLORS[lot.owner]
			t.sign_label.modulate = Color.WHITE
			t.sign_label.text = "%d G" % game.rent(id)
			t.sign_label.font_size = 58

	for id in _tiles:
		var parts: Array = [_tiles[id].mesh]
		if _tiles[id].has("panel"):
			parts.append(_tiles[id].panel)
		for part: MeshInstance3D in parts:
			var mat: StandardMaterial3D = part.material_override
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


## The dice block appears over player `index`'s head, spinning with its numbers
## flicking, until hit_block().
func show_block(index: int) -> void:
	clear_block()
	_block = _dice_block()
	_root.add_child(_block)
	_block.position = _tokens[index].position + Vector3(0, BLOCK_HEIGHT, 0)
	_block_y = TILE_H + BLOCK_HEIGHT
	_block_index = index
	_block.scale = Vector3.ZERO
	create_tween().tween_property(_block, "scale", Vector3.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_block_mode = "spin"


## Player `index` punches the block: it flies at the screen, bounces round the
## bottom of it as if just in front of the camera, and settles face on
## showing `result`, then vanishes. Returns once it has gone.
func hit_block(index: int, result: int) -> void:
	if _block == null:
		show_block(index)
	var figure := _tokens[index] as Character
	figure.punch()
	await get_tree().create_timer(Character.PUNCH_IMPACT).timeout
	block_hit.emit()
	_burst(_block.global_position, Color.WHITE, _root)
	# Hand it over to the camera at the same spot on screen and the same size.
	var held := _block.global_transform
	var at := _camera.to_local(held.origin)
	var shrink := DICE_DEPTH / maxf(-at.z, 0.01)
	_root.remove_child(_block)
	_camera.add_child(_block)
	_block.global_transform = held
	_block.position = at * shrink
	_block.scale = Vector3.ONE * shrink
	create_tween().tween_property(_block, "scale", Vector3.ONE * 0.75, 0.3)
	var side := -signf(at.x) if absf(at.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	_block_vel = Vector3(side * randf_range(0.6, 1.2), 2.4, 0)
	_block_spin = Vector3(randf_range(7, 11), randf_range(4, 8), randf_range(-6, 6))
	_block_mode = "bounce"
	await get_tree().create_timer(BOUNCE_SECONDS).timeout
	# Settle face on, the roll on its front.
	_block_mode = ""
	var faces: Array = _block.get_meta("faces")
	for f in faces:
		(f as Label3D).text = str(result)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_block, "position", Vector3(0, -_half_height() * 0.1, -DICE_DEPTH), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_block, "quaternion", Quaternion.IDENTITY, 0.35)
	tw.tween_property(_block, "scale", Vector3.ONE * 0.95, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	block_landed.emit()
	await get_tree().create_timer(0.8).timeout
	var out := create_tween()
	out.tween_property(_block, "scale", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	clear_block()


## Landing on the Star: a smiling star rises out of player `index` and grows
## slowly, turned to face the camera, twinkles popping round it, then shrinks
## away at the end of `seconds`.
func star_rise(index: int, seconds: float) -> void:
	var holder := Node3D.new()
	holder.position = _tokens[index].position + Vector3(0, 0.7, 0)
	holder.scale = Vector3.ONE * 0.15
	_root.add_child(holder)
	var star := _smiling_star()
	star.rotation.x = atan2(CAMERA_DIR.z, CAMERA_DIR.y)  # its face towards the camera
	holder.add_child(star)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(holder, "position:y", holder.position.y + 1.1, seconds).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "scale", Vector3.ONE * 1.5, seconds).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_property(holder, "rotation:y", 0.35, seconds).from(-0.35).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(holder, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(holder.queue_free)
	for k in int(seconds / 0.09):  # twinkles round it as it goes
		var twinkle := _label("✦", 64, [STAR_YELLOW, Color.WHITE, Color("#fff2b0")][k % 3], true)
		twinkle.outline_size = 0
		twinkle.no_depth_test = true
		twinkle.scale = Vector3.ZERO
		_root.add_child(twinkle)
		var t := create_tween()
		t.tween_interval(k * 0.09)
		t.tween_callback(func():
			var spread := 0.25 + 0.3 * holder.scale.x
			twinkle.position = holder.position + Vector3(randf_range(-spread, spread),
					randf_range(-spread, spread) * 0.8, randf_range(-0.1, 0.1)))
		t.tween_property(twinkle, "scale", Vector3.ONE * randf_range(0.5, 1.0), 0.12)
		t.tween_property(twinkle, "scale", Vector3.ZERO, 0.25)
		t.tween_callback(twinkle.queue_free)


func clear_block() -> void:
	if _block:
		_block.queue_free()
	_block = null
	_block_mode = ""


## Half the screen's height, in camera space, at the bouncing block's depth.
func _half_height() -> float:
	return DICE_DEPTH * tan(deg_to_rad(_camera.fov / 2))


func _move_block(delta: float) -> void:
	_block_flick -= delta
	if _block_mode != "" and _block_flick <= 0.0:
		_block_flick = 0.07
		for f in _block.get_meta("faces"):
			(f as Label3D).text = str(randi_range(2, 2 * GameState.DIE_SIDES))
	match _block_mode:
		"spin":
			_block.rotation.y += delta * 5.0
			_block.rotation.x = sin(_time * 3.0) * 0.4
			# Over their head wherever they are, even if they are still walking.
			var head := _tokens[_block_index].position
			_block.position = Vector3(head.x, _block_y + sin(_time * 4.0) * 0.04, head.z)
		"bounce":
			var half_h := _half_height()
			var view := get_viewport().get_visible_rect().size
			var half_w := half_h * view.x / maxf(view.y, 1.0)
			_block_vel.y -= 9.0 * delta
			_block.position += _block_vel * delta
			var floor_y := -half_h * 0.55
			if _block.position.y < floor_y and _block_vel.y < 0.0:
				_block.position.y = floor_y
				_block_vel.y *= -0.62
				_block_vel.x *= 0.85
				_block_spin *= 0.7
				block_bounce.emit()
			if absf(_block.position.x) > half_w * 0.75 and signf(_block_vel.x) == signf(_block.position.x):
				_block_vel.x = -_block_vel.x
			_block.rotation += _block_spin * delta

## A block has just come into one player's hands: the camera moves in on its
## lots for `seconds` while, one after another, each building spins round,
## puts on its gold roof and throws sparks, under a WHOLE BLOCK! banner.
func whole_block(ids: Array[int], seconds: float) -> void:
	if ids.is_empty():
		return
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for id in ids:
		lo = lo.min(_pos(id))
		hi = hi.max(_pos(id))
	var center := (lo + hi) / 2
	var view := get_viewport().get_visible_rect().size
	var aspect := view.x / maxf(view.y, 1.0)
	var need := maxf(hi.z - lo.z, (hi.x - lo.x) / aspect) + 3.0
	var dist := maxf(4.5, need * 0.5 / tan(deg_to_rad(_camera.fov * 0.5)))
	_focus_look = center + Vector3(0, 0.3, 0)
	_focus_pos = _focus_look + CAMERA_DIR.normalized() * dist
	_focus_until = _time + seconds
	var owner: int = game.lots[ids[0]].owner
	var color: Color = PLAYER_COLORS[owner] if owner >= 0 else ROOF_COLOR
	for i in ids.size():
		var t: Dictionary = _tiles[ids[i]]
		var roof: Node3D = t.roof
		roof.scale = Vector3.ZERO
		var delay := Music.FANFARE_LEAD_IN + i * Music.FANFARE_STEP  # in time with its note
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(t.building, "rotation:y", TAU, 0.55) \
				.from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(roof, "scale", Vector3.ONE, 0.45) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			t.building.rotation.y = 0.0
			var top: Vector3 = (t.roof_at as Node3D).position + Vector3(0, 0.3, 0)
			_burst(top, ROOF_COLOR, _root)
			_burst(top, color, _root))
	var label := _label("WHOLE BLOCK!", 110, ROOF_COLOR, true)
	label.no_depth_test = true
	label.outline_size = 16
	label.position = center + Vector3(0, 1.6, 0)
	label.scale = Vector3.ONE * 0.2
	_root.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.5, seconds - 0.8))
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


## Pulls the camera back to show the whole board for `seconds`.
func overview(seconds: float) -> void:
	_overview_until = maxf(_overview_until, _time + seconds)


## Whole board during an overview or while choices are highlighted, else close
## behind the current player.
func _move_camera(delta: float) -> void:
	var look := _overview_look
	var pos := _overview_pos
	if _time < _focus_until:
		look = _focus_look
		pos = _focus_pos
	elif _time >= _overview_until and not hold_overview and not always_overview \
			and (highlight.is_empty() or not zoom_for_highlight):
		look = _tokens[game.current].position
		pos = look + CAMERA_DIR.normalized() * FOLLOW_DIST
	var k := minf(1.0, delta * CAMERA_EASE)
	_camera.position = _camera.position.lerp(pos, k)
	_cam_look = _cam_look.lerp(look, k)
	_camera.look_at(_cam_look, Vector3.UP)

## A plot: earth and a SALE sign while empty; once built, the owner's colour,
## a model of the building (_plot_model) and a sign with what rivals pay.
func _sync_plot(id: int) -> void:
	var t: Dictionary = _tiles[id]
	var plot: Dictionary = game.plots[id]
	var mat: StandardMaterial3D = t.mesh.material_override
	var sign_mat: StandardMaterial3D = t.sign_board.material_override
	t.sale.visible = plot.owner < 0
	# An empty plot shows only its SALE sign; the cost is on the landing menu.
	for part: Node3D in [t.sign_post, t.sign_board, t.sign_label]:
		part.visible = plot.owner >= 0
	var key := "%s|%d|%d" % [plot.kind, plot.owner, plot.level] if plot.owner >= 0 else ""
	if t.get("model_key", "") != key:
		t.model_key = key
		for child in (t.model_at as Node3D).get_children():
			child.queue_free()
		if key != "":
			t.model_at.add_child(_plot_model(plot.kind, PLAYER_COLORS[plot.owner], plot.level))
	if plot.owner < 0:
		mat.albedo_color = TYPE_COLORS.plot
		return
	var colour: Color = PLAYER_COLORS[plot.owner]
	mat.albedo_color = colour.lerp(Color.WHITE, 0.25)
	sign_mat.albedo_color = colour
	t.sign_label.font_size = 40
	t.sign_label.modulate = Color.WHITE
	match plot.kind:
		"bridge":
			t.sign_label.text = "Toll %d G" % plot.toll
		"tax":
			t.sign_label.text = "Tax %d%%" % roundi(Plots.TAX_RATE * 100)
		_:
			t.sign_label.text = "%d G" % Plots.rival_charge(game, id, null)


## Take a break (the Moon space): the sky and light glow through a sunset,
## orange then dusky purple, and back to normal, while the camera shows the
## whole board so the closed signs can be seen.
func sunset(seconds := 2.6) -> void:
	overview(seconds)
	var sky := _env.background_color
	var ambient := _env.ambient_light_color
	var light := _sun.light_color
	var energy := _sun.light_energy
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_env, "background_color", Color("#ff8a4a"), seconds * 0.3)
	tw.tween_property(_env, "ambient_light_color", Color("#ffb070"), seconds * 0.3)
	tw.tween_property(_sun, "light_color", Color("#ff9a5a"), seconds * 0.3)
	tw.chain().tween_property(_env, "background_color", Color("#4a2a5a"), seconds * 0.35)
	tw.tween_property(_sun, "light_energy", energy * 0.55, seconds * 0.35)
	tw.tween_property(_env, "ambient_light_color", Color("#8a6ab0"), seconds * 0.35)
	tw.chain().tween_property(_env, "background_color", sky, seconds * 0.35)
	tw.tween_property(_env, "ambient_light_color", ambient, seconds * 0.35)
	tw.tween_property(_sun, "light_color", light, seconds * 0.35)
	tw.tween_property(_sun, "light_energy", energy, seconds * 0.35)


## PAYDAY: fireworks over the Depot, a big gold banner and the player celebrating.
func payday(index: int, amount: int) -> void:
	var at := _pos(game.board.depot)
	# Aim the show in over the board: the Depot may sit at an edge or corner.
	var inward := (_center - at).normalized()
	overview(2.4)
	var label := _label("PAYDAY!\n+%d G" % amount, 110, Color("#ffd84a"), true)
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
	if _block:
		_move_block(delta)
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
	elif s.type in ["relay", "dice", "interest", "arcade"]:
		base = RELAY_FRAME
	var tile := _box(Vector3(TILE, TILE_H, TILE), base)
	tile.position = _pos(s.id) + Vector3(0, TILE_H / 2, 0)
	_root.add_child(tile)
	var entry := {"mesh": tile, "base": base}

	var title: String = TYPE_LABELS.get(s.type, "")
	match s.type:
		"lot":
			title = ""
			var panel := _box(Vector3(TILE - 2 * FRAME, 0.012, TILE - 2 * FRAME), PANEL_FOR_SALE)
			panel.position = _pos(s.id) + Vector3(0, TILE_H + 0.006, 0)
			_root.add_child(panel)
			entry.panel = panel
			# The house: sync() builds it to the lot's size (_build_house) and
			# colours it; whole_block() spins it and pops its roof.
			var building := Node3D.new()
			building.position = _pos(s.id) + Vector3(0, TILE_H, -0.12)
			_root.add_child(building)
			entry.building = building
			entry.body_mat = _material(Color.WHITE)
			entry.roof_mat = _material(ROOF_COLOR, 0.35)
			entry.roof_mat.emission_enabled = false  # lit for a whole block
			var roof_at := Node3D.new()  # the top of the roof, for the bursts
			_root.add_child(roof_at)
			entry.roof_at = roof_at
			var post := _box(Vector3(0.03, SIGN_HEIGHT, 0.03), Color("#7a5a3a"))
			post.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT / 2, 0.34)
			_root.add_child(post)
			var board := _box(Vector3(0.74, 0.24, 0.03), Color.WHITE)  # fits "1088 G"
			board.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT, 0.34)
			board.rotation_degrees.x = -35  # tilted back towards the camera
			_root.add_child(board)
			entry.sign_board = board
			var amount := _label("", 58, Color.BLACK)
			amount.rotation_degrees.x = -35
			amount.outline_size = 0
			amount.pixel_size = 0.0035
			amount.position = board.position + board.basis.z * 0.02
			_root.add_child(amount)
			entry.sign_label = amount
		"relay":
			# A white frame round a square of the suit's colour mixed with
			# white, the suit glowing on it under the floating one.
			title = ""
			_glow_squares(s.id, s.color, entry)
			var symbol: String = SUIT_SYMBOLS.get(s.mark, "")
			var at := _pos(s.id) + Vector3(0, TILE_H + 0.02, 0.02)
			for ring in [[90, 0.15], [60, 0.25], [34, 0.45]]:  # the glow, fading outwards
				var halo := _label(symbol, 190, Color(s.color, 0.0))
				halo.outline_size = ring[0]
				halo.outline_modulate = Color(s.color.lightened(0.45), ring[1])
				halo.position = at
				_root.add_child(halo)
			var mark := _label(symbol, 190, s.color.lightened(0.3))
			mark.outline_size = 8
			mark.outline_modulate = Color(1, 1, 1, 0.9)
			mark.position = at + Vector3(0, 0.002, 0)
			_root.add_child(mark)
			var suit := _suit(s.mark, s.color)
			suit.scale = Vector3.ONE * 2.6
			suit.position = _pos(s.id) + Vector3(0, SUIT_HEIGHT, -0.15)
			_root.add_child(suit)
			_spinners.append(suit)
		"dice":  # a flat die on green that glows lighter to the middle
			title = ""
			_glow_squares(s.id, DICE_GREEN, entry, 0.6, 0.45)
			var die := _flat_die()
			die.position = _pos(s.id) + Vector3(0, TILE_H + 0.012, 0)
			_root.add_child(die)
		"interest":  # a smiling star lying on green and blue
			title = ""
			_squares(s.id, STAR_SQUARES, entry, 0.25)
			var star := _smiling_star()
			star.position = _pos(s.id) + Vector3(0, TILE_H + 0.012, 0)
			_root.add_child(star)
		"arcade":
			title = ""
			_squares(s.id, ARCADE_FLOOR, entry)  # a dim arcade-room floor
			var cabinet := _arcade_cabinet()
			cabinet.position = _pos(s.id) + Vector3(0, TILE_H + 0.012, -0.05)
			cabinet.rotation_degrees.y = -6  # nearly square on, a touch of the side showing
			_root.add_child(cabinet)
		"break":  # a big crescent moon floating over the tile
			var icon := _label("☾", 110, Color("#fff2b0"), true)
			icon.outline_size = 18
			icon.position = _pos(s.id) + Vector3(0, SUIT_HEIGHT, -0.15)
			_root.add_child(icon)
			_spinners.append(icon)
		"depot":  # the Bank: a grand bank with a money bag on top, a red carpet to its door
			title = ""
			var bank := _bank_building()
			bank.position = _pos(s.id) + Vector3(0, TILE_H, -0.27)
			_root.add_child(bank)
			var carpet := _box(Vector3(0.18, 0.01, 0.56), BANK_CARPET)
			carpet.position = _pos(s.id) + Vector3(0, TILE_H + 0.005, 0.2)
			_root.add_child(carpet)
			for x in [-0.1, 0.1]:  # its gold edging
				var edge := _box(Vector3(0.02, 0.012, 0.56), BANK_GOLD)
				edge.position = _pos(s.id) + Vector3(x, TILE_H + 0.006, 0.2)
				_root.add_child(edge)
			var word := _label("BANK", 64, BANK_GOLD)
			word.outline_size = 14
			word.outline_modulate = Color("#5a2a7a")
			word.position = _pos(s.id) + Vector3(0, TILE_H + 0.014, 0.36)
			_root.add_child(word)

	if title != "":
		var label := _label(title, 30, Color.WHITE)
		label.position = _pos(s.id) + Vector3(0, TILE_H + 0.01, 0.12)
		if s.type == "wildcard":  # a big green ? on purple
			label.font_size = 130
			label.modulate = WILDCARD_MARK
			label.outline_size = 18
			label.outline_modulate = Color("#2a1440")
			label.position.z = _pos(s.id).z
		_root.add_child(label)
		entry.title = label
	if s.type == "plot":
		# Its building (a model) and a sign with what rivals pay; sync() fills
		# them in once something is built.
		var model_at := Node3D.new()
		model_at.position = _pos(s.id) + Vector3(0, TILE_H, -0.08)
		_root.add_child(model_at)
		entry.model_at = model_at
		# While nothing is built: bare earth with grass round it and a
		# cartoon SALE sign.
		var sale := _for_sale()
		sale.position = _pos(s.id) + Vector3(0, TILE_H, 0)
		_root.add_child(sale)
		entry.sale = sale
		var post := _box(Vector3(0.03, SIGN_HEIGHT, 0.03), Color("#7a5a3a"))
		post.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT / 2, 0.34)
		_root.add_child(post)
		entry.sign_post = post
		var board := _box(Vector3(0.74, 0.24, 0.03), Color.WHITE)
		board.position = _pos(s.id) + Vector3(0, TILE_H + SIGN_HEIGHT, 0.34)
		board.rotation_degrees.x = -35
		_root.add_child(board)
		entry.sign_board = board
		var fee := _label("", 40, Color.BLACK)
		fee.rotation_degrees.x = -35
		fee.outline_size = 0
		fee.pixel_size = 0.0035
		fee.position = board.position + board.basis.z * 0.02
		_root.add_child(fee)
		entry.sign_label = fee
	_tiles[s.id] = entry


## (Re)builds a lot's house `w` wide and `h` tall (walls, not counting the
## roof) in its holder: walls with a door and a row of windows per floor, a
## gabled roof facing the camera and a chimney. Colours come from the tile's
## body_mat and roof_mat, which sync() sets.
static func _build_house(t: Dictionary, w: float, h: float) -> void:
	var holder: Node3D = t.building
	for child in holder.get_children():
		child.queue_free()
	var d := w * 0.85
	var body := _box(Vector3(w, h, d), Color.WHITE)
	body.material_override = t.body_mat
	body.position.y = h / 2
	holder.add_child(body)
	var rh := w * 0.6
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(w * 1.2, rh, d * 1.12)
	roof.mesh = prism
	roof.material_override = t.roof_mat
	roof.position.y = h + rh / 2
	holder.add_child(roof)
	t.roof = roof
	t.house_top = h + rh
	var chimney := _box(Vector3(w * 0.14, rh * 0.7, w * 0.14), HOUSE_TRIM)
	chimney.position = Vector3(w * 0.3, h + rh * 0.55, -d * 0.15)
	holder.add_child(chimney)
	var front := d / 2 + 0.006
	var door_h := minf(0.15, h * 0.6)
	var door := _box(Vector3(w * 0.26, door_h, 0.012), HOUSE_DOOR)
	door.position = Vector3(0, door_h / 2, front)
	holder.add_child(door)
	var floors := clampi(roundi(h / 0.2), 1, 6)
	var floor_h := h / floors
	var pane := minf(w * 0.2, floor_h * 0.45)
	for f in floors:
		var y := door_h * 0.6 if f == 0 else (f + 0.5) * floor_h
		for x in ([-0.32, 0.32] if f == 0 else [-0.22, 0.22]):
			var window := _box(Vector3(pane, pane, 0.012), HOUSE_WINDOW)
			window.position = Vector3(w * x, y, front)
			holder.add_child(window)


## Squares on space `id` stepping lighter towards the middle: `color` at the
## edge, mostly white in the centre (the Relays, the Dice space). The outer
## one is the entry's panel; `glow` makes them shine, `whiten` (0..1) how pale
## the middle gets.
func _glow_squares(id: int, color: Color, entry: Dictionary, glow := 0.0, whiten := 1.0) -> void:
	_squares(id, [color.lerp(Color.WHITE, 0.15 * whiten), color.lerp(Color.WHITE, 0.4 * whiten),
			color.lerp(Color.WHITE, 0.65 * whiten)], entry, glow)


## Three squares on space `id`, outermost first, in `colors`.
func _squares(id: int, colors: Array, entry: Dictionary, glow := 0.0) -> void:
	var sizes := [TILE - 2 * FRAME, 0.68, 0.48]
	for i in sizes.size():
		var square := _box(Vector3(sizes[i], 0.012, sizes[i]), Color.WHITE)
		square.material_override = _material(colors[i], glow)
		square.position = _pos(id) + Vector3(0, TILE_H + 0.006 + i * 0.002, 0)
		_root.add_child(square)
		if i == 0:
			entry.panel = square


## A flat, smiling star lying on the tile, with a darker rim.
static func _smiling_star() -> Node3D:
	var root := Node3D.new()
	var rim := _star_mesh(0.34, 0.15, STAR_RIM)
	root.add_child(rim)
	var star := _star_mesh(0.3, 0.13, STAR_YELLOW, 0.3)
	star.position.y = 0.012
	root.add_child(star)
	var top := 0.012 + STAR_THICK
	for x in [-0.05, 0.05]:  # eyes
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		eye.mesh = ball
		eye.material_override = _material(Color("#2a1a10"))
		eye.scale = Vector3(0.028, 0.01, 0.05)
		eye.position = Vector3(x, top, -0.02)
		root.add_child(eye)
	for i in 7:  # the smile: dots along an arc, lowest in the middle
		var a := deg_to_rad(25.0 + i * 130.0 / 6)
		var dot := _box(Vector3(0.022, 0.01, 0.022), Color("#b83a1a"))
		dot.position = Vector3(cos(a) * 0.065, top, 0.015 + sin(a) * 0.05)
		root.add_child(dot)
	return root


## A flat five-pointed star, `outer`/`inner` in radius and STAR_THICK thick,
## its top point away from the camera.
static func _star_mesh(outer: float, inner: float, color: Color, glow := 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array[Vector3] = []
	for k in 10:
		var a := deg_to_rad(-90.0 + k * 36.0)
		var r := outer if k % 2 == 0 else inner
		ring.append(Vector3(cos(a) * r, 0, sin(a) * r))
	var up := Vector3(0, STAR_THICK, 0)
	for k in 10:
		var a := ring[k]
		var b := ring[(k + 1) % 10]
		st.add_vertex(up)  # top face, a fan from the middle
		st.add_vertex(a + up)
		st.add_vertex(b + up)
		for v in [a, b, b + up, a, b + up, a + up]:  # the edge
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := _material(color, glow)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


## A classic upright arcade cabinet, facing the camera: a lit marquee, a
## glowing screen with a maze of dots on it, a control panel with a joystick
## and two buttons, and a coin door.
static func _arcade_cabinet() -> Node3D:
	var root := Node3D.new()
	var body := _box(Vector3(0.36, 0.72, 0.3), CABINET)
	body.position.y = 0.36
	root.add_child(body)
	for x in [-0.181, 0.181]:  # stripes down the sides
		var stripe := _box(Vector3(0.004, 0.08, 0.3), CABINET_STRIPE)
		stripe.position = Vector3(x, 0.5, 0)
		root.add_child(stripe)
	var marquee := _box(Vector3(0.36, 0.11, 0.08), Color("#ffd84a"))
	marquee.material_override = _material(Color("#ffd84a"), 0.6)
	marquee.position = Vector3(0, 0.665, 0.17)
	root.add_child(marquee)
	var sign_text := _label("ARCADE", 40, Color("#d43a1a"), false)
	sign_text.rotation_degrees.x = 0
	sign_text.outline_size = 4
	sign_text.outline_modulate = Color.WHITE
	sign_text.pixel_size = 0.0016
	sign_text.position = Vector3(0, 0.665, 0.212)
	root.add_child(sign_text)
	var screen_at := Node3D.new()  # the screen, tipped back a little
	screen_at.position = Vector3(0, 0.48, 0.152)
	screen_at.rotation_degrees.x = -12
	root.add_child(screen_at)
	screen_at.add_child(_box(Vector3(0.3, 0.24, 0.01), Color("#151515")))  # bezel
	var glass := _box(Vector3(0.26, 0.2, 0.01), Color.WHITE)
	glass.material_override = _material(Color("#0a1440"), 0.8)
	glass.position.z = 0.004
	screen_at.add_child(glass)
	for wall in [[0, 0.085, 0.24, 0.012], [0, -0.085, 0.24, 0.012], [-0.115, 0, 0.012, 0.18],
			[0.115, 0, 0.012, 0.18], [0, 0.02, 0.1, 0.012], [-0.06, -0.035, 0.012, 0.06], [0.06, -0.035, 0.012, 0.06]]:
		var line := _box(Vector3(wall[2], wall[3], 0.004), Color.WHITE)
		line.material_override = _material(Color("#3a6aff"), 1.5)
		line.position = Vector3(wall[0], wall[1], 0.011)
		screen_at.add_child(line)
	for x in range(-4, 5):  # dots along the corridors
		for y in [-0.05, 0.055]:
			var pellet := _box(Vector3(0.008, 0.008, 0.004), Color.WHITE)
			pellet.material_override = _material(Color("#ffe8a0"), 1.5)
			pellet.position = Vector3(x * 0.024, y, 0.011)
			screen_at.add_child(pellet)
	var panel := _box(Vector3(0.36, 0.04, 0.14), CABINET.darkened(0.3))
	panel.position = Vector3(0, 0.32, 0.2)
	panel.rotation_degrees.x = 15  # sloping towards the player
	root.add_child(panel)
	var stick := _box(Vector3(0.012, 0.06, 0.012), Color("#202020"))
	stick.position = Vector3(-0.08, 0.36, 0.21)
	root.add_child(stick)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.022
	ball.height = 0.044
	knob.mesh = ball
	knob.material_override = _material(Color("#e8302a"))
	knob.position = Vector3(-0.08, 0.395, 0.21)
	root.add_child(knob)
	for b in [[0.04, Color("#3a8aff")], [0.1, Color("#ffd84a")]]:
		var button := MeshInstance3D.new()
		var cap := CylinderMesh.new()
		cap.top_radius = 0.016
		cap.bottom_radius = 0.016
		cap.height = 0.02
		button.mesh = cap
		button.material_override = _material(b[1], 0.3)
		button.position = Vector3(b[0], 0.345, 0.22)
		button.rotation_degrees.x = 15
		root.add_child(button)
	var door := _box(Vector3(0.14, 0.12, 0.01), Color("#1a1a1a"))
	door.position = Vector3(0, 0.15, 0.153)
	root.add_child(door)
	for x in [-0.03, 0.03]:  # lit coin slots
		var slot := _box(Vector3(0.02, 0.035, 0.006), Color.WHITE)
		slot.material_override = _material(Color("#ff8c3a"), 1.0)
		slot.position = Vector3(x, 0.16, 0.159)
		root.add_child(slot)
	return root


## A die drawn flat on the tile, like the Star space's star: a white face with
## a grey rim showing five pips, turned a little for a casual look.
static func _flat_die() -> Node3D:
	const PIP := 0.11  # a pip's offset from the face's centre
	var root := Node3D.new()
	root.rotation_degrees.y = 14
	var rim := _box(Vector3(0.48, 0.02, 0.48), Color("#b8b8b0"))
	rim.position.y = 0.01
	root.add_child(rim)
	var edge := _outline(Vector3(0.48, 0.02, 0.48), 0.012)
	edge.position.y = 0.01
	root.add_child(edge)
	var lines := _edges(Vector3(0.48, 0.02, 0.48), 0.01)
	lines.position.y = 0.01
	root.add_child(lines)
	var face := _box(Vector3(0.43, 0.024, 0.43), Color("#fbfbf6"))
	face.position.y = 0.014
	root.add_child(face)
	for p in [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]:
		var pip := MeshInstance3D.new()
		var dot := CylinderMesh.new()
		dot.top_radius = 0.04
		dot.bottom_radius = 0.04
		dot.height = 0.006
		pip.mesh = dot
		pip.material_override = _material(Color("#202028"))
		pip.position = Vector3(p.x * PIP, 0.028, p.y * PIP)
		root.add_child(pip)
	return root


## A dark outline round a box `size` big: a slightly bigger black box showing
## only its inside, so just a rim of it shows round the edges.
static func _outline(size: Vector3, width: float) -> MeshInstance3D:
	var hull := _box(size + Vector3.ONE * width * 2, Color.BLACK)
	var m := _ink()
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	hull.material_override = m
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hull


## The outlines' colour: the dice numbers' blue, untouched by the light and a
## little see-through so they read soft rather than harsh.
static func _ink() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(DICE_NUMBER, INK_ALPHA)  # the numbers' blue
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## A dark line along each of the 12 edges of a box `size` big, so every face
## of it is outlined (the dice).
static func _edges(size: Vector3, width: float) -> Node3D:
	var root := Node3D.new()
	var h := size / 2
	for axis in 3:
		for a in [-1, 1]:
			for b in [-1, 1]:
				var dims := Vector3.ONE * width
				dims[axis] = size[axis] + width
				var at := Vector3.ZERO
				at[(axis + 1) % 3] = a * h[(axis + 1) % 3]
				at[(axis + 2) % 3] = b * h[(axis + 2) % 3]
				var line := _box(dims, Color.BLACK)
				line.material_override = _ink()
				line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				line.position = at
				root.add_child(line)
	return root


## The dice block rolled over a player's head: a white cube with a number on
## every face (the block's "faces" meta, the front (+z) face first).
static func _dice_block() -> Node3D:
	var root := Node3D.new()
	var cube := _box(Vector3.ONE * DICE_BLOCK, Color.WHITE)
	cube.material_override = _material(Color("#fbfbf6"), 0.15)
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # it flies right up to the camera
	root.add_child(cube)
	root.add_child(_outline(Vector3.ONE * DICE_BLOCK, 0.018))
	root.add_child(_edges(Vector3.ONE * DICE_BLOCK, 0.014))
	var h := DICE_BLOCK / 2 + 0.002
	var faces: Array[Label3D] = []
	for f in [[Vector3(0, 0, h), Vector3.ZERO], [Vector3(0, 0, -h), Vector3(0, 180, 0)],
			[Vector3(h, 0, 0), Vector3(0, 90, 0)], [Vector3(-h, 0, 0), Vector3(0, -90, 0)],
			[Vector3(0, h, 0), Vector3(-90, 0, 0)], [Vector3(0, -h, 0), Vector3(90, 0, 0)]]:
		var number := Label3D.new()
		number.font_size = 120
		number.pixel_size = DICE_BLOCK / 150.0
		number.modulate = DICE_NUMBER
		number.outline_size = 0
		number.double_sided = false
		number.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		number.position = f[0]
		number.rotation_degrees = f[1]
		root.add_child(number)
		faces.append(number)
	root.set_meta("faces", faces)
	return root


## An empty plot: bare earth, tufts of grass round its edge and a cartoon
## SALE sign on two posts.
static func _for_sale() -> Node3D:
	var root := Node3D.new()
	var inner := TILE - 2 * FRAME
	var earth := _box(Vector3(inner, 0.02, inner), EARTH)
	earth.position.y = 0.01
	root.add_child(earth)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # every plot looks the same
	for i in 5:  # clods
		var clod := _box(Vector3(0.07, 0.03, 0.05), EARTH.darkened(0.25))
		clod.position = Vector3(rng.randf_range(-0.3, 0.3), 0.025, rng.randf_range(-0.05, 0.3))
		clod.rotation.y = rng.randf() * PI
		root.add_child(clod)
	for i in 14:  # grass round the edge
		var side := i % 4
		var along := rng.randf_range(-0.36, 0.36)
		var edge := inner / 2 - 0.04
		var at := Vector3(along, 0, edge * (1 if side == 0 else -1)) if side < 2 \
				else Vector3(edge * (1 if side == 2 else -1), 0, along)
		for blade in 3:
			var tuft := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.03
			cone.height = rng.randf_range(0.07, 0.12)
			cone.radial_segments = 4
			tuft.mesh = cone
			tuft.material_override = _material(GRASS.lightened(rng.randf() * 0.2))
			tuft.position = at + Vector3((blade - 1) * 0.03, 0.02 + cone.height / 2, rng.randf_range(-0.02, 0.02))
			tuft.rotation_degrees.z = (blade - 1) * 18
			root.add_child(tuft)
	var sign := Node3D.new()
	sign.position = Vector3(0, 0, -0.1)
	sign.rotation_degrees = Vector3(-15, 0, 4)  # leaning back, a little crooked
	root.add_child(sign)
	for x in [-0.2, 0.2]:
		var post := _box(Vector3(0.035, 0.5, 0.035), Color("#7a5a3a"))
		post.position = Vector3(x, 0.25, -0.02)
		sign.add_child(post)
	var backing := _box(Vector3(0.62, 0.3, 0.03), Color.WHITE)
	backing.position.y = 0.42
	sign.add_child(backing)
	var board := _box(Vector3(0.56, 0.24, 0.03), SALE_RED)
	board.position = Vector3(0, 0.42, 0.006)
	sign.add_child(board)
	var word := _label("SALE", 80, Color("#fff3b0"), false)
	word.rotation_degrees.x = 0  # stands on the board, not flat on the tile
	word.outline_size = 14
	word.outline_modulate = Color("#7a1410")
	word.pixel_size = 0.0045
	word.position = Vector3(0, 0.42, 0.025)
	sign.add_child(word)
	return root


## The Bank on the Depot: a columned building on a plinth with steps, a gold
## trimmed pediment, a dome, and a big gold money bag sitting on the dome.
## Its front faces +z; it stands narrow and deep so the four player spots on
## the tile stay clear.
static func _bank_building() -> Node3D:
	var root := Node3D.new()
	var add := func(node: Node3D, at: Vector3) -> Node3D:
		node.position = at
		root.add_child(node)
		return node
	add.call(_box(Vector3(0.5, 0.05, 0.36), BANK_STONE.darkened(0.1)), Vector3(0, 0.025, 0.02))  # plinth
	add.call(_box(Vector3(0.3, 0.025, 0.06), BANK_STONE), Vector3(0, 0.0125, 0.21))  # steps
	add.call(_box(Vector3(0.44, 0.46, 0.28), BANK_STONE), Vector3(0, 0.28, -0.01))
	add.call(_box(Vector3(0.1, 0.2, 0.01), Color("#6b3a1e")), Vector3(0, 0.15, 0.135))  # door
	add.call(_box(Vector3(0.12, 0.02, 0.012), BANK_GOLD), Vector3(0, 0.26, 0.136))
	for x in [-0.165, -0.085, 0.085, 0.165]:
		add.call(_cyl(0.022, 0.026, 0.42, Color.WHITE), Vector3(x, 0.26, 0.16))
	for side in [-1, 1]:  # windows behind the columns
		add.call(_box(Vector3(0.05, 0.08, 0.01), Color("#ffe98a")), Vector3(side * 0.125, 0.36, 0.135))
	add.call(_box(Vector3(0.5, 0.05, 0.34), BANK_STONE.lightened(0.2)), Vector3(0, 0.535, 0.01))
	add.call(_box(Vector3(0.5, 0.015, 0.345), BANK_GOLD), Vector3(0, 0.5, 0.01))
	var pediment := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.5, 0.12, 0.34)
	pediment.mesh = prism
	pediment.material_override = _material(BANK_STONE.lightened(0.15))
	add.call(pediment, Vector3(0, 0.62, 0.01))
	add.call(_cyl(0.13, 0.14, 0.08, BANK_STONE), Vector3(0, 0.62, -0.06))  # the dome's drum
	add.call(_cyl(0.145, 0.145, 0.02, BANK_GOLD), Vector3(0, 0.665, -0.06))
	var dome := MeshInstance3D.new()
	var half := SphereMesh.new()
	half.radius = 0.13
	half.height = 0.26
	half.is_hemisphere = true
	dome.mesh = half
	dome.material_override = _material(BANK_STONE.lightened(0.1))
	add.call(dome, Vector3(0, 0.675, -0.06))
	# The money bag: a round sack, tied at the neck, the top flaring out, a G.
	var bag := MeshInstance3D.new()
	var sack := SphereMesh.new()
	sack.radius = 0.12
	sack.height = 0.22
	bag.mesh = sack
	bag.material_override = _material(BANK_GOLD, 0.25)
	add.call(bag, Vector3(0, 0.9, -0.06))
	add.call(_cyl(0.035, 0.05, 0.04, BANK_GOLD.darkened(0.25)), Vector3(0, 1.02, -0.06))
	add.call(_cyl(0.07, 0.03, 0.06, BANK_GOLD), Vector3(0, 1.07, -0.06))
	var g := _label("G", 70, BANK_GOLD.darkened(0.45))
	g.rotation_degrees.x = 0
	g.outline_size = 0
	g.pixel_size = 0.0025
	add.call(g, Vector3(0, 0.9, 0.062))
	return root


## A plot's building, standing on the tile, with the owner's `colour` in it:
##   bridge   a wooden bridge on stone piers over water, a toll booth and a
##            striped barrier on it
##   airport  an airliner on the runway, the terminal and control tower in
##            front of it
##   tax      a columned office with steps and a % on its pediment
##   repair   a garage with a roll-up door, a spanner on the roof and tyres
##   centre   a giant shopping mall: a tall white-clad block with louvres on
##            top and a red MALL sign, a curved glass entrance under a white
##            canopy, a long glass wing with a tall SHOPS sign and a terrace,
##            and a lamp post with banners; taller for each `level`
static func _plot_model(kind: String, colour: Color, level: int) -> Node3D:
	var root := Node3D.new()
	var add := func(node: Node3D, at: Vector3) -> Node3D:
		node.position = at
		root.add_child(node)
		return node
	match kind:
		"bridge":
			add.call(_box(Vector3(0.5, 0.012, 0.34), Color("#3f8fd8")), Vector3(0, 0.006, 0))  # water
			for x in [-0.28, 0.28]:
				add.call(_box(Vector3(0.12, 0.22, 0.3), STONE), Vector3(x, 0.11, 0))
			add.call(_box(Vector3(0.74, 0.05, 0.3), WOOD), Vector3(0, 0.245, 0))
			for z in [-0.14, 0.14]:  # railings
				add.call(_box(Vector3(0.74, 0.025, 0.02), colour), Vector3(0, 0.33, z))
				for x in [-0.33, -0.11, 0.11, 0.33]:
					add.call(_box(Vector3(0.02, 0.08, 0.02), colour.darkened(0.3)), Vector3(x, 0.29, z))
			add.call(_box(Vector3(0.12, 0.16, 0.12), colour.lerp(Color.WHITE, 0.3)), Vector3(0.24, 0.35, -0.06))
			add.call(_box(Vector3(0.15, 0.03, 0.15), colour.darkened(0.3)), Vector3(0.24, 0.445, -0.06))
			for i in 5:  # the barrier arm, red and white
				add.call(_box(Vector3(0.05, 0.025, 0.025), Color("#e8463a") if i % 2 == 0 else Color.WHITE),
						Vector3(0.12 - i * 0.05, 0.36, 0.06))
		"airport":  # an airliner on the runway, the terminal and tower in front
			add.call(_box(Vector3(0.92, 0.012, 0.28), Color("#45454d")), Vector3(0, 0.006, -0.18))
			for x in [-0.32, -0.16, 0.0, 0.16, 0.32]:  # the centre line
				add.call(_box(Vector3(0.08, 0.004, 0.018), Color.WHITE), Vector3(x, 0.014, -0.18))
			for x in [-0.43, 0.43]:  # threshold stripes at each end
				for z in [-0.28, -0.24, -0.12, -0.08]:
					add.call(_box(Vector3(0.035, 0.004, 0.022), Color.WHITE), Vector3(x, 0.014, z))
			var plane := _airliner(colour)
			plane.rotation.y = -0.12  # rolling down the runway, nose to the right
			add.call(plane, Vector3(0.08, 0.0, -0.18))
			add.call(_cyl(0.04, 0.05, 0.36, Color("#f2f2f2")), Vector3(-0.38, 0.18, 0.16))  # tower
			var cab := _cyl(0.085, 0.065, 0.08, Color.WHITE)
			cab.material_override = _material(Color("#7fd0ff"), 0.4)
			add.call(cab, Vector3(-0.38, 0.4, 0.16))
			add.call(_cyl(0.0, 0.095, 0.05, colour), Vector3(-0.38, 0.465, 0.16))
			add.call(_box(Vector3(0.42, 0.12, 0.13), Color("#f2f2f2")), Vector3(0.16, 0.06, 0.13))  # terminal
			add.call(_box(Vector3(0.42, 0.025, 0.132), colour), Vector3(0.16, 0.1, 0.13))
			var glass := _box(Vector3(0.34, 0.045, 0.005), Color.WHITE)
			glass.material_override = _material(Color("#7fd0ff"), 0.3)
			add.call(glass, Vector3(0.16, 0.05, 0.197))
		"tax":
			add.call(_box(Vector3(0.64, 0.04, 0.44), STONE.lightened(0.2)), Vector3(0, 0.02, 0.02))  # steps
			add.call(_box(Vector3(0.58, 0.04, 0.38), STONE.lightened(0.3)), Vector3(0, 0.06, 0.01))
			add.call(_box(Vector3(0.5, 0.3, 0.26), Color("#efe6d2")), Vector3(0, 0.23, -0.04))
			add.call(_box(Vector3(0.1, 0.16, 0.01), Color("#6b4a2e")), Vector3(0, 0.16, 0.095))  # door
			for x in [-0.2, -0.07, 0.07, 0.2]:
				add.call(_cyl(0.026, 0.03, 0.3, Color.WHITE), Vector3(x, 0.23, 0.14))
			add.call(_box(Vector3(0.58, 0.04, 0.36), Color.WHITE), Vector3(0, 0.4, 0.01))
			var pediment := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.6, 0.13, 0.36)
			pediment.mesh = prism
			pediment.material_override = _material(colour.lerp(Color.WHITE, 0.2))
			add.call(pediment, Vector3(0, 0.485, 0.01))
			var mark := _label("%", 60, Color.WHITE)
			mark.rotation_degrees.x = 0
			mark.outline_size = 8
			mark.outline_modulate = colour.darkened(0.4)
			mark.pixel_size = 0.0018
			add.call(mark, Vector3(0, 0.47, 0.195))
		"repair":
			add.call(_box(Vector3(0.56, 0.3, 0.38), colour.lerp(Color.WHITE, 0.45)), Vector3(0, 0.15, -0.02))
			add.call(_box(Vector3(0.62, 0.035, 0.44), colour.darkened(0.3)), Vector3(0, 0.318, -0.02))
			add.call(_box(Vector3(0.32, 0.22, 0.01), Color("#a8acb4")), Vector3(-0.06, 0.11, 0.175))  # door
			for i in 4:
				add.call(_box(Vector3(0.32, 0.008, 0.012), Color("#7c808a")), Vector3(-0.06, 0.03 + i * 0.055, 0.18))
			var spanner := Node3D.new()  # standing on the roof
			add.call(spanner, Vector3(0.05, 0.45, -0.02))
			spanner.rotation_degrees.z = 40
			var handle := _box(Vector3(0.04, 0.22, 0.03), Color("#c9ced6"))
			spanner.add_child(handle)
			for x in [-0.035, 0.035]:  # the open jaw
				var jaw := _box(Vector3(0.025, 0.06, 0.03), Color("#c9ced6"))
				jaw.position = Vector3(x, 0.13, 0)
				spanner.add_child(jaw)
			for y in [0.025, 0.07]:  # a stack of tyres
				var tyre := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = 0.025
				ring.outer_radius = 0.06
				tyre.mesh = ring
				tyre.material_override = _material(Color("#26262a"))
				add.call(tyre, Vector3(0.24, y, 0.25))
		_:  # centre: a giant shopping mall
			var h := 0.5 + 0.08 * level  # the main block, taller with each expansion
			var white := Color("#efeee9")
			var main := Vector3(-0.16, 0, -0.12)
			add.call(_box(Vector3(0.52, h, 0.46), white), main + Vector3(0, h / 2, 0))
			for i in range(1, 6):  # panel joints across the cladding
				add.call(_box(Vector3(0.524, 0.006, 0.464), Color("#d2d1ca")), main + Vector3(0, h * i / 6.0, 0))
			add.call(_box(Vector3(0.5, 0.1, 0.44), Color("#dcdcd6")), main + Vector3(0, h + 0.05, 0))  # louvres
			for i in 11:
				add.call(_box(Vector3(0.008, 0.09, 0.006), Color("#b8b8b2")),
						main + Vector3(-0.23 + i * 0.046, h + 0.05, 0.222))
			var sign := _label("MALL", 90, Color("#d8202c"))
			sign.rotation_degrees.x = 0
			sign.autowrap_mode = TextServer.AUTOWRAP_OFF
			sign.width = 0
			sign.outline_size = 10
			sign.outline_modulate = Color.WHITE
			sign.pixel_size = 0.0024
			add.call(sign, main + Vector3(0.06, h * 0.84, 0.234))
			# The curved glass entrance with its white canopy.
			var hall := _cyl(0.16, 0.17, 0.26, Color.WHITE)
			hall.material_override = _glass(Color("#4f8f9a"))
			add.call(hall, Vector3(-0.28, 0.13, 0.13))
			for y in [0.09, 0.18]:  # glazing bars
				var bar := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = 0.163
				ring.outer_radius = 0.173
				bar.mesh = ring
				bar.material_override = _material(Color("#d8e8ea"))
				add.call(bar, Vector3(-0.28, y, 0.13))
			var canopy := _cyl(0.17, 0.17, 0.018, Color("#e9eff0"))
			canopy.rotation.x = 0.12
			add.call(canopy, Vector3(-0.28, 0.27, 0.14))
			add.call(_box(Vector3(0.1, 0.12, 0.01), Color("#26323a")), Vector3(-0.28, 0.06, 0.3))  # doors
			# The long glass wing, a tall shop sign on its corner, a terrace in front.
			var wing_h := 0.3 + 0.04 * level
			var wing := _box(Vector3(0.36, wing_h, 0.5), Color.WHITE)
			wing.material_override = _glass(Color("#7fb6bc"))
			add.call(wing, Vector3(0.25, wing_h / 2, -0.08))
			for y in [wing_h * 0.4, wing_h * 0.75]:
				add.call(_box(Vector3(0.362, 0.01, 0.502), Color("#e8f0f0")), Vector3(0.25, y, -0.08))
			add.call(_box(Vector3(0.37, 0.05, 0.51), Color("#9aa4a8")), Vector3(0.25, wing_h + 0.025, -0.08))
			add.call(_box(Vector3(0.06, 0.28, 0.02), Color.WHITE), Vector3(0.1, wing_h * 0.5 + 0.04, 0.18))
			var shops := _label("S\nH\nO\nP\nS", 40, Color("#3a3446"))
			shops.rotation_degrees.x = 0
			shops.outline_size = 0
			shops.pixel_size = 0.0016
			shops.width = 0
			shops.autowrap_mode = TextServer.AUTOWRAP_OFF
			add.call(shops, Vector3(0.1, wing_h * 0.5 + 0.04, 0.191))
			add.call(_box(Vector3(0.34, 0.05, 0.08), Color("#3a3a42")), Vector3(0.25, 0.025, 0.21))
			add.call(_box(Vector3(0.16, 0.022, 0.005), colour), Vector3(0.25, 0.03, 0.251))
			var awning := _box(Vector3(0.36, 0.012, 0.13), Color.WHITE)
			awning.rotation.x = 0.28
			add.call(awning, Vector3(0.25, 0.13, 0.22))
			for x in [0.09, 0.41]:
				add.call(_box(Vector3(0.01, 0.12, 0.01), Color.WHITE), Vector3(x, 0.06, 0.27))
			# A lamp post with banners in the owner's colour.
			add.call(_cyl(0.008, 0.01, 0.46, Color("#5a5e66")), Vector3(-0.02, 0.23, 0.27))
			for x in [-0.045, 0.005]:
				add.call(_box(Vector3(0.04, 0.09, 0.004), colour), Vector3(x, 0.32, 0.27))
	return root


## An airliner `colour` on the tail, nose to +x, wheels on y = 0: fuselage
## with a window line and cockpit, swept wings with an engine under each, a
## tailplane and a fin.
static func _airliner(colour: Color) -> Node3D:
	var plane := Node3D.new()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.055
	capsule.height = 0.62
	body.mesh = capsule
	body.material_override = _material(Color.WHITE)
	body.rotation_degrees.z = 90
	body.position.y = 0.11
	plane.add_child(body)
	var windows := _box(Vector3(0.42, 0.014, 0.112), Color("#2a3a4a"))
	windows.position = Vector3(0.0, 0.125, 0)
	plane.add_child(windows)
	var stripe := _box(Vector3(0.48, 0.012, 0.111), colour)
	stripe.position = Vector3(-0.01, 0.096, 0)
	plane.add_child(stripe)
	var cockpit := _box(Vector3(0.03, 0.02, 0.08), Color("#2a3a4a"))
	cockpit.position = Vector3(0.27, 0.13, 0)
	plane.add_child(cockpit)
	for side in [-1, 1]:
		var wing := _box(Vector3(0.11, 0.012, 0.27), Color("#e4e4ea"))
		wing.position = Vector3(-0.02, 0.09, side * 0.15)
		wing.rotation.y = side * 0.4  # swept back
		plane.add_child(wing)
		var engine := _cyl(0.026, 0.026, 0.1, Color("#9aa0a8"))
		engine.rotation.z = PI / 2
		engine.position = Vector3(0.03, 0.065, side * 0.13)
		plane.add_child(engine)
		var stab := _box(Vector3(0.06, 0.01, 0.11), Color("#e4e4ea"))
		stab.position = Vector3(-0.28, 0.13, side * 0.06)
		stab.rotation.y = side * 0.4
		plane.add_child(stab)
	var fin := _box(Vector3(0.1, 0.13, 0.012), colour)
	fin.position = Vector3(-0.27, 0.2, 0)
	fin.rotation.z = -0.35
	plane.add_child(fin)
	for at in [Vector3(0.2, 0.03, 0), Vector3(-0.04, 0.03, -0.05), Vector3(-0.04, 0.03, 0.05)]:
		var wheel := _cyl(0.012, 0.012, 0.06, Color("#26262a"))
		wheel.position = at
		plane.add_child(wheel)
	return plane


## Tinted glass: shiny and slightly see-through.
static func _glass(colour: Color) -> StandardMaterial3D:
	var m := _material(Color(colour, 0.85))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.4
	m.roughness = 0.12
	return m


static func _cyl(top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = _material(color)
	return mi


## A suit symbol modelled from primitives, standing upright (it sways in _process).
static func _suit(mark: String, color: Color) -> Node3D:
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


static func _stem(m: Material) -> MeshInstance3D:
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
static func _shape_part(mesh: PrimitiveMesh, m: Material, at: Vector3, size: float) -> MeshInstance3D:
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


## Filler scenery: the board sits on a sunny, very basic golf course. Rough
## grass all round, light fairways running off towards greens with a flag in
## the hole, sand bunkers, a pond, and trees round the edge. The same course
## every time for a given board (a fixed seed).
func _build_golf_course(lo: Vector3, hi: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1964
	var centre := (lo + hi) / 2
	var half := Vector2(hi.x - lo.x, hi.z - lo.z) / 2 + Vector2(1.6, 1.6)  # board plus a margin
	var reach := maxf(half.x, half.y)
	var rough := _box(Vector3(reach * 8, 0.1, reach * 8), Color("#4f9a3c"))
	rough.position = centre - Vector3(0, 0.17, 0)
	_root.add_child(rough)
	# A spot on the course: outside the board, `out` of the board's size away.
	var spot := func(angle: float, out: float) -> Vector3:
		var dir := Vector2.from_angle(angle)
		var edge := minf(half.x / maxf(absf(dir.x), 0.01), half.y / maxf(absf(dir.y), 0.01))
		return centre + Vector3(dir.x, 0, dir.y) * (edge + out)
	# Three holes: a fairway strip running away from the board to a round green.
	for h in 3:
		var angle := TAU * h / 3.0 + rng.randf_range(-0.3, 0.3)
		var tee: Vector3 = spot.call(angle, 1.5)
		var green: Vector3 = spot.call(angle, rng.randf_range(9.0, 13.0))
		var fairway := _box(Vector3(2.6, 0.04, tee.distance_to(green)), Color("#6cc24f"))
		fairway.position = (tee + green) / 2 - Vector3(0, 0.12, 0)
		fairway.rotation.y = atan2(green.x - tee.x, green.z - tee.z)
		_root.add_child(fairway)
		_add_disc(green, 1.7, 0.06, Color("#7fd85a"), -0.11)
		_add_disc(green + Vector3(0.4, 0, 0.3), 0.08, 0.08, Color("#1a1a1a"), -0.09)  # the hole
		var pin := _box(Vector3(0.05, 1.6, 0.05), Color.WHITE)
		pin.position = green + Vector3(0.4, 0.7, 0.3)
		_root.add_child(pin)
		var flag := _box(Vector3(0.5, 0.3, 0.03), Color("#ff4a4a"))
		flag.position = green + Vector3(0.65, 1.35, 0.3)
		_root.add_child(flag)
		# A bunker beside each green, and a tee box at the near end.
		var side := Vector3(cos(angle + PI / 2), 0, sin(angle + PI / 2))
		_add_disc(green + side * rng.randf_range(2.2, 2.8), 0.9, 0.05, Color("#efd9a0"), -0.11)
		var tee_box := _box(Vector3(1.2, 0.06, 0.8), Color("#78c95a"))
		tee_box.position = tee - Vector3(0, 0.1, 0)
		tee_box.rotation.y = fairway.rotation.y
		_root.add_child(tee_box)
	# A pond, a couple more bunkers, and trees scattered round the edge.
	_add_disc(spot.call(TAU / 6.0 + 0.4, 5.0), 2.6, 0.05, Color("#3f8fd8"), -0.11)
	for i in 2:
		_add_disc(spot.call(rng.randf() * TAU, rng.randf_range(3.0, 6.0)), rng.randf_range(0.7, 1.1),
				0.05, Color("#efd9a0"), -0.11)
	for i in 34:
		var at: Vector3 = spot.call(rng.randf() * TAU, rng.randf_range(2.5, 16.0))
		var size := rng.randf_range(0.7, 1.3)
		var trunk := _box(Vector3(0.18, 0.9, 0.18) * size, Color("#7a5232"))
		trunk.position = at + Vector3(0, 0.3 * size, 0)
		_root.add_child(trunk)
		var leaves := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.55 * size
		ball.height = 1.1 * size
		leaves.mesh = ball
		leaves.material_override = _material(Color("#2f7a34").lightened(rng.randf() * 0.25))
		leaves.position = at + Vector3(0, 1.05 * size, 0)
		_root.add_child(leaves)


## A flat round patch (green, bunker, pond) lying on the course.
func _add_disc(at: Vector3, radius: float, height: float, color: Color, y: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	mi.material_override = _material(color)
	mi.position = Vector3(at.x, y, at.z)
	_root.add_child(mi)


static func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color)
	return mi


## Flat labels lie on the tile reading towards the camera; billboards face it.
static func _label(text: String, font_size: int, color: Color, billboard := false) -> Label3D:
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


## A left click on the board: finds the space under the pointer (where the
## ray meets the tiles' tops) and reports it as space_clicked.
func _unhandled_input(event: InputEvent) -> void:
	if game == null or not (event is InputEventMouseButton) or not event.pressed \
			or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var from := _camera.project_ray_origin(event.position)
	var dir := _camera.project_ray_normal(event.position)
	if absf(dir.y) < 0.0001:
		return
	var hit := from + dir * ((TILE_H - from.y) / dir.y)
	var best := -1
	var best_d := TILE * 0.6
	for s in game.board.spaces:
		var at := _pos(s.id)
		var d := Vector2(hit.x - at.x, hit.z - at.z).length()
		if d < best_d:
			best = s.id
			best_d = d
	if best >= 0:
		space_clicked.emit(best)
