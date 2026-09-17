extends SceneTree
## Verifies the authored player Pulse and enemy combat feedback contracts.

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
	await process_frame
	game.new_run(20260917)
	game.set_physics_process(false)
	game.controls.set_process(false)
	game.controls.set_physics_process(false)
	_test_player_pulse()
	_test_player_shield_hit()
	_test_enemy_spawn_contract()
	_test_enemy_fire_contract()
	_test_enemy_bomb_contract()
	_test_dash_laser_and_boss_contract()
	_test_five_boss_with_progressive_map_beam()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT VISUAL ANIMATION PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("COMBAT VISUAL ANIMATION FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _test_player_pulse() -> void:
	var player = game.player
	_check(player.pixel_animation_sheets.has("pulse"), "Player loads the authored Pulse sprite sheet")
	_check(int(player.pixel_animation_frame_counts.get("pulse", 0)) == 6, "Pulse uses six readable animation frames")
	_check(is_equal_approx(float(player.pixel_animation_fps.get("pulse", 0.0)), 12.0), "Pulse plays at the authored 12 FPS")
	var pulse_sheet: Texture2D = player.pixel_animation_sheets.get("pulse")
	var pulse_image: Image = pulse_sheet.get_image() if pulse_sheet != null else null
	var changed_frames: int = 0
	if pulse_image != null:
		for frame in range(1, 6):
			var changed_pixels: int = 0
			for y in range(32):
				for x in range(32):
					if pulse_image.get_pixel((frame - 1) * 32 + x, y) != pulse_image.get_pixel(frame * 32 + x, y):
						changed_pixels += 1
			_check(changed_pixels > 0, "Pulse frame %d has visible authored motion" % frame)
			if changed_pixels > 0:
				changed_frames += 1
	_check(changed_frames == 5, "All Pulse frame transitions change visible pixels")
	player.resonance = 100.0
	_check(player.pulse(), "Full Resonance activates the real Pulse action")
	_check(player.visual_animation() == "pulse" and player.pulse_animation_time > 0.0, "Pulse action selects the live player Pulse animation")
	_check(player.pulse_visual_radius >= 155.0, "Pulse visual radius follows the gameplay reach")

func _test_player_shield_hit() -> void:
	var player = game.player
	var previous_combat: bool = game.combat_active
	var previous_hp: float = player.hp
	var previous_shield: float = player.shield
	var previous_invulnerable: float = player.invulnerable
	game.combat_active = true
	player.hp = player.max_hp
	player.shield = player.max_shield
	player.invulnerable = 0.0
	player.shield_hit_animation_time = 0.0
	player.take_damage(12.0)
	_check(player.shield_hit_animation_time > 0.0, "A real damage event starts the circular shield-hit animation")
	_check(not player.shield_hit_broken and player.shield < player.max_shield and is_equal_approx(player.hp, player.max_hp), "Shield absorbs the hit while the player remains unharmed")
	player.hp = previous_hp
	player.shield = previous_shield
	player.invulnerable = previous_invulnerable
	player.shield_hit_animation_time = 0.0
	player.shield_hit_broken = false
	game.combat_active = previous_combat

func _test_enemy_spawn_contract() -> void:
	game.enemies.clear()
	game.enemies.spawn_debug_wave(0, 0, 20260917)
	_check(not game.enemies.units.is_empty(), "Debug wave creates units for spawn animation coverage")
	if game.enemies.units.is_empty():
		return
	var unit: Dictionary = game.enemies.units[0]
	_check(float(unit.get("spawn_grace", 0.0)) > 0.0, "Spawn starts with a non-interactive readable grace window")
	_check(unit.has("spawn_phase"), "Spawn owns a deterministic portal animation phase")
	_check(float(unit.get("spawn_phase", -1.0)) >= 0.0, "Spawn animation phase is initialized")

func _test_enemy_fire_contract() -> void:
	var unit: Dictionary = game.enemies.units[0]
	unit.spawn_grace = 0.0
	unit.transition = 0.0
	game.projectiles.clear()
	game.enemies.fire_effects.clear()
	game.enemies.hazards.clear()
	game.enemies._warn({"type": "volley", "owner": unit.id, "pos": unit.pos,
		"angle": 0.0, "count": 3, "spread": 0.55, "damage": 9.0})
	var warning: Dictionary = game.enemies.hazards.back()
	_check(bool(warning.get("preparing", false)), "Enemy projectile warning starts in an explicit preparing state")
	_check(warning.has("prepare_phase"), "Enemy projectile warning owns a deterministic animated charge phase")
	game.enemies._fire_hazard(warning)
	_check(not bool(warning.get("preparing", true)), "Projectile preparation closes when the attack is fired")
	_check(float(unit.get("fire_anim", 0.0)) > 0.0, "Enemy enters the fire animation when bullets leave the muzzle")
	_check(float(unit.get("fire_flash", 0.0)) > 0.0, "Enemy fire owns a short muzzle flash window")
	_check(not game.enemies.fire_effects.is_empty(), "Enemy fire creates a timed muzzle effect")
	_check(game.projectiles.count() == 3, "Enemy volley still creates the expected projectile count")
	if game.projectiles.count() > 0:
		_check(str(game.projectiles.active[0].get("visual", "")) == "enemy_orb", "Regular enemy bullets use the authored enemy orb visual")

func _test_enemy_bomb_contract() -> void:
	var unit: Dictionary = game.enemies.units[0]
	game.projectiles.clear()
	game.enemies.fire_effects.clear()
	game.enemies._warn({"type": "volley", "owner": unit.id, "pos": unit.pos,
		"angle": 0.0, "count": 3, "spread": 0.9, "behavior": "split"})
	var marker: Dictionary = game.enemies.hazards.back()
	_check(str(marker.get("behavior", "")) == "split" and int(marker.get("count", 0)) == 3, "Splitter telegraph carries the bomb spread contract")
	game.enemies._fire_hazard(marker)
	_check(game.projectiles.count() == 3, "Splitter fire creates the expected bomb volley")
	if game.projectiles.count() > 0:
		var bomb: Dictionary = game.projectiles.active[0]
		_check(str(bomb.get("visual", "")) == "enemy_bomb", "Splitter projectile uses the authored bomb visual")
		_check(float(bomb.get("split_after", 0.0)) > 0.0, "Bomb projectile owns a delayed split timing")
		_check(str(bomb.get("accent", "")) != "", "Bomb projectile carries a readable warning accent")

func _test_dash_laser_and_boss_contract() -> void:
	game.enemies.spawn_debug_wave(1, 0, 20260917)
	var charger: Dictionary = {}
	for candidate in game.enemies.units:
		if str(candidate.get("kind", "")) == "charger":
			charger = candidate
			break
	_check(not charger.is_empty(), "Debug roster exposes a charger for the enemy dash path")
	if not charger.is_empty():
		game.enemies.hazards.clear()
		game.enemies._warn_charge(charger)
		var dash_marker: Dictionary = game.enemies.hazards.back()
		_check(str(dash_marker.get("type", "")) == "charge" and dash_marker.has("path"), "Enemy dash owns a readable locked trajectory")
		_check(dash_marker.get("path", []).size() > 1, "Enemy dash trajectory reaches a collision-safe endpoint")

	game.enemies.spawn_room(3, 0, true, 20260917)
	_check(not game.enemies.units.is_empty(), "Boss room creates a boss for attack feedback coverage")
	if game.enemies.units.is_empty():
		return
	var boss: Dictionary = game.enemies.units[0]
	boss.spawn_grace = 0.0
	boss.transition = 0.0
	boss.phase = 2
	game.enemies.hazards.clear()
	game.enemies._boss_attack(boss, 0)
	_check(float(boss.get("attack_anim", 0.0)) > 0.0, "Boss attack starts the circular attack animation")
	_check(int(boss.get("phase", 1)) >= 2, "Boss phase 2 keeps the cyan shield state active")
	var beam_found: bool = false
	var legacy_laser_found: bool = false
	for hazard in game.enemies.hazards:
		if str(hazard.get("type", "")) == "boss_beam":
			beam_found = true
		if str(hazard.get("type", "")) == "laser" and int(hazard.get("owner", -1)) == int(boss.get("id", -2)):
			legacy_laser_found = true
	_check(beam_found, "Boss attack exposes the animated map-spanning beam")
	_check(not legacy_laser_found, "Boss attack does not create a duplicate legacy laser hazard")

func _test_five_boss_with_progressive_map_beam() -> void:
	var beam_counts: Array[int] = []
	for stage in range(5):
		# Run each boss against its authored stage layout so every encounter
		# confirms the shared beam animation and its progressive cadence.
		game.stage_index = stage
		game.room_index = 5
		game.configure_map_layout()
		game.enemies.spawn_room(stage, 5, true, 20260917 + stage)
		_check(game.enemies.units.size() == 1 and bool(game.enemies.units[0].get("boss", false)),
			"Stage %d creates exactly one boss for no-map-beam coverage" % (stage + 1))
		if game.enemies.units.is_empty():
			continue
		var boss: Dictionary = game.enemies.units[0]
		boss.spawn_grace = 0.0
		boss.transition = 0.0
		boss.phase = 2
		boss.charge_left = 0.0
		game.enemies._grace = 0.0
		var boss_beam_count: int = 0
		var boss_laser_found: bool = false
		var boss_rail_found: bool = false
		for attack_index in range(12):
			game.enemies.hazards.clear()
			boss.charge_left = 0.0
			game.enemies._boss_attack(boss, attack_index)
			for hazard in game.enemies.hazards:
				if str(hazard.get("type", "")) == "boss_beam" and int(hazard.get("owner", -1)) == int(boss.get("id", -2)):
					boss_beam_count += 1
					var path: Array = hazard.get("path", [])
					_check(path.size() == 2 and bool(hazard.get("map_spanning", false)),
						"Stage %d boss beam uses the shared map-spanning path" % (stage + 1))
					if path.size() == 2:
						_check(path[0].distance_to(path[1]) >= minf(game.arena.size.x, game.arena.size.y) * 0.9,
							"Stage %d boss beam is long enough to cross the arena" % (stage + 1))
				if str(hazard.get("type", "")) == "laser" and int(hazard.get("owner", -1)) == int(boss.get("id", -2)):
					boss_laser_found = true
				if str(hazard.get("type", "")) == "rail" and int(hazard.get("owner", -1)) == int(boss.get("id", -2)):
					boss_rail_found = true
		_check(boss_beam_count > 0, "Stage %d boss schedules its animated map-spanning beam" % (stage + 1))
		_check(not boss_laser_found, "Stage %d boss does not schedule a duplicate legacy laser" % (stage + 1))
		_check(not boss_rail_found, "Stage %d boss does not schedule a duplicate legacy rail strip" % (stage + 1))
		beam_counts.append(boss_beam_count)
		game.enemies.damage_enemy(int(boss.get("id", -1)), 1.0)
		_check(float(boss.get("hit_ring_anim", 0.0)) > 0.0,
			"Stage %d boss shows the orange hit ring after damage" % (stage + 1))
	for stage in range(1, beam_counts.size()):
		_check(beam_counts[stage] > beam_counts[stage - 1],
			"Stage %d schedules more boss beam occurrences than Stage %d" % [stage + 1, stage])

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
