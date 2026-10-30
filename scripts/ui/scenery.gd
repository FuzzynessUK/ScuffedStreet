class_name Scenery
extends Node3D
## The backdrop round and below the board, in one of a few themes, gently
## animated (slow drifting, bobbing, rolling waves, flickering, the odd distant
## cannon shot or meteor; nothing to pull the eye from the board). make()
## builds a theme for a board spanning `lo`..`hi`; the theme also says what
## the sky, the light and the fog look like, which BoardView applies.
##
## The board floats high above the scenery (DROP below it), so the theme's
## world shows between and round the tiles; there is no slab under the board.
## The camera looks down, so each theme is built close round the board, where
## it is always in view, and nothing in front of the board rises high enough
## to cover tiles. Surfaces carry soft natural textures in muted colours, and
## nothing in the scenery takes or casts shadows (the board's shadow does not
## fall on it).
##
##   lagoon   the Pirate Sea with the water still and, instead of the
##            seagulls and the buoy, a fish leaping out of it now and then
##            (Turtle Islands)
##   sea      a rough sea of big rolling waves under an overcast sky, further
##            down than the other themes; two big pirate ships ride them,
##            trading cannon fire, angled across the board; seagulls wheeling
##            overhead; (flash, smoke, a ball
##            arcing over, a splash); a third ship far off, rocks, barrels
##   space    stars all round, planets circling slowly below the board, each
##            on its own level so they never meet (a gas giant, a red rocky
##            one, an ice world, a blue-green one, a small moon), meteors
##            streaking past now and then
##   volcano  a sea of lava filling the whole view, glowing into a red haze at
##            the horizon; stone pillars and rocky outcrops standing in it,
##            broken platforms drifting, lava bubbles swelling and popping,
##            embers rising
##   castle   a historic fortress: massive curtain walls with battlements,
##            square towers, a gatehouse with a portcullis, the keep behind,
##            a moat, banners, soldiers patrolling the walls, cannons;
##            catapults flinging, barrels, crates and hay in the courtyard;
##            a great army filling the ground outside the back gate (ranks of
##            soldiers in companies, knights on horseback, standard bearers,
##            siege cannons, tents), seen over a low back wall
##   racing   a crazy slot-car Grand Prix: five tracks running right across
##            the scene and off the screen at both ends, at three heights so
##            they cross over one another (a main straight under the board
##            with a start gantry, an S-bend in front, two flyovers front to
##            back, a high flyover sweeping across in big S-curves);
##            Formula One cars in team colours, each in its slot at its own
##            speed, riding the climbs smoothly
##   storm    dark storm clouds drifting slowly below the board; the weather
##            turns from rain to hail to snow; lightning flickers inside the
##            clouds, followed by thunder

const B := preload("res://scripts/ui/board_view.gd")  # its model builders
const THEMES := ["sea", "lagoon", "space", "volcano", "castle", "racing", "storm"]
const NAMES := {"sea": "Pirate Sea", "lagoon": "Calm Sea", "space": "Space", "volcano": "Lava Dungeon",
		"castle": "Grand Castle", "racing": "Slot-Car Grand Prix", "storm": "Storm Clouds"}
const TEXTURE_SIZE := 256
const DROP := 3.0  # how far below the board the scenery lies (most themes)
const SEA_DROP := 4.2  # Pirate Sea: how far below the board the water lies
const WEATHER_SPELL := 25.0  # Storm Clouds: seconds of rain, then hail, then snow
const THUNDER_DELAY := 0.7  # seconds from a flash to its thunderclap
const BACK_WALL := 1.8  # Grand Castle: the back wall's height
const ARMY_DEPTH := 7.0  # how far back from the moat the army fills
const TRACK_POINTS := 160  # points along each slot-car track
const RACING_HAZE := 0.38  # how much the haze over the F1 tracks lightens them
const WAVES := [[0.7, 0.3, 0.0, 1.1], [0.45, 0.0, 0.42, -0.9], [0.12, 0.8, 0.8, 1.8]]  # [height, kx, kz, speed]
const SEA_SHADER := """
shader_type spatial;
render_mode shadows_disabled, cull_disabled;
uniform float wave_time = 0.0;
uniform float wave_scale = 1.0;  // 0: a still, flat sea (Calm Sea)
uniform vec4 deep : source_color = vec4(0.01, 0.12, 0.2, 1.0);
uniform vec4 crest : source_color = vec4(0.03, 0.32, 0.4, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.88, 0.9, 1.0);
varying float height;
float wave(vec2 p, float a, float kx, float kz, float speed) {
	return a * sin(p.x * kx + p.y * kz + wave_time * speed);
}
float dwave(vec2 p, float a, float kx, float kz, float speed, float k) {
	return a * k * cos(p.x * kx + p.y * kz + wave_time * speed);
}
void vertex() {
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	height = wave(p, 0.7, 0.3, 0.0, 1.1) + wave(p, 0.45, 0.0, 0.42, -0.9) + wave(p, 0.12, 0.8, 0.8, 1.8);
	height *= wave_scale;
	VERTEX.y += height;
	float dx = dwave(p, 0.7, 0.3, 0.0, 1.1, 0.3) + dwave(p, 0.12, 0.8, 0.8, 1.8, 0.8);
	float dz = dwave(p, 0.45, 0.0, 0.42, -0.9, 0.42) + dwave(p, 0.12, 0.8, 0.8, 1.8, 0.8);
	dx *= wave_scale;
	dz *= wave_scale;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}
void fragment() {
	vec3 c = mix(deep.rgb, crest.rgb, clamp(height * 0.5 + 0.5, 0.0, 1.0));
	c = mix(c, foam.rgb, smoothstep(1.12, 1.27, height) * 0.6);  // foam only on the highest crests
	ALBEDO = c;
	ROUGHNESS = 0.7;
	SPECULAR = 0.04;  // no bright patches of sky reflected: deep water, not sky
	METALLIC = 0.1;
}
"""

var sky := Color("#8cc8f0")  # the background colour
var ambient := Color("#bcd4ee")
var ambient_energy := 0.34
var sun_color := Color("#fff0d8")
var sun_energy := 0.8
var fog := 0.0  # depth fog density (0: none), fading into the sky colour
var drop := DROP  # how far below the board this theme lies
var shrink := 1.0  # the whole backdrop's size (Racing: smaller, so more of it shows)
var shift_back := 0.0  # how far back it sits, per unit of drop (Castle: centred under the board)
var wave_scale := 1.0  # the sea's waves (Calm Sea: 0, still water)

signal thunder  # a thunderclap after a lightning flash (Storm Clouds)

var _time := 0.0
var _anims: Array[Callable] = []  # each called every frame with the time so far
var _rng := RandomNumberGenerator.new()
var _centre := Vector3.ZERO
var _half := Vector2.ONE  # half the board's size, plus a margin
var _reach := 1.0
var _textures := {}  # textures made for this backdrop, by their two colours
var _sea: ShaderMaterial  # the waves, kept in step with the ships


static func make(theme: String, lo: Vector3, hi: Vector3) -> Scenery:
	var s := Scenery.new()
	s._rng.seed = 1964
	s._centre = (lo + hi) / 2
	s._half = Vector2(hi.x - lo.x, hi.z - lo.z) / 2 + Vector2(1.6, 1.6)
	s._reach = maxf(s._half.x, s._half.y)
	match theme:
		"space":
			s._space()
		"volcano":
			s._volcano()
		"castle":
			s._castle()
		"racing":
			s._racing()
		"storm":
			s._storm()
		"lagoon":  # the Pirate Sea with the water still
			s.wave_scale = 0.0
			s._pirate_sea()
		_:
			s._pirate_sea()
	s._no_shadows(s)
	s.scale = Vector3.ONE * s.shrink  # about the board's centre
	s.position = s._centre * (1.0 - s.shrink) + Vector3(0, -s.drop, 0)
	# Shifted back along the view, so the ground below lines up under the
	# board as the camera sees it (the board floats DROP above it).
	s.position.z -= s.drop * s.shift_back
	return s


func _process(delta: float) -> void:
	_time += delta
	if _sea:
		_sea.set_shader_parameter("wave_time", _time)
	for a in _anims:
		a.call(_time)


## A material with a soft natural pattern between two shades, the same density
## on every surface whatever its size (`tile`: metres one copy of the pattern
## covers). `glow` makes it shine with its own colours (lava).
func textured(dark: Color, light: Color, tile := 4.0, glow := 0.0, roughness := 0.95) -> StandardMaterial3D:
	var key := "%s|%s" % [dark.to_html(), light.to_html()]
	if not _textures.has(key):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 5
		noise.seed = key.hash()
		var tex := NoiseTexture2D.new()
		tex.width = TEXTURE_SIZE
		tex.height = TEXTURE_SIZE
		tex.seamless = true
		tex.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, dark)
		ramp.set_color(1, light)
		tex.color_ramp = ramp
		_textures[key] = tex
	var m := StandardMaterial3D.new()
	m.albedo_texture = _textures[key]
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	m.roughness = roughness
	if glow > 0.0:
		m.emission_enabled = true
		m.emission_texture = _textures[key]
		m.emission_energy_multiplier = glow
	return m


## Nothing in the scenery takes or casts a shadow.
func _no_shadows(node: Node) -> void:
	for child in node.get_children():
		var mi := child as MeshInstance3D
		if mi:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var m := mi.material_override as BaseMaterial3D
			if m:
				m.disable_receive_shadows = true
		_no_shadows(child)


# --- themes ---------------------------------------------------------------

