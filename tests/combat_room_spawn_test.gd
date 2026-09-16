extends SceneTree
## A combat wave may use only the current room floor.  It must not borrow an
## adjacent doorway or route corridor just because that area is walkable.

const MainScene = preload("res://scenes/main.tscn")
const EnemySystem = preload("res://scripts/combat/enemy_system.gd")
const MIN_SPAWN_EDGE_CLEARANCE := EnemySystem.CHAMBER_SPAWN_EDGE_CLEARANCE

var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.controls.set_process(false)
	for stage in range(5):
		game.start_debug_stage(stage)
		for room in range(4):
			for sample in range(8):
				game.enemies.clear()
				game.room_index = room
				game.combat_active = true
				game.enemies.spawn_room(stage, room, false, 940000 + stage * 10000 + room * 100 + sample)
				_check(not game.enemies.units.is_empty(), "Area %d Combat %d produces a normal wave for spawn-position verification" % [stage + 1, room + 1])
				var room_floor: Array[PackedVector2Array] = game.route_room_polygons(room)
				for enemy in game.enemies.units:
					_check(game._is_position_in_polygons(enemy.pos, enemy.radius, room_floor), "Area %d Combat %d spawns %s inside its own room rather than a corridor" % [stage + 1, room + 1, str(enemy.kind)])
					var edge_clearance := _room_edge_clearance(enemy.pos, room_floor)
					_check(edge_clearance >= MIN_SPAWN_EDGE_CLEARANCE, "Area %d Combat %d spawns %s in the chamber interior, at least %.0fpx from corridor and wall edges" % [stage + 1, room + 1, str(enemy.kind), MIN_SPAWN_EDGE_CLEARANCE])
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT ROOM SPAWN PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("COMBAT ROOM SPAWN FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)

func _room_edge_clearance(position: Vector2, polygons: Array[PackedVector2Array]) -> float:
	var best := INF
	for polygon in polygons:
		if not Geometry2D.is_point_in_polygon(position, polygon):
			continue
		for edge in range(polygon.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(position, polygon[edge], polygon[(edge + 1) % polygon.size()])
			best = minf(best, position.distance_to(nearest))
	return best
