extends SceneTree
## Armory placement contract: F9 exposes the title and every card's STT,
## weapon name, and loadout action as independently draggable/resizable controls.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const CYAN := Color("35e7ff")
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))

var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = false
	root.add_child(game)
	await _frames(2)
	var layout_path := "user://tests/armory_layout_%d.json" % OS.get_process_id()
	game.store = SaveScript.new(layout_path)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.profile.meta.unlocked = game.all_weapon_ids()
	game.profile.meta.shards = 64
	game.starter = "smg"
	game.profile.meta.starter = "smg"
	game.ui.armory_layout_positions.clear()
	game.ui.armory_layout_scales.clear()
	game.ui.show_unlocks()
	await _frames(3)

	var controls: Dictionary = game.ui.armory_layout_controls
	var expected_control_count: int = 1 + game.content.weapons.size() * 3
	_check(game.ui.armory_layout_editor != null, "Debug armory creates the placement editor")
	_check(game.ui.armory_layout_editor != null and not game.ui.armory_layout_editor.is_editor_active() and not game.ui.armory_layout_editor.visible, "Armory starts in normal mode without placement overlays")
	_check(controls.size() == expected_control_count, "Armory registers the title and three independent controls for every weapon")

	var title: Control = controls.get("title")
	_check(title is Label and title.get_theme_color("font_color") == CYAN and title.get_theme_font("font") == game.ui.bold and title.get_theme_color("font_outline_color") == Color(0, 0, 0, 0) and title.get_theme_color("font_shadow_color") == Color(0, 0, 0, 0) and title.get_theme_constant("outline_size") == 0 and title.get_theme_constant("shadow_outline_size") == 0, "Armory title uses flat cyan bold text without the LED effect")

	for weapon in game.content.weapons:
		var weapon_id := str(weapon.id)
		var stt: Control = controls.get("%s_stt" % weapon_id)
		var name_label: Control = controls.get("%s_name" % weapon_id)
		var action: Control = controls.get("%s_action" % weapon_id)
		_check(stt != null and name_label != null and action != null, "%s exposes STT, name, and action layout targets" % weapon_id)
		_check(name_label is Label and name_label.get_theme_color("font_color") == CYAN and name_label.get_theme_font("font") == game.ui.bold and name_label.autowrap_mode == TextServer.AUTOWRAP_OFF, "%s weapon name uses cyan bold single-line text" % weapon_id)
		_check(action is Button and action.get_meta("armory_equip_weapon_id", "") == weapon_id and action.get_theme_font("font") == game.ui.bold and action.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s action is a centered bold native button" % weapon_id)
		if weapon_id == "pistol":
			_check(stt.get_theme_color("font_color") == CYAN and action.get_theme_color("font_color") == CYAN, "Weapon 1 STT and default action use the same cyan color")
		if action != null:
			var action_rect: Rect2 = action.get_meta("armory_action_rect")
			var actual_action_rect := Rect2(action.position, action.size)
			_check(_rects_match(action_rect, actual_action_rect), "%s action starts aligned with its authored status dock" % weapon_id)

	var return_button: Button = game.ui.overlay.get_node_or_null("Armory_Return_Hitbox")
	_check(return_button != null and return_button.text == "TRỞ LẠI MENU" and not return_button.text.contains("<") and not return_button.text.contains("‹"), "Armory return button removes the leading arrow")
	_check(return_button != null and return_button.get_theme_font("font") == game.ui.bold and return_button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "Armory return button is bold and centered")

	var editor = game.ui.armory_layout_editor
	var toggle := _key(KEY_F9)
	game.ui._unhandled_input(toggle)
	await _frames(1)
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "F9 enables armory drag and resize mode")

	var name_target: Control = controls.get("pistol_name")
	if editor != null and title != null and name_target != null:
		var initial_name_position: Vector2 = name_target.position
		_double_click_mouse(editor, title.position + Vector2(120, 25))
		_check(editor.solo_item_id() == "title", "Double-clicking a component enters single-component edit mode")
		_drag_mouse(editor, initial_name_position + Vector2(50, 10), initial_name_position + Vector2(90, 30))
		_check(name_target.position == initial_name_position, "Single-component mode prevents other components from being moved")
		_double_click_mouse(editor, title.position + Vector2(120, 25))
		_check(editor.solo_item_id().is_empty(), "Double-clicking the selected component again restores the full editor")

	if editor != null and title != null:
		var initial_title_position: Vector2 = title.position
		_drag_mouse(editor, initial_title_position + Vector2(120, 25), initial_title_position + Vector2(160, 55))
		_check(title.position == initial_title_position + Vector2(40, 30), "Dragging the armory title moves only the title control")
		_check(game.ui.armory_layout_positions.get("title") == title.position, "Title movement is reflected in the pending armory layout")

	if editor != null and name_target != null:
		var before_scale: Vector2 = name_target.scale
		var handle := Rect2(name_target.position, name_target.size * name_target.scale).end - Vector2(2, 2)
		_drag_mouse(editor, handle, handle + Vector2(30, 12))
		_check(name_target.scale.x > before_scale.x and name_target.scale.y > before_scale.y, "Dragging a weapon name corner changes its size")
		_check(game.ui.armory_layout_scales.get("pistol_name") == name_target.scale, "Weapon name resizing is reflected in the pending armory layout")

	game.ui._unhandled_input(toggle)
	await _frames(2)
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "Second F9 saves the armory layout and returns to normal mode")
	var encoded_title: Variant = game.settings.get("armory_layout", {}).get("title", [])
	_check(encoded_title is Array and encoded_title.size() == 4, "Saved armory layout stores title position and scale")
	if encoded_title is Array and encoded_title.size() == 4 and title != null:
		_check(is_equal_approx(float(encoded_title[0]), title.position.x) and is_equal_approx(float(encoded_title[1]), title.position.y), "Saved title position matches the moved control")
		var reloaded: Dictionary = SaveScript.new(layout_path).load_profile()
		var persisted: Variant = reloaded.settings.get("armory_layout", {}).get("title", [])
		_check(persisted is Array and persisted.size() == 4 and is_equal_approx(float(persisted[0]), title.position.x), "Armory layout survives a fresh profile load")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ARMORY LAYOUT EDITOR PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ARMORY LAYOUT EDITOR FAIL: %d/%d checks" % [failures.size(), checks])
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

func _double_click_mouse(editor, at: Vector2) -> void:
	for _click in range(2):
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = at
		editor._gui_input(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = at
		editor._gui_input(release)

func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _rects_match(left: Rect2, right: Rect2) -> bool:
	return left.position.distance_to(right.position) <= 0.01 and left.size.distance_to(right.size) <= 0.01
