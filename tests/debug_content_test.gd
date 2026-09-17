extends SceneTree
## Integration coverage for the developer-only fast-test menu and its data state.

const MainScene = preload("res://scenes/main.tscn")

var game
var checks: int = 0
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
	_check(game.DEBUG_TEST_CONTENT_ENABLED, "Developer test-content switch is enabled for this build")
	var weapon_ids: Array[String] = game.all_weapon_ids()
	_check(weapon_ids.size() == game.content.weapons.size(), "Every authored weapon has a debug-unlock identifier")
	for id in weapon_ids:
		_check(game.profile.meta.unlocked.has(id), "%s is unlocked in the active debug profile" % id)
	game.select_starter("arc")
	_check(game.starter == "arc" and game.profile.meta.starter == "arc", "An unlocked armory weapon can be selected as the next run's starter")
	game.select_starter("pistol")
	_check(game.starter == "arc", "The fixed slot-1 pistol cannot create a duplicate starter loadout")
	game.new_run(4782)
	var checkpoint_before: Dictionary = game.profile.checkpoint.duplicate(true)
	var meta_before: Dictionary = game.profile.meta.duplicate(true)
	game.return_to_menu()
	game.start_debug_stage(3)
	_check(game.state == "playing" and game.stage_index == 3 and game.room_index == 0, "Debug zone selection starts the selected area in its first room")
	var boundary_toggle_key := InputEventKey.new()
	boundary_toggle_key.physical_keycode = KEY_Y
	boundary_toggle_key.pressed = true
	_check(not game.show_route_boundaries and not game.show_collision_boundaries, "Gameplay starts with route and collision boundary overlays hidden")
	game._unhandled_input(boundary_toggle_key)
	_check(game.show_route_boundaries and not game.show_collision_boundaries, "Y shows the cyan/purple route frame without enabling collision data")
	game._unhandled_input(boundary_toggle_key)
	_check(not game.show_route_boundaries and not game.show_collision_boundaries, "Y hides the cyan/purple route frame again without changing collision data")
	_check(game.debug_session and game.is_debug_map_tour() and game.tutorial_step == 4 and game.player.visible and not game.graph.is_empty(), "Debug zone starts an isolated map tour that skips onboarding and rebuilds player/map state")
	_check(not game.combat_active and game.enemies.living_count() == 0, "Debug map tour starts without combat or spawned enemies")
	var barrier_preview_key := InputEventKey.new()
	barrier_preview_key.physical_keycode = KEY_O
	barrier_preview_key.pressed = true
	game._unhandled_input(barrier_preview_key)
	_check(game.debug_show_combat_barriers and not game.combat_active and not game.active_combat_barrier_rects().is_empty(), "O shows the current room's combat-gate models in an enemy-free Debug Map")
	game._unhandled_input(barrier_preview_key)
	_check(not game.debug_show_combat_barriers and game.active_combat_barrier_rects().is_empty(), "O hides Debug Map combat-gate preview again without starting combat")
	_check(game.profile.checkpoint == checkpoint_before, "Selected debug zone leaves the campaign checkpoint unchanged")
	game.ui.show_map()
	var map_jump_buttons: int = 0
	var boss_jump: Button
	for child in game.ui.overlay.get_children():
		if child is Button and child.text.contains("ĐI TỚI") and not child.disabled:
			map_jump_buttons += 1
			if child.text.begins_with(game.room_name(5)):
				boss_jump = child
	_check(map_jump_buttons == 6, "Debug map exposes an enabled direct jump for every room")
	_check(boss_jump != null, "Debug map exposes a direct boss-room jump")
	if boss_jump != null:
		boss_jump.emit_signal("pressed")
		_check(game.room_index == 5 and not game.combat_active and game.enemies.living_count() == 0, "Debug map boss jump remains enemy-free and non-combat")
	game.ui.show_debug_zones()
	var zone_buttons: int = 0
	for child in game.ui.overlay.get_children():
		if child is Button and child.text == "VÀO TEST":
			zone_buttons += 1
	_check(zone_buttons == game.content.stages.size(), "Debug menu exposes one direct-entry action for every authored area")
	for stage in range(game.content.stages.size()):
		game.start_debug_stage(stage)
		if stage <= 4:
			_check(game.open_route_rooms() == [0, 1, 2, 3, 4, 5], "Debug map opens every connected room in Area %d" % (stage + 1))
		var room_wave_key := InputEventKey.new()
		room_wave_key.physical_keycode = KEY_G
		room_wave_key.pressed = true
		game._unhandled_input(room_wave_key)
		var normal_wave_count: int = game.enemies.units.size()
		_check(game.room_index == 0 and game.combat_active and normal_wave_count > 0 and game.enemies._waves_left == 0, "Area %d G starts exactly one ordinary Combat 1 wave, not a full multi-wave campaign encounter" % (stage + 1))
		_check(not game.active_combat_barrier_rects().is_empty(), "Area %d G activates the same Combat 1 corridor gates used by normal gameplay" % (stage + 1))
		game._unhandled_input(room_wave_key)
		_check(game.enemies.units.size() == normal_wave_count and game.combat_active, "Repeated G cannot stack or reset an active Area %d debug room wave" % (stage + 1))
		game.enemies.clear()
		game.complete_room()
		_check(not game.combat_active and game.state == "playing" and game.active_combat_barrier_rects().is_empty(), "Area %d debug room-wave completion reopens gates without rewards or campaign progression" % (stage + 1))
		# This is the live tester path: physically reach the boss chamber from the
		# connected route, then request the portal preview with T.
		game.player.position = game.boss_spawn_position()
		_check(game.route_room_at_position(game.player.position, game.player.radius) == 5, "Area %d boss centre belongs to the debug boss room" % (stage + 1))
		var portal_preview_key := InputEventKey.new()
		portal_preview_key.physical_keycode = KEY_T
		portal_preview_key.pressed = true
		game._unhandled_input(portal_preview_key)
		var triggered_gate := _debug_exit_portal()
		_check(not triggered_gate.is_empty() and triggered_gate.pos.distance_to(game.boss_spawn_position()) < 1.0, "T shows the shared portal at the Area %d debug boss centre" % (stage + 1))
		_check(is_zero_approx(game.exit_portal_appear_progress()), "T restarts the Area %d debug portal reveal animation" % (stage + 1))
		var boss_combat_key := InputEventKey.new()
		boss_combat_key.physical_keycode = KEY_U
		boss_combat_key.pressed = true
		game._unhandled_input(boss_combat_key)
		var boss: Dictionary = _active_boss()
		_check(_debug_exit_portal().is_empty(), "U hides the portal so it cannot cover the Area %d boss combat" % (stage + 1))
		_check(not boss.is_empty() and str(boss.get("kind", "")) == "boss%d" % stage and boss.pos.distance_to(game.boss_spawn_position()) < 1.0, "U spawns Area %d's authored boss at the verified boss-room centre" % (stage + 1))
		_check(not boss.is_empty() and is_equal_approx(float(boss.get("radius", 0.0)), game.enemies.BOSS_COLLISION_RADIUS), "Area %d boss uses the shared 150 percent collision radius" % (stage + 1))
		_check(is_equal_approx(game.enemies.BOSS_RENDER_SIZE, 120.0), "Area %d boss uses the shared 120px 150 percent render size" % (stage + 1))
		_check(game.combat_active and game.enemies.units.size() == 1 and not bool(boss.get("debug_preview", false)), "Area %d U starts a real isolated boss combat, not an inert preview" % (stage + 1))
		_check(game.player.position.distance_to(boss.pos) > boss.radius + game.player.radius and game.is_combat_position(game.player.position, game.player.radius), "Area %d combat starts the tester at a safe legal offset from the boss" % (stage + 1))
		game._unhandled_input(boss_combat_key)
		_check(game.enemies.units.size() == 1 and game.combat_active, "Repeated U cannot stack or reset an active Area %d boss combat" % (stage + 1))
		game._unhandled_input(portal_preview_key)
		_check(_debug_exit_portal().is_empty() and game.combat_active, "T cannot replace an active Area %d boss combat with a gate" % (stage + 1))
		# Skip the opening telegraph only in this headless assertion, then exercise
		# the same attack and hurt state changes the real combat loop uses.
		game.enemies._grace = 0.0
		boss["spawn_grace"] = 0.0
		game.enemies.on_beat(-int(boss.id) * 2)
		game.enemies.update(0.01)
		boss = _active_boss()
		_check(float(boss.get("attack_anim", 0.0)) > 0.0 and str(boss.get("anim_state", "")) == "attack" and not game.enemies.hazards.is_empty(), "Area %d combat executes the boss attack animation and telegraphed hazard" % (stage + 1))
		game.enemies.damage_enemy(int(boss.id), 1.0)
		game.enemies.update(0.01)
		boss = _active_boss()
		_check(float(boss.get("hurt_anim", 0.0)) > 0.0 and str(boss.get("anim_state", "")) == "hurt", "Area %d combat executes the boss hurt animation from real damage" % (stage + 1))
		game.enemies.damage_enemy(int(boss.id), float(boss.hp))
		var authored_death: bool = game.enemies._boss_animation_textures.has("boss%d:death" % stage)
		_check(game.enemies.living_count() == 0 and (not authored_death or not game.enemies._death_animations.is_empty()), "Area %d combat removes the boss after a real defeat and plays a death animation whenever that boss supplies one" % (stage + 1))
		game.enemies.update(game.enemies.clear_animation_delay() + 0.01)
		game.complete_room()
		_check(not game.combat_active and game.state == "playing" and game.enemies.living_count() == 0 and not _debug_exit_portal().is_empty(), "Area %d debug boss completion returns safely to a repeatable gate state" % (stage + 1))
		for room in range(6):
			game.travel(room)
			_check(game.state == "playing" and game.stage_index == stage and game.room_index == room, "Debug map jumps to Area %d room %d" % [stage + 1, room + 1])
			_check(not game.combat_active and game.enemies.living_count() == 0, "Debug map keeps Area %d room %d free of enemies" % [stage + 1, room + 1])
			if room == 5:
				var gate := _debug_exit_portal()
				_check(not gate.is_empty() and gate.pos.distance_to(game.boss_spawn_position()) < 1.0, "Debug map displays the shared gate at the centre of Area %d's boss room" % (stage + 1))
				_check(is_zero_approx(game.exit_portal_appear_progress()), "Debug Area %d gate begins its reveal from the closed-core frame" % (stage + 1))
				game._process(0.42)
				_check(game.exit_portal_appear_progress() > 0.0 and game.exit_portal_appear_progress() < 1.0, "Debug Area %d gate visibly reveals before its idle loop" % (stage + 1))
				game._process(1.0)
				_check(is_equal_approx(game.exit_portal_appear_progress(), 1.0), "Debug Area %d gate reaches its stable idle animation" % (stage + 1))
				game.player.position = gate.pos
				game.interact()
				_check(game.stage_index == stage and game.room_index == 5 and game.state == "playing", "Debug gate in Area %d remains a display-only test prop" % (stage + 1))
	game.end_run(true)
	_check(game.profile.checkpoint == checkpoint_before and game.profile.meta == meta_before, "Completing a debug session cannot overwrite campaign progress or award permanent stats")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("DEBUG CONTENT PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("DEBUG CONTENT FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _debug_exit_portal() -> Dictionary:
	for portal in game.portals:
		if str(portal.get("kind", "")) == "debug_exit":
			return portal
	return {}

func _active_boss() -> Dictionary:
	for unit in game.enemies.units:
		if bool(unit.get("boss", false)):
			return unit
	return {}
