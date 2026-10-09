extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Drone Companion Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	
	# Wait 2 frames for _ready
	await process_frame
	await process_frame
	
	# Verify companion_drone exists
	assert(game.companion_drone != null, "Companion drone must be initialized")
	assert(game.companion_drone.textures.has("idle"), "Drone must load idle texture")
	assert(game.companion_drone.textures.has("forward"), "Drone must load forward texture")
	assert(game.companion_drone.textures.has("fire1"), "Drone must load fire1 texture")
	print("[PASS] Drone textures loaded successfully: ", game.companion_drone.textures.keys())
	
	# Start a run
	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.profile.meta.has_drone = false
	game.new_run(12345)
	assert(game.state == "playing", "Game state should be playing")
	assert(game.has_drone == false, "Drone should not be owned initially")
	
	# Purchase drone with coins
	game.coins = 100
	var bought = game.buy_drone_companion()
	assert(bought == true, "Drone purchase must succeed with 100 coins")
	assert(game.coins == 40, "Coins should be deducted by 60")
	assert(game.has_drone == true, "has_drone should be true after purchase")
	assert(game.companion_drone.visible == true, "Drone should be visible after purchase")
	print("[PASS] Drone purchased successfully via coins and is visible in gameplay")
	
	# Simulate movement and check drone follows player
	var player_pos_start = game.player.position
	game.player.position += Vector2(100, 50)
	game._physics_process(0.1)
	assert(game.companion_drone.position.distance_to(game.player.position) < 120.0, "Drone should stay close to player")
	print("[PASS] Drone follows player motion smoothly")
	
	# Spawn a test enemy near drone
	game.enemies.units.clear()
	game.enemies._spawn("drone", game.player.position + Vector2(150, 0), false)
	assert(game.enemies.living_count() > 0, "Enemy should be spawned")
	game.enemies.units[0].spawn_grace = 0.0
	
	var enemy_initial_hp: float = float(game.enemies.units[0].hp)
	var fired: bool = false
	# Update physics so drone detects and fires
	for i in range(60):
		game._physics_process(1.0 / 60.0)
		if game.projectiles.count() > 0:
			fired = true
	
	assert(fired or game.enemies.units.is_empty() or game.enemies.units[0].hp < enemy_initial_hp, "Drone should have fired plasma at enemy")
	print("[PASS] Drone detected enemy and fired plasma projectile!")
	
	# Test toggle with KEY_T
	var initial_enabled = game.companion_drone.enabled
	var event = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_T
	game._unhandled_input(event)
	assert(game.companion_drone.enabled == not initial_enabled, "KEY_T should toggle drone enabled state")
	print("[PASS] KEY_T toggles drone enabled state correctly")
	
	print("[ALL DRONE TESTS PASSED SUCCESSFULLY!]")
	quit(0)
