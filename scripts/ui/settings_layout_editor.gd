class_name SettingsLayoutEditor
extends Control

## In-game placement tool for the Settings screen. It owns only the drag
## affordances; the actual settings controls remain children of their normal
## runtime groups. GameUI gates this editor behind the F7 placement mode.

signal group_moved(group_id: String, position: Vector2)
signal group_selected(group_id: String)

var _groups: Dictionary = {}
var _group_order: Array[String] = []
var _font: Font
var _bold_font: Font
var _active: bool = false
var _dragging_group_id: String = ""
var _drag_offset := Vector2.ZERO
var _selected_group_id: String = ""

func configure(entries: Array, regular_font: Font, bold_font: Font) -> void:
	_groups.clear()
	_group_order.clear()
	_font = regular_font
	_bold_font = bold_font
	for entry in entries:
		var group_id := str(entry.get("id", ""))
		var target: Control = entry.get("target")
		if group_id.is_empty() or target == null:
			continue
		_groups[group_id] = {
			"target": target,
			"label": str(entry.get("label", group_id)),
			"accent": entry.get("accent", Color.WHITE),
			"default_position": entry.get("default_position", target.position),
		}
		_group_order.append(group_id)
	queue_redraw()

func set_editor_active(next_active: bool) -> void:
	_active = next_active
	visible = next_active
	mouse_filter = Control.MOUSE_FILTER_STOP if next_active else Control.MOUSE_FILTER_IGNORE
	_dragging_group_id = ""
	queue_redraw()

func is_editor_active() -> bool:
	return _active

func group_position(group_id: String) -> Vector2:
	var target := _target_for(group_id)
	return target.position if target != null else Vector2.ZERO

func reset_layout() -> void:
	for group_id in _group_order:
		var target := _target_for(group_id)
		if target == null:
			continue
		var default_position: Vector2 = _groups[group_id].get("default_position", target.position)
		target.position = default_position
		group_moved.emit(group_id, target.position)
	_selected_group_id = ""
	_dragging_group_id = ""
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _begin_drag(event.position):
				accept_event()
		else:
			if not _dragging_group_id.is_empty():
				_dragging_group_id = ""
				accept_event()
	elif event is InputEventMouseMotion and not _dragging_group_id.is_empty():
		_move_drag(event.position)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _begin_drag(event.position):
				accept_event()
		elif not _dragging_group_id.is_empty():
			_dragging_group_id = ""
			accept_event()
	elif event is InputEventScreenDrag and not _dragging_group_id.is_empty():
		_move_drag(event.position)
		accept_event()

func _begin_drag(pointer: Vector2) -> bool:
	for index in range(_group_order.size() - 1, -1, -1):
		var group_id := _group_order[index]
		var target := _target_for(group_id)
		if target == null:
			continue
		if Rect2(target.position, target.size).grow(8.0).has_point(pointer):
			_dragging_group_id = group_id
			_selected_group_id = group_id
			_drag_offset = pointer - target.position
			group_selected.emit(group_id)
			queue_redraw()
			return true
	return false

func _move_drag(pointer: Vector2) -> void:
	var target := _target_for(_dragging_group_id)
	if target == null:
		_dragging_group_id = ""
		return
	var desired := pointer - _drag_offset
	var maximum := Vector2(maxf(0.0, size.x - target.size.x), maxf(0.0, size.y - target.size.y))
	target.position = Vector2(clampf(desired.x, 0.0, maximum.x), clampf(desired.y, 0.0, maximum.y))
	group_moved.emit(_dragging_group_id, target.position)
	queue_redraw()

func _target_for(group_id: String) -> Control:
	if not _groups.has(group_id):
		return null
	var target: Control = _groups[group_id].get("target")
	return target if target != null and is_instance_valid(target) else null

func _draw() -> void:
	if not _active or _font == null or _bold_font == null:
		return
	for group_id in _group_order:
		var target := _target_for(group_id)
		if target == null:
			continue
		var entry: Dictionary = _groups[group_id]
		var accent: Color = entry.get("accent", Color.WHITE)
		var rect := Rect2(target.position, target.size)
		var selected := group_id == _selected_group_id
		draw_rect(rect.grow(5.0), Color(accent.r, accent.g, accent.b, 0.08 if selected else 0.035), true)
		draw_rect(rect.grow(4.0), Color(accent.r, accent.g, accent.b, 0.96 if selected else 0.62), false, 2.0 if selected else 1.0)
		var label_text := "%s  ·  %d, %d" % [entry.get("label", group_id), roundi(target.position.x), roundi(target.position.y)]
		var label_width := minf(rect.size.x - 16.0, _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0)
		var label_rect := Rect2(rect.position + Vector2(8.0, 8.0), Vector2(maxf(80.0, label_width), 23.0))
		draw_rect(label_rect, Color(0.01, 0.006, 0.028, 0.94), true)
		draw_rect(label_rect, Color(accent.r, accent.g, accent.b, 0.82), false, 1.0)
		draw_string(_bold_font, label_rect.position + Vector2(8.0, 16.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x - 16.0, 13, accent)
	var help_rect := Rect2(28.0, size.y - 36.0, size.x - 56.0, 27.0)
	draw_rect(help_rect, Color(0.008, 0.004, 0.024, 0.92), true)
	draw_rect(help_rect, Color("35e7ff", 0.72), false, 1.0)
	draw_string(_font, help_rect.position + Vector2(12.0, 18.0), "CĂN CHỈNH · kéo 4 khung · F7: lưu và thoát chế độ kéo thả · R: khôi phục vị trí gốc", HORIZONTAL_ALIGNMENT_LEFT, help_rect.size.x - 24.0, 13, Color("e6f7ff"))
