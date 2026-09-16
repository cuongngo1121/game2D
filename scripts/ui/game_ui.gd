class_name GameUI
extends CanvasLayer

var game
var root: Control
var overlay: Control
var hud: Control
var font: Font
var bold: Font
var title_label: Label
var room_label: Label
var health_label: Label
var weapon_label: Label
var secondary_weapon_label: Label
var status_label: Label
var hint_label: Label
var boss_label: Label
var bars: Dictionary = {}
var beat_display: Control
var minimap: Control
var map_button: Button
var sound_toggle_button: Button
var music_toggle_button: Button
var demo_controls: Array[Control] = []
var _last_sfx_enabled: bool = true
var _last_music_enabled: bool = true
var overlay_box: Control
var settings_return: String = "menu"
var theme_resource: Theme
# This debug-only editor moves whole runtime groups while the exterior Settings
# artwork stays fixed. The working Vector2 values live here; they are serialized
# into the profile only when the user presses F7 to leave placement mode.
var settings_layout_editor
var settings_layout_groups: Dictionary = {}
var settings_layout_positions: Dictionary = {}
var settings_layout_editor_active: bool = false
const INK = Color("0b0718")
const SURFACE = Color("18112d")
const CYAN = Color("35e7ff")
const LED_PURPLE = Color("d65dff")
const WHITE = Color("e6f7ff")
const MUTED = Color("a79abb")
const CORAL = Color("ff846f")
const PIXEL_PLAYER_PREVIEW := "res://assets/characters/pixel_32/echo_runner_idle_0.png"
const MENU_BACKGROUND := "res://assets/backgrounds/menu_resonance_console_v1.png"
const ARMORY_BACKGROUND := "res://assets/backgrounds/armory_loadout_matrix_v1.png"
const SETTINGS_BACKGROUND := "res://assets/backgrounds/settings_calibration_console_v2.png"
const WeaponLoadoutStateScript = preload("res://scripts/ui/weapon_loadout_state.gd")
const SettingsLayoutEditorScript = preload("res://scripts/ui/settings_layout_editor.gd")
const MENU_ACTION_ORIGIN := Vector2(425.0, 174.0)
const MENU_ACTION_SIZE := Vector2(430.0, 76.0)
const MENU_ACTION_GAP := 12.0
const ARMORY_GRID_ORIGIN := Vector2(64.0, 143.0)
const ARMORY_CARD_SIZE := Vector2(276.0, 132.0)
const ARMORY_CARD_GAP := Vector2(18.0, 20.0)
const ARMORY_MODEL_PREVIEW_ORIGIN := Vector2(17.0, 47.0)
const ARMORY_MODEL_PREVIEW_SIZE := Vector2(72.0, 56.0)
const ARMORY_RETURN_RECT := Rect2(476.0, 616.0, 324.0, 54.0)
const SETTINGS_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const SETTINGS_TITLE_GROUP_RECT := Rect2(400.0, 39.0, 480.0, 65.0)
const SETTINGS_AUDIO_GROUP_RECT := Rect2(78.0, 139.0, 515.0, 396.0)
const SETTINGS_CONTROL_GROUP_RECT := Rect2(687.0, 139.0, 515.0, 409.0)
const SETTINGS_SLIDER_ROW_SIZE := Vector2(515.0, 72.0)
const SETTINGS_TOGGLE_SIZE := Vector2(492.0, 43.0)
const SETTINGS_SAVE_RECT := Rect2(443.0, 596.0, 394.0, 58.0)
const SETTINGS_LAYOUT_EDITOR_TEMPORARY_ENABLED := true
const SETTINGS_LAYOUT_GROUP_IDS := ["title", "audio", "controls", "save"]

func setup(owner_game) -> void:
	game = owner_game
	_load_settings_layout_positions()
	font = load("res://assets/fonts/NotoSans-Regular.ttf")
	bold = load("res://assets/fonts/NotoSans-Bold.ttf")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	theme_resource = Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 19
	theme_resource.set_color("font_color", "Button", WHITE)
	theme_resource.set_color("font_hover_color", "Button", CYAN)
	theme_resource.set_color("font_focus_color", "Button", WHITE)
	theme_resource.set_color("font_disabled_color", "Button", Color("80728e"))
	var default_button_style := panel_style(Color("27183f"), Color("51336d"))
	theme_resource.set_stylebox("normal", "Button", default_button_style)
	theme_resource.set_stylebox("hover", "Button", panel_style(Color("34204e"), CYAN))
	theme_resource.set_stylebox("pressed", "Button", panel_style(Color("123948"), CYAN))
	# Preserve keyboard focus semantics without adding a separate visual state.
	theme_resource.set_stylebox("focus", "Button", default_button_style)
	theme_resource.set_stylebox("disabled", "Button", panel_style(Color("171121"), Color("342841")))
	root.theme = theme_resource
	build_hud()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)

func panel_style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 17
	style.content_margin_right = 17
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func led_style(fill: Color, accent: Color, width: int = 2) -> StyleBoxFlat:
	var style = panel_style(fill, accent, width)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.72)
	style.shadow_size = 8
	style.shadow_offset = Vector2.ZERO
	return style

func menu_hitbox_style(accent: Color, fill_alpha: float, border_width: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(accent.r, accent.g, accent.b, fill_alpha)
	style.border_color = accent
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.56)
	style.shadow_size = 5
	style.shadow_offset = Vector2.ZERO
	return style

func slider_grabber_texture(accent: Color) -> Texture2D:
	var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	for y in range(20):
		for x in range(20):
			var distance: float = Vector2(x - 9.5, y - 9.5).length()
			if distance <= 6.0:
				image.set_pixel(x, y, Color(accent.r, accent.g, accent.b, 1.0))
			elif distance <= 9.0:
				image.set_pixel(x, y, Color(accent.r, accent.g, accent.b, (9.0 - distance) / 3.0 * 0.75))
	return ImageTexture.create_from_image(image)

func draw_settings_slider_led_fill(canvas: Control, value: float, minimum: float, maximum: float, accent: Color) -> void:
	# Keep the LED rail independent from HSlider's pressed/highlighted theme
	# surfaces, which can otherwise fall back to a neutral gray texture.
	var rail_left := 10.0
	var rail_right := maxf(rail_left, canvas.size.x - 10.0)
	var rail_y := canvas.size.y * 0.5
	var ratio := 0.0 if is_zero_approx(maximum - minimum) else clampf((value - minimum) / (maximum - minimum), 0.0, 1.0)
	var fill_right := lerpf(rail_left, rail_right, ratio)
	canvas.draw_line(Vector2(rail_left, rail_y), Vector2(rail_right, rail_y), Color(0.003, 0.008, 0.023, 0.96), 6.0, true)
	canvas.draw_line(Vector2(rail_left, rail_y), Vector2(rail_right, rail_y), Color(accent.r, accent.g, accent.b, 0.34), 2.0, true)
	canvas.draw_line(Vector2(rail_left, rail_y), Vector2(fill_right, rail_y), Color(accent.r, accent.g, accent.b, 0.92), 4.0, true)
	canvas.draw_line(Vector2(rail_left, rail_y - 0.5), Vector2(fill_right, rail_y - 0.5), Color(WHITE.r, WHITE.g, WHITE.b, 0.38), 1.0, true)

func toggle_style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style = panel_style(fill, border, width)
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	return style

func label(parent: Node, text: String, rect: Rect2, size_value: int = 20, color: Color = WHITE, heavy: bool = false) -> Label:
	var node = Label.new()
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", bold if heavy else font)
	node.add_theme_font_size_override("font_size", size_value)
	node.add_theme_color_override("font_color", color)
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func led_label(parent: Node, text: String, rect: Rect2, size_value: int, color: Color, heavy: bool = false) -> Label:
	var node = label(parent, text, rect, size_value, color, heavy)
	node.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.7))
	node.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.8))
	node.add_theme_constant_override("outline_size", 2)
	node.add_theme_constant_override("shadow_outline_size", 8)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	return node

func plain_label(parent: Node, text: String, rect: Rect2, size_value: int, color: Color, heavy: bool = false) -> Label:
	var node = label(parent, text, rect, size_value, color, heavy)
	node.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	node.add_theme_constant_override("outline_size", 0)
	node.add_theme_constant_override("shadow_outline_size", 0)
	node.add_theme_constant_override("shadow_offset_x", 0)
	node.add_theme_constant_override("shadow_offset_y", 0)
	return node

