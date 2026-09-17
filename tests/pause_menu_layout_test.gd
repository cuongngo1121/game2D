extends SceneTree
## Pause-menu artwork, action semantics, and debug placement contract.
## The placement editor is intentionally debug/PC-only; this test exercises the
## same runtime scene with an isolated profile and synthetic pointer events.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const PAUSE_BACKGROUND := "res://assets/backgrounds/pause_menu_overlay_v1.png"
const EXPECTED_POSITIONS := {
	"title": Vector2(405.0, 156.0),
	"continue": Vector2(405.0, 232.0),
	"settings": Vector2(405.0, 328.0),
	"menu": Vector2(405.0, 424.0),
}

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
	var layout_path := "user://tests/pause_menu_layout_%d.json" % OS.get_process_id()
	game.store = SaveScript.new(layout_path)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.ui.pause_layout_positions.clear()
	game.ui.pause_layout_scales.clear()
	game.new_run(468921, true, false, false)
	game.set_process(false)
	game.set_physics_process(false)
	game.pause_game()
	await _frames(2)

	_test_pause_surface()
	_test_pause_editor()
	await _test_pause_actions()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PAUSE MENU LAYOUT PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PAUSE MENU LAYOUT FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _group(item_id: String) -> Control:
	return game.ui.pause_layout_groups.get(item_id) as Control


func _hitbox(item_id: String) -> Button:
	var group := _group(item_id)
	return group.get_node_or_null(NodePath("Pause_%s_Hitbox" % item_id.capitalize())) as Button if group != null else null


