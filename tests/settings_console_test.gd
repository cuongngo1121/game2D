extends SceneTree
## Settings-console contract: static art owns only the exterior chassis. Each
## dynamic setting row or action is its own simple Godot runtime component.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const SETTINGS_ART_PATH := "res://assets/backgrounds/settings_calibration_console_v2.png"
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
const CYAN := Color("35e7ff")
const LED_PURPLE := Color("d65dff")
const SETTINGS_PLAIN_HEADINGS := [
	"CÀI ĐẶT",
	"◼  ÂM THANH & TRẢI NGHIỆM",
	"◼  ĐIỀU KHIỂN & GIAO DIỆN",
]

var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ui.show_settings("menu")
	await _frames(3)

	var sliders := _sliders()
	var toggles := _toggles()
	var save_action := _save_action()
	_check(_has_settings_art(), "Settings uses the clean exterior calibration-console artwork")
	_check(_settings_headings_have_no_led_effect(), "Settings title and section headings keep only their text color")
	_check(_settings_text_uses_section_colors(sliders, toggles), "Settings text follows the cyan audio and purple controls themes")
	_check(save_action != null and save_action.get_theme_font("font") == game.ui.bold, "Settings save action uses the bold font")
	_check(sliders.size() == 6, "Settings retains all six functional sliders")
	_check(_slider_ids(sliders) == ["music", "sfx", "latency_ms", "screen_shake", "touch_scale", "touch_opacity"], "Slider order and setting bindings remain stable")
	_check(toggles.size() == 3, "Settings retains all three functional switches")
	_check(_toggle_ids(toggles) == ["auto_aim", "vibration", "reduced_flashes"], "Switch order and setting bindings remain stable")
	_check(_art_rects_are_operable(sliders, toggles, save_action), "All artwork-aligned controls stay inside the 1280x720 screen without overlap")
	_check(_sliders_share_component_shells(sliders), "Each slider keeps its label, value, and track inside one runtime component")
	_check(_only_small_runtime_setting_shells(), "The detailed exterior remains static while runtime setting shells stay small and self-contained")
	_check(_sliders_keep_led_fill(sliders), "Slider rails use the project LED drawing in normal and pressed states instead of Godot gray surfaces")
	_check(_value_chips_fit_content(sliders), "Value chips stay compact, centered, and free of LED text effects")
	_check(_sliders_have_neutral_focus(sliders), "Sliders keep focus visually neutral")
	_check(_toggles_have_neutral_focus(toggles), "Switches keep focus and hover visually neutral")
	_check(save_action != null and _has_neutral_focus_style(save_action), "The save action has no separate focus style")
	_check(save_action != null and _has_neutral_hover_style(save_action), "The save action has no hover overlay")
	_check(game.ui.settings_layout_editor == null, "Test-mode Settings keeps the temporary placement layer out of normal control checks")

	var music_slider := _slider("music")
	if music_slider != null:
		music_slider.value = 0.65
		await _frames(1)
	_check(music_slider != null and is_equal_approx(float(game.settings.music), 0.65), "Music slider still writes its live setting")
	_check(_value_text("music") == "65%", "Music value chip updates with the slider")

	var latency_slider := _slider("latency_ms")
	if latency_slider != null:
		latency_slider.value = 125.0
		await _frames(1)
	_check(latency_slider != null and is_equal_approx(float(game.settings.latency_ms), 125.0), "Latency slider still writes the rhythm offset setting")
	_check(_value_text("latency_ms") == "125 ms", "Latency value chip keeps its unit")
	_check(_value_chips_fit_content(_sliders()), "Value chips reflow cleanly after a slider value changes")

	var vibration_toggle := _toggle("vibration")
	var vibration_target := false
	if vibration_toggle != null:
		vibration_target = not vibration_toggle.button_pressed
		vibration_toggle.button_pressed = vibration_target
		vibration_toggle.emit_signal("toggled", vibration_target)
		await _frames(1)
	_check(vibration_toggle != null and bool(game.settings.vibration) == vibration_target, "Vibration switch still writes its live setting")
	_check(vibration_toggle != null and _has_neutral_focus_style(vibration_toggle), "A switched control remains free of focus styling")

	if save_action != null:
		save_action.emit_signal("pressed")
		await _frames(2)
	_check(game.state == "menu", "The artwork save hitbox preserves the existing save-and-return behavior")

	game.queue_free()
	await process_frame
	await _verify_temporary_layout_editor_in_normal_game()
	if failures.is_empty():
		print("SETTINGS CONSOLE PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SETTINGS CONSOLE FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _has_settings_art() -> bool:
	for child in game.ui.overlay.get_children():
		if child is TextureRect and child.texture != null and child.texture.resource_path == SETTINGS_ART_PATH:
			return true
	return false

func _settings_headings_have_no_led_effect() -> bool:
	var found := 0
	for child in game.ui.overlay.find_children("*", "", true, false):
		if not child is Label or not SETTINGS_PLAIN_HEADINGS.has(child.text):
			continue
		found += 1
		if child.get_theme_constant("outline_size") != 0 or child.get_theme_constant("shadow_outline_size") != 0:
			return false
	return found == SETTINGS_PLAIN_HEADINGS.size()

func _settings_text_uses_section_colors(sliders: Array[HSlider], toggles: Array[Button]) -> bool:
	var expected_headings := {
		"CÀI ĐẶT": CYAN,
		"◼  ÂM THANH & TRẢI NGHIỆM": CYAN,
		"◼  ĐIỀU KHIỂN & GIAO DIỆN": LED_PURPLE,
	}
	var found_headings := 0
	for child in game.ui.overlay.find_children("*", "", true, false):
		if child is Label and expected_headings.has(child.text):
			found_headings += 1
			if child.get_theme_color("font_color") != expected_headings[child.text]:
				return false
	if found_headings != expected_headings.size():
		return false

	for key in ["music", "sfx", "latency_ms", "screen_shake"]:
		if not _slider_text_has_color(str(key), CYAN):
			return false
	for key in ["touch_scale", "touch_opacity"]:
		if not _slider_text_has_color(str(key), LED_PURPLE):
			return false

	for toggle in toggles:
		var original_state := toggle.button_pressed
		game.ui.apply_toggle_visual(toggle, false, LED_PURPLE)
		if toggle.get_theme_color("font_color") != LED_PURPLE or toggle.get_theme_color("font_hover_color") != LED_PURPLE:
			return false
		game.ui.apply_toggle_visual(toggle, true, LED_PURPLE)
		if toggle.get_theme_color("font_color") != LED_PURPLE or toggle.get_theme_color("font_hover_color") != LED_PURPLE:
			return false
		game.ui.apply_toggle_visual(toggle, original_state, LED_PURPLE)
	return true

func _slider_text_has_color(key: String, expected: Color) -> bool:
	var slider := _slider(key)
	if slider == null:
		return false
	var shell := slider.get_parent()
	if shell == null:
		return false
	var name_label := shell.get_node_or_null(NodePath("Settings_%s_Label" % key))
	var value_label := shell.get_node_or_null(NodePath("Settings_%s_Value" % key))
	return name_label is Label and value_label is Label and name_label.get_theme_color("font_color") == expected and value_label.get_theme_color("font_color") == expected

func _verify_temporary_layout_editor_in_normal_game() -> void:
	var calibration_game = MainScene.instantiate()
	calibration_game.test_mode = false
	root.add_child(calibration_game)
	await process_frame
	# Keep the persistence assertion isolated from the developer's real profile.
	var layout_path := "user://tests/settings_layout_%d.json" % OS.get_process_id()
	calibration_game.store = SaveScript.new(layout_path)
	calibration_game.profile = calibration_game.store.default_profile()
	calibration_game.settings = calibration_game.profile.settings
	calibration_game.ui.settings_layout_positions.clear()
	calibration_game.ui.show_settings("menu")
	await _frames(2)
	var editor = calibration_game.ui.settings_layout_editor
	var audio_group: Control = calibration_game.ui.settings_layout_groups.get("audio")
	_check(editor != null and not editor.is_editor_active(), "Normal Settings opens with the saved layout and normal controls enabled")
	_check(editor != null and not editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Placement editor stays transparent until F7 explicitly enables it")
	_check(audio_group != null and calibration_game.ui.settings_layout_groups.size() == 4, "Settings editor receives the four movable runtime groups")
	var toggle_editor := InputEventKey.new()
	toggle_editor.physical_keycode = KEY_F7
	toggle_editor.pressed = true
	calibration_game.ui._unhandled_input(toggle_editor)
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "First F7 enables drag mode and blocks accidental setting edits")
	if editor != null and audio_group != null:
		var initial_audio_position: Vector2 = audio_group.position
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = initial_audio_position + Vector2(40.0, 40.0)
		editor._gui_input(press)
		var motion := InputEventMouseMotion.new()
		motion.position = initial_audio_position + Vector2(80.0, 70.0)
		editor._gui_input(motion)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = motion.position
		editor._gui_input(release)
		await _frames(1)
		_check(audio_group.position == initial_audio_position + Vector2(40.0, 30.0), "Temporary editor moves the complete audio group in the real Settings screen")
		_check(calibration_game.ui.settings_layout_positions.get("audio") == audio_group.position, "Moved layout coordinate is retained for this app session")
		var music_slider := _slider_in(calibration_game.ui.overlay, "music")
		_check(music_slider != null and music_slider.get_meta("settings_art_rect") == Rect2(music_slider.get_global_position(), music_slider.size), "Moving a group refreshes its slider hitbox metadata")
	if editor != null:
		calibration_game.ui._unhandled_input(toggle_editor)
		_check(not editor.is_editor_active() and not editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Second F7 saves the layout and returns to normal Settings controls")
		var encoded_layout: Variant = calibration_game.settings.get("settings_layout_positions", {}).get("audio", [])
		_check(encoded_layout is Array and encoded_layout.size() == 2 and is_equal_approx(float(encoded_layout[0]), audio_group.position.x) and is_equal_approx(float(encoded_layout[1]), audio_group.position.y), "Second F7 serializes the moved coordinate into runtime settings")
		var reloaded_profile: Dictionary = SaveScript.new(layout_path).load_profile()
		var saved_audio: Variant = reloaded_profile.settings.get("settings_layout_positions", {}).get("audio", [])
		_check(saved_audio is Array and saved_audio.size() == 2 and is_equal_approx(float(saved_audio[0]), audio_group.position.x) and is_equal_approx(float(saved_audio[1]), audio_group.position.y), "Saved layout coordinates survive a fresh profile load")
		var saved_audio_position: Vector2 = audio_group.position
		calibration_game.ui.show_settings("menu")
		await _frames(2)
		var reopened_audio: Control = calibration_game.ui.settings_layout_groups.get("audio")
		_check(reopened_audio != null and reopened_audio.position == saved_audio_position, "Re-entering Settings restores the last saved group position")
	calibration_game.queue_free()
	await process_frame

func _slider_in(parent: Control, key: String) -> HSlider:
	for child in parent.find_children("*", "", true, false):
		if child is HSlider and child.get_meta("settings_slider_key", "") == key:
			return child
	return null

func _sliders() -> Array[HSlider]:
	var controls: Array[HSlider] = []
	for child in game.ui.overlay.find_children("*", "", true, false):
		if child is HSlider and child.visible and child.has_meta("settings_slider_key"):
			controls.append(child)
	controls.sort_custom(func(left: HSlider, right: HSlider):
		var left_at := left.get_global_position()
		var right_at := right.get_global_position()
		return left_at.x < right_at.x or (is_equal_approx(left_at.x, right_at.x) and left_at.y < right_at.y)
	)
	return controls

func _toggles() -> Array[Button]:
	var controls: Array[Button] = []
	for child in game.ui.overlay.find_children("*", "", true, false):
		if child is Button and child.visible and child.has_meta("settings_toggle_key"):
			controls.append(child)
	controls.sort_custom(func(left: Button, right: Button): return left.position.y < right.position.y)
	return controls

func _slider_ids(sliders: Array[HSlider]) -> Array[String]:
	var ids: Array[String] = []
	for slider in sliders:
		ids.append(str(slider.get_meta("settings_slider_key")))
	return ids

func _toggle_ids(toggles: Array[Button]) -> Array[String]:
	var ids: Array[String] = []
	for toggle in toggles:
		ids.append(str(toggle.get_meta("settings_toggle_key")))
	return ids

func _slider(key: String) -> HSlider:
	for slider in _sliders():
		if str(slider.get_meta("settings_slider_key")) == key:
			return slider
	return null

func _toggle(key: String) -> Button:
	for toggle in _toggles():
		if str(toggle.get_meta("settings_toggle_key")) == key:
			return toggle
	return null

func _save_action() -> Button:
	for child in game.ui.overlay.find_children("*", "", true, false):
		if child is Button and child.visible and child.get_meta("settings_action_id", "") == "save_and_return":
			return child
	return null

func _value_text(key: String) -> String:
	for child in game.ui.overlay.find_children("*", "", true, false):
		if child is Label and child.get_meta("settings_value_key", "") == key:
			return child.text
	return ""

func _art_rects_are_operable(sliders: Array[HSlider], toggles: Array[Button], save_action: Button) -> bool:
	var rects: Array[Rect2] = []
	for slider in sliders:
		var shell := slider.get_parent()
		if shell == null or not shell.has_meta("settings_component_rect"):
			return false
		var component_rect: Rect2 = shell.get_meta("settings_component_rect")
		var track_rect: Rect2 = slider.get_meta("settings_art_rect")
		if not VIEWPORT_RECT.encloses(component_rect) or not component_rect.encloses(track_rect):
			return false
		rects.append(component_rect)
	for toggle in toggles:
		var rect: Rect2 = toggle.get_meta("settings_art_rect")
		if not VIEWPORT_RECT.encloses(rect):
			return false
		rects.append(rect)
	if save_action == null:
		return false
	var save_rect: Rect2 = save_action.get_meta("settings_art_rect")
	if not VIEWPORT_RECT.encloses(save_rect):
		return false
	rects.append(save_rect)
	for first_index in range(rects.size()):
		for second_index in range(first_index + 1, rects.size()):
			if rects[first_index].intersects(rects[second_index]):
				return false
	return true

func _sliders_share_component_shells(sliders: Array[HSlider]) -> bool:
	for slider in sliders:
		var key := str(slider.get_meta("settings_slider_key"))
		var shell := slider.get_parent()
		if not (shell is Panel and shell.get_meta("settings_component_key", "") == key):
			return false
		if shell.get_node_or_null(NodePath("Settings_%s_Label" % key)) == null:
			return false
		if shell.get_node_or_null(NodePath("Settings_%s_Value" % key)) == null:
			return false
	return true

func _only_small_runtime_setting_shells() -> bool:
	for child in game.ui.overlay.get_children():
		if child is Panel and child.size.x >= 500.0 and child.size.y >= 200.0:
			return false
	return true

func _sliders_keep_led_fill(sliders: Array[HSlider]) -> bool:
	for slider in sliders:
		var key := str(slider.get_meta("settings_slider_key"))
		var shell := slider.get_parent()
		if shell == null:
			return false
		var visual := shell.get_node_or_null(NodePath("Settings_%s_LedFill" % key))
		if visual == null or visual.get_meta("settings_slider_visual_key", "") != key:
			return false
		if not (slider.get_theme_stylebox("slider") is StyleBoxEmpty):
			return false
		if not (slider.get_theme_stylebox("grabber_area") is StyleBoxEmpty):
			return false
		if not (slider.get_theme_stylebox("grabber_area_highlighted") is StyleBoxEmpty):
			return false
	return true

func _value_chips_fit_content(sliders: Array[HSlider]) -> bool:
	for slider in sliders:
		var key := str(slider.get_meta("settings_slider_key"))
		var shell := slider.get_parent()
		if shell == null:
			return false
		var chip := shell.get_node_or_null(NodePath("Settings_%s_ValueChip" % key))
		var value_label := shell.get_node_or_null(NodePath("Settings_%s_Value" % key))
		if not (chip is Panel and value_label is Label):
			return false
		if chip.size.x < 54.0 or chip.size.x > 96.0:
			return false
		if value_label.position != chip.position or value_label.size != chip.size:
			return false
		if value_label.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or value_label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
			return false
		if value_label.get_theme_constant("outline_size") != 0 or value_label.get_theme_constant("shadow_outline_size") != 0:
			return false
	return true

func _sliders_have_neutral_focus(sliders: Array[HSlider]) -> bool:
	for slider in sliders:
		if not (slider.get_theme_stylebox("focus") is StyleBoxEmpty):
			return false
	return true

func _toggles_have_neutral_focus(toggles: Array[Button]) -> bool:
	for toggle in toggles:
		if not _has_neutral_focus_style(toggle) or not _has_neutral_hover_style(toggle):
			return false
	return true

func _has_neutral_focus_style(control: Control) -> bool:
	if control == null:
		return false
	return control.get_theme_stylebox("focus") == control.get_theme_stylebox("normal") and control.get_theme_color("font_focus_color") == control.get_theme_color("font_color")

func _has_neutral_hover_style(control: Control) -> bool:
	if control == null:
		return false
	return control.get_theme_stylebox("hover") == control.get_theme_stylebox("normal") and control.get_theme_color("font_hover_color") == control.get_theme_color("font_color")

func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
