class_name MapBoundaryEditor
extends Control
## PC development overlay for tracing the actual walkable floor over a route-map art plate.
## It edits native background-image pixels, then writes the same data collision uses.

const LevelOneBoundaryData = preload("res://scripts/world/level_one_boundary_data.gd")
const LevelTwoBoundaryData = preload("res://scripts/world/level_two_boundary_data.gd")
const LevelThreeBoundaryData = preload("res://scripts/world/level_three_boundary_data.gd")
const LevelFourBoundaryData = preload("res://scripts/world/level_four_boundary_data.gd")
const LevelFiveBoundaryData = preload("res://scripts/world/level_five_boundary_data.gd")
const CorridorBarrierData = preload("res://scripts/world/corridor_barrier_data.gd")
const LEVEL_ONE_BACKGROUND: Texture2D = preload("res://assets/backgrounds/echo_terminal_route_background.png")
const LEVEL_TWO_BACKGROUND: Texture2D = preload("res://assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry_tiled_restored_hd.png")
const LEVEL_THREE_BACKGROUND: Texture2D = preload("res://assets/backgrounds/luminous_grove_route_background_user_final_fixed_hd_v29.png")
const LEVEL_FOUR_BACKGROUND: Texture2D = preload("res://assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png")
const LEVEL_FIVE_BACKGROUND: Texture2D = preload("res://assets/backgrounds/silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png")
const SNAP_STEPS := [2, 4, 8, 16, 32]
const DEFAULT_SNAP_STEP := 8
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0
const TOP_BAR_HEIGHT := 96.0
const BOTTOM_BAR_HEIGHT := 64.0

var game
var active := false
var previous_state := ""
var previous_hud_visible := false
var working_polygons: Dictionary = {}
var opened_snapshot: Dictionary = {}
var working_barriers: Array[Dictionary] = []
var opened_barriers_snapshot: Array[Dictionary] = []
var selected_room := 0
var selected_vertex := -1
var dragging_vertex := false
var dragging_barrier := false
var barrier_drag_start_art := Vector2.ZERO
var barrier_preview := Rect2()
var edit_mode := "boundary"
var panning := false
var pan_start_screen := Vector2.ZERO
var pan_start_center_art := Vector2.ZERO
var dirty := false
var status := ""
var map_rect := Rect2()
var snap_step := DEFAULT_SNAP_STEP
var zoom_scale := 1.0
var view_center_art := Vector2.ZERO
var toolbar_actions: Array[Dictionary] = []
var pending_action := ""
var pending_action_until := 0
var boundary_data
var background: Texture2D
var edited_stage := -1

func setup(owner_game) -> void:
	game = owner_game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL
	visible = false

func _select_route_source() -> void:
	var source_changed: bool = edited_stage != game.stage_index
	edited_stage = game.stage_index
	match edited_stage:
		0:
			boundary_data = LevelOneBoundaryData
			background = LEVEL_ONE_BACKGROUND
		1:
			boundary_data = LevelTwoBoundaryData
			background = LEVEL_TWO_BACKGROUND
		2:
			boundary_data = LevelThreeBoundaryData
			background = LEVEL_THREE_BACKGROUND
		3:
			boundary_data = LevelFourBoundaryData
			background = LEVEL_FOUR_BACKGROUND
		4:
			boundary_data = LevelFiveBoundaryData
			background = LEVEL_FIVE_BACKGROUND
		_:
			boundary_data = LevelOneBoundaryData
			background = LEVEL_ONE_BACKGROUND
	if source_changed or view_center_art == Vector2.ZERO:
		selected_room = 0
		selected_vertex = -1
		zoom_scale = 1.0
		view_center_art = boundary_data.ART_SIZE * 0.5

func open() -> void:
	if active or game == null or not game.is_open_route_stage():
		return
	_select_route_source()
	active = true
	visible = true
	previous_state = game.state
	previous_hud_visible = game.ui.hud.visible
	working_polygons = boundary_data.duplicate_room_art_polygons(game.route_art_polygons())
	opened_snapshot = boundary_data.duplicate_room_art_polygons(game.route_art_polygons())
	game.ensure_route_combat_barriers()
	working_barriers = CorridorBarrierData.duplicate_stage_art_barriers(game.route_barriers_art)
	opened_barriers_snapshot = CorridorBarrierData.duplicate_stage_art_barriers(game.route_barriers_art)
	selected_vertex = -1
	dragging_vertex = false
	dragging_barrier = false
	barrier_preview = Rect2()
	panning = false
	dirty = false
	# Keep the developer's last tracing settings when F6 closes and reopens the
	# overlay. `reset_view()` remains the deliberate way to return to 1:1.
	pending_action = ""
	status = "Chọn phòng, rồi bám từng đỉnh theo mép sàn sáng của ảnh nền. Nhấn B để đặt Rào chiến đấu."
	game.state = "boundary_editing"
	game.controls.reset()
	game.ui.hud.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	grab_focus()
	queue_redraw()

func request_close() -> void:
	if not active:
		return
	if dirty:
		if not _confirm("close"):
			return
		game.apply_route_boundary_polygons(opened_snapshot)
		game.apply_route_combat_barriers(opened_barriers_snapshot)
		status = "Đã bỏ các thay đổi chưa lưu."
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.state = previous_state
	game.ui.hud.visible = previous_hud_visible
	game.controls.reset()

