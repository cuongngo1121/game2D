class_name GameUI
extends CanvasLayer

var game
var root: Control
var overlay: Control
var hud: Control
var hud_art: TextureRect
var font: Font
var bold: Font
var title_label: Label
var room_label: Label
var health_label: Label
var weapon_label: Label
var secondary_weapon_label: Label
var current_weapon_preview: TextureRect
var secondary_weapon_preview: TextureRect
var current_weapon_box: Panel
var current_weapon_button: Button
var status_label: Label
var hint_label: Label
var boss_label: Label
var coin_label: Label
var shop_button: Button
var tutorial_panel: Panel
var tutorial_label: Label
var tutorial_skip_button: Button
var tutorial_displayed_step: int = -1
var campaign_difficulty_buttons: Dictionary = {}
var bars: Dictionary = {}
var beat_display: Control
var minimap: Control
var map_button: Button
var menu_button: Button
var pause_button: Button
var sound_toggle_button: Button
var music_toggle_button: Button
var demo_controls: Array[Control] = []
var hud_layout_editor
var hud_layout_groups: Dictionary = {}
var hud_layout_positions: Dictionary = {}
var hud_layout_scales: Dictionary = {}
var armory_layout_editor
var armory_layout_controls: Dictionary = {}
var armory_layout_positions: Dictionary = {}
var armory_layout_scales: Dictionary = {}
var current_armory_tab: String = "weapons"
var pause_layout_editor
var pause_layout_groups: Dictionary = {}
var pause_layout_positions: Dictionary = {}
var pause_layout_scales: Dictionary = {}
var reward_layout_editor
var reward_layout_groups: Dictionary = {}
var reward_layout_positions: Dictionary = {}
var reward_layout_scales: Dictionary = {}
var reward_layout_preview_active: bool = false
var reward_preview_restore_state: String = ""
var support_layout_editor
var support_layout_groups: Dictionary = {}
var support_layout_positions: Dictionary = {}
var support_layout_scales: Dictionary = {}
var hud_title_default_position := Vector2.ZERO
var hud_title_anchor := Vector2.ZERO
var hud_title_anchor_valid: bool = false
var _last_sfx_enabled: bool = true
var _last_music_enabled: bool = true
var _last_hud_title_text: String = ""
var overlay_box: Control
var settings_return: String = "menu"
var theme_resource: Theme
var menu_background_base: TextureRect
var menu_background_layers: Array[Dictionary] = []
var menu_background_time: float = 0.0
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
const MENU_BACKGROUND_BASE := "res://background/2 Background/1.png"
const MENU_BACKGROUND_LAYERS := [
	{"path": "res://background/2 Background/2.png", "speed": 2.0},
	{"path": "res://background/2 Background/3.png", "speed": 4.0},
	{"path": "res://background/2 Background/4.png", "speed": 7.0},
	{"path": "res://background/2 Background/5.png", "speed": 12.0},
]
const ARMORY_BACKGROUND := "res://assets/backgrounds/armory_loadout_matrix_v1.png"
const SETTINGS_BACKGROUND := "res://assets/backgrounds/settings_calibration_console_v2.png"
const GAMEPLAY_HUD_BACKGROUND := "res://assets/backgrounds/gameplay_hud_overlay_v5.png"
const PAUSE_BACKGROUND := "res://assets/backgrounds/pause_menu_overlay_v1.png"
const REWARD_BACKGROUND := "res://assets/backgrounds/upgrade_reward_overlay_v1.png"
const WeaponLoadoutStateScript = preload("res://scripts/ui/weapon_loadout_state.gd")
const SettingsLayoutEditorScript = preload("res://scripts/ui/settings_layout_editor.gd")
const HudLayoutEditorScript = preload("res://scripts/ui/hud_layout_editor.gd")
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
const HUD_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const HUD_LAYOUT_ITEM_IDS := ["hp", "shield", "energy", "title", "weapon", "pause", "boss"]
const TOUCH_LAYOUT_ITEM_IDS := ["move", "fire", "dash", "pulse"]
const HUD_LAYOUT_EDITOR_ENABLED := true
const ARMORY_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const ARMORY_LAYOUT_ITEM_IDS := [
	"title",
	"pistol_stt", "pistol_name", "pistol_action",
	"smg_stt", "smg_name", "smg_action",
	"shotgun_stt", "shotgun_name", "shotgun_action",
	"rail_stt", "rail_name", "rail_action",
	"beam_stt", "beam_name", "beam_action",
	"disc_stt", "disc_name", "disc_action",
	"arc_stt", "arc_name", "arc_action",
	"wave_stt", "wave_name", "wave_action",
	"glitch_stt", "glitch_name", "glitch_action",
	"orbit_stt", "orbit_name", "orbit_action",
	"blade_stt", "blade_name", "blade_action",
	"chord_stt", "chord_name", "chord_action",
]
const ARMORY_LAYOUT_EDITOR_ENABLED := true
const PAUSE_LAYOUT_EDITOR_ENABLED := true
const HUD_TITLE_FONT_SIZE := 20
const HUD_TITLE_HORIZONTAL_PADDING := 16.0
const HUD_TITLE_VERTICAL_SIZE := 34.0
const RESONANCE_BAR_SIZE := Vector2(72.0, 5.0)
const RESONANCE_BAR_GAP := 4.0
const PAUSE_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const PAUSE_LAYOUT_ITEM_IDS := ["title", "continue", "settings", "menu"]
const PAUSE_ACTION_ORIGIN := Vector2(405.0, 232.0)
const PAUSE_ACTION_SIZE := Vector2(470.0, 76.0)
const PAUSE_ACTION_GAP := 20.0
const PAUSE_TITLE_RECT := Rect2(405.0, 156.0, 470.0, 62.0)
const PAUSE_TITLE_FONT_SIZE := 31
const PAUSE_GLYPH_FONT_SIZE := 46
const REWARD_TITLE_RECT := Rect2(364.0, 52.0, 552.0, 44.0)
const REWARD_CARD_ORIGIN := Vector2(123.0, 157.0)
const REWARD_CARD_SIZE := Vector2(330.0, 384.0)
const REWARD_CARD_GAP := 30.0
const REWARD_CARD_ACTION_RECT := Rect2(45.0, 305.0, 240.0, 60.0)
const REWARD_REPAIR_RECT := Rect2(456.0, 584.0, 368.0, 62.0)
const REWARD_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const REWARD_LAYOUT_ITEM_IDS := [
	"title",
	"card_01", "card_01_title", "card_01_description",
	"card_02", "card_02_title", "card_02_description",
	"card_03", "card_03_title", "card_03_description",
	"repair",
]
const SUPPORT_TITLE_RECT := REWARD_TITLE_RECT
const SUPPORT_STATUS_RECT := Rect2(190.0, 104.0, 900.0, 29.0)
const SUPPORT_CARD_ICON_RECT := Rect2(115.0, 20.0, 100.0, 82.0)
const SUPPORT_CARD_TITLE_RECT := Rect2(24.0, 112.0, 282.0, 60.0)
const SUPPORT_CARD_DESCRIPTION_RECT := Rect2(24.0, 178.0, 282.0, 112.0)
const SUPPORT_CARD_ACTION_RECT := REWARD_CARD_ACTION_RECT
const SUPPORT_BACK_RECT := REWARD_REPAIR_RECT
const SUPPORT_LAYOUT_VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const SUPPORT_LAYOUT_ITEM_IDS := [
	"title", "status",
	"card_01", "card_01_icon", "card_01_title", "card_01_description",
	"card_02", "card_02_icon", "card_02_title", "card_02_description",
	"card_03", "card_03_icon", "card_03_title", "card_03_description",
	"back",
]

func setup(owner_game) -> void:
	game = owner_game
	_load_settings_layout_positions()
	_load_hud_layout()
	_load_armory_layout()
	_load_pause_layout()
	_load_reward_layout()
	_load_support_layout()
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


func round_gameplay_button(parent: Node, text: String, rect: Rect2, action: Callable, accent: Color) -> Button:
	var node := gameplay_button(parent, text, rect, action, false, accent)
	var radius := int(minf(rect.size.x, rect.size.y) * 0.5)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var fill := Color("05030a") if state == "normal" or state == "focus" else Color("0b0714") if state == "hover" else Color("140b20")
		var style := led_style(fill, accent, 2)
		style.set_corner_radius_all(radius)
		node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("font_color", accent)
	node.add_theme_color_override("font_hover_color", accent)
	node.add_theme_color_override("font_pressed_color", accent)
	node.add_theme_color_override("font_focus_color", accent)
	if text == "☰":
		# Draw the menu glyph instead of relying on a font symbol that can vary
		# between desktop and Android exports.
		node.text = ""
		var icon := Control.new()
		icon.position = Vector2(rect.size.x * 0.5 - 12.0, rect.size.y * 0.5 - 9.0)
		icon.size = Vector2(24.0, 18.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func():
			for y in [2.0, 9.0, 16.0]:
				icon.draw_line(Vector2(1.0, y), Vector2(23.0, y), accent, 2.0, true)
		)
		node.add_child(icon)
		icon.queue_redraw()
	node.tooltip_text = text
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
	menu_background_layers.clear()
	menu_background_base = null
	campaign_difficulty_buttons.clear()
	settings_layout_editor = null
	settings_layout_groups.clear()
	armory_layout_editor = null
	armory_layout_controls.clear()
	pause_layout_editor = null
	pause_layout_groups.clear()
	reward_layout_editor = null
	reward_layout_groups.clear()
	support_layout_editor = null
	support_layout_groups.clear()
	for child in overlay.get_children():
		if child is CanvasItem:
			child.hide()
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.remove_child(child)
		child.queue_free()
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade = ColorRect.new()
	shade.name = "Overlay_Dim"
	shade.set_meta("overlay_dim", true)
	shade.color = Color(0.025, 0.012, 0.065, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)

func hide_overlay() -> void:
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func move_overlay_to_front() -> void:
	root.move_child(overlay, -1)

func hud_layout_group(item_id: String, rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "GameplayHud_%s" % item_id.capitalize()
	group.position = hud_layout_position_for(item_id, rect.position)
	group.size = rect.size
	group.scale = hud_layout_scale_for(item_id)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.set_meta("hud_layout_item_id", item_id)
	group.set_meta("hud_layout_default_position", rect.position)
	group.set_meta("hud_layout_default_scale", Vector2.ONE)
	hud.add_child(group)
	hud_layout_groups[item_id] = group
	return group


func hud_title_text() -> String:
	if game == null:
		return ""
	if game.is_assignment_demo():
		return "SANDBOX · KIỂM TRA CƠ CHẾ"
	if not game.content is Dictionary:
		return ""
	var stages: Variant = game.content.get("stages", [])
	if not stages is Array or stages.is_empty():
		return ""
	var stage_index := clampi(game.stage_index, 0, stages.size() - 1)
	var stage: Variant = stages[stage_index]
	return str(stage.get("name", "")) if stage is Dictionary else ""


func hud_title_color() -> Color:
	if game == null or game.is_assignment_demo() or not game.content is Dictionary:
		return CYAN
	var stages: Variant = game.content.get("stages", [])
	if not stages is Array or stages.is_empty():
		return CYAN
	var stage_index := clampi(game.stage_index, 0, stages.size() - 1)
	var stage: Variant = stages[stage_index]
	return Color(str(stage.get("color", CYAN))) if stage is Dictionary else CYAN


func apply_hud_title_theme() -> void:
	if title_label == null:
		return
	var title_color := hud_title_color()
	title_label.add_theme_color_override("font_color", title_color)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	title_label.add_theme_constant_override("outline_size", 0)
	title_label.add_theme_constant_override("shadow_outline_size", 0)
	title_label.add_theme_constant_override("shadow_offset_x", 0)
	title_label.add_theme_constant_override("shadow_offset_y", 0)


func fit_hud_title_to_content() -> void:
	var title_group: Control = hud_layout_groups.get("title")
	if title_group == null or title_label == null or bold == null:
		return
	apply_hud_title_theme()
	var text_metrics: Vector2 = bold.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, HUD_TITLE_FONT_SIZE)
	var content_size := Vector2(maxf(1.0, ceil(text_metrics.x) + HUD_TITLE_HORIZONTAL_PADDING), HUD_TITLE_VERTICAL_SIZE)
	var title_scale := title_group.scale
	if not hud_title_anchor_valid:
		if hud_layout_positions.has("title"):
			# Saved HUD layouts store the group's top-left corner. Convert that
			# legacy position to a visual center using the first title we render;
			# subsequent map names keep this center even when their widths differ.
			hud_title_anchor = title_group.position + Vector2(content_size.x * title_scale.x * 0.5, content_size.y * title_scale.y * 0.5)
		else:
			hud_title_anchor = Vector2(HUD_LAYOUT_VIEWPORT_SIZE.x * 0.5, 28.0 + HUD_TITLE_VERTICAL_SIZE * title_scale.y * 0.5)
		hud_title_anchor_valid = true
	hud_title_default_position = Vector2((HUD_LAYOUT_VIEWPORT_SIZE.x - content_size.x) * 0.5, 28.0)
	title_group.size = content_size
	title_group.set_meta("hud_layout_default_position", hud_title_default_position)
	# Map names are measured as a single line. Keeping wrapping off prevents a
	# name that is close to the measured width from changing the Label height and
	# pushing its glyphs out of the vertically centered title box.
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.position = Vector2.ZERO
	title_label.size = content_size
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var anchored_position := hud_title_anchor - Vector2(content_size.x * title_scale.x * 0.5, content_size.y * title_scale.y * 0.5)
	title_group.position = Vector2(
		clampf(anchored_position.x, 0.0, maxf(0.0, HUD_LAYOUT_VIEWPORT_SIZE.x - content_size.x * title_scale.x)),
		clampf(anchored_position.y, 0.0, maxf(0.0, HUD_LAYOUT_VIEWPORT_SIZE.y - content_size.y * title_scale.y)))


