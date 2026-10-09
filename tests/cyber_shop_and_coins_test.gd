extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Cyber Shop & Coin Farming Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	
	await process_frame
	await process_frame
	
	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.profile.meta.has_drone = false
	game.new_run(98765)
	assert(game.state == "playing", "Game must be playing")
	
	# 1. Test Coin Drop on Enemy Kill
	game.enemies.units.clear()
	game.pickups.clear()
	var spawn_pos = game.player.position + Vector2(60, 0)
	game.enemies._spawn("crawler", spawn_pos, false)
	assert(game.enemies.living_count() > 0, "Enemy should spawn")
	game.enemies.units[0].spawn_grace = 0.0
	
	var enemy_id = game.enemies.units[0].id
	game.enemies.damage_enemy(enemy_id, 999.0) # Lethal damage
	
	# Check that a coin pickup was created
	var found_coin: bool = false
	for p in game.pickups:
		if int(p.get("coins", 0)) > 0:
			found_coin = true
			break
	assert(found_coin, "Defeated enemy must drop a pickup containing coins")
	print("[PASS] Enemies drop coins upon defeat")
	
	# 2. Test Coin Collection
	var initial_coins: int = game.coins
	# Place player directly on the coin to collect
	game.player.position = spawn_pos
	game._physics_process(0.1)
	assert(game.coins > initial_coins, "Player must collect the dropped coin")
	print("[PASS] Player collects coins successfully. Balance: ", game.coins)
	
	# 3. Test Shop Interaction & Purchases
	game.combat_active = false
	game.coins = 500 # Fund test
	game.open_cyber_shop()
	assert(game.state == "shop", "Game state should be shop")
	print("[PASS] Cyber Shop opens correctly")
	
	# Purchase Max HP Upgrade
	var old_max_hp = game.player.max_hp
	var hp_upgrade = game.buy_max_hp_upgrade()
	assert(hp_upgrade == true, "Max HP upgrade must succeed")
	assert(game.player.max_hp > old_max_hp, "Player Max HP must increase")
	print("[PASS] Max HP upgrade increased HP: %d -> %d" % [int(old_max_hp), int(game.player.max_hp)])
	
	# Purchase Max Shield Upgrade
	var old_shield = game.player.max_shield
	var shield_upgrade = game.buy_max_shield_upgrade()
	assert(shield_upgrade == true, "Max Shield upgrade must succeed")
	assert(game.player.max_shield > old_shield, "Player Max Shield must increase")
	print("[PASS] Max Shield upgrade increased Shield: %d -> %d" % [int(old_shield), int(game.player.max_shield)])
	
	# Purchase Damage Upgrade
	var dmg_upgrade = game.buy_damage_upgrade()
	assert(dmg_upgrade == true, "Damage upgrade must succeed")
	assert(int(game.upgrades.get("damage", 0)) == 1, "Damage upgrade level should be 1")
	print("[PASS] Damage upgrade purchased")
	
	# Close Shop
	game.resume_game()
	assert(game.state == "playing", "Game state should return to playing")
	print("[PASS] Resume game from shop works")
	
	# Check KEY_B hotkey opens shop
	var event_b = InputEventKey.new()
	event_b.pressed = true
	event_b.physical_keycode = KEY_B
	game._unhandled_input(event_b)
	assert(game.state == "shop", "KEY_B should open cyber shop during gameplay")
	print("[PASS] KEY_B hotkey opens cyber shop")
	
	# KEY_B toggles resume
	game._unhandled_input(event_b)
	assert(game.state == "playing", "KEY_B again should resume gameplay")
	print("[PASS] KEY_B hotkey resumes game")
	
	print("[ALL CYBER SHOP & COIN FARMING TESTS PASSED!]")
	quit(0)