func _pirate_sea() -> void:
	sky = Color("#7a98ac")
	ambient = Color("#b8c8d4")
	ambient_energy = 0.42
	sun_color = Color("#fff4e0")
	sun_energy = 0.8
	fog = 0.0015
	drop = SEA_DROP  # close under the board: the ships' masts end just below the tiles
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * _reach * 9.0
	plane.subdivide_width = 140
	plane.subdivide_depth = 140
	var water := MeshInstance3D.new()
	water.mesh = plane
	var shader := Shader.new()
	shader.code = SEA_SHADER
	_sea = ShaderMaterial.new()
	_sea.shader = shader
	_sea.set_shader_parameter("wave_scale", wave_scale)
	water.material_override = _sea
	_add(water, _centre)
	# Two ships either side of the board, broadside on, trading shots.
	var left := _ship(Color("#e8e0cc"), Color("#151515"))
	left.scale = Vector3.ONE * 2.0
	_float(left, _centre + Vector3(-_half.x * 0.5, 0, 0.6), PI / 2 - 0.7)  # angled across the board
	var right := _ship(Color("#d8cfb8"), Color("#8e2420"))
	right.scale = Vector3.ONE * 2.0
	_float(right, _centre + Vector3(_half.x * 0.5, 0, -0.6), -PI / 2 - 0.7)
	_cannon_fire(left, right, 0.0, 7.0)
	_cannon_fire(right, left, 3.6, 8.0)
	# A third ship far off, sailing slowly across.
	var far := _ship(Color("#cfc6b0"), Color("#151515"))
	far.scale = Vector3.ONE * 1.6
	_add(far, Vector3.ZERO)
	var far_z := _centre.z - _half.y - 7.0
	_anims.append(func(t: float):
		var x := _centre.x - _reach * 2.5 + fmod(t * 0.25, _reach * 5.0)
		far.position = Vector3(x, _wave_height(x, far_z) - 0.1, far_z)
		far.rotation = Vector3(_tilt(x, far_z).x, 0, _tilt(x, far_z).y))
	if wave_scale == 0.0:  # the still lagoon: fish leaping now and then instead
		_leaping_fish()
	# Seagulls wheeling over the water, wings flapping, in wide lazy circles.
	for i in (7 if wave_scale > 0.0 else 0):
		var gull := _seagull()
		_add(gull, _centre)
		var r := _rng.randf_range(_reach * 0.4, _reach * 1.2)
		var height := _rng.randf_range(1.5, 3.6)  # under the board, over the masts
		var speed := _rng.randf_range(0.15, 0.3) * (1 if i % 2 == 0 else -1)
		var start := _rng.randf() * TAU
		var wing_l: Node3D = gull.get_meta("left")
		var wing_r: Node3D = gull.get_meta("right")
		var flap := _rng.randf_range(5.0, 7.0)
		_anims.append(func(t: float):
			var a := start + t * speed
			gull.position = _centre + Vector3(cos(a) * r, height + sin(t * 0.7 + start) * 0.25, sin(a) * r * 0.7)
			var along := Vector3(-sin(a), 0, cos(a) * 0.7) * signf(speed)
			gull.rotation = Vector3(0, atan2(along.x, along.z), -0.3 * signf(speed))
			var w := sin(t * flap + start) * 0.6 if fmod(t + start, 4.0) < 2.5 else 0.1  # flapping, then gliding
			wing_l.rotation.z = w
			wing_r.rotation.z = -w)
	# A shark circling round the board, its fin cutting the water.
	var fin := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.8, 0.08)
	prism.left_to_right = 0.2
	fin.mesh = prism
	fin.material_override = textured(Color("#3a4450"), Color("#5a6470"), 0.4)
	_add(fin, _centre)
	var wake := B._box(Vector3(0.9, 0.03, 0.12), Color(0.9, 0.95, 0.97))
	_add(wake, _centre)
	_anims.append(func(t: float):
		var a := t * 0.18
		var r := _reach * 0.75
		var x := _centre.x + cos(a) * r
		var z := _centre.z + sin(a) * r * 0.7
		var y := _wave_height(x, z)
		fin.position = Vector3(x, y + 0.3, z)
		fin.rotation.y = -a
		wake.position = Vector3(x, y + 0.02, z)
		wake.rotation.y = -a)
	# Life rings bobbing on the waves.
	for i in 4:
		var ring := Node3D.new()
		for k in 8:
			var seg := B._cyl(0.11, 0.11, 0.42, Color("#e8302a") if k % 2 == 0 else Color("#f4f4f0"))
			var a := TAU * k / 8.0
			seg.position = Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
			seg.rotation = Vector3(PI / 2, -a, 0)
			ring.add_child(seg)
		_float(ring, _spot(_rng.randf() * TAU, _rng.randf_range(-3.0, 3.0)), _rng.randf() * TAU)
	if wave_scale > 0.0:  # a buoy with a light blinking on top (not on the still lagoon)
		var buoy := Node3D.new()
		var body := B._cyl(0.25, 0.4, 0.9, Color("#e8b020"))
		body.position.y = 0.3
		buoy.add_child(body)
		var light := _ball(0.1, Color.WHITE)
		var light_m := B._material(Color("#ff4030"), 2.0)
		light.material_override = light_m
		light.position.y = 0.85
		buoy.add_child(light)
		_float(buoy, _spot(0.8, 2.0), 0.0)
		_anims.append(func(t: float): light_m.emission_energy_multiplier = 2.5 if fmod(t, 2.0) < 0.3 else 0.2)
	# Rocks and floating barrels.
	var rock := textured(Color("#2a2c2e"), Color("#4c5052"), 1.2)
	for i in 6:
		var at := _spot(_rng.randf() * TAU, _rng.randf_range(3.0, 10.0))
		var lump := B._cyl(0.0, _rng.randf_range(0.6, 1.4), _rng.randf_range(1.2, 2.6), Color.WHITE)
		(lump.mesh as CylinderMesh).radial_segments = 6
		lump.material_override = rock
		lump.rotation = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf() * TAU, _rng.randf_range(-0.2, 0.2))
		_add(lump, at + Vector3(0, 0.3, 0))
	var wood := textured(Color("#3c2a1a"), Color("#6a4a2c"), 0.4)
	for i in 5:
		var barrel := B._cyl(0.14, 0.14, 0.35, Color.WHITE)
		barrel.material_override = wood
		barrel.rotation.z = PI / 2
		_float(barrel, _spot(_rng.randf() * TAU, _rng.randf_range(0.5, 5.0)), _rng.randf() * TAU)


func _space() -> void:
	sky = Color("#04050c")
	ambient = Color("#7a80b8")
	ambient_energy = 0.5
	sun_color = Color("#f4f6ff")
	sun_energy = 0.9
	# Stars all round and below, each twinkling at its own pace.
	for i in 220:
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, -0.15), _rng.randf_range(-1, 1)).normalized()
		var star := _ball(_rng.randf_range(0.03, 0.08), Color.WHITE)
		var m := B._material(Color("#fff6e8") if i % 3 else Color("#c8dcff"), 1.4)
		star.material_override = m
		_add(star, _centre + dir * _rng.randf_range(_reach * 1.2, _reach * 3.5))
		var phase := _rng.randf() * TAU
		var speed := _rng.randf_range(0.8, 2.0)
		_anims.append(func(t: float): m.emission_energy_multiplier = 0.9 + 0.6 * sin(t * speed + phase))
	# Planets circling slowly below the board, each on its own level and
	# orbit, spaced so they never meet, each turning as it goes.
	var planets := [  # [radius, orbit, depth, speed, dark, light, ringed]
		[2.2, _reach * 1.9, -7.0, 0.05, Color("#6a3a26"), Color("#c08050"), false],
		[1.1, _reach * 1.3, -13.0, -0.07, Color("#5a1e14"), Color("#b0503a"), false],
		[1.6, _reach * 2.4, -18.0, 0.04, Color("#7a9ab0"), Color("#e0f0f8"), false],
		[2.6, _reach * 1.6, -26.0, -0.03, Color("#1a3a5a"), Color("#4a8a7a"), false],
		[0.7, _reach * 2.8, -10.0, 0.09, Color("#5a5a60"), Color("#a8a8b0"), false],
	]
	for i in planets.size():
		var p: Array = planets[i]
		var planet := _planet(Vector3.ZERO, p[0], p[4], p[5], p[6], 0.15)
		var start := TAU * i / planets.size()
		_anims.append(func(t: float):
			var a: float = start + t * p[3]
			planet.position = _centre + Vector3(cos(a) * p[1], p[2], sin(a) * p[1] * 0.7))
	# Small space rocks tumbling slowly about.
	var rock_m := textured(Color("#3a342e"), Color("#6e665c"), 0.4)
	for i in 40:
		var rock := MeshInstance3D.new()
		var lump := SphereMesh.new()
		var r := _rng.randf_range(0.06, 0.22)
		lump.radius = r
		lump.height = r * _rng.randf_range(1.2, 1.8)
		lump.radial_segments = 6
		lump.rings = 3
		rock.mesh = lump
		rock.material_override = rock_m
		var base := _centre + Vector3(_rng.randf_range(-_reach * 1.5, _reach * 1.5), _rng.randf_range(-4.0, 1.0),
				_rng.randf_range(-_reach * 1.4, _reach * 1.2))
		_add(rock, base)
		var drift := Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.08, 0.08))
		var spin := Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * 0.6
		var span := _reach * 3.0
		_anims.append(func(t: float):
			var p := base + drift * t
			p.x = _centre.x - span / 2 + fposmod(p.x - _centre.x + span / 2, span)  # round again
			p.z = _centre.z - span / 2 + fposmod(p.z - _centre.z + span / 2, span)
			rock.position = p
			rock.rotation = spin * t)
	# Meteors streaking past below the board now and then.
	for i in 3:
		var head := _ball(0.12, Color.WHITE)
		head.material_override = B._material(Color("#ffe8c0"), 2.5)
		var trail := B._box(Vector3(0.08, 0.08, 2.4), Color.WHITE)
		var tm := B._material(Color("#ff9a50", 0.6), 1.5)
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		trail.material_override = tm
		var meteor := Node3D.new()
		meteor.add_child(head)
		trail.position.z = 1.2
		meteor.add_child(trail)
		_add(meteor, _centre)
		meteor.visible = false
		var period := _rng.randf_range(7.0, 12.0)
		var offset := _rng.randf() * period
		_anims.append(func(t: float):
			var cycle := floorf((t + offset) / period)
			var phase := fmod(t + offset, period)
			meteor.visible = phase < 1.6
			if not meteor.visible:
				return
			var r := RandomNumberGenerator.new()
			r.seed = int(cycle) * 7919 + i
			var from := _centre + Vector3(r.randf_range(-_reach * 2, _reach * 2), r.randf_range(-6, -2), -_reach * 2.5)
			var to := from + Vector3(r.randf_range(-_reach, _reach), r.randf_range(-6, -2), _reach * 4.5)
			meteor.position = from.lerp(to, phase / 1.6)
			meteor.look_at(meteor.position + (to - from), Vector3.UP))


