class_name Character
extends Node3D
## A placeholder walking figure built from primitives: head, body, two arms and
## two legs that swing while walk_to() is moving it, celebrate() for paydays
## and punch() for hitting the dice block.

const HEIGHT := 0.5
const STRIDE_SPEED := 14.0  # radians of swing phase per second
const SWING := 0.7          # max limb swing, radians
const SKIN := Color("#f1c9a5")
const TROUSERS := Color("#2f3140")
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


func setup(color: Color) -> void:
	_body = Node3D.new()
	add_child(_body)
	var torso := _part(CapsuleMesh.new(), color)
	torso.mesh.radius = 0.085
	torso.mesh.height = 0.24
	torso.position.y = 0.3
	_body.add_child(torso)
	var head := _part(SphereMesh.new(), SKIN)
	head.mesh.radius = 0.065
	head.mesh.height = 0.13
	head.position.y = 0.47
	_body.add_child(head)
	var cap := _part(CylinderMesh.new(), color.darkened(0.25))
	cap.mesh.top_radius = 0.05
	cap.mesh.bottom_radius = 0.07
	cap.mesh.height = 0.05
	cap.position.y = 0.53
	_body.add_child(cap)
	var nose := _part(SphereMesh.new(), SKIN.darkened(0.1))
	nose.mesh.radius = 0.018
	nose.mesh.height = 0.036
	nose.position = Vector3(0, 0.47, 0.065)  # faces +z, the way it walks
	_body.add_child(nose)
	for side in [-1, 1]:
		_legs.append(_limb(Vector3(0.045 * side, 0.2, 0), 0.2, 0.035, TROUSERS))
		_arms.append(_limb(Vector3(0.11 * side, 0.4, 0), 0.18, 0.028, color))


## Walks to `target` over `seconds`, turning to face the way it goes.
func walk_to(target: Vector3, seconds: float) -> void:
	var flat := Vector3(target.x - position.x, 0, target.z - position.z)
	if flat.length() > 0.01:
		rotation.y = atan2(flat.x, flat.z)
	_walking = true
	var tw := create_tween()
	tw.tween_property(self, "position", target, seconds)
	tw.tween_callback(func(): _walking = false)


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