func handle_key(event: InputEventKey) -> bool:
	if not active or not event.pressed or event.echo:
		return false
	match event.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			selected_room = event.physical_keycode - KEY_1
			selected_vertex = -1
			pending_action = ""
			status = _selected_room_status()
			queue_redraw()
			return true
		KEY_B:
			toggle_edit_mode()
			return true
		KEY_S:
			save()
			return true
		KEY_Z, KEY_BACKSPACE:
			if is_barrier_mode():
				undo_last_barrier()
			else:
				undo_last_vertex()
			return true
		KEY_LEFT:
			if not is_barrier_mode():
				nudge_selected_vertex(Vector2.LEFT, event.shift_pressed)
			return true
		KEY_RIGHT:
			if not is_barrier_mode():
				nudge_selected_vertex(Vector2.RIGHT, event.shift_pressed)
			return true
		KEY_UP:
			if not is_barrier_mode():
				nudge_selected_vertex(Vector2.UP, event.shift_pressed)
			return true
		KEY_DOWN:
			if not is_barrier_mode():
				nudge_selected_vertex(Vector2.DOWN, event.shift_pressed)
			return true
		KEY_G:
			adjust_snap_step(1)
			return true
		KEY_MINUS:
			zoom_at(map_rect.get_center(), 0.8)
			return true
		KEY_EQUAL:
			zoom_at(map_rect.get_center(), 1.25)
			return true
		KEY_0:
			reset_view()
			return true
		KEY_R:
			if is_barrier_mode():
				status = "Rào dùng kéo chuột để đặt; C×2 để bỏ các rào gắn với phòng đang chọn."
				queue_redraw()
			else:
				reset_selected_room()
			return true
		KEY_C:
			if is_barrier_mode():
				clear_selected_room_barriers()
			else:
				clear_selected_room()
			return true
		KEY_ESCAPE:
			request_close()
			return true
	return false

func set_snap_step(next_step: int) -> void:
	if not SNAP_STEPS.has(next_step):
		return
	snap_step = next_step
	status = "Lưới snap: %d px. Điểm mới, kéo chuột và phím mũi tên đều dùng bước này." % snap_step
	queue_redraw()

func adjust_snap_step(direction: int) -> void:
	var current_index := SNAP_STEPS.find(snap_step)
	current_index = clampi(current_index + direction, 0, SNAP_STEPS.size() - 1)
	set_snap_step(SNAP_STEPS[current_index])

func nudge_selected_vertex(direction: Vector2, accelerated: bool = false) -> void:
	var polygon: PackedVector2Array = working_polygons[selected_room]
	if selected_vertex < 0 or selected_vertex >= polygon.size():
		status = "Bấm vào một chấm vàng trước, rồi dùng mũi tên để dịch ±%d px." % snap_step
		queue_redraw()
		return
	var multiplier := 4.0 if accelerated else 1.0
	_set_selected_vertex_art(polygon[selected_vertex] + direction * snap_step * multiplier)
	var moved_polygon: PackedVector2Array = working_polygons[selected_room]
	var acceleration_suffix := " ×4" if accelerated else ""
	status = "Đỉnh %d: (%d, %d) · dịch %d px%s." % [selected_vertex + 1, moved_polygon[selected_vertex].x, moved_polygon[selected_vertex].y, snap_step, acceleration_suffix]
	queue_redraw()

func reset_view() -> void:
	zoom_scale = 1.0
	view_center_art = boundary_data.ART_SIZE * 0.5
	status = "Đã đưa ảnh về khung nhìn 100%."
	queue_redraw()

func zoom_at(screen_point: Vector2, multiplier: float) -> void:
	if map_rect.size.x <= 0 or map_rect.size.y <= 0:
		return
	var art_under_cursor := _screen_to_art_raw(screen_point)
	zoom_scale = clampf(zoom_scale * multiplier, MIN_ZOOM, MAX_ZOOM)
	var visible_size := _visible_art_rect().size
	var normalised := (screen_point - map_rect.position) / map_rect.size
	view_center_art = art_under_cursor - normalised * visible_size + visible_size * 0.5
	_clamp_view_center()
	status = "Zoom %d%% · lưới %d px." % [roundi(zoom_scale * 100.0), snap_step]
	queue_redraw()

