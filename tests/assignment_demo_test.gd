extends SceneTree
## Teacher-requirements demo: exercise the real debug-room systems without a
## campaign checkpoint or a manually played desktop session.

const MainScene = preload("res://scenes/main.tscn")

var game
var checks := 0
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
	var checkpoint_before: Dictionary = game.profile.checkpoint.duplicate(true)
	game.start_assignment_demo()
	_check(game.is_assignment_demo() and game.debug_session and game.state == "playing", "Debug Zones starts a self-contained teacher demo session")
	_check(not game.is_open_route_stage() and game.walkable_regions.size() == 1, "Demo owns one broad standalone test room instead of changing an authored map route")
	_check(game.profile.checkpoint == checkpoint_before, "Entering the teacher demo leaves the campaign checkpoint unchanged")
	_check(game.assignment_demo_props.size() == 3 and game.enemies.units.size() == 3, "Demo loads exactly X/Y/Z collision objects and live NPC targets")
	var visible_world_size: Vector2 = Vector2(1280, 720) / game.player.follow_camera.zoom
	var visible_world: Rect2 = Rect2(game.player.position - visible_world_size * 0.5, visible_world_size)
	var intruder_visible := false
	for unit in game.enemies.units:
		if int(unit.id) == game.assignment_intruder_id:
			intruder_visible = visible_world.has_point(unit.pos)
			break
	_check(intruder_visible and visible_world.encloses(game.assignment_forbidden_zone), "NPC Cảnh báo and the complete forbidden zone are visible together when the demo opens")
	_check(_hud_button("SFX · TẮT") != null and _hud_button("NHẠC · TẮT") != null, "HUD exposes one SoundOff action and one MusicOff action at fixed positions")
	_test_sandbox_hud_control_layout()

	game.toggle_short_effects()
	_check(not game.short_effects_enabled() and _hud_button("SFX · TẮT") == null, "SoundOff disables short effects and is replaced by SoundOn in the same HUD control")
	game.toggle_short_effects()
	_check(game.short_effects_enabled() and _hud_button("SFX · TẮT") != null, "SoundOn restores short effects")
	game.toggle_background_music()
	_check(not game.background_music_enabled() and _hud_button("NHẠC · TẮT") == null, "MusicOff mutes background music without stopping the gameplay clock")
	game.toggle_background_music()
	_check(game.background_music_enabled() and _hud_button("NHẠC · TẮT") != null, "MusicOn restores background music")

	_test_space_dash_does_not_reset_demo()
	_test_attacks_and_defenses()
	_test_collision_objects()
	_test_forbidden_zone_warning()
	_test_forbidden_zone_reentry_warning()
	game.return_to_menu()
	_check(not game.assignment_demo_active and game.state == "menu", "Leaving the demo clears its isolated mode")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("ASSIGNMENT DEMO PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("ASSIGNMENT DEMO FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)


func _test_attacks_and_defenses() -> void:
	var shots_before: int = game.projectiles.count()
	game.weapon_system.cooldown = 0.0
	_check(game.trigger_assignment_attack("pistol") and game.projectiles.count() > shots_before, "Attack 1 fires a live Pulse Pistol projectile")
	game.weapon_system.cooldown = 0.0
	shots_before = game.projectiles.count()
	_check(game.trigger_assignment_attack("glitch") and game.projectiles.count() > shots_before, "Attack 2 fires a live explosive missile projectile")
	game.weapon_system.cooldown = 0.0
	_check(game.trigger_assignment_attack("beam") and not game.weapon_system.beam_lines.is_empty(), "Attack 3 fires a live Prism Beam")
	game.player.position = Vector2(1430, 470)
	_check(game.activate_assignment_shield() and game.assignment_shield_time > 0.0 and game.player.invulnerable >= 3.0, "Defense 1 raises a timed shield and protects the player")
	_check(game.activate_assignment_emp() and game.assignment_emp_time > 0.0 and _any_enemy_disabled(), "Defense 2 emits EMP and temporarily disables nearby NPCs")


func _test_space_dash_does_not_reset_demo() -> void:
	game.reset_assignment_demo()
	var props_before: Array = game.assignment_demo_props.duplicate(true)
	var intruder_before: int = game.assignment_intruder_id
	var enemy_count_before: int = game.enemies.units.size()
	game.player.dash_cooldown = 0.0
	var reset_button := _hud_button("N · LÀM LẠI")
	_check(reset_button.focus_mode == Control.FOCUS_NONE, "In-game Reset control cannot retain keyboard focus and capture Space")
	var space_event := InputEventKey.new()
	space_event.keycode = KEY_SPACE
	space_event.physical_keycode = KEY_SPACE
	space_event.pressed = true
	# Reproduce the desktop route. Gameplay HUD buttons do not retain focus, so
	# Space always reaches Dash rather than activating Reset after a HUD click.
	root.push_input(space_event, true)
	space_event.pressed = false
	root.push_input(space_event, true)
	_check(game.player.dash_time > 0.0 and game.is_assignment_demo() and game.assignment_demo_props == props_before and game.assignment_intruder_id == intruder_before and game.enemies.units.size() == enemy_count_before, "Space starts Dash without rebuilding the teacher demo session")


