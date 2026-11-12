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
var cannon_muzzle: Marker3D
var cannon_projectiles: Array[Dictionary] = []
var cannon_cooldown := 0.0
const CANNON_SPEED := 28.0
const CANNON_RANGE := 65.0
var joystick: Control
var joystick_center := Vector2.ZERO
var wake_pieces: Array[MeshInstance3D] = []
var wake_lifetimes: Array[float] = []
var wake_cursor := 0
var wake_distance := 0.0
var wake_previous := Vector3.ZERO
const WAKE_COUNT := 18
const WAKE_LIFETIME := 3.0
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
	e.ambient_light_energy = 0.72
	e.glow_enabled = true
	e.glow_intensity = 0.18
	e.glow_bloom = 0.02
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
	surface.subdivide_width = 96
	surface.subdivide_depth = 96
	ocean.mesh = surface
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/ocean_mobile.gdshader")
	# Compact 256px seamless normal map, generated once rather than every frame.
	var ocean_noise := FastNoiseLite.new()
	ocean_noise.seed = 2147
	ocean_noise.frequency = 0.032
	ocean_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	ocean_noise.fractal_octaves = 3
	var ripple_texture := NoiseTexture2D.new()
	ripple_texture.width = 256
	ripple_texture.height = 256
	ripple_texture.seamless = true
	ripple_texture.as_normal_map = true
	ripple_texture.bump_strength = 3.0
	ripple_texture.generate_mipmaps = true
	ripple_texture.noise = ocean_noise
	water.set_shader_parameter("ripple_normal", ripple_texture)
	ocean.material_override = water
	ocean.position.y = -0.15
	add_child(ocean)
	for island in [Vector3(-15, 0, -12), Vector3(17, 0, -18), Vector3(-20, 0, 18), Vector3(22, 0, 18)]:
		var shore := mesh_box(self, Vector3(11, 1.0, 9), island + Vector3(0, -0.35, 0), Color("#dfc68e"))
		shore.material_override = _shader_material("res://shaders/shore_mobile.gdshader")
		var island_body := StaticBody3D.new()
		island_body.position = island + Vector3(0, -0.35, 0)
		var island_shape := CollisionShape3D.new()
		var island_box := BoxShape3D.new()
		island_box.size = Vector3(11, 1.0, 9)
		island_shape.shape = island_box
		island_body.add_child(island_shape)
		add_child(island_body)
		var canopy := mesh_box(self, Vector3(8, 1.5, 6), island + Vector3(0, 0.3, 0), Color("#5b9778"))
		canopy.material_override = _shader_material("res://shaders/vegetation_mobile.gdshader")
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
		_build_wind_sail()
	elif _apply_wind_to_sails(ship_visual) == 0:
		_build_wind_sail()
	_build_cannon()
	# Pool visual wake patches in world space so foam remains behind the moving ship.
	var wake_mesh := PlaneMesh.new()
	wake_mesh.size = Vector2(3.8, 5.5)
	for i in range(WAKE_COUNT):
		var patch := MeshInstance3D.new()
		patch.mesh = wake_mesh
		patch.material_override = _shader_material("res://shaders/wake_mobile.gdshader")
		patch.visible = false
		patch.position.y = 0.025
		add_child(patch)
		wake_pieces.append(patch)
		wake_lifetimes.append(WAKE_LIFETIME)
	wake_previous = ship.position

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	_update_camera()