func pan_to(screen_point: Vector2) -> void:
	if not panning:
		return
	var screen_delta := screen_point - pan_start_screen
	var visible_size := _visible_art_rect().size
	view_center_art = pan_start_center_art - Vector2(screen_delta.x / map_rect.size.x * visible_size.x, screen_delta.y / map_rect.size.y * visible_size.y)
	_clamp_view_center()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _activate_toolbar(event.position):
					accept_event()
					return
				if map_rect.has_point(event.position):
					if is_barrier_mode():
						begin_barrier_draw(event.position)
					else:
						begin_vertex_edit(event.position)
					accept_event()
			else:
				if dragging_barrier:
					finish_barrier_draw()
				dragging_vertex = false
				accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed and map_rect.has_point(event.position):
				panning = true
				pan_start_screen = event.position
				pan_start_center_art = view_center_art
				status = "Đang kéo khung nhìn. Lăn chuột để zoom quanh vị trí con trỏ."
			elif not event.pressed:
				panning = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if map_rect.has_point(event.position):
				if is_barrier_mode():
					remove_barrier_at(event.position)
				else:
					undo_last_vertex()
				accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if map_rect.has_point(event.position):
				zoom_at(event.position, 1.25)
				accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if map_rect.has_point(event.position):
				zoom_at(event.position, 0.8)
				accept_event()
	elif event is InputEventMouseMotion:
		if dragging_barrier and map_rect.has_point(event.position):
			update_barrier_preview(event.position)
		elif dragging_vertex and map_rect.has_point(event.position):
			move_selected_vertex(event.position)
		elif panning:
			pan_to(event.position)
		if dragging_barrier or dragging_vertex or panning:
			accept_event()

func begin_vertex_edit(screen_point: Vector2) -> void:
	var polygon: PackedVector2Array = working_polygons[selected_room]
	var nearest := _nearest_vertex(screen_point, polygon)
	if nearest >= 0:
		selected_vertex = nearest
		dragging_vertex = true
		status = "Kéo đỉnh %d của %s." % [nearest + 1, boundary_data.ROOM_NAMES[selected_room]]
		queue_redraw()
		return
	polygon.append(_screen_to_art(screen_point))
	working_polygons[selected_room] = polygon
	selected_vertex = polygon.size() - 1
	dirty = true
	pending_action = ""
	status = "Đã thêm đỉnh %d. Nhấn S để kiểm tra và lưu." % polygon.size()
	queue_redraw()

func begin_barrier_draw(screen_point: Vector2) -> void:
	barrier_drag_start_art = _screen_to_art(screen_point)
	barrier_preview = Rect2(barrier_drag_start_art, Vector2.ZERO)
	dragging_barrier = true
	pending_action = ""
	status = "Kéo một thanh mảnh băng ngang hành lang; cửa nối sẽ tự gắn với cả hai phòng kề."
	queue_redraw()

func update_barrier_preview(screen_point: Vector2) -> void:
	var end_art := _screen_to_art(screen_point)
	barrier_preview = _normalised_art_rect(barrier_drag_start_art, end_art)
	queue_redraw()

func finish_barrier_draw() -> void:
	if not dragging_barrier:
		return
	dragging_barrier = false
	var gate := barrier_preview
	barrier_preview = Rect2()
	# `_normalised_art_rect()` adds a fixed technical thickness to a line.  Test
	# the authored long axis rather than `max(size)`, otherwise a click with no
	# drag could be mistaken for a twelve-pixel-long barrier.
	var gate_length := gate.size.x if is_equal_approx(gate.size.y, CorridorBarrierData.DEFAULT_GATE_THICKNESS) else gate.size.y
	if gate_length < CorridorBarrierData.MIN_GATE_SIDE:
		status = "Chưa đặt rào: hãy kéo thanh dài tối thiểu %d px." % CorridorBarrierData.MIN_GATE_SIDE
		queue_redraw()
		return
	var rooms := _rooms_for_new_barrier(gate)
	working_barriers.append({"rooms": rooms, "rect": gate})
	dirty = true
	pending_action = ""
	status = "Đã đặt rào cho %s. Nhấn S để lưu; khi phòng còn quái rào sẽ hiện." % _room_list_label(rooms)
	queue_redraw()

func _normalised_art_rect(first: Vector2, second: Vector2) -> Rect2:
	# Barrier mode authors a line, not a filled box.  Convert the dominant drag
	# axis into a narrow technical rectangle so the existing save/selection format
	# remains valid, while a perfectly horizontal or vertical drag still works.
	var delta := second - first
	var thickness := CorridorBarrierData.DEFAULT_GATE_THICKNESS
	var gate: Rect2
	if absf(delta.x) >= absf(delta.y):
		gate = Rect2(
			Vector2(minf(first.x, second.x), first.y - thickness * 0.5),
			Vector2(absf(delta.x), thickness)
		)
	else:
		gate = Rect2(
			Vector2(first.x - thickness * 0.5, minf(first.y, second.y)),
			Vector2(thickness, absf(delta.y))
		)
	var art_size: Vector2 = boundary_data.ART_SIZE
	gate.position = Vector2(
		clampf(gate.position.x, 0.0, art_size.x - gate.size.x),
		clampf(gate.position.y, 0.0, art_size.y - gate.size.y)
	)
	return gate

func _rooms_for_new_barrier(gate: Rect2) -> Array[int]:
	# A gate sits over an edge, where a centre point may belong to neither room
	# (or only one of them).  Link every polygon the technical strip overlaps so
	# a single drawn bar closes the two rooms on either side of a doorway.
	var rooms: Array[int] = []
	var gate_polygon := PackedVector2Array([
		gate.position,
		Vector2(gate.end.x, gate.position.y),
		gate.end,
		Vector2(gate.position.x, gate.end.y),
	])
	for room in range(boundary_data.ROOM_COUNT):
		var polygon: PackedVector2Array = working_polygons.get(room, PackedVector2Array())
		if polygon.size() >= 3 and not Geometry2D.intersect_polygons(gate_polygon, polygon).is_empty():
			rooms.append(room)
	# Preserve the old authoring fallback for a deliberately decorative gate in
	# empty space, but never add the selected room when the bar clearly overlaps
	# one or more other room polygons.
	if rooms.is_empty():
		rooms.append(selected_room)
	rooms.sort()
	return rooms

