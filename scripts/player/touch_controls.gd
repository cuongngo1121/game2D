class_name TouchControls
extends Control
## Tracks each finger independently; a fire-to-dash slide keeps shooting briefly.

var game
var fingers: Dictionary = {}
var stick_finger: int = -1
var stick_origin = Vector2(152, 610)
var stick_vector = Vector2.ZERO
var is_touch: bool = false
var mouse_aim_active: bool = false
var mouse_viewport_position := Vector2.ZERO
var has_mouse_viewport_position: bool = false
var shoot_grace: float = 0
var keyboard_armed: bool = true
const TOUCH_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const TOUCH_LAYOUT_ITEM_IDS := ["move", "fire", "dash", "pulse"]
const TOUCH_LAYOUT_DEFAULT_RECTS := {
	"move": Rect2(93.0, 551.0, 118.0, 118.0),
	"fire": Rect2(1095.0, 539.0, 98.0, 98.0),
	"dash": Rect2(1002.0, 623.0, 68.0, 68.0),
	"pulse": Rect2(1151.0, 641.0, 68.0, 68.0),
}
const TOUCH_LAYOUT_MIN_SCALE := 0.55
const TOUCH_LAYOUT_MAX_SCALE := 2.0
const TOUCH_DASH_ICON: Texture2D = preload("res://assets/icons/touch_dash.svg")
var touch_layout_targets: Dictionary = {}
var touch_layout_positions: Dictionary = {}
var touch_layout_scales: Dictionary = {}
var button_centers: Dictionary = {}
var button_radii: Dictionary = {}

func setup(owner_game) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	is_touch = OS.has_feature("android")
	_load_touch_layout()
	_build_touch_layout_targets()
	_refresh_touch_layout_geometry()

func _load_touch_layout() -> void:
	touch_layout_positions.clear()
	touch_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("touch_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in TOUCH_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		touch_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		touch_layout_scales[item_id] = Vector2(clampf(float(encoded[2]), TOUCH_LAYOUT_MIN_SCALE, TOUCH_LAYOUT_MAX_SCALE), clampf(float(encoded[3]), TOUCH_LAYOUT_MIN_SCALE, TOUCH_LAYOUT_MAX_SCALE))

func _build_touch_layout_targets() -> void:
	for item_id: String in TOUCH_LAYOUT_ITEM_IDS:
		var default_rect: Rect2 = TOUCH_LAYOUT_DEFAULT_RECTS[item_id]
		var target := Control.new()
		target.name = "TouchLayout_%s" % item_id.capitalize()
		target.size = default_rect.size
		target.scale = _touch_layout_scale_for(item_id)
		target.position = _touch_layout_position_for(item_id, default_rect.position, target.size, target.scale)
		target.visible = false
		target.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.set_meta("touch_layout_item_id", item_id)
		target.set_meta("touch_layout_default_position", default_rect.position)
		target.set_meta("touch_layout_default_scale", Vector2.ONE)
		add_child(target)
		touch_layout_targets[item_id] = target

func touch_layout_target(item_id: String) -> Control:
	var target: Control = touch_layout_targets.get(item_id)
	return target

func touch_layout_default_rect(item_id: String) -> Rect2:
	var value: Variant = TOUCH_LAYOUT_DEFAULT_RECTS.get(item_id, Rect2())
	return value if value is Rect2 else Rect2()

func _touch_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = touch_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, TOUCH_LAYOUT_MIN_SCALE, TOUCH_LAYOUT_MAX_SCALE), clampf(stored.y, TOUCH_LAYOUT_MIN_SCALE, TOUCH_LAYOUT_MAX_SCALE))