func _apply_wind_to_sails(root: Node) -> int:
	# The original ship-medium.glb includes sail-a, sail-b and three flags.
	# Animate those instead of drawing a second, overlapping sail.
	var count := 0
	var part := root as MeshInstance3D
	if part != null and part.mesh != null:
		var part_name := str(part.name).to_lower()
		if part_name.begins_with("sail") or part_name.begins_with("flag"):
			var original: Material = part.get_surface_override_material(0)
			if original == null:
				original = part.mesh.surface_get_material(0)
			var cloth := _shader_material("res://shaders/sail_wind_mobile.gdshader")
			var is_flag := part_name.begins_with("flag")
			cloth.set_shader_parameter("sail_height", 0.97 if is_flag else (3.63 if part_name == "sail-b" else 4.73))
			cloth.set_shader_parameter("wind_strength", 0.65 if is_flag else 0.48)
			if original is BaseMaterial3D:
				var original_material := original as BaseMaterial3D
				cloth.set_shader_parameter("cloth_color", original_material.albedo_color)
				if original_material.albedo_texture != null:
					cloth.set_shader_parameter("albedo_texture", original_material.albedo_texture)
					cloth.set_shader_parameter("use_atlas", true)
			part.material_override = cloth
			count += 1
	for child in root.get_children():
		count += _apply_wind_to_sails(child)
	return count


func _build_wind_sail() -> void:
	# Subdivided cloth surface attached to the ship. Wind blows toward world -Z.
	var cloth := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2.6, 3.3)
	mesh.subdivide_width = 18
	mesh.subdivide_depth = 16
	cloth.mesh = mesh
	cloth.rotation.x = PI / 2.0
	cloth.position = Vector3(0.0, 3.0, 0.0)
	cloth.material_override = _shader_material("res://shaders/sail_wind_mobile.gdshader")
	(cloth.material_override as ShaderMaterial).set_shader_parameter("use_uv_height", true)
	ship.add_child(cloth)


func _build_cannon() -> void:
	# Port-side cannon, mounted on the ship and pointing to local -X.
	var carriage := mesh_box(ship, Vector3(1.1, 0.35, 0.9), Vector3(-1.15, 0.62, 0.0), Color("#573c2c"))
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.19
	barrel_mesh.bottom_radius = 0.27
	barrel_mesh.height = 1.8
	barrel.mesh = barrel_mesh
	barrel.material_override = material(Color("#252d34"))
	barrel.position = Vector3(-1.85, 0.94, 0)
	barrel.rotation.z = PI / 2.0
	ship.add_child(barrel)
	cannon_muzzle = Marker3D.new()
	cannon_muzzle.position = Vector3(-2.8, 0.94, 0)
	ship.add_child(cannon_muzzle)


func _cannon_flash(at: Vector3) -> void:
	# Short-lived glowing flash and expanding smoke puffs.
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	flash.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.62, 0.16)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.38, 0.04)
	flash.material_override = glow
	add_child(flash)
	flash.global_position = at
	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "scale", Vector3.ONE * 0.08, 0.18)
	flash_tween.tween_callback(flash.queue_free)
	for i in range(7):
		var puff := MeshInstance3D.new()
		var puff_mesh := SphereMesh.new()
		puff_mesh.radius = 0.11 if i < 4 else 0.06
		puff_mesh.height = 0.22 if i < 4 else 0.12
		puff.mesh = puff_mesh
		var puff_mat := StandardMaterial3D.new()
		puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff_mat.albedo_color = Color(0.56, 0.59, 0.60, 0.65) if i < 4 else Color(1.0, 0.55, 0.12, 0.95)
		puff.material_override = puff_mat
		add_child(puff)
		puff.global_position = at
		var direction := Vector3(randf_range(-1.0, 1.0), randf_range(0.2, 1.2), randf_range(-1.0, 1.0)).normalized()
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "position", puff.position + direction * (1.1 if i < 4 else 1.8), 0.65 if i < 4 else 0.3)
		tween.tween_property(puff, "scale", Vector3.ONE * (2.5 if i < 4 else 0.05), 0.65 if i < 4 else 0.3)
		tween.chain().tween_callback(puff.queue_free)


func _fire_cannon() -> void:
	if not sailing or cannon_cooldown > 0.0 or cannon_muzzle == null:
		return
	cannon_cooldown = 0.85
	var origin := cannon_muzzle.global_position
	var direction := (-ship.global_transform.basis.x).normalized()
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.20
	mesh.height = 0.40
	ball.mesh = mesh
	ball.material_override = material(Color("#25272b"))
	add_child(ball)
	ball.global_position = origin
	cannon_projectiles.append({"node": ball, "velocity": direction * CANNON_SPEED + Vector3.UP * 3.0, "distance": 0.0})
	_cannon_flash(origin)


