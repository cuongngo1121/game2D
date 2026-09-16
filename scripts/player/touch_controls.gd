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
var button_centers: Dictionary = {"fire": Vector2(1144, 588), "dash": Vector2(1036, 657), "pulse": Vector2(1185, 675), "swap": Vector2(911, 654), "interact": Vector2(788, 654)}

func setup(owner_game) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	is_touch = OS.has_feature("android")

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
				game.player.pulse()
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
			if event.position.x < 440 and event.position.y > 310 and stick_finger == -1:
				stick_finger = event.index
				stick_origin = Vector2(clampf(event.position.x, 82, 350), clampf(event.position.y, 360, 633))
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
			stick_vector = ((event.position - stick_origin) / (55.0 * game.settings.get("touch_scale", 1.0))).limit_length(1)
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
		var radius: float = (49.0 if action == "fire" else 34.0) * float(game.settings.get("touch_scale", 1.0))
		if point.distance_to(button_centers[action]) <= radius:
			return action
	return ""

func trigger(action: String) -> void:
	match action:
		"dash": game.player.dash()
		"pulse": game.player.pulse()
		"swap": game.swap_weapon()
		"interact": game.interact()

func _draw() -> void:
	if game == null or game.state != "playing":
		return
	var alpha: float = game.settings.get("touch_opacity", 0.65)
	var scale_value: float = game.settings.get("touch_scale", 1.0)
	var center = stick_origin if stick_finger != -1 else Vector2(152, 610)
	draw_circle(center, 59 * scale_value, Color(0.06, 0.06, 0.15, alpha))
	draw_arc(center, 59 * scale_value, 0, TAU, 32, Color(0.3, 0.6, 0.8, alpha), 2)
	draw_circle(center + stick_vector * 39 * scale_value, 22 * scale_value, Color(0.3, 0.65, 0.85, alpha))
	var font: Font = game.ui.font
	var names = {"fire": "BẮN", "dash": "DASH", "pulse": "PULSE", "swap": "ĐỔI", "interact": "DÙNG"}
	for action in button_centers:
		if action == "interact" and game.interaction_label().is_empty():
			continue
		var at: Vector2 = button_centers[action]
		var size_value: float = (49.0 if action == "fire" else 34.0) * scale_value
		var ready: bool = action != "pulse" or game.player.resonance >= 100
		if action == "dash":
			ready = game.player.dash_cooldown <= 0
		var color = Color("35e7ff") if ready else Color("70688c")
		color.a = alpha
		draw_circle(at, size_value, Color(0.075, 0.04, 0.16, alpha))
		draw_arc(at, size_value, 0, TAU, 32, color, 2)
		var label_text: String = names[action]
		if action == "dash" and not ready:
			label_text = "%.1f" % game.player.dash_cooldown
		var width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, at + Vector2(-width / 2, 6), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
