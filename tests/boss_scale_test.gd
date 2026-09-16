extends SceneTree
## Ensures the requested 150% boss scale remains consistent in every authored zone.

const MainScene = preload("res://scenes/main.tscn")

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
	_check(is_equal_approx(game.enemies.BOSS_RENDER_SIZE, 120.0), "Boss renderer uses the requested 120px 150% display size")
	_check(is_equal_approx(game.enemies.BOSS_COLLISION_RADIUS, 46.5), "Boss collision uses the requested 46.5px 150% radius")
	for stage in range(5):
		game.start_debug_stage(stage)
		game.player.position = game.boss_spawn_position()
		_check(game.trigger_debug_boss_combat_preview(), "Area %d accepts the live boss preview request at its boss-room centre" % (stage + 1))
		_check(game.enemies.units.size() == 1, "Area %d creates exactly one scaled boss" % (stage + 1))
		if not game.enemies.units.is_empty():
			var boss: Dictionary = game.enemies.units[0]
			_check(is_equal_approx(boss.radius, game.enemies.BOSS_COLLISION_RADIUS), "Area %d boss collision radius matches its enlarged visual" % (stage + 1))
			_check(boss.pos.distance_to(game.boss_spawn_position()) < 1.0, "Area %d enlarged boss still fits at its authored room centre" % (stage + 1))
			_check(game.player.position.distance_to(boss.pos) > boss.radius + game.player.radius, "Area %d debug combat keeps a safe offset from the enlarged boss" % (stage + 1))
		game.enemies.clear()
		game.combat_active = false
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS SCALE PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS SCALE FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
