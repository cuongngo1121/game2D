extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Drone Continue Persistence Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)

	await process_frame
	await process_frame

	game.profile.meta.unlocked_drones = []
	game.profile.meta.selected_drone = ""
	game.profile.meta.has_drone = false
	game.new_run(12345)
	game.coins = 200
	assert(game.buy_drone_companion() == true, "Drone purchase must succeed before save")
	assert(game.has_drone == true, "Drone should be owned after purchase")
	assert(game.selected_drone == "plasma", "Selected drone should be plasma")
	game.save_checkpoint()

	game.has_drone = false
	game.selected_drone = ""
	game.profile.meta.has_drone = false
	game.profile.meta.selected_drone = ""
	if game.companion_drone != null:
		game.companion_drone.enabled = false
		game.companion_drone.visible = false

	game.continue_run()
	assert(game.has_drone == true, "Continue-from-menu must restore the purchased drone")
	assert(game.selected_drone == "plasma", "Continue-from-menu must restore the selected drone type")
	print("[PASS] Drone persists through save/continue flow")

	game.profile.meta.unlocked_drones.append_array(["bomb", "scout"])
	game.select_drone("bomb", false)
	game.save_checkpoint()
	game.ui.show_unlocks("drones")
	await process_frame
	var scout_button := game.ui.overlay.get_node_or_null("Armory_DroneCardButton_scout") as Button
	assert(scout_button != null and scout_button.text == "CHỌN TRANG BỊ", "Unlocked Scout should be selectable from Armory")
	scout_button.emit_signal("pressed")
	await process_frame
	assert(game.selected_drone == "scout", "Armory should select Scout instead of Bomb")
	game.return_to_menu()
	game.continue_run()
	assert(game.selected_drone == "scout", "Continue must keep the newly selected Scout, not the checkpoint's old Bomb")
	assert(game.companion_drone.drone_type == "scout", "Resumed companion must use the newly selected Scout")
	print("[PASS] New Armory selection overrides checkpoint drone on continue")
	quit(0)