func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	# A transparent PNG owns the decorative HUD chassis. Every changing value,
	# fill and hitbox below remains a real Godot control over this image layer.
	hud_art = background_texture(hud, GAMEPLAY_HUD_BACKGROUND, TextureRect.STRETCH_SCALE)
	hud_art.name = "GameplayHudDecor"
	# Each resource rail is its own layout group. The values stay live Godot
	# ProgressBars while F8 can move and resize HP, Shield and Mana separately.
	health_label = null
	var hp_group := hud_layout_group("hp", Rect2(84, 44, 194, 11))
	create_bar("hp", Rect2(0, 0, 194, 11), CORAL, hp_group)
	var shield_group := hud_layout_group("shield", Rect2(84, 62, 194, 11))
	create_bar("shield", Rect2(0, 0, 194, 11), CYAN, shield_group)
	var energy_group := hud_layout_group("energy", Rect2(84, 80, 194, 10))
	create_bar("energy", Rect2(0, 0, 194, 10), Color("3478ff"), energy_group)
	
	# Coin Display on HUD
	var coin_container := Panel.new()
	coin_container.name = "GameplayHud_CoinContainer"
	coin_container.position = Vector2(84, 96)
	coin_container.size = Vector2(194, 22)
	var coin_box_style := StyleBoxFlat.new()
	coin_box_style.bg_color = Color(0.04, 0.03, 0.01, 0.6)
	coin_box_style.border_color = Color("ffd700")
	coin_box_style.set_border_width_all(1)
	coin_box_style.set_corner_radius_all(4)
	coin_container.add_theme_stylebox_override("panel", coin_box_style)
	coin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(coin_container)
	
	coin_label = plain_label(coin_container, "🪙 0 COIN", Rect2(6, 1, 182, 20), 14, Color("ffd700"), true)
	coin_label.name = "GameplayHud_CoinLabel"
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Quick Shop Button on HUD (Mobile Touch Friendly)
	shop_button = gameplay_button(hud, "🛒 CỬA HÀNG", Rect2(1048, 16, 118, 66), game.open_cyber_shop, false, Color("ffd700"))
	shop_button.name = "Gameplay_ShopButton"
	shop_button.add_theme_font_override("font", bold)
	shop_button.add_theme_font_size_override("font_size", 14)
	# Pulse is drawn by TouchControls. The live gauge starts at the authored
	# default position and is re-anchored to the saved Pulse transform once the
	# touch targets have been created.
	create_bar("resonance", Rect2(1149, 713, RESONANCE_BAR_SIZE.x, RESONANCE_BAR_SIZE.y), CYAN)
	var title_group := hud_layout_group("title", Rect2(0, 0, 1, 1))
	title_label = plain_label(title_group, hud_title_text(), Rect2(Vector2.ZERO, Vector2.ONE), HUD_TITLE_FONT_SIZE, WHITE, true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	room_label = plain_label(title_group, "", Rect2(Vector2.ZERO, Vector2.ZERO), 14, MUTED)
	room_label.visible = false
	fit_hud_title_to_content()
	var weapon_group := hud_layout_group("weapon", Rect2(838, 11, 190, 86))
	# Keep the slot itself as a real control so the player can see the currently
	# equipped model inside a stable, transparent HUD frame. The model remains
	# dynamic; only this container is decorative.
	current_weapon_box = Panel.new()
	current_weapon_box.name = "CurrentWeaponGameplaySlot"
	current_weapon_box.position = Vector2(8, 6)
	current_weapon_box.size = Vector2(174, 74)
	var weapon_slot_style := StyleBoxFlat.new()
	weapon_slot_style.bg_color = Color(0.02, 0.03, 0.09, 0.48)
	weapon_slot_style.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.9)
	weapon_slot_style.set_border_width_all(1)
	weapon_slot_style.set_corner_radius_all(8)
	weapon_slot_style.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.28)
	weapon_slot_style.shadow_size = 4
	weapon_slot_style.shadow_offset = Vector2.ZERO
	current_weapon_box.add_theme_stylebox_override("panel", weapon_slot_style)
	current_weapon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_group.add_child(current_weapon_box)
	var initial_weapon_model := gameplay_weapon_model_path(hud_weapon_definition(game.active_slot))
	current_weapon_preview = texture(weapon_group, initial_weapon_model, Rect2(55, 14, 80, 58))
	current_weapon_preview.name = "CurrentWeaponGameplayModel"
	current_weapon_preview.set_meta("hud_model_path", initial_weapon_model)
	current_weapon_button = Button.new()
	current_weapon_button.name = "Gameplay_WeaponSlotButton"
	current_weapon_button.position = Vector2.ZERO
	current_weapon_button.size = weapon_group.size
	current_weapon_button.tooltip_text = "Vũ khí đang trang bị"
	current_weapon_button.focus_mode = Control.FOCUS_NONE
	current_weapon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	current_weapon_button.flat = true
	current_weapon_button.mouse_filter = Control.MOUSE_FILTER_STOP
	var weapon_slot_hitbox_style := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		current_weapon_button.add_theme_stylebox_override(state, weapon_slot_hitbox_style)
	current_weapon_button.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	current_weapon_button.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	current_weapon_button.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	current_weapon_button.pressed.connect(game.swap_weapon)
	current_weapon_button.set_meta("hud_weapon_slot_action", "swap")
	weapon_group.add_child(current_weapon_button)
	weapon_label = null
	secondary_weapon_label = null
	secondary_weapon_preview = null
	# The gameplay HUD keeps only one circular action in the upper-right corner:
	# a larger pause button aligned with the decorative ring in the HUD artwork.
	menu_button = null
	var pause_group := hud_layout_group("pause", Rect2(1180, 6, 86, 86))
	pause_button = round_gameplay_button(pause_group, "Ⅱ", Rect2(0, 0, 86, 86), game.pause_game, CYAN)
	pause_button.name = "Gameplay_PauseButton"
	pause_button.add_theme_font_override("font", bold)
	pause_button.add_theme_font_size_override("font_size", PAUSE_GLYPH_FONT_SIZE)
	map_button = null
	minimap = null
	# These two switches are temporary controls for the assignment sandbox only;
	# they are not part of the five-area gameplay HUD.
	sound_toggle_button = gameplay_button(hud, "", sandbox_control_rect(0, 0), game.toggle_short_effects, false, CYAN)
	music_toggle_button = gameplay_button(hud, "", sandbox_control_rect(0, 1), game.toggle_background_music, false, LED_PURPLE)
	build_assignment_demo_controls()
	# Gameplay no longer reserves a status line or tutorial footer; the map and
	# controls stay readable without dynamic copy covering the playfield.
	status_label = null
	hint_label = null
	var boss_group := hud_layout_group("boss", Rect2(384, 130, 512, 39))
	boss_label = plain_label(boss_group, "", Rect2(0, 16, 512, 23), 16, CORAL, true)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_bar("boss", Rect2(6, 4, 500, 6), CORAL, boss_group)
	tutorial_panel = Panel.new()
	tutorial_panel.name = "Campaign_TutorialPanel"
	tutorial_panel.position = Vector2(306, 611)
	tutorial_panel.size = Vector2(668, 76)
	tutorial_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tutorial_style := panel_style(Color(0.015, 0.025, 0.07, 0.94), CYAN, 1)
	tutorial_style.shadow_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.28)
	tutorial_style.shadow_size = 8
	tutorial_panel.add_theme_stylebox_override("panel", tutorial_style)
	hud.add_child(tutorial_panel)
	tutorial_label = plain_label(tutorial_panel, "", Rect2(18, 9, 548, 58), 15, WHITE)
	tutorial_label.name = "Campaign_TutorialText"
	tutorial_skip_button = button(tutorial_panel, "BỎ QUA", Rect2(566, 17, 88, 42), func(): skip_campaign_tutorial(), false, MUTED)
	tutorial_skip_button.name = "Campaign_TutorialSkipButton"
	tutorial_skip_button.add_theme_font_size_override("font_size", 11)
	tutorial_panel.visible = false
	# The rhythm clock remains active for combat logic; only its decorative HUD
	# marker is removed from this screen.
	beat_display = null
	sound_toggle_button.visible = false
	music_toggle_button.visible = false
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

func create_bar(id: String, rect: Rect2, color: Color, parent: Node = null) -> void:
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
	var target_parent: Node = hud if parent == null else parent
	target_parent.add_child(progress)
	# Reset after theme minimum-size invalidation; pre-theme sizing retains default height.
	progress.set_deferred("size", rect.size)
	bars[id] = progress


func hud_layout_position_for(item_id: String, default_position: Vector2) -> Vector2:
	var stored: Variant = hud_layout_positions.get(item_id, default_position)
	if not stored is Vector2:
		return default_position
	return Vector2(clampf(stored.x, 0.0, HUD_LAYOUT_VIEWPORT_SIZE.x), clampf(stored.y, 0.0, HUD_LAYOUT_VIEWPORT_SIZE.y))


func hud_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = hud_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, 0.55, 2.0), clampf(stored.y, 0.55, 2.0))


func _load_hud_layout() -> void:
	hud_layout_positions.clear()
	hud_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("hud_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in HUD_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		hud_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		hud_layout_scales[item_id] = Vector2(float(encoded[2]), float(encoded[3]))
		# A previous HUD version stored the pause circle at the old 52x52
		# position. Treat only that authored default as legacy; preserve any
		# position/scale the player deliberately saved in the F8 editor.
		if item_id == "pause" and is_equal_approx(float(encoded[0]), 1092.0) and is_equal_approx(float(encoded[1]), 28.0) and is_equal_approx(float(encoded[2]), 1.0) and is_equal_approx(float(encoded[3]), 1.0):
			hud_layout_positions.erase(item_id)
			hud_layout_scales.erase(item_id)


func armory_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = armory_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, 0.55, 2.0), clampf(stored.y, 0.55, 2.0))


func armory_layout_position_for(item_id: String, default_rect: Rect2) -> Vector2:
	var stored: Variant = armory_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var visual_size := default_rect.size * armory_layout_scale_for(item_id)
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, ARMORY_LAYOUT_VIEWPORT_SIZE.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, ARMORY_LAYOUT_VIEWPORT_SIZE.y - visual_size.y)))


func armory_layout_apply_control(item_id: String, control: Control, default_rect: Rect2) -> Control:
	control.position = armory_layout_position_for(item_id, default_rect)
	control.size = default_rect.size
	control.scale = armory_layout_scale_for(item_id)
	control.set_meta("armory_layout_item_id", item_id)
	control.set_meta("armory_layout_default_position", default_rect.position)
	control.set_meta("armory_layout_default_scale", Vector2.ONE)
	armory_layout_controls[item_id] = control
	return control


func _load_armory_layout() -> void:
	armory_layout_positions.clear()
	armory_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("armory_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in ARMORY_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		armory_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		armory_layout_scales[item_id] = Vector2(float(encoded[2]), float(encoded[3]))


func pause_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = pause_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, 0.55, 2.0), clampf(stored.y, 0.55, 2.0))


func pause_layout_position_for(item_id: String, default_rect: Rect2) -> Vector2:
	var stored: Variant = pause_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var visual_size := default_rect.size * pause_layout_scale_for(item_id)
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, PAUSE_LAYOUT_VIEWPORT_SIZE.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, PAUSE_LAYOUT_VIEWPORT_SIZE.y - visual_size.y)))


func pause_layout_apply_control(item_id: String, control: Control, default_rect: Rect2) -> Control:
	control.position = pause_layout_position_for(item_id, default_rect)
	control.size = default_rect.size
	control.scale = pause_layout_scale_for(item_id)
	control.set_meta("pause_layout_item_id", item_id)
	control.set_meta("pause_layout_default_position", default_rect.position)
	control.set_meta("pause_layout_default_scale", Vector2.ONE)
	pause_layout_groups[item_id] = control
	return control


