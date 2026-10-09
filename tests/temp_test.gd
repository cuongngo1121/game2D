extends SceneTree

func _init() -> void:
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	
	game.new_run(1111)
	
	# Complete room 0
	game.combat_active = true
	game.enemies.clear()
	game.complete_room()
	await process_frame
	
	game.choose_upgrade("repair")
	await process_frame
	game.resume_game()
	await process_frame
	
	var target = game.room_entry_position(1)
	var pos = game.player.position
	print("Starting move. From: ", pos, " To: ", target)
	for step in range(200):
		var dir = (target - pos).normalized()
		var next_pos = game.move_actor(pos, dir * 20.0, game.player.radius)
		if next_pos.distance_squared_to(pos) < 0.001:
			print("STOPPED/BLOCKED at step ", step, " pos: ", pos)
			break
		pos = next_pos
		game.player.position = pos
		game.update_route_exploration()
		if game.room_index != 0:
			print("Entered room: ", game.room_index, " at step ", step, " pos: ", pos, " combat_active: ", game.combat_active)
			break
			
	print("Done simulation. Player room: ", game.room_index, " combat_active: ", game.combat_active, " pending: ", game.combat_chamber_pending)
	game.queue_free()
	quit(0)