func _touch_layout_position_for(item_id: String, default_position: Vector2, base_size: Vector2, scale: Vector2) -> Vector2:
	var stored: Variant = touch_layout_positions.get(item_id, default_position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_position
	return _clamp_touch_layout_position(desired_position, base_size, scale)

func _clamp_touch_layout_position(position: Vector2, base_size: Vector2, scale: Vector2) -> Vector2:
	var visual_size := base_size * scale
	return Vector2(
		clampf(position.x, 0.0, maxf(0.0, TOUCH_LAYOUT_VIEWPORT_SIZE.x - visual_size.x)),
		clampf(position.y, 0.0, maxf(0.0, TOUCH_LAYOUT_VIEWPORT_SIZE.y - visual_size.y)))

func _touch_layout_rect(item_id: String) -> Rect2:
	var target: Control = touch_layout_targets.get(item_id)
	if target == null:
		return Rect2()
	return Rect2(target.position, target.size * target.scale)

func _touch_layout_center(item_id: String) -> Vector2:
	return _touch_layout_rect(item_id).get_center()

func _touch_layout_radius(item_id: String) -> float:
	var rect := _touch_layout_rect(item_id)
	return minf(rect.size.x, rect.size.y) * 0.5

func _refresh_touch_layout_geometry() -> void:
	button_centers = {
		"fire": _touch_layout_center("fire"),
		"dash": _touch_layout_center("dash"),
		"pulse": _touch_layout_center("pulse"),
		"interact": Vector2(788.0, 654.0),
	}
	button_radii = {
		"fire": _touch_layout_radius("fire"),
		"dash": _touch_layout_radius("dash"),
		"pulse": _touch_layout_radius("pulse"),
		"interact": 34.0,
	}

func apply_touch_layout_transform(item_id: String, next_position: Vector2, next_scale: Vector2) -> void:
	var target: Control = touch_layout_targets.get(item_id)
	if target == null:
		return
	# All four editable targets are round controls. Keep resizing uniform so a
	# side handle cannot turn a joystick or action button into an ellipse.
	var uniform_scale := clampf(maxf(absf(next_scale.x), absf(next_scale.y)), TOUCH_LAYOUT_MIN_SCALE, TOUCH_LAYOUT_MAX_SCALE)
	target.scale = Vector2(uniform_scale, uniform_scale)
	target.position = _clamp_touch_layout_position(next_position, target.size, target.scale)
	_refresh_touch_layout_geometry()
	sync_touch_layout()
	if game != null and game.ui != null:
		game.ui.sync_resonance_bar_layout()
	queue_redraw()

func sync_touch_layout() -> void:
	if game == null or not game.settings is Dictionary:
		return
	var output: Dictionary = {}
	for item_id: String in TOUCH_LAYOUT_ITEM_IDS:
		var target: Control = touch_layout_targets.get(item_id)
		if target == null or not is_instance_valid(target):
			continue
		output[item_id] = [target.position.x, target.position.y, target.scale.x, target.scale.y]
	game.settings["touch_layout"] = output

func _movement_activation_rect() -> Rect2:
	var rect := _touch_layout_rect("move")
	return rect.grow(maxf(120.0, _touch_layout_radius("move")))

func _user_touch_scale() -> float:
	return maxf(0.1, float(game.settings.get("touch_scale", 1.0)))

func _is_layout_editor_active() -> bool:
	if game == null or game.ui == null:
		return false
	var editor = game.ui.hud_layout_editor
	return editor != null and is_instance_valid(editor) and editor.is_editor_active()

func reset() -> void:
	fingers.clear()
	stick_finger = -1
	stick_vector = Vector2.ZERO
	shoot_grace = 0
	keyboard_armed = false
	queue_redraw()

func movement() -> Vector2:
	if not keyboard_armed:
		return stick_vector
	var keyboard = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return (keyboard + stick_vector).limit_length(1)

func pulse_ready() -> bool:
	return game != null and game.player != null and game.player.hp > 0 and game.player.resonance >= 100.0

func firing() -> bool:
	if shoot_grace > 0:
		return true
	for touch in fingers.values():
		if touch.action == "fire":
			return true
	return not is_touch and keyboard_armed and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_global_mouse_position().y > 105

func aim_direction(from: Vector2) -> Vector2:
	for touch in fingers.values():
		if touch.action == "fire" and not game.settings.get("auto_aim", true):
			var direction: Vector2 = touch.pos - button_centers.fire
			if direction.length() > 8:
				return direction.normalized()
	return (desktop_mouse_world_position() - from).normalized() if mouse_aim_active else game.player.aim_direction

func desktop_mouse_world_position() -> Vector2:
	# This Control is parented to a CanvasLayer, so its global mouse position is
	# expressed in viewport pixels. Player.position is instead in the scrolling,
	# zoomed world. Invert the world's canvas transform before comparing them.
	var viewport_mouse_position: Vector2 = mouse_viewport_position if has_mouse_viewport_position else get_viewport().get_mouse_position()
	if game == null or game.world == null:
		return viewport_mouse_position
	var world_to_viewport: Transform2D = game.world.get_global_transform_with_canvas()
	return world_to_viewport.affine_inverse() * viewport_mouse_position

func _process(delta: float) -> void:
	if game == null:
		return
	visible = game.state == "playing"
	shoot_grace = maxf(0, shoot_grace - delta)
	if not keyboard_armed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_physical_key_pressed(KEY_W) and not Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_S) and not Input.is_physical_key_pressed(KEY_D):
		keyboard_armed = true
	if visible:
		queue_redraw()

