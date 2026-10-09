extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Armory Drone & Coin Purchase Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	game.test_mode = true
	root.add_child(game)
	
	await process_frame
	await process_frame
	
	# Start in unowned drone state with standard unlocks
	game.profile.meta.unlocked = ["pistol", "smg"]
	game.profile.meta.shards = 0
	game.profile.meta.has_drone = false
	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.coins = 0
	game.has_drone = false
	if "upgrades" in game and game.upgrades != null:
		game.upgrades.erase("drone")
	game.starter = "smg"
	
	# Open Armory
	game.ui.show_unlocks()
	await process_frame
	
	# 1. Check currency and drone bay in overlay
	var currency_node = game.ui.overlay.get_node_or_null("Armory_CurrencyLabel")
	assert(currency_node != null, "Armory must display currency label")
	print("[PASS] Currency label present in Armory: ", currency_node.text)
	
	var drone_btn = game.ui.overlay.get_node_or_null("Armory_DroneActionButton")
	assert(drone_btn != null, "Armory must have Drone Action Button")
	# set_deferred is used so wait extra frame
	await process_frame
	assert(drone_btn.disabled == true, "Drone buy button should be disabled when having 0 coins")
	assert(drone_btn.text == "MUA 60 🪙", "Drone button text should be MUA 60 🪙")
	print("[PASS] Drone Bay initially shows MUA 60 🪙 and is disabled with 0 coins")
	
	# 2. Add coins and purchase drone via Armory
	game.coins = 120
	game.ui.show_unlocks()
	await process_frame
	drone_btn = game.ui.overlay.get_node_or_null("Armory_DroneActionButton")
	assert(drone_btn.disabled == false, "Drone buy button should now be enabled with 120 coins")
	
	drone_btn.emit_signal("pressed")
	await process_frame
	
	assert(game.has_drone == true, "Drone must be owned after clicking buy")
	assert(game.coins == 60, "Coins must be deducted by 60")
	drone_btn = game.ui.overlay.get_node_or_null("Armory_DroneActionButton")
	assert(drone_btn.text == "ĐANG BẬT [TẮT]", "Drone button should show active state after buy")
	print("[PASS] Drone purchased in Armory successfully!")
	game.companion_drone.set_drone_type("bomb")
	var bomb_config: Dictionary = game.companion_drone._current_cfg()
	var bomb_anims: Dictionary = bomb_config.get("anims", {})
	var bomb_idle_info: Dictionary = bomb_anims.get("idle", {})
	var bomb_textures: Dictionary = game.companion_drone.textures
	var bomb_idle: Texture2D = bomb_textures.get("idle")
	assert(int(bomb_idle_info.get("frames", 0)) == 6, "Bomb Drone idle sheet must use all six frames")
	assert(bomb_idle.get_width() / 6 == 16 and bomb_idle.get_height() == 16, "Bomb Drone idle frame must be sliced as 16x16")
	game.companion_drone.set_drone_type("plasma")
	
	# 3. Toggle drone active state in Armory
	drone_btn.emit_signal("pressed")
	await process_frame
	assert(game.companion_drone.enabled == false, "Drone should be toggled off")
	drone_btn = game.ui.overlay.get_node_or_null("Armory_DroneActionButton")
	assert(drone_btn.text == "CHỌN TRANG BỊ", "Drone button should offer to re-equip")
	print("[PASS] Drone toggled on/off in Armory correctly")
	
	# 4. Test Weapon Coin Purchase
	assert(not game.profile.meta.unlocked.has("rail"), "Rail Synth should be locked initially")
	# Player has 60 coins, rail requires 50 coins
	var rail_button: Button = null
	for child in game.ui.overlay.get_children():
		if child is Button and str(child.get_meta("armory_weapon_id", "")) == "rail":
			rail_button = child
			break
	assert(rail_button != null, "Rail weapon card button must exist")
	assert(rail_button.disabled == false, "Rail card should be clickable because player has 60 coins")
	
	rail_button.emit_signal("pressed")
	await process_frame
	
	assert(game.profile.meta.unlocked.has("rail"), "Rail Synth must now be unlocked via coins")
	assert(game.coins == 10, "50 coins should be deducted for weapon purchase")
	print("[PASS] Weapon purchased with coins in Armory! Remaining coins: ", game.coins)
	
	# 5. Equip newly bought weapon
	for child in game.ui.overlay.get_children():
		if child is Button and str(child.get_meta("armory_weapon_id", "")) == "rail":
			rail_button = child
			break
	rail_button.emit_signal("pressed")
	await process_frame
	assert(game.starter == "rail", "Rail Synth must be equipped as starter weapon")
	print("[PASS] Newly purchased weapon equipped as starter!")
	
	print("[ALL ARMORY DRONE & WEAPON COIN TESTS PASSED!]")
	quit(0)
