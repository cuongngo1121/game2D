class_name HudLayoutEditor
extends Control

## Debug-only placement surface for the gameplay HUD. Runtime controls stay
## alive underneath it; this layer only changes their parent-group transform.

signal item_changed(item_id: String, position: Vector2, scale: Vector2)
signal item_selected(item_id: String)

const MIN_SCALE := 0.55
const MAX_SCALE := 2.0
const HANDLE_SIZE := 18.0
const DOUBLE_CLICK_WINDOW_MSEC := 450
const DOUBLE_CLICK_DISTANCE := 12.0

var _items: Dictionary = {}
var _item_order: Array[String] = []
var _font: Font
var _bold_font: Font
var _help_text := "CHỈNH HUD · kéo để di chuyển · kéo cạnh/góc để đổi cỡ · kích đúp để chỉnh riêng · kích đúp lại hiện tất cả · F8: lưu · R: mặc định"
var _active: bool = false
var _dragging_item_id: String = ""
var _resizing: bool = false
var _drag_offset := Vector2.ZERO
var _resize_handle: String = ""
var _resize_start_rect := Rect2()
var _resize_pointer_start := Vector2.ZERO
var _selected_item_id: String = ""
var _solo_item_id: String = ""
var _last_click_item_id: String = ""
var _last_click_position := Vector2.ZERO
var _last_click_time_msec: int = -1

func configure(entries: Array, regular_font: Font, bold_font: Font, help_text: String = "") -> void:
	_items.clear()
	_item_order.clear()
	_font = regular_font
	_bold_font = bold_font
	if not help_text.is_empty():
		_help_text = help_text
	for entry: Dictionary in entries:
		var item_id := str(entry.get("id", ""))
		var target: Control = entry.get("target")
		if item_id.is_empty() or target == null:
			continue
		_items[item_id] = {
			"target": target,
			"label": str(entry.get("label", item_id)),
			"accent": entry.get("accent", Color.WHITE),
			"default_position": entry.get("default_position", target.position),
			"default_scale": entry.get("default_scale", Vector2.ONE),
			"global_canvas": bool(entry.get("global_canvas", false)),
		}
		_item_order.append(item_id)
	queue_redraw()

func set_editor_active(next_active: bool) -> void:
	_active = next_active
	visible = next_active
	mouse_filter = Control.MOUSE_FILTER_STOP if next_active else Control.MOUSE_FILTER_IGNORE
	_dragging_item_id = ""
	_resizing = false
	_resize_handle = ""
	_clear_pointer_sequence()
	if not next_active:
		_solo_item_id = ""
		_selected_item_id = ""
	queue_redraw()

func is_editor_active() -> bool:
	return _active

func solo_item_id() -> String:
	return _solo_item_id

func item_position(item_id: String) -> Vector2:
	var target := _target_for(item_id)
	return _item_position(item_id, target) if target != null else Vector2.ZERO

func item_scale(item_id: String) -> Vector2:
	var target := _target_for(item_id)
	return _item_scale(item_id, target) if target != null else Vector2.ONE

