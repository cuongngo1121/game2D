extends SceneTree
## Regression contract for the Area 5 final-boss pressure profile.
##
## NULL MAESTRO must be a stronger follow-up to REFACTOR: it should close the
## gap faster, attack on a shorter beat interval, shoot more, split more bombs,
## lunge more often in its final phase, and use a denser map-spanning beam.

const EnemyScript = preload("res://scripts/combat/enemy_system.gd")

class TestPlayer:
	extends Node2D
	var radius: float = 11.0
	func take_damage(_amount: float) -> void:
		pass

class TestRhythm:
	extends RefCounted
	func beat_seconds() -> float:
		return 0.5

class TestAudio:
	extends RefCounted
	func play_sfx(_name: String) -> void:
		pass

class TestProjectiles:
	extends RefCounted
	func spawn(_spec: Dictionary) -> void:
		pass
	func clear() -> void:
		pass

class TestGame:
	extends Node2D
	var player := TestPlayer.new()
	var arena := Rect2(64, 112, 1152, 480)
	var obstacles: Array[Rect2] = []
	var rhythm := TestRhythm.new()
	var audio := TestAudio.new()
	var projectiles := TestProjectiles.new()
	var content: Dictionary = {"stages": [], "enemies": []}
	var combat_active: bool = true
	var enemies

	func initialize() -> void:
		player.position = Vector2(250, 352)
		add_child(player)
		enemies = EnemyScript.new()
		add_child(enemies)
		enemies.setup(self)

	func flash_text(_message: String, _color: Color) -> void:
		pass

	func add_fx(_pos: Vector2, _color: Color, _radius: float) -> void:
		pass

	func on_enemy_killed(_enemy: Dictionary) -> void:
		pass

	func has_line_of_sight(_from: Vector2, _to: Vector2) -> bool:
		return true

	func move_actor(pos: Vector2, motion: Vector2, radius: float) -> Vector2:
		var next: Vector2 = pos + motion
		next.x = clampf(next.x, arena.position.x + radius, arena.end.x - radius)
		next.y = clampf(next.y, arena.position.y + radius, arena.end.y - radius)
		return next

