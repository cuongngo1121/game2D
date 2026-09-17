extends SceneTree
## Gameplay HUD placement contract: F8 opens a drag/resize surface, changes are
## kept in the runtime settings while editing, and the second F8 persists them.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = false
	root.add_child(game)
	await process_frame
	var layout_path := "user://tests/hud_layout_%d.json" % OS.get_process_id()
	game.store = SaveScript.new(layout_path)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.ui.hud_layout_positions.clear()
	game.ui.hud_layout_scales.clear()
	game.new_run(921774, true, false, false)
	await _frames(2)

	var editor = game.ui.hud_layout_editor
	var hp: Control = game.ui.hud_layout_groups.get("hp")
	var shield: Control = game.ui.hud_layout_groups.get("shield")
	var energy: Control = game.ui.hud_layout_groups.get("energy")
	var title_group: Control = game.ui.hud_layout_groups.get("title")
	var pause_group: Control = game.ui.hud_layout_groups.get("pause")
	var move_button: Control = game.controls.touch_layout_target("move")
	var fire_button: Control = game.controls.touch_layout_target("fire")
	var dash_button: Control = game.controls.touch_layout_target("dash")
	var pulse_button: Control = game.controls.touch_layout_target("pulse")
	_check(editor != null, "Debug gameplay creates the HUD placement editor")
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "HUD starts in normal mode without placement overlays")
	var expected_hud_layout: Dictionary = game.store.default_profile().settings.get("hud_layout", {})
	var expected_hp_position := _layout_position(expected_hud_layout, "hp", Vector2(84, 44))
	var expected_shield_position := _layout_position(expected_hud_layout, "shield", Vector2(84, 62))
	var expected_energy_position := _layout_position(expected_hud_layout, "energy", Vector2(84, 80))
	var expected_pause_position := _layout_position(expected_hud_layout, "pause", Vector2(1180, 6))
	var expected_pause_scale := _layout_scale(expected_hud_layout, "pause")
	_check(hp != null and shield != null and energy != null and hp.position.is_equal_approx(expected_hp_position) and shield.position.is_equal_approx(expected_shield_position) and energy.position.is_equal_approx(expected_energy_position), "HP, Shield and Mana use separate shipped HUD transforms")
	_check(hp != null and shield != null and energy != null and game.ui.bars.hp.size.y > 8.0 and game.ui.bars.hp.size.x < 220.0 and game.ui.bars.shield.size.y > 8.0 and game.ui.bars.energy.size.y > 8.0, "HP, Shield and Mana remain separate live bars")
	_check(title_group != null and game.ui.title_label.text == "ECHO TERMINAL", "Gameplay title shows the current area name without its numeric prefix")
	_check(title_group != null and title_group.size.x < 300.0 and title_group.size.y <= 40.0 and game.ui.title_label.position == Vector2.ZERO and game.ui.title_label.size == title_group.size and game.ui.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and game.ui.title_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Gameplay title container hugs its text and keeps the text centered")
	if title_group != null:
		# Reproduce a player profile that saved the title group while another map
		# name was active. The title must keep one visual anchor as its text width
		# changes across all five areas.
		var saved_title_position := title_group.position
		var saved_title_scale := title_group.scale
		game.ui.hud_layout_positions["title"] = saved_title_position
		game.ui.hud_layout_scales["title"] = saved_title_scale
		var expected_title_center := saved_title_position + Vector2(title_group.size.x * saved_title_scale.x * 0.5, title_group.size.y * saved_title_scale.y * 0.5)
		for stage_index in range(5):
			game.start_debug_stage(stage_index)
			await _frames(2)
			var stage_title_group: Control = game.ui.hud_layout_groups.get("title")
			if stage_title_group != null:
				_check(game.ui.title_label.position == Vector2.ZERO and game.ui.title_label.size == stage_title_group.size and game.ui.title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and game.ui.title_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and game.ui.title_label.autowrap_mode == TextServer.AUTOWRAP_OFF, "Area %d keeps the map title label centered inside its container" % (stage_index + 1))
				var expected_title_color := Color(str(game.content.stages[stage_index].color))
				_check(game.ui.title_label.get_theme_color("font_color") == expected_title_color and game.ui.title_label.get_theme_color("font_outline_color") == Color(0, 0, 0, 0) and game.ui.title_label.get_theme_color("font_shadow_color") == Color(0, 0, 0, 0) and game.ui.title_label.get_theme_constant("outline_size") == 0 and game.ui.title_label.get_theme_constant("shadow_outline_size") == 0 and game.ui.title_label.get_theme_constant("shadow_offset_x") == 0 and game.ui.title_label.get_theme_constant("shadow_offset_y") == 0, "Area %d keeps its map theme color without title glow" % (stage_index + 1))
				var actual_title_center := stage_title_group.position + Vector2(stage_title_group.size.x * stage_title_group.scale.x * 0.5, stage_title_group.size.y * stage_title_group.scale.y * 0.5)
				_check(is_equal_approx(actual_title_center.x, expected_title_center.x) and is_equal_approx(actual_title_center.y, expected_title_center.y), "Area %d keeps the saved gameplay title anchor centered" % (stage_index + 1))
			else:
				_check(false, "Area %d keeps the saved gameplay title anchor centered" % (stage_index + 1))
	_check(game.ui.health_label == null, "HUD omits the character portrait and numeric HP/shield/mana row")
	_check(game.ui.room_label != null and not game.ui.room_label.visible and game.ui.room_label.text.is_empty(), "The room-credit-time line is removed from the gameplay HUD")
	_check(game.ui.current_weapon_box != null and game.ui.current_weapon_preview != null and game.ui.current_weapon_button != null and game.ui.weapon_label == null and game.ui.secondary_weapon_preview == null, "Current weapon area has a stable live model and a direct swap hitbox")
	_check(game.ui.hud_layout_groups.get("status") == null and game.ui.hud_layout_groups.get("hint") == null and game.ui.beat_display == null, "Gameplay HUD removes the status, hint and beat-marker controls")
	var expected_fire_center := _touch_center(fire_button)
	var expected_dash_center := _touch_center(dash_button)
	var expected_pulse_center := _touch_center(pulse_button)
	_check(move_button != null and fire_button != null and dash_button != null and pulse_button != null and game.controls.button_centers.fire.is_equal_approx(expected_fire_center) and game.controls.button_centers.dash.is_equal_approx(expected_dash_center) and game.controls.button_centers.pulse.is_equal_approx(expected_pulse_center), "Movement, fire, dash and pulse expose independent shipped touch targets")
	_check(game.ui.map_button == null and game.ui.minimap == null and game.ui.menu_button == null, "Map, room-number strip and gameplay Menu button are absent from gameplay HUD")
	_check(pause_group != null and pause_group.position.is_equal_approx(expected_pause_position) and pause_group.scale.is_equal_approx(expected_pause_scale), "Gameplay pause action uses its saved HUD transform")
	var pause_is_cyan := false
	if game.ui.pause_button != null:
		var pause_style: StyleBox = game.ui.pause_button.get_theme_stylebox("normal")
		pause_is_cyan = pause_style is StyleBoxFlat and (pause_style as StyleBoxFlat).border_color == Color("35e7ff") and game.ui.pause_button.get_theme_color("font_color") == Color("35e7ff")
	var pause_glyph_is_bold: bool = game.ui.pause_button != null and game.ui.pause_button.get_theme_font("font") == game.ui.bold and game.ui.pause_button.get_theme_font_size("font_size") == 46
	_check(game.ui.pause_button != null and game.ui.pause_button.size == Vector2(86, 86) and pause_is_cyan and pause_glyph_is_bold, "Gameplay pause action uses a large bold cyan circular target")
	_check(game.ui.sound_toggle_button != null and not game.ui.sound_toggle_button.visible and game.ui.music_toggle_button != null and not game.ui.music_toggle_button.visible, "SFX and music buttons stay hidden in the regular gameplay HUD")
	if game.ui.current_weapon_button != null:
		var active_slot_before: int = game.active_slot
		game.ui.current_weapon_button.emit_signal("pressed")
		_check(game.active_slot == (active_slot_before + 1) % game.weapons.size(), "Tapping the live weapon slot changes the active weapon")
	for stage_index in range(5):
		game.start_debug_stage(stage_index)
		await _frames(2)
		_check(not game.ui.sound_toggle_button.visible and not game.ui.music_toggle_button.visible, "Area %d debug gameplay HUD omits the SFX and music buttons" % (stage_index + 1))

	var toggle := _key(KEY_F8)
	game.ui._unhandled_input(toggle)
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "First F8 enables HUD drag and resize mode")
	if editor != null and hp != null and shield != null and energy != null:
		var initial_position: Vector2 = hp.position
		var shield_position: Vector2 = shield.position
		var energy_position: Vector2 = energy.position
		var body_offset := Vector2(40.0, hp.size.y * hp.scale.y * 0.5)
		_drag_mouse(editor, initial_position + body_offset, initial_position + body_offset + Vector2(80, 55))
		_check(hp.position == initial_position + Vector2(80, 55), "Dragging a HUD frame moves the selected resource group")
		_check(shield.position == shield_position and energy.position == energy_position, "Moving one resource bar leaves the other two in place")
		_check(game.ui.hud_layout_positions.get("hp") == hp.position, "Independent HP movement is reflected in the pending runtime layout")
		var before_scale: Vector2 = hp.scale
		var handle := Rect2(hp.position, hp.size * hp.scale).end - Vector2(2, 2)
		_drag_mouse(editor, handle, handle + Vector2(60, 24))
		_check(hp.scale.x > before_scale.x and hp.scale.y > before_scale.y, "Dragging the lower-right handle changes the selected bar size")
		var before_horizontal_scale: Vector2 = hp.scale
		var right_edge := Rect2(hp.position, hp.size * hp.scale).end
		var right_handle := Vector2(right_edge.x, hp.position.y + hp.size.y * hp.scale.y * 0.5)
		_drag_mouse(editor, right_handle, right_handle + Vector2(36, 0))
		_check(hp.scale.x > before_horizontal_scale.x and is_equal_approx(hp.scale.y, before_horizontal_scale.y), "Dragging a side handle stretches one resource bar on one axis only")

	if editor != null and move_button != null:
		var initial_move_position: Vector2 = move_button.position
		_drag_mouse(editor, initial_move_position + Vector2(40, 40), initial_move_position + Vector2(90, 70))
		_check(move_button.position == initial_move_position + Vector2(50, 30), "Dragging the movement target changes only its position")
		var before_move_scale: Vector2 = move_button.scale
		var move_handle := Rect2(move_button.position, move_button.size * move_button.scale).end - Vector2(2, 2)
		_drag_mouse(editor, move_handle, move_handle + Vector2(36, 24))
		_check(move_button.scale.x > before_move_scale.x and is_equal_approx(move_button.scale.x, move_button.scale.y), "Resizing a touch target changes its size while preserving a round control")

	if editor != null and pause_group != null:
		var initial_pause_position: Vector2 = pause_group.position
		_drag_mouse(editor, initial_pause_position + Vector2(20, 20), initial_pause_position + Vector2(30, 30))
		_check(pause_group.position == initial_pause_position + Vector2(10, 10), "Dragging the HUD editor moves the pause button")
		var before_pause_scale: Vector2 = pause_group.scale
		var pause_handle := Rect2(pause_group.position, pause_group.size * pause_group.scale).end - Vector2(2, 2)
		_drag_mouse(editor, pause_handle, pause_handle + Vector2(8, 6))
		_check(pause_group.scale.x > before_pause_scale.x and pause_group.scale.y > before_pause_scale.y, "Resizing the HUD editor changes the pause button size")

	game.ui._unhandled_input(toggle)
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "Second F8 saves the layout and returns to normal gameplay")
	var encoded: Variant = game.settings.get("hud_layout", {}).get("hp", [])
	_check(encoded is Array and encoded.size() == 4, "Saved HUD layout stores independent bar position and scale axes")
	if encoded is Array and encoded.size() == 4 and hp != null:
		_check(is_equal_approx(float(encoded[0]), hp.position.x) and is_equal_approx(float(encoded[1]), hp.position.y), "Saved HP position matches the moved bar")
		_check(is_equal_approx(float(encoded[2]), hp.scale.x) and is_equal_approx(float(encoded[3]), hp.scale.y), "Saved HP size matches the resized bar")
		var reloaded: Dictionary = SaveScript.new(layout_path).load_profile()
		var persisted: Variant = reloaded.settings.get("hud_layout", {}).get("hp", [])
		_check(persisted is Array and persisted.size() == 4 and is_equal_approx(float(persisted[0]), hp.position.x), "Independent HP layout survives a fresh profile load")
	var encoded_pause: Variant = game.settings.get("hud_layout", {}).get("pause", [])
	_check(encoded_pause is Array and encoded_pause.size() == 4, "Saved HUD layout stores the pause button position and size")
	if encoded_pause is Array and encoded_pause.size() == 4 and pause_group != null:
		_check(is_equal_approx(float(encoded_pause[0]), pause_group.position.x) and is_equal_approx(float(encoded_pause[1]), pause_group.position.y) and is_equal_approx(float(encoded_pause[2]), pause_group.scale.x) and is_equal_approx(float(encoded_pause[3]), pause_group.scale.y), "Saved pause layout matches the edited HUD control")
	var encoded_touch: Variant = game.settings.get("touch_layout", {}).get("move", [])
	_check(encoded_touch is Array and encoded_touch.size() == 4, "Saved touch layout stores movement position and size")
	if encoded_touch is Array and encoded_touch.size() == 4 and move_button != null:
		_check(is_equal_approx(float(encoded_touch[0]), move_button.position.x) and is_equal_approx(float(encoded_touch[1]), move_button.position.y) and is_equal_approx(float(encoded_touch[2]), move_button.scale.x) and is_equal_approx(float(encoded_touch[3]), move_button.scale.y), "Saved movement target matches the edited control")
		var reloaded_touch: Dictionary = SaveScript.new(layout_path).load_profile()
		var persisted_touch: Variant = reloaded_touch.settings.get("touch_layout", {}).get("move", [])
		_check(persisted_touch is Array and persisted_touch.size() == 4 and is_equal_approx(float(persisted_touch[0]), move_button.position.x), "Touch layout survives a fresh profile load")

	game.return_to_menu()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD LAYOUT EDITOR PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("HUD LAYOUT EDITOR FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func _drag_mouse(editor, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	editor._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	editor._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	editor._gui_input(release)

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _layout_position(layout: Dictionary, item_id: String, fallback: Vector2) -> Vector2:
	var encoded: Variant = layout.get(item_id, [])
	if not encoded is Array or encoded.size() < 2:
		return fallback
	return Vector2(float(encoded[0]), float(encoded[1]))


func _layout_scale(layout: Dictionary, item_id: String) -> Vector2:
	var encoded: Variant = layout.get(item_id, [])
	if not encoded is Array or encoded.size() < 4:
		return Vector2.ONE
	return Vector2(float(encoded[2]), float(encoded[3]))


func _touch_center(target: Control) -> Vector2:
	if target == null:
		return Vector2.ZERO
	return Rect2(target.position, target.size * target.scale).get_center()
