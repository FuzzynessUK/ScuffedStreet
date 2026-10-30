class_name CritterRace
extends CenterContainer
## Critter Race on screen: a little 3D meadow with a four-lane track. The
## player backs one of the animals, then the race plays out the plan from
## Minigames.race_plan, each animal moving in its own style. Placeholder
## animals are built from simple shapes and can be swapped for models later.

signal racer_picked(i: int)

const TRACK := 30.0        # metres from start to finish
const LANE := 1.6          # lane width
const VIEW := Vector2(660, 330)
const CPU_PICK := 0.9
const FINISH_HOLD := 1.0   # seconds to watch them cross the line
const PODIUM_LEAD := 1.0   # seconds on the podium before the prize shows
const PODIUM := Vector3(TRACK + 22, 0, 0)  # out of sight during the race
## Where each place stands, from the podium's middle: 1st on the tall middle
## step, 2nd and 3rd either side (the y is also each step's height), 4th on
## the grass.
const PODIUM_SPOTS := [Vector3(0, 1.2, 0), Vector3(0, 0.85, 1.45), Vector3(0, 0.55, -1.45),
		Vector3(0.5, 0, -2.9)]

var _title: Label
var _hint: Label
var _picks: HBoxContainer
var _camera: Camera3D
var _racers: Array[Node3D] = []
var _tags: Array[Label3D] = []
var _plan: Array = []
var _t := -1.0             # seconds into the race, -1 when not racing
var _phase: Array[float] = []
var _lane_z: Array[float] = []  # each racer's lane
var _podium: Node3D
var _confetti: CPUParticles3D
var _podium_order: Array = []
var _podium_t := -1.0      # seconds on the podium, -1 when not there
var _names: Array[String] = []  # the players' names, for the tags
var result: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#fff7e0")
	bg.border_color = Color("#ff9ad5")
	bg.set_border_width_all(4)
	bg.set_corner_radius_all(14)
	bg.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color("#e0569b"))
	col.add_child(_title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color("#5a4a3a"))
	col.add_child(_hint)

	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = VIEW
	col.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	_build_meadow(vp)

	_picks = HBoxContainer.new()
	_picks.alignment = BoxContainer.ALIGNMENT_CENTER
	_picks.add_theme_constant_override("separation", 8)
	col.add_child(_picks)
	for i in Minigames.RACERS.size():
		var r: Dictionary = Minigames.RACERS[i]
		var b := Button.new()
		b.text = "%s\n%s" % [r.name, r.blurb]
		b.custom_minimum_size = Vector2(150, 56)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.html(r.color)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(6)
		var hover := sb.duplicate() as StyleBoxFlat
		hover.set_border_width_all(3)
		hover.border_color = Color("#e0569b")
		for state in ["normal", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(state, sb)
		b.add_theme_stylebox_override("hover", hover)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			b.add_theme_color_override(state, Color("#3a2a20"))
		b.pressed.connect(func(): racer_picked.emit(i))
		_picks.add_child(b)

	result = Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.custom_minimum_size = Vector2(0, 30)
	result.add_theme_font_size_override("font_size", 22)
	col.add_child(result)


# --- the meadow -----------------------------------------------------------

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	return m


func _add(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h if h > 0 else r * 2
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	return c


func _build_meadow(vp: SubViewport) -> void:
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9ad8ff")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#fff4e0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	root.add_child(sun)

	var lanes := Minigames.RACERS.size()
	var width := lanes * LANE
	_add(root, _box(Vector3(TRACK + 60, 0.1, 40)), Color("#5fb043"), Vector3(TRACK / 2, -0.06, 0))
	_add(root, _box(Vector3(TRACK + 8, 0.06, width)), Color("#d9a865"), Vector3(TRACK / 2, 0, 0))
	for k in lanes + 1:
		var z := -width / 2 + k * LANE
		_add(root, _box(Vector3(TRACK + 8, 0.08, 0.06)), Color.WHITE, Vector3(TRACK / 2, 0.01, z))
	_add(root, _box(Vector3(0.15, 0.09, width)), Color.WHITE, Vector3(0, 0.01, 0))
	for row in 2:  # chequered finish line
		for k in int(width / 0.4):
			var c := Color.BLACK if (k + row) % 2 == 0 else Color.WHITE
			_add(root, _box(Vector3(0.4, 0.09, 0.4)), c,
					Vector3(TRACK + row * 0.4, 0.015, -width / 2 + 0.2 + k * 0.4))
	# A finish arch with bunting.
	for side in [-1, 1]:
		_add(root, _box(Vector3(0.2, 3.2, 0.2)), Color("#ff9ad5"), Vector3(TRACK, 1.6, side * (width / 2 + 0.4)))
	_add(root, _box(Vector3(0.3, 0.5, width + 1.2)), Color("#ff9ad5"), Vector3(TRACK, 3.2, 0))
	var flags := [Color("#ff6b6b"), Color("#ffd23f"), Color("#4fc3f7"), Color("#7ccf5a")]
	for k in 9:
		_add(root, _cone(0.22, 0.45), flags[k % 4], Vector3(TRACK, 2.75, -width / 2 + k * width / 8), Vector3(180, 0, 0))
	# Trees and flowers on both sides.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same meadow every time
	for k in 16:
		var x := -6.0 + k * (TRACK + 14) / 15.0
		for side in [-1, 1]:
			# Trees on the far side; on the near side only behind the camera.
			var z: float = rng.randf_range(12.0, 16.0)
			if side < 0:
				z = -rng.randf_range(width / 2 + 3, width / 2 + 9)
			_add(root, _box(Vector3(0.3, 1.4, 0.3)), Color("#8a5a3a"), Vector3(x, 0.7, z))
			_add(root, _sphere(rng.randf_range(0.8, 1.2)), Color("#3f9a4a").lightened(rng.randf() * 0.2),
					Vector3(x, 1.9, z))
			_add(root, _sphere(0.15), [Color("#ff6b9a"), Color("#ffe14a"), Color.WHITE][k % 3],
					Vector3(x + 1.5, 0.12, side * (width / 2 + 1.2)))

	for i in lanes:
		var racer := _animal(Minigames.RACERS[i].style, Color.html(Minigames.RACERS[i].color))
		racer.position = Vector3(0, 0, -width / 2 + LANE / 2 + i * LANE)
		root.add_child(racer)
		_racers.append(racer)
		var tag := Label3D.new()
		tag.text = Minigames.RACERS[i].name
		tag.font_size = 48
		tag.pixel_size = 0.009
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 1.6, 0)
		racer.add_child(tag)
		_tags.append(tag)
		_lane_z.append(racer.position.z)
	_build_podium(root)
	_camera = Camera3D.new()
	_camera.fov = 50
	root.add_child(_camera)
	_place_camera(0.0)


## The winners' podium past the finish, hidden until the race is over: 1st in
## the middle, 2nd on its left and 3rd on its right as the camera sees them,
## with a spot on the grass for 4th, and confetti above.
func _build_podium(root: Node3D) -> void:
	_podium = Node3D.new()
	_podium.position = PODIUM
	_podium.visible = false
	root.add_child(_podium)
	var steps := [[0, Color("#ffd84a")], [1, Color("#d7dde8")], [2, Color("#e8a26a")]]
	for s in steps:
		var place: int = s[0]
		var top: Vector3 = PODIUM_SPOTS[place]
		_add(_podium, _box(Vector3(1.4, top.y, 1.4)), s[1], Vector3(0, top.y / 2, top.z))
		var num := Label3D.new()
		num.text = str(place + 1)
		num.font_size = 96
		num.pixel_size = 0.008
		num.outline_size = 16
		num.position = Vector3(0.72, top.y / 2, top.z)
		num.rotation_degrees.y = 90  # facing the camera, which looks back down the track
		_podium.add_child(num)
	_confetti = CPUParticles3D.new()
	_confetti.position = Vector3(0, 5.5, 0)
	_confetti.emitting = false
	_confetti.amount = 160
	_confetti.lifetime = 3.5
	_confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_confetti.emission_box_extents = Vector3(1.5, 0.2, 3.5)
	_confetti.direction = Vector3.DOWN
	_confetti.spread = 30.0
	_confetti.initial_velocity_min = 0.5
	_confetti.initial_velocity_max = 1.5
	_confetti.gravity = Vector3(0, -2.5, 0)
	_confetti.angular_velocity_min = -360.0
	_confetti.angular_velocity_max = 360.0
	var bit := _box(Vector3(0.1, 0.02, 0.06))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bit.material = mat
	_confetti.mesh = bit
	var colours := Gradient.new()
	colours.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	colours.colors = PackedColorArray([Color("#ff6b6b"), Color("#ffd23f"), Color("#4fc3f7"),
			Color("#7ccf5a"), Color("#ff9ad5")])
	_confetti.color_initial_ramp = colours
	_podium.add_child(_confetti)


## Puts the animals on the podium in finishing order and starts the party.
func _show_podium(order: Array) -> void:
	_t = -1.0
	_podium.visible = true
	_podium_order = order
	var places := ["1st", "2nd", "3rd", "4th"]
	for k in order.size():
		var racer := _racers[order[k]]
		racer.position = PODIUM + PODIUM_SPOTS[k]
		racer.rotation = Vector3.ZERO
		var body: Node3D = racer.get_child(0)
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		_tags[order[k]].text = "%s %s" % [places[k], _tags[order[k]].text]
		_tags[order[k]].pixel_size = 0.0065  # four tags close together
	var eye := PODIUM + Vector3(5.6, 2.3, 0)
	_camera.transform = Transform3D(Basis(), eye).looking_at(PODIUM + Vector3(0, 1.0, 0), Vector3.UP)
	_confetti.restart()
	_confetti.emitting = true
	_podium_t = 0.0


## 1st jumps and spins, 2nd and 3rd hop and wiggle, 4th droops.
func _animate_podium(delta: float) -> void:
	_podium_t += delta
	var t := _podium_t
	for k in _podium_order.size():
		var racer := _racers[_podium_order[k]]
		var body: Node3D = racer.get_child(0)
		match k:
			0:
				body.position.y = absf(sin(t * 5.0)) * 0.7
				racer.rotation.y = t * 4.0
			1, 2:
				body.position.y = absf(sin(t * 6.5 + k)) * 0.3
				racer.rotation.y = sin(t * 4.0 + k) * 0.5
			_:
				body.rotation_degrees.z = -22.0  # head down
				racer.rotation.y = sin(t * 1.3) * 0.15


## A placeholder animal facing +x, built from simple shapes. The body is the
## first child so the styles can bob and tilt it.
func _animal(style: String, c: Color) -> Node3D:
	var a := Node3D.new()
	var body := Node3D.new()
	a.add_child(body)
	var dark := Color("#3a2a20")
	match style:
		"hop":  # bunny
			_add(body, _sphere(0.42, 0.7), c, Vector3(0, 0.4, 0))
			_add(body, _sphere(0.28), c, Vector3(0.38, 0.75, 0))
			for z in [-0.1, 0.1]:
				_add(body, _sphere(0.08, 0.55), c, Vector3(0.32, 1.15, z), Vector3(0, 0, -12))
				_add(body, _sphere(0.05), dark, Vector3(0.6, 0.8, z))
			_add(body, _sphere(0.06), Color("#ff8fb0"), Vector3(0.65, 0.72, 0))
			_add(body, _sphere(0.14), Color.WHITE, Vector3(-0.42, 0.45, 0))
		"steady":  # turtle
			_add(body, _sphere(0.55, 0.55), c, Vector3(0, 0.35, 0))
			_add(body, _sphere(0.2), Color("#c9b27a"), Vector3(0.6, 0.35, 0))
			for z in [-0.08, 0.08]:
				_add(body, _sphere(0.04), dark, Vector3(0.76, 0.42, z))
			for x in [-0.3, 0.3]:
				for z in [-0.35, 0.35]:
					_add(body, _sphere(0.12), Color("#c9b27a"), Vector3(x, 0.12, z))
		"dash":  # fox
			_add(body, _sphere(0.32, 0.9), c, Vector3(0, 0.45, 0), Vector3(0, 0, 90))
			_add(body, _sphere(0.27), c, Vector3(0.5, 0.65, 0))
			_add(body, _cone(0.1, 0.35), dark, Vector3(0.72, 0.62, 0), Vector3(0, 0, -90))
			for z in [-0.13, 0.13]:
				_add(body, _cone(0.1, 0.3), c, Vector3(0.45, 0.95, z))
				_add(body, _sphere(0.04), dark, Vector3(0.7, 0.72, z))
			_add(body, _sphere(0.16, 0.7), c, Vector3(-0.55, 0.6, 0), Vector3(0, 0, 50))
			_add(body, _sphere(0.1), Color.WHITE, Vector3(-0.78, 0.82, 0))
		_:  # duck
			_add(body, _sphere(0.42), c, Vector3(0, 0.42, 0))
			_add(body, _sphere(0.26), c, Vector3(0.3, 0.9, 0))
			_add(body, _box(Vector3(0.3, 0.08, 0.2)), Color("#ff9a2a"), Vector3(0.58, 0.86, 0))
			for z in [-0.12, 0.12]:
				_add(body, _sphere(0.04), dark, Vector3(0.48, 0.98, z))
				_add(body, _sphere(0.18, 0.1), Color("#ff9a2a"), Vector3(0.05, 0.03, z * 1.5))
			for z in [-0.42, 0.42]:
				_add(body, _sphere(0.2, 0.5), c.darkened(0.1), Vector3(-0.05, 0.5, z), Vector3(90, 0, 0))
	return a


func _place_camera(x: float) -> void:
	var eye := Vector3(x - 3.2, 3.0, 6.2)
	_camera.transform = Transform3D(Basis(), eye).looking_at(Vector3(x + 1.8, 0.3, 0), Vector3.UP)


# --- the race -------------------------------------------------------------

func _process(delta: float) -> void:
	if _podium_t >= 0.0:
		_animate_podium(delta)
		return
	if _t < 0.0 or _plan.is_empty():
		return
	_t += delta
	var lead := 0.0
	for i in _racers.size():
		var e: Dictionary = _plan[i]
		var p := Minigames.race_progress(e, _t)
		var x := p * TRACK
		if _t > e.time:
			x = TRACK + minf(2.0, (_t - e.time) * 3.0)  # coasting past the line
		var racer := _racers[i]
		# Speed now, for the styles: progress over the next instant.
		var v := (Minigames.race_progress(e, _t + 0.05) - p) / 0.05 * TRACK
		racer.position.x = x
		var body: Node3D = racer.get_child(0)
		var ph := _phase[i]
		match Minigames.RACERS[i].style:
			"hop":
				body.position.y = absf(sin(_t * 9.0 + ph)) * clampf(v * 0.12, 0.05, 0.7)
			"steady":
				body.position.y = absf(sin(_t * 6.0 + ph)) * 0.05
			"dash":
				body.rotation_degrees.z = -clampf(v * 2.0, 0.0, 18.0)
				body.position.y = absf(sin(_t * 14.0 + ph)) * 0.08
			_:
				body.rotation_degrees.x = sin(_t * 12.0 + ph) * 14.0
				body.position.y = maxf(0.0, sin(_t * 3.0 + ph)) * clampf(v * 0.06, 0.0, 0.4)
		lead = maxf(lead, x)
	_place_camera(clampf(lead - 2.0, 0.0, TRACK - 3.0))


## Every player still in backs a racer, whoever is furthest behind first
## (Minigames.race_pick_order); humans click, CPUs pick by themselves.
## Returns [[player index, racer index], ...] in that order.
func choose(g: GameState) -> Array:
	_title.text = "Critter Race"
	result.text = ""
	_plan = []
	_t = -1.0
	_podium_t = -1.0
	_podium.visible = false
	_confetti.emitting = false
	for i in _racers.size():
		_racers[i].position = Vector3(0, 0, _lane_z[i])
		_racers[i].rotation = Vector3.ZERO
		var body: Node3D = _racers[i].get_child(0)
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		_tags[i].modulate = Color.WHITE
		_tags[i].text = Minigames.RACERS[i].name
		_tags[i].pixel_size = 0.009
	_place_camera(0.0)
	_picks.visible = true
	visible = true
	_names.assign(g.players.map(func(x): return x.name))
	var picks := []
	for seat in Minigames.race_pick_order(g):
		var q := g.players[seat]
		var pick: int
		if q.is_cpu:
			_hint.text = "%s is picking a racer..." % q.name
			for b in _picks.get_children():
				b.disabled = true
			await get_tree().create_timer(CPU_PICK).timeout
			pick = Minigames.cpu_racer(g)
		else:
			_hint.text = "%s, who will you cheer on? 1st %d G (Lv %d) · 2nd %d G · 3rd %d G" % [
					q.name, Minigames.race_amount(0, q.level), q.level,
					Minigames.race_amount(1, q.level), Minigames.race_amount(2, q.level)]
			for b in _picks.get_children():
				b.disabled = false
			pick = await racer_picked
		picks.append([q.index, pick])
		_show_backers(picks)
	_picks.visible = false
	return picks


## Each racer's tag lists who backed it, in the first backer's colour.
func _show_backers(picks: Array) -> void:
	for i in _racers.size():
		var names := []
		var colour := Color.WHITE
		for pk in picks:
			if pk[1] == i:
				if names.is_empty():
					colour = BoardView.PLAYER_COLORS[pk[0]].lightened(0.25)
				names.append(_names[pk[0]])
		_tags[i].text = Minigames.RACERS[i].name if names.is_empty() \
				else "%s ★ %s" % [Minigames.RACERS[i].name, ", ".join(names)]
		_tags[i].modulate = colour


## Runs the race from `plan`, with `picks` (from choose) shown on the tags;
## returns once the podium is up. The caller pays each player.
func run(plan: Array, picks: Array) -> void:
	_plan = plan
	_phase.clear()
	for i in _racers.size():
		_phase.append(randf() * TAU)
	_show_backers(picks)
	for s in ["3", "2", "1"]:
		_hint.text = "Ready... %s" % s
		await get_tree().create_timer(0.6).timeout
	_hint.text = "GO!"
	_t = 0.0
	var longest := 0.0
	for e in plan:
		longest = maxf(longest, e.time)
	await get_tree().create_timer(longest + FINISH_HOLD).timeout
	var order := Minigames.race_order(plan)
	var names := order.map(func(i): return Minigames.RACERS[i].name)
	_hint.text = "1st %s · 2nd %s · 3rd %s · 4th %s" % names
	_show_podium(order)
	await get_tree().create_timer(PODIUM_LEAD).timeout


## One player's payout on the podium: who backed what and what it won.
func show_result(q: PlayerState, racer: int, prize: Dictionary) -> void:
	result.text = "%s backed the %s: %s" % [q.name, Minigames.RACERS[racer].name, prize.text]
	result.add_theme_color_override("font_color", BoardView.PLAYER_COLORS[q.index].darkened(0.25)
			if prize.kind != "none" else Color("#9a8a7a"))