func _volcano() -> void:
	sky = Color("#4a1206")  # the lava's glow on the haze, so the horizon melts into it
	ambient = Color("#c08060")
	ambient_energy = 0.32
	sun_color = Color("#ffb87a")
	sun_energy = 0.6
	fog = 0.02
	var stone := textured(Color("#231b18"), Color("#463830"), 1.0)
	# Lava under the whole stage, flowing slowly and glowing.
	var lava := textured(Color("#5a1204"), Color("#e8661a"), 5.0, 0.7, 0.6)
	_add(_slab(Vector3(_reach * 40, 0.1, _reach * 40), lava), _centre - Vector3(0, 0.6, 0))  # to every edge of the screen
	_anims.append(func(t: float):
		lava.uv1_offset = Vector3(t * 0.004, 0, t * 0.0025)
		lava.emission_energy_multiplier = 0.65 + 0.12 * sin(t * 0.7))
	# Stone pillars rising from the lava round the board.
	for k in 8:
		var at := _spot(TAU * k / 8.0 + 0.3, 1.2)
		var h := 2.2
		_add(_slab(Vector3(0.9, h + 0.6, 0.9), stone), at + Vector3(0, h / 2 - 0.6, 0))
		_add(_slab(Vector3(1.2, 0.3, 1.2), stone), at + Vector3(0, h - 0.15, 0))
	# Broken platforms of stone drifting very slowly in the lava.
	for k in 6:
		var at := _spot(_rng.randf() * TAU, _rng.randf_range(0.5, 2.0))
		var slab := _add(_slab(Vector3(_rng.randf_range(0.8, 1.6), 0.3, _rng.randf_range(0.6, 1.2)), stone), at - Vector3(0, 0.45, 0))
		slab.rotation = Vector3(_rng.randf_range(-0.08, 0.08), _rng.randf() * TAU, _rng.randf_range(-0.08, 0.08))
		var phase := _rng.randf() * TAU
		var rest := slab.position
		_anims.append(func(t: float): slab.position = rest + Vector3(0, sin(t * 0.4 + phase) * 0.04, 0))
	# Rocky outcrops standing in the lava all over, glowing where the lava
	# meets them.
	var glow_rim := B._material(Color("#c84a10"), 0.5)
	for k in 36:  # spread over the whole sea, right up to the top of the view
		var at := _centre + Vector3(_rng.randf_range(-_reach * 1.8, _reach * 1.8), 0,
				_rng.randf_range(-_reach * 2.8, _reach * 0.9))
		var cluster := Node3D.new()
		_add(cluster, at - Vector3(0, 0.6, 0))
		for j in _rng.randi_range(2, 4):
			var h := _rng.randf_range(0.5, 2.0)
			var rock := B._cyl(_rng.randf_range(0.05, 0.25), _rng.randf_range(0.35, 0.8), h, Color.WHITE)
			(rock.mesh as CylinderMesh).radial_segments = 5
			rock.material_override = stone
			rock.position = Vector3(_rng.randf_range(-0.5, 0.5), h / 2, _rng.randf_range(-0.5, 0.5))
			rock.rotation = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.25, 0.25))
			cluster.add_child(rock)
		var rim := B._cyl(0.55, 0.62, 0.05, Color.WHITE)
		rim.material_override = glow_rim
		rim.position.y = 0.06
		cluster.add_child(rim)
	_anims.append(func(t: float): glow_rim.emission_energy_multiplier = 0.45 + 0.15 * sin(t * 0.9))
	# Bubbles in the lava: each swells up slowly, pops with a ring spreading
	# out, and comes again a few seconds later.
	var bubble_m := B._material(Color("#ff7a20"), 1.2)
	for i in 26:
		var at := _centre + Vector3(_rng.randf_range(-_reach * 1.6, _reach * 1.6), -0.56,
				_rng.randf_range(-_reach * 2.4, _reach * 0.8))
		var bubble := _ball(1.0, Color.WHITE)
		bubble.material_override = bubble_m
		_add(bubble, at)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0
		ring.mesh = torus
		var ring_m := B._material(Color(1.0, 0.6, 0.2, 0.8), 1.4)
		ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = ring_m
		_add(ring, at)
		var size := _rng.randf_range(0.12, 0.3)
		var period := _rng.randf_range(2.5, 5.5)
		var offset := _rng.randf() * period
		_anims.append(func(t: float):
			var ph := fmod(t + offset, period) / period
			if ph < 0.8:  # swelling
				var k := ph / 0.8
				bubble.visible = true
				bubble.scale = Vector3(1, 0.7, 1) * size * k
				ring.visible = false
			else:  # popped: the ring spreads and fades
				var k := (ph - 0.8) / 0.2
				bubble.visible = false
				ring.visible = true
				ring.scale = Vector3(1, 0.3, 1) * size * (1.0 + k * 2.0)
				ring_m.albedo_color.a = 0.8 * (1.0 - k))
	# Embers drifting up from the lava and fading out, then starting again.
	for i in 30:
		var ember := _ball(_rng.randf_range(0.03, 0.06), Color.WHITE)
		var m := B._material(Color("#ffa040"), 1.8)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ember.material_override = m
		var base := _spot(_rng.randf() * TAU, _rng.randf_range(-3.0, 4.0)) - Vector3(0, 0.5, 0)
		_add(ember, base)
		var speed := _rng.randf_range(0.2, 0.45)
		var offset := _rng.randf() * 3.0
		var sway := _rng.randf() * TAU
		_anims.append(func(t: float):
			var k := fmod(t * speed + offset, 3.0)  # up to just under the board, then round again
			ember.position = base + Vector3(sin(t * 0.8 + sway) * 0.3, k, 0)
			m.albedo_color.a = clampf(1.0 - k / 3.0, 0.0, 1.0))