func _input(event: InputEvent) -> void:
	if game == null or game.state != "playing":
		return
	if _is_layout_editor_active():
		return
	if event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_viewport_position = event.position
		has_mouse_viewport_position = true
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_aim_active = true
		is_touch = false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				game.player.dash()
			KEY_Q:
				trigger("pulse")
			KEY_TAB:
				game.swap_weapon()
			KEY_E:
				game.interact()
			KEY_R:
				game.recall_pistol()
			KEY_ESCAPE, KEY_P:
				game.pause_game()
	if event is InputEventScreenTouch:
		is_touch = true
		mouse_aim_active = false
		if event.pressed:
			if _movement_activation_rect().has_point(event.position) and stick_finger == -1:
				stick_finger = event.index
				var move_rect := _touch_layout_rect("move")
				stick_origin = Vector2(clampf(event.position.x, move_rect.position.x, move_rect.end.x), clampf(event.position.y, move_rect.position.y, move_rect.end.y))
				stick_vector = Vector2.ZERO
			else:
				var action: String = action_at(event.position)
				fingers[event.index] = {"action": action, "pos": event.position}
				trigger(action)
		else:
			if event.index == stick_finger:
				stick_finger = -1
				stick_vector = Vector2.ZERO
			fingers.erase(event.index)
	if event is InputEventScreenDrag:
		if event.index == stick_finger:
			var joystick_travel := maxf(1.0, _touch_layout_radius("move") * (55.0 / 59.0) * _user_touch_scale())
			stick_vector = ((event.position - stick_origin) / joystick_travel).limit_length(1)
		elif fingers.has(event.index):
			var previous: String = fingers[event.index].action
			var action: String = action_at(event.position)
			# Sliding from fire to dash needs only the right thumb.
			if previous == "fire" and action == "dash":
				shoot_grace = 0.32
				trigger("dash")
				fingers[event.index].action = action
			elif action == "fire":
				fingers[event.index].action = "fire"
			fingers[event.index].pos = event.position

func action_at(point: Vector2) -> String:
	for action in button_centers:
		if action == "interact" and game.interaction_label().is_empty():
			continue
		if action == "pulse" and not pulse_ready():
			continue
		var center: Vector2 = button_centers[action]
		var radius: float = float(button_radii.get(action, 34.0)) * _user_touch_scale()
		if point.distance_to(center) <= radius:
			return action
	return ""

func trigger(action: String) -> void:
	match action:
		"dash": game.player.dash()
		"pulse":
			if pulse_ready():
				game.player.pulse()
		"interact": game.interact()

func _draw() -> void:
	if game == null or game.state != "playing":
		return
	var alpha: float = game.settings.get("touch_opacity", 0.65)
	var scale_value: float = _user_touch_scale()
	var move_center: Vector2 = _touch_layout_center("move")
	var move_radius: float = _touch_layout_radius("move") * scale_value
	var center: Vector2 = stick_origin if stick_finger != -1 else move_center
	draw_circle(center, move_radius, Color(0.06, 0.06, 0.15, alpha))
	draw_arc(center, move_radius, 0, TAU, 32, Color(0.3, 0.6, 0.8, alpha), 2)
	draw_circle(center + stick_vector * (move_radius * 39.0 / 59.0), move_radius * 22.0 / 59.0, Color(0.3, 0.65, 0.85, alpha))
	var font: Font = game.ui.font
	var names = {"interact": "DÙNG"}
	for action in button_centers:
		if action == "interact" and game.interaction_label().is_empty():
			continue
		var at: Vector2 = button_centers[action]
		var size_value: float = float(button_radii.get(action, 34.0)) * scale_value
		var ready: bool = action != "pulse" or pulse_ready()
		if action == "dash":
			ready = game.player.dash_cooldown <= 0
		var color: Color = Color("35e7ff") if ready else Color("70688c")
		color.a = alpha
		draw_circle(at, size_value, Color(0.075, 0.04, 0.16, alpha))
		draw_arc(at, size_value, 0, TAU, 32, color, 2)
		if action in ["fire", "dash", "pulse"]:
			if action == "dash":
				draw_touch_dash_icon(at, size_value, color)
			else:
				draw_touch_action_icon(action, at, size_value, color)
		else:
			var label_text: String = names[action]
			var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, at + Vector2(-width / 2, 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)

