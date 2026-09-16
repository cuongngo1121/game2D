extends SceneTree
## Actual main scene integration. Controlled damage verifies flow, not player skill or Android performance.

const MainScene = preload("res://scenes/main.tscn")
const Graph = preload("res://scripts/core/level_graph.gd")
const Save = preload("res://scripts/core/save_store.gd")

var game
var checks: int = 0
var failures: Array[String] = []

# Luminous Grove Combat 1 has a broad, obstacle-free floor at this world point.
# Keep combat/input checks inside its real connected-route collision instead of
# using the retired 1280 × 720 rectangular arena coordinates.
const SANDBOX_ORIGIN := Vector2(300.0, 2580.0)

func _sandbox_point(offset: Vector2 = Vector2.ZERO) -> Vector2:
	return SANDBOX_ORIGIN + offset

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_graphs()
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.controls.set_process(false)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.settings.music = 0.0
	game.settings.sfx = 0.0
	game.audio.set_volumes(0.0, 0.0)
	_check(game.state == "menu" and game.ui.overlay.visible, "Actual scene starts with menu and complete composition")
	_test_menu_checkpoint_actions()
	_test_player()
	_test_touch()
	_test_weapons()
	_test_upgrades()
	_test_combat_gate_lifecycle()
	_test_level_one_backtracking()
	_test_level_two_backtracking()
	_test_level_three_backtracking()
	_test_level_four_backtracking()
	_test_later_room_combat_lifecycle()
	_test_progression()
	_test_checkpoint()
	_test_death_replay()
	await process_frame
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("GAMEPLAY PASS: %d checks; 5,000 seeded graphs; all five stages via controlled encounter clears; actual player/input/weapons/UI flow" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _test_graphs() -> void:
	var all_connected: bool = true
	var deterministic: bool = true
	var all_diverse: bool = true
	for seed_value in range(1000):
		for stage in range(5):
			var graph: Dictionary = Graph.generate(seed_value, stage)
			all_connected = all_connected and Graph.reachable(graph).size() == 6
			deterministic = deterministic and graph == Graph.generate(seed_value, stage)
			all_diverse = all_diverse and graph.templates.has(0) and graph.templates.has(1) and graph.templates.has(2)
	_check(all_connected, "All 5,000 seed/stage graphs connect all six mandatory rooms")
	_check(deterministic, "All 5,000 graphs reproduce exactly from seed and stage")
	_check(all_diverse, "Every graph uses all three combat room templates")
	var graph: Dictionary = Graph.generate(929, 0)
	_check(graph.branch == 1 and graph.links[1].has(4), "Stage 1 keeps support as the Combat 2 branch shown on its authored route")
	_check(not Graph.can_enter(0, 1, [], graph), "Locked uncleared combat prevents graph travel")
	_check(not Graph.can_enter(3, 5, [0, 1, 3], graph), "Boss entry requires all four combat rooms")
	_check(Graph.can_enter(3, 5, [0, 1, 2, 3], graph), "Boss entry opens after mandatory rooms")
	_check(not Graph.can_enter(0, 5, [0, 1, 2, 3], graph), "Travel cannot jump to a non-neighbor")

func _visible_menu_button(label_text: String) -> Button:
	for child in game.ui.overlay.get_children():
		if not (child is Button):
			continue
		var candidate := child as Button
		if candidate.visible and candidate.text == label_text:
			return candidate
	return null

func _test_menu_checkpoint_actions() -> void:
	game.profile.checkpoint = {"seed": 913}
	var recoverable_checkpoint: Dictionary = game.profile.checkpoint.duplicate(true)
	game.ui.show_menu()
	var continue_button := _visible_menu_button("TIẾP TỤC")
	var new_run_button := _visible_menu_button("LƯỢT MỚI")
	_check(continue_button != null and new_run_button != null, "Checkpoint menu distinguishes continue from starting a new run")
	if new_run_button != null:
		new_run_button.emit_signal("pressed")
	_check(not game.profile.checkpoint.is_empty(), "New-run confirmation preserves the checkpoint until the player confirms")
	_check(_visible_menu_button("Giữ lượt đang dở") != null and _visible_menu_button("Bắt đầu lượt mới") != null, "New-run action opens an explicit recovery confirmation")
	var confirm_button := _visible_menu_button("Bắt đầu lượt mới")
	if confirm_button != null:
		confirm_button.emit_signal("pressed")
	_check(game.state == "playing" and game.profile.checkpoint != recoverable_checkpoint, "Confirmed new run replaces the old checkpoint only after explicit consent")
	game.return_to_menu()
	game.profile.checkpoint = {}
	game.ui.show_menu()
	_check(_visible_menu_button("CHƠI") != null and _visible_menu_button("LƯỢT MỚI") == null, "Fresh menu keeps the compact new-player start path")

func _sandbox() -> void:
	game.new_run(77991)
	# General combat checks use the wide opening in Luminous Grove Combat 1. It is
	# a real route room, so collision-sensitive weapons and touch movement remain
	# covered after all five areas adopted connected maps.
	game.stage_index = 2
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	game.enemies.clear()
	game.projectiles.clear()
	game.obstacles.clear()
	game.weapon_system.reset()
	game.controls.reset()
	game.player.position = SANDBOX_ORIGIN
	game.player.hp = 100.0
	game.player.shield = 50.0
	game.player.energy = 100.0
	game.player.invulnerable = 0.0
	game.player.resonance = 0.0
	game.player.perfect_beat = -999
	game.player.dash_time = 0.0
	game.player.dash_cooldown = 0.0
	game.player.move_direction = Vector2.ZERO
	game.player.aim_direction = Vector2.RIGHT
	game.player.last_move = Vector2.RIGHT
	game.combat_active = true
	game.state = "playing"
	game.upgrades.clear()
	game.player.refresh_stats()
	game.rhythm._elapsed = 0.0
	game.rhythm.offset_ms = 0.0
	game.rhythm.beat_index = 0
	game.rhythm._paused = false
	_check(game.is_combat_position(SANDBOX_ORIGIN, game.player.radius), "Combat fixture begins inside the authored Luminous Grove floor")

func _target(at: Vector2, hp: float = 5000.0) -> Dictionary:
	game.enemies._spawn("turret", at, false)
	var target: Dictionary = game.enemies.units.back()
	target.hp = hp
	target.max_hp = hp
	target.speed = 0.0
	target.spawn_grace = 0.0
	return target

func _test_player() -> void:
	_sandbox()
	_check(game.player.pixel_character_enabled, "Overhead player animation sheets load as valid 32 px resources")
	_check(game.player.visual_animation() == "idle", "Stationary player selects overhead idle animation")
	game.player.play_attack_animation()
	_check(game.player.visual_animation() == "attack", "Stationary fire selects the dedicated attack animation")
	game.player.move_direction = Vector2.RIGHT
	_check(game.player.visual_animation() == "run_attack", "Moving during the active firing window selects combined run-attack animation")
	game.player.attack_animation_time = 0.0
	_check(game.player.visual_animation() == "run", "Run-attack returns to run after the firing window closes")
	game.player.take_damage(18.0)
	_check(game.player.hp == 100.0 and game.player.shield == 32.0, "Actual player absorbs damage with shield first")
	game.player.take_damage(80.0)
	_check(game.player.hp == 100.0 and game.player.shield == 32.0, "Actual player i-frames reject immediate duplicate damage")
	game.player.invulnerable = 0.0
	game.player.take_damage(42.0)
	_check(game.player.hp == 90.0 and game.player.shield == 0.0, "Damage overflow crosses shield into health exactly once")
	game.player.update(3.0)
	_check(game.player.shield == 0.0, "Shield does not regenerate before its delay")
	game.player.update(1.1)
	_check(game.player.shield > 0.0 and game.player.regen_announced, "Shield regeneration begins after delay with feedback")
	game.player.energy = 0.0
	game.player.update(1.0)
	_check(is_equal_approx(game.player.energy, 5.0), "Base energy regenerates five units per second")
	game.player.resonance = 0.0
	game.player.invulnerable = 0.0
	game.player.dash_cooldown = 0.0
	game.rhythm._elapsed = game.rhythm.beat_seconds() * 0.4
	_check(game.player.dash() and game.player.dash_time > 0.0, "Off-beat dash activates immediately without waiting")
	_check(game.player.resonance == 0.0, "Off-beat dash performs normally without perfect reward")
	_check(not game.player.dash(), "Dash cooldown rejects repeated activation")
	game.player.dash_cooldown = 0.0
	game.rhythm._elapsed = 0.0
	game.rhythm.beat_index = 0
	game.player.dash()
	_check(game.player.resonance == 18.0, "On-beat combat dash awards resonance")
	game.player.dash_cooldown = 0.0
	game.player.dash()
	_check(game.player.resonance == 18.0, "A beat cannot reward repeated forced dash calls")
	game.combat_active = false
	game.player.dash_cooldown = 0.0
	game.rhythm.beat_index = 1
	game.rhythm._elapsed = game.rhythm.beat_seconds()
	game.player.dash()
	_check(game.player.resonance == 18.0, "Safe-room dash does not farm resonance")
	game.combat_active = true
	game.player.position = _sandbox_point(Vector2(-22, 0))
	game.obstacles.append(Rect2(_sandbox_point(Vector2(0, -90)), Vector2(70, 170)))
	game.player.dash_direction = Vector2.RIGHT
	game.player.dash_time = 0.19
	game.player.update(0.19)
	_check(game.player.position.x <= SANDBOX_ORIGIN.x - 11.0, "Actual dash cannot cross cover")
	var hp: float = game.player.hp
	game.player.invulnerable = 0.1
	game.player.take_damage(50.0)
	_check(game.player.hp == hp, "Dash invulnerability uses the same player damage gate")
	game.obstacles.clear()
	game.player.position = SANDBOX_ORIGIN
	var target: Dictionary = _target(_sandbox_point(Vector2(100, 0)))
	game.player.resonance = 99.0
	_check(not game.player.pulse() and target.hp == 5000.0, "Pulse cannot trigger below full resonance")
	for clearable in [true, false]:
		game.projectiles.spawn({"pos": _sandbox_point(Vector2(20, 0)), "vel": Vector2.ZERO, "enemy": true, "clearable": clearable})
	game.projectiles.spawn({"pos": _sandbox_point(Vector2(20, 0)), "vel": Vector2.ZERO, "enemy": false})
	game.projectiles.spawn({"pos": _sandbox_point(Vector2(300, 190)), "vel": Vector2.ZERO, "enemy": true})
	game.player.resonance = 100.0
	_check(game.player.pulse() and game.player.resonance == 0.0 and target.hp == 4905.0, "Actual Pulse consumes meter and applies its radial damage")
	_check(game.projectiles.count() == 3, "Pulse preserves friendly, uncleareable and distant projectiles")

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	game.controls._input(event)

func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	game.controls._input(event)

func _test_touch() -> void:
	_sandbox()
	# Desktop aim originates in viewport pixels, while Player.position is in the
	# scrolling world. Keep this explicit regression case off the viewport centre:
	# subtracting raw screen pixels from world coordinates produces a visibly
	# different firing angle once the follow camera is active.
	var mouse_point := Vector2(900, 210)
	Input.warp_mouse(mouse_point)
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.device = 0
	mouse_motion.position = mouse_point
	game.controls._input(mouse_motion)
	var expected_world_point: Vector2 = game.world.get_global_transform_with_canvas().affine_inverse() * mouse_point
	var expected_desktop_aim: Vector2 = (expected_world_point - game.player.position).normalized()
	var actual_desktop_aim: Vector2 = game.controls.aim_direction(game.player.position)
	_check(actual_desktop_aim.dot(expected_desktop_aim) > 0.999, "Desktop cursor aim converts viewport coordinates into the scrolling world before aiming")
	_touch(0, Vector2(150, 550), true)
	_drag(0, Vector2(220, 550))
	_touch(1, game.controls.button_centers.fire, true)
	_check(game.controls.movement().x > 0.9 and game.controls.firing(), "Two independent fingers move and fire simultaneously")
	var original: Vector2 = game.player.position
	game.player.update(0.1)
	_check(game.player.position.x > original.x, "Touch joystick moves actual player")
	game.player.dash_cooldown = 0.0
	_drag(1, game.controls.button_centers.dash)
	_check(game.player.dash_time > 0.0 and game.controls.firing(), "Right thumb slide fire-to-dash activates dash with brief continuous fire")
	_touch(0, Vector2(220, 550), false)
	_touch(1, game.controls.button_centers.dash, false)
	game.controls._process(0.4)
	_check(game.controls.movement() == Vector2.ZERO and not game.controls.firing(), "Finger release stops movement and firing after deliberate slide grace")
	_touch(0, Vector2(150, 550), true)
	_drag(0, Vector2(220, 550))
	_touch(1, game.controls.button_centers.fire, true)
	game.pause_game()
	_check(game.state == "paused" and game.controls.fingers.is_empty() and game.controls.movement() == Vector2.ZERO and not game.controls.firing(), "Pause clears held touch actions")
	var pos: Vector2 = game.player.position
	game._physics_process(1.0)
	_check(game.player.position == pos, "Pause stops actual physics progression")
	game.resume_game()
	_check(game.state == "playing" and game.enemies._grace >= 1.4 and game.player.invulnerable >= 1.4, "Resume restores explicit danger grace and i-frames")
	_touch(0, Vector2(150, 550), true)
	_drag(0, Vector2(220, 550))
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(game.state == "paused" and game.controls.stick_finger == -1, "Application pause clears fingers and requires explicit resume")
	game.resume_game()
	game.controls.is_touch = true
	game.controls.mouse_aim_active = false
	var mouse := InputEventMouseMotion.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	game.controls._input(mouse)
	_check(game.controls.is_touch and not game.controls.mouse_aim_active, "Synthetic mouse motion cannot switch touch aim mode")
	mouse.device = 0
	game.controls._input(mouse)
	_check(not game.controls.is_touch and game.controls.mouse_aim_active, "Real mouse motion enables PC aim")

func _test_weapons() -> void:
	for weapon in game.content.weapons:
		_sandbox()
		game.weapons = [weapon.id, "pistol"]
		game.active_slot = 0
		var distance: float = 220.0
		if weapon.id == "blade": distance = 65.0
		if weapon.id == "orbit": distance = 64.0
		var target: Dictionary = _target(_sandbox_point(Vector2(distance, 0)))
		var energy_before: float = game.player.energy
		_check(game.weapon_system.fire(), "%s accepts an immediate fire command" % weapon.id)
		_check(is_equal_approx(game.player.energy, energy_before - float(weapon.energy)), "%s spends the configured energy cost" % weapon.id)
		for frame in range(150):
			game.elapsed += 1.0 / 60.0
			game.weapon_system.update(1.0 / 60.0)
			game.projectiles.update(1.0 / 60.0)
		_check(target.hp < 5000.0, "%s real attack damages a target through its distinct behavior" % weapon.id)
	_sandbox()
	game.weapons = ["glitch", "rail"]
	game.active_slot = 0
	game.player.energy = 0.0
	var target: Dictionary = _target(_sandbox_point(Vector2(200, 0)))
	game.weapon_system.fire()
	for frame in range(50):
		game.projectiles.update(1.0 / 60.0)
	_check(target.hp < 5000.0 and game.player.energy == 0.0, "Empty energy falls back to a damaging free pistol shot")
	game.recall_pistol()
	_check(game.weapons[0] == "pistol" and game.weapons.size() == 2, "Explicit pistol recall replaces current slot without growing inventory")
	game.swap_weapon()
	_check(game.active_slot == 1, "Quick swap selects the second weapon")

func _test_upgrades() -> void:
	_sandbox()
	game.upgrades = {"speed": 1, "dash": 1, "shield": 1, "energy": 1, "regen": 1, "shield_delay": 1}
	game.player.refresh_stats()
	_check(game.player.max_shield == 70.0 and game.player.max_energy == 130.0, "Shield and energy upgrade maxima update actual player")
	_check(is_equal_approx(game.player.dash_period(), 1.42), "Dash upgrade shortens actual cooldown")
	game.player.energy = 0.0
	game.player.shield = 0.0
	game.player.since_damage = 3.3
	game.player.update(0.1)
	_check(is_equal_approx(game.player.energy, 0.85) and game.player.shield > 0.0, "Regen and shield-delay upgrades affect recovery")
	game.controls.stick_vector = Vector2.RIGHT
	game.player.dash_time = 0.0
	var before: float = game.player.position.x
	game.player.update(0.1)
	_check(is_equal_approx(game.player.position.x - before, 22.8), "Speed upgrade increases real movement")
	_sandbox()
	game.weapons = ["shotgun", "pistol"]
	game.active_slot = 0
	game.upgrades = {"pierce": 1, "bounce": 1}
	game.weapon_system.fire()
	var all_pierce_and_bounce: bool = game.projectiles.count() == 7
	for shot in game.projectiles.active:
		all_pierce_and_bounce = all_pierce_and_bounce and shot.pierce == 1 and shot.bounces == 1
	_check(all_pierce_and_bounce, "Shotgun synergy gives all seven pellets both pierce and bounded bounce")
	_sandbox()
	game.weapons = ["arc", "pistol"]
	game.active_slot = 0
	game.upgrades = {"chain": 1}
	var targets: Array = []
	for i in range(5):
		targets.append(_target(_sandbox_point(Vector2(70 + i * 85, 0))))
	game.weapon_system.fire()
	var hits: int = 0
	for target in targets:
		if target.hp < 5000.0: hits += 1
	_check(hits == 5, "Arc chain upgrade reaches five distinct targets")
	_sandbox()
	game.upgrades = {"perfect_wave": 1}
	var target: Dictionary = _target(_sandbox_point(Vector2(50, 0)))
	game.player.dash()
	_check(game.player.resonance == 22.0 and target.hp == 4986.0 and target.pos.x >= SANDBOX_ORIGIN.x + 90.0, "Perfect Dash synergy adds resonance, damage and physical push")
	_sandbox()
	game.weapons = ["beam", "orbit"]
	for room in range(4):
		game.room_index = room
		game.show_reward()
		for choice in game.pending_reward:
			_check(not choice.id in ["pierce", "bounce", "chain"], "Reward picker excludes incompatible upgrade %s" % choice.id)

func _test_combat_gate_lifecycle() -> void:
	game.new_run(620417)
	var first_room_gates: Array[Rect2] = game.active_combat_barrier_rects()
	_check(game.combat_active and not first_room_gates.is_empty(), "An uncleared Combat 1 activates its authored corridor gate model")
	_clear_encounter()
	_check(not game.combat_active and game.active_combat_barrier_rects().is_empty(), "Clearing every enemy removes the corridor gate model before route travel resumes")
	_enter_route_room(1)
	var combat_two_gates: Array[Rect2] = game.active_combat_barrier_rects()
	_check(game.room_index == 1 and game.combat_active and combat_two_gates.size() >= 2, "Entering uncleared Combat 2 activates gates for both the previous and forward/branch corridors")

func _clear_encounter() -> void:
	var safety: int = 0
	while game.enemies.living_count() > 0 and safety < 12:
		safety += 1
		game.player.invulnerable = 999.0
		game.enemies.update(2.1)
		for target in game.enemies.units.duplicate():
			if target.boss:
				game.enemies.damage_enemy(target.id, target.max_hp * 0.55)
				game.enemies.update(2.2)
				if game.stage_index == 4:
					game.enemies.damage_enemy(target.id, target.max_hp * 0.2)
					game.enemies.update(2.2)
			game.enemies.damage_enemy(target.id, 99999.0)
	_check(game.enemies.living_count() == 0, "Controlled encounter clears every wave and boss phase")
	# Bosses now hold their authored death animation before their reward appears.
	# Advance through that real non-interactive delay instead of assuming the old
	# generic 0.4-second enemy clear applies to every encounter.
	game._physics_process(game.enemies.clear_animation_delay() + 0.01)
	_check(game.state == "reward" and not game.combat_active, "Encounter completion opens reward overlay and stops combat")
	var credits: int = game.coins
	game.complete_room()
	_check(game.coins == credits, "Repeated room completion does not award coins twice")
	game.choose_upgrade("repair")
	var reward_count: int = game.rewarded.size()
	game.choose_upgrade("repair")
	_check(game.state == "playing" and game.rewarded.size() == reward_count, "Upgrade choice is applied once and resumes safe room")
	_check(game.profile.checkpoint.get("room", -1) == game.room_index, "Room completion captures checkpoint at the cleared room")
	_check(game.store.validate_checkpoint(game.profile.checkpoint), "Captured checkpoint passes persistence invariants")

func _walk_to_level_one_room(destination: int) -> void:
	var waypoints: Array[Vector2] = []
	# Combat 1 and Combat 2 meet through a lower bent hallway. Once the safe
	# corridor reaches the Combat 2 threshold, the test must follow its short
	# inner turn as well; a centre-to-centre diagonal would cut through a wall.
	if game.room_index == 0 and destination == 1:
		waypoints = [
			game.level_one_art_to_world_point(Vector2(260, 760)),
			game.level_one_art_to_world_point(Vector2(310, 760)),
			game.level_one_art_to_world_point(Vector2(350, 700)),
			game.level_one_art_to_world_point(Vector2(350, 630)),
			game.level_one_art_to_world_point(Vector2(500, 630)),
		]
	elif game.room_index == 1 and destination == 0:
		waypoints = [
			game.level_one_art_to_world_point(Vector2(500, 630)),
			game.level_one_art_to_world_point(Vector2(350, 630)),
			game.level_one_art_to_world_point(Vector2(350, 700)),
			game.level_one_art_to_world_point(Vector2(310, 760)),
			game.level_one_art_to_world_point(Vector2(260, 760)),
		]
	waypoints.append(game.room_entry_position(destination))
	for waypoint in waypoints:
		game.player.position = game.move_actor(game.player.position, waypoint - game.player.position, game.player.radius)
		# A real player crosses the hall and chamber on separate physics frames. Run
		# the same exploration update at each leg so the test preserves the new
		# safe-corridor -> pending-room -> active-combat sequence.
		game.update_route_exploration()

func _enter_route_room(destination: int) -> void:
	# Route-entry tests place the player at a documented room centre, then invoke
	# the same overlap/lock transition that regular movement reaches. The separate
	# backtracking tests exercise the collision restriction around that transition.
	game.player.position = game.room_entry_position(destination)
	game.update_route_exploration()
	# Entering room 5 first switches to its unlocked corridor. Continue to its
	# authored chamber centre for the real second overlap that starts the boss;
	# it must stay distinct from merely reaching the boss corridor.
	if destination == 5 and game.boss_chamber_pending:
		game.player.position = game.boss_spawn_position()
		game.update_route_exploration()

func _use_boss_exit_portal() -> void:
	var gate: Dictionary = game.boss_exit_portal()
	_check(not gate.is_empty(), "Cleared boss exposes a campaign exit portal")
	if gate.is_empty():
		return
	# Let the visible gate finish materialising, then reproduce its intentional
	# leave-and-return gesture. This covers the player-facing route rather than
	# calling travel(6) directly, which normal gameplay does not expose.
	game._process(1.0)
	game.player.position = gate.pos + Vector2(220, 0)
	game._physics_process(0.1)
	game.player.position = gate.pos
	game._physics_process(0.1)

func _test_level_one_backtracking() -> void:
	game.new_run(884477)
	game.player.invulnerable = 999.0
	_clear_encounter()
	_check(game.portals.is_empty(), "LV1 removes room-transition portal buttons after Combat 1")
	game.travel(1)
	_check(game.room_index == 0 and not game.combat_active, "LV1 ignores legacy room-travel buttons after Combat 1")
	_walk_to_level_one_room(1)
	_check(game.room_index == 1 and game.combat_active, "Walking into opened Combat 2 starts its encounter without a room-transition button")
	var combat_one_position: Vector2 = game.room_entry_position(0)
	var blocked_return: Vector2 = game.move_actor(game.player.position, combat_one_position - game.player.position, game.player.radius)
	_check(blocked_return.distance_to(combat_one_position) > game.player.radius and game.room_index == 1, "Combat 2 collision blocks walking back to Combat 1 while enemies remain")
	_clear_encounter()
	_walk_to_level_one_room(0)
	_check(game.room_index == 0 and not game.combat_active, "After Combat 2, the connected boundary allows walking back to cleared Combat 1 safely")

func _test_level_two_backtracking() -> void:
	game.new_run(993211)
	game.stage_index = 1
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	_check(game.is_open_route_stage() and game.portals.is_empty(), "Bass Foundry uses a connected route without legacy room-transition portals")
	_check(game.walkable_polygons == game.route_room_polygons(0), "Bass Foundry begins with only its first authored floor polygon physically open")
	game.player.invulnerable = 999.0
	_clear_encounter()
	_check(game.is_route_room_open(1), "Clearing Bass Foundry Combat 1 opens its next connected room")
	_enter_route_room(1)
	_check(game.room_index == 1 and game.combat_active, "Entering the opened Bass Foundry Combat 2 floor starts combat without a button")
	_check(not game.is_walkable_position(game.room_entry_position(0), game.player.radius), "Bass Foundry combat blocks return to the previous room until enemies are cleared")
	_clear_encounter()
	_enter_route_room(0)
	_check(game.room_index == 0 and not game.combat_active, "Bass Foundry permits backtracking to Combat 1 after Combat 2 is cleared")

func _test_level_three_backtracking() -> void:
	game.new_run(128314)
	game.stage_index = 2
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	_check(game.is_open_route_stage() and game.portals.is_empty(), "Luminous Grove uses a connected route without legacy room-transition portals")
	_check(game.arena.size == Vector2(4344, 3258), "Luminous Grove world is 50% larger than the previous 2896 x 2172 route")
	_check(game.level_three_art_scale() == Vector2(3, 3), "Luminous Grove scales art, collision and entry points uniformly at 3x")
	_check(game.walkable_polygons == game.route_room_polygons(0), "Luminous Grove begins with only its first authored floor polygon physically open")
	game.player.invulnerable = 999.0
	_clear_encounter()
	_check(game.is_route_room_open(1), "Clearing Luminous Grove Combat 1 opens Combat 2")
	_enter_route_room(1)
	_check(game.room_index == 1 and game.combat_active, "Entering opened Luminous Grove Combat 2 starts combat without a button")
	_check(not game.is_walkable_position(game.room_entry_position(0), game.player.radius), "Luminous Grove combat blocks return to Combat 1 until enemies are cleared")
	_clear_encounter()
	_check(game.is_route_room_open(4), "Clearing Luminous Grove Combat 2 opens the support branch")
	_enter_route_room(0)
	_check(game.room_index == 0 and not game.combat_active, "Luminous Grove permits backtracking to Combat 1 after Combat 2 is cleared")

func _test_level_four_backtracking() -> void:
	game.new_run(771804)
	game.stage_index = 3
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	_check(game.is_open_route_stage() and game.portals.is_empty(), "Prism Spire uses a connected route without legacy room-transition portals")
	_check(game.arena.size == Vector2(4344, 3258), "Prism Spire world is 50% larger than its former 2896 x 2172 layout")
	_check(game.level_four_art_scale() == Vector2(3, 3), "Prism Spire scales art, collision and entry points uniformly at 3x")
	_check(game.walkable_polygons == game.route_room_polygons(0), "Prism Spire begins with only its first authored floor polygon physically open")
	game.player.invulnerable = 999.0
	_clear_encounter()
	_check(game.is_route_room_open(1), "Clearing Prism Spire Combat 1 opens Combat 2")
	_enter_route_room(1)
	_check(game.room_index == 1 and game.combat_active, "Entering opened Prism Spire Combat 2 starts combat without a button")
	_check(not game.is_walkable_position(game.room_entry_position(0), game.player.radius), "Prism Spire combat blocks return to Combat 1 until enemies are cleared")
	_clear_encounter()
	_check(game.is_route_room_open(4), "Clearing Prism Spire Combat 2 opens the support branch")
	_enter_route_room(0)
	_check(game.room_index == 0 and not game.combat_active, "Prism Spire permits backtracking to Combat 1 after Combat 2 is cleared")

func _advance_live_encounter(seconds: float) -> Dictionary:
	# Tests normally call individual systems directly. This helper deliberately
	# drives Main's real process/physics path, because room transitions resume the
	# rhythm clock there and EnemySystem receives attacks through its beat signal.
	var initial_positions: Dictionary = {}
	for unit in game.enemies.units:
		initial_positions[int(unit.id)] = unit.pos
	var step := 1.0 / 60.0
	var frames := int(ceil(seconds / step))
	for frame in range(frames):
		game._process(step)
		game._physics_process(step)
	var moved := false
	var attacked := false
	for unit in game.enemies.units:
		var id := int(unit.id)
		moved = moved or (initial_positions.has(id) and unit.pos.distance_to(initial_positions[id]) > 4.0)
		attacked = attacked or int(unit.turn) > 0
	return {"moved": moved, "attacked": attacked}

func _test_later_room_combat_lifecycle() -> void:
	game.new_run(426801)
	game.player.invulnerable = 999.0
	# This follows the same reward pause/resume boundary used by a real clear,
	# then crosses the authored LV1 entrance into Combat 2.
	game.enemies.clear()
	game.complete_room()
	game.choose_upgrade("repair")
	var beat_before: int = int(game.rhythm.beat_index)
	game.player.position = game.room_entry_position(1)
	game.update_route_exploration()
	_check(game.room_index == 1 and game.state == "playing" and game.combat_active, "Reward resume enters Combat 2 with its encounter active")
	var room_two := _advance_live_encounter(7.0)
	_check(game.rhythm.beat_index > beat_before, "Later-room runtime progression emits new rhythm beats after reward resume")
	_check(room_two.attacked, "Later-room enemies receive beats and begin their real attack patterns")
	_check(room_two.moved, "Later-room enemies advance through the real collision/path movement loop")
	# The boss shares the same beat delivery but has a separate movement and attack
	# branch, so exercise it explicitly rather than inferring it from normal mobs.
	game.combat_active = false
	game.cleared = [0, 1, 2, 3, 4]
	game.enter_room(5)
	_check(game.room_index == 5 and game.combat_active and game.enemies.units.size() == 1 and game.enemies.units[0].boss, "Opened boss room creates its active boss encounter")
	var boss := _advance_live_encounter(7.0)
	_check(boss.attacked, "Boss receives beats and starts a boss attack pattern")
	_check(boss.moved, "Boss advances through its orbit movement instead of remaining frozen")

func _test_progression() -> void:
	game.new_run(884477)
	_check(game.is_open_route_stage() and game.walkable_polygons == game.level_one_room_polygons(0), "Stage 1 begins as a connected route with only Combat 1 physically open")
	game.player.invulnerable = 999.0
	for stage in range(5):
		_check(game.stage_index == stage and game.room_index == 0, "Stage %d begins in first room" % (stage + 1))
		_check(game.is_open_route_stage() and game.portals.is_empty(), "Stage %d relies on a connected route instead of room portals" % (stage + 1))
		game.travel(5)
		_check(game.room_index == 0, "Combat cannot skip directly to boss")
		for room in range(4):
			_check(game.room_index == room and game.combat_active, "Stage %d combat room %d is encountered" % [stage + 1, room + 1])
			_clear_encounter()
			if room < 3:
				_check(game.is_route_room_open(room + 1), "Stage %d opens Combat %d after Combat %d is cleared" % [stage + 1, room + 2, room + 1])
			if room == int(game.graph.branch):
				_enter_route_room(4)
				_check(game.room_index == 4 and not game.combat_active, "Seeded support branch is reachable and safe")
				game.player.position = game.support_station_position()
				game.interact()
				_check(game.state == "shop", "Support interaction opens actual shop overlay")
				if game.graph.support == "heal":
					game.heal_support()
				else:
					var offers: Array = game.support_offers()
					game.buy_weapon(offers[0].id)
				_check(game.support_purchased and game.rewarded.has(4) and game.state == "playing", "Support reward applies once and returns to gameplay")
				var money: int = game.coins
				game.heal_support()
				_check(game.coins == money and game.rewarded.count(4) == 1, "Support cannot be collected twice")
				_enter_route_room(room)
				_check(game.room_index == room and not game.combat_active, "Return from support preserves cleared combat state")
			_enter_route_room(room + 1 if room < 3 else 5)
		_check(game.room_index == 5 and game.combat_active, "Boss room opens after four combat rooms")
		_clear_encounter()
		_check(game.cleared.size() == 6 and game.rewarded.size() == 6, "Stage includes four combats, support and boss with unique rewards")
		var coins_before_exit: int = game.coins
		var weapons_before_exit: Array = game.weapons.duplicate()
		var upgrades_before_exit: Dictionary = game.upgrades.duplicate(true)
		_use_boss_exit_portal()
		if stage < 4:
			_check(game.stage_index == stage + 1 and game.room_index == 0 and game.state == "playing", "Boss exit portal carries Area %d into Area %d" % [stage + 1, stage + 2])
			_check(game.coins == coins_before_exit and game.weapons == weapons_before_exit and game.upgrades == upgrades_before_exit, "Boss exit preserves the current run build into the next area")
		else:
			_check(game.state == "victory", "Final boss exit portal reaches the victory flow")
	_check(game.state == "victory" and game.stage_index == 4 and not game.combat_active, "All five stages reach the actual victory flow")
	_check(game.profile.checkpoint.is_empty() and game.projectiles.count() == 0, "Victory clears resume checkpoint and projectiles")
	var wins: int = game.profile.meta.wins
	var shards: int = game.profile.meta.shards
	game.end_run(true)
	_check(game.profile.meta.wins == wins and game.profile.meta.shards == shards, "Victory metadata is recorded once")

func _test_checkpoint() -> void:
	game.new_run(778877)
	_clear_encounter()
	var checkpoint: Dictionary = game.profile.checkpoint.duplicate(true)
	if checkpoint.is_empty():
		_check(false, "Checkpoint content exists for actual restore test")
		return
	_walk_to_level_one_room(1)
	_check(game.profile.checkpoint == checkpoint, "Entering unfinished combat preserves previous completed-room snapshot")
	game.return_to_menu()
	game.profile.checkpoint = JSON.parse_string(JSON.stringify(checkpoint))
	game.continue_run()
	_check(game.seed_value == 778877 and game.room_index == 0 and game.cleared.has(0) and not game.combat_active, "JSON checkpoint restores same seed and safe completed room")
	_check(game.rewarded.has(0) and game.coins == int(checkpoint.coins) and game.weapons == checkpoint.weapons, "Checkpoint restores rewards, coins and weapon inventory without mixing states")
	var money: int = game.coins
	game.complete_room()
	game.choose_upgrade("repair")
	_check(game.coins == money and game.rewarded.count(0) == 1, "Restoring completed room cannot duplicate its reward")
	_walk_to_level_one_room(1)
	_check(game.combat_active and game.enemies.living_count() > 0, "Travel from restored safe checkpoint recreates next encounter")

func _test_death_replay() -> void:
	game.new_run(334499)
	game.player.invulnerable = 0.0
	game.player.shield = 0.0
	game.player.hp = 1.0
	game.projectiles.spawn({"pos": game.player.position, "vel": Vector2.ZERO, "enemy": true, "damage": 10.0})
	game.projectiles.update(1.0 / 60.0)
	_check(game.state == "game_over" and not game.combat_active and game.player.hp == 0.0, "Enemy bullet reaches actual death and game-over flow")
	_check(game.profile.checkpoint.is_empty() and game.projectiles.count() == 0 and game.enemies.living_count() == 0, "Death clears checkpoint, projectile and encounter state")
	var shards: int = game.profile.meta.shards
	game.end_run(false)
	_check(game.profile.meta.shards == shards, "Repeated death cannot duplicate permanent rewards")
	game.new_run(334500)
	_check(game.state == "playing" and game.stage_index == 0 and game.room_index == 0 and game.player.hp == 100.0 and not game.end_recorded, "New run after death resets full run progression")
	_check(game.upgrades.is_empty() and game.coins == 0 and game.player.resonance == 0.0, "Temporary upgrades, coins and resonance do not leak into replay")
