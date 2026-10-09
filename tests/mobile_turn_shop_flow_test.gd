extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Mobile Optimization & Turn-Based Shop Flow Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	
	await process_frame
	await process_frame
	
	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.profile.meta.has_drone = false
	game.coins = 200
	game.ui.show_unlocks("drones")
	await process_frame
	var plasma_button := game.ui.overlay.get_node_or_null("Armory_DroneCardButton_plasma") as Button
	assert(plasma_button != null and not plasma_button.disabled, "Plasma Drone must be selectable from Equipment")
	plasma_button.emit_signal("pressed")
	await process_frame
	assert(game.selected_drone == "plasma", "Selecting Plasma in Equipment must equip it")
	assert(game.companion_drone.enabled, "Selecting a Drone in Equipment must enable it by default")
	game.new_run(12345)
	assert(game.companion_drone.enabled, "Equipped Drone must remain enabled when the run starts")
	assert(game.state == "playing", "Game should start in playing state")
	
	# 1. Verify HUD Shop Button is Touch-First & Mobile Optimized
	var shop_btn = game.ui.hud.get_node_or_null("Gameplay_ShopButton") as Button
	assert(shop_btn != null, "HUD must have Gameplay_ShopButton for mobile touch")
	assert(shop_btn.text == "🛒 CỬA HÀNG", "HUD shop button should have mobile-friendly text without keyboard hints")
	print("[PASS] Mobile HUD Shop button present with clean touch label: ", shop_btn.text)
	
	# 2. Touch HUD Shop Button in safe moment (combat_active = false) to open Cyber Shop
	game.combat_active = false
	shop_btn.emit_signal("pressed")
	await process_frame
	assert(game.state == "shop", "Tapping HUD shop button must open Cyber Shop")
	assert(game.ui.overlay.visible == true, "Cyber Shop overlay must be visible")
	print("[PASS] Tapping HUD Shop button successfully opened Cyber Shop")
	
	# 3. Confirm the Cyber Shop no longer sells or toggles Drones.
	game.coins = 200
	game.ui.show_cyber_shop()
	await process_frame
	for child in game.ui.overlay.get_children():
		if child is Button:
			assert(child.text != "MUA 60 🪙", "Cyber Shop must not sell the Drone")
	assert(game.has_drone and game.companion_drone.enabled, "Equipped Drone must stay enabled in the Cyber Shop")
	var continue_button: Button = null
	for child in game.ui.overlay.get_children():
		if child is Button and child.text.contains("TIẾP TỤC CHIẾN ĐẤU"):
			continue_button = child
			break
	assert(continue_button != null, "Cyber Shop must retain its continue button")
	print("[PASS] Cyber Shop has no Drone purchase and keeps the equipped Drone enabled")
	
	# 4. Tap Resume Button in Shop
	continue_button = null
	for child in game.ui.overlay.get_children():
		if child is Button and child.text.contains("TIẾP TỤC CHIẾN ĐẤU"):
			continue_button = child
			break
	assert(continue_button != null, "Cyber Shop must expose its continue button")
	continue_button.emit_signal("pressed")
	await process_frame
	assert(game.state == "playing", "Resuming from shop returns to playing state")
	assert(not game.ui.overlay.visible, "Overlay closes on resume")
	print("[PASS] Resume button returns player to active combat")
	
	# 5. Test End of Monster Turn -> Cyber Shop Auto Open
	# Simulate clearing a room and choosing an upgrade
	game.combat_active = true
	game.enemies.clear()
	game.complete_room()
	await process_frame
	assert(game.state == "reward", "First clear offers reward cards")
	
	# Player selects reward upgrade -> Flow should automatically open Cyber Shop!
	game.choose_upgrade("repair")
	await process_frame
	assert(game.state == "shop", "After choosing reward upgrade, game automatically opens Cyber Shop for mobile upgrades!")
	print("[PASS] Turn/Room clear seamlessly opens Cyber Shop to spend farmed coins!")
	
	# 6. Subsequent cleared room auto opens Cyber Shop directly
	game.resume_game()
	await process_frame
	assert(game.state == "playing", "Returned to playing")
	
	# Complete room again (already rewarded)
	game.combat_active = true
	game.complete_room()
	await process_frame
	assert(game.state == "shop", "Subsequent turn clear directly opens Cyber Shop")
	print("[PASS] Subsequent turn clear opens Cyber Shop directly")
	
	print("[ALL MOBILE OPTIMIZATION & TURN-BASED SHOP FLOW TESTS PASSED!]")
	quit(0)
