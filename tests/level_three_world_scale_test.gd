extends SceneTree
## Keeps the authored Area 3 route, collision and entry coordinates on one scale.

const MainScene = preload("res://scenes/main.tscn")

var failures: Array[String] = []

func _initialize() -> void:

	call_deferred("run")

func run() -> void:

	var game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_debug_stage(2)
	await process_frame
	_check(game.arena.size == Vector2(4344, 3258), "LV3 runtime world is exactly 50% larger than the former 2896 x 2172 layout")
	_check(game.level_three_art_scale() == Vector2(3, 3), "LV3 background, collision and room entries share a uniform 3x transform")
	_check(game.level_three_art_to_world_point(Vector2(1448, 1086)) == Vector2(4344, 3258), "LV3 native-art extent lands at the enlarged world extent")
	var combat_one_art: PackedVector2Array = game.level_three_room_art_polygon(0)
	var combat_one_world: Array[PackedVector2Array] = game.level_three_room_polygons(0)
	_check(not combat_one_art.is_empty() and combat_one_world.size() == 1, "LV3 Combat 1 keeps its authored collision polygon after scaling")
	if not combat_one_art.is_empty() and combat_one_world.size() == 1:
		_check(combat_one_world[0][0] == combat_one_art[0] * 3.0, "LV3 Combat 1 polygon vertices map into world space at 3x")
	_check(game.is_walkable_position(game.room_entry_position(0)), "LV3 Combat 1 entry remains walkable through the scaled runtime collision")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("LEVEL THREE WORLD SCALE: 0 failures")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("LEVEL THREE WORLD SCALE: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:

	if not condition:
		failures.append(description)