func button(parent: Node, text: String, rect: Rect2, action: Callable, primary: bool = false, led_color: Color = Color(0, 0, 0, 0)) -> Button:
	var node = Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if led_color.a > 0.0:
		var normal_fill = Color("05030a")
		var hover_fill = Color("0b0714")
		var pressed_fill = Color("140b20")
		var normal_style := led_style(normal_fill, led_color)
		node.add_theme_stylebox_override("normal", normal_style)
		node.add_theme_stylebox_override("hover", led_style(hover_fill, led_color))
		node.add_theme_stylebox_override("pressed", led_style(pressed_fill, led_color))
		node.add_theme_stylebox_override("focus", normal_style)
		node.add_theme_color_override("font_color", led_color)
		node.add_theme_color_override("font_hover_color", led_color)
		node.add_theme_color_override("font_pressed_color", led_color)
		node.add_theme_color_override("font_focus_color", led_color)
	elif primary:
		var primary_style := panel_style(Color("163b48"), CYAN)
		node.add_theme_stylebox_override("normal", primary_style)
		node.add_theme_stylebox_override("focus", primary_style)
		node.add_theme_color_override("font_color", CYAN)
		node.add_theme_color_override("font_focus_color", CYAN)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

## Gameplay HUD controls are activated by touch/click or their named hotkey.
## They must never retain keyboard focus: otherwise Godot treats Space as a
## button activation and can swallow the player's Dash input after a HUD click.
func gameplay_button(parent: Node, text: String, rect: Rect2, action: Callable, primary: bool = false, led_color: Color = Color(0, 0, 0, 0)) -> Button:
	var node := button(parent, text, rect, action, primary, led_color)
	node.focus_mode = Control.FOCUS_NONE
	return node


