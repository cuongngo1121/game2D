class_name WeaponLoadoutState
extends Control
## A runtime-only state layer for an armory card. The background artwork owns
## the static chassis; this component makes the actionable loadout state clear.

enum State {
	AVAILABLE,
	EQUIPPED,
	FIXED,
	LOCKED,
}

const CYAN := Color("35e7ff")
const LED_PURPLE := Color("d65dff")
const LOCKED := Color("756b91")

var state: int = State.AVAILABLE
var weapon_id := ""
var can_activate := true
var _pressed := false

var state_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_labels()
	_apply_state()

func configure(next_state: int, next_weapon_id: String, next_can_activate: bool) -> void:
	state = next_state
	weapon_id = next_weapon_id
	can_activate = next_can_activate
	_apply_state()

func set_interaction_feedback(next_pressed: bool) -> void:
	if _pressed == next_pressed:
		return
	_pressed = next_pressed
	queue_redraw()

func state_key() -> String:
	match state:
		State.AVAILABLE:
			return "available"
		State.EQUIPPED:
			return "equipped"
		State.FIXED:
			return "fixed"
		_:
			return "locked"

func _create_labels() -> void:
	state_label = Label.new()
	state_label.name = "LoadoutStateText"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.add_theme_font_size_override("font_size", 11)
	add_child(state_label)

func _apply_state() -> void:
	if state_label == null:
		return
	var text_color := _state_color()
	match state:
		State.AVAILABLE:
			state_label.text = "CHỌN TRANG BỊ"
		State.EQUIPPED:
			state_label.text = "ĐANG TRANG BỊ"
		State.FIXED:
			state_label.text = "MẶC ĐỊNH"
		State.LOCKED:
			state_label.text = "MỞ KHÓA · 8 MẢNH"
	state_label.add_theme_color_override("font_color", text_color)
	_layout_labels()
	queue_redraw()

func _layout_labels() -> void:
	var dock := _status_rect()
	state_label.position = Vector2(dock.position.x + 29.0, dock.position.y + 3.0)
	state_label.size = Vector2(dock.size.x - 34.0, 24.0)

func _status_rect() -> Rect2:
	var dock_width := maxf(144.0, size.x * 0.60)
	return Rect2(size.x - dock_width - 18.0, size.y - 39.0, dock_width, 30.0)

func _state_color() -> Color:
	match state:
		State.EQUIPPED:
			return LED_PURPLE
		State.FIXED:
			return CYAN
		State.LOCKED:
			return LOCKED
		_:
			return CYAN

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var card_rect := Rect2(Vector2(6.0, 6.0), size - Vector2(12.0, 12.0))
	var dock := _status_rect()
	var accent := _state_color()
	var fill := Color(accent.r, accent.g, accent.b, 0.08)
	if state == State.EQUIPPED:
		draw_rect(card_rect, Color(LED_PURPLE.r, LED_PURPLE.g, LED_PURPLE.b, 0.09), true)
		draw_line(Vector2(18.0, 8.0), Vector2(size.x - 18.0, 8.0), LED_PURPLE, 1.5, true)
		draw_line(Vector2(10.0, 20.0), Vector2(10.0, size.y - 20.0), Color(LED_PURPLE.r, LED_PURPLE.g, LED_PURPLE.b, 0.82), 1.5, true)
	elif state == State.FIXED:
		draw_line(Vector2(18.0, 8.0), Vector2(size.x - 18.0, 8.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.46), 1.0, true)
	elif state == State.LOCKED:
		fill = Color(LOCKED.r, LOCKED.g, LOCKED.b, 0.05)
	draw_rect(dock, fill, true)
	draw_rect(dock, accent, false, 1.5, true)
	_draw_dock_corners(dock, accent)
	_draw_state_symbol(dock, accent)
	if can_activate and _pressed:
		var feedback_color := Color(accent.r, accent.g, accent.b, 0.92)
		draw_rect(card_rect.grow(-3.0), Color(accent.r, accent.g, accent.b, 0.045), true)
		draw_rect(card_rect.grow(-3.0), feedback_color, false, 1.0, true)

func _draw_dock_corners(dock: Rect2, accent: Color) -> void:
	var inset := 4.0
	var corner := 6.0
	var top_left := dock.position + Vector2(inset, inset)
	var top_right := Vector2(dock.end.x - inset, dock.position.y + inset)
	var bottom_left := Vector2(dock.position.x + inset, dock.end.y - inset)
	var bottom_right := dock.end - Vector2(inset, inset)
	draw_line(top_left, top_left + Vector2(corner, 0.0), accent, 1.0, true)
	draw_line(top_left, top_left + Vector2(0.0, corner), accent, 1.0, true)
	draw_line(top_right, top_right - Vector2(corner, 0.0), accent, 1.0, true)
	draw_line(top_right, top_right + Vector2(0.0, corner), accent, 1.0, true)
	draw_line(bottom_left, bottom_left + Vector2(corner, 0.0), accent, 1.0, true)
	draw_line(bottom_left, bottom_left - Vector2(0.0, corner), accent, 1.0, true)
	draw_line(bottom_right, bottom_right - Vector2(corner, 0.0), accent, 1.0, true)
	draw_line(bottom_right, bottom_right - Vector2(0.0, corner), accent, 1.0, true)

func _draw_state_symbol(dock: Rect2, accent: Color) -> void:
	var center := Vector2(dock.position.x + 16.0, dock.get_center().y)
	match state:
		State.AVAILABLE:
			draw_circle(center, 7.0, Color(accent.r, accent.g, accent.b, 0.14))
			draw_arc(center, 7.0, 0.0, TAU, 16, accent, 1.0, true)
			draw_line(center - Vector2(3.0, 0.0), center + Vector2(3.0, 0.0), accent, 1.5, true)
			draw_line(center - Vector2(0.0, 3.0), center + Vector2(0.0, 3.0), accent, 1.5, true)
		State.EQUIPPED:
			draw_circle(center, 7.0, Color(accent.r, accent.g, accent.b, 0.22))
			draw_arc(center, 7.0, 0.0, TAU, 16, accent, 1.0, true)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(-1.0, 3.0), accent, 1.7, true)
			draw_line(center + Vector2(-1.0, 3.0), center + Vector2(5.0, -4.0), accent, 1.7, true)
		State.FIXED:
			draw_circle(center, 5.0, Color(accent.r, accent.g, accent.b, 0.74))
			draw_circle(center, 2.0, Color("071426"))
		State.LOCKED:
			var body := Rect2(center - Vector2(5.0, 1.0), Vector2(10.0, 8.0))
			draw_rect(body, Color(accent.r, accent.g, accent.b, 0.24), true)
			draw_rect(body, accent, false, 1.0, true)
			draw_arc(center - Vector2(0.0, 1.0), 4.0, PI, TAU, 10, accent, 1.0, true)