var game: TestGame
var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = TestGame.new()
	root.add_child(game)
	game.initialize()
	_test_area5_closes_more_aggressively()
	_test_area5_attack_profile_is_heavier()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS AREA 5 DIFFICULTY PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("BOSS AREA 5 DIFFICULTY FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _setup_boss(stage: int) -> Dictionary:
	game.enemies.clear()
	game.enemies._stage = stage
	game.enemies._boss_room = true
	game.enemies._grace = 0.0
	game.player.position = Vector2(250, 352)
	game.enemies._spawn("boss%d" % stage, Vector2(900, 352), true)
	var boss: Dictionary = game.enemies.units[0]
	boss.spawn_grace = 0.0
	boss.transition = 0.0
	boss.phase = 2
	boss.charge_left = 0.0
	return boss


func _test_area5_closes_more_aggressively() -> void:
	var boss3: Dictionary = _setup_boss(3)
	var boss3_speed: float = float(boss3.speed)
	var boss3_start: Vector2 = boss3.pos
	game.enemies.update(0.5)
	var boss3_advance: float = boss3_start.distance_to(boss3.pos)

	var boss4: Dictionary = _setup_boss(4)
	var boss4_speed: float = float(boss4.speed)
	var boss4_start: Vector2 = boss4.pos
	game.enemies.update(0.5)
	var boss4_advance: float = boss4_start.distance_to(boss4.pos)

	_check(boss4_speed >= boss3_speed + 6.0,
		"Area 5 NULL MAESTRO has a clearly higher chase speed than Area 4 REFACTOR")
	_check(boss4_advance >= boss3_advance + 3.0,
		"Area 5 NULL MAESTRO closes the player gap more decisively in the same time slice")
	_check(int(boss4.attack_beats) < int(boss3.attack_beats),
		"Area 5 NULL MAESTRO attacks on a shorter beat interval than Area 4")


func _test_area5_attack_profile_is_heavier() -> void:
	var boss3: Dictionary = _setup_boss(3)
	var area4_profile: Dictionary = _collect_attack_profile(boss3, 12)

	var boss4: Dictionary = _setup_boss(4)
	var area5_profile: Dictionary = _collect_attack_profile(boss4, 12)
	_check(int(area5_profile.events) > int(area4_profile.events),
		"Area 5 emits more telegraphed attack hazards than Area 4")
	_check(int(area5_profile.shot_markers) > int(area4_profile.shot_markers),
		"Area 5 schedules more projectile directions than Area 4")
	_check(int(area5_profile.bombs) >= 5,
		"Area 5 repeatedly schedules split bomb spreads")
	_check(int(area5_profile.beams) >= 20,
		"Area 5 repeatedly schedules its denser map-spanning beam")
	_check(area5_profile.types.has("volley"),
		"Area 5 keeps the inherited volley pattern")
	_check(area5_profile.types.has("ring"),
		"Area 5 keeps the inherited ring pattern")
	_check(area5_profile.types.has("spiral"),
		"Area 5 keeps the inherited spiral pattern")
	_check(area5_profile.types.has("support"),
		"Area 5 keeps the inherited support pattern")
	_check(area5_profile.types.has("floor"),
		"Area 5 keeps a local floor pressure zone")
	_check(area5_profile.types.has("charge"),
		"Area 5 keeps the telegraphed targeted lunge")
	_check(not area5_profile.first_bomb.is_empty(),
		"Area 5 exposes a concrete bomb telegraph with split behavior")
	_check(not area5_profile.first_beam.is_empty(),
		"Area 5 exposes a concrete map-spanning beam telegraph")
	if not area5_profile.first_bomb.is_empty():
		_check(str(area5_profile.first_bomb.get("behavior", "")) == "split" and
			int(area5_profile.first_bomb.get("count", 0)) >= 5,
			"Area 5 bomb telegraph carries at least five splitting projectiles")
		game.enemies._fire_hazard(area5_profile.first_bomb)
		_check(not bool(area5_profile.first_bomb.get("preparing", true)),
			"Area 5 bomb preparation closes cleanly when the spread fires")
	if not area5_profile.first_beam.is_empty():
		var beam: Dictionary = area5_profile.first_beam
		var beam_path: Array = beam.get("path", [])
		_check(beam_path.size() == 2 and bool(beam.get("map_spanning", false)) and
			beam_path[0].distance_to(beam_path[1]) >= minf(game.arena.size.x, game.arena.size.y) * 0.9,
			"Area 5 beam crosses the arena through the shared map-wide path")
		_check(beam.get("target_position", Vector2.ZERO).distance_to(game.player.position) < 0.1,
			"Area 5 beam locks the player's position when its warning starts")
		game.enemies.fire_effects.clear()
		game.enemies._fire_hazard(beam)
		_check(not bool(beam.get("preparing", true)) and not game.enemies.fire_effects.is_empty(),
			"Area 5 beam fires through the shared boss feedback path")

	# The final phase deliberately shortens the lunge interval again. This makes
	# the lunge rate higher than Area 4's phase-2 profile without hiding the
	# warning marker behind an immediate hit.
	boss4.phase = 3
	var area5_final_profile: Dictionary = _collect_attack_profile(boss4, 12)
	_check(int(area5_final_profile.lunges) > int(area4_profile.lunges),
		"Area 5 final phase lunges more often than Area 4 phase 2")


func _collect_attack_profile(boss: Dictionary, attack_count: int) -> Dictionary:
	var types: Dictionary = {}
	var events: int = 0
	var shot_markers: int = 0
	var bombs: int = 0
	var beams: int = 0
	var lunges: int = 0
	var first_bomb: Dictionary = {}
	var first_beam: Dictionary = {}
	for attack_index in range(attack_count):
		game.enemies.hazards.clear()
		boss.charge_left = 0.0
		game.enemies._boss_attack(boss, attack_index)
		events += game.enemies.hazards.size()
		for hazard in game.enemies.hazards:
			var hazard_type: String = str(hazard.get("type", ""))
			types[hazard_type] = true
			if hazard_type in ["volley", "ring", "spiral"] and str(hazard.get("behavior", "normal")) != "split":
				shot_markers += int(hazard.get("count", 0))
			if str(hazard.get("behavior", "normal")) == "split":
				bombs += 1
				if first_bomb.is_empty():
					first_bomb = hazard
			if hazard_type == "boss_beam":
				beams += 1
				if first_beam.is_empty():
					first_beam = hazard
			if hazard_type == "charge" and bool(hazard.get("boss_lunge", false)):
				lunges += 1
	return {"types": types, "events": events, "shot_markers": shot_markers,
		"bombs": bombs, "beams": beams, "lunges": lunges,
		"first_bomb": first_bomb, "first_beam": first_beam}


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
