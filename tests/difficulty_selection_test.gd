extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const EASY := "easy"
const NORMAL := "normal"
const HARD := "hard"

func _init() -> void:
	print("[TEST] Initializing Campaign Difficulty Test...")
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.test_mode = true
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.difficulty_mode = NORMAL

	game.ui.show_campaign_intro()
	var easy_button := game.ui.overlay.get_node_or_null("Campaign_Difficulty_Easy") as Button
	var hard_button := game.ui.overlay.get_node_or_null("Campaign_Difficulty_Hard") as Button
	assert(easy_button != null and hard_button != null, "Prologue should provide Easy, Normal and Hard choices")
	easy_button.emit_signal("pressed")
	assert(game.difficulty_mode == EASY, "Easy choice updates the active difficulty")
	hard_button = game.ui.overlay.get_node_or_null("Campaign_Difficulty_Hard") as Button
	hard_button.emit_signal("pressed")
	assert(game.difficulty_mode == HARD and game.settings.difficulty == HARD, "Hard choice updates the run and saved preference")
	var start_button := game.ui.overlay.get_node_or_null("Campaign_StartButton") as Button
	start_button.emit_signal("pressed")
	assert(game.profile.checkpoint.difficulty == HARD, "New run checkpoint stores the selected difficulty")
	game.return_to_menu()
	game.continue_run()
	assert(game.difficulty_mode == HARD, "Continue restores the checkpoint difficulty")

	var easy_unit := _spawn_normal(game, EASY)
	var normal_unit := _spawn_normal(game, NORMAL)
	var hard_unit := _spawn_normal(game, HARD)
	assert(easy_unit.kind == normal_unit.kind and normal_unit.kind == hard_unit.kind, "Seeded difficulty comparison uses the same enemy")
	assert(is_equal_approx(easy_unit.max_hp / normal_unit.max_hp, 0.78), "Easy lowers enemy health")
	assert(is_equal_approx(hard_unit.max_hp / normal_unit.max_hp, 1.45), "Hard raises enemy health")
	assert(hard_unit.damage > normal_unit.damage and hard_unit.speed > normal_unit.speed, "Hard raises damage and movement speed")
	assert(hard_unit.attack_beats < normal_unit.attack_beats and easy_unit.attack_beats > normal_unit.attack_beats, "Hard attacks more often while Easy gives longer gaps")

	var normal_boss := _spawn_boss(game, NORMAL)
	var hard_boss := _spawn_boss(game, HARD)
	assert(hard_boss.max_hp > normal_boss.max_hp and hard_boss.damage > normal_boss.damage, "Difficulty also scales bosses")
	print("[PASS] Difficulty selection persists and changes enemy and boss stats")
	game.queue_free()
	quit(0)

func _spawn_normal(game, mode: String) -> Dictionary:
	game.difficulty_mode = mode
	game.enemies.spawn_room(0, 0, false, 510510)
	return game.enemies.units[0].duplicate(true)

func _spawn_boss(game, mode: String) -> Dictionary:
	game.difficulty_mode = mode
	game.enemies.spawn_room(0, 5, true, 615615)
	return game.enemies.units[0].duplicate(true)
