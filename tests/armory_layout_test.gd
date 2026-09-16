extends SceneTree
## Armory contract: the image owns the fixed chassis; native Buttons own every
## card hitbox; WeaponLoadoutState owns the A/B/FIXED/LOCKED visual states.

const MainScene = preload("res://scenes/main.tscn")
const WeaponLoadoutState = preload("res://scripts/ui/weapon_loadout_state.gd")
const ARMORY_ART_PATH := "res://assets/backgrounds/armory_loadout_matrix_v1.png"
const ARMORY_CARD_SIZE := Vector2(276.0, 132.0)
const ARMORY_MODEL_PREVIEW_SIZE := Vector2(72.0, 56.0)
const ARMORY_MODEL_PREVIEW_CENTER := Vector2(53.0, 75.0)
const CARD_GLOW_OUTSET := 4.0
const VIEWPORT_RECT := Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
const REMOVED_CARD_COPY := [
	"NĂNG LƯỢNG",
	"CHU KỲ",
	"SẴN SÀNG",
	"Ô 02 · ĐANG DÙNG",
	"Ô 01 · DỰ PHÒNG",
	"CHƯA SỞ HỮU",
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
	# Keep the first render deterministic: every authored weapon is available,
	# SMG is the selected starter, and no test persistence reaches disk.
	game.profile.meta.unlocked = game.all_weapon_ids()
	game.profile.meta.shards = 64
	game.starter = "smg"
	game.profile.meta.starter = "smg"
	game.ui.show_unlocks()
	await _frames(3)

	var actions := _visible_armory_actions()
	_check(_has_armory_art(), "Armory uses the dedicated loadout-matrix artwork")
	_check(actions.size() == game.content.weapons.size(), "Armory exposes one native hitbox for every authored weapon")
	_check(_action_ids(actions) == game.all_weapon_ids(), "Weapon hitboxes remain in authored visual order")
	_check(_action_rects_are_clear(actions), "Artwork-aligned card hitboxes stay inside the 1280x720 screen and do not overlap")
	_check(_state_layers_match_hitboxes(actions), "Each weapon hitbox has one matching runtime state component over its card")
	_check(_armory_previews_match_gameplay_models(), "Armory previews use the same pixel weapon model resource loaded by gameplay")
	_check(not _has_legacy_card_panels(), "The static artwork now owns the card chassis instead of duplicate runtime panels")
	_check(_has_no_removed_card_copy(), "Weapon cards omit energy, cycle, and secondary state copy")
	_check(_weapon_hitboxes_have_no_hover_overlay(actions), "Weapon card hitboxes have no pointer-hover overlay")
	_check(_weapon_hitboxes_have_no_focus_overlay(actions), "Weapon card hitboxes have no visual focus overlay")
	_check(_status_layers_are_single_line(actions), "Each loadout state component displays only its primary state label")
	_check(_shared_button_focus_matches_normal(), "The shared Button theme keeps focus visually identical to normal")
	_check(_visible_buttons_have_neutral_focus(game.ui.overlay), "The armory's visible buttons keep focus visually neutral")
	_check(_has_neutral_focus_style(game.ui.sound_toggle_button) and _has_neutral_focus_style(game.ui.music_toggle_button), "HUD audio buttons keep focus visually neutral")

	var pistol_state = _state_for("pistol")
	var equipped_state = _state_for("smg")
	var available_state = _state_for("shotgun")
	_check(pistol_state != null and pistol_state.state_key() == "fixed" and pistol_state.state_label.text == "MẶC ĐỊNH", "Pulse Pistol remains a visually distinct fixed fallback")
	_check(equipped_state != null and equipped_state.state_key() == "equipped" and equipped_state.state_label.text == "ĐANG TRANG BỊ", "State B clearly represents the currently equipped starter")
	_check(available_state != null and available_state.state_key() == "available" and available_state.state_label.text == "CHỌN TRANG BỊ", "State A clearly represents an unlocked weapon that is not equipped")
	var pistol_button := _action(actions, "pistol")
	var shotgun_button := _action(actions, "shotgun")
	_check(pistol_button != null and pistol_button.disabled, "The fixed fallback cannot be selected as a duplicate starter")
	_check(_is_operable_art_region(shotgun_button), "An available weapon uses its complete visible card as the native touch/click target")

	if shotgun_button != null:
		# The headless SceneTree has no OS pointer; emit the same native signal a
		# verified card hitbox would send after checking its geometry above.
		shotgun_button.emit_signal("pressed")
		await _frames(2)
	_check(game.starter == "shotgun", "Selecting an available weapon retains the existing starter-selection behavior")
	equipped_state = _state_for("shotgun")
	available_state = _state_for("smg")
	_check(equipped_state != null and equipped_state.state_key() == "equipped", "The newly selected weapon redraws into state B")
	_check(available_state != null and available_state.state_key() == "available", "The previously equipped weapon redraws into state A")

	game.profile.meta.unlocked = ["pistol", "smg", "shotgun"]
	game.profile.meta.shards = 0
	game.starter = "shotgun"
	game.profile.meta.starter = "shotgun"
	game.ui.show_unlocks()
	await _frames(2)
	var locked_state = _state_for("rail")
	var locked_button := _action(_visible_armory_actions(), "rail")
	_check(locked_state != null and locked_state.state_key() == "locked" and locked_state.state_label.text == "MỞ KHÓA · 8 MẢNH", "Locked weapons retain a separate truthful ownership state")
	_check(locked_button != null and locked_button.disabled, "A locked weapon stays disabled when the player lacks the required shards")
	var return_button := _return_button()
	_check(return_button != null and _is_operable_return_region(return_button), "The artwork return frame keeps a matching operable native Button")
	_check(return_button != null and _has_neutral_focus_style(return_button), "The armory return action has no separate focus effect")

	game.ui.show_menu()
	await _frames(2)
	_check(_visible_buttons_have_neutral_focus(game.ui.overlay), "Menu action hitboxes have no visual focus effect")
	game.ui.show_settings("menu")
	await _frames(2)
	_check(_visible_buttons_have_neutral_focus(game.ui.overlay), "Settings buttons have no visual focus effect")
	_check(_visible_sliders_have_no_focus_overlay(game.ui.overlay), "Settings sliders have no visual focus overlay")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ARMORY LAYOUT PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("ARMORY LAYOUT FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _visible_armory_actions() -> Array[Button]:
	var actions: Array[Button] = []
	for child in game.ui.overlay.get_children():
		if child is Button and child.visible and child.has_meta("armory_weapon_id"):
			actions.append(child)
	actions.sort_custom(func(left: Button, right: Button): return left.position.y < right.position.y or (is_equal_approx(left.position.y, right.position.y) and left.position.x < right.position.x))
	return actions

func _action_ids(actions: Array[Button]) -> Array[String]:
	var ids: Array[String] = []
	for action in actions:
		ids.append(str(action.get_meta("armory_weapon_id")))
	return ids

func _action(actions: Array[Button], weapon_id: String) -> Button:
	for action in actions:
		if str(action.get_meta("armory_weapon_id")) == weapon_id:
			return action
	return null

func _state_for(weapon_id: String):
	for child in game.ui.overlay.get_children():
		if child.visible and child.get_script() == WeaponLoadoutState and child.has_meta("armory_weapon_id") and str(child.get_meta("armory_weapon_id")) == weapon_id:
			return child
	return null

func _has_armory_art() -> bool:
	for child in game.ui.overlay.get_children():
		if child is TextureRect and child.texture != null and child.texture.resource_path == ARMORY_ART_PATH:
			return true
	return false

func _action_rects_are_clear(actions: Array[Button]) -> bool:
	for i in range(actions.size()):
		var first: Rect2 = actions[i].get_meta("armory_art_rect")
		if first.size != ARMORY_CARD_SIZE or not VIEWPORT_RECT.encloses(first):
			return false
		for j in range(i + 1, actions.size()):
			var second: Rect2 = actions[j].get_meta("armory_art_rect")
			if first.grow(CARD_GLOW_OUTSET).intersects(second.grow(CARD_GLOW_OUTSET)):
				return false
	return true

func _state_layers_match_hitboxes(actions: Array[Button]) -> bool:
	var state_count := 0
	for action in actions:
		var state_layer = _state_for(str(action.get_meta("armory_weapon_id")))
		if state_layer == null or state_layer.get_script() != WeaponLoadoutState:
			return false
		if state_layer.position != action.position or state_layer.size != action.size:
			return false
		state_count += 1
	return state_count == game.content.weapons.size()

func _armory_previews_match_gameplay_models() -> bool:
	for weapon in game.content.weapons:
		var weapon_id := str(weapon.id)
		var model_path := str(weapon.get("model", ""))
		var preview: TextureRect
		for child in game.ui.overlay.get_children():
			if child is TextureRect and child.get_meta("armory_weapon_model_id", "") == weapon_id:
				preview = child
				break
		var gameplay_texture = game.player.weapon_textures.get(weapon_id)
		if preview == null or preview.texture == null or preview.get_meta("armory_weapon_model_path", "") != model_path:
			return false
		var state_layer = _state_for(weapon_id)
		if state_layer == null:
			return false
		var preview_center: Vector2 = preview.position - state_layer.position + preview.size * 0.5
		if preview.texture.resource_path != model_path or preview.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			return false
		if preview.size != ARMORY_MODEL_PREVIEW_SIZE or preview_center.distance_to(ARMORY_MODEL_PREVIEW_CENTER) > 0.1:
			return false
		if not (gameplay_texture is Texture2D) or gameplay_texture.resource_path != model_path:
			return false
	return true

func _has_legacy_card_panels() -> bool:
	for child in game.ui.overlay.get_children():
		if child is Panel and child.size == ARMORY_CARD_SIZE:
			return true
	return false

func _has_no_removed_card_copy() -> bool:
	for removed_copy in REMOVED_CARD_COPY:
		if _tree_contains_text(game.ui.overlay, removed_copy):
			return false
	return true

func _tree_contains_text(parent: Node, unwanted_text: String) -> bool:
	for child in parent.get_children():
		if child is Label and child.visible and child.text.contains(unwanted_text):
			return true
		if _tree_contains_text(child, unwanted_text):
			return true
	return false

func _weapon_hitboxes_have_no_hover_overlay(actions: Array[Button]) -> bool:
	for action in actions:
		var hover_style := action.get_theme_stylebox("hover")
		if not (hover_style is StyleBoxEmpty):
			return false
	return true

func _weapon_hitboxes_have_no_focus_overlay(actions: Array[Button]) -> bool:
	for action in actions:
		if not _has_neutral_focus_style(action):
			return false
	return true

func _shared_button_focus_matches_normal() -> bool:
	var theme: Theme = game.ui.theme_resource
	return theme.get_stylebox("focus", "Button") == theme.get_stylebox("normal", "Button") and theme.get_color("font_focus_color", "Button") == theme.get_color("font_color", "Button")

func _visible_buttons_have_neutral_focus(parent: Node) -> bool:
	for child in parent.get_children():
		if child is Button and child.visible and child.focus_mode != Control.FOCUS_NONE and not _has_neutral_focus_style(child):
			return false
		if not _visible_buttons_have_neutral_focus(child):
			return false
	return true

func _visible_sliders_have_no_focus_overlay(parent: Node) -> bool:
	for child in parent.get_children():
		if child is HSlider and child.visible and not (child.get_theme_stylebox("focus") is StyleBoxEmpty):
			return false
		if not _visible_sliders_have_no_focus_overlay(child):
			return false
	return true

func _has_neutral_focus_style(control: Control) -> bool:
	if control == null:
		return false
	return control.get_theme_stylebox("focus") == control.get_theme_stylebox("normal") and control.get_theme_color("font_focus_color") == control.get_theme_color("font_color")

func _status_layers_are_single_line(actions: Array[Button]) -> bool:
	for action in actions:
		var state_layer = _state_for(str(action.get_meta("armory_weapon_id")))
		if state_layer == null or state_layer.get_node_or_null("LoadoutStateDetail") != null:
			return false
	return true

func _is_operable_art_region(action: Button) -> bool:
	if action == null or action.disabled or not action.is_visible_in_tree():
		return false
	if action.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	var hitbox_rect := action.get_global_rect()
	return hitbox_rect.size == action.size and hitbox_rect.has_point(hitbox_rect.get_center())

func _return_button() -> Button:
	for child in game.ui.overlay.get_children():
		if child is Button and child.name == "Armory_Return_Hitbox":
			return child
	return null

func _is_operable_return_region(action: Button) -> bool:
	if action == null or action.disabled or not action.is_visible_in_tree():
		return false
	if action.mouse_filter != Control.MOUSE_FILTER_STOP:
		return false
	return VIEWPORT_RECT.encloses(action.get_global_rect()) and action.get_global_rect().has_point(action.get_global_rect().get_center())

func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
