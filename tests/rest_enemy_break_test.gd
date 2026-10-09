extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const REST_ELITE_IDS := ["rest_vanguard", "rest_gas_brute", "rest_siege_tank"]

func _init() -> void:
	print("[TEST] Initializing Rest Enemy Break Test...")
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.test_mode = true
	game.new_run(864201)
	for elite_id: String in REST_ELITE_IDS:
		for animation_name: String in ["idle", "move", "attack", "hurt", "death"]:
			assert(game.enemies._animation_textures.has("%s:%s" % [elite_id, animation_name]), "%s must load its %s sprite sheet" % [elite_id, animation_name])
	var elite_choices: Dictionary = {}
	for seed_value in range(60):
		elite_choices[game.enemies.choose_rest_elite_kind(seed_value)] = true
	assert(elite_choices.size() == REST_ELITE_IDS.size(), "Seeded rest breaks can select all three elite types")

	game.enemies.clear()
	game.combat_active = true
	game.complete_room()
	var selected_elite: String = game.pending_rest_enemy
	assert(REST_ELITE_IDS.has(selected_elite), "Each cleared combat break should queue one random elite")
	assert(game.state == "reward" and game.enemies.units.is_empty(), "The elite must wait during the reward break")

	game.choose_upgrade("repair")
	assert(game.state == "playing" and game.profile.checkpoint.pending_rest_enemy == selected_elite, "The queued elite is saved with the checkpoint")
	game.return_to_menu()
	game.continue_run()
	assert(game.pending_rest_enemy == selected_elite, "Continue restores the same queued elite")

	game.enter_room(1)
	var elite_count := 0
	var spawned_kind := ""
	for unit: Dictionary in game.enemies.units:
		if REST_ELITE_IDS.has(str(unit.kind)):
			elite_count += 1
			spawned_kind = str(unit.kind)
	assert(elite_count == 1 and spawned_kind == selected_elite, "The next combat spawns exactly the queued elite alongside its normal wave")
	assert(game.pending_rest_enemy.is_empty(), "The elite queue is consumed exactly once")

	game.save_checkpoint()
	game.continue_run()
	var duplicate_count := 0
	for unit: Dictionary in game.enemies.units:
		if REST_ELITE_IDS.has(str(unit.kind)):
			duplicate_count += 1
	assert(duplicate_count == 0, "A consumed elite does not respawn when continuing the active room")

	print("[PASS] One random elite appears after each rest, persists through continue, and is consumed once")
	game.queue_free()
	quit(0)
