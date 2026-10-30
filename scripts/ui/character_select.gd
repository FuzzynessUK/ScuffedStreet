class_name CharacterSelect
extends CenterContainer
## Character select, shown over the board: every character (Character.LOOKS)
## stands on a lit stage, turning slowly, in the colour of the player picking,
## with its name and a line about it under it. pick() waits for one: a click on
## a character or its button. Ones already taken stand dimmed and can't be
## picked.

signal chosen(look: String)

const STAGE := Vector2(840, 300)  # pixels
const SPACING := 1.0  # metres between characters on the stage
const TURN_SPEED := 0.6

var _title: Label
var _viewport: SubViewport
var _figures := {}  # look -> Character
var _buttons := {}  # look -> Button
var _available: Array = []
var _colour := Color.WHITE
var _time := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1e1e28")
	bg.border_color = Color("#ffd84a")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(12)
	bg.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	col.add_child(_title)
	var view := SubViewportContainer.new()
	view.custom_minimum_size = STAGE
	view.stretch = true
	view.gui_input.connect(_on_stage_input)
	col.add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2a3a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c8c8d8")
	env.ambient_light_energy = 0.5
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	sun.light_energy = 1.0
	_viewport.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	_viewport.add_child(cam)
	var width := (Character.LOOK_ORDER.size() - 1) * SPACING
	cam.look_at_from_position(Vector3(0, 1.1, 5.6), Vector3(0, 0.45, 0), Vector3.UP)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = width / 2 + 0.8
	disc.bottom_radius = width / 2 + 0.8
	disc.height = 0.08
	floor_mesh.mesh = disc
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_color = Color("#3a3a50")
	floor_mesh.material_override = floor_m
	floor_mesh.scale = Vector3(1, 1, 0.3)
	floor_mesh.position.y = -0.04
	_viewport.add_child(floor_mesh)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for look in Character.LOOK_ORDER:
		var info: Dictionary = Character.LOOKS[look]
		var b := Button.new()
		b.text = info.name
		b.tooltip_text = info.line
		b.custom_minimum_size = Vector2(STAGE.x / Character.LOOK_ORDER.size() - 4, 54)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_choose.bind(look))
		row.add_child(b)
		_buttons[look] = b


## Shows the stage for `who` in `colour`, the characters in `available`
## pickable, and returns the one they choose.
func pick(who: String, colour: Color, available: Array) -> String:
	_colour = colour
	_available = available
	_title.text = "%s: choose your character" % who
	_title.add_theme_color_override("font_color", colour.lightened(0.3))
	for f in _figures.values():
		f.queue_free()
	_figures.clear()
	var order: Array = Character.LOOK_ORDER
	for i in order.size():
		var look: String = order[i]
		var fig := Character.new()
		fig.setup(colour, look)
		fig.scale = Vector3.ONE * 1.5
		fig.position = Vector3((i - (order.size() - 1) / 2.0) * SPACING, 0, 0)
		_viewport.add_child(fig)
		_figures[look] = fig
		var free: bool = look in available
		_buttons[look].disabled = not free
		_buttons[look].text = Character.LOOKS[look].name if free else "%s\n(taken)" % Character.LOOKS[look].name
		if not free:
			_dim(fig)
	visible = true
	var look: String = await chosen
	visible = false
	return look


func _choose(look: String) -> void:
	if look in _available:
		var fig: Character = _figures[look]
		fig.celebrate()
		await get_tree().create_timer(0.6).timeout
		chosen.emit(look)


## A click on the stage picks the character nearest it.
func _on_stage_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var order: Array = Character.LOOK_ORDER
		var i := clampi(int(event.position.x / STAGE.x * order.size()), 0, order.size() - 1)
		_choose(order[i])


## Greys out a taken character.
func _dim(node: Node) -> void:
	for child in node.get_children():
		var mi := child as MeshInstance3D
		if mi and mi.material_override:
			var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			m.albedo_color = m.albedo_color.darkened(0.6)
			mi.material_override = m
		_dim(child)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for look in _figures:
		var fig: Character = _figures[look]
		if look in _available:
			fig.rotation.y = sin(_time * TURN_SPEED + fig.position.x) * 0.6
