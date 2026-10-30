class_name Character
extends Node3D
## A placeholder walking figure built from primitives: head, body, two arms and
## two legs that swing while walk_to() is moving it, celebrate() for paydays
## and punch() for hitting the dice block. It wears one of the LOOKS (the
## placeholder characters picked at the start of a game) in its player's
## colour: a build, a skin tone, trousers and something on its head.

const HEIGHT := 0.5
const STRIDE_SPEED := 14.0  # radians of swing phase per second
const SWING := 0.7          # max limb swing, radians
const SKIN := Color("#f1c9a5")
const TROUSERS := Color("#2f3140")
## The characters: id -> name, a line about them, skin, trousers, build
## (width, height) and headwear (hat) in its own colour (hat_color).
const LOOKS := {
	"max": {"name": "Max", "line": "Cap on backwards, always in a hurry", "skin": Color("#f1c9a5"),
			"trousers": Color("#2f3140"), "build": Vector2(1.0, 1.0), "hat": "cap", "hat_color": Color("#2a2a30")},
	"lulu": {"name": "Lulu", "line": "Small, quick and never without her bow", "skin": Color("#e8b890"),
			"trousers": Color("#4a3a6a"), "build": Vector2(0.95, 0.85), "hat": "bow", "hat_color": Color("#ff5a9a")},
	"duke": {"name": "Duke", "line": "Tall, top-hatted and terribly rich (he says)", "skin": Color("#f4d8c0"),
			"trousers": Color("#1a1a20"), "build": Vector2(0.9, 1.15), "hat": "tophat", "hat_color": Color("#18181c")},
	"rosa": {"name": "Rosa", "line": "Bobble hat, big ideas", "skin": Color("#c88a5a"),
			"trousers": Color("#3a5a8a"), "build": Vector2(1.0, 0.95), "hat": "beanie", "hat_color": Color("#f0f0ec")},
	"tex": {"name": "Tex", "line": "Rides into every deal like it's the last", "skin": Color("#d8a070"),
			"trousers": Color("#3a5070"), "build": Vector2(1.05, 1.05), "hat": "cowboy", "hat_color": Color("#8a5a2a")},
	"zip": {"name": "Zip", "line": "Helmet on, wheels ready, slim and speedy", "skin": Color("#8a5a3a"),
			"trousers": Color("#202830"), "build": Vector2(0.85, 1.05), "hat": "helmet", "hat_color": Color("#e8e8ee")},
	"bo": {"name": "Chef Bo", "line": "Cooks up a bargain, tall hat and all", "skin": Color("#f0c8a0"),
			"trousers": Color("#2a2a2a"), "build": Vector2(1.2, 0.95), "hat": "chef", "hat_color": Color("#f8f8f4")},
	"gus": {"name": "Gus", "line": "Stout, crowned, king of the street (in his head)", "skin": Color("#6a4028"),
			"trousers": Color("#4a2a2a"), "build": Vector2(1.25, 0.9), "hat": "crown", "hat_color": Color("#f2bf2a")},
}
const LOOK_ORDER := ["max", "lulu", "duke", "rosa", "tex", "zip", "bo", "gus"]
const CELEBRATE_SECONDS := 1.8
const BID_SECONDS := 0.6
const PUNCH_SECONDS := 0.45
const PUNCH_IMPACT := 0.15  # seconds into a punch when the fist is highest

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _body: Node3D
var _phase := 0.0
var _walking := false
var _celebrating := 0.0  # seconds of celebration left
var _bidding := 0.0      # seconds of a bid reaction left
var _punching := 0.0     # seconds of a punch left


