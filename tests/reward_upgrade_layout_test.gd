extends SceneTree
## Upgrade/reward overlay artwork, layout, and real clear-to-resume behavior.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const REWARD_BACKGROUND := "res://assets/backgrounds/upgrade_reward_overlay_v1.png"
const EXPECTED_CARD_RECTS := [
	Rect2(123.0, 157.0, 330.0, 384.0),
	Rect2(483.0, 157.0, 330.0, 384.0),
	Rect2(843.0, 157.0, 330.0, 384.0),
]

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
	var layout_path := "user://tests/reward_upgrade_layout_%d.json" % OS.get_process_id()
	game.store = SaveScript.new(layout_path)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.ui.reward_layout_positions.clear()
	game.ui.reward_layout_scales.clear()
	game.new_run(468921, true, false, false)
	game.combat_active = true
	game.enemies.clear()
	game.complete_room()
	await _frames(2)

	_test_reward_surface()
	_test_reward_editor()
	_test_reward_actions()
	await _test_reward_preview()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("REWARD UPGRADE LAYOUT PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("REWARD UPGRADE LAYOUT FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _test_reward_surface() -> void:
	_check(game.state == "reward", "Clearing a room opens the upgrade state")
	_check(game.pending_reward.size() == 3, "A fresh room exposes three compatible upgrade choices")
	var art := game.ui.overlay.get_node_or_null(NodePath("Reward_UpgradeArtwork")) as TextureRect
	_check(art != null and art.texture != null and str(art.get_meta("reward_background_path", "")) == REWARD_BACKGROUND, "Reward uses the dedicated upgrade console artwork")
	var shade: ColorRect = null
	for child in game.ui.overlay.get_children():
		if child is ColorRect and child.has_meta("overlay_dim") and child.visible:
			shade = child as ColorRect
			break
	_check(shade != null and shade.color.a >= 0.8 and shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gameplay is dimmed while the reward choice is open")
	_check(game.ui.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Reward overlay isolates gameplay input")
	var image: Image = null
	if art != null and art.texture is Texture2D:
		image = art.texture.get_image()
	_check(image != null and image.get_pixel(0, 0).a < 0.05, "Reward artwork keeps transparent negative space outside the chassis")
	var title_group := game.ui.reward_layout_groups.get("title") as Control
	var title := title_group.get_node_or_null(NodePath("Reward_Title")) as Label if title_group != null else null
	_check(title != null and title.text == "NÂNG CẤP SAU PHÒNG" and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Reward title is runtime text centered in the top slot")
	_check(game.ui.reward_layout_groups.get("subtitle") == null and game.ui.overlay.get_node_or_null(NodePath("Reward_Subtitle")) == null, "Reward screen removes the redundant description under its title")
	for index in range(3):
		var card := game.ui.overlay.get_node_or_null(NodePath("Reward_Card_%02d" % (index + 1))) as Control
		var hitbox := card.get_node_or_null(NodePath("Reward_Card_%02d_Hitbox" % (index + 1))) as Button if card != null else null
		var card_title := card.get_node_or_null(NodePath("Reward_Card_%02d_Title" % (index + 1))) as Label if card != null else null
		var card_description := card.get_node_or_null(NodePath("Reward_Card_%02d_Description" % (index + 1))) as Label if card != null else null
		var module_label := card.get_node_or_null(NodePath("Reward_Card_%02d_Module" % (index + 1))) as Label if card != null else null
		_check(card != null and card.position.is_equal_approx(EXPECTED_CARD_RECTS[index].position) and card.size == EXPECTED_CARD_RECTS[index].size, "Reward card %d aligns with its authored artwork frame" % (index + 1))
		_check(module_label == null and card_title != null and card_description != null, "Reward card %d removes the module label and keeps editable title/description text" % (index + 1))
		_check(card_title != null and not card_title.text.is_empty() and card_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and card_title.get_theme_color("font_color") == Color("35e7ff"), "Reward card %d centers its cyan upgrade title" % (index + 1))
		_check(card_description != null and card_description.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and card_description.get_theme_color("font_color") == Color("35e7ff"), "Reward card %d left-aligns its cyan description" % (index + 1))
		_check(hitbox != null and hitbox.focus_mode == Control.FOCUS_ALL and hitbox.tooltip_text.contains("Chọn nâng cấp"), "Reward card %d contains a named keyboard/touch target" % (index + 1))
		_check(hitbox != null and hitbox.get_theme_stylebox("normal") is StyleBoxEmpty and hitbox.get_theme_stylebox("disabled") is StyleBoxEmpty and hitbox.get_theme_stylebox("hover") is StyleBoxEmpty and hitbox.get_theme_stylebox("focus") is StyleBoxEmpty and hitbox.get_theme_stylebox("pressed") is StyleBoxEmpty, "Reward card %d leaves only centered text in every button state" % (index + 1))
	var repair := game.ui.overlay.get_node_or_null(NodePath("Reward_RepairButton")) as Button
	_check(repair != null and repair.text == "SỬA CHỮA  +25 HP" and repair.focus_mode == Control.FOCUS_ALL, "Reward screen keeps the repair fallback as a real action")
	_check(repair != null and repair.get_theme_stylebox("normal") is StyleBoxEmpty and repair.get_theme_stylebox("focus") is StyleBoxEmpty and repair.get_theme_stylebox("pressed") is StyleBoxEmpty, "Repair action also renders only centered text")


func _test_reward_editor() -> void:
	var editor = game.ui.reward_layout_editor
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "Reward placement editor starts hidden outside placement mode")
	var toggle := _key(KEY_F11)
	game.ui._unhandled_input(toggle)
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "F11 opens reward placement mode and blocks accidental reward presses")
	var card := game.ui.reward_layout_groups.get("card_01") as Control
	var title_text := game.ui.reward_layout_groups.get("card_01_title") as Label
	var description_text := game.ui.reward_layout_groups.get("card_01_description") as Label
	var repair := game.ui.reward_layout_groups.get("repair") as Control
	if editor == null or card == null or title_text == null or description_text == null or repair == null:
		return
	var initial_position := card.position
	_drag_mouse(editor, initial_position + Vector2(300.0, 40.0), initial_position + Vector2(328.0, 58.0))
	_check(card.position == initial_position + Vector2(28.0, 18.0), "Dragging a reward card moves its text and action together")
	var initial_title_position := title_text.position
	var title_start := title_text.get_global_position() + Vector2(100.0, 30.0)
	_drag_mouse(editor, title_start, title_start + Vector2(28.0, 18.0))
	_check(title_text.position == initial_title_position + Vector2(28.0, 18.0), "Dragging a card title edits only the title text position")
	var before_scale := card.scale
	var handle := Rect2(card.position, card.size * card.scale).end - Vector2(2.0, 2.0)
	_drag_mouse(editor, handle, handle + Vector2(28.0, 10.0))
	_check(card.scale.x > before_scale.x and card.scale.y > before_scale.y, "Dragging a reward card corner changes its text and touch size together")
	var title_before_scale := title_text.get_global_transform_with_canvas().get_scale()
	var title_handle := Rect2(title_text.get_global_position(), title_text.size * title_before_scale).end - Vector2(2.0, 2.0)
	editor._toggle_solo_item("card_01_title")
	_drag_mouse(editor, title_handle, title_handle + Vector2(20.0, 8.0))
	var title_after_scale := title_text.get_global_transform_with_canvas().get_scale()
	_check(title_after_scale.x > title_before_scale.x and title_after_scale.y > title_before_scale.y, "Resizing a card title changes only its text size")
	var changed_position := card.position
	game.ui._unhandled_input(toggle)
	_check(not editor.is_editor_active() and not editor.visible, "F11 saves the reward layout and exits placement mode")
	var stored: Variant = game.settings.get("reward_layout", {}).get("card_01", [])
	_check(stored is Array and stored.size() == 4 and is_equal_approx(float(stored[0]), changed_position.x) and is_equal_approx(float(stored[2]), card.scale.x), "Reward card position and size are serialized into the current profile")
	var stored_title: Variant = game.settings.get("reward_layout", {}).get("card_01_title", [])
	_check(stored_title is Array and stored_title.size() == 4 and is_equal_approx(float(stored_title[0]), title_text.position.x) and is_equal_approx(float(stored_title[2]), title_text.scale.x), "Card title position and size are serialized independently")
	_check(game.ui.reward_layout_groups.get("title") != null and game.ui.reward_layout_groups.get("card_01_description") != null, "Reward editor keeps card title and description as independent layout groups")


func _test_reward_actions() -> void:
	var first_card := game.ui.overlay.get_node_or_null(NodePath("Reward_Card_01")) as Control
	var first_button := first_card.get_node_or_null(NodePath("Reward_Card_01_Hitbox")) as Button if first_card != null else null
	var choice_id := str(first_button.get_meta("reward_choice_id", "")) if first_button != null else ""
	if first_button != null:
		first_button.emit_signal("pressed")
	_check(not choice_id.is_empty(), "First reward target keeps the selected upgrade id")
	_check(game.state == "playing", "Choosing an upgrade returns to gameplay")
	_check(game.rewarded.has(0) and game.pending_reward.is_empty(), "Choosing an upgrade marks the room rewarded exactly once")
	_check(int(game.upgrades.get(choice_id, 0)) == 1, "Choosing an upgrade applies its stack to the current run")
	_check(not game.ui.overlay.visible, "Reward overlay closes after the upgrade is applied")


func _test_reward_preview() -> void:
	var before_cleared: Array = game.cleared.duplicate(true)
	var before_rewarded: Array = game.rewarded.duplicate(true)
	var before_pending: Array = game.pending_reward.duplicate(true)
	var before_upgrades: Dictionary = game.upgrades.duplicate(true)
	var before_coins: int = game.coins
	var before_checkpoint: Dictionary = game.profile.checkpoint.duplicate(true)
	game.ui._unhandled_input(_key(KEY_F11))
	await _frames(1)
	var editor = game.ui.reward_layout_editor
	_check(game.ui.reward_layout_preview_active and game.state == "reward", "F11 from gameplay opens the upgrade layout preview without clearing a room")
	_check(editor != null and editor.is_editor_active() and editor.visible, "Gameplay F11 opens the reward editor immediately")
	_check(game.ui.overlay.visible and game.ui.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Reward preview dims and blocks the live gameplay surface")
	_check(game.cleared == before_cleared and game.rewarded == before_rewarded and game.pending_reward == before_pending, "Reward preview leaves room progress and pending rewards unchanged")
	_check(game.upgrades == before_upgrades and game.coins == before_coins and game.profile.checkpoint == before_checkpoint, "Reward preview does not grant upgrades, credits, or a checkpoint")

	game.ui._unhandled_input(_key(KEY_F11))
	await _frames(1)
	_check(not game.ui.reward_layout_preview_active and game.state == "playing" and not game.ui.overlay.visible, "F11 closes the preview and returns to the live room")
	_check(game.cleared == before_cleared and game.rewarded == before_rewarded and game.pending_reward == before_pending and game.upgrades == before_upgrades and game.coins == before_coins, "Closing the preview keeps the gameplay state intact")


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


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
