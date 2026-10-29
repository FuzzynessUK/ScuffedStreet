class_name Character
extends Node3D
## A placeholder walking figure built from primitives: head, body, two arms and
## two legs that swing while walk_to() is moving it.

const HEIGHT := 0.5
const STRIDE_SPEED := 14.0  # radians of swing phase per second
const SWING := 0.7          # max limb swing, radians
const SKIN := Color("#f1c9a5")
const TROUSERS := Color("#2f3140")

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _body: Node3D
var _phase := 0.0
var _walking := false


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


func _process(delta: float) -> void:
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
