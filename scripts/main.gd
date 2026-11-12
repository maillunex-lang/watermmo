extends Control

const OCEAN := Color("082333")
const CYAN := Color("5be7d6")
const SAND := Color("f1ca85")
var sailing := false
var position_normalized := Vector2(0.50, 0.50)
var destination := position_normalized
var nav_layer: Control

func _ready() -> void:
	build_menu()

func _process(delta: float) -> void:
	if sailing:
		position_normalized = position_normalized.move_toward(destination, delta * 0.18)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN)
	for i in range(24):
		draw_line(Vector2(0, i * size.y / 24), Vector2(size.x, i * size.y / 24), Color("113849"), 1.0)
	for i in range(35):
		draw_line(Vector2(i * size.x / 35, 0), Vector2(i * size.x / 35, size.y), Color("103344"), 1.0)
	for island in [Vector2(.16,.28),Vector2(.77,.33),Vector2(.24,.79),Vector2(.83,.81)]:
		draw_circle(island * size, 44, Color("205565"))
		draw_circle(island * size, 36, Color("54846c"))
	if sailing:
		var p := position_normalized * size
		if position_normalized.distance_to(destination) > 0.01:
			draw_dashed_line(p, destination * size, CYAN, 2.0, 8)
		draw_circle(p, 25, Color(0.3,0.9,0.8,0.2))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-23), p+Vector2(-13,16),p+Vector2(13,16)]), SAND)

func _gui_input(event: InputEvent) -> void:
	if not sailing:
		return
	if event is InputEventScreenTouch and event.pressed:
		destination = event.position / size
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		destination = event.position / size
	else:
		return
	destination.x = clampf(destination.x, 0.05, 0.95)
	destination.y = clampf(destination.y, 0.13, 0.85)

func make_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(210, 56)
	button.pressed.connect(callback)
	return button

func build_menu() -> void:
	sailing = false
	if is_instance_valid(nav_layer):
		nav_layer.queue_free()
	nav_layer = VBoxContainer.new()
	nav_layer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	nav_layer.position = Vector2(65, 110)
	nav_layer.add_theme_constant_override("separation", 18)
	add_child(nav_layer)
	var heading := Label.new()
	heading.text = "WATERMMO\nПОКОРИ ОКЕАН"
	heading.add_theme_font_size_override("font_size", 48)
	heading.add_theme_color_override("font_color", CYAN)
	nav_layer.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Морская MMORPG • Альфа 0.1.0"
	subtitle.add_theme_font_size_override("font_size", 20)
	nav_layer.add_child(subtitle)
	nav_layer.add_child(make_button("НАЧАТЬ ПЛАВАНИЕ", build_world))
	nav_layer.add_child(make_button("О ПРОЕКТЕ", func(): dialog("WaterMMO", "Первый офлайн-каркас. Онлайн и игровые системы появятся позже.")))
	nav_layer.add_child(make_button("НАСТРОЙКИ", func(): dialog("Настройки", "Настройки звука и графики появятся в следующих версиях.")))

func build_world() -> void:
	sailing = true
	if is_instance_valid(nav_layer):
		nav_layer.queue_free()
	nav_layer = VBoxContainer.new()
	nav_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	nav_layer.position = Vector2(20,20)
	add_child(nav_layer)
	var heading := Label.new()
	heading.text = "⚓ АРХИПЕЛАГ 01   •   КОСНИСЬ МОРЯ, ЧТОБЫ ЗАДАТЬ КУРС"
	heading.add_theme_color_override("font_color", CYAN)
	visibility_layer(heading)
	nav_layer.add_child(heading)
	nav_layer.add_child(make_button("☰  МЕНЮ", build_menu))
	var toolbar := HBoxContainer.new()
	nav_layer.add_child(toolbar)
	for name in ["ПОРТ", "КАРТА", "ФЛОТ", "ЗАДАНИЯ"]:
		var n: String = str(name)
		toolbar.add_child(make_button(n, func(): dialog(n, "Раздел будет реализован в следующих версиях.")))

func visibility_layer(_control: Control) -> void:
	pass

func dialog(title_text: String, body: String) -> void:
	var d := AcceptDialog.new()
	d.title = title_text
	d.dialog_text = body
	add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	d.popup_centered()