func draw_touch_action_icon(action: String, at: Vector2, radius: float, color: Color) -> void:
	match action:
		"fire":
			# Four broken outer arcs, cardinal marks and a central ring, matching
			# the second reference instead of a text label.
			var target_stroke := maxf(2.0, radius * 0.085)
			var outer_radius := radius * 0.50
			for arc_data in [
				[deg_to_rad(-160.0), deg_to_rad(-110.0)],
				[deg_to_rad(-70.0), deg_to_rad(-20.0)],
				[deg_to_rad(20.0), deg_to_rad(70.0)],
				[deg_to_rad(110.0), deg_to_rad(160.0)],
			]:
				draw_arc(at, outer_radius, arc_data[0], arc_data[1], 12, color, target_stroke, true)
			draw_line(at + Vector2(0.0, -0.57) * radius, at + Vector2(0.0, -0.37) * radius, color, target_stroke, true)
			draw_line(at + Vector2(0.0, 0.37) * radius, at + Vector2(0.0, 0.57) * radius, color, target_stroke, true)
			draw_line(at + Vector2(-0.57, 0.0) * radius, at + Vector2(-0.37, 0.0) * radius, color, target_stroke, true)
			draw_line(at + Vector2(0.37, 0.0) * radius, at + Vector2(0.57, 0.0) * radius, color, target_stroke, true)
			draw_circle(at, radius * 0.16, Color(color.r, color.g, color.b, color.a * 0.20))
			draw_arc(at, radius * 0.16, 0.0, TAU, 24, color, target_stroke, true)
		"pulse":
			# Two crossed orbit rings around a spiky resonance core, matching the
			# third reference's compact planet/energy silhouette.
			var orbit_stroke := maxf(1.8, radius * 0.065)
			draw_touch_orbit(at + Vector2(0.0, 0.02) * radius, radius * 0.58, deg_to_rad(-16.0), 0.30, color, orbit_stroke)
			draw_touch_orbit(at + Vector2(0.0, 0.02) * radius, radius * 0.58, deg_to_rad(18.0), 0.30, Color(color.r, color.g, color.b, color.a * 0.78), orbit_stroke)
			var core := PackedVector2Array([
				at + Vector2(-0.34, -0.05) * radius,
				at + Vector2(-0.16, -0.05) * radius,
				at + Vector2(-0.21, -0.28) * radius,
				at + Vector2(0.00, -0.12) * radius,
				at + Vector2(0.11, -0.34) * radius,
				at + Vector2(0.18, -0.11) * radius,
				at + Vector2(0.37, -0.16) * radius,
				at + Vector2(0.25, 0.05) * radius,
				at + Vector2(0.34, 0.22) * radius,
				at + Vector2(0.08, 0.15) * radius,
				at + Vector2(-0.03, 0.31) * radius,
				at + Vector2(-0.14, 0.13) * radius,
				at + Vector2(-0.37, 0.20) * radius,
				at + Vector2(-0.24, 0.03) * radius,
			])
			draw_colored_polygon(core, Color(color.r, color.g, color.b, color.a * 0.22))
			draw_polyline(PackedVector2Array([
				core[0], core[1], core[2], core[3], core[4], core[5], core[6], core[7],
				core[8], core[9], core[10], core[11], core[12], core[13], core[0],
			]), color, orbit_stroke, true)
			draw_circle(at, radius * 0.07, color)


func draw_touch_dash_icon(at: Vector2, radius: float, color: Color) -> void:
	# The authored SVG is drawn as a tinted texture so the runner's silhouette
	# stays intact at every F8 size instead of being rebuilt from loose segments.
	var icon_size := radius * 1.32
	draw_texture_rect(
		TOUCH_DASH_ICON,
		Rect2(at - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size),
		false,
		color)


func draw_touch_orbit(at: Vector2, radius: float, rotation: float, vertical_scale: float, color: Color, stroke: float) -> void:
	var points := PackedVector2Array()
	for index in range(41):
		var angle := TAU * float(index) / 40.0
		var local := Vector2(cos(angle) * radius, sin(angle) * radius * vertical_scale)
		var rotated := Vector2(
			local.x * cos(rotation) - local.y * sin(rotation),
			local.x * sin(rotation) + local.y * cos(rotation))
		points.append(at + rotated)
	draw_polyline(points, color, stroke, true)
