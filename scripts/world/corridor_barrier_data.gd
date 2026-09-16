class_name CorridorBarrierData
extends RefCounted
## Persistent, native-map-coordinate combat-gate models.
##
## These rectangles are deliberately separate from `map_boundaries_lv*.json`:
## walkable polygons remain the authoritative movement collision, while gates
## communicate the same active combat lock at an authored corridor position.

const ROOM_COUNT := 6
const MIN_GATE_SIDE := 8.0
const DEFAULT_GATE_THICKNESS := 12.0
const DATA_PATHS := [
	"res://data/corridor_barriers_lv1.json",
	"res://data/corridor_barriers_lv2.json",
	"res://data/corridor_barriers_lv3.json",
	"res://data/corridor_barriers_lv4.json",
	"res://data/corridor_barriers_lv5.json",
]

# The final SILENT CORE branch diverges after Combat 4; the other routes use
# the standard Combat 2 support branch. Each pair is only used to generate
# default editor labels and gate positions. Runtime combat activates every
# authored gate in the current map, regardless of these room labels.
const STAGE_CONNECTIONS := {
	0: [[0, 1], [1, 2], [1, 4], [2, 3], [3, 5]],
	1: [[0, 1], [1, 2], [1, 4], [2, 3], [3, 5]],
	2: [[0, 1], [1, 2], [1, 4], [2, 3], [3, 5]],
	3: [[0, 1], [1, 2], [1, 4], [2, 3], [3, 5]],
	4: [[0, 1], [1, 2], [2, 3], [3, 4], [3, 5]],
}