func panel(parent: Node, rect: Rect2, color: Color = SURFACE, border: Color = Color("39284f")) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", panel_style(color, border))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func glow_panel(parent: Node, rect: Rect2, color: Color, accent: Color) -> Panel:
	var node = Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", led_style(color, accent, 2))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func accent_rule(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var node = ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func texture(parent: Node, path: String, rect: Rect2) -> TextureRect:
	var image = TextureRect.new()
	image.texture = load(path)
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func background_texture(parent: Node, path: String, stretch_mode: int = TextureRect.STRETCH_KEEP_ASPECT_COVERED) -> TextureRect:
	var image = TextureRect.new()
	image.texture = load(path)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = stretch_mode
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func clear_overlay() -> void:
	settings_layout_editor = null
	settings_layout_groups.clear()
	for child in overlay.get_children():
		if child is CanvasItem:
			child.hide()
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		child.queue_free()
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.color = Color(0.025, 0.012, 0.065, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

func hide_overlay() -> void:
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func move_overlay_to_front() -> void:
	root.move_child(overlay, -1)

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	panel(hud, Rect2(52, 14, 1176, 83), Color("120c24"), Color("302144"))
	texture(hud, PIXEL_PLAYER_PREVIEW, Rect2(66, 25, 48, 52))
	health_label = label(hud, "", Rect2(126, 20, 278, 22), 16, WHITE, true)
	create_bar("hp", Rect2(128, 48, 114, 9), CORAL)
	create_bar("shield", Rect2(249, 48, 120, 9), CYAN)
	create_bar("energy", Rect2(128, 66, 242, 7), Color("3478ff"))
	title_label = label(hud, "", Rect2(398, 22, 352, 24), 20, WHITE, true)
	room_label = label(hud, "", Rect2(398, 52, 360, 27), 14, MUTED)
	weapon_label = label(hud, "", Rect2(765, 20, 252, 25), 17, CYAN, true)
	secondary_weapon_label = label(hud, "", Rect2(765, 48, 240, 20), 13, MUTED)
	create_bar("resonance", Rect2(765, 72, 235, 6), Color("9b4dff"))
	map_button = gameplay_button(hud, "BẢN ĐỒ", Rect2(1040, 29, 103, 49), game.show_map)
	gameplay_button(hud, "Ⅱ", Rect2(1153, 29, 57, 49), game.pause_game)
	# Each pair intentionally occupies one fixed rect. The label tells the player
	# what a click will do, so SoundOff/SoundOn and MusicOff/MusicOn never coexist.
	sound_toggle_button = gameplay_button(hud, "", sandbox_control_rect(0, 0), game.toggle_short_effects, false, CYAN)
	music_toggle_button = gameplay_button(hud, "", sandbox_control_rect(0, 1), game.toggle_background_music, false, LED_PURPLE)
	build_assignment_demo_controls()
	status_label = label(hud, "", Rect2(300, 601, 545, 28), 18, CYAN, true)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = label(hud, "", Rect2(290, 637, 470, 62), 16, MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label = label(hud, "", Rect2(384, 146, 512, 23), 16, CORAL, true)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_bar("boss", Rect2(390, 134, 500, 6), CORAL)
	beat_display = Control.new()
	beat_display.position = Vector2(672, 108)
	beat_display.size = Vector2(50, 20)
	beat_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beat_display.draw.connect(draw_beat)
	hud.add_child(beat_display)
	minimap = Control.new()
	minimap.position = Vector2(1031, 99)
	minimap.size = Vector2(175, 25)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(draw_minimap)
	hud.add_child(minimap)
	refresh_runtime_audio_controls(true)


func build_assignment_demo_controls() -> void:
	var attacks := [
		["1 · ĐẠN", sandbox_control_rect(1, 0), "pistol", CYAN],
		["2 · TÊN LỬA", sandbox_control_rect(2, 0), "glitch", CORAL],
		["3 · TIA", sandbox_control_rect(3, 0), "beam", LED_PURPLE],
	]
	for item: Array in attacks:
		var attack_button := gameplay_button(hud, str(item[0]), item[1], func(): game.trigger_assignment_attack(str(item[2])), false, item[3])
		attack_button.tooltip_text = "Tấn công demo: %s" % str(item[0])
		demo_controls.append(attack_button)
	var shield_button := gameplay_button(hud, "F · KHIÊN", sandbox_control_rect(1, 1), game.activate_assignment_shield, false, CYAN)
	shield_button.tooltip_text = "Phòng thủ 1: khiên tạm thời"
	demo_controls.append(shield_button)
	var emp_button := gameplay_button(hud, "H · EMP", sandbox_control_rect(2, 1), game.activate_assignment_emp, false, LED_PURPLE)
	emp_button.tooltip_text = "Phòng thủ 2: vô hiệu NPC ngắn hạn"
	demo_controls.append(emp_button)
	var reset_button := gameplay_button(hud, "N · LÀM LẠI", sandbox_control_rect(3, 1), game.reset_assignment_demo, false, CORAL)
	reset_button.tooltip_text = "Hồi lại NPC, X/Y/Z và vùng cảnh báo"
	demo_controls.append(reset_button)
	for control in demo_controls:
		control.visible = false


func sandbox_control_rect(column: int, row: int) -> Rect2:
	# Four equal 140x48 buttons. Each grid step is 160x68, preserving a 20px
	# empty lane around the neon glow both horizontally and vertically.
	return Rect2(Vector2(28 + column * 160, 100 + row * 68), Vector2(140, 48))


func refresh_runtime_audio_controls(force: bool = false) -> void:
	if game == null or sound_toggle_button == null or music_toggle_button == null:
		return
	var sfx_on: bool = game.short_effects_enabled()
	var music_on: bool = game.background_music_enabled()
	if force or _last_sfx_enabled != sfx_on:
		_last_sfx_enabled = sfx_on
		sound_toggle_button.text = "SFX · TẮT" if sfx_on else "SFX · BẬT"
		sound_toggle_button.tooltip_text = "SoundOff: tắt hiệu ứng âm thanh" if sfx_on else "SoundOn: bật hiệu ứng âm thanh"
		apply_runtime_audio_visual(sound_toggle_button, sfx_on, CYAN)
	if force or _last_music_enabled != music_on:
		_last_music_enabled = music_on
		music_toggle_button.text = "NHẠC · TẮT" if music_on else "NHẠC · BẬT"
		music_toggle_button.tooltip_text = "MusicOff: tắt nhạc nền" if music_on else "MusicOn: bật nhạc nền"
		apply_runtime_audio_visual(music_toggle_button, music_on, LED_PURPLE)


func apply_runtime_audio_visual(control: Button, enabled: bool, accent: Color) -> void:
	var border := accent if enabled else CORAL
	var normal_fill := Color("05030a") if enabled else Color("251019")
	var hover_fill := Color("0b0714") if enabled else Color("35121c")
	var normal_style := led_style(normal_fill, border)
	control.add_theme_stylebox_override("normal", normal_style)
	control.add_theme_stylebox_override("hover", led_style(hover_fill, border))
	control.add_theme_stylebox_override("pressed", led_style(Color("140b20"), border))
	control.add_theme_stylebox_override("focus", normal_style)
	var text_color := accent if enabled else CORAL
	control.add_theme_color_override("font_color", text_color)
	control.add_theme_color_override("font_hover_color", text_color)
	control.add_theme_color_override("font_pressed_color", text_color)
	control.add_theme_color_override("font_focus_color", text_color)

func create_bar(id: String, rect: Rect2, color: Color) -> void:
	var progress = ProgressBar.new()
	progress.position = rect.position
	progress.size = rect.size
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color("332642")
	background_style.set_corner_radius_all(3)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	progress.add_theme_stylebox_override("background", background_style)
	progress.add_theme_stylebox_override("fill", fill_style)
	hud.add_child(progress)
	# Reset after theme minimum-size invalidation; pre-theme sizing retains default height.
	progress.set_deferred("size", rect.size)
	bars[id] = progress

func draw_minimap() -> void:
	if game.graph.is_empty(): return
	for i in range(6):
		var at = Vector2(12 + i * 29, 11)
		var color: Color = CYAN if game.cleared.has(i) else Color("756386")
		if i == game.room_index:
			minimap.draw_rect(Rect2(at - Vector2(11, 11), Vector2(23, 23)), Color("163b48"))
			minimap.draw_rect(Rect2(at - Vector2(11, 11), Vector2(23, 23)), CYAN, false, 1)
		var text: String = str(i + 1) if i < 4 else ("+" if i == 4 else "B")
		minimap.draw_string(bold, at + Vector2(-5, 6), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func draw_beat() -> void:
	var current: int = posmod(game.rhythm.beat_index, 4)
	for i in range(4):
		var color: Color = CYAN if i == current else Color("473654")
		var radius: float = 3 + (1.0 - game.rhythm.phase()) * 2 if i == current else 3.0
		beat_display.draw_circle(Vector2(i * 15, 5), radius, color)

func _process(_delta: float) -> void:
	if game == null:
		return
	hud.visible = game.state not in ["menu", "game_over", "victory", "unlocks"]
	if not hud.visible:
		return
	refresh_runtime_audio_controls()
	var demo_visible: bool = game.is_assignment_demo() and game.state == "playing"
	for control in demo_controls:
		control.visible = demo_visible
	var player = game.player
	health_label.text = "HP %d   ◆ %d   ⚡ %d" % [ceili(player.hp), ceili(player.shield), ceili(player.energy)]
	bars.hp.value = player.hp
	bars.shield.max_value = player.max_shield
	bars.shield.value = player.shield
	bars.energy.max_value = player.max_energy
	bars.energy.value = player.energy
	bars.resonance.value = player.resonance
	title_label.text = "SANDBOX · KIỂM TRA CƠ CHẾ" if game.is_assignment_demo() else "%02d  %s" % [game.stage_index + 1, game.content.stages[game.stage_index].name]
	room_label.text = ("Phòng thử độc lập · %d tín dụng · %d:%02d" % [game.coins, int(game.elapsed) / 60, int(game.elapsed) % 60]) if game.is_assignment_demo() else "%s  ·  %d tín dụng  ·  %d:%02d" % [game.room_name(game.room_index), game.coins, int(game.elapsed) / 60, int(game.elapsed) % 60]
	map_button.text = "HƯỚNG DẪN" if game.is_assignment_demo() else "BẢN ĐỒ"
	weapon_label.text = "%d  %s" % [game.active_slot + 1, game.weapon_system.definition(game.weapons[game.active_slot]).name]
	secondary_weapon_label.text = "↔  %d  %s  ·  %d%%" % [(1 - game.active_slot) + 1, game.weapon_system.definition(game.weapons[1 - game.active_slot]).name if game.weapons.size() == 2 else "Pulse Pistol", int(player.resonance)]
	var boss: Vector2 = game.enemies.boss_health()
	bars.boss.visible = boss.y > 0
	boss_label.visible = boss.y > 0
	if boss.y > 0:
		bars.boss.max_value = boss.y
		bars.boss.value = boss.x
		boss_label.text = game.content.stages[game.stage_index].boss
	status_label.text = game.flash_message if game.flash_time > 0 else game.interaction_label()
	status_label.add_theme_color_override("font_color", game.flash_color if game.flash_time > 0 else CYAN)
	if not game.save_error.is_empty():
		hint_label.text = game.save_error
	elif game.tutorial_step < 4 and game.stage_index == 0 and game.room_index == 0:
		var hints: Array = ["Di chuyển: kéo vùng trái / WASD. Chấm trắng là tâm nhân vật.", "Giữ BẮN / chuột trái. Cảm ứng tự ngắm qua đường nhìn.", "Chạm DASH / Space để né. Lướt ngón từ BẮN sang DASH.", "Dash tránh đạn, laser và bẫy; không xuyên tường. Đúng nhịp được +18 cộng hưởng."]
		hint_label.text = hints[game.tutorial_step]
	elif game.is_assignment_demo():
		hint_label.text = "1 ĐẠN · 2 TÊN LỬA · 3 TIA · F KHIÊN · H EMP · chạm X/Y/Z · NPC vào vùng đỏ sẽ báo 4 lần"
	elif game.is_debug_map_tour():
		hint_label.text = "DEBUG MAP · O bật/tắt rào phòng hiện tại · G gọi 1 đợt quái ở C1–C4 · U đấu boss · Y viền map · BẢN ĐỒ nhảy phòng · F6 mở editor"
	elif game.player.resonance >= 100:
		hint_label.text = "PULSE đã sẵn sàng · Chạm PULSE / Q để phá đạn"
	elif not game.combat_active:
		hint_label.text = "Đi bộ qua hành lang sáng; vùng đỏ vẫn bị chặn. Bản đồ cho biết lối đi." if game.is_open_route_stage() else "Đến cửa sáng và nhấn E / DÙNG. Bản đồ cho biết lối đi."
	else:
		hint_label.text = "DASH / Space  ·  PULSE / Q  ·  Đổi / Tab"
	beat_display.queue_redraw()
	minimap.queue_redraw()

func show_menu() -> void:
	clear_overlay()
	# The menu art owns the static button frames. These controls only own the
	# matching rectangular hit regions, labels, focus, hover, and pressed feedback.
	background_texture(overlay, MENU_BACKGROUND, TextureRect.STRETCH_SCALE)
	var veil = ColorRect.new()
	veil.color = Color(0.008, 0.004, 0.035, 0.16)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	var title = led_label(overlay, "NEON", Rect2(0, 37, 1280, 65), 58, CYAN, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle = led_label(overlay, "RESONANCE", Rect2(0, 95, 1280, 52), 44, LED_PURPLE, true)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var has_checkpoint: bool = not game.profile.get("checkpoint", {}).is_empty()
	var continue_action = menu_image_action("continue", "TIẾP TỤC", 0, game.continue_run, CYAN, not has_checkpoint)
	# Starting over discards only the active run, so retain the explicit
	# confirmation instead of silently replacing a recoverable checkpoint.
	var new_run_action: Callable = confirm_new_run if has_checkpoint else game.new_run
	var new_run = menu_image_action("new_run", "LƯỢT MỚI", 1, new_run_action, LED_PURPLE)
	menu_image_action("armory", "KHO VŨ KHÍ", 2, show_unlocks, CYAN)
	menu_image_action("debug", "KHU VỰC DEBUG", 3, show_debug_zones, LED_PURPLE)
	menu_image_action("settings", "CÀI ĐẶT", 4, func(): show_settings("menu"), CYAN)
	if has_checkpoint:
		continue_action.grab_focus()
	else:
		new_run.grab_focus()

func menu_action_rect(index: int) -> Rect2:
	return Rect2(MENU_ACTION_ORIGIN + Vector2(0.0, index * (MENU_ACTION_SIZE.y + MENU_ACTION_GAP)), MENU_ACTION_SIZE)

func menu_image_action(action_id: String, title_text: String, index: int, action: Callable, accent: Color, disabled: bool = false) -> Button:
	var rect := menu_action_rect(index)
	var title_color := Color("69778c") if disabled else accent
	var title_label = label(overlay, title_text, Rect2(rect.position + Vector2(0, 22), Vector2(rect.size.x, 32)), 23, title_color, true)
	title_label.add_theme_color_override("font_outline_color", Color(title_color.r, title_color.g, title_color.b, 0.72))
	title_label.add_theme_color_override("font_shadow_color", Color(title_color.r, title_color.g, title_color.b, 0.82))
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.add_theme_constant_override("shadow_outline_size", 3)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var target = Button.new()
	target.name = "Menu_%s_Hitbox" % action_id
	target.text = title_text
	target.tooltip_text = title_text
	target.position = rect.position
	target.size = rect.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.disabled = disabled
	target.set_meta("menu_action_id", action_id)
	target.set_meta("menu_art_rect", rect)
	var transparent = StyleBoxEmpty.new()
	target.add_theme_stylebox_override("normal", transparent)
	target.add_theme_stylebox_override("disabled", transparent)
	target.add_theme_stylebox_override("hover", menu_hitbox_style(accent, 0.08, 2))
	target.add_theme_stylebox_override("pressed", menu_hitbox_style(accent, 0.16, 3))
	target.add_theme_stylebox_override("focus", transparent)
	var invisible_text := Color(1, 1, 1, 0)
	target.add_theme_color_override("font_color", invisible_text)
	target.add_theme_color_override("font_hover_color", invisible_text)
	target.add_theme_color_override("font_pressed_color", invisible_text)
	target.add_theme_color_override("font_focus_color", invisible_text)
	target.add_theme_color_override("font_disabled_color", invisible_text)
	target.pressed.connect(action)
	overlay.add_child(target)
	return target

func cycle_starter() -> void:
	var unlocked: Array = game.profile.meta.unlocked
	var index: int = unlocked.find(game.starter)
	game.starter = unlocked[(index + 1) % unlocked.size()]
	if game.starter == "pistol" and unlocked.size() > 1:
		game.starter = unlocked[(index + 2) % unlocked.size()]
	show_menu()

func confirm_new_run() -> void:
	clear_overlay()
	panel(overlay, Rect2(340, 220, 600, 290))
	label(overlay, "Bắt đầu lượt mới?", Rect2(380, 250, 520, 48), 29, WHITE, true)
	label(overlay, "Checkpoint của lượt đang dở sẽ được thay thế. Cài đặt và nội dung đã mở khóa vẫn được giữ.", Rect2(380, 310, 510, 84), 21, MUTED)
	button(overlay, "Giữ lượt đang dở", Rect2(378, 426, 241, 52), show_menu).grab_focus()
	button(overlay, "Bắt đầu lượt mới", Rect2(632, 426, 270, 52), game.new_run, true)

func modal_header(title: String, subtitle: String = "") -> void:
	clear_overlay()
	label(overlay, title, Rect2(90, 66, 1100, 65), 38, WHITE, true)
	label(overlay, subtitle, Rect2(92, 138, 1090, 64), 19, MUTED)

func show_rewards(choices: Array) -> void:
	modal_header("TÍN HIỆU ĐÃ ĐƯỢC LÀM SẠCH", "Chọn một nâng cấp cho lượt chơi này. Chiến đấu và nhạc đang tạm dừng.")
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var x: float = 90 + i * 374
		panel(overlay, Rect2(x, 229, 352, 292), Color("1d1234"), Color("624089"))
		label(overlay, "MODULE  %02d" % (i + 1), Rect2(x + 25, 250, 290, 28), 15, CYAN)
		label(overlay, choice.name, Rect2(x + 25, 295, 297, 65), 26, WHITE, true)
		label(overlay, choice.description, Rect2(x + 25, 370, 298, 125), 19, MUTED)
		button(overlay, "CHỌN NÂNG CẤP", Rect2(x, 540, 352, 59), func(): game.choose_upgrade(choice.id), true)
	button(overlay, "Sửa chữa +25 HP", Rect2(476, 638, 328, 49), func(): game.choose_upgrade("repair"))

func show_pause() -> void:
	modal_header("TẠM DỪNG", "Tiếp tục khi bạn sẵn sàng. Nhạc và giao tranh sẽ cùng tiếp tục; mọi thao tác đang giữ đã được xóa.")
	panel(overlay, Rect2(92, 228, 665, 350))
	label(overlay, game.content.stages[game.stage_index].name, Rect2(122, 253, 605, 45), 29, CYAN, true)
	label(overlay, "%s\nSeed %d · %d tín dụng\nCheckpoint được ghi sau phòng và sau khi chọn thưởng." % [game.room_name(game.room_index), game.seed_value, game.coins], Rect2(122, 318, 605, 118), 21, MUTED)
	for i in range(game.weapons.size()):
		var weapon: Dictionary = game.weapon_system.definition(game.weapons[i])
		texture(overlay, gameplay_weapon_model_path(weapon), Rect2(121 + i * 293, 454, 51, 51))
		label(overlay, "%d · %s" % [i + 1, weapon.name], Rect2(182 + i * 293, 460, 220, 51), 18, WHITE)
	button(overlay, "TIẾP TỤC", Rect2(812, 230, 375, 64), game.resume_game, true).grab_focus()
	button(overlay, "Cài đặt", Rect2(812, 314, 375, 57), func(): show_settings("paused"))
	button(overlay, "Gọi lại Pulse Pistol", Rect2(812, 391, 375, 57), func(): game.recall_pistol(); show_pause())
	button(overlay, "Về menu · giữ checkpoint", Rect2(812, 468, 375, 57), game.return_to_menu)
	label(overlay, "Hết năng lượng: tự bắn Pulse Pistol miễn phí cho đến khi năng lượng hồi đủ.", Rect2(123, 614, 1020, 55), 19, MUTED)

func show_map() -> void:
	var continuous_route: bool = game.is_open_route_stage()
	var map_debug: bool = game.is_debug_map_tour()
	var heading := "DEBUG MAP TOUR" if map_debug else ("BẢN ĐỒ LIÊN THÔNG" if continuous_route else "SƠ ĐỒ TẦN SỐ")
	var subtitle := "Tất cả phòng đã mở. O xem rào của phòng hiện tại; G gọi một đợt quái thường tại C1–C4; U đấu boss. Cả hai chế độ debug không thay checkpoint hay phần thưởng." if map_debug else ("Các vùng đã mở nối trực tiếp trên map. Hãy tự đi qua hành lang; vùng đỏ vẫn bị chặn." if continuous_route else "Bốn phòng chiến đấu mở đường đến boss. Trạm hỗ trợ nằm trên một nhánh phụ.")
	modal_header(heading, subtitle)
	for i in range(6):
		var x: float = 92 + (i % 3) * 375
		var y: float = 230 + (i / 3) * 167
		var current: bool = game.room_index == i
		var completed: bool = game.cleared.has(i)
		var name_text: String = game.room_name(i)
		if map_debug:
			var accent := Color(str(game.content.stages[game.stage_index].color))
			button(overlay, "%s\nĐI TỚI · DEBUG" % name_text, Rect2(x, y, 348, 133), func(): game.travel(i), true, accent)
		elif continuous_route:
			var opened: bool = game.is_route_room_open(i)
			var status: String = "ĐANG Ở ĐÂY" if current else ("ĐÃ LÀM SẠCH" if completed else ("ĐÃ MỞ · ĐI BỘ TỚI" if opened else "ĐANG KHÓA"))
			var border := CYAN if current or opened else Color("703548")
			var fill := Color("163b48") if current else (Color("0d2431") if opened else Color("180d20"))
			panel(overlay, Rect2(x, y, 348, 133), fill, border)
			label(overlay, "%s\n%s" % [name_text, status], Rect2(x + 16, y + 25, 316, 86), 20, CYAN if current or opened else MUTED, true)
		else:
			var accessible: bool = not game.combat_active and game.GraphScript.can_enter(game.room_index, i, game.cleared, game.graph)
			var status: String = "ĐANG Ở ĐÂY" if current else ("ĐÃ LÀM SẠCH" if completed else "CHƯA KHÁM PHÁ")
			var control = button(overlay, "%s\n%s" % [name_text, status], Rect2(x, y, 348, 133), func(): game.travel(i), accessible)
			control.disabled = not accessible
	if game.room_index == 5 and game.rewarded.has(5):
		button(overlay, "Khôi phục NOCTIS" if game.stage_index == 4 else "Sang khu vực tiếp theo", Rect2(808, 606, 374, 58), func(): game.travel(6), true)
	button(overlay, "Trở lại phòng", Rect2(92, 606, 342, 58), game.resume_game)
	label(overlay, "O: xem rào · G: 1 đợt quái C1–C4 · U: boss. Combat debug không lưu tiến độ." if map_debug else ("Di chuyển trực tiếp trên map; phòng chưa mở bị chặn." if continuous_route else "Chỉ đi tới phòng nối trực tiếp. Cửa chỉ khóa khi đang giao chiến hoặc đấu boss."), Rect2(453, 611, 335, 58), 16, MUTED)

func show_shop(offers: Array) -> void:
	var kind: String = game.graph.support
	modal_header("TRẠM HỖ TRỢ", "Chọn một dịch vụ. Vũ khí sẽ thay ô đang cầm: %s · Bạn có %d tín dụng." % [game.weapon_system.definition(game.weapons[game.active_slot]).name, game.coins])
	if kind == "heal":
		panel(overlay, Rect2(250, 238, 780, 271))
		label(overlay, "Trạm tái tạo", Rect2(291, 270, 690, 52), 32, CYAN, true)
		label(overlay, "Hồi 45 máu, đầy khiên và năng lượng. Chỉ dùng một lần trong khu vực.", Rect2(291, 348, 690, 82), 25, MUTED)
		button(overlay, "TÁI TẠO MIỄN PHÍ", Rect2(420, 536, 440, 62), game.heal_support, true)
	else:
		var price: int = 0 if kind == "chest" else 55 + game.stage_index * 12
		for i in range(offers.size()):
			var offer: Dictionary = offers[i]
			var x: float = 90 + i * 374
			panel(overlay, Rect2(x, 224, 352, 311))
			texture(overlay, gameplay_weapon_model_path(offer), Rect2(x + 125, 243, 94, 79))
			label(overlay, offer.name, Rect2(x + 23, 334, 308, 40), 24, WHITE, true)
			label(overlay, offer.description, Rect2(x + 23, 385, 307, 128), 18, MUTED)
			var buy = button(overlay, "NHẬN MIỄN PHÍ" if price == 0 else "MUA · %d TÍN DỤNG" % price, Rect2(x, 551, 352, 59), func(): game.buy_weapon(offer.id), true)
			buy.disabled = game.coins < price
	button(overlay, "Để sau · trở lại phòng", Rect2(440, 645, 400, 48), game.resume_game)

func gameplay_weapon_model_path(weapon: Dictionary) -> String:
	var model_path := str(weapon.get("model", ""))
	if not model_path.is_empty() and ResourceLoader.exists(model_path):
		return model_path
	var sprite_path := str(weapon.get("sprite", ""))
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		return sprite_path
	return str(weapon.get("icon", ""))

func show_settings(return_state: String) -> void:
	settings_return = return_state
	game.state = "settings"
	game.controls.reset()
	game.rhythm.pause_music()
	clear_overlay()
	# Settings always opens in normal interaction mode. F7 is an explicit opt-in
	# for moving the four complete layout groups.
	settings_layout_editor_active = false
	# The image is only the external console chassis. Every setting row, its
	# text/value/slider, every switch, and the save button are one runtime
	# component so they share an exact geometry source of truth.
	background_texture(overlay, SETTINGS_BACKGROUND, TextureRect.STRETCH_SCALE)
	var title_group := settings_layout_group("title", SETTINGS_TITLE_GROUP_RECT)
	var title = plain_label(title_group, "CÀI ĐẶT", Rect2(Vector2.ZERO, SETTINGS_TITLE_GROUP_RECT.size), 42, CYAN, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var audio_group := settings_layout_group("audio", SETTINGS_AUDIO_GROUP_RECT)
	plain_label(audio_group, "◼  ÂM THANH & TRẢI NGHIỆM", Rect2(0, 0, SETTINGS_AUDIO_GROUP_RECT.size.x, 28), 19, CYAN, true)
	accent_rule(audio_group, Rect2(0, 32, SETTINGS_AUDIO_GROUP_RECT.size.x, 2), Color(CYAN.r, CYAN.g, CYAN.b, 0.65))
	setting_slider(audio_group, "music", "Âm lượng nhạc", 0, 1, 0.05, Rect2(0, 42, SETTINGS_SLIDER_ROW_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 100, "%", CYAN)
	setting_slider(audio_group, "sfx", "Âm lượng hiệu ứng", 0, 1, 0.05, Rect2(0, 136, SETTINGS_SLIDER_ROW_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 100, "%", CYAN)
	setting_slider(audio_group, "latency_ms", "Bù độ trễ nhịp", -300, 300, 5, Rect2(0, 230, SETTINGS_SLIDER_ROW_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 1, " ms", CYAN)
	setting_slider(audio_group, "screen_shake", "Rung màn hình", 0, 1, 0.1, Rect2(0, 324, SETTINGS_SLIDER_ROW_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 100, "%", CYAN)
	var controls_group := settings_layout_group("controls", SETTINGS_CONTROL_GROUP_RECT)
	plain_label(controls_group, "◼  ĐIỀU KHIỂN & GIAO DIỆN", Rect2(0, 0, SETTINGS_CONTROL_GROUP_RECT.size.x, 28), 19, LED_PURPLE, true)
	accent_rule(controls_group, Rect2(0, 32, SETTINGS_CONTROL_GROUP_RECT.size.x, 2), Color(LED_PURPLE.r, LED_PURPLE.g, LED_PURPLE.b, 0.65))
	setting_slider(controls_group, "touch_scale", "Kích thước nút", 0.85, 1.1, 0.05, Rect2(0, 42, SETTINGS_TOGGLE_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 100, "%", LED_PURPLE)
	setting_slider(controls_group, "touch_opacity", "Độ rõ nút cảm ứng", 0.25, 1, 0.05, Rect2(0, 136, SETTINGS_TOGGLE_SIZE.x, SETTINGS_SLIDER_ROW_SIZE.y), 100, "%", LED_PURPLE)
	setting_toggle(controls_group, "auto_aim", "Tự ngắm khi dùng cảm ứng", Vector2(9, 214), LED_PURPLE)
	setting_toggle(controls_group, "vibration", "Rung thiết bị", Vector2(9, 290), LED_PURPLE)
	setting_toggle(controls_group, "reduced_flashes", "Giảm hiệu ứng sáng", Vector2(9, 366), LED_PURPLE)
	var save_group := settings_layout_group("save", SETTINGS_SAVE_RECT)
	settings_save_action(save_group, Rect2(Vector2.ZERO, SETTINGS_SAVE_RECT.size))
	show_settings_layout_editor()

func settings_layout_group(group_id: String, rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "SettingsLayout_%s" % group_id.capitalize()
	group.position = settings_layout_position_for(group_id, rect)
	group.size = rect.size
	group.mouse_filter = Control.MOUSE_FILTER_PASS
	group.set_meta("settings_layout_group_id", group_id)
	group.set_meta("settings_layout_default_position", rect.position)
	overlay.add_child(group)
	settings_layout_groups[group_id] = group
	return group

func settings_layout_position_for(group_id: String, rect: Rect2) -> Vector2:
	var stored = settings_layout_positions.get(group_id, rect.position)
	if not (stored is Vector2):
		return rect.position
	var candidate: Vector2 = stored
	var maximum := SETTINGS_LAYOUT_VIEWPORT_SIZE - rect.size
	return Vector2(clampf(candidate.x, 0.0, maxf(0.0, maximum.x)), clampf(candidate.y, 0.0, maxf(0.0, maximum.y)))

func _load_settings_layout_positions() -> void:
	settings_layout_positions.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("settings_layout_positions", {})
	if not stored is Dictionary:
		return
	for group_id in SETTINGS_LAYOUT_GROUP_IDS:
		var encoded: Variant = stored.get(group_id)
		if not encoded is Array or encoded.size() != 2:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])):
			continue
		settings_layout_positions[group_id] = Vector2(float(encoded[0]), float(encoded[1]))

func _serialized_settings_layout_positions() -> Dictionary:
	var output: Dictionary = {}
	for group_id in SETTINGS_LAYOUT_GROUP_IDS:
		var position: Variant = settings_layout_positions.get(group_id)
		if position is Vector2:
			output[group_id] = [position.x, position.y]
	return output

func _sync_settings_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["settings_layout_positions"] = _serialized_settings_layout_positions()

func save_settings_layout_positions() -> bool:
	_sync_settings_layout_to_runtime_settings()
	return game != null and game.persist_profile()

func show_settings_layout_editor() -> void:
	if not settings_layout_editor_is_available():
		return
	var editor = SettingsLayoutEditorScript.new()
	editor.name = "Settings_LayoutEditor"
	overlay.add_child(editor)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.configure([
		{"id": "title", "target": settings_layout_groups.get("title"), "label": "TIÊU ĐỀ", "accent": CYAN, "default_position": SETTINGS_TITLE_GROUP_RECT.position},
		{"id": "audio", "target": settings_layout_groups.get("audio"), "label": "ÂM THANH", "accent": CYAN, "default_position": SETTINGS_AUDIO_GROUP_RECT.position},
		{"id": "controls", "target": settings_layout_groups.get("controls"), "label": "ĐIỀU KHIỂN", "accent": LED_PURPLE, "default_position": SETTINGS_CONTROL_GROUP_RECT.position},
		{"id": "save", "target": settings_layout_groups.get("save"), "label": "LƯU", "accent": CYAN, "default_position": SETTINGS_SAVE_RECT.position},
	], font, bold)
	editor.group_moved.connect(_on_settings_layout_group_moved)
	settings_layout_editor = editor
	settings_layout_editor.set_editor_active(settings_layout_editor_active)
	refresh_settings_layout_metadata()

func settings_layout_editor_is_available() -> bool:
	return SETTINGS_LAYOUT_EDITOR_TEMPORARY_ENABLED and OS.is_debug_build() and game != null and not game.test_mode

func _on_settings_layout_group_moved(group_id: String, position: Vector2) -> void:
	settings_layout_positions[group_id] = position
	_sync_settings_layout_to_runtime_settings()
	refresh_settings_layout_metadata()

func refresh_settings_layout_metadata() -> void:
	for child in overlay.find_children("*", "", true, false):
		if child is Panel and child.has_meta("settings_component_key"):
			child.set_meta("settings_component_rect", Rect2(child.get_global_position(), child.size))
		elif child is HSlider and child.has_meta("settings_art_rect"):
			child.set_meta("settings_art_rect", Rect2(child.get_global_position(), child.size))
		elif child is Button and child.has_meta("settings_art_rect"):
			child.set_meta("settings_art_rect", Rect2(child.get_global_position(), child.size))

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.state != "settings" or settings_layout_editor == null or not is_instance_valid(settings_layout_editor):
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_F7:
		if settings_layout_editor_active:
			# F7 on the active editor is the commit boundary. Keep the editor open
			# when persistence fails so a layout cannot be mistaken for saved work.
			if not save_settings_layout_positions():
				get_viewport().set_input_as_handled()
				return
			settings_layout_editor_active = false
			settings_layout_editor.set_editor_active(false)
		else:
			settings_layout_editor_active = true
			settings_layout_editor.set_editor_active(true)
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_R and settings_layout_editor.is_editor_active():
		settings_layout_editor.reset_layout()
		get_viewport().set_input_as_handled()

func settings_control_shell(parent: Node, key: String, rect: Rect2, accent: Color) -> Panel:
	var shell := Panel.new()
	shell.name = "Settings_%s_Component" % key
	shell.position = rect.position
	shell.size = rect.size
	# PASS keeps the decorative shell out of the way while its child HSlider
	# remains the single interactive touch target for this row.
	shell.mouse_filter = Control.MOUSE_FILTER_PASS
	shell.set_meta("settings_component_key", key)
	var shell_style := panel_style(Color(0.004, 0.009, 0.025, 0.82), Color(accent.r, accent.g, accent.b, 0.48))
	shell_style.set_corner_radius_all(7)
	shell_style.shadow_size = 0
	shell.add_theme_stylebox_override("panel", shell_style)
	parent.add_child(shell)
	shell.set_meta("settings_component_rect", Rect2(shell.get_global_position(), shell.size))
	return shell

func settings_value_text(value: float, multiplier: float, suffix: String) -> String:
	return "%d%s" % [roundi(value * multiplier), suffix]

func settings_value_rect(value_text: String, shell_width: float) -> Rect2:
	var text_width := ceilf(font.get_string_size(value_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
	var chip_width := clampf(text_width + 22.0, 54.0, 96.0)
	return Rect2(shell_width - 16.0 - chip_width, 7.0, chip_width, 26.0)

func setting_slider(parent: Node, key: String, name_text: String, minimum: float, maximum: float, step: float, row_rect: Rect2, multiplier: float, suffix: String, accent: Color = CYAN) -> void:
	var shell := settings_control_shell(parent, key, row_rect, accent)
	var current_value_text := settings_value_text(float(game.settings[key]), multiplier, suffix)
	var value_rect := settings_value_rect(current_value_text, shell.size.x)
	var name_label := label(shell, name_text, Rect2(16, 7, value_rect.position.x - 24.0, 25), 20, WHITE)
	name_label.name = "Settings_%s_Label" % key
	name_label.add_theme_color_override("font_outline_color", Color(accent.r, accent.g, accent.b, 0.22))
	name_label.add_theme_constant_override("outline_size", 1)
	var value_chip := settings_value_chip(shell, value_rect, accent)
	value_chip.name = "Settings_%s_ValueChip" % key
	value_chip.set_meta("settings_value_chip_key", key)
	var value_label := label(shell, current_value_text, value_rect, 18, WHITE)
	value_label.name = "Settings_%s_Value" % key
	value_label.set_meta("settings_value_key", key)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_constant_override("outline_size", 0)
	value_label.add_theme_constant_override("shadow_outline_size", 0)
	value_label.add_theme_constant_override("shadow_offset_x", 0)
	value_label.add_theme_constant_override("shadow_offset_y", 0)
	var slider = HSlider.new()
	slider.name = "Settings_%s_Slider" % key
	slider.position = Vector2(16, 37)
	slider.size = Vector2(shell.size.x - 32, 22)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(game.settings[key])
	slider.tooltip_text = name_text
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.set_meta("settings_slider_key", key)
	slider.set_meta("settings_component_key", key)
	var slider_visual := Control.new()
	slider_visual.name = "Settings_%s_LedFill" % key
	slider_visual.position = slider.position
	slider_visual.size = slider.size
	slider_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_visual.set_meta("settings_slider_visual_key", key)
	slider_visual.set_meta("settings_slider_led_accent", accent)
	slider_visual.draw.connect(func(): draw_settings_slider_led_fill(slider_visual, slider.value, minimum, maximum, accent))
	var transparent_surface := StyleBoxEmpty.new()
	slider.add_theme_stylebox_override("slider", transparent_surface)
	slider.add_theme_stylebox_override("grabber_area", transparent_surface)
	slider.add_theme_stylebox_override("grabber_area_highlighted", transparent_surface)
	slider.add_theme_stylebox_override("focus", transparent_surface)
	var grabber = slider_grabber_texture(accent)
	slider.add_theme_icon_override("grabber", grabber)
	slider.add_theme_icon_override("grabber_highlight", grabber)
	slider.value_changed.connect(func(value: float):
		game.settings[key] = value
		var updated_value_text := settings_value_text(value, multiplier, suffix)
		var updated_value_rect := settings_value_rect(updated_value_text, shell.size.x)
		value_label.text = updated_value_text
		value_chip.position = updated_value_rect.position
		value_chip.size = updated_value_rect.size
		value_label.position = updated_value_rect.position
		value_label.size = updated_value_rect.size
		name_label.size.x = updated_value_rect.position.x - 24.0
		slider_visual.queue_redraw()
		game.audio.set_volumes(game.settings.music, game.settings.sfx)
		game.rhythm.offset_ms = float(game.settings.latency_ms)
	)
	shell.add_child(slider_visual)
	shell.add_child(slider)
	slider.set_meta("settings_art_rect", Rect2(slider.get_global_position(), slider.size))
	slider_visual.queue_redraw()

func settings_value_chip(parent: Node, rect: Rect2, accent: Color) -> Panel:
	var chip := Panel.new()
	chip.position = rect.position
	chip.size = rect.size
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_style := panel_style(Color(0.004, 0.009, 0.025, 0.76), Color(accent.r, accent.g, accent.b, 0.46))
	chip_style.set_corner_radius_all(6)
	chip_style.shadow_size = 0
	chip.add_theme_stylebox_override("panel", chip_style)
	parent.add_child(chip)
	return chip

func setting_toggle(parent: Node, key: String, name_text: String, at: Vector2, accent: Color = LED_PURPLE) -> void:
	var check = Button.new()
	check.name = "Settings_%s_Toggle" % key
	check.text = name_text
	check.tooltip_text = name_text
	check.position = at
	check.size = SETTINGS_TOGGLE_SIZE
	check.toggle_mode = true
	check.alignment = HORIZONTAL_ALIGNMENT_LEFT
	check.focus_mode = Control.FOCUS_ALL
	check.flat = true
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.button_pressed = bool(game.settings[key])
	check.set_meta("settings_toggle_key", key)
	check.set_meta("settings_component_key", key)
	var indicator = Control.new()
	indicator.name = "Settings_%s_Indicator" % key
	indicator.position = Vector2(check.size.x - 92, 4)
	indicator.size = Vector2(76, 32)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.draw.connect(func(): draw_toggle_indicator(indicator, check.button_pressed, accent))
	check.add_child(indicator)
	apply_toggle_visual(check, check.button_pressed, accent)
	check.toggled.connect(func(value: bool):
		game.settings[key] = value
		apply_toggle_visual(check, value, accent)
		indicator.queue_redraw()
	)
	parent.add_child(check)
	check.set_meta("settings_art_rect", Rect2(check.get_global_position(), check.size))

func apply_toggle_visual(check: Button, active: bool, accent: Color) -> void:
	var fill = Color(accent.r, accent.g, accent.b, 0.15) if active else Color(0.004, 0.009, 0.025, 0.82)
	var border = Color(accent.r, accent.g, accent.b, 0.84) if active else Color(accent.r, accent.g, accent.b, 0.48)
	var component_style := panel_style(fill, border)
	component_style.set_corner_radius_all(7)
	component_style.shadow_size = 0
	check.add_theme_stylebox_override("normal", component_style)
	check.add_theme_stylebox_override("hover", component_style)
	check.add_theme_stylebox_override("pressed", component_style)
	check.add_theme_stylebox_override("focus", component_style)
	var text_color = accent if active else WHITE
	check.add_theme_color_override("font_color", text_color)
	check.add_theme_color_override("font_hover_color", text_color)
	check.add_theme_color_override("font_pressed_color", text_color)
	check.add_theme_color_override("font_hover_pressed_color", text_color)
	check.add_theme_color_override("font_focus_color", text_color)

func draw_toggle_indicator(canvas: Control, active: bool, accent: Color) -> void:
	var track = StyleBoxFlat.new()
	track.bg_color = Color(accent.r, accent.g, accent.b, 0.26) if active else Color("151020")
	track.border_color = accent if active else Color("625b70")
	track.set_border_width_all(1)
	track.set_corner_radius_all(12)
	canvas.draw_style_box(track, Rect2(2, 4, 70, 24))
	var center := Vector2(53.0 if active else 20.0, 16.0)
	var core := accent if active else Color("938aa5")
	canvas.draw_circle(center, 8.0, core)
	canvas.draw_arc(center, 8.0, 0.0, TAU, 16, Color(WHITE.r, WHITE.g, WHITE.b, 0.68), 1.0, true)
	if active:
		canvas.draw_line(center + Vector2(-3.5, 0.0), center + Vector2(-0.5, 3.0), INK, 1.5, true)
		canvas.draw_line(center + Vector2(-0.5, 3.0), center + Vector2(4.5, -4.0), INK, 1.5, true)
	else:
		canvas.draw_line(center + Vector2(-3.0, 0.0), center + Vector2(3.0, 0.0), INK, 1.5, true)

func settings_save_action(parent: Node, rect: Rect2) -> Button:
	var target := Button.new()
	target.name = "Settings_Save_Hitbox"
	target.text = "LƯU VÀ TRỞ LẠI"
	target.tooltip_text = "Lưu cài đặt và trở lại"
	target.position = rect.position
	target.size = rect.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = false
	target.set_meta("settings_action_id", "save_and_return")
	var component_style := panel_style(Color(0.004, 0.009, 0.025, 0.88), Color(CYAN.r, CYAN.g, CYAN.b, 0.82), 1)
	component_style.set_corner_radius_all(7)
	component_style.shadow_size = 0
	target.add_theme_stylebox_override("normal", component_style)
	target.add_theme_stylebox_override("hover", component_style)
	target.add_theme_stylebox_override("pressed", component_style)
	target.add_theme_stylebox_override("focus", component_style)
	target.add_theme_color_override("font_color", CYAN)
	target.add_theme_color_override("font_hover_color", CYAN)
	target.add_theme_color_override("font_pressed_color", CYAN)
	target.add_theme_color_override("font_focus_color", CYAN)
	target.add_theme_color_override("font_outline_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.42))
	target.add_theme_constant_override("outline_size", 1)
	target.pressed.connect(close_settings)
	parent.add_child(target)
	target.set_meta("settings_art_rect", Rect2(target.get_global_position(), target.size))
	return target

func close_settings() -> void:
	game.persist_profile()
	if settings_return == "menu":
		game.return_to_menu()
	else:
		game.state = "paused"
		show_pause()

func show_help() -> void:
	modal_header("SỬA CHỮA THÀNH PHỐ BẰNG NHỊP ĐIỆU", "ECHO RUNNER có thể di chuyển, bắn và dash bất kỳ lúc nào. Thao tác đúng nhịp được thưởng thêm.")
	var titles: Array = ["01  DI CHUYỂN & BẮN", "02  DASH & CỘNG HƯỞNG", "03  ĐỌC CẢNH BÁO"]
	var bodies: Array = ["Cảm ứng: kéo bên trái để đi, giữ BẮN bên phải. Tự ngắm chỉ chọn địch có đường nhìn.\n\nPC: WASD + chuột. Tab đổi súng, E tương tác, Esc tạm dừng.", "Dash / Space né xuyên nguy hiểm trong thời gian ngắn, dừng ở tường.\n\nDash trong ±120 ms quanh beat cho +18 Resonance khi giao tranh. Đầy thanh: PULSE / Q gây sát thương và xóa đạn gần.", "Vạch nét đứt / vùng viền: đang báo trước. Lõi sáng đặc: đang gây sát thương.\n\nLaser và vùng sàn không thể bị Pulse xóa. Đạn có hình riêng. Đèn 4 nhịp luôn hoạt động kể cả khi tắt tiếng."]
	for i in range(3):
		var x: float = 90 + i * 374
		panel(overlay, Rect2(x, 234, 352, 351))
		label(overlay, titles[i], Rect2(x + 22, 258, 309, 53), 19, CYAN, true)
		label(overlay, bodies[i], Rect2(x + 22, 324, 307, 244), 19, MUTED)
	button(overlay, "ĐÃ HIỂU", Rect2(463, 624, 354, 60), show_menu, true)

func show_unlocks() -> void:
	game.state = "unlocks"
	clear_overlay()
	# The artwork owns the chassis, data bays, and return frame. Every mutable
	# element below remains runtime UI so current loadout data never becomes baked
	# into the image.
	background_texture(overlay, ARMORY_BACKGROUND, TextureRect.STRETCH_SCALE)
	var veil = ColorRect.new()
	veil.color = Color(0.004, 0.01, 0.028, 0.12)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	var title = led_label(overlay, "KHO VŨ KHÍ", Rect2(64, 36, 480, 58), 42, Color("d9fbff"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	accent_rule(overlay, Rect2(64, 117, 426, 2), Color(CYAN.r, CYAN.g, CYAN.b, 0.74))
	var first_action: Button
	for i in range(game.content.weapons.size()):
		var weapon: Dictionary = game.content.weapons[i]
		var column: int = i % 4
		var row: int = i / 4
		var card_position: Vector2 = ARMORY_GRID_ORIGIN + Vector2(column * (ARMORY_CARD_SIZE.x + ARMORY_CARD_GAP.x), row * (ARMORY_CARD_SIZE.y + ARMORY_CARD_GAP.y))
		var card_rect := Rect2(card_position, ARMORY_CARD_SIZE)
		var unlocked: bool = game.profile.meta.unlocked.has(weapon.id)
		var fixed_primary: bool = weapon.id == "pistol"
		var selected: bool = unlocked and weapon.id == game.starter
		var state: int = armory_loadout_state(fixed_primary, selected, unlocked)
		var can_activate: bool = not fixed_primary and not selected and (unlocked or int(game.profile.meta.shards) >= 8)
		var accent: Color = LED_PURPLE if selected else (Color("b5f7ff") if fixed_primary else (CYAN if unlocked else Color("756b91")))
		var state_visual = WeaponLoadoutStateScript.new()
		state_visual.name = "ArmoryState_%s" % weapon.id
		state_visual.position = card_position
		state_visual.size = ARMORY_CARD_SIZE
		state_visual.set_meta("armory_weapon_id", weapon.id)
		state_visual.configure(state, str(weapon.id), can_activate)
		overlay.add_child(state_visual)
		armory_weapon_details(weapon, i, card_position, accent)
		var action: Callable = func(): game.select_starter(weapon.id) if unlocked else game.unlock_weapon(weapon.id)
		var weapon_button := armory_weapon_hitbox(str(weapon.id), str(weapon.name), card_rect, action, can_activate, state_visual)
		if first_action == null and can_activate:
			first_action = weapon_button
	var return_button := armory_return_button()
	if first_action != null:
		first_action.grab_focus()
	else:
		return_button.grab_focus()

func armory_loadout_state(fixed_primary: bool, selected: bool, unlocked: bool) -> int:
	if fixed_primary:
		return WeaponLoadoutStateScript.State.FIXED
	if selected:
		return WeaponLoadoutStateScript.State.EQUIPPED
	if unlocked:
		return WeaponLoadoutStateScript.State.AVAILABLE
	return WeaponLoadoutStateScript.State.LOCKED

func armory_weapon_details(weapon: Dictionary, index: int, card_position: Vector2, accent: Color) -> void:
	label(overlay, "%02d" % (index + 1), Rect2(card_position + Vector2(15, 10), Vector2(34, 17)), 11, accent, true)
	var model_path := gameplay_weapon_model_path(weapon)
	var model_preview := texture(overlay, model_path, Rect2(card_position + ARMORY_MODEL_PREVIEW_ORIGIN, ARMORY_MODEL_PREVIEW_SIZE))
	model_preview.name = "Armory_%s_GameplayModel" % weapon.id
	model_preview.set_meta("armory_weapon_model_id", str(weapon.id))
	model_preview.set_meta("armory_weapon_model_path", model_path)
	var name_label = label(overlay, str(weapon.name), Rect2(card_position + Vector2(92, 18), Vector2(154, 23)), 15, WHITE, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF

func armory_weapon_hitbox(action_id: String, weapon_name: String, card_rect: Rect2, action: Callable, can_activate: bool, state_visual) -> Button:
	var target = Button.new()
	target.name = "Armory_%s_Hitbox" % action_id
	target.text = weapon_name
	target.tooltip_text = weapon_name
	target.position = card_rect.position
	target.size = card_rect.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.disabled = not can_activate
	target.set_meta("armory_weapon_id", action_id)
	target.set_meta("armory_art_rect", card_rect)
	var transparent = StyleBoxEmpty.new()
	target.add_theme_stylebox_override("normal", transparent)
	target.add_theme_stylebox_override("disabled", transparent)
	# The card must not visually react merely because the pointer passes over it.
	# Focus stays visually neutral; press still gives touch/click feedback.
	target.add_theme_stylebox_override("hover", transparent)
	target.add_theme_stylebox_override("pressed", menu_hitbox_style(CYAN, 0.08, 2))
	target.add_theme_stylebox_override("focus", transparent)
	var invisible_text := Color(1, 1, 1, 0)
	target.add_theme_color_override("font_color", invisible_text)
	target.add_theme_color_override("font_hover_color", invisible_text)
	target.add_theme_color_override("font_pressed_color", invisible_text)
	target.add_theme_color_override("font_focus_color", invisible_text)
	target.add_theme_color_override("font_disabled_color", invisible_text)
	target.pressed.connect(action)
	target.button_down.connect(func(): state_visual.set_interaction_feedback(true))
	target.button_up.connect(func(): state_visual.set_interaction_feedback(false))
	overlay.add_child(target)
	return target

func armory_return_button() -> Button:
	var target = Button.new()
	target.name = "Armory_Return_Hitbox"
	target.text = "‹  TRỞ LẠI MENU"
	target.tooltip_text = "Trở lại menu"
	target.position = ARMORY_RETURN_RECT.position
	target.size = ARMORY_RETURN_RECT.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	var transparent = StyleBoxEmpty.new()
	target.add_theme_stylebox_override("normal", transparent)
	target.add_theme_stylebox_override("hover", menu_hitbox_style(CYAN, 0.06, 2))
	target.add_theme_stylebox_override("pressed", menu_hitbox_style(CYAN, 0.12, 3))
	target.add_theme_stylebox_override("focus", transparent)
	target.add_theme_color_override("font_color", CYAN)
	target.add_theme_color_override("font_hover_color", WHITE)
	target.add_theme_color_override("font_pressed_color", CYAN)
	target.add_theme_color_override("font_focus_color", CYAN)
	target.pressed.connect(game.return_to_menu)
	overlay.add_child(target)
	return target

func show_debug_zones() -> void:
	modal_header("KHU VỰC DEBUG", "Mở toàn bộ phòng để vẽ và test map. Hoặc vào Bài Demo để kiểm tra đủ âm thanh, 3 tấn công, 2 phòng thủ, X/Y/Z và vùng cấm. Không thay checkpoint hoặc thống kê chiến dịch.")
	for i in range(game.content.stages.size()):
		var stage: Dictionary = game.content.stages[i]
		var column: int = i % 2
		var row: int = i / 2
		var x: float = 132 + column * 518
		var y: float = 226 + row * 118
		var accent := Color(str(stage.color))
		panel(overlay, Rect2(x, y, 496, 96), Color("091225"), accent)
		label(overlay, "KHU VỰC %02d" % (i + 1), Rect2(x + 18, y + 14, 116, 21), 13, accent, true)
		label(overlay, str(stage.name), Rect2(x + 18, y + 41, 275, 34), 21, WHITE, true)
		button(overlay, "VÀO TEST", Rect2(x + 332, y + 23, 143, 50), func(): game.start_debug_stage(i), true, accent)
	panel(overlay, Rect2(650, 462, 496, 96), Color("120d25"), CORAL)
	label(overlay, "KHU VỰC DEMO", Rect2(668, 476, 290, 21), 14, CORAL, true)
	label(overlay, "Sandbox", Rect2(668, 505, 300, 30), 17, WHITE, true)
	button(overlay, "VÀO DEMO", Rect2(978, 485, 143, 50), game.start_assignment_demo, true, CORAL)
	button(overlay, "‹  TRỞ LẠI MENU", Rect2(460, 638, 360, 50), show_menu, false, LED_PURPLE)


func show_assignment_demo_info() -> void:
	modal_header("SANDBOX · HƯỚNG DẪN KIỂM TRA", "Đây là phòng debug độc lập: không ghi checkpoint, tiền hoặc thống kê của chiến dịch.")
	panel(overlay, Rect2(110, 224, 500, 315), Color("091225"), CYAN)
	panel(overlay, Rect2(670, 224, 500, 315), Color("160d25"), LED_PURPLE)
	label(overlay, "A · DI CHUYỂN / TẤN CÔNG", Rect2(140, 252, 440, 32), 21, CYAN, true)
	label(overlay, "Di chuyển: WASD hoặc cần trái\n\n1 / ĐẠN: Pulse Pistol\n2 / TÊN LỬA: Glitch Launcher nổ vùng\n3 / TIA: Prism Beam\n\nMỗi đòn gọi hiệu ứng âm thanh ngắn. Các nút SANDBOX trên HUD cũng dùng được bằng chạm/click.", Rect2(140, 302, 436, 207), 18, WHITE)
	label(overlay, "PHÒNG THỦ / VA CHẠM", Rect2(700, 252, 440, 32), 21, LED_PURPLE, true)
	label(overlay, "F / KHIÊN: bảo vệ 3 giây, xóa đạn gần\nH / EMP: vô hiệu NPC trong vùng 2.5 giây\n\nChạm X: +20 tín dụng, tăng tốc\nChạm Y: hồi HP, tăng khiên\nChạm Z: nổ, giảm HP/khiên, làm chậm\n\nNPC đi vào vùng đỏ sẽ phát 4 cảnh báo liên tiếp.", Rect2(700, 302, 436, 207), 18, WHITE)
	button(overlay, "N · LÀM LẠI DEMO", Rect2(268, 582, 320, 58), game.reset_assignment_demo, false, CORAL)
	button(overlay, "TIẾP TỤC TEST", Rect2(692, 582, 320, 58), game.resume_game, true, CYAN)

func show_result(victory: bool) -> void:
	clear_overlay()
	label(overlay, "BẢN PHỐI ĐÃ TRỌN VẸN" if victory else "TÍN HIỆU ĐÃ NGẮT", Rect2(120, 91, 1060, 71), 48, CYAN if victory else CORAL, true)
	label(overlay, "NOCTIS lại cất tiếng. Trong hàng triệu âm thanh, vẫn có một nhịp chờ người sửa chữa trở về." if victory else "THE SILENCE tạm thời thắng thế. Mảnh cộng hưởng được giữ lại để mở thêm lựa chọn cho lượt sau.", Rect2(124, 184, 997, 105), 25, MUTED)
	panel(overlay, Rect2(123, 332, 1025, 177))
	var stats: Array = [["KHU VỰC", "%d / 5" % (game.stage_index + 1)], ["THỜI GIAN", "%d:%02d" % [int(game.elapsed) / 60, int(game.elapsed) % 60]], ["ĐỊCH ĐÃ HẠ", str(game.run_kills)], ["PERFECT DASH", str(game.perfect_count)]]
	for i in range(4):
		label(overlay, stats[i][0], Rect2(155 + i * 254, 356, 219, 30), 15, MUTED)
		label(overlay, stats[i][1], Rect2(155 + i * 254, 402, 219, 64), 39, WHITE, true)
	button(overlay, "CHƠI LẠI", Rect2(123, 558, 485, 65), game.new_run, true).grab_focus()
	button(overlay, "Về menu", Rect2(631, 558, 517, 65), game.return_to_menu)
	label(overlay, "Seed %d · Mảnh cộng hưởng tích lũy: %d" % [game.seed_value, game.profile.meta.shards], Rect2(125, 655, 1020, 36), 17, MUTED)