func _castle() -> void:
	sky = Color("#9fb4c4")
	shift_back = 0.65  # the courtyard centred under the board as seen
	ambient = Color("#c8d4de")
	ambient_energy = 0.38
	sun_energy = 0.8
	fog = 0.004
	var stone := textured(Color("#77706a"), Color("#a29a8e"), 1.2)
	var dark_stone := textured(Color("#5a544e"), Color("#7e766c"), 1.2)
	_ground(textured(Color("#5e5440"), Color("#7e7258"), 3.0))  # packed earth inside the walls
	var hx := _half.x + 1.0
	var hz := _half.y + 1.0
	# The moat outside the walls.
	var water := textured(Color("#2a3e48"), Color("#456470"), 2.5, 0.0, 0.2)
	_anims.append(func(t: float): water.uv1_offset = Vector3(t * 0.004, 0, 0))
	for side in [[Vector3(0, 0, -hz - 2.2), Vector3(hx * 2 + 7.0, 0.06, 2.4)], [Vector3(0, 0, hz + 2.2), Vector3(hx * 2 + 7.0, 0.06, 2.4)],
			[Vector3(-hx - 2.2, 0, 0), Vector3(2.4, 0.06, hz * 2 + 2.0)], [Vector3(hx + 2.2, 0, 0), Vector3(2.4, 0.06, hz * 2 + 2.0)]]:
		_add(_slab(side[1], water), _centre + side[0] - Vector3(0, 0.08, 0))
	# Massive curtain walls with battlements: tall at the sides, low behind (so
	# the army outside the gate shows over it) and in front (the board).
	_wall(Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), BACK_WALL, 1.0, stone)
	_wall(Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), 3.0, 1.0, stone)
	_wall(Vector3(hx, 0, -hz), Vector3(hx, 0, hz), 3.0, 1.0, stone)
	_wall(Vector3(-hx, 0, hz), Vector3(hx, 0, hz), 1.6, 0.9, stone)
	# Square towers at the corners.
	for c in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(hx, 0, hz)]:
		_square_tower(_centre + c, 2.2, 4.5 if c.z < 0 else 2.2, dark_stone)
	# The gatehouse in the back wall: round towers either side, a portcullis.
	var gate := _centre + Vector3(0, 0, -hz)
	for x in [-1.5, 1.5]:
		var tower := B._cyl(1.0, 1.05, 6.2, Color.WHITE)
		tower.material_override = dark_stone
		_add(tower, gate + Vector3(x, 3.1, 0.2))
		for k in 8:
			var a := TAU * k / 8.0
			_add(_slab(Vector3(0.35, 0.4, 0.35), dark_stone), gate + Vector3(x + cos(a) * 0.9, 6.4, 0.2 + sin(a) * 0.9))
	_add(B._box(Vector3(1.8, 2.6, 0.1), Color("#120e0c")), gate + Vector3(0, 1.3, 0.55))
	for k in 6:  # the portcullis
		_add(B._box(Vector3(0.05, 2.5, 0.05), Color("#3a3a3e")), gate + Vector3(-0.75 + k * 0.3, 1.3, 0.62))
	for k in 5:
		_add(B._box(Vector3(1.7, 0.05, 0.05), Color("#3a3a3e")), gate + Vector3(0, 0.3 + k * 0.5, 0.62))
	# The great keep behind, a flag on top.
	var keep := _centre + Vector3(0, 0, -hz - ARMY_DEPTH - 6.0)  # beyond the army
	_add(_slab(Vector3(6.0, 8.5, 4.5), dark_stone), keep + Vector3(0, 4.25, 0))
	_battlements(keep + Vector3(-3.0, 8.5, 2.25), keep + Vector3(3.0, 8.5, 2.25), dark_stone)
	for x in [-1.5, 0.0, 1.5]:
		for y in [3.0, 5.5]:
			_add(B._box(Vector3(0.18, 0.7, 0.05), Color("#141210")), keep + Vector3(x, y, 2.27))
	_flag(keep + Vector3(0, 8.5, 0), Color("#8e2420"))
	# Banners hanging still on the gatehouse towers.
	for x in [-1.5, 1.5]:
		var banner := Node3D.new()
		_add(banner, gate + Vector3(x, 5.6, 1.22))
		var cloth := B._box(Vector3(0.7, 2.2, 0.03), Color("#8e2420"))
		cloth.position.y = -1.1
		banner.add_child(cloth)
		var stripe := B._box(Vector3(0.16, 2.2, 0.035), Color("#c8a040"))
		stripe.position.y = -1.1
		banner.add_child(stripe)
	# Cannons along the walls, pointing out; one fires now and then.
	var cannons: Array[Node3D] = []
	for c in [[Vector3(-hx * 0.5, BACK_WALL, -hz - 0.1), PI], [Vector3(hx * 0.5, BACK_WALL, -hz - 0.1), PI],
			[Vector3(-hx - 0.1, 3.0, -hz * 0.3), -PI / 2], [Vector3(hx + 0.1, 3.0, -hz * 0.3), PI / 2],
			[Vector3(-hx - 0.1, 3.0, hz * 0.4), -PI / 2], [Vector3(hx + 0.1, 3.0, hz * 0.4), PI / 2]]:
		var cannon := _cannon()
		cannon.rotation.y = c[1]
		_add(cannon, _centre + c[0])
		cannons.append(cannon)
	_volleys(cannons, 6.0)
	# Catapults in the courtyard, under the board, each flinging now and then.
	for k in 3:
		var cat := _catapult()
		var at := _centre + Vector3((k - 1) * hx * 0.55, -0.1, -hz * 0.25 + (k % 2) * hz * 0.4)
		cat.rotation.y = PI + (k - 1) * 0.3
		_add(cat, at)
		var arm: Node3D = cat.get_meta("arm")
		var period := 7.0 + k * 1.3
		var offset := k * 2.2
		_anims.append(func(t: float):
			var ph := fmod(t + offset, period)
			if ph < 0.25:  # the throw
				arm.rotation.x = lerpf(-1.1, 0.6, ph / 0.25)
			else:  # winding back down
				arm.rotation.x = lerpf(0.6, -1.1, clampf((ph - 0.25) / (period * 0.6), 0.0, 1.0)))
	# Barrels, crates and haystacks about the courtyard.
	var wood := textured(Color("#4a3420"), Color("#6e5034"), 0.4)
	var hay := textured(Color("#a8883a"), Color("#d8b85a"), 0.3)
	for i in 14:
		var at := _centre + Vector3(_rng.randf_range(-hx + 1.0, hx - 1.0), 0, _rng.randf_range(-hz + 1.0, hz - 1.0))
		match i % 3:
			0:
				var barrel := B._cyl(0.22, 0.22, 0.5, Color.WHITE)
				barrel.material_override = wood
				_add(barrel, at + Vector3(0, 0.15, 0))
			1:
				var crate := _add(_slab(Vector3(0.5, 0.5, 0.5), wood), at + Vector3(0, 0.15, 0))
				crate.rotation.y = _rng.randf() * PI
			_:
				var bale := B._cyl(0.35, 0.35, 0.6, Color.WHITE)
				bale.material_override = hay
				bale.rotation.z = PI / 2
				_add(bale, at + Vector3(0, 0.25, 0))
	# Soldiers patrolling the wall walks.
	for k in 6:
		var a: Vector3
		var b: Vector3
		var y: float
		match k % 3:
			0:
				a = Vector3(-hx + 1.5, 0, -hz)
				b = Vector3(hx - 1.5, 0, -hz)
				y = BACK_WALL
			1:
				a = Vector3(-hx, 0, -hz + 1.5)
				b = Vector3(-hx, 0, hz - 1.5)
				y = 3.0
			_:
				a = Vector3(hx, 0, -hz + 1.5)
				b = Vector3(hx, 0, hz - 1.5)
				y = 3.0
		_soldier(_centre + a + Vector3(0, y, 0), _centre + b + Vector3(0, y, 0), k)
	# An army camped outside, behind the castle at the top of the view.
	_army(hx, hz)
	# Trees beyond the moat.
	for i in 24:
		var side := -1.0 if i % 2 == 0 else 1.0
		_tree(_centre + Vector3(side * _rng.randf_range(hx + 5.0, hx + 13.0), 0,
				_rng.randf_range(-hz - 8.0, hz + 4.0)), _rng.randf_range(0.9, 1.5))


func _racing() -> void:
	sky = Color("#a9c2d4")
	shrink = 0.6  # everything smaller, more road in view
	ambient_energy = 0.38
	fog = 0.003
	_add(_slab(Vector3(_reach * 18, 0.1, _reach * 18), textured(Color("#2f5a2a"), Color("#3e6e34"), 4.0)),
			_centre - Vector3(0, 0.17, 0))  # the green baize under the set, wide enough once shrunk
	# Slot-car tracks running right across the scene, each well off the screen
	# at both ends, at three heights so they cross over one another: each a
	# run of points [position, up] the track is laid along and the cars follow.
	var far := _reach * 5.5  # how far past the board each track runs (off screen, shrunk)
	var hx := _half.x
	var hz := _half.y
	var tracks: Array = []
	# The main straight, under the board, along x on the ground.
	tracks.append(_track_path(func(u: float) -> Vector3:
		return _centre + Vector3(lerpf(-far, far, u), 0.0, -0.2)))
	# An S-bend sweeping across the front, on the ground.
	tracks.append(_track_path(func(u: float) -> Vector3:
		return _centre + Vector3(lerpf(far, -far, u), 0.0, hz * 0.85 + sin(u * TAU * 2.0) * 1.2)))
	# Two flyovers front to back, over the ground tracks.
	for x in [-hx * 0.45, hx * 0.45]:
		tracks.append(_track_path(func(u: float) -> Vector3:
			return _centre + Vector3(x + sin(u * TAU) * 0.8, 0.8, lerpf(far, -far, u))))
	# The high flyover, sweeping across over everything in big S-curves.
	tracks.append(_track_path(func(u: float) -> Vector3:
		var d := lerpf(-far, far, u)
		return _centre + Vector3(d, 1.6 + sin(u * TAU * 3.0) * 0.15, d * 0.3 + sin(u * TAU * 1.5) * hz * 0.9)))
	for track in tracks:
		_lay_track(track)
	# A haze between the board and the tracks, so they sit back softly behind
	# it, lighter and lower in contrast (the board itself is above it).
	var haze := MeshInstance3D.new()
	var sheet := PlaneMesh.new()
	sheet.size = Vector2.ONE * _reach * 30
	haze.mesh = sheet
	var haze_m := StandardMaterial3D.new()
	haze_m.albedo_color = Color(0.88, 0.92, 0.95, RACING_HAZE)
	haze_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.material_override = haze_m
	_add(haze, _centre + Vector3(0, (drop - 0.5) / shrink, 0))  # just under the board
	# A start gantry over the main straight, with its lights.
	var start := _centre + Vector3(-hx * 0.75, 0, -0.2)
	for z in [-0.95, 0.95]:
		_add(B._box(Vector3(0.1, 1.5, 0.1), Color("#c8c8d0")), start + Vector3(0, 0.75, z))
	_add(B._box(Vector3(0.2, 0.3, 2.1), Color("#202028")), start + Vector3(0, 1.5, 0))
	for k in 5:
		var lamp := _ball(0.06, Color.WHITE)
		lamp.material_override = B._material(Color("#e8302a"), 1.6)
		_add(lamp, start + Vector3(0.11, 1.5, -0.6 + k * 0.3))
	for i in 8:  # the chequered line
		for j in 2:
			_add(B._box(Vector3(0.18, 0.03, 0.18), Color("#151515") if (i + j) % 2 == 0 else Color("#ecece8")),
					start + Vector3(0.09 * j - 0.04, 0.05, -0.63 + i * 0.18))
	# Formula One cars in team colours, two to a track in their own slots, each
	# at its own pace; off one end of the screen and back on at the other.
	var teams := [Color("#d8201c"), Color("#1c3ac8"), Color("#e8b020"), Color("#20a060"), Color("#ececec"),
			Color("#e86a10"), Color("#7a2ac8"), Color("#151515"), Color("#18a8c8"), Color("#c81870")]
	for i in teams.size():
		var track: Array = tracks[i % tracks.size()]
		var car := _f1_car(teams[i])
		_add(car, Vector3.ZERO)
		var lane := 0.32 if i < tracks.size() else -0.32
		var pace := _rng.randf_range(0.035, 0.07)  # of the track a second
		var offset := _rng.randf()
		_anims.append(func(t: float): _ride(car, track, fposmod(t * pace + offset, 1.0), lane))


## A track's points along `at` (u from 0 to 1 -> position), level, closely
## enough spaced for smooth climbs.
func _track_path(at: Callable) -> Array:
	var pts: Array = []
	for k in TRACK_POINTS + 1:
		pts.append([at.call(k / float(TRACK_POINTS)), Vector3.UP])
	return pts


## Carries `car` to `along` (0..1) of the way along `track`, `lane` across
## from the middle, upright on the track and pointing along it.
func _ride(car: Node3D, track: Array, along: float, lane: float) -> void:
	var f := along * (track.size() - 1)
	var i := mini(int(f), track.size() - 2)
	var k := f - i
	var a: Array = track[i]
	var b: Array = track[i + 1]
	var up: Vector3 = (a[1] as Vector3).lerp(b[1], k).normalized()
	var ahead: Vector3 = (b[0] - a[0]).normalized()
	var side := ahead.cross(up).normalized()
	car.position = (a[0] as Vector3).lerp(b[0], k) + side * lane + up * 0.06
	car.basis = Basis(ahead, up, -side)  # cars face +x