func _load_pause_layout() -> void:
	pause_layout_positions.clear()
	pause_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("pause_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in PAUSE_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		pause_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		pause_layout_scales[item_id] = Vector2(float(encoded[2]), float(encoded[3]))


func _serialized_pause_layout() -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in PAUSE_LAYOUT_ITEM_IDS:
		var group: Control = pause_layout_groups.get(item_id)
		if group == null or not is_instance_valid(group):
			continue
		output[item_id] = [group.position.x, group.position.y, group.scale.x, group.scale.y]
	return output


func _sync_pause_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["pause_layout"] = _serialized_pause_layout()


func save_pause_layout() -> bool:
	_sync_pause_layout_to_runtime_settings()
	return game != null and game.persist_profile()


func _serialized_armory_layout() -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in ARMORY_LAYOUT_ITEM_IDS:
		var control: Control = armory_layout_controls.get(item_id)
		if control == null or not is_instance_valid(control):
			continue
		output[item_id] = [control.position.x, control.position.y, control.scale.x, control.scale.y]
	return output


func _sync_armory_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["armory_layout"] = _serialized_armory_layout()


func save_armory_layout() -> bool:
	_sync_armory_layout_to_runtime_settings()
	return game != null and game.persist_profile()


func _serialized_hud_layout() -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in HUD_LAYOUT_ITEM_IDS:
		var group: Control = hud_layout_groups.get(item_id)
		if group == null or not is_instance_valid(group):
			continue
		output[item_id] = [group.position.x, group.position.y, group.scale.x, group.scale.y]
	return output


func _sync_hud_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["hud_layout"] = _serialized_hud_layout()


func save_hud_layout() -> bool:
	_sync_hud_layout_to_runtime_settings()
	if game != null and game.controls != null:
		game.controls.sync_touch_layout()
	return game != null and game.persist_profile()


func hud_weapon_definition(slot: int) -> Dictionary:
	if game == null or game.weapon_system == null or game.weapons.is_empty():
		return {}
	var safe_slot := clampi(slot, 0, game.weapons.size() - 1)
	return game.weapon_system.definition(game.weapons[safe_slot])


func refresh_hud_weapon_preview(preview: TextureRect, weapon: Dictionary) -> void:
	if preview == null or weapon.is_empty():
		return
	var model_path := gameplay_weapon_model_path(weapon)
	if model_path.is_empty() or str(preview.get_meta("hud_model_path", "")) == model_path:
		return
	var model_resource: Resource = load(model_path)
	if model_resource is Texture2D:
		preview.texture = model_resource
		preview.set_meta("hud_model_path", model_path)


func sync_resonance_bar_layout() -> void:
	var resonance_bar: ProgressBar = bars.get("resonance")
	if resonance_bar == null or game == null or game.controls == null:
		return
	var pulse_target: Control = game.controls.touch_layout_target("pulse")
	if pulse_target == null or not is_instance_valid(pulse_target):
		return
	var pulse_rect := Rect2(pulse_target.position, pulse_target.size * pulse_target.scale)
	var pulse_center := pulse_rect.get_center()
	var touch_scale := clampf(float(game.settings.get("touch_scale", 1.0)), 0.1, 4.0)
	var pulse_visual_radius := minf(pulse_rect.size.x, pulse_rect.size.y) * 0.5 * touch_scale
	var desired_position := Vector2(
		pulse_center.x - RESONANCE_BAR_SIZE.x * 0.5,
		pulse_center.y + pulse_visual_radius + RESONANCE_BAR_GAP)
	var maximum_position := HUD_LAYOUT_VIEWPORT_SIZE - RESONANCE_BAR_SIZE
	resonance_bar.position = Vector2(
		clampf(desired_position.x, 0.0, maximum_position.x),
		clampf(desired_position.y, 0.0, maximum_position.y))
	resonance_bar.size = RESONANCE_BAR_SIZE


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

func _process(_delta: float) -> void:
	if game == null:
		return
	if game.state == "menu":
		_animate_menu_background(_delta)
	hud.visible = game.state not in ["menu", "game_over", "victory", "unlocks", "area_transition"]
	if hud_layout_editor != null and game.state != "playing" and hud_layout_editor.is_editor_active():
		hud_layout_editor.set_editor_active(false)
	if pause_layout_editor != null and is_instance_valid(pause_layout_editor) and game.state != "paused" and pause_layout_editor.is_editor_active():
		pause_layout_editor.set_editor_active(false)
	if not hud.visible:
		return
	sync_campaign_tutorial()
	refresh_runtime_audio_controls()
	var demo_visible: bool = game.is_assignment_demo() and game.state == "playing"
	for control in demo_controls:
		control.visible = demo_visible
	if sound_toggle_button != null:
		sound_toggle_button.visible = demo_visible
	if music_toggle_button != null:
		music_toggle_button.visible = demo_visible
	var player = game.player
	bars.hp.max_value = player.max_hp
	bars.hp.value = player.hp
	bars.shield.max_value = player.max_shield
	bars.shield.value = player.shield
	bars.energy.max_value = player.max_energy
	bars.energy.value = player.energy
	if coin_label != null and is_instance_valid(coin_label):
		coin_label.text = "🪙 %d COIN" % game.coins
	if shop_button != null and is_instance_valid(shop_button):
		shop_button.visible = not demo_visible
	sync_resonance_bar_layout()
	bars.resonance.max_value = 100.0
	bars.resonance.value = player.resonance
	var next_hud_title := hud_title_text()
	if _last_hud_title_text != next_hud_title:
		_last_hud_title_text = next_hud_title
		title_label.text = next_hud_title
		fit_hud_title_to_content()
	room_label.text = ""
	var current_weapon: Dictionary = hud_weapon_definition(game.active_slot)
	refresh_hud_weapon_preview(current_weapon_preview, current_weapon)
	var boss: Vector2 = game.enemies.boss_health()
	bars.boss.visible = boss.y > 0
	boss_label.visible = boss.y > 0
	if boss.y > 0:
		bars.boss.max_value = boss.y
		bars.boss.value = boss.x
		boss_label.text = game.content.stages[game.stage_index].boss

func show_menu() -> void:
	clear_overlay()
	# Keep the lobby art separate from its interactive controls.
	_add_menu_background_layers()
	var veil = ColorRect.new()
	veil.color = Color(0.008, 0.004, 0.035, 0.4)
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
	var new_run_action: Callable = confirm_new_run if has_checkpoint else show_campaign_intro
	var new_run = menu_image_action("new_run", "LƯỢT MỚI", 1, new_run_action, LED_PURPLE)
	menu_image_action("armory", "TRANG BỊ", 2, show_unlocks, CYAN)
	menu_image_action("debug", "KHU VỰC DEBUG", 3, show_debug_zones, LED_PURPLE)
	menu_image_action("settings", "CÀI ĐẶT", 4, func(): show_settings("menu"), CYAN)
	if has_checkpoint:
		continue_action.grab_focus()
	else:
		new_run.grab_focus()

func menu_action_rect(index: int) -> Rect2:
	return Rect2(MENU_ACTION_ORIGIN + Vector2(0.0, index * (MENU_ACTION_SIZE.y + MENU_ACTION_GAP)), MENU_ACTION_SIZE)

func show_campaign_intro() -> void:
	clear_overlay()
	_add_menu_background_layers()
	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.004, 0.035, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	panel(overlay, Rect2(112, 164, 1056, 440), Color(0.015, 0.022, 0.065, 0.94), CYAN)
	var chapter := plain_label(overlay, "HỒI I · TÍN HIỆU ĐẦU TIÊN", Rect2(160, 192, 960, 22), 14, LED_PURPLE, true)
	chapter.name = "Campaign_ChapterLabel"
	var heading := led_label(overlay, "NOCTIS ĐÃ IM LẶNG", Rect2(160, 222, 960, 45), 32, CYAN, true)
	heading.name = "Campaign_StoryTitle"
	var story := plain_label(overlay, "NOCTIS từng giữ năm vùng cộng hưởng trong cùng một nhịp. THE SILENCE đã cắt đường truyền, biến các trạm thành ổ phát tín hiệu địch. Phi công, vũ khí còn lại và drone đồng hành là hy vọng cuối cùng để khôi phục mạng lưới.", Rect2(160, 278, 960, 84), 18, WHITE)
	story.name = "Campaign_StoryBody"
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var objective := plain_label(overlay, "NHIỆM VỤ · Thu hồi năm lớp nhạc, đánh bại kẻ giữ vùng và đánh thức lõi SILENT CORE.", Rect2(160, 374, 960, 27), 16, Color("ffd166"), true)
	objective.name = "Campaign_Objective"
	var route_names := PackedStringArray()
	for stage: Dictionary in game.content.stages:
		route_names.append(str(stage.get("name", "UNKNOWN")))
	var route := plain_label(overlay, "ĐƯỜNG TRUYỀN   " + "  →  ".join(route_names), Rect2(160, 410, 960, 34), 14, CYAN, true)
	route.name = "Campaign_Route"
	var controls := plain_label(overlay, "DI CHUYỂN  WASD / CẦN TRÁI · BẮN  CHUỘT / NÚT BẮN · DASH  SPACE / NÚT DASH\nE  TƯƠNG TÁC · TAB  ĐỔI VŨ KHÍ · B  MỞ CỬA HÀNG KHI AN TOÀN", Rect2(160, 432, 960, 42), 13, MUTED)
	controls.name = "Campaign_ControlsGuide"
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var difficulty_title := plain_label(overlay, "ĐỘ KHÓ", Rect2(160, 482, 100, 26), 14, WHITE, true)
	difficulty_title.name = "Campaign_DifficultyLabel"
	var difficulty_options: Array[Dictionary] = [
		{"id": "easy", "text": "DỄ", "rect": Rect2(270, 478, 150, 38), "accent": CYAN},
		{"id": "normal", "text": "THƯỜNG", "rect": Rect2(430, 478, 150, 38), "accent": LED_PURPLE},
		{"id": "hard", "text": "KHÓ", "rect": Rect2(590, 478, 150, 38), "accent": CORAL},
	]
	for option: Dictionary in difficulty_options:
		var mode: String = str(option.id)
		var is_selected: bool = game.difficulty_mode == mode
		var accent: Color = option.accent if is_selected else MUTED
		var select_action := Callable(self, "select_campaign_difficulty").bind(mode)
		var option_button := button(overlay, str(option.text), option.rect, select_action, is_selected, accent)
		option_button.name = "Campaign_Difficulty_%s" % mode.capitalize()
		option_button.add_theme_font_size_override("font_size", 13)
		campaign_difficulty_buttons[mode] = option_button
	var difficulty_hint := plain_label(overlay, "Dễ thở hơn · Thường cân bằng · Khó: địch nhiều máu, đau hơn, nhanh và tấn công dồn dập", Rect2(160, 518, 960, 19), 12, MUTED)
	difficulty_hint.name = "Campaign_DifficultyHint"
	var start_button := button(overlay, "BẮT ĐẦU CHIẾN DỊCH", Rect2(370, 544, 300, 48), game.new_run, true, CYAN)
	start_button.name = "Campaign_StartButton"
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.grab_focus()
	var skip_button := button(overlay, "BỎ QUA", Rect2(698, 544, 190, 48), game.new_run, false, MUTED)
	skip_button.name = "Campaign_SkipButton"
	skip_button.add_theme_font_size_override("font_size", 15)

func select_campaign_difficulty(mode: String) -> void:
	if not ["easy", "normal", "hard"].has(mode):
		return
	game.difficulty_mode = mode
	game.settings["difficulty"] = mode
	show_campaign_intro()

func show_boss_briefing(stage_index: int) -> void:
	clear_overlay()
	var stage: Dictionary = game.content.stages[stage_index]
	var veil := ColorRect.new()
	veil.color = Color(0.004, 0.008, 0.025, 0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	panel(overlay, Rect2(150, 128, 980, 464), Color(0.02, 0.025, 0.075, 0.97), Color("ff846f"))
	var kicker := plain_label(overlay, "CẢNH BÁO · TÍN HIỆU BOSS", Rect2(200, 158, 880, 24), 15, Color("ff846f"), true)
	kicker.name = "BossBriefingKicker"
	var name := led_label(overlay, str(stage.get("boss", "UNKNOWN")), Rect2(200, 190, 880, 50), 34, Color("ff846f"), true)
	name.name = "BossBriefingName"
	var stage_name := plain_label(overlay, "%s · %s" % [str(stage.get("name", "")), str(stage.get("subtitle", ""))], Rect2(200, 244, 880, 24), 15, CYAN, true)
	stage_name.name = "BossBriefingStage"
	var warning := plain_label(overlay, "KỸ NĂNG\n%s" % str(stage.get("boss_warning", "Đòn đánh có vệt báo trước; quan sát và né khỏi vùng nguy hiểm.")), Rect2(200, 294, 880, 76), 18, WHITE, true)
	warning.name = "BossBriefingWarning"
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var counter := plain_label(overlay, "CÁCH ĐỐI PHÓ\n%s" % str(stage.get("boss_counter", "Giữ di chuyển và dash khỏi vệt báo trước.")), Rect2(200, 386, 880, 76), 17, MUTED)
	counter.name = "BossBriefingCounter"
	counter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm := button(overlay, "ĐÃ RÕ · VÀO ĐẤU", Rect2(430, 500, 420, 58), game.confirm_boss_briefing, true, Color("ff846f"))
	confirm.name = "BossBriefing_ConfirmButton"
	confirm.add_theme_font_size_override("font_size", 17)
	confirm.grab_focus()

func show_area_transition(previous_stage_index: int, next_stage_index: int) -> void:
	clear_overlay()
	var previous_stage: Dictionary = game.content.stages[previous_stage_index]
	var next_stage: Dictionary = game.content.stages[next_stage_index]
	background_texture(overlay, REWARD_BACKGROUND, TextureRect.STRETCH_SCALE)
	var veil := ColorRect.new()
	veil.color = Color(0.008, 0.012, 0.04, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	panel(overlay, Rect2(132, 152, 1016, 424), Color(0.015, 0.022, 0.065, 0.96), CYAN)
	var recovered := plain_label(overlay, "%s · LỚP NHẠC %d / 5 ĐÃ ĐƯỢC KHÔI PHỤC" % [str(previous_stage.get("name", "")), previous_stage_index + 1], Rect2(184, 187, 912, 26), 15, Color("ffd166"), true)
	recovered.name = "AreaTransition_Progress"
	var destination := led_label(overlay, "%s · %s" % [str(next_stage.get("name", "")), str(next_stage.get("subtitle", ""))], Rect2(184, 226, 912, 48), 29, CYAN, true)
	destination.name = "AreaTransition_Title"
	var story := plain_label(overlay, str(next_stage.get("transition_story", next_stage.get("description", "Tín hiệu kế tiếp đang chờ."))), Rect2(184, 300, 912, 76), 19, WHITE)
	story.name = "AreaTransition_Story"
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var objective := plain_label(overlay, "MỤC TIÊU TIẾP THEO · %s" % str(next_stage.get("description", "")), Rect2(184, 396, 912, 70), 16, MUTED)
	objective.name = "AreaTransition_Objective"
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var continue_button := button(overlay, "ĐI TỚI KHU VỰC TIẾP THEO", Rect2(390, 492, 500, 58), game.confirm_area_transition, true, CYAN)
	continue_button.name = "AreaTransition_ContinueButton"
	continue_button.add_theme_font_size_override("font_size", 17)
	continue_button.grab_focus()

func sync_campaign_tutorial() -> void:
	if tutorial_panel == null or not is_instance_valid(tutorial_panel):
		return
	var tutorial_active: bool = game.state == "playing" and not game.debug_session and game.stage_index == 0 and game.room_index == 0 and game.tutorial_step < 4
	tutorial_panel.visible = tutorial_active
	if not tutorial_active or tutorial_displayed_step == game.tutorial_step:
		return
	var prompts: Array[String] = [
		"HƯỚNG DẪN 1/4 · DI CHUYỂN\nWASD hoặc cần trái: rời điểm rơi và dò tín hiệu gần nhất.",
		"HƯỚNG DẪN 2/4 · TẤN CÔNG\nChuột trái hoặc nút BẮN: hạ tín hiệu địch để mở đường.",
		"HƯỚNG DẪN 3/4 · DASH\nSPACE hoặc nút DASH: lướt né đòn. Canh nhịp để đạt Perfect Dash.",
		"HƯỚNG DẪN 4/4 · TIẾN TRÌNH\nDọn sạch địch, đi qua cổng; nhấn E tại cổng hoặc trạm để tương tác.",
	]
	tutorial_displayed_step = game.tutorial_step
	tutorial_label.text = prompts[game.tutorial_step]

func skip_campaign_tutorial() -> void:
	game.tutorial_step = 4
	game.tutorial_timer = 0.0
	tutorial_panel.visible = false

func _add_menu_background_layers() -> void:
	menu_background_time = 0.0
	menu_background_layers.clear()
	var viewport_size := get_viewport().get_visible_rect().size
	menu_background_base = background_texture(overlay, MENU_BACKGROUND_BASE, TextureRect.STRETCH_SCALE)
	menu_background_base.name = "MenuBackgroundBase"
	for layer_info: Dictionary in MENU_BACKGROUND_LAYERS:
		var layer_texture := load(str(layer_info.path)) as Texture2D
		var copies: Array[Sprite2D] = []
		for copy_index in range(2):
			var sprite := Sprite2D.new()
			sprite.name = "MenuBackgroundLayer_%d_Copy_%d" % [menu_background_layers.size(), copy_index]
			sprite.texture = layer_texture
			sprite.flip_h = copy_index == 1
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.centered = true
			overlay.add_child(sprite)
			copies.append(sprite)
		menu_background_layers.append({"sprites": copies, "speed": float(layer_info.speed)})
	_layout_menu_background_layers()

func _animate_menu_background(delta: float) -> void:
	if menu_background_base == null or menu_background_layers.is_empty():
		return
	menu_background_time += delta
	_layout_menu_background_layers()

func _layout_menu_background_layers() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var tile_width: float = viewport_size.x
	var loop_width: float = tile_width * 2.0
	for layer_info: Dictionary in menu_background_layers:
		var copies: Array = layer_info.sprites
		var texture: Texture2D = copies[0].texture
		var scale_to_viewport := Vector2(viewport_size.x / texture.get_width(), viewport_size.y / texture.get_height())
		var travel: float = fposmod(menu_background_time * float(layer_info.speed) * 2.0, loop_width)
		var first_x: float = fposmod(tile_width - travel, loop_width) - tile_width * 0.5
		var second_x: float = fposmod(tile_width * 2.0 - travel, loop_width) - tile_width * 0.5
		if second_x <= -tile_width * 0.5:
			second_x += loop_width
		for copy_index in range(copies.size()):
			var sprite: Sprite2D = copies[copy_index]
			sprite.scale = scale_to_viewport
			sprite.position = Vector2(first_x if copy_index == 0 else second_x, viewport_size.y * 0.5)

func menu_image_action(action_id: String, title_text: String, index: int, action: Callable, accent: Color, disabled: bool = false) -> Button:
	var rect := menu_action_rect(index)
	var target := button(overlay, title_text, rect, action, false, accent)
	target.name = "Menu_%s_Hitbox" % action_id
	target.tooltip_text = title_text
	target.add_theme_font_override("font", bold)
	target.add_theme_font_size_override("font_size", 23)
	target.add_theme_color_override("font_disabled_color", Color("69778c"))
	target.focus_mode = Control.FOCUS_ALL
	target.disabled = disabled
	target.set_meta("menu_action_id", action_id)
	target.set_meta("menu_art_rect", rect)
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
	button(overlay, "Bắt đầu lượt mới", Rect2(632, 426, 270, 52), show_campaign_intro, true)

func modal_header(title: String, subtitle: String = "") -> void:
	clear_overlay()
	label(overlay, title, Rect2(90, 66, 1100, 65), 38, WHITE, true)
	label(overlay, subtitle, Rect2(92, 138, 1090, 64), 19, MUTED)

func show_rewards(choices: Array, preview: bool = false) -> void:
	reward_layout_preview_active = preview
	clear_overlay()
	var reward_art := background_texture(overlay, REWARD_BACKGROUND, TextureRect.STRETCH_SCALE)
	reward_art.name = "Reward_UpgradeArtwork"
	reward_art.set_meta("reward_background_path", REWARD_BACKGROUND)
	var title_group := reward_layout_group("title", REWARD_TITLE_RECT)
	var title := plain_label(title_group, "NÂNG CẤP SAU PHÒNG", Rect2(Vector2.ZERO, REWARD_TITLE_RECT.size), 30, CYAN, true)
	title.name = "Reward_Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var first_choice_button: Button = null
	for index in range(3):
		var card_rect := Rect2(REWARD_CARD_ORIGIN + Vector2(index * (REWARD_CARD_SIZE.x + REWARD_CARD_GAP), 0.0), REWARD_CARD_SIZE)
		var choice: Dictionary = choices[index] if index < choices.size() else {}
		var card_button := reward_choice_card(index, choice, card_rect)
		if first_choice_button == null and card_button != null:
			first_choice_button = card_button
	var repair_button := reward_repair_button()
	show_reward_layout_editor()
	if preview and reward_layout_editor != null:
		reward_layout_editor.set_editor_active(true)
		overlay.move_child(reward_layout_editor, -1)
	elif first_choice_button != null:
		first_choice_button.grab_focus()
	else:
		repair_button.grab_focus()


func show_reward_layout_preview() -> void:
	if not reward_layout_editor_is_available() or game.state != "playing":
		return
	reward_preview_restore_state = game.state
	game.state = "reward"
	game.controls.reset()
	game.rhythm.pause_music()
	var preview_choices: Array = []
	for upgrade in game.content.upgrades:
		preview_choices.append(upgrade)
		if preview_choices.size() == 3:
			break
	show_rewards(preview_choices, true)


func close_reward_layout_preview() -> void:
	if not reward_layout_preview_active:
		return
	reward_layout_preview_active = false
	var restore_state := reward_preview_restore_state
	reward_preview_restore_state = ""
	if game == null:
		hide_overlay()
		return
	if restore_state == "playing":
		# Re-enter the regular resume lifecycle so controls, music, invulnerability,
		# and the enemy grace window are restored together after preview mode.
		game.state = "paused"
		game.resume_game()
	else:
		hide_overlay()


func reward_choice_card(index: int, choice: Dictionary, rect: Rect2) -> Button:
	var group := Control.new()
	group.name = "Reward_Card_%02d" % (index + 1)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_layout_apply_control("card_%02d" % (index + 1), group, rect)
	group.set_meta("reward_card_index", index)
	group.set_meta("reward_card_rect", rect)
	overlay.add_child(group)
	var choice_id := str(choice.get("id", ""))
	if choice_id.is_empty():
		var empty_label := plain_label(group, "KHÔNG CÓ MODULE", Rect2(24.0, 168.0, 282.0, 45.0), 18, CYAN, true)
		empty_label.name = "Reward_Card_%02d_Empty" % (index + 1)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return null
	var title_rect := Rect2(24.0, 66.0, 282.0, 78.0)
	var title_label := plain_label(group, str(choice.get("name", "")), title_rect, 23, CYAN, true)
	title_label.name = "Reward_Card_%02d_Title" % (index + 1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_layout_apply_child_control("card_%02d_title" % (index + 1), title_label, title_rect, REWARD_CARD_SIZE)
	var description_rect := Rect2(24.0, 157.0, 282.0, 132.0)
	var description_label := plain_label(group, str(choice.get("description", "")), description_rect, 16, CYAN)
	description_label.name = "Reward_Card_%02d_Description" % (index + 1)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	reward_layout_apply_child_control("card_%02d_description" % (index + 1), description_label, description_rect, REWARD_CARD_SIZE)
	var target := Button.new()
	target.name = "Reward_Card_%02d_Hitbox" % (index + 1)
	target.text = "CHỌN NÂNG CẤP"
	target.tooltip_text = "Chọn nâng cấp: %s" % str(choice.get("name", ""))
	target.position = REWARD_CARD_ACTION_RECT.position
	target.size = REWARD_CARD_ACTION_RECT.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_font_override("font", bold)
	target.add_theme_font_size_override("font_size", 14)
	target.set_meta("reward_choice_id", choice_id)
	target.set_meta("reward_card_index", index)
	target.set_meta("reward_action_rect", REWARD_CARD_ACTION_RECT)
	for state: String in ["normal", "disabled", "hover", "focus", "pressed"]:
		target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	target.add_theme_color_override("font_color", CYAN)
	target.add_theme_color_override("font_disabled_color", CYAN)
	target.add_theme_color_override("font_hover_color", CYAN)
	target.add_theme_color_override("font_pressed_color", CYAN)
	target.add_theme_color_override("font_focus_color", CYAN)
	target.disabled = reward_layout_preview_active
	target.pressed.connect(func(): game.choose_upgrade(choice_id))
	group.add_child(target)
	return target


func reward_repair_button() -> Button:
	var target := Button.new()
	target.name = "Reward_RepairButton"
	target.text = "SỬA CHỮA  +25 HP"
	target.tooltip_text = "Sửa chữa và hồi 25 HP"
	reward_layout_apply_control("repair", target, REWARD_REPAIR_RECT)
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_font_override("font", bold)
	target.add_theme_font_size_override("font_size", 16)
	target.set_meta("reward_choice_id", "repair")
	target.set_meta("reward_action_rect", REWARD_REPAIR_RECT)
	for state: String in ["normal", "disabled", "hover", "focus", "pressed"]:
		target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	target.add_theme_color_override("font_color", CYAN)
	target.add_theme_color_override("font_disabled_color", CYAN)
	target.add_theme_color_override("font_hover_color", CYAN)
	target.add_theme_color_override("font_pressed_color", CYAN)
	target.add_theme_color_override("font_focus_color", CYAN)
	target.disabled = reward_layout_preview_active
	target.pressed.connect(func(): game.choose_upgrade("repair"))
	overlay.add_child(target)
	return target


func reward_layout_group(item_id: String, default_rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "Reward_Layout_%s" % item_id
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_layout_apply_control(item_id, group, default_rect)
	overlay.add_child(group)
	return group


func reward_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = reward_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, 0.55, 2.0), clampf(stored.y, 0.55, 2.0))


func reward_layout_position_for(item_id: String, default_rect: Rect2) -> Vector2:
	var stored: Variant = reward_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var visual_size := default_rect.size * reward_layout_scale_for(item_id)
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, REWARD_LAYOUT_VIEWPORT_SIZE.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, REWARD_LAYOUT_VIEWPORT_SIZE.y - visual_size.y)))