func _test_pause_surface() -> void:
	var art := game.ui.overlay.get_node_or_null(NodePath("Pause_MenuArtwork")) as TextureRect
	var shade: ColorRect = null
	for child in game.ui.overlay.get_children():
		if child is ColorRect and child.has_meta("overlay_dim") and child.visible:
			shade = child as ColorRect
			break
	_check(art != null and art.texture != null and str(art.get_meta("pause_background_path", "")) == PAUSE_BACKGROUND, "Pause uses the selected three-button artwork asset")
	_check(shade != null and shade.color.a >= 0.8 and shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gameplay is dimmed by a non-interactive full-screen pause shade")
	_check(game.ui.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Pause overlay isolates gameplay input while open")
	var image := art.texture.get_image() if art != null and art.texture is Texture2D else null
	_check(image != null and image.get_pixel(0, 0).a < 0.05, "Pause artwork keeps transparent negative space outside the panel")
	var title_group := _group("title")
	var pause_title := title_group.get_node_or_null(NodePath("Pause_Title")) as Label if title_group != null else null
	_check(title_group != null and title_group.position.is_equal_approx(EXPECTED_POSITIONS["title"]) and title_group.size == Vector2(470.0, 62.0), "Pause title uses an independent authored layout frame")
	_check(pause_title != null and pause_title.text == "TẠM DỪNG" and pause_title.get_theme_color("font_color") == Color("35e7ff") and pause_title.get_theme_font("font") == game.ui.bold, "Pause title is bold cyan runtime text")
	var labels: Array[String] = []
	var hitboxes: Array[Button] = []
	for item_id: String in ["continue", "settings", "menu"]:
		var group := _group(item_id)
		var hitbox := _hitbox(item_id)
		var title := group.get_node_or_null(NodePath("Pause_%s_Label" % item_id.capitalize())) as Label if group != null else null
		if title != null:
			labels.append(title.text)
		if hitbox != null:
			hitboxes.append(hitbox)
		_check(group != null and group.position.is_equal_approx(EXPECTED_POSITIONS[item_id]) and group.size == Vector2(470.0, 76.0), "Pause %s group aligns with its authored artwork frame" % item_id)
		_check(title != null and hitbox != null and title.position == Vector2.ZERO + Vector2(0.0, 13.0) and hitbox.position == Vector2.ZERO and hitbox.size == Vector2(470.0, 76.0), "Pause %s keeps text and hitbox in one movable rectangle" % item_id)
		var text_only: bool = title != null and title.get_theme_constant("outline_size") == 0 and title.get_theme_constant("shadow_outline_size") == 0
		var invisible_hitbox: bool = hitbox != null and hitbox.get_meta("pause_hitbox_visual", "") == "invisible" and hitbox.get_theme_stylebox("normal") is StyleBoxEmpty and hitbox.get_theme_stylebox("hover") is StyleBoxEmpty and hitbox.get_theme_stylebox("pressed") is StyleBoxEmpty and hitbox.get_theme_stylebox("focus") is StyleBoxEmpty
		_check(text_only and invisible_hitbox, "Pause %s renders only centered text while keeping an invisible rectangular hitbox" % item_id)
	_check(labels == ["TIẾP TỤC", "CÀI ĐẶT", "MENU"], "Pause exposes exactly the three requested Vietnamese actions")
	_check(hitboxes.size() == 3 and hitboxes[0].focus_mode == Control.FOCUS_ALL and hitboxes[0].tooltip_text == "TIẾP TỤC", "Pause actions keep named keyboard/pointer targets")
	var all_centered := true
	for item_id: String in ["continue", "settings", "menu"]:
		var group := _group(item_id)
		all_centered = all_centered and is_equal_approx((group.position.x + group.size.x * group.scale.x * 0.5), 640.0)
	_check(all_centered, "All three pause action rectangles share the 1280px canvas center")


func _test_pause_editor() -> void:
	var editor = game.ui.pause_layout_editor
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "Pause placement editor starts hidden in normal debug gameplay")
	var toggle := _key(KEY_F10)
	game.ui._unhandled_input(toggle)
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "F10 opens pause placement mode and blocks accidental button presses")
	var group := _group("continue")
	var label := group.get_node_or_null(NodePath("Pause_Continue_Label")) as Label
	var hitbox := _hitbox("continue")
	if editor == null or group == null or label == null or hitbox == null:
		return
	var initial_position := group.position
	var initial_label_position := label.position
	var initial_hitbox_position := hitbox.position
	_drag_mouse(editor, initial_position + Vector2(140.0, 38.0), initial_position + Vector2(200.0, 68.0))
	_check(group.position == initial_position + Vector2(60.0, 30.0), "Dragging a pause rectangle moves the complete action group")
	_check(label.position == initial_label_position and hitbox.position == initial_hitbox_position and label.get_global_position().is_equal_approx(group.get_global_position() + label.position * group.scale), "Dragging keeps the visible text aligned with the touch hitbox")
	var before_scale := group.scale
	var handle := Rect2(group.position, group.size * group.scale).end - Vector2(2.0, 2.0)
	_drag_mouse(editor, handle, handle + Vector2(40.0, 12.0))
	_check(group.scale.x > before_scale.x and group.scale.y > before_scale.y, "Dragging a pause rectangle corner changes its visible and touch size together")
	var title_group := _group("title")
	if editor != null and title_group != null:
		var initial_title_position: Vector2 = title_group.position
		_drag_mouse(editor, initial_title_position + Vector2(240, 20), initial_title_position + Vector2(270, 35))
		_check(title_group.position == initial_title_position + Vector2(30, 15), "Dragging the pause title frame moves the title")
		var before_title_scale: Vector2 = title_group.scale
		var title_handle := Rect2(title_group.position, title_group.size * title_group.scale).end - Vector2(2, 2)
		_drag_mouse(editor, title_handle, title_handle + Vector2(28, 8))
		_check(title_group.scale.x > before_title_scale.x and title_group.scale.y > before_title_scale.y, "Resizing the pause title frame changes its rendered text size")
	var changed_position := group.position
	game.ui._unhandled_input(toggle)
	_check(not editor.is_editor_active() and not editor.visible, "F10 saves the pause layout and returns to normal pause controls")
	var stored: Variant = game.settings.get("pause_layout", {}).get("continue", [])
	_check(stored is Array and stored.size() == 4 and is_equal_approx(float(stored[0]), changed_position.x) and is_equal_approx(float(stored[2]), group.scale.x), "Pause rectangle position and size are serialized into the current profile")
	var stored_title: Variant = game.settings.get("pause_layout", {}).get("title", [])
	_check(title_group != null and stored_title is Array and stored_title.size() == 4 and is_equal_approx(float(stored_title[0]), title_group.position.x) and is_equal_approx(float(stored_title[2]), title_group.scale.x), "Pause title position and text size are serialized into the current profile")


func _test_pause_actions() -> void:
	var settings_button := _hitbox("settings")
	if settings_button != null:
		settings_button.emit_signal("pressed")
	_check(game.state == "settings", "CÀI ĐẶT opens Settings from the paused screen")
	game.ui.close_settings()
	_check(game.state == "paused" and game.ui.pause_layout_groups.size() == 4, "Closing Settings returns to the simplified pause screen")
	var continue_button := _hitbox("continue")
	if continue_button != null:
		continue_button.emit_signal("pressed")
	_check(game.state == "playing", "TIẾP TỤC resumes the paused run")
	game.pause_game()
	game.profile.checkpoint = {"seed": 777}
	await _frames(1)
	var menu_button := _hitbox("menu")
	if menu_button != null:
		menu_button.emit_signal("pressed")
	_check(game.state == "menu" and game.profile.checkpoint == {"seed": 777}, "MENU returns to the menu without discarding the safe checkpoint")


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
	for _index in range(count):
		await process_frame