## Lays a slot-car track along `track`: grey track with two slots, red and
## white edges, and posts under it where it is lifted.
func _lay_track(track: Array) -> void:
	var surface := textured(Color("#3a3a40"), Color("#4a4a52"), 0.6, 0.0, 0.6)
	for i in track.size() - 1:
		var p0: Vector3 = track[i][0]
		var p1: Vector3 = track[i + 1][0]
		var up: Vector3 = ((track[i][1] as Vector3) + track[i + 1][1]).normalized()
		var ahead := (p1 - p0).normalized()
		var side := ahead.cross(up).normalized()
		var holder := Node3D.new()
		holder.basis = Basis(side, up, -ahead)
		_add(holder, (p0 + p1) / 2)
		var length := p0.distance_to(p1) + 0.02
		holder.add_child(_slab(Vector3(1.3, 0.06, length), surface))
		for x in [-0.32, 0.32]:  # the slots
			var slot := B._box(Vector3(0.03, 0.065, length), Color("#141416"))
			slot.position.x = x
			holder.add_child(slot)
		for x in [-0.66, 0.66]:  # the edges
			var edge := B._box(Vector3(0.06, 0.09, length), Color("#c86a64") if i % 2 == 0 else Color("#e8e6e0"))
			edge.position.x = x
			holder.add_child(edge)
		if p0.y > 0.4 and i % 4 == 0:  # posts under a raised stretch
			_add(B._box(Vector3(0.12, p0.y, 0.12), Color("#b0b0b8")), Vector3(p0.x, p0.y / 2, p0.z))


## A Formula One car `colour`, nose to +x: a slim body and nose cone, the
## cockpit and halo, wide front and rear wings, four open wheels.
func _f1_car(colour: Color) -> Node3D:
	var car := Node3D.new()
	var add := func(node: Node3D, at: Vector3) -> void:
		node.position = at
		car.add_child(node)
	add.call(B._box(Vector3(0.95, 0.09, 0.22), colour), Vector3(0, 0.1, 0))  # the body
	var nose := B._cyl(0.02, 0.07, 0.4, Color.WHITE)
	nose.material_override = B._material(colour)
	nose.rotation.z = -PI / 2
	add.call(nose, Vector3(0.62, 0.09, 0))
	for z in [-0.17, 0.17]:  # sidepods
		add.call(B._box(Vector3(0.45, 0.08, 0.12), colour.darkened(0.15)), Vector3(-0.05, 0.09, z))
	add.call(B._box(Vector3(0.18, 0.07, 0.12), Color("#141418")), Vector3(0.05, 0.17, 0))  # cockpit
	var helmet := _ball(0.045, Color("#f0d020"))
	add.call(helmet, Vector3(0.04, 0.2, 0))
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.075
	halo.mesh = torus
	halo.material_override = B._material(Color("#1a1a1e"))
	halo.scale = Vector3(1.2, 1, 1)
	add.call(halo, Vector3(0.06, 0.22, 0))
	add.call(B._box(Vector3(0.08, 0.02, 0.5), colour.darkened(0.35)), Vector3(0.82, 0.04, 0))  # front wing
	add.call(B._box(Vector3(0.1, 0.03, 0.42), colour.darkened(0.35)), Vector3(-0.5, 0.26, 0))  # rear wing
	for z in [-0.18, 0.18]:
		add.call(B._box(Vector3(0.1, 0.16, 0.02), colour.darkened(0.35)), Vector3(-0.5, 0.18, z))
	for x in [-0.36, 0.42]:
		for z in [-0.24, 0.24]:
			var wheel := B._cyl(0.1, 0.1, 0.1, Color("#141416"))
			wheel.rotation.x = PI / 2
			add.call(wheel, Vector3(x, 0.1, z))
	return car


func _storm() -> void:
	sky = Color("#2a323c")
	ambient = Color("#8e9aa8")
	ambient_energy = 0.36
	sun_color = Color("#c8d0dc")
	sun_energy = 0.45
	fog = 0.012
	# Heavy storm clouds below the board, drifting slowly.
	var dark := textured(Color("#2c3138"), Color("#56606a"), 2.0)
	var mid := textured(Color("#3c434c"), Color("#6c7680"), 2.0)
	for m in [dark, mid]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.93)
	_clouds(26, -6.0, -1.0, [dark, mid], 0.35)
	# A low dark layer far below, so there is never bare sky under the board.
	var floor_m := textured(Color("#1e2228"), Color("#353c44"), 5.0)
	_add(_slab(Vector3(_reach * 9, 0.1, _reach * 9), floor_m), _centre - Vector3(0, 9.0, 0))
	_anims.append(func(t: float): floor_m.uv1_offset = Vector3(t * 0.003, 0, 0))
	# The weather turns every WEATHER_SPELL seconds: rain, then hail, then
	# snow, fading from one to the next.
	var rain_m := B._material(Color(0.78, 0.84, 0.9, 0.35))
	var hail_m := B._material(Color(0.9, 0.94, 1.0, 0.9))
	var snow_m := B._material(Color(1.0, 1.0, 1.0, 0.9))
	for m in [rain_m, hail_m, snow_m]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var kinds := [  # [material, size, fall speed, sway, count]
		[rain_m, Vector3(0.012, 0.45, 0.012), 7.0, 0.0, 170],
		[hail_m, Vector3(0.05, 0.05, 0.05), 5.0, 0.05, 110],
		[snow_m, Vector3(0.05, 0.05, 0.05), 0.9, 0.5, 160],
	]
	for kind in kinds:
		for i in kind[4]:
			var bit := B._box(kind[1], Color.WHITE)
			bit.material_override = kind[0]
			var x := _centre.x + _rng.randf_range(-_reach * 1.6, _reach * 1.6)
			var z := _centre.z + _rng.randf_range(-_reach * 1.6, _reach * 1.2)
			var y0 := _rng.randf() * 10.0
			var phase := _rng.randf() * TAU
			_add(bit, Vector3(x, 0, z))
			var speed: float = kind[2]
			var sway: float = kind[3]
			_anims.append(func(t: float):
				bit.position = Vector3(x + sin(t * 0.8 + phase) * sway, 2.2 - fmod(y0 + t * speed, 10.0), z))
	_anims.append(func(t: float):  # which weather now, crossfading
		var spell := t / WEATHER_SPELL
		var now := int(spell) % 3
		var k := clampf((fmod(spell, 1.0) - 0.85) / 0.15, 0.0, 1.0)  # the last 15% fades to the next
		var alphas := [0.0, 0.0, 0.0]
		alphas[now] = 1.0 - k
		alphas[(now + 1) % 3] = k
		rain_m.albedo_color.a = 0.35 * alphas[0]
		hail_m.albedo_color.a = 0.9 * alphas[1]
		snow_m.albedo_color.a = 0.9 * alphas[2])
	# Lightning flickering inside the clouds now and then.
	var flash := OmniLight3D.new()
	flash.light_color = Color("#dce6ff")
	flash.omni_range = 14.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	_add(flash, _centre)
	var period := 9.0
	var heard := [-1]  # the last flash whose thunder has been played
	_anims.append(func(t: float):
		var cycle := floorf(t / period)
		var phase := fmod(t, period)
		if phase > THUNDER_DELAY and heard[0] != int(cycle):
			heard[0] = int(cycle)
			thunder.emit()
		var r := RandomNumberGenerator.new()
		r.seed = int(cycle) * 4813
		if phase < 0.05:
			flash.position = _centre + Vector3(r.randf_range(-_reach, _reach), -3.5, r.randf_range(-_reach, _reach))
		var e := 0.0
		if phase < 0.08:
			e = 3.0
		elif phase > 0.16 and phase < 0.22:
			e = 2.0
		elif phase < 0.6:
			e = maxf(0.0, 1.2 - phase * 2.0)
		flash.light_energy = e)


# --- pieces ---------------------------------------------------------------

func _add(node: Node3D, at: Vector3) -> Node3D:
	node.position = at
	add_child(node)
	return node


