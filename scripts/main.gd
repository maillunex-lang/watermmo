extends Node3D

const TEAL := Color("#64e5d7")
const GOLD := Color("#e8c58c")
var ship: Node3D
var camera: Camera3D
var ui: CanvasLayer
var menu: Control
var world_hud: Control
var sailing := false
var target := Vector3.ZERO
var zoom := 27.0
var fingers: Dictionary = {}
var pinch_distance := 0.0
var stick_vector := Vector2.ZERO
var left_touch := -1
var right_touches: Dictionary = {}
var right_last: Dictionary = {}
var camera_yaw := 0.0
var camera_pitch := 0.65
var joystick: Control
var joystick_center := Vector2.ZERO
const STICK_RADIUS := 72.0
const TOUCH_AREA_FRACTION := 0.42


func _ready() -> void:
	_build_world()
	_build_ui()
	_show_menu()

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	m.metallic = 0.0
	return m

func mesh_box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	obj.mesh = box
	obj.position = at
	obj.material_override = material(color)
	parent.add_child(obj)
	return obj

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#83b5c8")
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("#a5d1d3")
	e.fog_density = 0.008
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8e0e2")
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.05
	sun.light_color = Color("#ffe2ae")
	sun.shadow_enabled = false
	add_child(sun)
	var ocean := MeshInstance3D.new()
	var surface := PlaneMesh.new()
	surface.size = Vector2(230, 230)
	surface.subdivide_width = 64
	surface.subdivide_depth = 64
	ocean.mesh = surface
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/ocean_mobile.gdshader")
	ocean.material_override = water
	ocean.position.y = -0.15
	add_child(ocean)
	for island in [Vector3(-15, 0, -12), Vector3(17, 0, -18), Vector3(-20, 0, 18), Vector3(22, 0, 18)]:
		mesh_box(self, Vector3(11, 1.0, 9), island + Vector3(0, -0.35, 0), Color("#dfc68e"))
		mesh_box(self, Vector3(8, 1.5, 6), island + Vector3(0, 0.3, 0), Color("#5b9778"))
		_model("rocks-sand-a", self, island + Vector3(-4.0, 0.45, 1.0), 1.0)
		_model("tower-complete-small", self, island + Vector3(1.5, 1.05, 0.5), 0.9)
		_model("structure-platform-dock", self, island + Vector3(4.8, 0.1, 0.0), 1.0)
		for i in range(4):
			var x: float = island.x + float(i % 2) * 2.5 - 1.5
			var z: float = island.z + float(i / 2) * 2.0 - 1.0
			_model("palm-straight" if i % 2 == 0 else "palm-bend", self, Vector3(x, 1.05, z), 1.0)
	ship = Node3D.new()
	add_child(ship)
	var ship_visual := _model("ship-medium", ship, Vector3.ZERO, 1.0)
	if ship_visual == null:
		mesh_box(ship, Vector3(2.3, 0.9, 5.4), Vector3(0, 0.45, 0), Color("#654c39"))

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()

func _model(model_name: String, parent: Node3D, at: Vector3, scale_factor: float) -> Node3D:
	var path := "res://assets/kenney_pirate/" + model_name + ".glb"
	var resource := load(path)
	if resource is PackedScene:
		var model := (resource as PackedScene).instantiate() as Node3D
		parent.add_child(model)
		model.position = at
		model.scale = Vector3.ONE * scale_factor
		return model
	return null

