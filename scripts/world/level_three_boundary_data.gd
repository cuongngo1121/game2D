class_name LevelThreeBoundaryData
extends RefCounted
## Persistent native-image-coordinate walkable polygons for LV3 / Luminous Grove.
## The shared validation prevents editor traces from reaching the polygon renderer
## before they are safe to triangulate.

const SharedBoundaryData = preload("res://scripts/world/level_two_boundary_data.gd")
const DATA_PATH := "res://data/map_boundaries_lv3.json"
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
	# Neighbouring rooms overlap at their visible doorways by 25–50 source pixels.
	# This lets the collision union become a real open route after a clear while
	# the active-room polygon still seals the doorway during combat.
	return {
		0: PackedVector2Array([Vector2(48, 780), Vector2(270, 780), Vector2(270, 950), Vector2(48, 950)]),
		1: PackedVector2Array([Vector2(160, 555), Vector2(580, 555), Vector2(580, 600), Vector2(650, 600), Vector2(650, 520), Vector2(700, 520), Vector2(700, 710), Vector2(255, 710), Vector2(255, 805), Vector2(215, 805), Vector2(215, 700), Vector2(160, 700)]),
		2: PackedVector2Array([Vector2(690, 410), Vector2(885, 410), Vector2(885, 445), Vector2(1025, 445), Vector2(1025, 575), Vector2(900, 575), Vector2(900, 605), Vector2(700, 605), Vector2(700, 570), Vector2(650, 570), Vector2(650, 520), Vector2(690, 520)]),
		3: PackedVector2Array([Vector2(1040, 370), Vector2(1220, 370), Vector2(1220, 560), Vector2(1050, 560), Vector2(1050, 520), Vector2(1000, 520), Vector2(1000, 445), Vector2(1040, 445)]),
		4: PackedVector2Array([Vector2(680, 210), Vector2(830, 210), Vector2(830, 350), Vector2(795, 350), Vector2(795, 540), Vector2(690, 540), Vector2(690, 450), Vector2(740, 450), Vector2(740, 350), Vector2(680, 350)]),
		5: PackedVector2Array([Vector2(1200, 125), Vector2(1405, 125), Vector2(1405, 330), Vector2(1250, 330), Vector2(1250, 395), Vector2(1195, 395), Vector2(1195, 300), Vector2(1160, 300), Vector2(1160, 210), Vector2(1200, 210)]),
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
		return {
			"ok": false,
			"message": "Không thể ghi %s: %s" % [DATA_PATH, error_string(FileAccess.get_open_error())],
		}
	file.store_string(JSON.stringify(_to_json(polygons), "\t") + "\n")
	file.close()
	return {"ok": true, "message": "Đã lưu ranh giới LV3 vào %s" % DATA_PATH}

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
