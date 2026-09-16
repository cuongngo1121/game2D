class_name LevelFiveBoundaryData
extends RefCounted
## Persistent native-image-coordinate walkable polygons for LV5 / Silent Core.
## The HD atlas is display-only. These points always remain in the original
## 1448 x 1086 concept-art space shared by Main and Map Boundary Editor.

const SharedBoundaryData = preload("res://scripts/world/level_two_boundary_data.gd")
const DATA_PATH := "res://data/map_boundaries_lv5.json"
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
	# The source map's actual route is C1 -> C2 -> C3 -> C4 -> Boss.
	# Support is the upper-left branch off C4, so all adjacent rooms overlap only
	# at their visible floor doorways. This keeps revisits smooth while combat
	# still closes every doorway by using only the active room polygon.
	return {
		0: PackedVector2Array([Vector2(52, 786), Vector2(228, 786), Vector2(228, 670), Vector2(278, 670), Vector2(278, 768), Vector2(298, 768), Vector2(298, 988), Vector2(52, 988)]),
		1: PackedVector2Array([Vector2(228, 668), Vector2(382, 668), Vector2(382, 590), Vector2(576, 590), Vector2(576, 620), Vector2(630, 620), Vector2(630, 584), Vector2(708, 584), Vector2(708, 650), Vector2(662, 650), Vector2(662, 676), Vector2(576, 676), Vector2(576, 748), Vector2(382, 748), Vector2(382, 720), Vector2(298, 720), Vector2(298, 778), Vector2(228, 778)]),
		2: PackedVector2Array([Vector2(706, 470), Vector2(864, 470), Vector2(864, 350), Vector2(932, 350), Vector2(932, 470), Vector2(976, 470), Vector2(976, 662), Vector2(706, 662)]),
		3: PackedVector2Array([Vector2(816, 154), Vector2(1000, 154), Vector2(1000, 220), Vector2(1154, 220), Vector2(1154, 280), Vector2(1000, 280), Vector2(1000, 370), Vector2(932, 370), Vector2(932, 478), Vector2(864, 478), Vector2(864, 370), Vector2(816, 370), Vector2(816, 280), Vector2(704, 280), Vector2(704, 220), Vector2(816, 220)]),
		4: PackedVector2Array([Vector2(548, 184), Vector2(706, 184), Vector2(706, 220), Vector2(830, 220), Vector2(830, 280), Vector2(706, 280), Vector2(706, 334), Vector2(548, 334)]),
		5: PackedVector2Array([Vector2(1150, 124), Vector2(1380, 124), Vector2(1380, 366), Vector2(1150, 366), Vector2(1150, 280), Vector2(992, 280), Vector2(992, 220), Vector2(1150, 220)]),
	}

static func duplicate_room_art_polygons(source: Dictionary) -> Dictionary:
	return SharedBoundaryData.duplicate_room_art_polygons(source)

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
	return SharedBoundaryData.validate_polygon(polygon)

static func save_room_art_polygons(polygons: Dictionary) -> Dictionary:
	var validation := validate_room_art_polygons(polygons)
	if not validation.get("ok", false):
		return validation
	var file := FileAccess.open(DATA_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Không thể ghi %s: %s" % [DATA_PATH, error_string(FileAccess.get_open_error())]}
	file.store_string(JSON.stringify(_to_json(polygons), "\t") + "\n")
	file.close()
	return {"ok": true, "message": "Đã lưu ranh giới LV5 vào %s" % DATA_PATH}

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
	return {"version": 1, "art_size": [roundi(ART_SIZE.x), roundi(ART_SIZE.y)], "rooms": rooms}