func reward_layout_apply_control(item_id: String, control: Control, default_rect: Rect2) -> Control:
	control.position = reward_layout_position_for(item_id, default_rect)
	control.size = default_rect.size
	control.scale = reward_layout_scale_for(item_id)
	control.set_meta("reward_layout_item_id", item_id)
	control.set_meta("reward_layout_default_position", default_rect.position)
	control.set_meta("reward_layout_default_scale", Vector2.ONE)
	reward_layout_groups[item_id] = control
	return control


func reward_layout_apply_child_control(item_id: String, control: Control, default_rect: Rect2, parent_size: Vector2) -> Control:
	var stored: Variant = reward_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var scale := reward_layout_scale_for(item_id)
	var visual_size := default_rect.size * scale
	control.position = Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, parent_size.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, parent_size.y - visual_size.y)))
	control.size = default_rect.size
	control.scale = scale
	control.set_meta("reward_layout_item_id", item_id)
	control.set_meta("reward_layout_default_position", default_rect.position)
	control.set_meta("reward_layout_default_scale", Vector2.ONE)
	reward_layout_groups[item_id] = control
	return control


func _load_reward_layout() -> void:
	reward_layout_positions.clear()
	reward_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("reward_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in REWARD_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		reward_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		reward_layout_scales[item_id] = Vector2(float(encoded[2]), float(encoded[3]))


func _serialized_reward_layout() -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in REWARD_LAYOUT_ITEM_IDS:
		var group: Control = reward_layout_groups.get(item_id)
		if group == null or not is_instance_valid(group):
			continue
		output[item_id] = [group.position.x, group.position.y, group.scale.x, group.scale.y]
	return output


func _sync_reward_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["reward_layout"] = _serialized_reward_layout()


func save_reward_layout() -> bool:
	_sync_reward_layout_to_runtime_settings()
	return game != null and game.persist_profile()


func show_reward_layout_editor() -> void:
	if not reward_layout_editor_is_available():
		return
	var editor = HudLayoutEditorScript.new()
	editor.name = "Reward_LayoutEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(editor)
	var entries: Array = [{"id": "title", "target": reward_layout_groups.get("title"), "label": "TIÊU ĐỀ", "accent": CYAN, "default_position": REWARD_TITLE_RECT.position, "default_scale": Vector2.ONE}]
	for index in range(3):
		var card_id := "card_%02d" % (index + 1)
		var card_position := REWARD_CARD_ORIGIN + Vector2(index * (REWARD_CARD_SIZE.x + REWARD_CARD_GAP), 0.0)
		entries.append({"id": card_id, "target": reward_layout_groups.get(card_id), "label": "KHUNG CARD %02d" % (index + 1), "accent": CYAN, "default_position": card_position, "default_scale": Vector2.ONE})
		entries.append({"id": "%s_title" % card_id, "target": reward_layout_groups.get("%s_title" % card_id), "label": "TÊN CARD %02d" % (index + 1), "accent": CYAN, "default_position": Vector2(24.0, 66.0), "default_scale": Vector2.ONE, "global_canvas": true})
		entries.append({"id": "%s_description" % card_id, "target": reward_layout_groups.get("%s_description" % card_id), "label": "MÔ TẢ CARD %02d" % (index + 1), "accent": CYAN, "default_position": Vector2(24.0, 157.0), "default_scale": Vector2.ONE, "global_canvas": true})
	entries.append({"id": "repair", "target": reward_layout_groups.get("repair"), "label": "SỬA CHỮA", "accent": CYAN, "default_position": REWARD_REPAIR_RECT.position, "default_scale": Vector2.ONE})
	editor.configure(entries, font, bold, "CHỈNH NÂNG CẤP · kéo card để di chuyển · tên/mô tả card có khung riêng · kéo cạnh/góc để đổi cỡ · F11: lưu · R: mặc định")
	editor.item_changed.connect(_on_reward_layout_item_changed)
	reward_layout_editor = editor
	editor.set_editor_active(false)


func reward_layout_editor_is_available() -> bool:
	return OS.is_debug_build() and game != null and not game.test_mode


func _on_reward_layout_item_changed(item_id: String, position: Vector2, scale: Vector2) -> void:
	reward_layout_positions[item_id] = position
	reward_layout_scales[item_id] = scale
	_sync_reward_layout_to_runtime_settings()


func show_pause() -> void:
	clear_overlay()
	var pause_art := background_texture(overlay, PAUSE_BACKGROUND, TextureRect.STRETCH_SCALE)
	pause_art.name = "Pause_MenuArtwork"
	pause_art.set_meta("pause_background_path", PAUSE_BACKGROUND)
	var title_group := Control.new()
	title_group.name = "Pause_TitleGroup"
	title_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layout_apply_control("title", title_group, PAUSE_TITLE_RECT)
	var title := label(title_group, "TẠM DỪNG", Rect2(Vector2.ZERO, PAUSE_TITLE_RECT.size), PAUSE_TITLE_FONT_SIZE, CYAN, true)
	title.name = "Pause_Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	overlay.add_child(title_group)
	var continue_button := pause_action("continue", "TIẾP TỤC", pause_action_rect(0), game.resume_game, CYAN)
	pause_action("settings", "CÀI ĐẶT", pause_action_rect(1), func(): show_settings("paused"), LED_PURPLE)
	pause_action("menu", "MENU", pause_action_rect(2), game.return_to_menu, CYAN)
	show_pause_layout_editor()
	continue_button.grab_focus()


func pause_action_rect(index: int) -> Rect2:
	return Rect2(PAUSE_ACTION_ORIGIN + Vector2(0.0, index * (PAUSE_ACTION_SIZE.y + PAUSE_ACTION_GAP)), PAUSE_ACTION_SIZE)


func pause_action(action_id: String, title_text: String, rect: Rect2, action: Callable, accent: Color) -> Button:
	var group := Control.new()
	group.name = "Pause_Action_%s" % action_id.capitalize()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_layout_apply_control(action_id, group, rect)
	# The artwork owns the decorative chassis. At runtime each pause action is
	# intentionally only its centered text plus an invisible rectangular target;
	# the F10 editor remains responsible for showing the editable rectangle.
	var title_label := plain_label(group, title_text, Rect2(0.0, 13.0, rect.size.x, rect.size.y - 26.0), 24, accent, true)
	title_label.name = "Pause_%s_Label" % action_id.capitalize()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var target := Button.new()
	target.name = "Pause_%s_Hitbox" % action_id.capitalize()
	target.text = title_text
	target.tooltip_text = title_text
	target.position = Vector2.ZERO
	target.size = rect.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.set_meta("pause_action_id", action_id)
	target.set_meta("pause_art_rect", rect)
	target.set_meta("pause_hitbox_visual", "invisible")
	# Do not draw a hover, focus, or pressed treatment over the authored button
	# frames. The label is the only runtime-visible part of this action.
	for state: String in ["normal", "disabled", "focus", "hover", "pressed"]:
		target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var invisible_text := Color(1, 1, 1, 0)
	target.add_theme_color_override("font_color", invisible_text)
	target.add_theme_color_override("font_hover_color", invisible_text)
	target.add_theme_color_override("font_pressed_color", invisible_text)
	target.add_theme_color_override("font_focus_color", invisible_text)
	target.add_theme_color_override("font_disabled_color", invisible_text)
	target.pressed.connect(action)
	group.add_child(target)
	overlay.add_child(group)
	return target


func show_pause_layout_editor() -> void:
	if not pause_layout_editor_is_available():
		return
	var editor = HudLayoutEditorScript.new()
	editor.name = "Pause_LayoutEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(editor)
	var entries: Array = [
		{"id": "title", "target": pause_layout_groups.get("title"), "label": "TẠM DỪNG", "accent": CYAN, "default_position": PAUSE_TITLE_RECT.position, "default_scale": Vector2.ONE},
		{"id": "continue", "target": pause_layout_groups.get("continue"), "label": "TIẾP TỤC", "accent": CYAN, "default_position": PAUSE_ACTION_ORIGIN, "default_scale": Vector2.ONE},
		{"id": "settings", "target": pause_layout_groups.get("settings"), "label": "CÀI ĐẶT", "accent": LED_PURPLE, "default_position": pause_action_rect(1).position, "default_scale": Vector2.ONE},
		{"id": "menu", "target": pause_layout_groups.get("menu"), "label": "MENU", "accent": CYAN, "default_position": pause_action_rect(2).position, "default_scale": Vector2.ONE},
	]
	editor.configure(entries, font, bold, "CHỈNH TẠM DỪNG · kéo khung để di chuyển · kéo cạnh/góc để đổi cỡ chữ hoặc nút · F10: lưu · R: mặc định")
	editor.item_changed.connect(_on_pause_layout_item_changed)
	pause_layout_editor = editor
	editor.set_editor_active(false)


func pause_layout_editor_is_available() -> bool:
	return PAUSE_LAYOUT_EDITOR_ENABLED and OS.is_debug_build() and game != null and not game.test_mode


func _on_pause_layout_item_changed(item_id: String, position: Vector2, scale: Vector2) -> void:
	pause_layout_positions[item_id] = position
	pause_layout_scales[item_id] = scale
	_sync_pause_layout_to_runtime_settings()

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

func show_cyber_shop() -> void:
	clear_overlay()
	background_texture(overlay, REWARD_BACKGROUND, TextureRect.STRETCH_SCALE)
	
	# Header title
	var title := led_label(overlay, "CYBER SHOP · TRẠM NÂNG CẤP CHIẾN ĐẤU", Rect2(0, 16, 1280, 34), 23, CYAN, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var subtitle := plain_label(overlay, "Thu thập Coin khi diệt quái mỗi đợt để nâng cấp Drone trợ chiến và sức mạnh sinh tồn", Rect2(0, 51, 1280, 20), 13, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Balance banner in the center
	glow_panel(overlay, Rect2(440, 76, 400, 38), Color(0.06, 0.04, 0.01, 0.9), Color("ffd700"))
	var balance_text := plain_label(overlay, "🪙 SỐ DƯ: %d COIN" % game.coins, Rect2(440, 78, 400, 34), 18, Color("ffd700"), true)
	balance_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# 7 Upgrade Items (4 Left column, 3 Right column)
	var left_x: float = 65.0
	var right_x: float = 675.0
	var card_w: float = 540.0
	var card_h: float = 102.0
	var start_y: float = 126.0
	var gap_y: float = 112.0
	
	var player = game.player
	var upgrades: Dictionary = game.upgrades
	var has_drone: bool = game.has_drone or int(upgrades.get("drone", 0)) > 0
	var drone_overclock_lvl: int = int(upgrades.get("drone_overclock", 0))
	var health_lvl: int = int(upgrades.get("health", 0))
	var shield_lvl: int = int(upgrades.get("shield", 0))
	var damage_lvl: int = int(upgrades.get("damage", 0))
	var magnet_lvl: int = int(upgrades.get("magnet", 0))
	var speed_lvl: int = int(upgrades.get("speed", 0))
	
	var items: Array = [
		{
			"col": 0, "row": 0,
			"icon": "⚡",
			"name": "Drone Overclock",
			"desc": "Tăng 25% tốc độ bắn đạn và +6 sát thương đạn Plasma mỗi cấp (yêu cầu sở hữu Drone).",
			"level_text": "Cấp %d/3" % drone_overclock_lvl if drone_overclock_lvl < 3 else "TỐI ĐA (Cấp 3/3)",
			"price": 45,
			"disabled": (not has_drone) or drone_overclock_lvl >= 3 or game.coins < 45,
			"btn_text": "TỐI ĐA" if drone_overclock_lvl >= 3 else ("CHƯA CÓ DRONE" if not has_drone else "NÂNG CẤP 45 🪙"),
			"action_id": "drone_overclock",
		},
		{
			"col": 1, "row": 0,
			"icon": "❤️",
			"name": "Hồi Máu Khẩn Cấp (+45 HP)",
			"desc": "Hồi ngay lập tức 45 HP sinh lực (hiện tại: %d/%d HP)." % [int(player.hp), int(player.max_hp)],
			"level_text": "Khẩn cấp",
			"price": 20,
			"disabled": player.hp >= player.max_hp or game.coins < 20,
			"btn_text": "MÁU ĐẦY" if player.hp >= player.max_hp else "HỒI 20 🪙",
			"action_id": "heal",
		},
		{
			"col": 0, "row": 1,
			"icon": "💖",
			"name": "Gia Cố Máu Tối Đa (+25 Max HP)",
			"desc": "+25 Máu tối đa vĩnh viễn và hồi ngay 25 HP. Máu tối đa hiện tại: %d HP." % int(player.max_hp),
			"level_text": "Cấp %d/5" % health_lvl if health_lvl < 5 else "TỐI ĐA (Cấp 5/5)",
			"price": 35 + health_lvl * 10,
			"disabled": health_lvl >= 5 or game.coins < (35 + health_lvl * 10),
			"btn_text": "TỐI ĐA" if health_lvl >= 5 else "MUA %d 🪙" % (35 + health_lvl * 10),
			"action_id": "max_hp",
		},
		{
			"col": 1, "row": 1,
			"icon": "🛡️",
			"name": "Khuếch Đại Khiên (+20 Max Shield)",
			"desc": "+20 Khiên tối đa vĩnh viễn và nạp đầy khiên ngay. Khiên tối đa hiện tại: %d." % int(player.max_shield),
			"level_text": "Cấp %d/5" % shield_lvl if shield_lvl < 5 else "TỐI ĐA (Cấp 5/5)",
			"price": 30 + shield_lvl * 10,
			"disabled": shield_lvl >= 5 or game.coins < (30 + shield_lvl * 10),
			"btn_text": "TỐI ĐA" if shield_lvl >= 5 else "MUA %d 🪙" % (30 + shield_lvl * 10),
			"action_id": "max_shield",
		},
		{
			"col": 0, "row": 2,
			"icon": "⚔️",
			"name": "Tăng Sát Thương Vũ Khí (+15%)",
			"desc": "+15% sát thương toàn bộ súng, đạn và đòn đánh. Sát thương cộng thêm: +" + str(damage_lvl * 15) + "%.",
			"level_text": "Cấp %d/5" % damage_lvl if damage_lvl < 5 else "TỐI ĐA (Cấp 5/5)",
			"price": 40 + damage_lvl * 15,
			"disabled": damage_lvl >= 5 or game.coins < (40 + damage_lvl * 15),
			"btn_text": "TỐI ĐA" if damage_lvl >= 5 else "MUA %d 🪙" % (40 + damage_lvl * 15),
			"action_id": "damage",
		},
		{
			"col": 1, "row": 2,
			"icon": "🧲",
			"name": "Nam Châm Hút Coin (+50 px)",
			"desc": "Tăng bán kính tự động hút Coin và Năng lượng thêm +50px giúp farm coin cực nhàn.",
			"level_text": "Cấp %d/3" % magnet_lvl if magnet_lvl < 3 else "TỐI ĐA (Cấp 3/3)",
			"price": 25,
			"disabled": magnet_lvl >= 3 or game.coins < 25,
			"btn_text": "TỐI ĐA" if magnet_lvl >= 3 else "MUA 25 🪙",
			"action_id": "magnet",
		},
		{
			"col": 0, "row": 3,
			"icon": "💨",
			"name": "Tốc Độ Di Chuyển (+23 px/s)",
			"desc": "+23 px/s tốc độ chạy giúp nhân vật di chuyển cơ động, né đạn quái linh hoạt hơn.",
			"level_text": "Cấp %d/3" % speed_lvl if speed_lvl < 3 else "TỐI ĐA (Cấp 3/3)",
			"price": 30,
			"disabled": speed_lvl >= 3 or game.coins < 30,
			"btn_text": "TỐI ĐA" if speed_lvl >= 3 else "MUA 30 🪙",
			"action_id": "speed",
		}
	]
	
	for item in items:
		var x: float = left_x if item.col == 0 else right_x
		var y: float = start_y + item.row * gap_y
		var card_rect := Rect2(x, y, card_w, card_h)
		
		# Card background panel
		panel(overlay, card_rect, Color(0.03, 0.02, 0.07, 0.88), Color("39284f") if item.disabled else CYAN)
		
		# Icon & Title
		var title_str: String = "%s %s" % [item.icon, item.name]
		var item_title := plain_label(overlay, title_str, Rect2(x + 12, y + 8, card_w - 140, 24), 15, Color("35e7ff") if not item.disabled else MUTED, true)
		item_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		item_title.clip_text = true
		
		# Level badge
		var lvl_lbl := plain_label(overlay, "[%s]" % item.level_text, Rect2(x + card_w - 104, y + 9, 92, 20), 11, Color("ffd700") if item.disabled else CYAN)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_lbl.clip_text = true
		
		# Description
		var card_desc := plain_label(overlay, item.desc, Rect2(x + 12, y + 34, card_w - 170, 60), 12, MUTED)
		card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		# Buy Button
		var btn_rect := Rect2(x + card_w - 150, y + 30, 140, 48)
		var action_cb: Callable = _on_cyber_shop_buy.bind(String(item.action_id))
		var btn: Button = button(overlay, item.btn_text, btn_rect, action_cb, not item.disabled, Color("ffd700") if not item.disabled else MUTED)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = item.disabled
		btn.focus_mode = Control.FOCUS_NONE
	
	# Close / Resume Button at bottom (Touch-first for Mobile)
	var close_btn := button(overlay, "TIẾP TỤC CHIẾN ĐẤU  ▶", Rect2(440, 584, 400, 52), game.resume_game, true, CYAN)
	close_btn.add_theme_font_size_override("font_size", 17)
	close_btn.grab_focus()

func _on_cyber_shop_buy(action_id: String) -> void:
	match action_id:
		"drone_overclock":
			game.buy_drone_overclock()
		"heal":
			game.buy_heal_hp()
		"max_hp":
			game.buy_max_hp_upgrade()
		"max_shield":
			game.buy_max_shield_upgrade()
		"damage":
			game.buy_damage_upgrade()
		"magnet":
			game.buy_magnet_upgrade()
		"speed":
			game.buy_speed_upgrade()
	show_cyber_shop()

func show_shop(offers: Array) -> void:
	var kind: String = game.graph.support
	if kind == "heal":
		modal_header("TRẠM HỖ TRỢ", "Chọn một dịch vụ. Vũ khí sẽ thay ô đang cầm: %s · Bạn có %d tín dụng." % [game.weapon_system.definition(game.weapons[game.active_slot]).name, game.coins])
		panel(overlay, Rect2(250, 238, 780, 271))
		label(overlay, "Trạm tái tạo", Rect2(291, 270, 690, 52), 32, CYAN, true)
		label(overlay, "Hồi 45 máu, đầy khiên và năng lượng. Chỉ dùng một lần trong khu vực.", Rect2(291, 348, 690, 82), 25, MUTED)
		button(overlay, "TÁI TẠO MIỄN PHÍ", Rect2(420, 536, 440, 62), game.heal_support, true)
	else:
		var price: int = 0 if kind == "chest" else 55 + game.stage_index * 12
		show_support_weapon_choices(offers, price)


func show_support_weapon_choices(offers: Array, price: int) -> void:
	clear_overlay()
	var support_art := background_texture(overlay, REWARD_BACKGROUND, TextureRect.STRETCH_SCALE)
	support_art.name = "Support_WeaponArtwork"
	support_art.set_meta("support_background_path", REWARD_BACKGROUND)
	var title_group := support_layout_group("title", SUPPORT_TITLE_RECT)
	var title := plain_label(title_group, "TRẠM HỖ TRỢ", Rect2(Vector2.ZERO, SUPPORT_TITLE_RECT.size), 30, CYAN, true)
	title.name = "Support_Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var status_group := support_layout_group("status", SUPPORT_STATUS_RECT)
	var current_weapon_name: String = str(game.weapon_system.definition(game.weapons[game.active_slot]).name)
	var status := plain_label(status_group, "ĐỔI Ô ĐANG CẦM: %s · %d TÍN DỤNG" % [current_weapon_name, game.coins], Rect2(Vector2.ZERO, SUPPORT_STATUS_RECT.size), 17, CYAN)
	status.name = "Support_Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var first_button: Button = null
	for index in range(3):
		var card_rect := Rect2(REWARD_CARD_ORIGIN + Vector2(index * (REWARD_CARD_SIZE.x + REWARD_CARD_GAP), 0.0), REWARD_CARD_SIZE)
		var offer: Dictionary = offers[index] if index < offers.size() else {}
		var choice_button := support_weapon_card(index, offer, card_rect, price)
		if first_button == null and choice_button != null:
			first_button = choice_button
	var back_button := support_back_button()
	show_support_layout_editor()
	if first_button != null:
		first_button.grab_focus()
	else:
		back_button.grab_focus()


func support_weapon_card(index: int, offer: Dictionary, rect: Rect2, price: int) -> Button:
	var card_id := "card_%02d" % (index + 1)
	var group := Control.new()
	group.name = "Support_Card_%02d" % (index + 1)
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_layout_apply_control(card_id, group, rect)
	group.set_meta("support_card_index", index)
	overlay.add_child(group)
	var offer_id := str(offer.get("id", ""))
	if offer_id.is_empty():
		var empty_label := plain_label(group, "KHÔNG CÓ VŨ KHÍ", Rect2(24.0, 168.0, 282.0, 45.0), 18, CYAN, true)
		empty_label.name = "Support_Card_%02d_Empty" % (index + 1)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		return null

	var icon_layout := Control.new()
	icon_layout.name = "Support_Card_%02d_IconLayout" % (index + 1)
	icon_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_layout_apply_child_control("%s_icon" % card_id, icon_layout, SUPPORT_CARD_ICON_RECT, REWARD_CARD_SIZE)
	group.add_child(icon_layout)
	var icon := texture(icon_layout, gameplay_weapon_model_path(offer), Rect2(Vector2.ZERO, SUPPORT_CARD_ICON_RECT.size))
	icon.name = "Support_Card_%02d_Icon" % (index + 1)

	var title_label := plain_label(group, str(offer.get("name", "")), SUPPORT_CARD_TITLE_RECT, 23, CYAN, true)
	title_label.name = "Support_Card_%02d_Title" % (index + 1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	support_layout_apply_child_control("%s_title" % card_id, title_label, SUPPORT_CARD_TITLE_RECT, REWARD_CARD_SIZE)
	var description_label := plain_label(group, str(offer.get("description", "")), SUPPORT_CARD_DESCRIPTION_RECT, 16, CYAN)
	description_label.name = "Support_Card_%02d_Description" % (index + 1)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	support_layout_apply_child_control("%s_description" % card_id, description_label, SUPPORT_CARD_DESCRIPTION_RECT, REWARD_CARD_SIZE)

	var action_text := "NHẬN MIỄN PHÍ" if price == 0 else "MUA · %d TÍN DỤNG" % price
	var action_button := support_text_button(group, action_text, SUPPORT_CARD_ACTION_RECT, func(): game.buy_weapon(offer_id), "Trang bị %s" % str(offer.get("name", "")))
	action_button.name = "Support_Card_%02d_Hitbox" % (index + 1)
	action_button.disabled = game.coins < price
	return action_button


func support_back_button() -> Button:
	var target := support_text_button(overlay, "ĐỂ SAU · TRỞ LẠI PHÒNG", SUPPORT_BACK_RECT, game.resume_game, "Bỏ qua trạm hỗ trợ và trở lại phòng")
	target.name = "Support_BackButton"
	support_layout_apply_control("back", target, SUPPORT_BACK_RECT)
	return target


func support_text_button(parent: Node, text_value: String, rect: Rect2, action: Callable, tooltip: String) -> Button:
	var target := Button.new()
	target.text = text_value
	target.position = rect.position
	target.size = rect.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.tooltip_text = tooltip
	target.add_theme_font_override("font", bold)
	target.add_theme_font_size_override("font_size", 16)
	for state: String in ["normal", "disabled", "hover", "focus", "pressed"]:
		target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	target.add_theme_color_override("font_color", CYAN)
	target.add_theme_color_override("font_disabled_color", Color(CYAN.r, CYAN.g, CYAN.b, 0.42))
	target.add_theme_color_override("font_hover_color", CYAN)
	target.add_theme_color_override("font_pressed_color", CYAN)
	target.add_theme_color_override("font_focus_color", CYAN)
	target.pressed.connect(action)
	parent.add_child(target)
	return target


func support_layout_group(item_id: String, default_rect: Rect2) -> Control:
	var group := Control.new()
	group.name = "Support_Layout_%s" % item_id
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	support_layout_apply_control(item_id, group, default_rect)
	overlay.add_child(group)
	return group


func support_layout_scale_for(item_id: String) -> Vector2:
	var stored: Variant = support_layout_scales.get(item_id, Vector2.ONE)
	if not stored is Vector2:
		return Vector2.ONE
	return Vector2(clampf(stored.x, 0.55, 2.0), clampf(stored.y, 0.55, 2.0))


func support_layout_position_for(item_id: String, default_rect: Rect2) -> Vector2:
	var stored: Variant = support_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var visual_size := default_rect.size * support_layout_scale_for(item_id)
	return Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, SUPPORT_LAYOUT_VIEWPORT_SIZE.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, SUPPORT_LAYOUT_VIEWPORT_SIZE.y - visual_size.y)))


func support_layout_apply_control(item_id: String, control: Control, default_rect: Rect2) -> Control:
	control.position = support_layout_position_for(item_id, default_rect)
	control.size = default_rect.size
	control.scale = support_layout_scale_for(item_id)
	control.set_meta("support_layout_item_id", item_id)
	control.set_meta("support_layout_default_position", default_rect.position)
	control.set_meta("support_layout_default_scale", Vector2.ONE)
	support_layout_groups[item_id] = control
	return control


func support_layout_apply_child_control(item_id: String, control: Control, default_rect: Rect2, parent_size: Vector2) -> Control:
	var stored: Variant = support_layout_positions.get(item_id, default_rect.position)
	var desired_position: Vector2 = stored if stored is Vector2 else default_rect.position
	var scale := support_layout_scale_for(item_id)
	var visual_size := default_rect.size * scale
	control.position = Vector2(
		clampf(desired_position.x, 0.0, maxf(0.0, parent_size.x - visual_size.x)),
		clampf(desired_position.y, 0.0, maxf(0.0, parent_size.y - visual_size.y)))
	control.size = default_rect.size
	control.scale = scale
	control.set_meta("support_layout_item_id", item_id)
	control.set_meta("support_layout_default_position", default_rect.position)
	control.set_meta("support_layout_default_scale", Vector2.ONE)
	support_layout_groups[item_id] = control
	return control


func _load_support_layout() -> void:
	support_layout_positions.clear()
	support_layout_scales.clear()
	if game == null or not game.settings is Dictionary:
		return
	var stored: Variant = game.settings.get("support_layout", {})
	if not stored is Dictionary:
		return
	for item_id: String in SUPPORT_LAYOUT_ITEM_IDS:
		var encoded: Variant = stored.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not (encoded[0] is int or encoded[0] is float) or not (encoded[1] is int or encoded[1] is float):
			continue
		if not (encoded[2] is int or encoded[2] is float) or not (encoded[3] is int or encoded[3] is float):
			continue
		if not is_finite(float(encoded[0])) or not is_finite(float(encoded[1])) or not is_finite(float(encoded[2])) or not is_finite(float(encoded[3])):
			continue
		support_layout_positions[item_id] = Vector2(float(encoded[0]), float(encoded[1]))
		support_layout_scales[item_id] = Vector2(float(encoded[2]), float(encoded[3]))


func _serialized_support_layout() -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in SUPPORT_LAYOUT_ITEM_IDS:
		var group: Control = support_layout_groups.get(item_id)
		if group == null or not is_instance_valid(group):
			continue
		output[item_id] = [group.position.x, group.position.y, group.scale.x, group.scale.y]
	return output


func _sync_support_layout_to_runtime_settings() -> void:
	if game != null and game.settings is Dictionary:
		game.settings["support_layout"] = _serialized_support_layout()


func save_support_layout() -> bool:
	_sync_support_layout_to_runtime_settings()
	return game != null and game.persist_profile()


func show_support_layout_editor() -> void:
	if not support_layout_editor_is_available():
		return
	var editor = HudLayoutEditorScript.new()
	editor.name = "Support_LayoutEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(editor)
	var entries: Array = [
		{"id": "title", "target": support_layout_groups.get("title"), "label": "TIÊU ĐỀ", "accent": CYAN, "default_position": SUPPORT_TITLE_RECT.position, "default_scale": Vector2.ONE},
		{"id": "status", "target": support_layout_groups.get("status"), "label": "TRẠNG THÁI", "accent": CYAN, "default_position": SUPPORT_STATUS_RECT.position, "default_scale": Vector2.ONE},
	]
	for index in range(3):
		var card_id := "card_%02d" % (index + 1)
		var card_position := REWARD_CARD_ORIGIN + Vector2(index * (REWARD_CARD_SIZE.x + REWARD_CARD_GAP), 0.0)
		entries.append({"id": card_id, "target": support_layout_groups.get(card_id), "label": "KHUNG CARD %02d" % (index + 1), "accent": CYAN, "default_position": card_position, "default_scale": Vector2.ONE})
		entries.append({"id": "%s_icon" % card_id, "target": support_layout_groups.get("%s_icon" % card_id), "label": "ICON CARD %02d" % (index + 1), "accent": CYAN, "default_position": SUPPORT_CARD_ICON_RECT.position, "default_scale": Vector2.ONE, "global_canvas": true})
		entries.append({"id": "%s_title" % card_id, "target": support_layout_groups.get("%s_title" % card_id), "label": "TÊN CARD %02d" % (index + 1), "accent": CYAN, "default_position": SUPPORT_CARD_TITLE_RECT.position, "default_scale": Vector2.ONE, "global_canvas": true})
		entries.append({"id": "%s_description" % card_id, "target": support_layout_groups.get("%s_description" % card_id), "label": "MÔ TẢ CARD %02d" % (index + 1), "accent": CYAN, "default_position": SUPPORT_CARD_DESCRIPTION_RECT.position, "default_scale": Vector2.ONE, "global_canvas": true})
	entries.append({"id": "back", "target": support_layout_groups.get("back"), "label": "TRỞ LẠI PHÒNG", "accent": CYAN, "default_position": SUPPORT_BACK_RECT.position, "default_scale": Vector2.ONE})
	editor.configure(entries, font, bold, "CHỈNH TRẠM HỖ TRỢ · kéo card để di chuyển · icon/tên/mô tả có khung riêng · kéo cạnh/góc để đổi cỡ · F11: lưu · R: mặc định")
	editor.item_changed.connect(_on_support_layout_item_changed)
	support_layout_editor = editor
	editor.set_editor_active(false)


func support_layout_editor_is_available() -> bool:
	return OS.is_debug_build() and game != null and not game.test_mode


func _on_support_layout_item_changed(item_id: String, position: Vector2, scale: Vector2) -> void:
	support_layout_positions[item_id] = position
	support_layout_scales[item_id] = scale
	_sync_support_layout_to_runtime_settings()

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


func show_hud_layout_editor() -> void:
	if not hud_layout_editor_is_available():
		return
	var editor = HudLayoutEditorScript.new()
	editor.name = "Gameplay_HudLayoutEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(editor)
	var entries: Array = [
		{"id": "hp", "target": hud_layout_groups.get("hp"), "label": "HP", "accent": CORAL, "default_position": Vector2(84, 44), "default_scale": Vector2.ONE},
		{"id": "shield", "target": hud_layout_groups.get("shield"), "label": "KHIÊN", "accent": CYAN, "default_position": Vector2(84, 62), "default_scale": Vector2.ONE},
		{"id": "energy", "target": hud_layout_groups.get("energy"), "label": "MANA", "accent": Color("3478ff"), "default_position": Vector2(84, 80), "default_scale": Vector2.ONE},
		{"id": "title", "target": hud_layout_groups.get("title"), "label": "TIÊU ĐỀ", "accent": CYAN, "default_position": hud_title_default_position, "default_scale": Vector2.ONE},
		{"id": "weapon", "target": hud_layout_groups.get("weapon"), "label": "VŨ KHÍ", "accent": LED_PURPLE, "default_position": Vector2(838, 11), "default_scale": Vector2.ONE},
		{"id": "pause", "target": hud_layout_groups.get("pause"), "label": "TẠM DỪNG", "accent": CYAN, "default_position": Vector2(1180, 6), "default_scale": Vector2.ONE},
		{"id": "boss", "target": hud_layout_groups.get("boss"), "label": "BOSS", "accent": CORAL, "default_position": Vector2(384, 130), "default_scale": Vector2.ONE},
	]
	if game.controls != null:
		for item_id: String in TOUCH_LAYOUT_ITEM_IDS:
			var touch_target: Control = game.controls.touch_layout_target(item_id)
			var default_rect: Rect2 = game.controls.touch_layout_default_rect(item_id)
			entries.append({"id": item_id, "target": touch_target, "label": "NÚT %s" % item_id.to_upper(), "accent": CYAN, "default_position": default_rect.position, "default_scale": Vector2.ONE})
	editor.configure(entries, font, bold, "CHỈNH HUD + NÚT CẢM ỨNG · kéo để di chuyển · kéo cạnh/góc để đổi cỡ · kích đúp để chỉnh riêng · kích đúp lại hiện tất cả · F8: lưu · R: mặc định")
	editor.item_changed.connect(_on_hud_layout_item_changed)
	hud_layout_editor = editor
	editor.set_editor_active(false)


func hud_layout_editor_is_available() -> bool:
	return HUD_LAYOUT_EDITOR_ENABLED and OS.is_debug_build() and game != null and not game.test_mode


func _on_hud_layout_item_changed(item_id: String, position: Vector2, scale: Vector2) -> void:
	if TOUCH_LAYOUT_ITEM_IDS.has(item_id):
		if game != null and game.controls != null:
			game.controls.apply_touch_layout_transform(item_id, position, scale)
		return
	hud_layout_positions[item_id] = position
	hud_layout_scales[item_id] = scale
	if item_id == "title":
		var title_group: Control = hud_layout_groups.get("title")
		if title_group != null:
			hud_title_anchor = position + Vector2(title_group.size.x * scale.x * 0.5, title_group.size.y * scale.y * 0.5)
			hud_title_anchor_valid = true
	_sync_hud_layout_to_runtime_settings()


func show_armory_layout_editor(entries: Array) -> void:
	if not armory_layout_editor_is_available():
		return
	var editor = HudLayoutEditorScript.new()
	editor.name = "Armory_LayoutEditor"
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(editor)
	editor.configure(entries, font, bold, "CHỈNH KHO VŨ KHÍ · kéo thành phần để di chuyển · kéo cạnh/góc để đổi cỡ · kích đúp để chỉnh riêng · kích đúp lại hiện tất cả · F9: lưu · R: mặc định")
	editor.item_changed.connect(_on_armory_layout_item_changed)
	armory_layout_editor = editor
	editor.set_editor_active(false)


func armory_layout_editor_is_available() -> bool:
	return ARMORY_LAYOUT_EDITOR_ENABLED and OS.is_debug_build() and game != null and not game.test_mode


func _on_armory_layout_item_changed(item_id: String, position: Vector2, scale: Vector2) -> void:
	armory_layout_positions[item_id] = position
	armory_layout_scales[item_id] = scale
	_sync_armory_layout_to_runtime_settings()

func _unhandled_input(event: InputEvent) -> void:
	if game != null and game.state == "playing" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		if reward_layout_editor_is_available():
			show_reward_layout_preview()
			get_viewport().set_input_as_handled()
		return
	if game != null and game.state == "reward" and reward_layout_editor != null and is_instance_valid(reward_layout_editor) and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			if reward_layout_editor.is_editor_active():
				if save_reward_layout():
					reward_layout_editor.set_editor_active(false)
					if reward_layout_preview_active:
						close_reward_layout_preview()
				else:
					game.flash_text("CHƯA LƯU ĐƯỢC BỐ CỤC NÂNG CẤP", CORAL)
			else:
				reward_layout_editor.set_editor_active(true)
				overlay.move_child(reward_layout_editor, -1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R and reward_layout_editor.is_editor_active():
			reward_layout_editor.reset_layout()
			get_viewport().set_input_as_handled()
			return
	if game != null and game.state == "shop" and support_layout_editor != null and is_instance_valid(support_layout_editor) and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			if support_layout_editor.is_editor_active():
				if save_support_layout():
					support_layout_editor.set_editor_active(false)
				else:
					game.flash_text("CHƯA LƯU ĐƯỢC BỐ CỤC TRẠM HỖ TRỢ", CORAL)
			else:
				support_layout_editor.set_editor_active(true)
				overlay.move_child(support_layout_editor, -1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R and support_layout_editor.is_editor_active():
			support_layout_editor.reset_layout()
			get_viewport().set_input_as_handled()
			return
	if game != null and game.state == "paused" and pause_layout_editor != null and is_instance_valid(pause_layout_editor) and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F10:
			if pause_layout_editor.is_editor_active():
				if save_pause_layout():
					pause_layout_editor.set_editor_active(false)
				else:
					game.flash_text("CHƯA LƯU ĐƯỢC BỐ CỤC TẠM DỪNG", CORAL)
			else:
				pause_layout_editor.set_editor_active(true)
				overlay.move_child(pause_layout_editor, -1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R and pause_layout_editor.is_editor_active():
			pause_layout_editor.reset_layout()
			get_viewport().set_input_as_handled()
			return
	if game != null and game.state == "playing" and hud_layout_editor != null and is_instance_valid(hud_layout_editor) and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F8:
			if hud_layout_editor.is_editor_active():
				if save_hud_layout():
					hud_layout_editor.set_editor_active(false)
				else:
					game.flash_text("CHƯA LƯU ĐƯỢC BỐ CỤC HUD", CORAL)
			else:
				hud_layout_editor.set_editor_active(true)
				root.move_child(hud_layout_editor, -1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R and hud_layout_editor.is_editor_active():
			hud_layout_editor.reset_layout()
			get_viewport().set_input_as_handled()
			return
	if game != null and game.state == "unlocks" and armory_layout_editor != null and is_instance_valid(armory_layout_editor) and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F9:
			if armory_layout_editor.is_editor_active():
				if save_armory_layout():
					armory_layout_editor.set_editor_active(false)
				else:
					game.flash_text("CHƯA LƯU ĐƯỢC BỐ CỤC KHO VŨ KHÍ", CORAL)
			else:
				armory_layout_editor.set_editor_active(true)
				overlay.move_child(armory_layout_editor, -1)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_R and armory_layout_editor.is_editor_active():
			armory_layout_editor.reset_layout()
			get_viewport().set_input_as_handled()
			return
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
	var name_label := label(shell, name_text, Rect2(16, 7, value_rect.position.x - 24.0, 25), 20, accent)
	name_label.name = "Settings_%s_Label" % key
	name_label.add_theme_color_override("font_outline_color", Color(accent.r, accent.g, accent.b, 0.22))
	name_label.add_theme_constant_override("outline_size", 1)
	var value_chip := settings_value_chip(shell, value_rect, accent)
	value_chip.name = "Settings_%s_ValueChip" % key
	value_chip.set_meta("settings_value_chip_key", key)
	var value_label := label(shell, current_value_text, value_rect, 18, accent)
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
	var text_color: Color = accent
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
	target.add_theme_font_override("font", bold)
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

func show_unlocks(target_tab: String = "") -> void:
	game.state = "unlocks"
	if not target_tab.is_empty():
		current_armory_tab = target_tab
	clear_overlay()
	background_texture(overlay, ARMORY_BACKGROUND, TextureRect.STRETCH_SCALE)
	var veil = ColorRect.new()
	veil.color = Color(0.004, 0.01, 0.028, 0.12)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(veil)
	var armory_entries: Array = []
	var title_rect := Rect2(64, 30, 210, 44)
	var title = plain_label(overlay, "TRANG BỊ", title_rect, 30, CYAN, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	armory_layout_apply_control("title", title, title_rect)
	armory_entries.append({"id": "title", "target": title, "label": "TIÊU ĐỀ", "accent": CYAN, "default_position": title_rect.position, "default_scale": Vector2.ONE})
	
	# Tab Switchers: VŨ KHÍ vs DRONE
	var tab_w_accent: Color = CYAN if current_armory_tab == "weapons" else MUTED
	var tab_d_accent: Color = CYAN if current_armory_tab == "drones" else MUTED
	var tab_w_btn := button(overlay, "⚔  VŨ KHÍ", Rect2(285, 32, 135, 46), func(): show_unlocks("weapons"), true, tab_w_accent)
	tab_w_btn.add_theme_font_size_override("font_size", 15)
	tab_w_btn.name = "Armory_Tab_Weapons"
	tab_w_btn.focus_mode = Control.FOCUS_NONE
	var tab_d_btn := button(overlay, "🛸  DRONE", Rect2(430, 32, 135, 46), func(): show_unlocks("drones"), true, tab_d_accent)
	tab_d_btn.add_theme_font_size_override("font_size", 15)
	tab_d_btn.name = "Armory_Tab_Drones"
	tab_d_btn.focus_mode = Control.FOCUS_NONE
	
	accent_rule(overlay, Rect2(64, 117, 426, 2), Color(CYAN.r, CYAN.g, CYAN.b, 0.74))
	
	# Currency banner
	var coins_count: int = game.coins if (game != null and "coins" in game) else 0
	var shards_count: int = int(game.profile.meta.get("shards", 0)) if (game != null and "profile" in game and "meta" in game.profile) else 0
	var currency_lbl := plain_label(overlay, "🪙 %d COIN   ·   💎 %d MẢNH" % [coins_count, shards_count], Rect2(64, 82, 426, 24), 14, Color("ffd700"), true)
	currency_lbl.name = "Armory_CurrencyLabel"
	currency_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	currency_lbl.clip_text = true
	
	if current_armory_tab == "weapons":
		# Dedicated Drone Companion Quick Bay
		var drone_bay_rect := Rect2(590, 24, 626, 88)
		var has_drone: bool = bool(game.has_drone if (game != null and "has_drone" in game) else false) or int(game.upgrades.get("drone", 0) if (game != null and "upgrades" in game) else 0) > 0 or bool(game.profile.meta.get("has_drone", false) if (game != null and "profile" in game and "meta" in game.profile) else false)
		var drone_active: bool = game != null and game.companion_drone != null and game.companion_drone.enabled
		var drone_accent: Color = Color("35e7ff") if has_drone else Color("4d3566")
		panel(overlay, drone_bay_rect, Color(0.04, 0.02, 0.08, 0.94), drone_accent)
		
		var drone_icon_box := Rect2(602, 34, 68, 68)
		glow_panel(overlay, drone_icon_box, Color(0.02, 0.04, 0.08, 0.95), CYAN if has_drone else MUTED)
		var drone_icon_lbl := plain_label(overlay, "🛸", Rect2(602, 40, 68, 48), 34, CYAN, true)
		drone_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		var drone_title := plain_label(overlay, "DRONE TRỢ CHIẾN PLASMA", Rect2(682, 32, 340, 22), 15, Color("35e7ff") if has_drone else Color("ffd700"), true)
		drone_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		drone_title.clip_text = true
		var drone_status_text: String
		if has_drone:
			drone_status_text = "Đang trang bị [BẬT] · Bay bọc lót, bắn Plasma 14 dmg" if drone_active else "Đang dự bị [TẮT] · Bấm nút để trang bị mang vào trận"
		else:
			drone_status_text = "Tự động bay bọc lót, bắn plasma 14 dmg (Phím T để Bật/Tắt)"
		var drone_desc := plain_label(overlay, drone_status_text, Rect2(682, 54, 340, 48), 11, Color("35e7ff") if (has_drone and drone_active) else MUTED)
		drone_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var drone_btn_rect := Rect2(1038, 42, 166, 52)
		var drone_btn_text: String
		var drone_btn_can_act: bool = false
		var drone_action: Callable
		if not has_drone:
			drone_btn_text = "MUA 60 🪙"
			drone_btn_can_act = coins_count >= 60 or shards_count >= 10
			drone_action = func():
				if game.buy_drone_companion():
					show_unlocks()
		else:
			drone_btn_text = "ĐANG BẬT [TẮT]" if drone_active else "CHỌN TRANG BỊ"
			drone_btn_can_act = true
			drone_action = func():
				if game.companion_drone != null:
					game.companion_drone.enabled = not game.companion_drone.enabled
					game.companion_drone.visible = game.companion_drone.enabled
				game.persist_profile()
				show_unlocks()
				
		var drone_btn := button(overlay, drone_btn_text, drone_btn_rect, drone_action, drone_btn_can_act, Color("ffd700") if not has_drone else CYAN)
		drone_btn.add_theme_font_size_override("font_size", 14)
		drone_btn.name = "Armory_DroneActionButton"
		drone_btn.disabled = not drone_btn_can_act
		drone_btn.focus_mode = Control.FOCUS_NONE
		if not drone_btn_can_act:
			drone_btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
			drone_btn.modulate = Color(1, 1, 1, 0.5)
		
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
			var can_activate: bool = not fixed_primary and not selected and (unlocked or int(game.profile.meta.shards) >= 8 or game.coins >= 50)
			var accent: Color = LED_PURPLE if selected else (CYAN if fixed_primary else (CYAN if unlocked else Color("756b91")))
			var state_visual = WeaponLoadoutStateScript.new()
			state_visual.name = "ArmoryState_%s" % weapon.id
			state_visual.position = card_position
			state_visual.size = ARMORY_CARD_SIZE
			state_visual.set_meta("armory_weapon_id", weapon.id)
			state_visual.configure(state, str(weapon.id), can_activate)
			overlay.add_child(state_visual)
			var details: Dictionary = armory_weapon_details(weapon, i, card_position, accent)
			var stt_rect := Rect2(card_position + Vector2(15, 10), Vector2(34, 17))
			var name_rect := Rect2(card_position + Vector2(92, 18), Vector2(154, 23))
			armory_entries.append({"id": "%s_stt" % weapon.id, "target": details.get("stt"), "label": "%02d · STT" % (i + 1), "accent": accent, "default_position": stt_rect.position, "default_scale": Vector2.ONE})
			armory_entries.append({"id": "%s_name" % weapon.id, "target": details.get("name"), "label": "%02d · TÊN" % (i + 1), "accent": CYAN, "default_position": name_rect.position, "default_scale": Vector2.ONE})
			var action: Callable = func(): game.select_starter(weapon.id) if unlocked else game.unlock_weapon(weapon.id)
			armory_weapon_hitbox(str(weapon.id), str(weapon.name), card_rect, action, can_activate, state_visual)
			var action_rect := armory_action_rect(card_rect)
			var action_button := armory_weapon_action_button(str(weapon.id), armory_loadout_text(state, game.coins >= 50), action_rect, action, can_activate, accent, state_visual)
			armory_entries.append({"id": "%s_action" % weapon.id, "target": action_button, "label": "%02d · TRANG BỊ" % (i + 1), "accent": accent, "default_position": action_rect.position, "default_scale": Vector2.ONE})
			if first_action == null and can_activate:
				first_action = action_button
		var return_button := armory_return_button()
		show_armory_layout_editor(armory_entries)
		if first_action != null:
			first_action.grab_focus()
		else:
			return_button.grab_focus()
	else:
		# DRONES TAB
		const DRONE_LIST: Array[Dictionary] = [
			{
				"id": "plasma", "name": "DRONE PLASMA", "type": "TẤN CÔNG LIÊN TỤC",
				"desc": "Bay bọc lót theo phi công, xả đạn Plasma 14 DMG liên tục (CD: 0.65s). Xuyên phá giáp mục tiêu nhanh chóng.",
				"icon": "🛸", "accent": Color("35e7ff"), "coin": 60, "shard": 10
			},
			{
				"id": "scout", "name": "DRONE TRINH SÁT", "type": "QUÉT RADAR 360°",
				"desc": "Định kỳ quét radar toàn màn hình, làm lộ diện điểm yếu khiến toàn bộ quái trong vùng chịu thêm +60% sát thương!",
				"icon": "📡", "accent": Color("ff916d"), "coin": 75, "shard": 12
			},
			{
				"id": "bomb", "name": "DRONE NÉM BOM", "type": "NỔ DIỆN RỘNG (AOE)",
				"desc": "Mỗi 2.5s thả bom chùm nổ lan 45 DMG bán kính 90px quét sạch bầy quái áp sát. Gây chấn động làm chậm kẻ địch.",
				"icon": "💣", "accent": Color("ff4d6d"), "coin": 90, "shard": 14
			},
			{
				"id": "laser", "name": "DRONE SENTINEL", "type": "LASER XUNG NĂNG",
				"desc": "Chiếu tia laser xuyên phá hội tụ liên tục lên quái gần nhất, thiêu đốt 22 DMG/giây không thể né tránh.",
				"icon": "⚡", "accent": Color("b366ff"), "coin": 110, "shard": 16
			},
			{
				"id": "support", "name": "DRONE NANO REPAIR", "type": "HỒI PHỤC KHIÊN",
				"desc": "Tự động kích hoạt trường tái tạo nano, hồi phục +14 Khiên (hoặc +8 Máu) mỗi 3.6s giúp tăng khả năng sống sót tối đa.",
				"icon": "🛡️", "accent": Color("88ffc9"), "coin": 120, "shard": 18
			},
		]
		
		var unlocked_drones: Array = game.profile.meta.get("unlocked_drones", [])
		var first_drone_btn: Button = null
		
		for i in range(DRONE_LIST.size()):
			var drone_info: Dictionary = DRONE_LIST[i]
			var d_id: String = drone_info.id
			var box := Rect2(64 + i * 232, 135, 218, 485)
			var is_unlocked: bool = unlocked_drones.has(d_id) or (d_id == "plasma" and bool(game.profile.meta.get("has_drone", false)))
			var is_selected: bool = is_unlocked and game.selected_drone == d_id and game.has_drone
			var d_accent: Color = LED_PURPLE if is_selected else (drone_info.accent if is_unlocked else MUTED)
			
			panel(overlay, box, Color(0.04, 0.02, 0.08, 0.94), d_accent)
			
			var type_lbl := label(overlay, drone_info.type, Rect2(box.position.x + 8, box.position.y + 12, box.size.x - 16, 20), 11, drone_info.accent, true)
			type_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			type_lbl.clip_text = true
			glow_panel(overlay, Rect2(box.position.x + 69, box.position.y + 38, 80, 80), Color(0.02, 0.04, 0.08, 0.95), drone_info.accent)
			var icon_lbl := plain_label(overlay, drone_info.icon, Rect2(box.position.x + 69, box.position.y + 44, 80, 68), 44, drone_info.accent, true)
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			var name_lbl := label(overlay, drone_info.name, Rect2(box.position.x + 8, box.position.y + 126, box.size.x - 16, 26), 14, WHITE, true)
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
			name_lbl.clip_text = true
			accent_rule(overlay, Rect2(box.position.x + 20, box.position.y + 158, box.size.x - 40, 2), Color(d_accent.r, d_accent.g, d_accent.b, 0.5))
			
			var desc_lbl := label(overlay, drone_info.desc, Rect2(box.position.x + 12, box.position.y + 170, box.size.x - 24, 210), 12, Color("35e7ff") if is_selected else (WHITE if is_unlocked else MUTED))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			
			var btn_rect := Rect2(box.position.x + 14, box.position.y + 412, box.size.x - 28, 52)
			var btn_text: String
			var btn_action: Callable
			var btn_color: Color
			var can_act: bool = true
			if is_selected:
				btn_text = "ĐANG DÙNG [BỎ]"
				btn_color = LED_PURPLE
				btn_action = func(): game.select_drone("")
			elif is_unlocked:
				btn_text = "CHỌN TRANG BỊ"
				btn_color = CYAN
				btn_action = (func(id: String): game.select_drone(id)).bind(d_id)
			else:
				var cost_coins: int = int(drone_info.coin)
				var cost_shards: int = int(drone_info.shard)
				can_act = coins_count >= cost_coins or shards_count >= cost_shards
				btn_text = "MUA %d 🪙" % cost_coins
				btn_color = Color("ffd700") if can_act else MUTED
				btn_action = (func(id: String): game.unlock_drone(id)).bind(d_id)
			
			var act_btn := button(overlay, btn_text, btn_rect, btn_action, can_act, btn_color)
			act_btn.add_theme_font_size_override("font_size", 15)
			act_btn.name = "Armory_DroneCardButton_%s" % d_id
			act_btn.focus_mode = Control.FOCUS_ALL
			if not can_act:
				act_btn.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
				act_btn.modulate = Color(1, 1, 1, 0.5)
			if first_drone_btn == null and can_act:
				first_drone_btn = act_btn
				
		var return_button := armory_return_button()
		if first_drone_btn != null:
			first_drone_btn.grab_focus()
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

func armory_loadout_text(state: int, can_buy_coins: bool = false) -> String:
	match state:
		WeaponLoadoutStateScript.State.AVAILABLE:
			return "CHỌN TRANG BỊ"
		WeaponLoadoutStateScript.State.EQUIPPED:
			return "ĐANG TRANG BỊ"
		WeaponLoadoutStateScript.State.FIXED:
			return "MẶC ĐỊNH"
		_:
			if can_buy_coins:
				return "MUA · 50 🪙"
			return "MỞ KHÓA · 8 MẢNH"


func armory_weapon_details(weapon: Dictionary, index: int, card_position: Vector2, accent: Color) -> Dictionary:
	var stt_rect := Rect2(card_position + Vector2(15, 10), Vector2(34, 17))
	var stt_label := label(overlay, "%02d" % (index + 1), stt_rect, 11, accent, true)
	stt_label.name = "Armory_%s_STT" % weapon.id
	armory_layout_apply_control("%s_stt" % weapon.id, stt_label, stt_rect)
	var model_path := gameplay_weapon_model_path(weapon)
	var model_preview := texture(overlay, model_path, Rect2(card_position + ARMORY_MODEL_PREVIEW_ORIGIN, ARMORY_MODEL_PREVIEW_SIZE))
	model_preview.name = "Armory_%s_GameplayModel" % weapon.id
	model_preview.set_meta("armory_weapon_model_id", str(weapon.id))
	model_preview.set_meta("armory_weapon_model_path", model_path)
	var name_rect := Rect2(card_position + Vector2(92, 18), Vector2(154, 23))
	var name_label := label(overlay, str(weapon.name), name_rect, 15, CYAN, true)
	name_label.name = "Armory_%s_WeaponName" % weapon.id
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	armory_layout_apply_control("%s_name" % weapon.id, name_label, name_rect)
	return {"stt": stt_label, "name": name_label}


func armory_action_rect(card_rect: Rect2) -> Rect2:
	var dock_width := maxf(144.0, card_rect.size.x * 0.60)
	return Rect2(card_rect.position + Vector2(card_rect.size.x - dock_width - 18.0, card_rect.size.y - 39.0), Vector2(dock_width, 30.0))


func armory_weapon_action_button(action_id: String, action_text: String, action_rect: Rect2, action: Callable, can_activate: bool, accent: Color, state_visual) -> Button:
	var target := Button.new()
	target.name = "Armory_%s_ActionButton" % action_id
	target.text = action_text
	target.tooltip_text = action_text
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.disabled = not can_activate
	target.add_theme_font_override("font", bold)
	target.add_theme_font_size_override("font_size", 11)
	var transparent := StyleBoxEmpty.new()
	target.add_theme_stylebox_override("normal", transparent)
	target.add_theme_stylebox_override("disabled", transparent)
	target.add_theme_stylebox_override("hover", transparent)
	target.add_theme_stylebox_override("focus", transparent)
	target.add_theme_stylebox_override("pressed", menu_hitbox_style(accent, 0.08, 1))
	target.add_theme_color_override("font_color", accent)
	target.add_theme_color_override("font_hover_color", accent)
	target.add_theme_color_override("font_pressed_color", accent)
	target.add_theme_color_override("font_focus_color", accent)
	target.add_theme_color_override("font_disabled_color", Color(accent.r, accent.g, accent.b, 0.56))
	target.set_meta("armory_equip_weapon_id", action_id)
	target.set_meta("armory_action_rect", action_rect)
	armory_layout_apply_control("%s_action" % action_id, target, action_rect)
	target.pressed.connect(action)
	target.button_down.connect(func(): state_visual.set_interaction_feedback(true))
	target.button_up.connect(func(): state_visual.set_interaction_feedback(false))
	overlay.add_child(target)
	# Button's theme minimum height can expand a 30px dock when it enters the
	# tree. Restore the authored dock size after that theme pass so the editor
	# resizes the same visible region as the card artwork.
	target.set_deferred("size", action_rect.size)
	if state_visual.state_label != null:
		state_visual.state_label.visible = false
	return target

func armory_weapon_hitbox(action_id: String, weapon_name: String, card_rect: Rect2, action: Callable, can_activate: bool, state_visual) -> Button:
	var target = Button.new()
	target.name = "Armory_%s_Hitbox" % action_id
	target.text = weapon_name
	target.tooltip_text = weapon_name
	target.position = card_rect.position
	target.size = card_rect.size
	target.focus_mode = Control.FOCUS_NONE
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
	target.text = "TRỞ LẠI MENU"
	target.tooltip_text = "Trở lại menu"
	target.position = ARMORY_RETURN_RECT.position
	target.size = ARMORY_RETURN_RECT.size
	target.focus_mode = Control.FOCUS_ALL
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.flat = true
	target.alignment = HORIZONTAL_ALIGNMENT_CENTER
	target.add_theme_font_override("font", bold)
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
