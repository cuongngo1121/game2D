extends SceneTree
## Support weapon choices share the upgrade console layout while preserving the
## free/purchase action and the safe return-to-room escape.

const MainScene = preload("res://scenes/main.tscn")
const SaveScript = preload("res://scripts/core/save_store.gd")
const SUPPORT_BACKGROUND := "res://assets/backgrounds/upgrade_reward_overlay_v1.png"
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
	var layout_path := "user://tests/support_weapon_layout_%d.json" % OS.get_process_id()
	game.store = SaveScript.new(layout_path)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.ui.support_layout_positions.clear()
	game.ui.support_layout_scales.clear()
	game.ui._load_support_layout()
	game.new_run(685321, true, false, false)
	game.graph["support"] = "chest"
	game.coins = 977
	game.support_purchased = false
	game.state = "shop"
	var offers: Array = game.support_offers()
	game.ui.show_shop(offers)
	await _frames(2)

	_test_support_surface(offers)
	_test_support_editor()
	_test_support_action(offers)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("SUPPORT WEAPON LAYOUT PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SUPPORT WEAPON LAYOUT FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _test_support_surface(offers: Array) -> void:
	_check(game.state == "shop", "Opening the support choice surface keeps the shop state")
	_check(offers.size() == 3, "A chest exposes three weapon choices")
	var art := game.ui.overlay.get_node_or_null(NodePath("Support_WeaponArtwork")) as TextureRect
	_check(art != null and art.texture != null and str(art.get_meta("support_background_path", "")) == SUPPORT_BACKGROUND, "Support choices reuse the authored upgrade console artwork")
	var shade: ColorRect = null
	for child in game.ui.overlay.get_children():
		if child is ColorRect and child.has_meta("overlay_dim") and child.visible:
			shade = child as ColorRect
			break
	_check(shade != null and shade.color.a >= 0.8 and shade.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Gameplay is dimmed while support choices are open")
	_check(game.ui.overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "Support overlay isolates gameplay input")
	var title := game.ui.support_layout_groups.get("title").get_node_or_null(NodePath("Support_Title")) as Label
	var status := game.ui.support_layout_groups.get("status").get_node_or_null(NodePath("Support_Status")) as Label
	_check(title != null and title.text == "TRẠM HỖ TRỢ" and title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and title.get_theme_color("font_color") == Color("35e7ff"), "Support title is centered and cyan")
	_check(status != null and status.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and status.get_theme_color("font_color") == Color("35e7ff"), "Support status stays visible in the shared top slot")
	for index in range(3):
		var card := game.ui.overlay.get_node_or_null(NodePath("Support_Card_%02d" % (index + 1))) as Control
		var icon_layout := game.ui.support_layout_groups.get("card_%02d_icon" % (index + 1)) as Control
		var icon := icon_layout.get_node_or_null(NodePath("Support_Card_%02d_Icon" % (index + 1))) as TextureRect if icon_layout != null else null
		var card_title := game.ui.support_layout_groups.get("card_%02d_title" % (index + 1)) as Label
		var card_description := game.ui.support_layout_groups.get("card_%02d_description" % (index + 1)) as Label
		var hitbox := card.get_node_or_null(NodePath("Support_Card_%02d_Hitbox" % (index + 1))) as Button if card != null else null
		_check(card != null and card.position.is_equal_approx(EXPECTED_CARD_RECTS[index].position) and card.size == EXPECTED_CARD_RECTS[index].size, "Support card %d aligns with its authored artwork frame" % (index + 1))
		_check(icon != null and icon.texture != null, "Support card %d keeps its weapon image as runtime content" % (index + 1))
		_check(card_title != null and card_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and card_title.get_theme_color("font_color") == Color("35e7ff"), "Support card %d centers its cyan title" % (index + 1))
		_check(card_description != null and card_description.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and card_description.get_theme_color("font_color") == Color("35e7ff"), "Support card %d left-aligns its cyan description" % (index + 1))
		_check(hitbox != null and hitbox.text == "NHẬN MIỄN PHÍ" and hitbox.focus_mode == Control.FOCUS_ALL and hitbox.tooltip_text.contains("Trang bị"), "Support card %d keeps a named selection target" % (index + 1))
		_check(hitbox != null and hitbox.get_theme_stylebox("normal") is StyleBoxEmpty and hitbox.get_theme_stylebox("disabled") is StyleBoxEmpty and hitbox.get_theme_stylebox("hover") is StyleBoxEmpty and hitbox.get_theme_stylebox("focus") is StyleBoxEmpty and hitbox.get_theme_stylebox("pressed") is StyleBoxEmpty, "Support card %d leaves only centered text in every button state" % (index + 1))
	_check(game.ui.overlay.get_node_or_null(NodePath("Support_Card_01/Panel")) == null, "Support cards do not add a second opaque panel over the authored frame")
	var back := game.ui.overlay.get_node_or_null(NodePath("Support_BackButton")) as Button
	_check(back != null and back.text == "ĐỂ SAU · TRỞ LẠI PHÒNG" and back.get_theme_stylebox("normal") is StyleBoxEmpty and back.get_theme_stylebox("focus") is StyleBoxEmpty, "Support keeps a text-only safe return action")


func _test_support_editor() -> void:
	var editor = game.ui.support_layout_editor
	_check(editor != null and not editor.is_editor_active() and not editor.visible, "Support placement editor starts hidden outside placement mode")
	game.ui._unhandled_input(_key(KEY_F11))
	_check(editor != null and editor.is_editor_active() and editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "F11 opens support placement mode and blocks accidental selection")
	_check(editor != null and editor._items.has("title") and editor._items.has("status") and editor._items.has("card_01_icon") and editor._items.has("card_01_title") and editor._items.has("card_01_description") and editor._items.has("back"), "Support editor exposes independent title, icon, text, and return groups")
	var card := game.ui.support_layout_groups.get("card_01") as Control
	var initial_position := card.position if card != null else Vector2.ZERO
	if editor != null and card != null:
		_drag_mouse(editor, initial_position + Vector2(300.0, 40.0), initial_position + Vector2(328.0, 58.0))
		_check(card.position == initial_position + Vector2(28.0, 18.0), "Dragging a support card moves its choice content together")
	game.ui._unhandled_input(_key(KEY_F11))
	_check(not editor.is_editor_active() and not editor.visible, "F11 saves the support layout and exits placement mode")
	var stored: Variant = game.settings.get("support_layout", {}).get("card_01", [])
	_check(stored is Array and stored.size() == 4 and is_equal_approx(float(stored[0]), card.position.x) and is_equal_approx(float(stored[2]), card.scale.x), "Support card position and size are serialized into the current profile")


func _test_support_action(offers: Array) -> void:
	var first_card := game.ui.overlay.get_node_or_null(NodePath("Support_Card_01")) as Control
	var first_button := first_card.get_node_or_null(NodePath("Support_Card_01_Hitbox")) as Button if first_card != null else null
	var selected_id := str(offers[0].get("id", ""))
	if first_button != null:
		first_button.emit_signal("pressed")
	_check(game.state == "playing", "Selecting a support weapon returns to gameplay")
	_check(game.support_purchased and game.rewarded.has(4), "Selecting a support weapon marks the support reward once")
	_check(game.weapons[game.active_slot] == selected_id, "Selecting a support card equips the selected weapon")
	_check(not game.ui.overlay.visible, "Support overlay closes after the weapon is equipped")


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


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