func undo_last_barrier() -> void:
	for index in range(working_barriers.size() - 1, -1, -1):
		var rooms: Array = working_barriers[index].get("rooms", [])
		if not rooms.has(selected_room):
			continue
		working_barriers.remove_at(index)
		dirty = true
		pending_action = ""
		status = "Đã bỏ rào cuối gắn với %s." % boundary_data.ROOM_NAMES[selected_room]
		queue_redraw()
		return
	status = "%s chưa có rào để bỏ." % boundary_data.ROOM_NAMES[selected_room]
	queue_redraw()

func remove_barrier_at(screen_point: Vector2) -> void:
	var art_point := _screen_to_art(screen_point)
	for index in range(working_barriers.size() - 1, -1, -1):
		var gate: Rect2 = working_barriers[index].get("rect", Rect2())
		if not gate.grow(maxf(4.0, snap_step * 0.5)).has_point(art_point):
			continue
		working_barriers.remove_at(index)
		dirty = true
		pending_action = ""
		status = "Đã xóa rào dưới con trỏ. Nhấn S để lưu."
		queue_redraw()
		return
	status = "Không có rào tại vị trí chuột."
	queue_redraw()

func move_selected_vertex(screen_point: Vector2) -> void:
	_set_selected_vertex_art(_screen_to_art(screen_point))
	status = "Đã di chuyển đỉnh %d theo lưới %d px. Nhấn S để kiểm tra và lưu." % [selected_vertex + 1, snap_step]
	queue_redraw()

func _set_selected_vertex_art(art_point: Vector2) -> void:
	var polygon: PackedVector2Array = working_polygons[selected_room]
	if selected_vertex < 0 or selected_vertex >= polygon.size():
		return
	polygon[selected_vertex] = snap_art_point(art_point)
	working_polygons[selected_room] = polygon
	dirty = true
	pending_action = ""

func undo_last_vertex() -> void:
	var polygon: PackedVector2Array = working_polygons[selected_room]
	if polygon.is_empty():
		status = "%s chưa có đỉnh để bỏ." % boundary_data.ROOM_NAMES[selected_room]
		queue_redraw()
		return
	polygon.remove_at(polygon.size() - 1)
	working_polygons[selected_room] = polygon
	dirty = true
	pending_action = ""
	status = "Đã bỏ đỉnh cuối. %s còn %d đỉnh." % [boundary_data.ROOM_NAMES[selected_room], polygon.size()]
	queue_redraw()

func reset_selected_room() -> void:
	if not _confirm("reset"):
		return
	var defaults: Dictionary = boundary_data.default_room_art_polygons()
	working_polygons[selected_room] = defaults[selected_room]
	selected_vertex = -1
	dirty = true
	status = "Đã khôi phục mẫu ban đầu cho %s. Nhấn S để lưu." % boundary_data.ROOM_NAMES[selected_room]
	queue_redraw()

func clear_selected_room() -> void:
	if not _confirm("clear"):
		return
	working_polygons[selected_room] = PackedVector2Array()
	selected_vertex = -1
	dirty = true
	status = "Đã xóa các đỉnh của %s. Bấm trái trên ảnh để vẽ lại từ đầu." % boundary_data.ROOM_NAMES[selected_room]
	queue_redraw()

func clear_selected_room_barriers() -> void:
	if not _confirm("clear_barriers"):
		return
	var retained: Array[Dictionary] = []
	var changed := false
	for barrier in working_barriers:
		var rooms: Array = barrier.get("rooms", [])
		if not rooms.has(selected_room):
			retained.append(barrier)
			continue
		changed = true
		var retained_rooms: Array[int] = []
		for room in rooms:
			if int(room) != selected_room:
				retained_rooms.append(int(room))
		if not retained_rooms.is_empty():
			retained.append({"rooms": retained_rooms, "rect": barrier.get("rect", Rect2())})
	working_barriers = retained
	if changed:
		dirty = true
		status = "Đã bỏ liên kết rào của %s; rào chung vẫn giữ cho phòng kề bên." % boundary_data.ROOM_NAMES[selected_room]
	else:
		status = "%s chưa có rào để xóa." % boundary_data.ROOM_NAMES[selected_room]
	queue_redraw()