func _test_sandbox_hud_control_layout() -> void:
	var top_row: Array[Button] = [_hud_button("SFX · TẮT"), _hud_button("1 · ĐẠN"), _hud_button("2 · TÊN LỬA"), _hud_button("3 · TIA")]
	var bottom_row: Array[Button] = [_hud_button("NHẠC · TẮT"), _hud_button("F · KHIÊN"), _hud_button("H · EMP"), _hud_button("N · LÀM LẠI")]
	var expected_x: Array[float] = [28.0, 188.0, 348.0, 508.0]
	var layout_is_clear := true
	for row in [top_row, bottom_row]:
		for index in range(row.size()):
			var control: Button = row[index]
			var expected_y := 100.0 if row == top_row else 168.0
			layout_is_clear = layout_is_clear and control != null and is_equal_approx(control.position.x, expected_x[index]) and is_equal_approx(control.position.y, expected_y) and is_equal_approx(control.size.x, 140.0) and is_equal_approx(control.size.y, 48.0)
			if index > 0:
				var previous: Button = row[index - 1]
				layout_is_clear = layout_is_clear and control.position.x - (previous.position.x + previous.size.x) >= 20.0
	for child in game.ui.hud.get_children():
		if child is Label and child.text == "BÀI DEMO":
			layout_is_clear = false
	_check(layout_is_clear, "Sandbox HUD uses equal 140x48 controls in a two-row grid with at least 20 px gaps")


func _test_collision_objects() -> void:
	var object_x := _demo_prop("X")
	var credits_before: int = game.coins
	game.player.position = object_x.pos
	game.update_assignment_demo_collisions()
	_check(game.coins == credits_before + 20 and game.assignment_speed_boost_time > 0.0, "X collision grants credits and a temporary move-speed increase")
	var object_y := _demo_prop("Y")
	game.player.shield = 0.0
	game.player.hp = 42.0
	game.player.position = object_y.pos
	game.update_assignment_demo_collisions()
	_check(game.player.shield > 0.0 and game.player.hp > 42.0, "Y collision restores both shield and HP")
	var object_z := _demo_prop("Z")
	game.player.shield = 50.0
	game.player.hp = 90.0
	game.player.position = object_z.pos
	game.update_assignment_demo_collisions()
	_check(game.player.shield < 50.0 and game.player.hp < 90.0 and game.assignment_slow_time > 0.0, "Z collision explodes, damages HP/shield, and applies a slow")


func _test_forbidden_zone_warning() -> void:
	game.reset_assignment_demo()
	# Keep A outside and away from the red-zone edge. This isolates one natural
	# first crossing; re-entry is verified independently below.
	game.player.position = Vector2(1600, 720)
	# Drive the same EnemySystem movement loop the player sees. Do not teleport the
	# NPC into the zone: this catches a missing route/waypoint regression.
	for index in range(42):
		game.enemies.update(0.1)
		game.update_assignment_demo(0.1)
	_check(game.assignment_intruder_completed_intro_route and game.assignment_warning_count == 4, "NPC visibly walks into the forbidden area and triggers exactly four consecutive warning cues")


func _test_forbidden_zone_reentry_warning() -> void:
	game.reset_assignment_demo()
	var intruder: Dictionary = _assignment_intruder()
	intruder.pos = game.assignment_forbidden_zone.get_center()
	for index in range(50):
		game.update_assignment_demo(0.1)
	var first_entry_warning_count: int = game.assignment_warning_count
	intruder.pos = game.assignment_forbidden_zone.end + Vector2(80, 80)
	game.update_assignment_demo(0.1)
	intruder.pos = game.assignment_forbidden_zone.get_center()
	for index in range(50):
		game.update_assignment_demo(0.1)
	_check(first_entry_warning_count == 4 and game.assignment_warning_count == first_entry_warning_count + 4, "NPC leaving then re-entering the forbidden area emits a new four-cue warning")


func _assignment_intruder() -> Dictionary:
	for unit in game.enemies.units:
		if int(unit.get("id", -1)) == game.assignment_intruder_id:
			return unit
	return {}


func _demo_prop(id: String) -> Dictionary:
	for prop in game.assignment_demo_props:
		if str(prop.get("id", "")) == id:
			return prop
	return {}


func _any_enemy_disabled() -> bool:
	for unit in game.enemies.units:
		if float(unit.get("exposed", 0.0)) > 0.0:
			return true
	return false


func _hud_button(text_value: String) -> Button:
	for child in game.ui.hud.get_children():
		if child is Button and child.text == text_value:
			return child
	return null


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