func setup(color: Color, look := "max") -> void:
	var l: Dictionary = LOOKS.get(look, LOOKS.max)
	_body = Node3D.new()
	add_child(_body)
	_body.scale = Vector3(l.build.x, l.build.y, l.build.x)
	var torso := _part(CapsuleMesh.new(), color)
	torso.mesh.radius = 0.085
	torso.mesh.height = 0.24
	torso.position.y = 0.3
	_body.add_child(torso)
	var head := _part(SphereMesh.new(), l.skin)
	head.mesh.radius = 0.065
	head.mesh.height = 0.13
	head.position.y = 0.47
	_body.add_child(head)
	_hat(l.hat, l.hat_color, color)
	var nose := _part(SphereMesh.new(), (l.skin as Color).darkened(0.1))
	nose.mesh.radius = 0.018
	nose.mesh.height = 0.036
	nose.position = Vector3(0, 0.47, 0.065)  # faces +z, the way it walks
	_body.add_child(nose)
	for side in [-1, 1]:
		_legs.append(_limb(Vector3(0.045 * side, 0.2, 0), 0.2, 0.035, l.trousers))
		_arms.append(_limb(Vector3(0.11 * side, 0.4, 0), 0.18, 0.028, color))


## Walks to `target` over `seconds`, turning to face the way it goes. `up` is
## the way up where it is going (a 3D board's wall spaces stand sideways).
func walk_to(target: Vector3, seconds: float, up := Vector3.UP) -> void:
	var dir := target - position
	dir -= up * dir.dot(up)
	if up.is_equal_approx(Vector3.UP):
		if dir.length() > 0.01:
			rotation = Vector3(0, atan2(dir.x, dir.z), 0)
	else:
		stand(up, dir if dir.length() > 0.01 else -basis.y)
	_walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, seconds)
	tw.tween_callback(func(): _walking = false)


## Stands with its head towards `up`, facing `forward` (both world directions).
func stand(up: Vector3, forward: Vector3) -> void:
	var fwd := (forward - up * forward.dot(up)).normalized()
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.DOWN
	basis = Basis(up.cross(fwd), up, fwd)


## Arms up, waving, and a few hops, facing the camera.
func celebrate() -> void:
	_celebrating = CELEBRATE_SECONDS
	rotation.y = 0.0


## A bid at an auction: one arm shoots up with a little hop.
func bid() -> void:
	_bidding = BID_SECONDS


## Punches the dice block over its head: a jump with one fist thrust straight
## up, highest at PUNCH_IMPACT, facing the camera.
func punch() -> void:
	_punching = PUNCH_SECONDS
	rotation.y = 0.0


func _process(delta: float) -> void:
	if _punching > 0.0:
		_punching -= delta
		var t := PUNCH_SECONDS - _punching
		# Up fast to the hit, then back down over the rest.
		var k := t / PUNCH_IMPACT if t < PUNCH_IMPACT else clampf(1.0 - (t - PUNCH_IMPACT) / (PUNCH_SECONDS - PUNCH_IMPACT), 0.0, 1.0)
		_arms[1].rotation.x = -3.1 * k
		_arms[0].rotation.x = 0.5 * k
		_legs[0].rotation.x = -0.3 * k
		_legs[1].rotation.x = 0.2 * k
		_body.position.y = k * 0.2
		return
	if _bidding > 0.0 and _celebrating <= 0.0:
		_bidding -= delta
		var k := sin(PI * clampf(1.0 - _bidding / BID_SECONDS, 0.0, 1.0))  # up and back down
		_arms[1].rotation.x = -2.9 * k
		_arms[0].rotation.x = 0.3 * k
		_body.position.y = k * 0.09
		return
	if _celebrating > 0.0:
		_celebrating -= delta
		var t := CELEBRATE_SECONDS - _celebrating
		var wave := sin(t * 18.0) * 0.35
		_arms[0].rotation.x = -2.7 + wave
		_arms[1].rotation.x = -2.7 - wave
		_legs[0].rotation.x = 0.0
		_legs[1].rotation.x = 0.0
		_body.position.y = absf(sin(t * 7.0)) * 0.16
		return
	if _walking:
		_phase += delta * STRIDE_SPEED
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 10.0))
	var swing := sin(_phase) * SWING
	_legs[0].rotation.x = swing
	_legs[1].rotation.x = -swing
	_arms[0].rotation.x = -swing
	_arms[1].rotation.x = swing
	_body.position.y = absf(sin(_phase)) * 0.025


