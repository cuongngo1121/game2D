extends SceneTree
## Regression contract for the Area 4 boss difficulty profile.
##
## Refractor must close distance more decisively than Choir Widow, attack on a
## shorter beat interval, inherit the three earlier boss pattern families, and
## expose one local, target-locked Prism Burst of its own.

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
	_test_area4_closes_more_aggressively()
	_test_area4_attack_profile_is_heavier()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS AREA 4 DIFFICULTY PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("BOSS AREA 4 DIFFICULTY FAIL: %d/%d checks" % [failures.size(), checks])
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


func _test_area4_closes_more_aggressively() -> void:
	var boss2: Dictionary = _setup_boss(2)
	var boss2_speed: float = float(boss2.speed)
	var boss2_attack_beats: int = int(boss2.attack_beats)
	var boss2_start: Vector2 = boss2.pos
	game.enemies.update(0.5)
	var boss2_advance: float = boss2_start.distance_to(boss2.pos)

	var boss3: Dictionary = _setup_boss(3)
	var boss3_speed: float = float(boss3.speed)
	var boss3_start: Vector2 = boss3.pos
	game.enemies.update(0.5)
	var boss3_advance: float = boss3_start.distance_to(boss3.pos)

	_check(boss3_speed >= boss2_speed + 10.0,
		"Area 4 Refractor has a clearly higher chase speed than Area 3 Choir Widow")
	_check(boss3_advance >= boss2_advance + 5.0,
		"Area 4 Refractor closes the player gap more decisively in the same time slice")
	_check(int(boss3.attack_beats) < boss2_attack_beats,
		"Area 4 Refractor attacks on a shorter beat interval than Area 3")


func _test_area4_attack_profile_is_heavier() -> void:
	var boss2: Dictionary = _setup_boss(2)
	var boss2_hazard_events: int = _collect_attack_hazards(boss2, 12)

	var boss3: Dictionary = _setup_boss(3)
	var boss3_hazard_types: Dictionary = {}
	var boss3_hazard_events: int = 0
	var prism_burst: Dictionary = {}
	for attack_index in range(12):
		game.enemies.hazards.clear()
		boss3.charge_left = 0.0
		game.enemies._boss_attack(boss3, attack_index)
		boss3_hazard_events += game.enemies.hazards.size()
		for hazard in game.enemies.hazards:
			boss3_hazard_types[str(hazard.get("type", ""))] = true
			if bool(hazard.get("prism_burst", false)):
				prism_burst = hazard

	_check(boss3_hazard_events > boss2_hazard_events,
		"Area 4 Refractor emits more telegraphed attack hazards than Area 3")
	_check(boss3_hazard_types.has("volley"),
		"Area 4 Refractor inherits the earlier boss volley pattern")
	_check(boss3_hazard_types.has("ring"),
		"Area 4 Refractor inherits the earlier boss ring pattern")
	_check(boss3_hazard_types.has("support"),
		"Area 4 Refractor inherits the earlier boss support pattern")
	_check(boss3_hazard_types.has("spiral"),
		"Area 4 Refractor keeps its rotating spiral pattern")
	_check(boss3_hazard_types.has("charge"),
		"Area 4 Refractor keeps its telegraphed approach lunge")
	_check(not prism_burst.is_empty(),
		"Area 4 Refractor exposes its unique Prism Burst skill")
	if not prism_burst.is_empty():
		_check(str(prism_burst.get("shape", "")) == "prism_burst" and
			float(prism_burst.get("radius", 999.0)) <= 110.0,
			"Prism Burst remains a local, readable target-locked hazard instead of a map-wide beam")
		_check(prism_burst.pos.distance_to(game.player.position) < 0.1,
			"Prism Burst locks to the player's position at warning time")


func _collect_attack_hazards(boss: Dictionary, attack_count: int) -> int:
	var total: int = 0
	for attack_index in range(attack_count):
		game.enemies.hazards.clear()
		boss.charge_left = 0.0
		game.enemies._boss_attack(boss, attack_index)
		total += game.enemies.hazards.size()
	return total


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
