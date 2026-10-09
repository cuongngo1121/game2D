extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Equipment 2-Tab (Weapons & Drones) System Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	
	await process_frame
	await process_frame
	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.profile.meta.has_drone = false
	
	# -----------------------------------------------------------------
	# 1. Main Menu Navigation: KHO VŨ KHÍ -> TRANG BỊ
	# -----------------------------------------------------------------
	game.ui.show_menu()
	await process_frame
	var armory_btn = game.ui.overlay.get_node_or_null("Menu_armory_Hitbox") as Button
	assert(armory_btn != null, "Menu must contain armory hitbox")
	assert(armory_btn.text == "TRANG BỊ", "Menu button must be renamed to TRANG BỊ: %s" % armory_btn.text)
	print("[PASS] Main Menu button renamed to TRANG BỊ successfully")
	
	# -----------------------------------------------------------------
	# 2. Enter Equipment: verify tabs and title
	# -----------------------------------------------------------------
	armory_btn.emit_signal("pressed")
	await process_frame
	assert(game.state == "unlocks", "Should enter unlocks state")
	
	var title_lbl = game.ui.overlay.get_node_or_null("Armory_title") as Label
	var tab_weapons = game.ui.overlay.get_node_or_null("Armory_Tab_Weapons") as Button
	var tab_drones = game.ui.overlay.get_node_or_null("Armory_Tab_Drones") as Button
	assert(tab_weapons != null, "Equipment must have Weapons tab")
	assert(tab_drones != null, "Equipment must have Drones tab")
	print("[PASS] Equipment screen contains both [⚔ VŨ KHÍ] and [🛸 DRONE] tabs")
	
	# -----------------------------------------------------------------
	# 3. Switch to [🛸 DRONE] Tab
	# -----------------------------------------------------------------
	tab_drones.emit_signal("pressed")
	await process_frame
	assert(game.ui.current_armory_tab == "drones", "Current equipment tab should be drones")
	
	# Check Drone Cards
	var plasma_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_plasma") as Button
	var scout_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_scout") as Button
	var bomb_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_bomb") as Button
	var laser_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_laser") as Button
	var support_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_support") as Button
	
	assert(plasma_btn != null and scout_btn != null and bomb_btn != null and laser_btn != null and support_btn != null,
		"All 5 Drone cards must be present in Drone Tab")
	print("[PASS] All 5 Drone cards (Plasma, Scout, Bomb, Laser, Support) rendered cleanly")
	
	# -----------------------------------------------------------------
	# 4. Purchase and Equip Drone from Drones Tab
	# -----------------------------------------------------------------
	game.coins = 200
	game.ui.show_unlocks("drones")
	await process_frame
	
	scout_btn = game.ui.overlay.get_node_or_null("Armory_DroneCardButton_scout") as Button
	assert(scout_btn != null and not scout_btn.disabled, "Scout drone button should be active with 200 coins")
	scout_btn.emit_signal("pressed")
	await process_frame
	
	assert(game.profile.meta.unlocked_drones.has("scout"), "Scout drone must now be unlocked in profile")
	assert(game.selected_drone == "scout", "Scout drone should be automatically equipped; selected ID was '%s'" % game.selected_drone)
	assert(game.has_drone == true, "has_drone flag must be true")
	assert(game.companion_drone.enabled, "Selecting a Drone in Equipment must enable it immediately")
	print("[PASS] Scout Drone unlocked and equipped from Drones tab! Coins remaining: ", game.coins)
	
	# -----------------------------------------------------------------
	# 5. Start Game: Verify equipped drone goes into battle
	# -----------------------------------------------------------------
	game.new_run(55555)
	await process_frame
	assert(game.has_drone == true, "Run starts with drone equipped from Equipment screen")
	assert(game.companion_drone != null and game.companion_drone.enabled, "Companion drone is enabled in run")
	assert(game.companion_drone.drone_type == "scout", "Drone in battle matches equipped scout drone")
	print("[PASS] Equipped Scout Drone successfully carried into combat map!")
	
	# -----------------------------------------------------------------
	# 6. Switch to Bomb Drone and enter combat
	# -----------------------------------------------------------------
	game.coins = 150
	var unlocked_ok = game.unlock_drone("bomb")
	print("Unlocked ok: ", unlocked_ok, " selected_drone: ", game.selected_drone, " coins: ", game.coins, " meta: ", game.profile.meta)
	assert(game.selected_drone == "bomb", "Bomb drone equipped")
	
	game.new_run(66666)
	await process_frame
	assert(game.companion_drone.drone_type == "bomb", "New run adopts newly equipped bomb drone")
	print("[PASS] Swapping equipped Drone to Bomb Drone correctly enters combat map!")
	
	print("[ALL EQUIPMENT 2-TAB & DRONE TESTS PASSED!]")
	game.queue_free()
	quit(0)
