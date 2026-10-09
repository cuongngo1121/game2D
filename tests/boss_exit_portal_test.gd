extends SceneTree
## End-to-end boss exit coverage: kill -> reward -> portal appears -> player
## deliberately leaves its radius and walks back through it.

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
	for stage in range(5):
		_prepare_defeated_boss(stage)
		var expected_gate_position: Vector2 = game.boss_spawn_position()
		var gate := _boss_exit_portal()
		_check(not gate.is_empty(), "Area %d creates its exit portal immediately after the boss is defeated" % (stage + 1))
		if not gate.is_empty():
			_check(gate.pos.distance_to(expected_gate_position) < 1.0, "Area %d places its exit portal at the boss chamber centre" % (stage + 1))
		_check(is_zero_approx(game.exit_portal_appear_progress()), "Area %d gate starts from the closed-core frame" % (stage + 1))
		game._process(0.42)
		var mid_appear: float = float(game.exit_portal_appear_progress())
		_check(mid_appear > 0.0 and mid_appear < 1.0, "Area %d gate has a visible in-progress appearance phase" % (stage + 1))
		game.choose_upgrade("repair")
		_check(game.state == "playing" and game.rewarded.has(5), "Area %d unlocks its exit portal after the boss reward is accepted" % (stage + 1))
		# `continue_run()` enters this same cleared room after loading a checkpoint.
		# Re-enter it directly here to make sure the exit cannot disappear between
		# a completed boss and the next area.
		game.enter_room(5)
		_check(not game.boss_exit_portal().is_empty() and not game.combat_active, "Area %d restores its exit portal in a completed-boss checkpoint" % (stage + 1))
		game._process(1.0)
		_check(is_equal_approx(game.exit_portal_appear_progress(), 1.0), "Area %d gate reaches its stable looping frame before travel is armed" % (stage + 1))
		# Leaving first prevents a standing player from being transported the same
		# frame the gate finishes appearing; walking back in is the intentional use.
		game.player.position = expected_gate_position + Vector2(220, 0)
		game._physics_process(0.1)
		game.player.position = expected_gate_position
		game._physics_process(0.1)
		if stage < 4:
			_check(game.state == "area_transition" and game.stage_index == stage, "Area %d portal shows the story bridge before Area %d" % [stage + 1, stage + 2])
			var story_label := game.ui.overlay.get_node_or_null("AreaTransition_Story") as Label
			_check(story_label != null and not story_label.text.is_empty(), "Area %d transition includes a short narrative" % (stage + 1))
			var continue_button := game.ui.overlay.get_node_or_null("AreaTransition_ContinueButton") as Button
			_check(continue_button != null, "Area %d transition exposes an action to continue")
			if continue_button != null:
				continue_button.emit_signal("pressed")
			_check(game.stage_index == stage + 1 and game.room_index == 0 and game.state == "playing", "Area %d transition carries the player into Area %d" % [stage + 1, stage + 2])
		else:
			_check(game.state == "victory", "Area 5 portal completes the run instead of entering a nonexistent Area 6")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS EXIT PORTAL PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS EXIT PORTAL FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _prepare_defeated_boss(stage: int) -> void:
	game.new_run(741100 + stage)
	game.stage_index = stage
	game.graph = game.GraphScript.generate(game.seed_value, stage)
	game.set_stage_music()
	game.cleared = [0, 1, 2, 3]
	game.enter_room(5)
	game.enemies.clear()
	game.combat_active = true
	game.complete_room()

func _boss_exit_portal() -> Dictionary:
	for portal in game.portals:
		if int(portal.get("room", -1)) == 6:
			return portal
	return {}

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
