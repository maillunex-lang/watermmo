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

func _ready() -> void:
	_build_world()
	_build_ui()
	_show_menu()

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
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
	e.background_color = Color("#8cb8c6")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#c8e0e2")
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	mesh_box(self, Vector3(230, 0.15, 230), Vector3(0, -0.18, 0), Color("#12627b"))
	for island in [Vector3(-15, 0, -12), Vector3(17, 0, -18), Vector3(-20, 0, 18), Vector3(22, 0, 18)]:
		mesh_box(self, Vector3(11, 1.0, 9), island + Vector3(0, -0.35, 0), Color("#dfc68e"))
		mesh_box(self, Vector3(8, 1.5, 6), island + Vector3(0, 0.3, 0), Color("#5b9778"))
		for i in range(4):
			var x: float = island.x + float(i % 2) * 2.5 - 1.5
			var z: float = island.z + float(i / 2) * 2.0 - 1.0
			mesh_box(self, Vector3(0.35, 2.2, 0.35), Vector3(x, 1.7, z), Color("#805b3e"))
			mesh_box(self, Vector3(2.0, 2.1, 2.0), Vector3(x, 3.1, z), Color("#2e795a"))
	ship = Node3D.new()
	add_child(ship)
	mesh_box(ship, Vector3(2.3, 0.9, 5.4), Vector3(0, 0.45, 0), Color("#654c39"))
	mesh_box(ship, Vector3(1.7, 0.5, 2.0), Vector3(0, 1.05, 0.6), Color("#e7d8b3"))
	mesh_box(ship, Vector3(0.12, 5.0, 0.12), Vector3(0, 3.1, 0), Color("#5c4435"))
	mesh_box(ship, Vector3(0.08, 3.3, 2.3), Vector3(0, 3.0, 0.0), Color("#f4e7ce"))
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()

func _update_camera() -> void:
	if camera == null:
		return
	camera.position = ship.position + Vector3(0, zoom, zoom * 0.75)
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

func _process(delta: float) -> void:
	if sailing:
		var movement := target - ship.position
		if movement.length() > 0.12:
			ship.position += movement.normalized() * minf(movement.length(), delta * 7.0)
			ship.rotation.y = lerp_angle(ship.rotation.y, atan2(-movement.x, -movement.z), delta * 3.0)
		ship.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.08
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if not sailing:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			if fingers.size() == 1:
				_set_destination(event.position)
		else:
			fingers.erase(event.index)
			pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		fingers[event.index] = event.position
		if fingers.size() == 2:
			var positions := fingers.values()
			var distance: float = (positions[0] as Vector2).distance_to(positions[1] as Vector2)
			if pinch_distance > 0:
				zoom = clampf(zoom * pinch_distance / maxf(distance, 1), 12, 48)
			pinch_distance = distance
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_set_destination(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = maxf(12, zoom - 2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = minf(48, zoom + 2)

func _set_destination(screen_pos: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var sea := Plane(Vector3.UP, 0)
	var hit: Variant = sea.intersects_ray(origin, direction)
	if hit is Vector3:
		target = Vector3(clampf(hit.x, -95, 95), 0, clampf(hit.z, -95, 95))