func _update_projectiles(delta: float) -> void:
	cannon_cooldown = maxf(0.0, cannon_cooldown - delta)
	var space := get_world_3d().direct_space_state
	for i in range(cannon_projectiles.size() - 1, -1, -1):
		var shot: Dictionary = cannon_projectiles[i]
		var ball: MeshInstance3D = shot["node"]
		var old_pos := ball.global_position
		var velocity: Vector3 = shot["velocity"]
		velocity += Vector3.DOWN * 9.8 * delta
		var new_pos := old_pos + velocity * delta
		var ray := PhysicsRayQueryParameters3D.create(old_pos, new_pos)
		var hit := space.intersect_ray(ray)
		var distance: float = shot["distance"] + old_pos.distance_to(new_pos)
		if not hit.is_empty() or new_pos.y <= -0.15 or distance >= CANNON_RANGE:
			if not hit.is_empty():
				_cannon_explosion(hit["position"])
			elif new_pos.y <= -0.15:
				_cannon_explosion(Vector3(new_pos.x, -0.15, new_pos.z))
			ball.queue_free()
			cannon_projectiles.remove_at(i)
		else:
			ball.global_position = new_pos
			shot["velocity"] = velocity
			shot["distance"] = distance
			cannon_projectiles[i] = shot


func _cannon_explosion(at: Vector3) -> void:
	_cannon_flash(at)
	var burst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	burst.mesh = sphere
	var orange := StandardMaterial3D.new()
	orange.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orange.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orange.albedo_color = Color(1.0, 0.35, 0.06, 0.75)
	burst.material_override = orange
	add_child(burst)
	burst.global_position = at
	var tween := create_tween()
	tween.tween_property(burst, "scale", Vector3.ONE * 3.0, 0.23)
	tween.tween_property(burst, "scale", Vector3.ZERO, 0.22)
	tween.tween_callback(burst.queue_free)


func _shader_material(path: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	return mat

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
	var fire := Button.new()
	fire.text = "💥 ОГОНЬ"
	fire.custom_minimum_size = Vector2(150, 75)
	fire.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	fire.position = Vector2(-195, -245)
	world_hud.add_child(fire)
	fire.pressed.connect(_fire_cannon)
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
		ship.position += forward * stick_vector.y * delta * 7.0
		ship.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.08
	_update_wake(delta)
	_update_projectiles(delta)
	_update_camera()

func _update_wake(delta: float) -> void:
	for i in range(wake_pieces.size()):
		if wake_lifetimes[i] < WAKE_LIFETIME:
			wake_lifetimes[i] += delta
			var age: float = minf(1.0, wake_lifetimes[i] / WAKE_LIFETIME)
			wake_pieces[i].visible = age < 1.0
			(wake_pieces[i].material_override as ShaderMaterial).set_shader_parameter("age", age)
	var moved := Vector2(ship.position.x - wake_previous.x, ship.position.z - wake_previous.z).length()
	wake_previous = ship.position
	if not sailing or absf(stick_vector.y) < 0.18:
		wake_distance = 0.0
		return
	wake_distance += moved
	if wake_distance < 0.7:
		return
	wake_distance = fmod(wake_distance, 0.7)
	var patch := wake_pieces[wake_cursor]
	patch.global_position = ship.global_position - ship.global_transform.basis.z * 4.4
	patch.position.y = 0.03
	patch.rotation.y = ship.rotation.y + PI
	patch.visible = true
	wake_lifetimes[wake_cursor] = 0.0
	(patch.material_override as ShaderMaterial).set_shader_parameter("age", 0.0)
	(patch.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(absf(stick_vector.y), 0.2, 1.0))
	wake_cursor = (wake_cursor + 1) % WAKE_COUNT

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