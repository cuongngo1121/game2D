class_name LevelTwoBoundaryData
extends RefCounted
## Persistent, native-image-coordinate walkable polygons for LV2 / Bass Foundry.
## These shapes follow the visible inner floor of the amber route backdrop.

const DATA_PATH := "res://data/map_boundaries_lv2.json"
const ART_SIZE := Vector2(1448.0, 1086.0)
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
	# Each doorway intentionally overlaps its neighbour by at least 20 native
	# pixels. The overlap becomes part of the merged exploration collision area,
	# so a player's radius can cross a lit doorway without catching on an edge.
	return {
		0: PackedVector2Array([Vector2(42, 690), Vector2(300, 690), Vector2(300, 1002), Vector2(42, 1002)]),
		1: PackedVector2Array([Vector2(275, 450), Vector2(555, 450), Vector2(555, 500), Vector2(620, 500), Vector2(620, 642), Vector2(600, 642), Vector2(600, 805), Vector2(558, 805), Vector2(558, 710), Vector2(275, 710)]),
		2: PackedVector2Array([Vector2(595, 315), Vector2(855, 315), Vector2(855, 385), Vector2(930, 385), Vector2(930, 590), Vector2(850, 590), Vector2(850, 560), Vector2(595, 560)]),
		3: PackedVector2Array([Vector2(785, 45), Vector2(1105, 45), Vector2(1105, 135), Vector2(1240, 135), Vector2(1240, 300), Vector2(1120, 300), Vector2(1120, 320), Vector2(945, 320), Vector2(945, 405), Vector2(870, 405), Vector2(870, 330), Vector2(785, 330)]),
		4: PackedVector2Array([Vector2(420, 780), Vector2(665, 780), Vector2(665, 960), Vector2(420, 960)]),
		5: PackedVector2Array([Vector2(1115, 285), Vector2(1405, 285), Vector2(1405, 565), Vector2(1115, 565)]),
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
	return {"ok": true, "message": "Đã lưu ranh giới LV2 vào %s" % DATA_PATH}

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
