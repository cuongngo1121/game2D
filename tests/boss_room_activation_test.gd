extends SceneTree
## Regression coverage for the connected boss routes in Areas 1–5.
## The boss polygon includes its approach corridor, but combat must wait until
## the player reaches the chamber itself. Each boss then spawns at that
## chamber's authored centre rather than at a generic arena corner.

const MainScene = preload("res://scenes/main.tscn")

const BOSS_APPROACH_ART_POINTS := {
	0: Vector2(1324, 360),
	1: Vector2(1226, 260),
	2: Vector2(1238, 350),
	3: Vector2(1160, 190),
	4: Vector2(1060, 250),
}

const BOSS_CHAMBER_CENTRES_ART := {
	0: Vector2(1490, 200),
	1: Vector2(1274, 426),
	2: Vector2(1285, 240),
	3: Vector2(1290, 198),
	4: Vector2(1265, 245),
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
		_prepare_boss_approach(stage)
		var corridor: Vector2 = _route_art_to_world(BOSS_APPROACH_ART_POINTS[stage])
		var centre: Vector2 = _route_art_to_world(BOSS_CHAMBER_CENTRES_ART[stage])
		_check(game._is_position_in_polygons(corridor, game.player.radius, game.route_room_polygons(5)), "Area %d approach point belongs to its authored boss route" % (stage + 1))
		_check(game._is_position_in_polygons(centre, game.player.radius, game.route_room_polygons(5)), "Area %d chamber centre is a valid boss-floor point" % (stage + 1))
		game.player.position = corridor
		game.update_route_exploration()
		_check(game.room_index == 5, "Area %d records entry into the boss route after the player crosses the final boundary" % (stage + 1))
		_check(not game.combat_active and game.enemies.living_count() == 0, "Area %d corridor entry does not spawn or lock the boss" % (stage + 1))
		game.player.position = centre
		game.update_route_exploration()
		_check(game.state == "boss_briefing" and not game.combat_active and game.enemies.living_count() == 0, "Area %d shows the boss warning before spawning the boss" % (stage + 1))
		var warning_label := game.ui.overlay.get_node_or_null("BossBriefingWarning") as Label
		_check(warning_label != null and warning_label.text.contains(str(game.content.stages[stage].boss_warning)), "Area %d briefing includes its boss-specific skill warning" % (stage + 1))
		_check(not str(game.content.stages[stage].boss_counter).is_empty(), "Area %d briefing includes counterplay advice" % (stage + 1))
		var confirm_button := game.ui.overlay.get_node_or_null("BossBriefing_ConfirmButton") as Button
		_check(confirm_button != null, "Area %d briefing exposes a start-fight button" % (stage + 1))
		if confirm_button != null:
			confirm_button.emit_signal("pressed")
		_check(game.combat_active and game.enemies.living_count() == 1, "Area %d starts the boss after the player confirms the briefing" % (stage + 1))
		if game.enemies.living_count() == 1:
			var boss: Dictionary = game.enemies.units[0]
			_check(boss.boss and boss.pos.distance_to(centre) < 1.0, "Area %d boss spawns at the authored chamber centre" % (stage + 1))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS ROOM ACTIVATION PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS ROOM ACTIVATION FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _prepare_boss_approach(stage: int) -> void:
	game.new_run(931200 + stage)
	game.stage_index = stage
	game.graph = game.GraphScript.generate(game.seed_value, stage)
	game.set_stage_music()
	# The final room becomes available after all four combat encounters clear.
	# Keep the player in cleared Combat 4 so the next movement is the real
	# route transition, not a direct test-only room jump.
	game.cleared = [0, 1, 2, 3]
	game.enter_room(3)
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