## The headwear `kind` in `colour` on top of the head (`band`: the player's
## colour, for a hatband or bobble).
func _hat(kind: String, colour: Color, band: Color) -> void:
	var add := func(mesh: PrimitiveMesh, c: Color, at: Vector3) -> MeshInstance3D:
		var m := _part(mesh, c)
		m.position = at
		_body.add_child(m)
		return m
	match kind:
		"cap":  # a baseball cap, peak at the back
			add.call(_dome(0.07), colour, Vector3(0, 0.49, 0))
			var peak: MeshInstance3D = add.call(_flat(0.05, 0.012), band, Vector3(0, 0.505, -0.075))
			peak.scale = Vector3(1.1, 1, 0.9)
		"bow":  # a big hair bow on top
			for side in [-1, 1]:
				var loop: MeshInstance3D = add.call(_ball(0.04), colour, Vector3(side * 0.045, 0.54, 0))
				loop.scale = Vector3(1.2, 0.8, 0.5)
			add.call(_ball(0.018), colour.darkened(0.2), Vector3(0, 0.54, 0))
		"tophat":
			add.call(_flat(0.09, 0.012), colour, Vector3(0, 0.525, 0))
			add.call(_flat(0.055, 0.13), colour, Vector3(0, 0.595, 0))
			add.call(_flat(0.057, 0.02), band, Vector3(0, 0.545, 0))
		"beanie":  # a woolly hat with a bobble in the player's colour
			add.call(_dome(0.07), colour, Vector3(0, 0.49, 0))
			add.call(_flat(0.071, 0.025), colour.darkened(0.15), Vector3(0, 0.495, 0))
			add.call(_ball(0.025), band, Vector3(0, 0.57, 0))
		"cowboy":
			var brim: MeshInstance3D = add.call(_flat(0.12, 0.01), colour, Vector3(0, 0.52, 0))
			brim.scale = Vector3(1, 1, 0.8)
			add.call(_flat(0.055, 0.08), colour, Vector3(0, 0.56, 0))
			add.call(_flat(0.057, 0.015), band, Vector3(0, 0.53, 0))
		"helmet":  # a cycle helmet with a stripe
			var shell: MeshInstance3D = add.call(_dome(0.078), colour, Vector3(0, 0.485, -0.005))
			shell.scale = Vector3(1, 1, 1.2)
			add.call(_flat(0.02, 0.005), band, Vector3(0, 0.565, 0)).scale = Vector3(1, 1, 4.5)
		"chef":  # a tall puffed chef's hat
			add.call(_flat(0.06, 0.06), colour, Vector3(0, 0.545, 0))
			var puff: MeshInstance3D = add.call(_ball(0.075), colour, Vector3(0, 0.615, 0))
			puff.scale = Vector3(1, 0.7, 1)
		"crown":
			add.call(_flat(0.06, 0.05), colour, Vector3(0, 0.545, 0))
			for k in 5:
				var a := TAU * k / 5.0
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.016
				cone.height = 0.04
				add.call(cone, colour, Vector3(cos(a) * 0.05, 0.585, sin(a) * 0.05))
			add.call(_ball(0.012), band, Vector3(0, 0.555, 0.06))


func _dome(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r
	s.is_hemisphere = true
	return s


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	return s


func _flat(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


## A limb hangs from a pivot at its top so rotating the pivot swings it.
func _limb(pivot_at: Vector3, length: float, radius: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_at
	_body.add_child(pivot)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	var part := _part(mesh, color)
	part.position.y = -length / 2
	pivot.add_child(part)
	return pivot


func _part(mesh: PrimitiveMesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	return mi
