extends SceneTree
## Fast geometry guard for the authored Prism Spire continuous route.

const BoundaryData = preload("res://scripts/world/level_four_boundary_data.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var polygons: Dictionary = BoundaryData.load_room_art_polygons()
	_check(BoundaryData.validate_room_art_polygons(polygons).get("ok", false), "LV4 data has six valid simple polygons")
	_check(polygons.size() == BoundaryData.ROOM_COUNT, "LV4 data includes four combats, support and boss")
	for link in [[0, 1], [1, 2], [1, 4], [2, 3], [3, 5]]:
		var merged: Array = Geometry2D.merge_polygons(polygons[int(link[0])], polygons[int(link[1])])
		_check(merged.size() == 1, "LV4 route rooms %d and %d overlap at a crossable doorway" % [int(link[0]) + 1, int(link[1]) + 1])
	if failures.is_empty():
		print("LEVEL FOUR BOUNDARY DATA: 0 failures")
		quit(0)
	for failure in failures:
		push_error(failure)
	print("LEVEL FOUR BOUNDARY DATA: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
