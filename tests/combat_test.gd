extends SceneTree
## Headless integration of the real enemy/projectile modules with deterministic host callbacks.

const EnemyScript = preload("res://scripts/combat/enemy_system.gd")
const ProjectileScript = preload("res://scripts/combat/projectile_system.gd")

class TestPlayer:
	extends Node2D
	var hp: float = 100.0
	var shield: float = 0.0
	var invulnerable: float = 0.0
	var radius: float = 11.0
	var host
	var damage_calls: int = 0
	var clear_on_hit: bool = false
	func take_damage(amount: float) -> void:
		if invulnerable > 0.0:
			return
		damage_calls += 1
		hp -= amount
		invulnerable = 0.85
		if clear_on_hit:
			host.projectiles.clear()
			host.enemies.clear()

class TestAudio:
	extends RefCounted
	func play_sfx(_name: String) -> void:
		pass

class TestRhythm:
	extends RefCounted
	var beat_duration: float = 60.0 / 90.0
	func beat_seconds() -> float:
		return beat_duration

class TestGame:
	extends Node2D
	var player: TestPlayer
	var arena := Rect2(64, 112, 1152, 480)
	var obstacles: Array[Rect2] = []
	var rhythm := TestRhythm.new()
	var audio := TestAudio.new()
	var rng := RandomNumberGenerator.new()
	var stage_index: int = 0
	var content: Dictionary = {"stages": [], "enemies": []}
	var projectiles
	var enemies
	var combat_active: bool = true
	var killed: Array[int] = []
	func initialize() -> void:
		player = TestPlayer.new()
		player.position = Vector2(150, 350)
		player.host = self
		add_child(player)
		projectiles = ProjectileScript.new()
		add_child(projectiles)
		projectiles.setup(self)
		enemies = EnemyScript.new()
		add_child(enemies)
		enemies.setup(self)
		for key in ["enemies", "stages"]:
			content[key] = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % key))
	func flash_text(_message: String, _color: Color) -> void:
		pass
	func add_fx(_pos: Vector2, _color: Color, _radius: float) -> void:
		pass
	func on_enemy_killed(enemy: Dictionary) -> void:
		killed.append(enemy.id)
	func boss_spawn_position() -> Vector2:
		# Match the runtime contract: boss encounters begin at the playable room centre.
		return arena.get_center()
	func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
		for rect in obstacles:
			if not ProjectileScript._segment_rect(a, b, rect).is_empty():
				return false
		return true
	func move_actor(pos: Vector2, motion: Vector2, radius: float) -> Vector2:
		var steps: int = maxi(1, int(ceil(motion.length() / 5.0)))
		for iteration in range(steps):
			for axis in range(2):
				var next: Vector2 = pos
				next[axis] += motion[axis] / steps
				next.x = clampf(next.x, arena.position.x + radius, arena.end.x - radius)
				next.y = clampf(next.y, arena.position.y + radius, arena.end.y - radius)
				var blocked: bool = false
				for obstacle in obstacles:
					if obstacle.grow(radius).has_point(next):
						blocked = true
				if not blocked:
					pos = next
		return pos