static func load_stage_art_barriers(stage: int, room_polygons: Dictionary, art_size: Vector2) -> Array[Dictionary]:
	var data_path := _data_path(stage)
	if not data_path.is_empty() and FileAccess.file_exists(data_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		if parsed is Dictionary:
			var barriers := _barriers_from_json(parsed.get("barriers", []))
			if validate_stage_art_barriers(barriers, art_size).get("ok", false):
				return duplicate_stage_art_barriers(barriers)
	return default_stage_art_barriers(stage, room_polygons, art_size)

static func default_stage_art_barriers(stage: int, room_polygons: Dictionary, art_size: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for connection in STAGE_CONNECTIONS.get(stage, []):
		if not connection is Array or connection.size() != 2:
			continue
		var first_room := int(connection[0])
		var second_room := int(connection[1])
		var first: PackedVector2Array = room_polygons.get(first_room, PackedVector2Array())
		var second: PackedVector2Array = room_polygons.get(second_room, PackedVector2Array())
		if first.size() < 3 or second.size() < 3:
			continue
		var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(first, second)
		var gate_rect := Rect2()
		if not intersections.is_empty():
			var overlap_rect := _bounds_for_polygons(intersections)
			if overlap_rect.size.x >= 1.0 and overlap_rect.size.y >= 1.0:
				gate_rect = _gate_rect_for_overlap(overlap_rect, art_size)
		# Several established route polygons deliberately meet at a clean shared
		# wall edge rather than overlapping area.  `intersect_polygons()` correctly
		# reports no filled intersection there, so derive a gate from the nearest
		# pair of edge points instead of silently leaving that corridor unmarked.
		if gate_rect.size.x <= 0.0 or gate_rect.size.y <= 0.0:
			gate_rect = _gate_rect_for_nearest_connection(first, second, art_size)
		result.append({"rooms": [first_room, second_room], "rect": gate_rect})
	return result

static func duplicate_stage_art_barriers(source: Array[Dictionary]) -> Array[Dictionary]:
	var duplicate: Array[Dictionary] = []
	for barrier in source:
		var rooms: Array = barrier.get("rooms", [])
		var copied_rooms: Array[int] = []
		for room in rooms:
			copied_rooms.append(int(room))
		var rect: Rect2 = barrier.get("rect", Rect2())
		duplicate.append({"rooms": copied_rooms, "rect": Rect2(rect.position, rect.size)})
	return duplicate

static func validate_stage_art_barriers(barriers: Array[Dictionary], art_size: Vector2) -> Dictionary:
	for index in range(barriers.size()):
		var barrier: Dictionary = barriers[index]
		var rooms: Array = barrier.get("rooms", [])
		if rooms.is_empty():
			return {"ok": false, "message": "Rào %d chưa được gắn với phòng nào." % (index + 1)}
		var seen_rooms := {}
		for room in rooms:
			var room_index := int(room)
			if room_index < 0 or room_index >= ROOM_COUNT:
				return {"ok": false, "message": "Rào %d có chỉ số phòng ngoài phạm vi." % (index + 1)}
			if seen_rooms.has(room_index):
				return {"ok": false, "message": "Rào %d gắn trùng một phòng." % (index + 1)}
			seen_rooms[room_index] = true
		var rect = barrier.get("rect", null)
		if not rect is Rect2:
			return {"ok": false, "message": "Rào %d không có hình chữ nhật hợp lệ." % (index + 1)}
		var gate: Rect2 = rect.abs()
		if gate.size.x < MIN_GATE_SIDE or gate.size.y < MIN_GATE_SIDE:
			return {"ok": false, "message": "Rào %d quá mỏng; mỗi cạnh cần ít nhất %d px." % [index + 1, MIN_GATE_SIDE]}
		if gate.position.x < 0.0 or gate.position.y < 0.0 or gate.end.x > art_size.x or gate.end.y > art_size.y:
			return {"ok": false, "message": "Rào %d vượt ngoài ảnh map." % (index + 1)}
	return {"ok": true, "message": "%d rào hành lang hợp lệ." % barriers.size()}

static func save_stage_art_barriers(stage: int, barriers: Array[Dictionary], art_size: Vector2) -> Dictionary:
	var validation := validate_stage_art_barriers(barriers, art_size)
	if not validation.get("ok", false):
		return validation
	var data_path := _data_path(stage)
	if data_path.is_empty():
		return {"ok": false, "message": "Khu vực này không hỗ trợ lưu rào hành lang."}
	var file := FileAccess.open(data_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Không thể ghi %s: %s" % [data_path, error_string(FileAccess.get_open_error())]}
	file.store_string(JSON.stringify(_to_json(barriers, art_size), "\t") + "\n")
	file.close()
	return {"ok": true, "message": "Đã lưu %d rào hành lang vào %s" % [barriers.size(), data_path]}

static func _data_path(stage: int) -> String:
	if stage < 0 or stage >= DATA_PATHS.size():
		return ""
	return DATA_PATHS[stage]

static func _barriers_from_json(value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item in value:
		if not item is Dictionary:
			return []
		var room_values = item.get("rooms", [])
		var rect_values = item.get("rect", [])
		if not room_values is Array or not rect_values is Array or rect_values.size() != 4:
			return []
		var rooms: Array[int] = []
		for room in room_values:
			rooms.append(int(room))
		result.append({
			"rooms": rooms,
			"rect": Rect2(float(rect_values[0]), float(rect_values[1]), float(rect_values[2]), float(rect_values[3])).abs(),
		})
	return result

static func _to_json(barriers: Array[Dictionary], art_size: Vector2) -> Dictionary:
	var serialized: Array = []
	for barrier in barriers:
		var rooms: Array = barrier.get("rooms", [])
		var rect: Rect2 = barrier.get("rect", Rect2())
		var serialized_rooms: Array[int] = []
		for room in rooms:
			serialized_rooms.append(int(room))
		serialized.append({
			"rooms": serialized_rooms,
			"rect": [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)],
		})
	return {"version": 1, "art_size": [roundi(art_size.x), roundi(art_size.y)], "barriers": serialized}

static func _bounds_for_polygons(polygons: Array[PackedVector2Array]) -> Rect2:
	var first_point := true
	var bounds := Rect2()
	for polygon in polygons:
		for point in polygon:
			if first_point:
				bounds = Rect2(point, Vector2.ZERO)
				first_point = false
			else:
				bounds = bounds.expand(point)
	return bounds

static func _gate_rect_for_overlap(overlap_rect: Rect2, art_size: Vector2) -> Rect2:
	var center := overlap_rect.get_center()
	if overlap_rect.size.x >= overlap_rect.size.y:
		var height := clampf(maxf(overlap_rect.size.y, 40.0), 40.0, 120.0)
		return _clamp_rect_to_art(Rect2(center - Vector2(DEFAULT_GATE_THICKNESS * 0.5, height * 0.5), Vector2(DEFAULT_GATE_THICKNESS, height)), art_size)
	var width := clampf(maxf(overlap_rect.size.x, 40.0), 40.0, 120.0)
	return _clamp_rect_to_art(Rect2(center - Vector2(width * 0.5, DEFAULT_GATE_THICKNESS * 0.5), Vector2(width, DEFAULT_GATE_THICKNESS)), art_size)

static func _gate_rect_for_nearest_connection(first: PackedVector2Array, second: PackedVector2Array, art_size: Vector2) -> Rect2:
	var nearest_first := first[0]
	var nearest_second := second[0]
	var shortest_distance := INF
	for point in first:
		for edge in range(second.size()):
			var closest := Geometry2D.get_closest_point_to_segment(point, second[edge], second[(edge + 1) % second.size()])
			var distance := point.distance_to(closest)
			if distance < shortest_distance:
				shortest_distance = distance
				nearest_first = point
				nearest_second = closest
	for point in second:
		for edge in range(first.size()):
			var closest := Geometry2D.get_closest_point_to_segment(point, first[edge], first[(edge + 1) % first.size()])
			var distance := point.distance_to(closest)
			if distance < shortest_distance:
				shortest_distance = distance
				nearest_first = closest
				nearest_second = point
	var center := (nearest_first + nearest_second) * 0.5
	var first_center := _bounds_for_polygons([first]).get_center()
	var second_center := _bounds_for_polygons([second]).get_center()
	var connection := second_center - first_center
	if absf(connection.x) >= absf(connection.y):
		return _clamp_rect_to_art(Rect2(center - Vector2(DEFAULT_GATE_THICKNESS * 0.5, 32.0), Vector2(DEFAULT_GATE_THICKNESS, 64.0)), art_size)
	return _clamp_rect_to_art(Rect2(center - Vector2(32.0, DEFAULT_GATE_THICKNESS * 0.5), Vector2(64.0, DEFAULT_GATE_THICKNESS)), art_size)

static func _clamp_rect_to_art(rect: Rect2, art_size: Vector2) -> Rect2:
	var size := Vector2(minf(rect.size.x, art_size.x), minf(rect.size.y, art_size.y))
	return Rect2(
		Vector2(clampf(rect.position.x, 0.0, art_size.x - size.x), clampf(rect.position.y, 0.0, art_size.y - size.y)),
		size
	)