## A box with material `m`.
func _slab(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := B._box(size, Color.WHITE)
	if m:
		mi.material_override = m
	return mi


## A big ground plane under everything.
func _ground(m: Material) -> void:
	_add(_slab(Vector3(_reach * 9, 0.1, _reach * 9), m), _centre - Vector3(0, 0.17, 0))


## A spot outside the board, `out` beyond its edge in direction `angle`.
func _spot(angle: float, out: float) -> Vector3:
	var dir := Vector2.from_angle(angle)
	var edge := minf(_half.x / maxf(absf(dir.x), 0.01), _half.y / maxf(absf(dir.y), 0.01))
	return _centre + Vector3(dir.x, 0, dir.y) * (edge + out)


func _ball(r: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2
	mi.mesh = mesh
	mi.material_override = B._material(colour)
	return mi


## The sea's height at x, z now (the same waves as the shader).
func _wave_height(x: float, z: float) -> float:
	var h := 0.0
	for w in WAVES:
		h += w[0] * wave_scale * sin(x * w[1] + z * w[2] + _time * w[3])
	return h


## How much the sea slopes at x, z: (pitch about x, roll about z).
func _tilt(x: float, z: float) -> Vector2:
	return Vector2((_wave_height(x, z + 0.6) - _wave_height(x, z - 0.6)) * 0.35,
			(_wave_height(x - 0.6, z) - _wave_height(x + 0.6, z)) * 0.35)


## Keeps `node` riding the waves at `at`, turned `heading` about y.
func _float(node: Node3D, at: Vector3, heading: float) -> void:
	_add(node, at)
	_anims.append(func(_t: float):
		var tilt := _tilt(at.x, at.z)
		node.position = Vector3(at.x, _wave_height(at.x, at.z) * 0.7 - 0.15 * node.scale.y, at.z)
		node.rotation = Vector3(tilt.x, heading, tilt.y))


## A three-masted pirate ship, bow to +x: a rounded wooden hull (a long
## capsule, its top cut level by the deck) with a raised stern castle,
## planking, a bowsprit, round gun ports, masts with billowing `sail` sails
## and a crow's nest, a `flag` flag at the top.
func _ship(sail: Color, flag: Color) -> Node3D:
	var ship := Node3D.new()
	var hull_m := textured(Color("#2c1d12"), Color("#54381f"), 0.35)
	var deck_m := textured(Color("#6a4a2c"), Color("#8e6a42"), 0.3)
	var trim := B._material(Color("#a8822a"))
	var add := func(node: Node3D, at: Vector3) -> Node3D:
		node.position = at
		ship.add_child(node)
		return node
	# The hull: a capsule lying along x, flattened into a boat's belly.
	var hull := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.55
	capsule.height = 3.6
	capsule.radial_segments = 24
	capsule.rings = 8
	hull.mesh = capsule
	hull.material_override = hull_m
	hull.rotation.z = PI / 2
	hull.scale = Vector3(0.8, 1, 1)  # shallower than it is wide
	add.call(hull, Vector3(0, 0.15, 0))
	# Bulwarks round the deck, following the hull's curve.
	var deck := _ball(0.5, Color.WHITE)
	deck.material_override = deck_m
	deck.scale = Vector3(3.1, 0.05, 0.92)
	add.call(deck, Vector3(0, 0.56, 0))
	for k in 24:  # the rail, a ring of posts and a band
		var a := TAU * k / 24.0
		var p := Vector3(cos(a) * 1.55, 0.66, sin(a) * 0.46)
		add.call(B._cyl(0.02, 0.02, 0.16, Color("#3a2614")), p)
	var band := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.98
	torus.outer_radius = 1.02
	band.mesh = torus
	band.material_override = trim
	band.scale = Vector3(1.55, 1, 0.47)
	add.call(band, Vector3(0, 0.73, 0))
	# The stern castle: a rounded block on the stern with gold trim and windows.
	var castle := _ball(0.5, Color.WHITE)
	castle.material_override = hull_m
	castle.scale = Vector3(0.9, 0.7, 0.95)
	add.call(castle, Vector3(-1.35, 0.75, 0))
	for z in [-0.18, 0.0, 0.18]:
		var window := _ball(0.05, Color.WHITE)
		window.material_override = B._material(Color("#ffd880"), 0.8)
		add.call(window, Vector3(-1.78, 0.8, z))
	# Round gun ports along both sides.
	for k in 6:
		for side in [-1, 1]:
			var port := B._cyl(0.06, 0.06, 0.02, Color("#0c0806"))
			port.rotation.x = PI / 2
			add.call(port, Vector3(-0.9 + k * 0.38, 0.32, side * 0.5))
	# The bowsprit, raking forward.
	var sprit := B._cyl(0.02, 0.035, 1.2, Color.WHITE)
	sprit.material_override = hull_m
	sprit.rotation.z = -1.2
	add.call(sprit, Vector3(2.15, 0.75, 0))
	# Masts, yards and billowing sails; a crow's nest on the main mast.
	for k in 3:
		var x: float = [-0.65, 0.35, 1.25][k]
		var h: float = [1.35, 1.55, 1.15][k]  # short, so a big ship stays under the board
		var mast := B._cyl(0.035, 0.05, h, Color.WHITE)
		mast.material_override = hull_m
		add.call(mast, Vector3(x, 0.56 + h / 2, 0))
		for s in 2:
			var tall := h * 0.32
			var sail_m := textured(sail.darkened(0.12), sail, 0.6)
			var cloth := _ball(0.5, Color.WHITE)  # half a flattened ball: a sail filled with wind
			cloth.material_override = sail_m
			cloth.scale = Vector3(0.22, tall, 0.95 - s * 0.18)
			add.call(cloth, Vector3(x + 0.06, 0.56 + h * (0.42 + s * 0.33), 0))
			var yard := B._cyl(0.018, 0.018, 1.0 - s * 0.18, Color.WHITE)
			yard.material_override = hull_m
			yard.rotation.x = PI / 2
			add.call(yard, Vector3(x, 0.56 + h * (0.42 + s * 0.33) + tall / 2, 0))
		if k == 1:
			add.call(B._cyl(0.12, 0.09, 0.1, Color("#3a2614")), Vector3(x, 0.56 + h * 0.97, 0))
	var pennant := Node3D.new()
	add.call(pennant, Vector3(0.38, 2.14, 0))
	var cloth := B._box(Vector3(0.4, 0.22, 0.02), flag)
	cloth.position.x = -0.2
	pennant.add_child(cloth)
	return ship


## One fish leaping out of the still water every now and then (10 to 20
## seconds apart), somewhere new round the board each time, with a splash
## where it goes in.
func _leaping_fish() -> void:
	var fish := _fish(Color("#c0c8d0"))
	fish.scale = Vector3.ONE * 2.2  # big enough to see from up here
	_add(fish, _centre)
	fish.visible = false
	var splash := _ball(0.5, Color(0.92, 0.97, 1.0))
	_add(splash, _centre)
	splash.visible = false
	var leap := 1.1  # seconds in the air
	# Kept in a dictionary: a lambda's captured locals are copies, so plain
	# variables would be back to their first values on the next frame.
	var first := _rng.randf() * TAU
	var jump := {"start": _rng.randf_range(4.0, 10.0), "at": _centre + Vector3(cos(first), 0, sin(first) * 0.8) * _reach * 0.9,
		"way": Vector3(sin(first + 1.2), 0, cos(first + 1.2)),
		"length": 3.0, "high": 1.6}
	_anims.append(func(t: float):
		var k: float = t - float(jump.start)
		if k > leap + 0.6:  # done: the next one, later and somewhere else
			jump.start = t + _rng.randf_range(10.0, 20.0)
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(_reach * 0.55, _reach * 1.3)
			jump.at = _centre + Vector3(cos(a) * r, 0, sin(a) * r * 0.8)
			var turn := _rng.randf() * TAU
			jump.way = Vector3(sin(turn), 0, cos(turn))
			jump.length = _rng.randf_range(2.4, 3.6)
			jump.high = _rng.randf_range(1.2, 2.0)
			k = t - float(jump.start)
		var at: Vector3 = jump.at
		var way: Vector3 = jump.way
		var length: float = jump.length
		fish.visible = k >= 0.0 and k < leap
		if fish.visible:
			var u := k / leap
			var p := at + way * (u - 0.5) * length
			fish.position = Vector3(p.x, _wave_height(p.x, p.z) - 0.1 + sin(u * PI) * float(jump.high), p.z)
			fish.rotation = Vector3(-(1.0 - 2.0 * u) * 1.1, atan2(way.x, way.z), 0)
		var s := k - leap  # the splash, spreading as it fades after going in
		splash.visible = s >= -leap * 0.15 and s < 0.5
		if splash.visible:
			var e := at + way * length * 0.5
			var g := clampf((s + leap * 0.15) / 0.65, 0.0, 1.0)
			splash.position = Vector3(e.x, _wave_height(e.x, e.z) + 0.02, e.z)
			splash.scale = Vector3(0.4 + g * 1.4, 0.08 * (1.0 - g), 0.4 + g * 1.4))


## A fish facing +z in `colour`: a long body, a paler belly, a forked tail.
func _fish(colour: Color) -> Node3D:
	var fish := Node3D.new()
	var body := _ball(0.18, colour)
	body.scale = Vector3(0.45, 0.8, 1.6)
	fish.add_child(body)
	var belly := _ball(0.15, colour.lightened(0.45))
	belly.scale = Vector3(0.4, 0.5, 1.4)
	belly.position.y = -0.04
	fish.add_child(belly)
	for side in [-1, 1]:  # the forked tail
		var lobe := B._box(Vector3(0.02, 0.16, 0.14), colour.darkened(0.15))
		lobe.position = Vector3(0, side * 0.06, -0.33)
		lobe.rotation.x = side * 0.5
		fish.add_child(lobe)
	return fish


## A seagull flying towards +z: a white body and head, a yellow beak, and two
## grey-tipped wings on hinges (its metas "left" and "right") so they flap.
func _seagull() -> Node3D:
	var gull := Node3D.new()
	var body := _ball(0.12, Color("#f4f4f2"))
	body.scale = Vector3(0.8, 0.7, 1.6)
	gull.add_child(body)
	var head := _ball(0.07, Color("#f8f8f6"))
	head.position = Vector3(0, 0.05, 0.2)
	gull.add_child(head)
	var beak := B._cyl(0.0, 0.025, 0.08, Color("#e8b020"))
	beak.rotation.x = PI / 2
	beak.position = Vector3(0, 0.04, 0.29)
	gull.add_child(beak)
	for side in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.06, 0.03, 0)
		gull.add_child(hinge)
		var wing := B._box(Vector3(0.38, 0.015, 0.14), Color("#e8e8ea"))
		wing.position.x = side * 0.19
		hinge.add_child(wing)
		var tip := B._box(Vector3(0.1, 0.016, 0.12), Color("#3a3a40"))
		tip.position.x = side * 0.36
		hinge.add_child(tip)
		gull.set_meta("left" if side < 0 else "right", hinge)
	return gull


## `from` fires at `to` every `period` seconds, starting `offset` in: a flash
## at its side, a puff of smoke drifting off, a ball arcing over, a splash
## beside the target.
func _cannon_fire(from: Node3D, to: Node3D, offset: float, period: float) -> void:
	var flash := _ball(0.25, Color.WHITE)
	flash.material_override = B._material(Color("#ffd080"), 3.0)
	var smoke := _ball(0.4, Color.WHITE)
	var smoke_m := B._material(Color(0.75, 0.75, 0.72, 0.0))
	smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smoke_m
	var ball := _ball(0.07, Color("#151515"))
	var splash := B._cyl(0.12, 0.25, 1.0, Color.WHITE)
	var splash_m := B._material(Color(0.9, 0.95, 0.97, 0.8))
	splash_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splash.material_override = splash_m
	for n in [flash, smoke, ball, splash]:
		add_child(n)
		n.visible = false
	_anims.append(func(t: float):
		var phase := fmod(t + offset, period)
		var toward := (to.position - from.position)
		toward.y = 0
		var muzzle := from.position + toward.normalized() * 0.55 * from.scale.x + Vector3(0, 0.35 * from.scale.x, 0)
		var target := to.position - toward.normalized() * 1.0 * to.scale.x
		flash.visible = phase < 0.12
		flash.position = muzzle
		smoke.visible = phase < 3.0
		if smoke.visible:
			smoke.position = muzzle + Vector3(0, phase * 0.25, 0) + toward.normalized() * phase * 0.2
			smoke.scale = Vector3.ONE * (0.6 + phase * 0.8)
			smoke_m.albedo_color.a = 0.7 * (1.0 - phase / 3.0)
		ball.visible = phase < 1.2
		if ball.visible:
			var k := phase / 1.2
			ball.position = muzzle.lerp(target, k) + Vector3(0, sin(k * PI) * 2.0, 0)
		splash.visible = phase > 1.2 and phase < 2.0
		if splash.visible:
			var k := (phase - 1.2) / 0.8
			splash.position = Vector3(target.x, 0.2 + sin(k * PI) * 0.4, target.z)
			splash.scale = Vector3(1, sin(k * PI) + 0.01, 1))


## A planet `r` across between two shades, turning slowly; `ringed` gives it a
## ring.
func _planet(at: Vector3, r: float, dark: Color, light: Color, ringed: bool, spin: float) -> MeshInstance3D:
	var planet := _ball(r, Color.WHITE)
	planet.material_override = textured(dark, light, r * 0.7)
	_add(planet, at)
	if ringed:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r * 1.3
		torus.outer_radius = r * 1.65
		ring.mesh = torus
		var ring_m := textured(Color("#8a7a5a"), Color("#d0c098"), 1.0)
		ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_m.albedo_color = Color(1, 1, 1, 0.7)
		ring.material_override = ring_m
		ring.scale = Vector3(1, 0.03, 1)
		ring.rotation = Vector3(0.4, 0, 0.25)
		planet.add_child(ring)
	_anims.append(func(t: float): planet.rotation.y = t * spin)
	return planet


## A stone curtain wall from `a` to `b` (offsets from the board's centre),
## `height` tall and `thick` thick, with battlements along its top.
func _wall(a: Vector3, b: Vector3, height: float, thick: float, m: Material) -> void:
	var length := a.distance_to(b)
	var wall := _add(_slab(Vector3(thick, height, length), m), _centre + (a + b) / 2 + Vector3(0, height / 2 - 0.05, 0))
	wall.rotation.y = atan2(b.x - a.x, b.z - a.z)
	_battlements(_centre + a + Vector3(0, height, 0), _centre + b + Vector3(0, height, 0), m)


## Merlons along a wall top from `a` to `b`.
func _battlements(a: Vector3, b: Vector3, m: Material) -> void:
	var dir := (b - a).normalized()
	for k in int(a.distance_to(b) / 0.7):
		var merlon := _add(_slab(Vector3(0.6, 0.45, 0.4), m), a + dir * (0.35 + k * 0.7) + Vector3(0, 0.2, 0))
		merlon.rotation.y = atan2(dir.x, dir.z)


## A square tower `size` across standing on `base`, `height` tall, with
## battlements and arrow slits.
func _square_tower(base: Vector3, size: float, height: float, m: Material) -> void:
	_add(_slab(Vector3(size, height, size), m), base + Vector3(0, height / 2, 0))
	var h := size / 2
	for edge in [[Vector3(-h, 0, -h), Vector3(h, 0, -h)], [Vector3(-h, 0, h), Vector3(h, 0, h)],
			[Vector3(-h, 0, -h), Vector3(-h, 0, h)], [Vector3(h, 0, -h), Vector3(h, 0, h)]]:
		_battlements(base + edge[0] + Vector3(0, height, 0), base + edge[1] + Vector3(0, height, 0), m)
	for y in range(1, int(height / 1.6)):
		for face in [Vector3(0, 0, h + 0.01), Vector3(h + 0.01, 0, 0), Vector3(-h - 0.01, 0, 0)]:
			_add(B._box(Vector3(0.08, 0.5, 0.08), Color("#141210")), base + face + Vector3(0, y * 1.6, 0))


## A flag on a pole standing on `top`, stirring in the wind.
func _flag(top: Vector3, colour: Color) -> void:
	_add(B._box(Vector3(0.06, 1.6, 0.06), Color("#8a8a90")), top + Vector3(0, 0.8, 0))
	var flag := Node3D.new()
	_add(flag, top + Vector3(0.03, 1.35, 0))
	var cloth := B._box(Vector3(1.0, 0.6, 0.02), colour)
	cloth.position.x = 0.5
	flag.add_child(cloth)
	var phase := _rng.randf() * TAU
	_anims.append(func(t: float): flag.rotation.y = sin(t * 1.4 + phase) * 0.25)


## A wooden catapult on wheels, throwing towards -z: a frame, uprights, and
## an arm with a sling cup (its meta "arm", pivoted to swing about x).
func _catapult() -> Node3D:
	var cat := Node3D.new()
	var wood := textured(Color("#4a3420"), Color("#6e5034"), 0.4)
	for x in [-0.3, 0.3]:
		var rail := _slab(Vector3(0.1, 0.12, 1.4), wood)
		rail.position = Vector3(x, 0.2, 0)
		cat.add_child(rail)
		var post := _slab(Vector3(0.1, 0.8, 0.1), wood)
		post.position = Vector3(x, 0.6, -0.2)
		cat.add_child(post)
		for z in [-0.55, 0.55]:
			var wheel := B._cyl(0.17, 0.17, 0.06, Color.WHITE)
			wheel.material_override = wood
			wheel.rotation.z = PI / 2
			wheel.position = Vector3(x * 1.25, 0.17, z)
			cat.add_child(wheel)
	var cross := _slab(Vector3(0.7, 0.1, 0.1), wood)
	cross.position = Vector3(0, 0.95, -0.2)
	cat.add_child(cross)
	var arm := Node3D.new()
	arm.position = Vector3(0, 0.45, 0.1)
	cat.add_child(arm)
	var beam := _slab(Vector3(0.08, 0.08, 1.2), wood)
	beam.position.z = 0.5
	arm.add_child(beam)
	var cup := B._cyl(0.14, 0.08, 0.1, Color("#3a2a1a"))
	cup.position = Vector3(0, 0.05, 1.1)
	arm.add_child(cup)
	var stone := _ball(0.1, Color("#6a6660"))
	stone.position = Vector3(0, 0.14, 1.1)
	arm.add_child(stone)
	arm.rotation.x = -1.1
	cat.set_meta("arm", arm)
	return cat


## A great army drawn up outside the castle's back gate, filling the ground
## from the moat to the keep: ranks of soldiers with spears and shields in
## companies of their own colours, an aisle up the middle to the drawbridge,
## standard bearers and knights on horseback at the front, siege cannons,
## tents at the back. Standard flags stir; everyone else stands.
func _army(hx: float, hz: float) -> void:
	var companies := [Color("#2a4a8a"), Color("#4a6a2a"), Color("#6a2a6a"), Color("#8a6a1a")]
	var canvas := textured(Color("#b8ac90"), Color("#d8ccb0"), 0.6)
	var gate := _centre + Vector3(0, 0, -hz)
	# The drawbridge across the moat.
	_add(_slab(Vector3(1.6, 0.1, 2.6), textured(Color("#4a3420"), Color("#6e5034"), 0.5)), gate + Vector3(0, -0.04, -2.2))
	var front := -hz - 3.8
	var width := hx + 3.0
	var rows := 9
	var spots: Array = []  # [position, company colour]
	for row in rows:
		var z := front - row * (ARMY_DEPTH / rows)
		var x := -width
		while x <= width:
			if absf(x) > 1.0:  # leave the aisle to the gate clear
				var colour: Color = companies[int((x + width) / (width * 2.0) * companies.size()) % companies.size()]
				spots.append([_centre + Vector3(x + (row % 2) * 0.25, 0, z), colour])
			x += 0.55
	_ranks(spots)
	# At the front: standard bearers and knights on horseback either side of the aisle.
	for side in [-1, 1]:
		for k in 3:
			var at := _centre + Vector3(side * (1.6 + k * 2.4), 0, front + 1.0)
			_add(_knight(companies[k % companies.size()]), at)
			var pole := at + Vector3(side * 0.7, 0, 0)
			_add(B._cyl(0.02, 0.02, 2.4, Color("#5a3a1a")), pole + Vector3(0, 1.2, 0))
			var flag := Node3D.new()
			_add(flag, pole + Vector3(0.02, 2.15, 0))
			var cloth := B._box(Vector3(0.8, 0.5, 0.02), companies[k % companies.size()])
			cloth.position.x = 0.4
			flag.add_child(cloth)
			var phase := _rng.randf() * TAU
			_anims.append(func(t: float): flag.rotation.y = sin(t * 1.3 + phase) * 0.25)
		for k in 2:  # siege cannons aimed at the gate
			var cannon := _cannon()
			cannon.scale = Vector3.ONE * 1.5
			_add(cannon, _centre + Vector3(side * (2.6 + k * 4.0), 0, front + 0.3))
	# Tents at the back of the camp.
	for k in 9:
		var tent := B._cyl(0.0, 0.9, 1.4, Color.WHITE)
		(tent.mesh as CylinderMesh).radial_segments = 8
		tent.material_override = canvas
		var x := lerpf(-width, width, k / 8.0)
		if absf(x) < 2.5:
			continue
		_add(tent, _centre + Vector3(x, 0.7, front - ARMY_DEPTH - 0.8))


## Foot soldiers standing at `spots` ([position, tabard colour] each), facing
## the castle: drawn as one MultiMesh per body part (legs, body, arms, head,
## helmet, spear, its tip, shield), each soldier one instance coloured as it
## should be, so hundreds of them cost only a few draws.
func _ranks(spots: Array) -> void:
	const S := 1.4  # the same size as the figures elsewhere
	var skin := Color("#f1c9a5")
	var parts := [  # [mesh, offset, colour ("tabard" = the soldier's), scale]
		[_capsule(0.035, 0.2), Vector3(-0.045, 0.1, 0), Color("#2f3140"), Vector3.ONE],
		[_capsule(0.035, 0.2), Vector3(0.045, 0.1, 0), Color("#2f3140"), Vector3.ONE],
		[_capsule(0.085, 0.24), Vector3(0, 0.3, 0), "tabard", Vector3.ONE],
		[_capsule(0.028, 0.18), Vector3(-0.11, 0.31, 0), "tabard", Vector3.ONE],
		[_capsule(0.028, 0.18), Vector3(0.11, 0.31, 0), "tabard", Vector3.ONE],
		[_sphere(0.065), Vector3(0, 0.47, 0), skin, Vector3.ONE],
		[_sphere(0.088), Vector3(0, 0.545, 0), Color("#7a7a82"), Vector3(1, 0.8, 1)],
		[_rod(0.008, 0.008, 0.8), Vector3(0.14, 0.45, 0), Color("#6a4a2a"), Vector3.ONE],
		[_rod(0.0, 0.02, 0.07), Vector3(0.14, 0.88, 0), Color("#c0c0c8"), Vector3.ONE],
		[_rod(0.09, 0.09, 0.02), Vector3(-0.12, 0.32, 0.06), "shield", Vector3.ONE],
	]
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = part[0]
		mm.instance_count = spots.size()
		var turn := Basis(Vector3.RIGHT, PI / 2) if part[2] is String and part[2] == "shield" else Basis.IDENTITY
		for i in spots.size():
			var at: Vector3 = spots[i][0]
			mm.set_instance_transform(i, Transform3D(turn.scaled(part[3] * S), at + part[1] * S))
			var c: Color = part[2] if part[2] is Color else (spots[i][1] as Color).lightened(0.3 if part[2] == "shield" else 0.0)
			mm.set_instance_color(i, c)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.disable_receive_shadows = true
		mmi.material_override = m
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 2
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 10
	s.rings = 5
	return s


func _rod(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 8
	return c


## A knight on a horse, facing the castle (+z): a brown horse with legs, neck
## and head, a rider in `colour` with a helmet and lance.
func _knight(colour: Color) -> Node3D:
	var knight := Node3D.new()
	var hide := Color("#5a3a22")
	var body := _ball(0.5, hide)
	body.scale = Vector3(0.45, 0.4, 1.0)
	body.position.y = 0.75
	knight.add_child(body)
	for x in [-0.13, 0.13]:
		for z in [-0.3, 0.3]:
			var leg := B._box(Vector3(0.08, 0.6, 0.08), hide.darkened(0.2))
			leg.position = Vector3(x, 0.3, z)
			knight.add_child(leg)
	var neck := B._box(Vector3(0.14, 0.45, 0.16), hide)
	neck.position = Vector3(0, 1.05, 0.45)
	neck.rotation.x = 0.5
	knight.add_child(neck)
	var head := B._box(Vector3(0.14, 0.16, 0.34), hide)
	head.position = Vector3(0, 1.25, 0.62)
	knight.add_child(head)
	var cloth := B._box(Vector3(0.5, 0.25, 0.7), colour)  # its caparison
	cloth.position.y = 0.72
	knight.add_child(cloth)
	var rider := Character.new()
	rider.setup(colour)
	rider.scale = Vector3.ONE * 1.4
	rider.position.y = 0.8
	knight.add_child(rider)
	var helmet := _ball(0.09, Color("#9a9aa2"))
	helmet.position.y = 0.8 + 0.545 * 1.4
	knight.add_child(helmet)
	var lance := B._cyl(0.012, 0.02, 1.8, Color("#c8b890"))
	lance.position = Vector3(0.22, 1.7, 0)
	knight.add_child(lance)
	return knight


## A cannon on a wheeled carriage, its barrel pointing to +z.
func _cannon() -> Node3D:
	var cannon := Node3D.new()
	var wood := textured(Color("#3a2818"), Color("#5c4028"), 0.4)
	var carriage := _slab(Vector3(0.4, 0.2, 0.6), wood)
	carriage.position.y = 0.2
	cannon.add_child(carriage)
	for x in [-0.23, 0.23]:
		for z in [-0.18, 0.18]:
			var wheel := B._cyl(0.12, 0.12, 0.05, Color.WHITE)
			wheel.material_override = wood
			wheel.rotation.z = PI / 2
			wheel.position = Vector3(x, 0.12, z)
			cannon.add_child(wheel)
	var barrel := B._cyl(0.07, 0.1, 0.8, Color("#26262a"))
	barrel.rotation.x = PI / 2 - 0.1
	barrel.position = Vector3(0, 0.38, 0.2)
	cannon.add_child(barrel)
	return cannon


## Now and then one of `cannons` fires: a flash at its muzzle and a puff of
## smoke drifting away, roughly every `period` seconds.
func _volleys(cannons: Array[Node3D], period: float) -> void:
	var flash := _ball(0.2, Color.WHITE)
	flash.material_override = B._material(Color("#ffd080"), 3.0)
	var smoke := _ball(0.35, Color.WHITE)
	var smoke_m := B._material(Color(0.78, 0.78, 0.75, 0.0))
	smoke_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smoke_m
	add_child(flash)
	add_child(smoke)
	_anims.append(func(t: float):
		var cycle := int(t / period)
		var phase := fmod(t, period)
		var gun: Node3D = cannons[cycle % cannons.size()]
		var muzzle := gun.position + gun.basis.z * 0.65 + Vector3(0, 0.45, 0)
		flash.visible = phase < 0.1
		flash.position = muzzle
		smoke.visible = phase < 2.5
		if smoke.visible:
			smoke.position = muzzle + gun.basis.z * phase * 0.3 + Vector3(0, phase * 0.3, 0)
			smoke.scale = Vector3.ONE * (0.5 + phase * 0.7)
			smoke_m.albedo_color.a = 0.6 * (1.0 - phase / 2.5))


## A soldier walking up and down a wall walk between `a` and `b`: a figure
## with a red tabard, a helmet and a spear.
func _soldier(a: Vector3, b: Vector3, k: int) -> void:
	var soldier := Character.new()
	soldier.setup(Color("#8e2420"))
	soldier.scale = Vector3.ONE * 1.4
	var helmet := _ball(0.088, Color("#8a8a90"))  # wholly over the cap, so they don't flicker
	helmet.scale = Vector3(1, 0.8, 1)
	helmet.position.y = 0.545
	soldier.add_child(helmet)
	var spear := B._cyl(0.008, 0.008, 0.7, Color("#6a4a2a"))
	spear.position = Vector3(0.14, 0.4, 0)
	soldier.add_child(spear)
	var tip := B._cyl(0.0, 0.02, 0.07, Color("#b8b8c0"))
	tip.position = Vector3(0.14, 0.78, 0)
	soldier.add_child(tip)
	_add(soldier, a)
	soldier.set("_walking", true)
	var length := a.distance_to(b)
	var speed := 0.35
	var offset := k * 3.0
	_anims.append(func(t: float):
		var d := fmod(t * speed + offset, length * 2.0)
		var going := d < length
		var k2 := d / length if going else 2.0 - d / length
		soldier.position = a.lerp(b, k2)
		var dir := (b - a) if going else (a - b)
		soldier.rotation.y = atan2(dir.x, dir.z))


## A tree, `size` times the usual: a pine (stacked cones) or a broadleaf (a few
## overlapping leafy crowns), its foliage stirring slightly.
func _tree(at: Vector3, size: float) -> void:
	var bark := textured(Color("#3a2a1c"), Color("#5c4430"), 0.4)
	var leaves := textured(Color("#1f4a24"), Color("#3c7038"), 1.2) if _rng.randf() < 0.6 \
			else textured(Color("#1a3a22"), Color("#2e5a34"), 1.2)
	var crown := Node3D.new()
	if _rng.randf() < 0.4:  # a pine
		_add(_slab(Vector3(0.14, 0.6, 0.14) * size, bark), at + Vector3(0, 0.25 * size, 0))
		_add(crown, at + Vector3(0, 0.45 * size, 0))
		for k in 3:
			var cone := B._cyl(0.0, (0.6 - k * 0.15) * size, 0.8 * size, Color.WHITE)
			cone.material_override = leaves
			cone.position.y = (0.35 + k * 0.4) * size
			crown.add_child(cone)
	else:  # a broadleaf
		_add(_slab(Vector3(0.16, 0.9, 0.16) * size, bark), at + Vector3(0, 0.3 * size, 0))
		_add(crown, at + Vector3(0, 1.0 * size, 0))
		for k in 3:
			var puff := _ball((0.42 - k * 0.04) * size, Color.WHITE)
			puff.material_override = leaves
			puff.position = Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.05, 0.25), _rng.randf_range(-0.2, 0.2)) * size
			crown.add_child(puff)
	var phase := _rng.randf() * TAU
	_anims.append(func(t: float): crown.rotation.z = sin(t * 0.7 + phase) * 0.015)


## `count` clouds drifting slowly across, between heights `low` and `high`,
## wrapping round when they drift too far; puffs share `materials` in turn.
func _clouds(count: int, low: float, high: float, materials: Array, speed_scale := 1.0) -> void:
	var span := _reach * 6.0
	for i in count:
		var cloud := Node3D.new()
		for k in _rng.randi_range(5, 9):
			var puff := _ball(_rng.randf_range(0.8, 1.7), Color.WHITE)
			puff.material_override = materials[k % materials.size()]
			puff.scale = Vector3(1.3, 0.6, 1)
			puff.position = Vector3(k * 0.85 - 3.0, _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.8, 0.8))
			cloud.add_child(puff)
		var z := _centre.z + _rng.randf_range(-span / 2, span / 3)
		var y := _rng.randf_range(low, high)
		var x0 := _rng.randf_range(0, span)
		var speed := _rng.randf_range(0.1, 0.22) * speed_scale
		_add(cloud, Vector3.ZERO)
		var left := _centre.x - span / 2
		_anims.append(func(t: float):
			cloud.position = Vector3(left + fmod(x0 + t * speed, span), y, z))