func save() -> void:
	var validation: Dictionary = boundary_data.validate_room_art_polygons(working_polygons)
	if not validation.get("ok", false):
		status = "Chưa lưu: %s" % validation.get("message", "polygon không hợp lệ.")
		queue_redraw()
		return
	var barrier_validation: Dictionary = CorridorBarrierData.validate_stage_art_barriers(working_barriers, boundary_data.ART_SIZE)
	if not barrier_validation.get("ok", false):
		status = "Chưa lưu: %s" % barrier_validation.get("message", "rào hành lang không hợp lệ.")
		queue_redraw()
		return
	var barrier_result: Dictionary = CorridorBarrierData.save_stage_art_barriers(edited_stage, working_barriers, boundary_data.ART_SIZE)
	if not barrier_result.get("ok", false):
		status = str(barrier_result.get("message", "Không thể lưu rào hành lang."))
		queue_redraw()
		return
	var result: Dictionary = boundary_data.save_room_art_polygons(working_polygons)
	status = str(result.get("message", "Không rõ trạng thái lưu.")) + " · " + str(barrier_result.get("message", ""))
	if result.get("ok", false):
		game.apply_route_boundary_polygons(working_polygons)
		game.apply_route_combat_barriers(working_barriers)
		opened_snapshot = boundary_data.duplicate_room_art_polygons(working_polygons)
		opened_barriers_snapshot = CorridorBarrierData.duplicate_stage_art_barriers(working_barriers)
		dirty = false
		pending_action = ""
	queue_redraw()

func _confirm(action: String) -> bool:
	var now := Time.get_ticks_msec()
	if pending_action == action and now <= pending_action_until:
		pending_action = ""
		return true
	pending_action = action
	pending_action_until = now + 2500
	match action:
		"reset": status = "Nhấn R hoặc KHÔI PHỤC lần nữa trong 2,5 giây để thay polygon phòng này bằng mẫu ban đầu."
		"clear": status = "Nhấn C hoặc XÓA PHÒNG lần nữa trong 2,5 giây để xóa toàn bộ đỉnh phòng này."
		"clear_barriers": status = "Nhấn C hoặc XÓA RÀO lần nữa trong 2,5 giây để bỏ các rào gắn với phòng này."
		"close": status = "Có thay đổi chưa lưu. Nhấn ĐÓNG/Esc lần nữa trong 2,5 giây để bỏ thay đổi và thoát."
	queue_redraw()
	return false

func _activate_toolbar(point: Vector2) -> bool:
	for target in toolbar_actions:
		if Rect2(target.rect).has_point(point):
			match str(target.action):
				"room":
					selected_room = int(target.room)
					selected_vertex = -1
					pending_action = ""
					status = _selected_room_status()
				"mode": toggle_edit_mode()
				"save": save()
				"reset": reset_selected_room()
				"clear": clear_selected_room()
				"clear_barriers": clear_selected_room_barriers()
				"snap_down": adjust_snap_step(-1)
				"snap_up": adjust_snap_step(1)
				"zoom_out": zoom_at(map_rect.get_center(), 0.8)
				"zoom_in": zoom_at(map_rect.get_center(), 1.25)
				"zoom_reset": reset_view()
				"close": request_close()
			queue_redraw()
			return true
	return false

func is_barrier_mode() -> bool:
	return edit_mode == "barrier"

func toggle_edit_mode() -> void:
	edit_mode = "boundary" if is_barrier_mode() else "barrier"
	selected_vertex = -1
	dragging_vertex = false
	dragging_barrier = false
	barrier_preview = Rect2()
	pending_action = ""
	if is_barrier_mode():
		status = "CHẾ ĐỘ RÀO: Chọn phòng, rồi kéo chuột trái băng ngang hành lang. Rào ở cửa nối sẽ tự gắn với hai phòng."
	else:
		status = "CHẾ ĐỘ RANH GIỚI: Kéo đỉnh theo mép sàn sáng; rào hành lang giữ nguyên."
	queue_redraw()

func _selected_room_status() -> String:
	if is_barrier_mode():
		return "Đặt rào cho %s. Kéo chuột trái qua hành lang; chuột phải xóa rào." % boundary_data.ROOM_NAMES[selected_room]
	return "Đang sửa %s." % boundary_data.ROOM_NAMES[selected_room]

func _room_list_label(rooms: Array) -> String:
	var labels: Array[String] = []
	for room in rooms:
		var room_index := int(room)
		if room_index >= 0 and room_index < boundary_data.ROOM_NAMES.size():
			labels.append(boundary_data.ROOM_NAMES[room_index])
	return " / ".join(labels)

func _nearest_vertex(screen_point: Vector2, polygon: PackedVector2Array) -> int:
	var threshold := 15.0
	var best := -1
	var best_distance := threshold
	for index in range(polygon.size()):
		var distance := _art_to_screen(polygon[index]).distance_to(screen_point)
		if distance <= best_distance:
			best = index
			best_distance = distance
	return best

func _screen_to_art(screen_point: Vector2) -> Vector2:
	return snap_art_point(_screen_to_art_raw(screen_point))

func _screen_to_art_raw(screen_point: Vector2) -> Vector2:
	var normalised := (screen_point - map_rect.position) / map_rect.size
	var visible_art := _visible_art_rect()
	return _clamp_art_point(visible_art.position + Vector2(clampf(normalised.x, 0.0, 1.0) * visible_art.size.x, clampf(normalised.y, 0.0, 1.0) * visible_art.size.y))

func snap_art_point(art_point: Vector2) -> Vector2:
	var clamped := _clamp_art_point(art_point)
	return _clamp_art_point(Vector2(roundf(clamped.x / snap_step) * snap_step, roundf(clamped.y / snap_step) * snap_step))