func _update_camera() -> void:
	if camera == null:
		return
	camera.position = ship.position + Vector3(sin(camera_yaw) * zoom * cos(camera_pitch), zoom * sin(camera_pitch), cos(camera_yaw) * zoom * cos(camera_pitch))
	camera.look_at(ship.position, Vector3.UP)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	world_hud = Control.new()
	world_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(world_hud)
	var title := Label.new()
	title.text = "WATERMMO"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", TEAL)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	title.position = Vector2(60, -130)
	menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "МОРСКИЕ ПРИКЛЮЧЕНИЯ • 3D"
	subtitle.add_theme_font_size_override("font_size", 21)
	subtitle.position = Vector2(65, 210)
	menu.add_child(subtitle)
	var start := _button("НАЧАТЬ ПЛАВАНИЕ", menu, Vector2(65, 270))
	start.pressed.connect(_start_game)
	var info := _button("О ПРОЕКТЕ", menu, Vector2(65, 340))
	info.pressed.connect(func(): _popup("WaterMMO", "3D-каркас. Сетевые системы появятся в следующих версиях."))
	var top := Label.new()
	top.text = "⚓ WATERMMO 3D  •  КОСНИСЬ МОРЯ, ЧТОБЫ ЗАДАТЬ КУРС"
	top.position = Vector2(24, 18)
	top.add_theme_font_size_override("font_size", 22)
	top.add_theme_color_override("font_color", TEAL)
	world_hud.add_child(top)
	var back := _button("МЕНЮ", world_hud, Vector2(24, 65))
	back.pressed.connect(_show_menu)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 24
	bar.offset_right = -24
	bar.offset_top = -76
	bar.offset_bottom = -12
	bar.add_theme_constant_override("separation", 12)
	world_hud.add_child(bar)
	joystick = Control.new()
	joystick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.position = Vector2(48, -244)
	joystick.custom_minimum_size = Vector2(180, 180)
	joystick.size = Vector2(180, 180)
	joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_hud.add_child(joystick)
	joystick.draw.connect(_draw_stick)
	for label in ["ПОРТ", "КАРТА", "ФЛОТ", "ЗАДАНИЯ"]:
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(130, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(b)
		var captured: String = label
		b.pressed.connect(func(): _popup(captured, "Раздел в разработке."))

func _button(label: String, parent: Control, at: Vector2) -> Button:
	var b := Button.new()
	b.text = label
	b.position = at
	b.custom_minimum_size = Vector2(250, 56)
	parent.add_child(b)
	return b

func _popup(title: String, message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	ui.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()

func _show_menu() -> void:
	sailing = false
	menu.visible = true
	world_hud.visible = false

func _start_game() -> void:
	sailing = true
	menu.visible = false
	world_hud.visible = true

func _draw_stick() -> void:
	var center := Vector2(90, 90)
	joystick.draw_circle(center, 76, Color(0.01, 0.11, 0.19, 0.42))
	joystick.draw_arc(center, 76, 0, TAU, 64, Color(0.36, 0.9, 0.92, 0.75), 3.0, true)
	joystick.draw_circle(center + stick_vector * STICK_RADIUS, 30, Color(0.23, 0.76, 0.82, 0.85))
	joystick.draw_arc(center + stick_vector * STICK_RADIUS, 30, 0, TAU, 32, Color.WHITE, 2.0, true)

func _process(delta: float) -> void:
	if sailing:
		# Manual joystick replaces tap-to-destination; no collision or physics changes.
		ship.rotation.y += stick_vector.x * delta * 1.7
		var forward := -ship.global_transform.basis.z
		ship.position += forward * (-stick_vector.y) * delta * 7.0
		ship.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.08
	_update_camera()

func _input(event: InputEvent) -> void:
	if not sailing:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if touch.position.x < get_viewport().get_visible_rect().size.x * TOUCH_AREA_FRACTION and left_touch == -1:
				left_touch = touch.index
				_update_stick(touch.position)
			else:
				right_touches[touch.index] = touch.position
				right_last[touch.index] = touch.position
		else:
			if touch.index == left_touch:
				left_touch = -1
				stick_vector = Vector2.ZERO
				joystick.queue_redraw()
			right_touches.erase(touch.index)
			right_last.erase(touch.index)
			pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == left_touch:
			_update_stick(drag.position)
		elif right_touches.has(drag.index):
			right_touches[drag.index] = drag.position
			if right_touches.size() >= 2:
				var values := right_touches.values()
				var distance: float = (values[0] as Vector2).distance_to(values[1] as Vector2)
				if pinch_distance > 0.0:
					zoom = clampf(zoom * pinch_distance / maxf(distance, 1.0), 12.0, 48.0)
				pinch_distance = distance
			else:
				pinch_distance = 0.0
				camera_yaw -= drag.relative.x * 0.006
				camera_pitch = clampf(camera_pitch + drag.relative.y * 0.004, 0.18, 1.35)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clampf(camera_pitch + event.relative.y * 0.004, 0.18, 1.35)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = maxf(12, zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = minf(48, zoom + 2)

func _update_stick(position: Vector2) -> void:
	var rect := get_viewport().get_visible_rect().size
	# Joystick anchored 48 px from left and 244 px above bottom.
	var center := Vector2(138, rect.y - 154)
	stick_vector = ((position - center) / STICK_RADIUS).limit_length(1.0)
	joystick.queue_redraw()