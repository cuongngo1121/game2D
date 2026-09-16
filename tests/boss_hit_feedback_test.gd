extends SceneTree
## Regression: sustained projectile damage must not freeze a boss on its last Hurt frame.

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
	for stage in range(5):
		_test_continuous_hits(stage)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS HIT FEEDBACK PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("BOSS HIT FEEDBACK FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _test_continuous_hits(stage: int) -> void:
	game.enemies.clear()
	game.enemies._stage = stage
	game.enemies._grace = 0.0
	game.player.position = Vector2(250, 352)
	game.enemies._spawn("boss%d" % stage, Vector2(900, 352), true)
	var boss: Dictionary = game.enemies.units.back()
	boss.spawn_grace = 0.0
	var saw_hurt: bool = false
	var saw_non_hurt_frame: bool = false
	var hurt_frames: Dictionary = {}
	for _shot in range(36):
		game.enemies.damage_enemy(boss.id, 1.0)
		game.enemies.update(0.03)
		saw_hurt = saw_hurt or boss.anim_state == "hurt"
		saw_non_hurt_frame = saw_non_hurt_frame or boss.anim_state != "hurt"
		if boss.anim_state == "hurt":
			var hurt_fps: float = float(game.enemies.BOSS_ANIMATION_CONFIG.hurt.fps)
			var frame: int = mini(int(boss.anim_elapsed * hurt_fps), int(game.enemies.BOSS_ANIMATION_CONFIG.hurt.frames) - 1)
			hurt_frames[frame] = true
	_check(saw_hurt, "Boss %d shows a Hurt response during sustained damage" % (stage + 1))
	_check(saw_non_hurt_frame, "Boss %d alternates away from Hurt during sustained damage instead of freezing on one frame" % (stage + 1))
	_check(hurt_frames.size() == int(game.enemies.BOSS_ANIMATION_CONFIG.hurt.frames), "Boss %d reaches every authored Hurt frame during sustained damage" % (stage + 1))
	for _settle in range(8):
		game.enemies.update(0.05)
	_check(boss.anim_state != "hurt", "Boss %d exits Hurt once sustained damage stops" % (stage + 1))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