func _clamp_art_point(art_point: Vector2) -> Vector2:
	return Vector2(clampf(art_point.x, 0.0, boundary_data.ART_SIZE.x), clampf(art_point.y, 0.0, boundary_data.ART_SIZE.y))

func _art_to_screen(art_point: Vector2) -> Vector2:
	var visible_art := _visible_art_rect()
	return map_rect.position + Vector2((art_point.x - visible_art.position.x) / visible_art.size.x * map_rect.size.x, (art_point.y - visible_art.position.y) / visible_art.size.y * map_rect.size.y)

func _visible_art_rect() -> Rect2:
	var visible_size: Vector2 = boundary_data.ART_SIZE / zoom_scale
	return Rect2(view_center_art - visible_size * 0.5, visible_size)

func _clamp_view_center() -> void:
	var half_size := _visible_art_rect().size * 0.5
	view_center_art = Vector2(
		clampf(view_center_art.x, half_size.x, boundary_data.ART_SIZE.x - half_size.x),
		clampf(view_center_art.y, half_size.y, boundary_data.ART_SIZE.y - half_size.y)
	)

func _map_fit_rect() -> Rect2:
	var content := Rect2(16, TOP_BAR_HEIGHT + 10.0, maxf(1.0, size.x - 32.0), maxf(1.0, size.y - TOP_BAR_HEIGHT - BOTTOM_BAR_HEIGHT - 20.0))
	var art_ratio: float = boundary_data.ART_SIZE.x / boundary_data.ART_SIZE.y
	var content_ratio := content.size.x / content.size.y
	var draw_size := content.size
	if content_ratio > art_ratio:
		draw_size.x = content.size.y * art_ratio
	else:
		draw_size.y = content.size.x / art_ratio
	return Rect2(content.get_center() - draw_size * 0.5, draw_size)

func _draw() -> void:
	if not active or game == null:
		return
	map_rect = _map_fit_rect()
	draw_rect(Rect2(Vector2.ZERO, size), Color("080513"))
	draw_texture_rect_region(background, map_rect, _background_source_rect(_visible_art_rect()))
	draw_rect(map_rect, Color(0.0, 0.02, 0.08, 0.3))
	_draw_snap_grid()
	draw_rect(map_rect, Color("35e7ff", 0.85), false, 2.0)
	for room in range(boundary_data.ROOM_COUNT):
		_draw_room_polygon(room)
	_draw_corridor_barriers()
	_draw_toolbar()
	_draw_help()

func _background_source_rect(art_rect: Rect2) -> Rect2:
	# Boundary coordinates intentionally remain in the source-map's native pixels
	# (1448 x 1086 for LV2). Convert only the texture sampling rectangle, so an
	# HD backdrop can be zoomed without changing any existing collision vertices.
	var texture_size: Vector2 = background.get_size()
	var art_size: Vector2 = boundary_data.ART_SIZE
	var texture_scale := Vector2(texture_size.x / art_size.x, texture_size.y / art_size.y)
	return Rect2(art_rect.position * texture_scale, art_rect.size * texture_scale)

func _draw_snap_grid() -> void:
	var visible_art := _visible_art_rect()
	var display_step := snap_step
	while display_step / visible_art.size.x * map_rect.size.x < 12.0:
		display_step *= 2
	var first_x := floori(visible_art.position.x / display_step) * display_step
	var first_y := floori(visible_art.position.y / display_step) * display_step
	var grid_color := Color("35e7ff", 0.12)
	var major_color := Color("9b87ff", 0.22)
	for x in range(first_x, ceili(visible_art.end.x) + display_step, display_step):
		var screen_x := _art_to_screen(Vector2(x, visible_art.position.y)).x
		var color := major_color if posmod(x / display_step, 4) == 0 else grid_color
		draw_line(Vector2(screen_x, map_rect.position.y), Vector2(screen_x, map_rect.end.y), color, 1.0)
	for y in range(first_y, ceili(visible_art.end.y) + display_step, display_step):
		var screen_y := _art_to_screen(Vector2(visible_art.position.x, y)).y
		var color := major_color if posmod(y / display_step, 4) == 0 else grid_color
		draw_line(Vector2(map_rect.position.x, screen_y), Vector2(map_rect.end.x, screen_y), color, 1.0)

