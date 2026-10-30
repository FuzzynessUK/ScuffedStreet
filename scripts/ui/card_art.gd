class_name CardArt
extends Control
## The picture on a Wildcard (Wildcards.CARDS): a little 3D scene of what the
## card does (CardScene), its subject in the middle and turning gently, on a
## backdrop that says what kind of card it is, with a caption above. Set
## `card` (a card's name) to show it.

## The backdrop says what kind of card it is.
const MOODS := {
	"gain": Color("#fff1c2"), "pay": Color("#ffe0dc"), "move": Color("#dcefff"),
	"bonds": Color("#dcf5ec"), "lots": Color("#ece3ff"), "night": Color("#3a3a5a"),
}
const SWAY := 0.35  # how far the scene turns either way, radians
## The bright card each kind of picture sits on (the Scrap Heap's big card).
const CARD_COLOURS := {
	"gain": Color("#ff9a1f"), "pay": Color("#7f89a3"), "move": Color("#2f86e8"),
	"bonds": Color("#14a98a"), "lots": Color("#8b4fe0"), "night": Color("#2b2f6e"),
}

var with_caption := true  # the caption over the picture (off when the card shows its own)
var card := "":
	set(v):
		card = v
		_show()

var _view: SubViewportContainer
var _viewport: SubViewport
var _scene: Node3D  # the card's CardScene, turned by _process
var _caption: Label
var _time := 0.0


func _init() -> void:
	clip_contents = true
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_view.add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d8d8e8")
	env.ambient_light_energy = 1.0
	var world := WorldEnvironment.new()
	world.environment = env
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	_viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 36
	camera.position = Vector3(0, 1.25, 2.7)
	_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 0.42, 0), Vector3.UP)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 6
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 19)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)


func _show() -> void:
	if _scene:
		_scene.queue_free()
		_scene = null
	var said: Array = CardScene.caption(card)
	_caption.text = said[0]
	_caption.add_theme_color_override("font_color", said[1])
	_caption.visible = with_caption
	_scene = CardScene.build(card)
	_viewport.add_child(_scene)
	var night := CardScene.mood(card) == "night"
	var env: Environment = (_viewport.get_child(0) as WorldEnvironment).environment
	env.ambient_light_color = Color("#6a6a9a") if night else Color("#d8d8e8")
	(_viewport.get_child(1) as DirectionalLight3D).light_energy = 0.45 if night else 1.15
	_caption.add_theme_color_override("font_outline_color",
			Color(0, 0, 0, 0.6) if night else Color(1, 1, 1, 0.9))
	queue_redraw()


func _process(delta: float) -> void:
	if _scene and is_visible_in_tree():
		_time += delta
		_scene.rotation.y = sin(_time * 0.8) * SWAY


func _draw() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = MOODS[CardScene.mood(card)]
	box.set_corner_radius_all(14)
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2.ZERO, size))
