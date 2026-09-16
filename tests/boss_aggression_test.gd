extends SceneTree
## Verifies active chase and telegraphed player-targeted lunges for all bosses.

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
		var next := pos + motion
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
	for stage in range(5):
		_test_boss(stage)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS AGGRESSION PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS AGGRESSION FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _test_boss(stage: int) -> void:
	game.enemies.clear()
	game.enemies._stage = stage
	game.enemies._grace = 0.0
	game.player.position = Vector2(250, 352)
	game.enemies._spawn("boss%d" % stage, Vector2(900, 352), true)
	var boss: Dictionary = game.enemies.units.back()
	boss.spawn_grace = 0.0
	var before_distance: float = boss.pos.distance_to(game.player.position)
	game.enemies.update(0.5)
	var after_distance: float = boss.pos.distance_to(game.player.position)
	_check(after_distance < before_distance, "Boss %d actively closes distance toward the player instead of orbiting passively" % (stage + 1))
	var lunge: Dictionary = {}
	for turn in range(8):
		game.enemies.hazards.clear()
		game.enemies._boss_attack(boss, turn * 6)
		for hazard in game.enemies.hazards:
			if hazard.type == "charge" and bool(hazard.get("boss_lunge", false)):
				lunge = hazard
				break
		if not lunge.is_empty():
			break
	_check(not lunge.is_empty(), "Boss %d schedules a telegraphed targeted lunge within its active pattern" % (stage + 1))
	if lunge.is_empty():
		return
	var expected_direction: Vector2 = (game.player.position - boss.pos).normalized()
	var expected_endpoint: Vector2 = game.enemies._ray_endpoint(boss.pos, expected_direction, boss.radius)
	var lunge_length: float = lunge.path[0].distance_to(lunge.path[1])
	_check(lunge.direction.dot(expected_direction) > 0.99, "Boss %d lunge direction is aimed at the player's recorded position" % (stage + 1))
	_check(float(lunge.warning) >= maxf(0.8, 2.0 * game.rhythm.beat_seconds()), "Boss %d lunge keeps the required readable warning time" % (stage + 1))
	_check(lunge.path[0].distance_to(boss.pos) < 0.1 and lunge.path[1].distance_to(expected_endpoint) < 0.1 and lunge_length >= game.arena.size.x * 0.6, "Boss %d lunge marker reaches the full open room lane" % (stage + 1))
	game.enemies.hazards.clear()
	game.enemies._fire_hazard(lunge)
	var before_lunge: Vector2 = boss.pos
	game.enemies.update(0.08)
	_check((boss.pos - before_lunge).dot(expected_direction) > 0.0, "Boss %d moves forward after its warning fires" % (stage + 1))
	for _step in range(32):
		if boss.charge_left <= 0.0:
			break
		game.enemies.update(0.1)
	_check(boss.pos.distance_to(expected_endpoint) < 1.0, "Boss %d completes the marked full-room lunge at its wall or obstacle" % (stage + 1))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
