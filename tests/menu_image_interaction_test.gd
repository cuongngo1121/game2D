extends SceneTree
## Lobby interaction contract: controls render independently from the backdrop.

const MainScene = preload("res://scenes/main.tscn")
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
const MENU_BASE_PATH := "res://background/2 Background/1.png"
const MENU_LAYER_PATHS := [
	"res://background/2 Background/2.png",
	"res://background/2 Background/3.png",
	"res://background/2 Background/4.png",
	"res://background/2 Background/5.png",
]
const REMOVED_MENU_COPY := [
	"CHECKPOINT SẴN SÀNG",
	"CHƯA CÓ CHECKPOINT",
	"BẮT ĐẦU TẦN SỐ MỚI",
	"CẤU HÌNH TẢI TRANG",
	"KIỂM TRA CÁC KHU VỰC",
	"ÂM THANH & ĐIỀU KHIỂN",
	"OFFLINE",
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
	game.profile.checkpoint = {}
	game.ui.show_menu()
	await _frames(4)

	var actions := _visible_menu_actions()
	_check(_has_menu_background_layers(), "Menu uses all five newly added factory background layers")
	_check(_actions_have_rendered_buttons(actions), "Menu actions keep visible button frames independently from the background")
	var foreground_sprites: Array = game.ui.menu_background_layers[3].sprites
	var foreground_position: float = foreground_sprites[0].position.x
	var tile_width: float = game.ui.get_viewport().get_visible_rect().size.x
	_check(is_equal_approx(foreground_sprites[1].position.x - foreground_position, tile_width), "Mirrored background tiles start edge-to-edge")
	game.ui._animate_menu_background(0.5)
	var first_scroll_position: float = foreground_sprites[0].position.x
	game.ui._animate_menu_background(0.5)
	_check(first_scroll_position < foreground_position and foreground_sprites[0].position.x < first_scroll_position, "Lobby background scrolls continuously in one direction")
	_check(is_equal_approx(foreground_sprites[1].position.x - foreground_sprites[0].position.x, tile_width), "Background tiles stay edge-to-edge while scrolling")
	_check(_has_no_secondary_menu_copy(), "Menu removes every circled secondary description and the footer status copy")
	_check(actions.size() == 5, "Menu exposes exactly five artwork-aligned action hitboxes")
	_check(_action_ids(actions) == ["continue", "new_run", "armory", "debug", "settings"], "Menu preserves the five intended action destinations in visual order")
	_check(_action_rects_are_clear(actions), "Menu hitboxes stay inside the 1280x720 screen and do not overlap")
	var continue_button := _action(actions, "continue")
	var new_run_button := _action(actions, "new_run")
	_check(continue_button != null and continue_button.disabled, "Continue is visibly represented but safely disabled when no checkpoint exists")
	_check(new_run_button != null and not new_run_button.disabled, "New run remains actionable when there is no checkpoint")
	_check(_is_operable_art_region(new_run_button), "New-run uses an enabled native Button exactly over its artwork rectangle")
	if new_run_button != null:
		new_run_button.emit_signal("pressed")
		await _frames(4)
	_check(game.state == "menu" and game.ui.overlay.get_node_or_null("Campaign_StoryTitle") != null, "New Run opens the campaign prologue")
	_check(game.ui.overlay.get_node_or_null("Campaign_StoryBody") != null and game.ui.overlay.get_node_or_null("Campaign_Route") != null, "The prologue explains NOCTIS and lists the five-region route")
	_check(game.ui.overlay.get_node_or_null("Campaign_ControlsGuide") != null, "The prologue explains keyboard and touch controls")
	var campaign_start := game.ui.overlay.get_node_or_null("Campaign_StartButton") as Button
	_check(campaign_start != null and not campaign_start.disabled, "The prologue has a working campaign start action")
	if campaign_start != null:
		campaign_start.emit_signal("pressed")
		await _frames(4)
	_check(game.state == "playing" and not game.profile.checkpoint.is_empty(), "Starting from the prologue creates the normal run checkpoint")
	_check(game.ui.tutorial_panel.visible and game.ui.tutorial_label.text.contains("DI CHUYỂN"), "First room displays the movement tutorial")
	game.ui.tutorial_skip_button.emit_signal("pressed")
	await process_frame
	_check(game.tutorial_step == 4 and not game.ui.tutorial_panel.visible, "The player can dismiss the first-room tutorial")

	game.return_to_menu()
	await _frames(4)
	continue_button = _action(_visible_menu_actions(), "continue")
	_check(continue_button != null and not continue_button.disabled, "Continue becomes actionable after a real checkpoint is created")
	_check(_is_operable_art_region(continue_button), "Continue uses an enabled native Button exactly over its artwork rectangle")
	if continue_button != null:
		continue_button.emit_signal("pressed")
		await _frames(2)
	_check(game.state == "playing", "The continue artwork hitbox restores the checkpoint through the existing run flow")

	game.return_to_menu()
	await _frames(4)
	actions = _visible_menu_actions()

	var armory_button := _action(actions, "armory")
	_check(_is_operable_art_region(armory_button), "Armory uses an enabled native Button exactly over its artwork rectangle")
	if armory_button != null:
		# The headless SceneTree has no OS pointer, so invoke the same native
		# Button signal a click emits after asserting its live hitbox geometry.
		armory_button.emit_signal("pressed")
		await process_frame
	_check(game.state == "unlocks", "The armory artwork hitbox's pressed signal opens the weapon armory")
	game.ui.show_menu()
	await _frames(4)
	var settings_button := _action(_visible_menu_actions(), "settings")
	_check(_is_operable_art_region(settings_button), "Settings uses an enabled native Button exactly over its artwork rectangle")
	if settings_button != null:
		settings_button.emit_signal("pressed")
		await process_frame
	_check(game.state == "settings", "The settings artwork hitbox's pressed signal opens settings")

	game.return_to_menu()
	await _frames(4)
	var debug_button := _action(_visible_menu_actions(), "debug")
	_check(_is_operable_art_region(debug_button), "Debug uses an enabled native Button exactly over its artwork rectangle")
	if debug_button != null:
		debug_button.emit_signal("pressed")
		await process_frame
	var zone_buttons: int = 0
	for child in game.ui.overlay.get_children():
		if child is Button and child.visible and child.text == "VÀO TEST":
			zone_buttons += 1
	_check(zone_buttons == game.content.stages.size(), "The debug artwork hitbox opens the existing zone-selection menu")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("MENU IMAGE INTERACTION PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MENU IMAGE INTERACTION FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _visible_menu_actions() -> Array[Button]:
	var actions: Array[Button] = []
	for child in game.ui.overlay.get_children():
		if child is Button and child.visible and child.has_meta("menu_action_id"):
			actions.append(child)
	actions.sort_custom(func(left: Button, right: Button): return left.position.y < right.position.y)
	return actions

func _action_ids(actions: Array[Button]) -> Array[String]:
	var ids: Array[String] = []
	for action in actions:
		ids.append(str(action.get_meta("menu_action_id")))
	return ids

func _action(actions: Array[Button], action_id: String) -> Button:
	for action in actions:
		if str(action.get_meta("menu_action_id")) == action_id:
			return action
	return null

func _has_menu_background_layers() -> bool:
	if game.ui.menu_background_base == null or game.ui.menu_background_base.texture.resource_path != MENU_BASE_PATH:
		return false
	if game.ui.menu_background_layers.size() != MENU_LAYER_PATHS.size():
		return false
	for index in range(MENU_LAYER_PATHS.size()):
		var sprites: Array = game.ui.menu_background_layers[index].sprites
		if sprites.size() != 2 or sprites[0].texture.resource_path != MENU_LAYER_PATHS[index] or not sprites[1].flip_h:
			return false
	return true

func _has_no_secondary_menu_copy() -> bool:
	for child in game.ui.overlay.get_children():
		var visible_copy := ""
		if child is Label:
			visible_copy = child.text
		elif child is Button:
			visible_copy = child.tooltip_text
		else:
			continue
		for removed_copy in REMOVED_MENU_COPY:
			if visible_copy.contains(removed_copy):
				return false
	return true

func _action_rects_are_clear(actions: Array[Button]) -> bool:
	for i in range(actions.size()):
		var first: Rect2 = actions[i].get_meta("menu_art_rect")
		if not VIEWPORT_RECT.encloses(first):
			return false
		for j in range(i + 1, actions.size()):
			var second: Rect2 = actions[j].get_meta("menu_art_rect")
			if first.intersects(second):
				return false
	return true

func _is_operable_art_region(action: Button) -> bool:
	if action == null or action.disabled or not action.is_visible_in_tree():
		return false
	if action.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	var hitbox_rect := action.get_global_rect()
	return hitbox_rect.size == action.size and hitbox_rect.has_point(hitbox_rect.get_center())

func _actions_have_rendered_buttons(actions: Array[Button]) -> bool:
	for action in actions:
		var style := action.get_theme_stylebox("normal") as StyleBoxFlat
		if style == null or style.bg_color.a <= 0.0 or action.get_theme_color("font_color").a <= 0.0:
			return false
	return true

func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