var checks: int = 0
var failures: Array[String] = []
var game: TestGame

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = TestGame.new()
	root.add_child(game)
	game.initialize()
	_test_collision()
	_test_behavior()
	_test_encounters()
	_test_hazards()
	_test_patterns()
	_test_reentrant_clear()
	_test_load()
	game.free()
	if failures.is_empty():
		print("COMBAT PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("COMBAT FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _reset() -> void:
	game.enemies.clear()
	game.projectiles.clear()
	game.obstacles.clear()
	game.killed.clear()
	game.player.position = Vector2(150, 350)
	game.player.hp = 100.0
	game.player.invulnerable = 0.0
	game.player.damage_calls = 0
	game.player.clear_on_hit = false
	game.enemies._grace = 0.0
	game.enemies._stage = 0

func _target(pos: Vector2, kind: String = "turret") -> Dictionary:
	game.enemies._spawn(kind, pos, kind.begins_with("boss"))
	var unit: Dictionary = game.enemies.units.back()
	unit.spawn_grace = 0.0
	unit.hp = 100.0
	unit.max_hp = 100.0
	unit.speed = 0.0
	return unit

func _test_collision() -> void:
	_reset()
	var a: Dictionary = _target(Vector2(330, 300))
	game.projectiles.spawn({"pos": Vector2(130, 300), "vel": Vector2(4000, 0), "damage": 30.0})
	game.projectiles.update(0.1)
	_check(a.hp == 70.0 and game.projectiles.count() == 0, "Swept projectile detects target crossed in one frame")
	_reset()
	a = _target(Vector2(450, 300))
	game.obstacles.append(Rect2(300, 220, 24, 160))
	game.projectiles.spawn({"pos": Vector2(130, 300), "vel": Vector2(8000, 0), "damage": 30.0})
	game.projectiles.update(0.1)
	_check(a.hp == 100.0 and game.projectiles.count() == 0, "Cover is hit before a target behind it at high speed")
	_check(game.enemies.nearest_target(Vector2(130, 300), 700.0).is_empty(), "Auto aim excludes target behind cover")
	game.enemies.damage_in_radius(Vector2(285, 300), 220.0, 50.0)
	_check(a.hp == 100.0, "Explosion respects cover")
	_reset()
	a = _target(Vector2(330, 300))
	var b: Dictionary = _target(Vector2(400, 300))
	game.projectiles.spawn({"pos": Vector2(130, 300), "vel": Vector2(3000, 0), "damage": 30.0, "pierce": 1})
	game.projectiles.update(0.1)
	_check(a.hp == 70.0 and b.hp == 70.0 and game.projectiles.count() == 0, "Pierce one hits exactly two distinct targets in travel order")
	_reset()
	a = _target(Vector2(330, 300))
	game.projectiles.spawn({"pos": Vector2(330, 300), "vel": Vector2.ZERO, "damage": 30.0, "pierce": 99})
	for frame in range(5):
		game.projectiles.update(0.016)
	_check(a.hp == 70.0, "Stationary overlapping projectile cannot repeatedly damage the same enemy")
	_reset()
	game.projectiles.spawn({"pos": Vector2(1190, 200), "vel": Vector2(500, 0), "bounces": 1})
	game.projectiles.update(0.1)
	_check(game.projectiles.count() == 1, "One bounce retains projectile after arena contact")
	if game.projectiles.count() == 1:
		_check(game.projectiles.active[0].vel.x < 0.0 and game.projectiles.active[0].pos.x < 1212, "Arena bounce reflects velocity and spends remaining frame time")
	game.projectiles.update(3.0)
	_check(game.projectiles.count() == 0, "Projectile lifespan eventually retires bounced projectile")
	_reset()
	game.obstacles.append(Rect2(300, 250, 40, 100))
	game.projectiles.spawn({"pos": Vector2(250, 300), "vel": Vector2(500, 0), "bounces": 1})
	game.projectiles.update(0.12)
	_check(game.projectiles.count() == 1 and game.projectiles.active[0].vel.x < 0.0, "Cover reflection uses obstacle entering face")
	_reset()
	game.projectiles.spawn({"pos": Vector2(50, 350), "vel": Vector2(3000, 0), "enemy": true})
	game.projectiles.update(0.1)
	_check(game.player.hp == 100.0 and game.projectiles.count() == 0, "Off-arena projectile cannot enter to cause unexpected damage")
	_reset()
	for i in range(4):
		game.projectiles.spawn({"pos": Vector2(150, 350), "vel": Vector2.ZERO, "enemy": true, "damage": 15.0})
	game.projectiles.update(0.016)
	_check(game.player.hp == 85.0 and game.player.damage_calls == 1, "Clustered enemy bullets respect one shared player invulnerability rule")

func _test_behavior() -> void:
	_reset()
	var a: Dictionary = _target(Vector2(330, 300))
	game.projectiles.spawn({"pos": Vector2(280, 300), "vel": Vector2(400, 0), "damage": 35.0, "behavior": "glitch"})
	game.projectiles.update(0.2)
	_check(a.hp == 100.0 and game.projectiles.active[0].armed, "Glitch arms on contact and delays damage")
	game.projectiles.update(0.5)
	_check(a.hp == 65.0 and game.projectiles.count() == 0, "Glitch explosion deals one radial hit after fuse")
	_reset()
	game.player.position = Vector2(150, 300)
	a = _target(Vector2(270, 300))
	game.projectiles.spawn({"pos": Vector2(175, 300), "vel": Vector2(400, 0), "damage": 15.0, "behavior": "disc", "pierce": 20, "life": 3.0})
	for frame in range(90):
		game.projectiles.update(1.0 / 60.0)
	_check(a.hp == 70.0 and game.projectiles.count() == 0, "Disc hits once outbound and once returning, then player catches it")
	_reset()
	game.projectiles.spawn({"pos": Vector2(400, 300), "vel": Vector2(50, 0), "enemy": true, "behavior": "split"})
	game.projectiles.update(0.7)
	_check(game.projectiles.count() == 2 and game.projectiles.active[0].behavior == "normal", "Delayed enemy shot splits once into two normal bullets")
	_reset()
	for clearable in [true, false]:
		game.projectiles.spawn({"pos": Vector2(200, 300), "vel": Vector2.ZERO, "enemy": true, "clearable": clearable})
	game.projectiles.spawn({"pos": Vector2(200, 300), "vel": Vector2.ZERO, "enemy": false})
	game.projectiles.erase_in_radius(Vector2(200, 300), 70.0)
	_check(game.projectiles.count() == 2, "Pulse erases only clearable enemy projectiles")
	game.projectiles.clear()
	var allocated: int = game.projectiles.total_allocated
	game.projectiles.spawn({"pos": Vector2(500, 300), "vel": Vector2.ZERO})
	_check(game.projectiles.total_allocated == allocated and game.projectiles.active[0].hit_ids.is_empty(), "Pool reuses shot dictionary with a fresh hit ledger")

func _test_encounters() -> void:
	_reset()
	game.enemies.spawn_room(0, 0, false, 4411)
	var signature: Array = []
	for unit in game.enemies.units:
		signature.append([unit.kind, unit.pos])
		_check(unit.pos.distance_to(game.player.position) >= 230.0 and unit.spawn_grace >= 1.3, "Initial spawn has distance and readable grace")
	game.enemies.spawn_room(0, 0, false, 4411)
	var repeated: Array = []
	for unit in game.enemies.units:
		repeated.append([unit.kind, unit.pos])
	_check(signature == repeated, "Encounter seed reproduces roster and spawn positions")
	var waves: int = 0
	while game.enemies.living_count() > 0 and waves < 8:
		for unit in game.enemies.units.duplicate():
			unit.spawn_grace = 0.0
			game.enemies.damage_enemy(unit.id, 99999.0)
			game.enemies.damage_enemy(unit.id, 99999.0)
		waves += 1
		if waves < 3:
			_check(game.enemies.living_count() > 0, "Door count stays nonzero between unfinished waves")
		game.enemies.update(1.9)
	_check(waves == 3 and game.enemies.living_count() == 0, "Stage one combat finishes after exactly three waves")
	var unique: Dictionary = {}
	for id in game.killed:
		unique[id] = true
	_check(unique.size() == game.killed.size(), "Each defeated enemy triggers exactly one reward callback")
	for stage in range(5):
		game.enemies.spawn_room(stage, 5, true, 888 + stage)
		var boss: Dictionary = game.enemies.units[0]
		boss.spawn_grace = 0.0
		game.enemies.damage_enemy(boss.id, boss.max_hp * 0.55)
		_check(boss.phase == 2 and boss.transition > 1.0, "Boss %d enters warned phase two" % stage)
		var hp: float = boss.hp
		game.enemies.damage_enemy(boss.id, 100.0)
		_check(boss.hp == hp, "Boss %d intermission blocks damage" % stage)
		boss.transition = 0.0
		if stage == 4:
			game.enemies.damage_enemy(boss.id, boss.max_hp * 0.2)
			_check(boss.phase == 3, "Final boss has a third phase")
			boss.transition = 0.0
		game.enemies.damage_enemy(boss.id, 99999.0)
		_check(game.enemies.boss_health() == Vector2.ZERO and game.enemies.living_count() == 0, "Boss %d can be finished" % stage)
	_reset()
	game.obstacles.append(Rect2(450, 112, 80, 330))
	game.enemies._build_grid()
	var path: Array = game.enemies._find_path(Vector2(700, 300), Vector2(150, 300))
	_check(not path.is_empty(), "Repath finds a route around tall cover")
	var routed_below: bool = false
	for point in path:
		if point.y > 442:
			routed_below = true
	_check(routed_below, "Repath uses the open corridor, preserving live enemy")

func _test_hazards() -> void:
	_reset()
	var sniper: Dictionary = _target(Vector2(850, 300), "sniper")
	game.enemies._warn_laser(sniper, true)
	var laser: Dictionary = game.enemies.hazards[0]
	var path: Array = laser.path.duplicate()
	_check(path.size() == 3, "Reflected laser warns exactly two segments, at most one reflection")
	_check(laser.warning >= maxf(0.8, 2.0 * game.rhythm.beat_seconds()), "Heavy warning satisfies max 0.8 seconds or two beats")
	game.player.position = Vector2(150, 510)
	game.enemies.update(0.4)
	_check(laser.path == path and sniper.pos == Vector2(850, 300), "Laser locks full path and emitter before firing")
	game.enemies.resume_grace()
	var remaining: float = laser.remaining
	game.enemies.update(0.2)
	_check(laser.remaining == remaining, "Resume grace freezes existing warning countdown")
	var count: int = game.enemies.hazards.size()
	game.enemies.on_beat(100)
	_check(game.enemies.hazards.size() == count, "Resume grace suppresses beat attacks")
	_reset()
	game.enemies._warn({"type": "floor", "pos": game.player.position, "radius": 70.0, "damage": 20.0})
	game.enemies._update_hazards(0.8)
	_check(game.player.hp == 100.0, "Floor marker cannot hurt during warning")
	game.enemies._update_hazards(0.6)
	_check(game.player.hp == 80.0, "Floor pulse hurts after its full two-beat warning")
	game.player.invulnerable = 0.0
	game.enemies._update_hazards(0.1)
	_check(game.player.hp == 80.0, "One floor pulse cannot damage repeatedly")
	_reset()
	game.player.invulnerable = 1.0
	game.enemies._warn({"type": "rail", "pos": game.player.position, "rect": Rect2(100, 320, 200, 60), "damage": 20.0})
	game.enemies._update_hazards(1.4)
	_check(game.player.hp == 100.0, "Dash invulnerability also protects against rail hazards")
	_reset()
	game.enemies._rail_trap(-1, 0)
	var left: Rect2 = game.enemies.hazards[0].rect
	var right: Rect2 = game.enemies.hazards[1].rect
	_check(right.position.x - left.end.x >= 170.0, "Rail retains a safe gap wider than player diameter plus margin")
	_reset()
	var support: Dictionary = _target(Vector2(800, 300), "support")
	for i in range(8):
		game.enemies._fire_hazard({"type": "support", "owner": support.id, "pos": support.pos, "summon": true, "damage": 0.0})
	_check(game.enemies.units.size() == 3, "Support cannot exceed two simultaneously living summons")

func _test_reentrant_clear() -> void:
	_reset()
	game.enemies._stage = 4
	var boss: Dictionary = _target(Vector2(400, 300), "boss4")
	for i in range(5):
		game.projectiles.spawn({"pos": Vector2(300, 300), "vel": Vector2(2000, 0), "damage": 50.0})
	game.projectiles.update(0.1)
	_check(boss.phase == 2 and game.projectiles.count() == 0, "Projectile-triggered final boss phase clear safely exits projectile iteration")
	_reset()
	game.player.clear_on_hit = true
	for i in range(4):
		game.projectiles.spawn({"pos": game.player.position, "vel": Vector2.ZERO, "enemy": true})
	game.projectiles.update(0.016)
	_check(game.projectiles.count() == 0, "Player death callback safely clears active projectile iteration")
	_reset()
	game.player.clear_on_hit = true
	game.enemies._warn({"type": "floor", "pos": game.player.position, "radius": 70.0})
	game.enemies._update_hazards(2.0)
	_check(game.enemies.hazards.is_empty(), "Player death callback safely clears active hazard iteration")

func _test_patterns() -> void:
	for kind in EnemyScript.DEFAULTS:
		_reset()
		var enemy: Dictionary = _target(Vector2(900, 350), kind)
		enemy.turn = 2 # Exercise support summon on its third attack.
		game.enemies._regular_attack(enemy, 24)
		_check(not game.enemies.hazards.is_empty(), "%s emits its readable attack marker" % kind)
		for frame in range(180):
			game.player.invulnerable = 1.0
			game.enemies.update(1.0 / 60.0)
			game.projectiles.update(1.0 / 60.0)
	for stage in range(5):
		for phase in range(1, 4 if stage == 4 else 3):
			_reset()
			game.enemies._stage = stage
			var boss: Dictionary = _target(Vector2(850, 350), "boss%d" % stage)
			boss.phase = phase
			for turn in range(3):
				game.enemies._boss_attack(boss, turn * 6)
				for frame in range(210):
					game.player.invulnerable = 1.0
					game.enemies.update(1.0 / 60.0)
					game.projectiles.update(1.0 / 60.0)
			_check(game.enemies.units.has(boss), "Boss %d phase %d executes attack/echo/charge/summon combinations" % [stage, phase])
	_reset()
	var enemy: Dictionary = _target(Vector2(900, 350), "fan")
	var beat: int = (enemy.attack_beats - (enemy.id * 2) % enemy.attack_beats) % enemy.attack_beats
	game.enemies.on_beat(beat)
	var count: int = game.enemies.hazards.size()
	game.enemies.on_beat(beat)
	_check(count > 0 and game.enemies.hazards.size() == count, "Repeated beat delivery cannot duplicate enemy attacks")

func _test_load() -> void:
	_reset()
	game.obstacles.append(Rect2(300, 320, 72, 72))
	game.obstacles.append(Rect2(600, 320, 72, 72))
	game.obstacles.append(Rect2(900, 320, 72, 72))
	for i in range(10):
		_target(Vector2(230 + i * 80, 460))
	for i in range(300):
		game.projectiles.spawn({"pos": Vector2(200 + (i % 50) * 10, 150 + (i / 50) * 17), "vel": Vector2(12, 0), "life": 60.0})
	var start: int = Time.get_ticks_usec()
	for frame in range(600):
		game.projectiles.update(1.0 / 60.0)
	var per_frame_ms: float = float(Time.get_ticks_usec() - start) / 600000.0
	_check(game.projectiles.count() == 300, "Load exercise preserves all 300 live projectiles without population culling")
	print("COMBAT LOAD: 300 projectiles + 10 targets + 3 covers; 600 simulated ticks; collision-loop mean %.3f ms/tick (headless desktop CPU only; no renderer or Android FPS claim)" % per_frame_ms)
