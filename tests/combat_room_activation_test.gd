extends SceneTree
## Every ordinary combat polygon includes its approach corridor. This contract
## verifies that Areas 1–5 keep those corridors safe, then start the encounter
## only after NOCTIS crosses the authored chamber threshold.

const MainScene = preload("res://scenes/main.tscn")

const COMBAT_APPROACH_ART_POINTS := {
	0: {
		1: Vector2(330, 760),
		2: Vector2(760, 585),
		3: Vector2(1100, 580),
	},
	1: {
		1: Vector2(300, 696),
		2: Vector2(590, 596),
		3: Vector2(910, 300),
	},
	2: {
		1: Vector2(200, 730),
		2: Vector2(650, 630),
		3: Vector2(950, 490),
	},
	3: {
		1: Vector2(260, 840),
		2: Vector2(688, 500),
		3: Vector2(900, 320),
	},
	4: {
		1: Vector2(270, 750),
		2: Vector2(600, 650),
		3: Vector2(900, 420),
	},
}

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
		for room in range(1, 4):
			_prepare_combat_approach(stage, room)
			var approach: Vector2 = _route_art_to_world(COMBAT_APPROACH_ART_POINTS[stage][room])
			var chamber: Vector2 = game.room_entry_position(room)
			_check(game._is_position_in_polygons(approach, game.player.radius, game.route_room_polygons(room)), "Area %d Combat %d approach point belongs to the newly opened route" % [stage + 1, room + 1])
			_check(not game.has_reached_combat_chamber(approach, game.player.radius), "Area %d Combat %d approach stays outside its chamber trigger" % [stage + 1, room + 1])
			game.player.position = approach
			game.update_route_exploration()
			_check(game.room_index == room and not game.combat_active and game.enemies.living_count() == 0, "Area %d Combat %d corridor entry leaves enemies unspawned" % [stage + 1, room + 1])
			_check(game.active_combat_barrier_rects().is_empty(), "Area %d Combat %d corridor entry leaves every combat barrier hidden" % [stage + 1, room + 1])
			_check(game.has_reached_combat_chamber(chamber, game.player.radius), "Area %d Combat %d room entry lies inside its chamber trigger" % [stage + 1, room + 1])
			game.player.position = chamber
			game.update_route_exploration()
			_check(game.combat_active and game.enemies.living_count() > 0, "Area %d Combat %d starts only after the player steps into the chamber" % [stage + 1, room + 1])
			_check(not game.active_combat_barrier_rects().is_empty(), "Area %d Combat %d shows its barriers only with the started encounter" % [stage + 1, room + 1])
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT ROOM ACTIVATION PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("COMBAT ROOM ACTIVATION FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _prepare_combat_approach(stage: int, room: int) -> void:
	game.new_run(945000 + stage * 10 + room)
	game.stage_index = stage
	game.graph = game.GraphScript.generate(game.seed_value, stage)
	game.set_stage_music()
	game.cleared = []
	for cleared_room in range(room):
		game.cleared.append(cleared_room)
	game.enter_room(room - 1)
	game.enemies.clear()
	game.player.invulnerable = 999.0

func _route_art_to_world(art_point: Vector2) -> Vector2:
	match game.stage_index:
		0: return game.level_one_art_to_world_point(art_point)
		1: return game.level_two_art_to_world_point(art_point)
		2: return game.level_three_art_to_world_point(art_point)
		3: return game.level_four_art_to_world_point(art_point)
		4: return game.level_five_art_to_world_point(art_point)
	return art_point

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