func reset_layout() -> void:
	for item_id in _item_order:
		var target := _target_for(item_id)
		if target == null:
			continue
		target.position = _items[item_id].get("default_position", target.position)
		target.scale = _items[item_id].get("default_scale", Vector2.ONE)
		_emit_item_changed(item_id, target)
	_selected_item_id = ""
	_dragging_item_id = ""
	_resizing = false
	_resize_handle = ""
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _handle_pointer_press(event.position):
				accept_event()
		else:
			if not _dragging_item_id.is_empty():
				_dragging_item_id = ""
				_resizing = false
				_resize_handle = ""
				accept_event()
	elif event is InputEventMouseMotion and not _dragging_item_id.is_empty():
		if event.position.distance_to(_last_click_position) > DOUBLE_CLICK_DISTANCE:
			_clear_pointer_sequence()
		_move_pointer(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _handle_pointer_press(event.position):
				accept_event()
		elif not _dragging_item_id.is_empty():
			_dragging_item_id = ""
			_resizing = false
			_resize_handle = ""
			accept_event()
	elif event is InputEventScreenDrag and not _dragging_item_id.is_empty():
		_clear_pointer_sequence()
		_move_pointer(event.position)
		accept_event()

func _handle_pointer_press(pointer: Vector2) -> bool:
	var item_id := _item_at_pointer(pointer)
	if _is_double_click(item_id, pointer):
		_toggle_solo_item(item_id)
		return true
	if item_id.is_empty():
		_clear_pointer_sequence()
	else:
		_last_click_item_id = item_id
		_last_click_position = pointer
		_last_click_time_msec = Time.get_ticks_msec()
	return _begin_pointer(pointer)

func _is_double_click(item_id: String, pointer: Vector2) -> bool:
	if item_id.is_empty() or _last_click_item_id != item_id or _last_click_time_msec < 0:
		return false
	var elapsed_msec: int = Time.get_ticks_msec() - _last_click_time_msec
	return elapsed_msec >= 0 and elapsed_msec <= DOUBLE_CLICK_WINDOW_MSEC and pointer.distance_to(_last_click_position) <= DOUBLE_CLICK_DISTANCE

func _clear_pointer_sequence() -> void:
	_last_click_item_id = ""
	_last_click_position = Vector2.ZERO
	_last_click_time_msec = -1

func _toggle_solo_item(item_id: String) -> void:
	if item_id.is_empty():
		return
	if _solo_item_id == item_id:
		_solo_item_id = ""
		_selected_item_id = ""
	else:
		_solo_item_id = item_id
		_selected_item_id = item_id
	_dragging_item_id = ""
	_resizing = false
	_resize_handle = ""
	_clear_pointer_sequence()
	item_selected.emit(item_id)
	queue_redraw()

func _begin_pointer(pointer: Vector2) -> bool:
	# Resize handles have priority over another item's body when two HUD frames
	# touch. This keeps the lower-right corner reliable even in dense layouts.
	for index in range(_item_order.size() - 1, -1, -1):
		var item_id := _item_order[index]
		if not _can_edit_item(item_id):
			continue
		var target := _target_for(item_id)
		if target == null:
			continue
		var rect := _item_rect(item_id, target)
		var resize_handle := _resize_handle_for_rect(rect, pointer)
		if not resize_handle.is_empty():
			_dragging_item_id = item_id
			_resizing = true
			_resize_handle = resize_handle
			_resize_start_rect = rect
			_resize_pointer_start = pointer
			_selected_item_id = item_id
			item_selected.emit(item_id)
			queue_redraw()
			return true
	for index in range(_item_order.size() - 1, -1, -1):
		var item_id := _item_order[index]
		if not _can_edit_item(item_id):
			continue
		var target := _target_for(item_id)
		if target == null:
			continue
		var rect := _item_rect(item_id, target)
		if rect.grow(8.0).has_point(pointer):
			_dragging_item_id = item_id
			_resizing = false
			_drag_offset = pointer - _item_position(item_id, target)
			_selected_item_id = item_id
			item_selected.emit(item_id)
			queue_redraw()
			return true
	return false

func _can_edit_item(item_id: String) -> bool:
	return _solo_item_id.is_empty() or _solo_item_id == item_id

func _item_at_pointer(pointer: Vector2) -> String:
	for index in range(_item_order.size() - 1, -1, -1):
		var item_id := _item_order[index]
		var target := _target_for(item_id)
		if target == null:
			continue
		if _item_rect(item_id, target).grow(8.0).has_point(pointer):
			return item_id
	return ""

func _move_pointer(pointer: Vector2) -> void:
	var target := _target_for(_dragging_item_id)
	if target == null:
		_dragging_item_id = ""
		_resizing = false
		return
	if _resizing:
		_resize_target(_dragging_item_id, target, pointer)
	else:
		var desired_position := pointer - _drag_offset
		var visual_size := target.size * _item_scale(_dragging_item_id, target)
		var maximum_position := Vector2(maxf(0.0, size.x - visual_size.x), maxf(0.0, size.y - visual_size.y))
		_set_item_position(_dragging_item_id, target, Vector2(clampf(desired_position.x, 0.0, maximum_position.x), clampf(desired_position.y, 0.0, maximum_position.y)))
	_emit_item_changed(_dragging_item_id, target)
	queue_redraw()

func _resize_target(item_id: String, target: Control, pointer: Vector2) -> void:
	var delta := pointer - _resize_pointer_start
	var start_rect := _resize_start_rect
	var next_rect := start_rect
	var parent_global_scale := _parent_global_scale_for(target) if _uses_global_canvas(item_id) else Vector2.ONE
	var minimum_size := target.size * MIN_SCALE * parent_global_scale
	var maximum_size := target.size * MAX_SCALE * parent_global_scale
	var max_horizontal := maxf(minimum_size.x, minf(maximum_size.x, size.x - start_rect.position.x))
	var max_vertical := maxf(minimum_size.y, minf(maximum_size.y, size.y - start_rect.position.y))

	if _resize_handle.contains("e"):
		next_rect.size.x = clampf(start_rect.size.x + delta.x, minimum_size.x, max_horizontal)
	elif _resize_handle.contains("w"):
		var left_min := maxf(0.0, start_rect.end.x - maximum_size.x)
		var left_max := start_rect.end.x - minimum_size.x
		next_rect.position.x = clampf(start_rect.position.x + delta.x, left_min, left_max)
		next_rect.size.x = start_rect.end.x - next_rect.position.x

	if _resize_handle.contains("s"):
		next_rect.size.y = clampf(start_rect.size.y + delta.y, minimum_size.y, max_vertical)
	elif _resize_handle.contains("n"):
		var top_min := maxf(0.0, start_rect.end.y - maximum_size.y)
		var top_max := start_rect.end.y - minimum_size.y
		next_rect.position.y = clampf(start_rect.position.y + delta.y, top_min, top_max)
		next_rect.size.y = start_rect.end.y - next_rect.position.y

	_set_item_position(item_id, target, next_rect.position)
	_set_item_scale(item_id, target, Vector2(
		clampf(next_rect.size.x / maxf(1.0, target.size.x), MIN_SCALE * parent_global_scale.x, MAX_SCALE * parent_global_scale.x),
		clampf(next_rect.size.y / maxf(1.0, target.size.y), MIN_SCALE * parent_global_scale.y, MAX_SCALE * parent_global_scale.y)))

func _target_for(item_id: String) -> Control:
	if not _items.has(item_id):
		return null
	var target: Control = _items[item_id].get("target")
	return target if target != null and is_instance_valid(target) else null

func _uses_global_canvas(item_id: String) -> bool:
	return _items.has(item_id) and bool(_items[item_id].get("global_canvas", false))

func _item_position(item_id: String, target: Control) -> Vector2:
	return target.global_position if _uses_global_canvas(item_id) else target.position

func _item_scale(item_id: String, target: Control) -> Vector2:
	return _global_scale_for(target) if _uses_global_canvas(item_id) else target.scale

func _set_item_position(item_id: String, target: Control, position: Vector2) -> void:
	if _uses_global_canvas(item_id):
		target.global_position = position
	else:
		target.position = position

func _set_item_scale(item_id: String, target: Control, scale: Vector2) -> void:
	if not _uses_global_canvas(item_id):
		target.scale = scale
		return
	var parent_global_scale := _parent_global_scale_for(target)
	target.scale = Vector2(
		scale.x / maxf(0.001, parent_global_scale.x),
		scale.y / maxf(0.001, parent_global_scale.y))

func _global_scale_for(target: Control) -> Vector2:
	return target.get_global_transform_with_canvas().get_scale()

func _parent_global_scale_for(target: Control) -> Vector2:
	var parent := target.get_parent() as Control
	return parent.get_global_transform_with_canvas().get_scale() if parent != null else Vector2.ONE

func _emit_item_changed(item_id: String, target: Control) -> void:
	item_changed.emit(item_id, target.position, target.scale)

func _item_rect(item_id: String, target: Control) -> Rect2:
	return Rect2(_item_position(item_id, target), target.size * _item_scale(item_id, target))

func _resize_handle_for_rect(rect: Rect2, pointer: Vector2) -> String:
	if not rect.grow(2.0).has_point(pointer):
		return ""
	# Thin resource bars must retain a usable body area. Scale the hit bands
	# down for their small height instead of letting an 18px handle cover them.
	var half_x := minf(HANDLE_SIZE * 0.5, maxf(5.0, rect.size.x * 0.2))
	var half_y := minf(HANDLE_SIZE * 0.5, maxf(3.0, rect.size.y * 0.35))
	var near_left := absf(pointer.x - rect.position.x) <= half_x
	var near_right := absf(pointer.x - rect.end.x) <= half_x
	var near_top := absf(pointer.y - rect.position.y) <= half_y
	var near_bottom := absf(pointer.y - rect.end.y) <= half_y
	if near_left and near_top:
		return "nw"
	if near_right and near_top:
		return "ne"
	if near_right and near_bottom:
		return "se"
	if near_left and near_bottom:
		return "sw"
	if near_top:
		return "n"
	if near_right:
		return "e"
	if near_bottom:
		return "s"
	if near_left:
		return "w"
	return ""

func _resize_handle_rects(rect: Rect2) -> Array[Rect2]:
	var half := HANDLE_SIZE * 0.5
	var centers := [
		rect.position,
		Vector2(rect.get_center().x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, rect.get_center().y),
		rect.end,
		Vector2(rect.get_center().x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.position.x, rect.get_center().y),
	]
	var handles: Array[Rect2] = []
	for center: Vector2 in centers:
		handles.append(Rect2(center - Vector2(half, half), Vector2(HANDLE_SIZE, HANDLE_SIZE)))
	return handles

func _draw() -> void:
	if not _active or _font == null or _bold_font == null:
		return
	for item_id in _item_order:
		if not _solo_item_id.is_empty() and item_id != _solo_item_id:
			continue
		var target := _target_for(item_id)
		if target == null:
			continue
		var entry: Dictionary = _items[item_id]
		var accent: Color = entry.get("accent", Color.WHITE)
		var rect := _item_rect(item_id, target)
		var selected := item_id == _selected_item_id
		draw_rect(rect.grow(6.0), Color(accent.r, accent.g, accent.b, 0.10 if selected else 0.035), true)
		draw_rect(rect.grow(4.0), Color(accent.r, accent.g, accent.b, 0.96 if selected else 0.64), false, 2.0 if selected else 1.0)
		for handle: Rect2 in _resize_handle_rects(rect):
			draw_rect(handle, Color(accent.r, accent.g, accent.b, 0.32 if selected else 0.16), true)
			draw_rect(handle, Color(accent.r, accent.g, accent.b, 0.82), false, 1.0)
		var rendered_size := target.size * _item_scale(item_id, target)
		var item_position := _item_position(item_id, target)
		var item_scale := _item_scale(item_id, target)
		var label_text := "%s · %d,%d · %d×%d px · %.0f%% × %.0f%%" % [entry.get("label", item_id), roundi(item_position.x), roundi(item_position.y), roundi(rendered_size.x), roundi(rendered_size.y), item_scale.x * 100.0, item_scale.y * 100.0]
		var label_text_width := _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
		var available_width := maxf(120.0, size.x - rect.position.x - 8.0)
		var label_width := minf(maxf(120.0, label_text_width), available_width)
		var label_rect := Rect2(rect.position + Vector2(8.0, 8.0), Vector2(label_width, 22.0))
		draw_rect(label_rect, Color(0.01, 0.006, 0.028, 0.94), true)
		draw_rect(label_rect, Color(accent.r, accent.g, accent.b, 0.82), false, 1.0)
		draw_string(_bold_font, label_rect.position + Vector2(8.0, 15.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - 16.0, 12, accent)
	var help_rect := Rect2(24.0, size.y - 38.0, size.x - 48.0, 29.0)
	draw_rect(help_rect, Color(0.008, 0.004, 0.024, 0.94), true)
	draw_rect(help_rect, Color("35e7ff", 0.72), false, 1.0)
	draw_string(_font, help_rect.position + Vector2(12.0, 19.0), _help_text, HORIZONTAL_ALIGNMENT_LEFT, help_rect.size.x - 24.0, 13, Color("e6f7ff"))
