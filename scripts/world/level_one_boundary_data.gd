class_name LevelOneBoundaryData
extends RefCounted
## Persistent, native-image-coordinate walkable polygons for LV1.
## Both RoomView and movement collision consume this one representation.

const DATA_PATH := "res://data/map_boundaries_lv1.json"
const ART_SIZE := Vector2(1672.0, 941.0)
const ROOM_COUNT := 6
const ROOM_NAMES := ["Chiến đấu 1", "Chiến đấu 2", "Chiến đấu 3", "Chiến đấu 4", "Hỗ trợ", "Boss"]

static func load_room_art_polygons() -> Dictionary:
	if FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			var rooms = parsed.get("rooms", {})
			if rooms is Dictionary:
				var result := {}
				for index in range(ROOM_COUNT):
					var polygon := _points_from_json(rooms.get(str(index), []))
					if validate_polygon(polygon).get("ok", false):
						result[index] = polygon
				if result.size() == ROOM_COUNT:
					return result
	return default_room_art_polygons()

static func default_room_art_polygons() -> Dictionary:
	return {
		0: PackedVector2Array([Vector2(88, 660), Vector2(298, 660), Vector2(298, 870), Vector2(88, 870)]),
		1: PackedVector2Array([Vector2(433, 485), Vector2(735, 485), Vector2(735, 719), Vector2(433, 719), Vector2(433, 658), Vector2(420, 658), Vector2(420, 820), Vector2(270, 820), Vector2(270, 574), Vector2(394, 574), Vector2(394, 556), Vector2(433, 556)]),
		2: PackedVector2Array([Vector2(805, 485), Vector2(1070, 485), Vector2(1070, 695), Vector2(805, 695), Vector2(805, 620), Vector2(700, 620), Vector2(700, 550), Vector2(805, 550)]),
		3: PackedVector2Array([Vector2(1170, 395), Vector2(1470, 395), Vector2(1470, 620), Vector2(1225, 620), Vector2(1225, 630), Vector2(1015, 630), Vector2(1015, 540), Vector2(1170, 540)]),
		4: PackedVector2Array([Vector2(500, 205), Vector2(735, 205), Vector2(735, 390), Vector2(675, 390), Vector2(675, 540), Vector2(560, 540), Vector2(560, 390), Vector2(500, 390)]),
		5: PackedVector2Array([Vector2(1338, 55), Vector2(1623, 55), Vector2(1623, 345), Vector2(1400, 345), Vector2(1400, 445), Vector2(1250, 445), Vector2(1250, 145), Vector2(1338, 145)]),
	}

static func duplicate_room_art_polygons(source: Dictionary) -> Dictionary:
	var duplicate := {}
	for index in range(ROOM_COUNT):
		var polygon: PackedVector2Array = source.get(index, PackedVector2Array())
		duplicate[index] = polygon.duplicate()
	return duplicate

static func save_room_art_polygons(polygons: Dictionary) -> Dictionary:
	var validation := validate_room_art_polygons(polygons)
	if not validation.get("ok", false):
		return validation
	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"message": "Không thể ghi %s: %s" % [DATA_PATH, error_string(FileAccess.get_open_error())],
		}
	file.store_string(JSON.stringify(_to_json(polygons), "\t") + "\n")
	file.close()
	return {"ok": true, "message": "Đã lưu ranh giới LV1 vào %s" % DATA_PATH}

static func validate_room_art_polygons(polygons: Dictionary) -> Dictionary:
	for index in range(ROOM_COUNT):
		if not polygons.has(index):
			return {"ok": false, "message": "%s chưa có polygon." % ROOM_NAMES[index]}
		var polygon: PackedVector2Array = polygons[index]
		var polygon_validation := validate_polygon(polygon)
		if not polygon_validation.get("ok", false):
			return {"ok": false, "message": "%s: %s" % [ROOM_NAMES[index], polygon_validation.message]}
	return {"ok": true, "message": "Tất cả 6 vùng đều hợp lệ."}

static func validate_polygon(polygon: PackedVector2Array) -> Dictionary:
	if polygon.size() < 3:
		return {"ok": false, "message": "cần ít nhất 3 đỉnh."}
	if absf(_signed_area(polygon)) < 64.0:
		return {"ok": false, "message": "diện tích quá nhỏ hoặc các đỉnh thẳng hàng."}
	for index in range(polygon.size()):
		if polygon[index].distance_to(polygon[(index + 1) % polygon.size()]) < 2.0:
			return {"ok": false, "message": "có hai đỉnh quá sát nhau."}
	if _has_self_intersection(polygon):
		return {"ok": false, "message": "các cạnh giao nhau; hãy sắp xếp lại đỉnh theo một vòng bao."}
	if Geometry2D.triangulate_polygon(polygon).is_empty():
		return {"ok": false, "message": "không thể tạo vùng kín từ các đỉnh này."}
	return {"ok": true, "message": "Hợp lệ."}

static func _points_from_json(value) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if not value is Array:
		return polygon
	for point in value:
		if not point is Array or point.size() != 2:
			return PackedVector2Array()
		polygon.append(Vector2(float(point[0]), float(point[1])))
	return polygon

static func _to_json(polygons: Dictionary) -> Dictionary:
	var rooms := {}
	for index in range(ROOM_COUNT):
		var points: Array = []
		var polygon: PackedVector2Array = polygons[index]
		for point in polygon:
			points.append([roundi(point.x), roundi(point.y)])
		rooms[str(index)] = points
	return {
		"version": 1,
		"art_size": [roundi(ART_SIZE.x), roundi(ART_SIZE.y)],
		"rooms": rooms,
	}

static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return area * 0.5

static func _has_self_intersection(polygon: PackedVector2Array) -> bool:
	var size := polygon.size()
	for first in range(size):
		var first_next := (first + 1) % size
		for second in range(first + 1, size):
			var second_next := (second + 1) % size
			if first == second or first_next == second or second_next == first:
				continue
			if _segments_intersect(polygon[first], polygon[first_next], polygon[second], polygon[second_next]):
				return true
	return false

static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var first_direction := b - a
	var second_direction := d - c
	var divisor := first_direction.cross(second_direction)
	if absf(divisor) < 0.001:
		return false
	var first_factor := (c - a).cross(second_direction) / divisor
	var second_factor := (c - a).cross(first_direction) / divisor
	return first_factor > 0.001 and first_factor < 0.999 and second_factor > 0.001 and second_factor < 0.999
