class_name LevelFourBoundaryData
extends RefCounted
## Persistent native-image-coordinate walkable polygons for LV4 / Prism Spire.
## The shared validation keeps editor traces safe for Godot's polygon renderer.

const SharedBoundaryData = preload("res://scripts/world/level_two_boundary_data.gd")
const DATA_PATH := "res://data/map_boundaries_lv4.json"
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
	# Each neighbouring pair overlaps at a real doorway. This creates one
	# walkable route after the preceding encounter clears, while combat still
	# constrains movement to the active room polygon.
	return {
		0: PackedVector2Array([Vector2(25, 770), Vector2(260, 770), Vector2(260, 1005), Vector2(25, 1005)]),
		1: PackedVector2Array([Vector2(400, 510), Vector2(650, 510), Vector2(650, 700), Vector2(620, 700), Vector2(620, 790), Vector2(555, 790), Vector2(555, 700), Vector2(430, 700), Vector2(430, 710), Vector2(385, 710), Vector2(385, 760), Vector2(335, 760), Vector2(335, 820), Vector2(280, 820), Vector2(280, 855), Vector2(240, 855), Vector2(240, 800), Vector2(260, 800), Vector2(260, 750), Vector2(315, 750), Vector2(315, 700), Vector2(365, 700), Vector2(365, 650), Vector2(400, 650)]),
		2: PackedVector2Array([Vector2(745, 350), Vector2(850, 350), Vector2(850, 300), Vector2(925, 300), Vector2(925, 350), Vector2(960, 350), Vector2(960, 545), Vector2(780, 545), Vector2(780, 590), Vector2(630, 590), Vector2(630, 405), Vector2(745, 405)]),
		3: PackedVector2Array([Vector2(850, 80), Vector2(985, 80), Vector2(985, 115), Vector2(1030, 115), Vector2(1030, 155), Vector2(1200, 155), Vector2(1200, 210), Vector2(1030, 210), Vector2(1030, 255), Vector2(925, 255), Vector2(925, 350), Vector2(850, 350), Vector2(850, 255), Vector2(800, 255), Vector2(800, 130), Vector2(850, 130)]),
		4: PackedVector2Array([Vector2(555, 660), Vector2(620, 660), Vector2(620, 790), Vector2(660, 790), Vector2(660, 915), Vector2(500, 915), Vector2(500, 790), Vector2(555, 790)]),
		5: PackedVector2Array([Vector2(1180, 95), Vector2(1400, 95), Vector2(1400, 300), Vector2(1180, 300), Vector2(1180, 220), Vector2(1150, 220), Vector2(1150, 160), Vector2(1180, 160)]),
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
	return {"ok": true, "message": "Đã lưu ranh giới LV4 vào %s" % DATA_PATH}

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
