extends SceneTree
## Regression coverage for continuous connected-route entry. The player must keep
## moving through a quiet corridor, then enter combat from a safe chamber point;
## activating a gate underneath the player is a hard failure.

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
			_prepare(stage, room)
			var approach: Vector2 = _route_art_to_world(COMBAT_APPROACH_ART_POINTS[stage][room])
			var chamber: Vector2 = game.room_entry_position(room)
			var direction: Vector2 = (chamber - approach).normalized()
			game.player.position = approach
			game.controls.keyboard_armed = false
			game.controls.stick_vector = direction
			game.update_route_exploration()
			var label := "Area %d Combat %d" % [stage + 1, room + 1]
			_check(game.room_index == room and game.combat_chamber_pending, "%s enters a pending chamber state from the connected route" % label)
			_check(game.controls.movement().distance_to(direction) < 0.001, "%s preserves held movement across connected-room entry" % label)
			var activation_frame := -1
			var activation_position := Vector2.ZERO
			for frame in range(180):
				# Re-apply the held direction so the traversal assertion isolates the
				# barrier-under-player bug from any input-source implementation detail.
				game.controls.keyboard_armed = false
				game.controls.stick_vector = direction
				game._physics_process(0.05)
				if activation_frame < 0 and game.combat_active:
					activation_frame = frame
					activation_position = game.player.position
				if activation_frame >= 0 and frame >= activation_frame + 12:
					break
			_check(activation_frame >= 0, "%s activates during a continuous walk-in" % label)
			if activation_frame >= 0:
				var safe_combat_position: bool = game._is_position_in_polygons(game.player.position, game.player.radius, game.combat_walkable_polygons())
				var blocked_by_gate: bool = game.is_blocked_by_active_combat_barrier(activation_position, game.player.radius)
				var moved_after_activation: float = game.player.position.distance_to(activation_position)
				_check(safe_combat_position, "%s keeps the player inside the combat polygon after activation" % label)
				_check(not blocked_by_gate, "%s never activates a barrier underneath the player" % label)
				_check(moved_after_activation > 1.0, "%s keeps moving after combat activation" % label)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT ROOM ENTRY TRAVERSAL PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("COMBAT ROOM ENTRY TRAVERSAL FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _prepare(stage: int, room: int) -> void:
	game.new_run(947000 + stage * 10 + room)
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