func _draw_room_polygon(room: int) -> void:
	var art_polygon: PackedVector2Array = working_polygons.get(room, PackedVector2Array())
	if art_polygon.is_empty():
		return
	# A polygon can be temporarily incomplete or self-intersecting while its
	# vertices are being traced. Godot's filled-polygon renderer triangulates its
	# input, so only send it a shape that the same boundary validator accepts.
	# The outline and vertices remain visible, in coral, so the author can repair
	# the trace without an engine error flooding the terminal.
	var polygon_validation: Dictionary = boundary_data.validate_polygon(art_polygon)
	var can_fill: bool = polygon_validation.get("ok", false)
	var polygon := PackedVector2Array()
	for point in art_polygon:
		polygon.append(_clamp_screen_point(_art_to_screen(point)))
	var selected := room == selected_room
	var edge := Color("ff846f") if not can_fill else (Color("fff3a3") if selected else Color("9b87ff", 0.55))
	if can_fill:
		var fill := Color("35e7ff", 0.10 if selected else 0.035)
		draw_colored_polygon(polygon, fill)
	if polygon.size() >= 2:
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, edge, 3.0 if selected else 1.4, true)
	if selected:
		for index in range(polygon.size()):
			if not map_rect.grow(10.0).has_point(_art_to_screen(art_polygon[index])):
				continue
			var color := Color("ff846f") if index == selected_vertex else Color("fff3a3")
			draw_circle(polygon[index], 7.0, Color("0b0718"))
			draw_circle(polygon[index], 4.0, color)
			var text := str(index + 1)
			draw_string(game.ui.font, polygon[index] + Vector2(9, -8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffffff"))

func _draw_corridor_barriers() -> void:
	for index in range(working_barriers.size()):
		var barrier: Dictionary = working_barriers[index]
		var art_rect: Rect2 = barrier.get("rect", Rect2())
		if art_rect.size.x <= 0.0 or art_rect.size.y <= 0.0:
			continue
		var screen_rect := Rect2(_art_to_screen(art_rect.position), _art_to_screen(art_rect.end) - _art_to_screen(art_rect.position)).abs()
		var rooms: Array = barrier.get("rooms", [])
		var selected := rooms.has(selected_room)
		_draw_barrier_model(screen_rect, selected, false)
		if map_rect.grow(10.0).has_point(screen_rect.get_center()):
			var label := "RÀO %d · %s" % [index + 1, _room_list_label(rooms)]
			draw_string(game.ui.font, screen_rect.get_center() + Vector2(8, -9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff3a3") if selected else Color("a79abb"))
	if dragging_barrier and barrier_preview.size.x > 0.0 and barrier_preview.size.y > 0.0:
		var preview_rect := Rect2(_art_to_screen(barrier_preview.position), _art_to_screen(barrier_preview.end) - _art_to_screen(barrier_preview.position)).abs()
		_draw_barrier_model(preview_rect, true, true)

func _draw_barrier_model(rect: Rect2, selected: bool, preview: bool) -> void:
	var accent := Color("35e7ff") if preview else Color("ff846f")
	var alpha := 0.92 if selected else 0.40
	# The editor uses the same long-axis line as the in-game model.  The
	# rectangular drag area is intentionally retained only to make it practical
	# to place and select the bar with a mouse.
	var center := rect.get_center()
	var from: Vector2
	var to: Vector2
	if rect.size.y > rect.size.x:
		from = Vector2(center.x, rect.position.y)
		to = Vector2(center.x, rect.end.y)
	else:
		from = Vector2(rect.position.x, center.y)
		to = Vector2(rect.end.x, center.y)
	draw_line(from, to, Color("080513", 0.88), 8.0, true)
	draw_line(from, to, Color(accent, alpha * 0.34), 5.0, true)
	draw_line(from, to, Color(accent, alpha), 2.5 if selected else 1.5, true)

func _clamp_screen_point(screen_point: Vector2) -> Vector2:
	return Vector2(clampf(screen_point.x, map_rect.position.x, map_rect.end.x), clampf(screen_point.y, map_rect.position.y, map_rect.end.y))

func _draw_toolbar() -> void:
	toolbar_actions.clear()
	draw_rect(Rect2(0, 0, size.x, TOP_BAR_HEIGHT), Color("120c24", 0.97))
	draw_line(Vector2(0, 51), Vector2(size.x, 51), Color("51336d"), 1.0)
	draw_line(Vector2(0, TOP_BAR_HEIGHT), Vector2(size.x, TOP_BAR_HEIGHT), Color("35e7ff", 0.65), 2.0)
	var mode_title := "ĐẶT RÀO COMBAT" if is_barrier_mode() else "VẼ RANH GIỚI"
	draw_string(game.ui.bold, Vector2(18, 35), "%s · LV%d" % [mode_title, edited_stage + 1], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e6f7ff"))
	var x := 228.0
	_draw_toolbar_button(Rect2(x, 8, 116, 36), "RÀO B" if not is_barrier_mode() else "RANH GIỚI B", "mode", -1, is_barrier_mode(), Color("3d172d") if is_barrier_mode() else Color("163b48"))
	x += 126.0
	for room in range(boundary_data.ROOM_COUNT):
		var label := str(room + 1)
		if room == 4:
			label = "5 Hỗ trợ"
		elif room == 5:
			label = "6 Boss"
		else:
			label = "%d C%d" % [room + 1, room + 1]
		var width := 60.0 if room < 4 else 80.0
		_draw_toolbar_button(Rect2(x, 8, width, 36), label, "room", room, room == selected_room)
		x += width + 4.0
	_draw_toolbar_button(Rect2(x + 6, 8, 72, 36), "LƯU S", "save", -1, false, Color("163b48"))
	if is_barrier_mode():
		_draw_toolbar_button(Rect2(x + 84, 8, 90, 36), "XÓA RÀO", "clear_barriers", -1, false, Color("3d172d"))
		_draw_toolbar_button(Rect2(x + 180, 8, 82, 36), "ĐÓNG", "close", -1, false)
	else:
		_draw_toolbar_button(Rect2(x + 84, 8, 104, 36), "KHÔI PHỤC", "reset", -1, false)
		_draw_toolbar_button(Rect2(x + 194, 8, 98, 36), "XÓA PHÒNG", "clear", -1, false, Color("3d172d"))
		_draw_toolbar_button(Rect2(x + 298, 8, 82, 36), "ĐÓNG", "close", -1, false)
	var controls_y := 60.0
	draw_string(game.ui.font, Vector2(18, controls_y + 20), "LƯỚI %d px" % snap_step, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff3a3"))
	_draw_toolbar_button(Rect2(108, controls_y, 30, 26), "−", "snap_down", -1, false)
	_draw_toolbar_button(Rect2(144, controls_y, 30, 26), "+", "snap_up", -1, false)
	draw_string(game.ui.font, Vector2(198, controls_y + 20), "ZOOM %d%%" % roundi(zoom_scale * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff3a3"))
	_draw_toolbar_button(Rect2(292, controls_y, 30, 26), "−", "zoom_out", -1, false)
	_draw_toolbar_button(Rect2(328, controls_y, 30, 26), "+", "zoom_in", -1, false)
	_draw_toolbar_button(Rect2(364, controls_y, 48, 26), "1:1", "zoom_reset", -1, false)
	draw_string(game.ui.font, Vector2(434, controls_y + 20), "B: đổi Ranh giới/Rào · Lăn: zoom · Giữ chuột giữa: pan · G: đổi bước lưới", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a79abb"))

func _draw_toolbar_button(rect: Rect2, text: String, action: String, room: int, selected: bool, fill: Color = Color("27183f")) -> void:
	var border := Color("fff3a3") if selected else Color("51336d")
	draw_rect(rect, fill if not selected else Color("384157"))
	draw_rect(rect, border, false, 2.0 if selected else 1.0)
	var text_size: Vector2 = game.ui.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(game.ui.font, rect.get_center() - Vector2(text_size.x * 0.5, -4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e6f7ff"))
	toolbar_actions.append({"rect": rect, "action": action, "room": room})

func _draw_help() -> void:
	var panel := Rect2(0, size.y - BOTTOM_BAR_HEIGHT, size.x, BOTTOM_BAR_HEIGHT)
	draw_rect(panel, Color("120c24", 0.97))
	draw_line(Vector2(0, panel.position.y), Vector2(size.x, panel.position.y), Color("51336d"), 1.0)
	if is_barrier_mode():
		var selected_gates := 0
		for barrier in working_barriers:
			if Array(barrier.get("rooms", [])).has(selected_room):
				selected_gates += 1
		var gate_state := "%s · %d rào gắn · lưới %d px · %d%% · %s" % [boundary_data.ROOM_NAMES[selected_room], selected_gates, snap_step, roundi(zoom_scale * 100.0), "CHƯA LƯU" if dirty else "đã đồng bộ"]
		draw_string(game.ui.bold, Vector2(18, panel.position.y + 23), gate_state, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff3a3"))
		draw_string(game.ui.font, Vector2(18, panel.position.y + 49), "Trái+kéo: đặt rào · cửa nối tự gắn 2 phòng · Phải: xóa cả rào · Z: bỏ rào cuối · C×2: bỏ rào phòng chọn · B: về Ranh giới · S: lưu", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a79abb"))
		if not status.is_empty():
			var barrier_status_width := minf(size.x * 0.47, game.ui.font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
			draw_string(game.ui.font, Vector2(size.x - barrier_status_width - 18, panel.position.y + 23), status, HORIZONTAL_ALIGNMENT_LEFT, barrier_status_width, 14, Color("35e7ff"))
		return
	var room_validation: Dictionary = boundary_data.validate_polygon(working_polygons.get(selected_room, PackedVector2Array()))
	var selected_text := "chưa chọn đỉnh"
	var selected_polygon: PackedVector2Array = working_polygons[selected_room]
	if selected_vertex >= 0 and selected_vertex < selected_polygon.size():
		var selected_art := selected_polygon[selected_vertex]
		selected_text = "P%d (%d, %d)" % [selected_vertex + 1, selected_art.x, selected_art.y]
	var state_text := "%s · %d đỉnh · %s · lưới %d px · %d%% · %s" % [boundary_data.ROOM_NAMES[selected_room], selected_polygon.size(), selected_text, snap_step, roundi(zoom_scale * 100.0), room_validation.get("message", "")]
	draw_string(game.ui.bold, Vector2(18, panel.position.y + 23), state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("fff3a3"))
	draw_string(game.ui.font, Vector2(18, panel.position.y + 49), "Trái: thêm/kéo snap · Giữa: pan · Lăn: zoom · ←↑→↓: ±lưới · Shift+mũi tên: ×4 · Z: bỏ · S: lưu · R×2/C×2 · Esc/F6: đóng", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a79abb"))
	if not status.is_empty():
		var status_width := minf(size.x * 0.47, game.ui.font.get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		draw_string(game.ui.font, Vector2(size.x - status_width - 18, panel.position.y + 23), status, HORIZONTAL_ALIGNMENT_LEFT, status_width, 14, Color("35e7ff"))
