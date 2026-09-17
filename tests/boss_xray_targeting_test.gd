extends SceneTree
## Regression seam for the progressive boss beam: every area must expose the
## authored map-spanning beam, with a denser cadence from Area 1 to Area 5.

const EnemyScript = preload("res://scripts/combat/enemy_system.gd")

class TestPlayer:
	extends Node2D
	var radius: float = 11.0
	func take_damage(_amount: float) -> void:
		pass

class TestRhythm:
	func beat_seconds() -> float:
		return 0.5

class TestAudio:
	func play_sfx(_name: String) -> void:
		pass

class TestProjectiles:
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
	var beam_counts: Array[int] = []
	for stage in range(5):
		beam_counts.append(_test_stage(stage))
	for stage in range(1, beam_counts.size()):
		_check(beam_counts[stage] > beam_counts[stage - 1],
			"Area %d schedules more map-spanning boss beams than Area %d" % [stage + 1, stage])
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS XRAY TARGETING PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("BOSS XRAY TARGETING FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _test_stage(stage: int) -> int:
	game.enemies.clear()
	game.enemies._stage = stage
	game.enemies._boss_room = true
	game.enemies._grace = 0.0
	game.player.position = Vector2(600.0, 352.0)
	game.enemies._spawn("boss%d" % stage, Vector2(700.0, 352.0), true)
	if game.enemies.units.is_empty():
		_check(false, "Area %d creates a boss for the X-ray test" % (stage + 1))
		return 0
	var boss: Dictionary = game.enemies.units[0]
	boss.spawn_grace = 0.0
	boss.transition = 0.0
	boss.phase = 2
	boss.charge_left = 0.0
	game.enemies._grace = 0.0
	var beam_count: int = 0
	var legacy_boss_laser: bool = false
	var legacy_boss_rail: bool = false
	game.player.position = boss.pos + Vector2(250.0, 120.0)
	boss.turn = 0
	for attack_index in range(12):
		game.enemies.hazards.clear()
		boss.charge_left = 0.0
		game.enemies._boss_attack(boss, attack_index)
		for hazard in game.enemies.hazards:
			var hazard_type: String = str(hazard.get("type", ""))
			if hazard_type == "boss_beam" and int(hazard.get("owner", -1)) == int(boss.id):
				beam_count += 1
				var path: Array = hazard.get("path", [])
				_check(path.size() == 2 and bool(hazard.get("map_spanning", false)),
					"Area %d boss beam records one map-spanning collision segment" % (stage + 1))
				if path.size() == 2:
					var map_span: float = path[0].distance_to(path[1])
					var minimum_span: float = minf(game.arena.size.x, game.arena.size.y) * 0.9
					_check(map_span >= minimum_span,
						"Area %d boss beam reaches across the arena" % (stage + 1))
					var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(boss.pos, path[0], path[1])
					_check(nearest.distance_to(boss.pos) < 0.1,
						"Area %d boss beam crosses its emitter" % (stage + 1))
			if hazard_type == "laser" and int(hazard.get("owner", -1)) == int(boss.id):
				legacy_boss_laser = true
			if hazard_type == "rail" and int(hazard.get("owner", -1)) == int(boss.id):
				legacy_boss_rail = true
	_check(beam_count > 0, "Area %d boss exposes the animated map-spanning beam" % (stage + 1))
	_check(not legacy_boss_laser, "Area %d boss has no duplicate legacy laser source" % (stage + 1))
	_check(not legacy_boss_rail, "Area %d boss has no duplicate legacy rail source" % (stage + 1))
	if stage == 3:
		game.enemies.hazards.clear()
		game.enemies._stage_trap(12)
		var duplicate_trap_beam: bool = false
		var duplicate_trap_rail: bool = false
		for hazard in game.enemies.hazards:
			if str(hazard.get("type", "")) == "laser":
				duplicate_trap_beam = true
			if str(hazard.get("type", "")) == "rail":
				duplicate_trap_rail = true
		_check(not duplicate_trap_beam, "Area 4 boss room does not add a second map-spanning X-ray trap")
		_check(not duplicate_trap_rail, "Area 4 boss room does not add a legacy map-spanning rail trap")
	return beam_count


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
