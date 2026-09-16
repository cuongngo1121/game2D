class_name EnemySystem
extends Node2D
## Beat-driven encounters. Every heavy attack is locked and warned for >= two beats.

const WARNING := Color("ff916d")
const ENEMY_COLOR := Color("ff647c")
const PIXEL_ENEMY_DIR := "res://assets/sprites/pixel_32/enemies/"
const PIXEL_ENEMY_ANIMATION_DIR := "res://assets/sprites/pixel_32/enemies/animations/"
const BOSS_ANIMATION_DIR := "res://assets/sprites/pixel_64/bosses/"
# Boss art is authored at 64px per frame but deliberately displayed at 150% of
# its former world scale. Keep the combat radius in the same proportion so
# contact, damage targeting, spawn clearance and the shadow agree with what the
# player sees across all five final rooms.
const BOSS_RENDER_SIZE := 120.0
const BOSS_COLLISION_RADIUS := 46.5
# Bosses actively chase a pressure range, then execute telegraphed room-spanning
# charges toward the player's position captured at warning time. The full route
# is always drawn before moving, so the longer charge is still readable.
const BOSS_CHASE_SPEED := 42.0
const BOSS_LUNGE_SPEED := 480.0
const BOSS_LUNGE_MIN_DISTANCE := 72.0
# Hurt sheets are three-frame reads. Under automatic fire, finish every frame
# before briefly returning to the live action, rather than holding frame zero
# or the final Hurt frame indefinitely.
const BOSS_HURT_PULSE_PERIOD := 0.36
const BOSS_HURT_PULSE_DURATION := 0.24
# Spawn locations need more space than a moving unit's collision radius.  This
# excludes thin doorway strips and corridors while retaining them for movement.
const CHAMBER_SPAWN_EDGE_CLEARANCE := 72.0
const CHAMBER_SPAWN_GRID_STEP := 24.0
const ENEMY_ANIMATION_CONFIG := {
	"idle": {"frames": 4, "fps": 6.0, "loop": true},
	"move": {"frames": 6, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 12.0, "loop": false},
	"hurt": {"frames": 3, "fps": 10.0, "loop": false},
	"death": {"frames": 6, "fps": 8.0, "loop": false},
}
const BOSS_ANIMATION_CONFIG := {
	"idle": {"frames": 4, "fps": 6.0, "loop": true},
	"move": {"frames": 6, "fps": 10.0, "loop": true},
	"attack": {"frames": 4, "fps": 12.0, "loop": false},
	"hurt": {"frames": 3, "fps": 10.0, "loop": false},
	"death": {"frames": 6, "fps": 8.0, "loop": false},
}
const BOSS_ANIMATION_IDS := {"boss0": "conductor_01", "boss1": "subwoofer", "boss2": "choir_widow", "boss3": "refractor", "boss4": "null_maestro"}
const STAGE_ROSTERS = [
	["drone", "fan", "skirmisher"],
	["charger", "turret", "drone", "fan"],
	["splitter", "support", "fan", "warden"],
	["sniper", "spiral", "charger", "skirmisher"],
	["warden", "sniper", "splitter", "support", "spiral", "charger"]]
const DEFAULTS = {
	"drone": {"hp": 48.0, "speed": 86.0, "attack_beats": 5},
	"fan": {"hp": 64.0, "speed": 36.0, "attack_beats": 6},
	"charger": {"hp": 92.0, "speed": 40.0, "attack_beats": 7},
	"turret": {"hp": 108.0, "speed": 0.0, "attack_beats": 7},
	"splitter": {"hp": 76.0, "speed": 32.0, "attack_beats": 7},
	"support": {"hp": 72.0, "speed": 34.0, "attack_beats": 9},
	"sniper": {"hp": 64.0, "speed": 25.0, "attack_beats": 8},
	"spiral": {"hp": 90.0, "speed": 28.0, "attack_beats": 6},
	"warden": {"hp": 125.0, "speed": 30.0, "attack_beats": 8},
	"skirmisher": {"hp": 62.0, "speed": 94.0, "attack_beats": 5}}

var game
var units: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_id: int = 1
var _stage: int = 0
var _room: int = 0
var _boss_room: bool = false
var _waves_left: int = 0
var _wave: int = 0
var _wave_delay: float = 0.0
var _grace: float = 0.0
var _time: float = 0.0
var _last_beat: int = -1
var _textures: Dictionary = {}
var _animation_textures: Dictionary = {}
var _boss_animation_textures: Dictionary = {}
var _death_animations: Array[Dictionary] = []
var _path_grid: Dictionary = {}
var _epoch: int = 0

func setup(owner_game) -> void:
	game = owner_game
	z_index = 8
	for kind in DEFAULTS:
		var pixel_path: String = PIXEL_ENEMY_DIR + "enemy_%s_32.png" % kind
		var fallback_path: String = "res://assets/sprites/enemy_%s.svg" % kind
		if ResourceLoader.exists(pixel_path):
			_textures[kind] = load(pixel_path)
		elif ResourceLoader.exists(fallback_path):
			_textures[kind] = load(fallback_path)
		for animation_name in ENEMY_ANIMATION_CONFIG:
			var config: Dictionary = ENEMY_ANIMATION_CONFIG[animation_name]
			var animation_path: String = PIXEL_ENEMY_ANIMATION_DIR + "enemy_%s_%s_%dx32.png" % [kind, animation_name, int(config.frames)]
			if ResourceLoader.exists(animation_path):
				_animation_textures["%s:%s" % [kind, animation_name]] = load(animation_path)
	for i in range(5):
		var path: String = "res://assets/sprites/boss_%d.svg" % (i + 1)
		if ResourceLoader.exists(path):
			_textures["boss%d" % i] = load(path)
	for boss_kind in BOSS_ANIMATION_IDS:
		var boss_id: String = BOSS_ANIMATION_IDS[boss_kind]
		for animation_name in BOSS_ANIMATION_CONFIG:
			var config: Dictionary = BOSS_ANIMATION_CONFIG[animation_name]
			var animation_path: String = BOSS_ANIMATION_DIR + "%s/animations/%s_%s_%dx64.png" % [boss_id, boss_id, animation_name, int(config.frames)]
			if ResourceLoader.exists(animation_path):
				_boss_animation_textures["%s:%s" % [boss_kind, animation_name]] = load(animation_path)

func clear() -> void:
	_epoch += 1
	units.clear()
	hazards.clear()
	_death_animations.clear()
	_waves_left = 0
	_wave = 0
	_wave_delay = 0.0
	_last_beat = -1
	_path_grid.clear()
	queue_redraw()

func spawn_room(stage: int, room_index: int, boss: bool, seed_value: int) -> void:
	clear()
	_stage = clampi(stage, 0, 4)
	_room = room_index
	_boss_room = boss
	_rng.seed = seed_value
	_grace = _warning_time()
	_build_grid()
	if boss:
		# Connected route maps own a chamber centre for every final encounter.
		# Do not derive a boss position from the arena edge: route sizes differ and
		# the boss would otherwise appear in a corridor or against a wall.
		_spawn("boss%d" % _stage, game.boss_spawn_position(), true)
	else:
		_waves_left = 3 if stage < 3 else 4
		_start_wave()

func spawn_debug_wave(stage: int, room_index: int, seed_value: int) -> void:
	# Debug Map needs the same roster, spawn safety, warning and first-wave size
	# as a normal encounter, but only one wave so the tester can repeatedly check
	# a room and its combat gates without clearing a full campaign encounter.
	clear()
	_stage = clampi(stage, 0, 4)
	_room = room_index
	_boss_room = false
	_rng.seed = seed_value
	_grace = _warning_time()
	_build_grid()
	_waves_left = 1
	_start_wave()

func resume_grace(seconds: float = 1.4) -> void:
	_grace = maxf(seconds, _warning_time())
	# Existing markers stay fixed, and receive a complete warning after resume.
	for hazard in hazards:
		if not hazard.fired:
			hazard.remaining = maxf(hazard.remaining, _warning_time())

func living_count() -> int:
	return units.size() + _waves_left

func boss_health() -> Vector2:
	for unit in units:
		if unit.boss:
			return Vector2(unit.hp, unit.max_hp)
	return Vector2.ZERO

func nearest_target(from: Vector2, max_range: float) -> Dictionary:
	var best: Dictionary = {}
	var distance_squared: float = max_range * max_range
	for unit in units:
		if unit.spawn_grace > 0.0:
			continue
		var distance: float = from.distance_squared_to(unit.pos)
		if distance < distance_squared and game.has_line_of_sight(from, unit.pos):
			distance_squared = distance
			best = unit
	return best

func damage_in_radius(center: Vector2, radius: float, amount: float) -> void:
	var hit_ids: Array[int] = []
	for unit in units:
		if center.distance_to(unit.pos) <= radius + unit.radius and game.has_line_of_sight(center, unit.pos):
			hit_ids.append(unit.id)
	for id in hit_ids:
		damage_enemy(id, amount)

func damage_enemy(id: int, amount: float) -> void:
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if unit.id != id or unit.spawn_grace > 0.0 or unit.transition > 0.0:
			continue
		var multiplier: float = 1.6 if unit.exposed > 0.0 else 1.0
		unit.hp = maxf(0.0, unit.hp - amount * multiplier)
		var starts_hurt_read: bool = unit.hurt_anim <= 0.0
		unit.hit_flash = 0.12
		# A single hit stays readable long enough to reach all three 10 FPS Hurt
		# frames. Repeated projectiles refresh this window without restarting its
		# pulse, so the boss never appears stuck on the first frame.
		unit.hurt_anim = 0.30
		if unit.boss and starts_hurt_read:
			# Preserve the start of this hit sequence while automatic fire refreshes
			# the duration. The animation pulse must begin with a visible Hurt frame.
			unit.hurt_pulse_started = _time
		if unit.hp <= 0.0:
			if unit.boss and _boss_animation_textures.has("%s:death" % unit.kind):
				_death_animations.append({"kind": unit.kind, "pos": unit.pos, "elapsed": 0.0, "boss": true})
			elif not unit.boss and _animation_textures.has("%s:death" % unit.kind):
				_death_animations.append({"kind": unit.kind, "pos": unit.pos, "elapsed": 0.0})
			units.remove_at(i)
			game.add_fx(unit.pos, Color("35e7ff"), unit.radius * 2.5)
			game.audio.play_sfx("hit")
			# Owned unfinished attacks cease when their source is destroyed.
			hazards = hazards.filter(func(h: Dictionary) -> bool: return h.owner != id)
			game.on_enemy_killed(unit)
		elif unit.boss:
			var fraction: float = unit.hp / unit.max_hp
			var desired: int = 1
			if unit.kind == "boss4":
				desired = 3 if fraction <= 0.33 else (2 if fraction <= 0.67 else 1)
			else:
				desired = 2 if fraction <= 0.5 else 1
			if desired > unit.phase:
				unit.phase = desired
				unit.transition = _warning_time() + 0.7
				unit.charge_left = 0.0
				hazards = hazards.filter(func(h: Dictionary) -> bool: return h.owner != id)
				if unit.kind == "boss4":
					game.projectiles.clear() # Explicit, readable phase intermission.
					_grace = unit.transition
				game.flash_text("%s · GIAI ĐOẠN %d" % [unit.get("name", "BOSS"), desired], Color("35e7ff"))
				game.audio.play_sfx("boss")
		return

func update(delta: float) -> void:
	var update_epoch: int = _epoch
	_time += delta
	_grace = maxf(0.0, _grace - delta)
	for i in range(_death_animations.size() - 1, -1, -1):
		_death_animations[i].elapsed += delta
		var death: Dictionary = _death_animations[i]
		var death_duration: float = 6.0 / 8.0
		if bool(death.get("boss", false)):
			death_duration = float(BOSS_ANIMATION_CONFIG.death.frames) / float(BOSS_ANIMATION_CONFIG.death.fps)
		if death.elapsed >= death_duration:
			_death_animations.remove_at(i)
	if units.is_empty() and _waves_left > 0:
		_wave_delay += delta
		if _wave_delay >= 1.8:
			_start_wave()
	for unit in units:
		unit.hit_flash = maxf(0.0, unit.hit_flash - delta)
		unit.spawn_grace = maxf(0.0, unit.spawn_grace - delta)
		unit.transition = maxf(0.0, unit.transition - delta)
		unit.exposed = maxf(0.0, unit.exposed - delta)
		unit.contact_cd = maxf(0.0, unit.contact_cd - delta)
		unit.attack_anim = maxf(0.0, unit.attack_anim - delta)
		unit.hurt_anim = maxf(0.0, unit.hurt_anim - delta)
		var can_act: bool = unit.spawn_grace <= 0.0 and unit.transition <= 0.0 and _grace <= 0.0
		var previous_pos: Vector2 = unit.pos
		if can_act:
			_move_unit(unit, delta)
		unit.last_pos = previous_pos if can_act else unit.pos
		_update_enemy_animation(unit, delta)
		if not can_act:
			continue
		if unit.pos.distance_to(game.player.position) < unit.radius + game.player.radius and unit.contact_cd <= 0.0:
			game.player.take_damage(unit.damage)
			if update_epoch != _epoch:
				return
			unit.contact_cd = 1.0
	if _grace <= 0.0:
		_update_hazards(delta)
	queue_redraw()

func on_beat(index: int) -> void:
	if index == _last_beat:
		return
	_last_beat = index
	if not game.combat_active or _grace > 0.0:
		return
	for unit in units:
		if unit.spawn_grace > 0.0 or unit.transition > 0.0 or unit.charge_left > 0.0 or unit.exposed > 0.0:
			continue
		var interval: int = unit.attack_beats
		if (index + unit.id * 2) % interval == 0:
			if unit.boss:
				_boss_attack(unit, index)
			else:
				_regular_attack(unit, index)
	if index % 12 == 4 and _heavy_hazard_count() < 2:
		_stage_trap(index)

func _warning_time() -> float:
	return maxf(0.8, float(game.rhythm.beat_seconds()) * 2.0)

func _start_wave() -> void:
	_waves_left -= 1
	_wave += 1
	_wave_delay = 0.0
	var roster: Array = STAGE_ROSTERS[_stage]
	var stage_data: Array = game.content.get("stages", [])
	if _stage < stage_data.size() and stage_data[_stage].get("enemy_ids", []).size() > 0:
		roster = stage_data[_stage].enemy_ids
	var number: int = 4 + mini(_stage, 3) + int(_wave > 1)
	for i in range(number):
		var kind: String = str(roster[(_rng.randi_range(0, roster.size() - 1) + i) % roster.size()])
		_spawn(kind, _spawn_position(i), false)
	game.flash_text("ĐỢT %d · TÍN HIỆU ĐỊCH" % _wave, WARNING)

func _spawn_position(_index: int) -> Vector2:
	var area := _combat_spawn_bounds()
	for attempt in range(90):
		var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if _chamber_spawn_open(p, 24.0) and p.distance_to(game.player.position) >= 230.0:
			var crowded: bool = false
			for unit in units:
				if p.distance_to(unit.pos) < 62.0:
					crowded = true
			if not crowded:
				return p
	# A normal movement grid intentionally contains the connecting corridors.
	# Its old fallback therefore recreated the same spawn bug after a random miss.
	# Scan only the current room bounds and rank valid chamber-interior cells.
	return _best_chamber_spawn_position(area)

func _combat_spawn_bounds() -> Rect2:
	if not game.has_method("combat_walkable_polygons"):
		return game.arena.grow(-46.0)
	var polygons: Array[PackedVector2Array] = game.combat_walkable_polygons()
	var has_point := false
	var bounds := Rect2()
	for polygon in polygons:
		for point in polygon:
			if not has_point:
				bounds = Rect2(point, Vector2.ZERO)
				has_point = true
			else:
				bounds = bounds.expand(point)
	if not has_point:
		return game.arena.grow(-46.0)
	return bounds.intersection(game.arena.grow(-46.0))

func _chamber_spawn_open(pos: Vector2, radius: float) -> bool:
	if not _position_open(pos, radius):
		return false
	var edge_clearance := _combat_room_edge_clearance(pos)
	return edge_clearance == INF or edge_clearance >= maxf(CHAMBER_SPAWN_EDGE_CLEARANCE, radius + 20.0)

func _combat_room_edge_clearance(pos: Vector2) -> float:
	if not game.has_method("combat_walkable_polygons"):
		return INF
	var polygons: Array[PackedVector2Array] = game.combat_walkable_polygons()
	if polygons.is_empty():
		return INF
	var best_clearance := -INF
	for polygon in polygons:
		if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(pos, polygon):
			continue
		var clearance := INF
		for edge in range(polygon.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(pos, polygon[edge], polygon[(edge + 1) % polygon.size()])
			clearance = minf(clearance, pos.distance_to(nearest))
		best_clearance = maxf(best_clearance, clearance)
	return best_clearance

func _best_chamber_spawn_position(area: Rect2) -> Vector2:
	var best := Vector2.ZERO
	var best_score := -INF
	var columns := maxi(1, int(ceil(area.size.x / CHAMBER_SPAWN_GRID_STEP)))
	var rows := maxi(1, int(ceil(area.size.y / CHAMBER_SPAWN_GRID_STEP)))
	for y in range(rows):
		for x in range(columns):
			var p := area.position + Vector2(
				minf((float(x) + 0.5) * CHAMBER_SPAWN_GRID_STEP, area.size.x),
				minf((float(y) + 0.5) * CHAMBER_SPAWN_GRID_STEP, area.size.y)
			)
			if not _chamber_spawn_open(p, 24.0):
				continue
			var nearest_unit := INF
			for unit in units:
				nearest_unit = minf(nearest_unit, p.distance_to(unit.pos))
			var edge_clearance := _combat_room_edge_clearance(p)
			var score := minf(p.distance_to(game.player.position), 900.0) + minf(nearest_unit, 900.0) * 0.6 + edge_clearance * 2.0
			if score > best_score:
				best_score = score
				best = p
	if best_score > -INF:
		return best
	# A malformed or extremely narrow legacy room has no chamber-sized cell.
	# Preserve the old geometry-safe fallback rather than spawning outside map
	# collision; authored route rooms all use the stricter branch above.
	for key in _path_grid:
		var fallback: Vector2 = _cell_position(key)
		if _position_open(fallback, 24.0):
			return fallback
	return game.player.position

func _spawn(kind: String, pos: Vector2, boss: bool, summoner: int = -1) -> void:
	var stats: Dictionary = DEFAULTS.get(kind, DEFAULTS.drone).duplicate()
	for config in game.content.get("enemies", []):
		if config.get("id", "") == kind:
			stats.merge(config, true)
	var max_hp: float = float(stats.get("hp", 60.0)) * (1.0 + _stage * 0.15)
	if boss:
		max_hp = float(stats.get("boss_hp", 1100.0 + _stage * 300.0))
		var stages: Array = game.content.get("stages", [])
		if _stage < stages.size():
			stats["name"] = stages[_stage].get("boss", kind.to_upper())
	var radius: float = float(stats.get("radius", BOSS_COLLISION_RADIUS if boss else 15.0))
	if not _position_open(pos, radius):
		pos = _spawn_position(0)
	units.append({"id": _next_id, "kind": kind, "pos": pos, "hp": max_hp, "max_hp": max_hp,
		"radius": radius, "boss": boss, "phase": 1, "name": stats.get("name", kind.to_upper()),
		"speed": float(stats.get("speed", 35.0)) if not boss else BOSS_CHASE_SPEED + float(_stage) * 2.0,
		"damage": float(stats.get("damage", 12.0 + _stage * 2.0)),
		"bullet_speed": float(stats.get("bullet_speed", 155.0 + _stage * 9.0)),
		"attack_beats": int(stats.get("attack_beats", 8)) if not boss else 6,
		"spawn_grace": _warning_time(), "hit_flash": 0.0, "transition": 0.0,
		"exposed": 0.0, "contact_cd": 0.0, "charge_left": 0.0, "charge_dir": Vector2.ZERO,
		"path": [], "path_age": 0.0, "stuck": 0.0, "last_pos": pos,
		"turn": 0, "summoner": summoner, "reward_scale": 0.35 if summoner >= 0 else 1.0,
		"anim_state": "idle", "anim_elapsed": 0.0, "attack_anim": 0.0, "hurt_anim": 0.0,
		"hurt_pulse_started": 0.0})
	units.back()["reward"] = maxi(1, int(float(stats.get("reward", 25 if boss else 4)) * (0.35 if summoner >= 0 else 1.0)))
	_next_id += 1

func _unit(id: int) -> Dictionary:
	for unit in units:
		if unit.id == id:
			return unit
	return {}

func _move_unit(unit: Dictionary, delta: float) -> void:
	var assignment_waypoint := Vector2.ZERO
	if game != null and game.has_method("assignment_demo_intruder_waypoint"):
		assignment_waypoint = game.assignment_demo_intruder_waypoint(int(unit.id))
	if assignment_waypoint.length_squared() > 0.0:
		var to_waypoint: Vector2 = assignment_waypoint - unit.pos
		if to_waypoint.length_squared() > 1.0:
			var waypoint_motion: Vector2 = to_waypoint.normalized() * unit.speed * delta
			unit.pos = game.move_combat_actor(unit.pos, waypoint_motion, unit.radius) if game.has_method("move_combat_actor") else game.move_actor(unit.pos, waypoint_motion, unit.radius)
			return
	if unit.charge_left > 0.0:
		var velocity: Vector2 = unit.charge_dir * (BOSS_LUNGE_SPEED if unit.boss else 390.0)
		var target: Vector2 = game.move_combat_actor(unit.pos, velocity * delta, unit.radius) if game.has_method("move_combat_actor") else game.move_actor(unit.pos, velocity * delta, unit.radius)
		unit.charge_left -= delta
		if target.distance_to(unit.pos) < velocity.length() * delta * 0.45:
			unit.charge_left = 0.0
			unit.exposed = 2.8 if unit.boss else 1.0
			game.add_fx(target, WARNING, unit.radius * 1.8)
		unit.pos = target
		return
	for hazard in hazards:
		if hazard.owner == unit.id and not hazard.fired and hazard.type in ["charge", "laser"]:
			return # Locked heavy attacks use exactly the position shown by their marker.
	if unit.speed <= 0.0 or unit.exposed > 0.0:
		return
	var to_player: Vector2 = game.player.position - unit.pos
	var distance: float = to_player.length()
	var direction := Vector2.ZERO
	if unit.kind == "drone" or unit.kind == "charger":
		direction = to_player.normalized()
	elif unit.boss:
		# All bosses keep the player inside a pressure ring instead of passively
		# circling the arena centre. Higher phases shrink the ring, making the
		# encounter deliberately more assertive while leaving a dodge lane.
		var player_direction := to_player.normalized()
		var strafe_direction := player_direction.orthogonal() * (1.0 if (unit.id + unit.turn) % 2 else -1.0)
		var desired_distance := 230.0 - float(unit.phase - 1) * 28.0
		if distance > desired_distance + 28.0:
			direction = (player_direction * 0.9 + strafe_direction * 0.45).normalized()
		elif distance < desired_distance - 38.0:
			direction = (-player_direction * 0.8 + strafe_direction * 0.65).normalized()
		else:
			direction = strafe_direction
	elif unit.kind == "skirmisher":
		direction = to_player.normalized().orthogonal() * (1.0 if unit.id % 2 else -1.0)
		if distance > 340.0:
			direction = (direction + to_player.normalized()).normalized()
		elif distance < 150.0:
			direction = (direction - to_player.normalized()).normalized()
	elif distance > 280.0:
		direction = to_player.normalized()
	elif distance < 175.0:
		direction = -to_player.normalized()
	unit.path_age += delta
	if not game.has_line_of_sight(unit.pos, game.player.position) or unit.stuck > 1.0:
		if unit.path_age > 1.0 or unit.path.is_empty():
			unit.path = _find_path(unit.pos, game.player.position)
			unit.path_age = 0.0
		while not unit.path.is_empty() and unit.pos.distance_to(unit.path[0]) < 22.0:
			unit.path.pop_front()
		if not unit.path.is_empty():
			direction = (unit.path[0] - unit.pos).normalized()
	var separation := Vector2.ZERO
	for other in units:
		if other.id == unit.id:
			continue
		var apart: Vector2 = unit.pos - other.pos
		if apart.length_squared() < pow(unit.radius + other.radius + 8.0, 2.0) and apart.length_squared() > 0.01:
			separation += apart.normalized() * 0.6
	var motion: Vector2 = (direction + separation).limit_length() * unit.speed * delta
	var next: Vector2 = game.move_combat_actor(unit.pos, motion, unit.radius) if game.has_method("move_combat_actor") else game.move_actor(unit.pos, motion, unit.radius)
	if direction.length_squared() > 0.1 and next.distance_squared_to(unit.pos) < 0.01:
		unit.stuck += delta
	else:
		unit.stuck = maxf(0.0, unit.stuck - delta)
	unit.pos = next

func _regular_attack(unit: Dictionary, beat: int) -> void:
	unit.turn += 1
	unit.attack_anim = 0.48
	var angle: float = (game.player.position - unit.pos).angle()
	match unit.kind:
		"drone":
			if unit.pos.distance_to(game.player.position) > 120.0:
				_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 1, "spread": 0.0})
		"fan":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 5, "spread": 1.05})
		"charger":
			if _heavy_hazard_count() < 3:
				_warn_charge(unit)
		"turret":
			_warn({"type": "ring", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 13, "gap": angle})
		"splitter":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 3, "spread": 0.9, "behavior": "split"})
		"support":
			_warn({"type": "support", "owner": unit.id, "pos": unit.pos, "summon": unit.turn % 3 == 0})
		"sniper":
			if _heavy_hazard_count() < 3:
				_warn_laser(unit, false)
		"spiral":
			_warn({"type": "spiral", "owner": unit.id, "pos": unit.pos, "angle": beat * 0.35, "count": 11})
		"warden":
			if _heavy_hazard_count() < 3:
				_warn({"type": "floor", "owner": unit.id, "pos": game.player.position, "radius": 68.0, "damage": unit.damage})
		"skirmisher":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 2, "spread": 0.18})

func _boss_attack(unit: Dictionary, beat: int) -> void:
	unit.turn += 1
	unit.attack_anim = 0.48
	var angle: float = (game.player.position - unit.pos).angle()
	match unit.kind:
		"boss0":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 9, "spread": 2.0, "skip_middle": true})
			if unit.phase == 2 and unit.turn % 2 == 0:
				_rail_trap(unit.id, unit.turn)
			_try_boss_lunge(unit)
		"boss1":
			if not _try_boss_lunge(unit):
				_warn({"type": "ring", "owner": unit.id, "pos": unit.pos, "angle": unit.turn * 0.28, "count": 22, "gap": angle, "speed": 140.0})
		"boss2":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 7, "spread": 1.55, "echo": true})
			if unit.phase == 2 and unit.turn % 3 == 0:
				_warn({"type": "support", "owner": unit.id, "pos": unit.pos, "summon": true})
			_try_boss_lunge(unit)
		"boss3":
			_warn_laser(unit, true)
			if unit.phase == 2 and unit.turn % 2 == 0:
				_warn({"type": "spiral", "owner": unit.id, "pos": unit.pos, "angle": beat * 0.25, "count": 15, "speed": 130.0})
			_try_boss_lunge(unit)
		"boss4":
			if not _try_boss_lunge(unit) and unit.turn % 3 == 0 and unit.phase >= 2:
				_warn_laser(unit, false)
			elif not _has_pending_boss_lunge(unit.id):
				_warn({"type": "ring", "owner": unit.id, "pos": unit.pos, "angle": unit.turn * 0.22, "count": 25, "gap": unit.turn * 0.48, "speed": 145.0})
			if unit.phase >= 2:
				_warn({"type": "floor", "owner": unit.id, "pos": game.player.position, "radius": 72.0, "damage": unit.damage})
			if unit.phase == 3 and unit.turn % 3 == 1:
				_rail_trap(unit.id, unit.turn)

func _boss_lunge_interval(unit: Dictionary) -> int:
	match unit.kind:
		"boss0": return 2 if unit.phase >= 2 else 3
		"boss1": return 3 if unit.phase >= 2 else 4
		"boss2": return 3 if unit.phase >= 2 else 4
		"boss3": return 3 if unit.phase >= 2 else 4
		"boss4": return 3 if unit.phase >= 2 else 4
	return 4

func _has_pending_boss_lunge(owner: int) -> bool:
	for hazard in hazards:
		if hazard.owner == owner and hazard.type == "charge" and bool(hazard.get("boss_lunge", false)):
			return true
	return false

func _try_boss_lunge(unit: Dictionary) -> bool:
	if unit.turn % _boss_lunge_interval(unit) != 0 or _heavy_hazard_count() >= 2:
		return false
	return _warn_boss_lunge(unit)

func _base_animation_state(unit: Dictionary) -> String:
	if unit.attack_anim > 0.0 or unit.charge_left > 0.0:
		return "attack"
	if unit.pos.distance_squared_to(unit.last_pos) > 0.01:
		return "move"
	return "idle"

func _update_enemy_animation(unit: Dictionary, delta: float) -> void:
	var next_state: String = _base_animation_state(unit)
	if unit.hurt_anim > 0.0:
		if not unit.boss:
			next_state = "hurt"
		else:
			# Damage can arrive faster than the one-shot Hurt sheet can finish.
			# Keep the hit read, but pulse back to real movement/attack frames so
			# automatic weapons create a visible, responsive flicker rather than a
			# frozen final Hurt frame.
			var pulse_elapsed: float = maxf(0.0, _time - float(unit.get("hurt_pulse_started", _time)))
			var pulse: float = fposmod(pulse_elapsed, BOSS_HURT_PULSE_PERIOD)
			if pulse < BOSS_HURT_PULSE_DURATION:
				next_state = "hurt"
	if unit.anim_state != next_state:
		unit.anim_state = next_state
		unit.anim_elapsed = 0.0
	else:
		unit.anim_elapsed += delta

func clear_animation_delay() -> float:
	# Boss defeat remains non-interactive, but the room waits just long enough to
	# show the authored 64px death read before it presents the victory/reward UI.
	for death in _death_animations:
		if bool(death.get("boss", false)):
			return float(BOSS_ANIMATION_CONFIG.death.frames) / float(BOSS_ANIMATION_CONFIG.death.fps)
	return 0.35

func _warn(spec: Dictionary) -> void:
	var warning: float = _warning_time()
	var hazard: Dictionary = {"owner": -1, "remaining": warning, "warning": warning,
		"fired": false, "active_time": 0.5, "hit_player": false, "damage": 15.0,
		"color": WARNING, "radius": 40.0}
	hazard.merge(spec, true)
	hazards.append(hazard)

func _warn_charge(unit: Dictionary) -> void:
	var direction: Vector2 = (game.player.position - unit.pos).normalized()
	var path: Array[Vector2] = [unit.pos, _ray_endpoint(unit.pos, direction, unit.radius)]
	_warn({"type": "charge", "owner": unit.id, "pos": unit.pos, "path": path, "direction": direction, "radius": unit.radius})

func _warn_boss_lunge(unit: Dictionary) -> bool:
	var to_player: Vector2 = game.player.position - unit.pos
	var distance: float = to_player.length()
	if distance <= 0.001:
		return false
	var direction: Vector2 = to_player / distance
	# Match the regular charger: lock the aim at telegraph time, then cross the
	# whole reachable lane until the boss reaches a wall or obstacle.
	var endpoint: Vector2 = _ray_endpoint(unit.pos, direction, unit.radius)
	var travel: float = unit.pos.distance_to(endpoint)
	if travel < BOSS_LUNGE_MIN_DISTANCE:
		return false
	_warn({"type": "charge", "owner": unit.id, "pos": unit.pos, "path": [unit.pos, endpoint],
		"direction": direction, "radius": unit.radius, "charge_duration": travel / BOSS_LUNGE_SPEED,
		"boss_lunge": true, "warning_text": "LƯỚT NHẮM MỤC TIÊU"})
	return true

func _warn_laser(unit: Dictionary, reflected: bool) -> void:
	var direction: Vector2 = (game.player.position - unit.pos).normalized()
	var start: Vector2 = unit.pos
	var contact: Dictionary = _ray_contact(start, direction)
	var points: Array[Vector2] = [start, contact.pos]
	if reflected and contact.normal != Vector2.ZERO:
		var reflected_direction: Vector2 = direction.bounce(contact.normal)
		points.append(_ray_endpoint(contact.pos + reflected_direction * 1.0, reflected_direction, 0.0))
	_warn({"type": "laser", "owner": unit.id, "pos": start, "path": points,
		"radius": 7.0 if unit.boss else 5.0, "damage": unit.damage * 1.3, "reflected": reflected})

func _heavy_hazard_count() -> int:
	var count: int = 0
	for hazard in hazards:
		if hazard.type in ["floor", "rail", "laser", "charge"]:
			count += 1
	return count

func _stage_trap(beat: int) -> void:
	match _stage:
		0:
			_rail_trap(-1, beat / 12)
		1:
			# Bass Foundry is an authored, connected route rather than the legacy
			# rectangular arena. Anchor the warning to the current combat room so the
			# piston marker never appears in a sealed-off chamber or inside a wall.
			var offset: float = 140.0 if beat % 24 else -140.0
			var center: Vector2 = game.player.position + Vector2(offset, 0.0)
			if not _position_open(center, 70.0):
				center = game.player.position + Vector2(-offset, 0.0)
			if not _position_open(center, 70.0):
				center = game.player.position
			_warn({"type": "floor", "pos": center, "radius": 70.0, "damage": 18.0, "shape": "piston"})
		2:
			_warn({"type": "floor", "pos": game.player.position, "radius": 65.0, "damage": 17.0})
		3:
			var x: float = game.arena.position.x + 320.0 + float((beat / 12) % 2) * 450.0
			_warn({"type": "laser", "pos": Vector2(x, game.arena.position.y),
				"path": [Vector2(x, game.arena.position.y), Vector2(x, game.arena.end.y)], "radius": 6.0, "damage": 18.0})
		4:
			var column: int = int(beat / 12) % 4
			for row in range(2):
				var p := Vector2(game.arena.position.x + 160.0 + column * 245.0, game.arena.position.y + 125.0 + row * 225.0)
				_warn({"type": "floor", "pos": p, "radius": 58.0, "damage": 18.0, "shape": "tile"})

func _rail_trap(owner: int, sequence: int) -> void:
	var y: float = game.arena.position.y + (145.0 if sequence % 2 else 340.0)
	var safe_x: float = game.arena.get_center().x + (-120.0 if sequence % 2 else 180.0)
	# Two marked segments with a 170px opening; never an arena-spanning barrier.
	for rect in [Rect2(game.arena.position.x, y - 18.0, safe_x - 85.0 - game.arena.position.x, 36.0),
		Rect2(safe_x + 85.0, y - 18.0, game.arena.end.x - safe_x - 85.0, 36.0)]:
		_warn({"type": "rail", "owner": owner, "pos": rect.get_center(), "rect": rect, "damage": 17.0})

func _update_hazards(delta: float) -> void:
	var update_epoch: int = _epoch
	# Use an index bounded by the initial size: echoes append safely for next frame.
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if hazard.owner >= 0 and _unit(hazard.owner).is_empty():
			hazards.remove_at(i)
			continue
		hazard.remaining -= delta
		if not hazard.fired and hazard.remaining <= 0.0:
			hazard.fired = true
			hazard.remaining = hazard.active_time
			_fire_hazard(hazard)
		if hazard.fired:
			_damage_hazard(hazard)
			if update_epoch != _epoch:
				return
			if hazard.remaining <= 0.0:
				hazards.remove_at(i)

func _fire_hazard(hazard: Dictionary) -> void:
	var unit: Dictionary = _unit(hazard.owner)
	var damage: float = unit.get("damage", hazard.damage)
	var speed: float = hazard.get("speed", unit.get("bullet_speed", 155.0))
	match hazard.type:
		"volley":
			var count: int = hazard.count
			for i in range(count):
				if hazard.get("skip_middle", false) and i == count / 2:
					continue
				var angle: float = hazard.angle + (float(i) / maxf(1.0, count - 1.0) - 0.5) * hazard.spread
				_bullet(hazard.pos, angle, speed, damage, hazard.get("behavior", "normal"))
			if hazard.get("echo", false):
				var echo: Dictionary = hazard.duplicate(true)
				echo.echo = false
				echo.remaining = _warning_time()
				echo.fired = false
				echo.color = Color("be8aff")
				hazards.append(echo)
		"ring":
			for i in range(hazard.count):
				var angle: float = hazard.angle + TAU * float(i) / hazard.count
				if absf(wrapf(angle - hazard.gap, -PI, PI)) > 0.46:
					_bullet(hazard.pos, angle, speed, damage)
		"spiral":
			for i in range(hazard.count):
				# Two opposite sectors stay empty; slow staggered spokes leave lanes.
				if i % 6 == 0 or i % 6 == 1:
					continue
				var angle: float = hazard.angle + TAU * float(i) / hazard.count
				_bullet(hazard.pos, angle, speed * (0.8 + (i % 3) * 0.08), damage)
		"charge":
			if not unit.is_empty():
				unit.charge_dir = hazard.direction
				unit.charge_left = float(hazard.get("charge_duration", 1.8))
		"support":
			for other in units:
				if other.id != hazard.owner and other.pos.distance_to(hazard.pos) < 260.0:
					other.hp = minf(other.max_hp, other.hp + 8.0)
					game.add_fx(other.pos, Color("75ffc4"), 23.0)
			if hazard.get("summon", false) and not unit.is_empty():
				var summons: int = 0
				for other in units:
					if other.summoner == unit.id:
						summons += 1
				if summons < (3 if unit.boss else 2) and units.size() < 14:
					_spawn("fan" if unit.boss else "drone", _spawn_position(summons), false, unit.id)
		"laser", "rail", "floor":
			game.audio.play_sfx("boss" if not unit.is_empty() and unit.boss else "hit")

func _bullet(origin: Vector2, angle: float, speed: float, damage: float, behavior: String = "normal") -> void:
	var direction := Vector2.from_angle(angle)
	# A muzzle may be near a rushing player; the full preceding marker warns them.
	game.projectiles.spawn({"pos": origin + direction * 20.0, "vel": direction * speed,
		"damage": damage, "enemy": true, "radius": 4.5, "life": 6.5,
		"color": Color("ffc279") if behavior == "split" else ENEMY_COLOR, "behavior": behavior})

func _damage_hazard(hazard: Dictionary) -> void:
	if hazard.hit_player:
		return
	var p: Vector2 = game.player.position
	var player_radius: float = game.player.radius
	var hits: bool = false
	match hazard.type:
		"floor":
			hits = p.distance_to(hazard.pos) < hazard.radius + player_radius
		"rail":
			hits = hazard.rect.grow(player_radius).has_point(p)
		"laser":
			for i in range(hazard.path.size() - 1):
				var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(p, hazard.path[i], hazard.path[i + 1])
				if nearest.distance_to(p) < hazard.radius + player_radius:
					hits = true
	if hits:
		hazard.hit_player = true
		game.player.take_damage(hazard.damage)

func _position_open(pos: Vector2, radius: float) -> bool:
	if game.has_method("is_combat_position") and not game.is_combat_position(pos, radius):
		return false
	if not game.has_method("is_combat_position") and game.has_method("is_walkable_position") and not game.is_walkable_position(pos, radius):
		return false
	if not game.arena.grow(-radius).has_point(pos):
		return false
	for rect in game.obstacles:
		if rect.grow(radius).has_point(pos):
			return false
	return true

func _ray_endpoint(origin: Vector2, direction: Vector2, inset: float) -> Vector2:
	return _ray_contact(origin, direction, inset).pos

func _ray_contact(origin: Vector2, direction: Vector2, inset: float = 0.0) -> Dictionary:
	var area: Rect2 = game.arena.grow(-inset)
	var best: float = 2400.0
	var normal := Vector2.ZERO
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			continue
		var edge: float = area.end[axis] if direction[axis] > 0.0 else area.position[axis]
		var distance: float = (edge - origin[axis]) / direction[axis]
		if distance >= 0.0 and distance < best:
			best = distance
			normal = Vector2.ZERO
			normal[axis] = -signf(direction[axis])
	for rect in game.obstacles:
		var hit: Dictionary = ProjectileSystem._segment_rect(origin, origin + direction * 2400.0, rect.grow(inset))
		if not hit.is_empty() and hit.t * 2400.0 < best and hit.t > 0.00001:
			best = hit.t * 2400.0
			normal = hit.normal
	return {"pos": origin + direction * best, "normal": normal}

func _build_grid() -> void:
	_path_grid.clear()
	var width: int = maxi(1, int(ceil(game.arena.size.x / 48.0)))
	var height: int = maxi(1, int(ceil(game.arena.size.y / 48.0)))
	for y in range(height):
		for x in range(width):
			var key := Vector2i(x, y)
			if _position_open(_cell_position(key), 22.0):
				_path_grid[key] = true

func _cell_position(cell: Vector2i) -> Vector2:
	return game.arena.position + Vector2(cell) * 48.0 + Vector2(24.0, 24.0)

func _nearest_cell(position: Vector2) -> Vector2i:
	var nearest := Vector2i.ZERO
	var closest: float = INF
	for key in _path_grid:
		var distance: float = _cell_position(key).distance_squared_to(position)
		if distance < closest:
			closest = distance
			nearest = key
	return nearest

func _find_path(from: Vector2, to: Vector2) -> Array:
	var start: Vector2i = _nearest_cell(from)
	var goal: Vector2i = _nearest_cell(to)
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var cursor: int = 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == goal:
			break
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + step
			if _path_grid.has(next) and not previous.has(next):
				previous[next] = current
				frontier.append(next)
	if not previous.has(goal):
		return []
	var path: Array = []
	var current: Vector2i = goal
	while current != start:
		path.push_front(_cell_position(current))
		current = previous[current]
	return path

func _draw() -> void:
	for hazard in hazards:
		_draw_hazard(hazard)
	for unit in units:
		var p: Vector2 = unit.pos
		var size: float = BOSS_RENDER_SIZE if unit.boss else 40.0
		var tint := Color.WHITE
		if unit.spawn_grace > 0.0:
			tint.a = 0.35
			draw_arc(p, unit.radius + 14.0, _time, _time + TAU * 0.8, 24, WARNING, 2.0)
			draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), WARNING, 2.0)
			draw_line(p + Vector2(0, -8), p + Vector2(0, 8), WARNING, 2.0)
		draw_ellipse_shadow(p + Vector2(0, unit.radius * 0.8), unit.radius)
		var animation_key: String = "%s:%s" % [unit.kind, unit.anim_state]
		if unit.boss and _boss_animation_textures.has(animation_key):
			_draw_boss_animation(unit, p, size, tint)
		elif not unit.boss and _animation_textures.has(animation_key):
			_draw_enemy_animation(unit, p, size, tint)
		elif _textures.has(unit.kind):
			draw_texture_rect(_textures[unit.kind], Rect2(p - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, tint)
		else:
			_draw_silhouette(unit, tint)
		if unit.hit_flash > 0.0:
			draw_arc(p, unit.radius + 3.0, 0.0, TAU, 16, Color.WHITE, 3.0)
		if unit.transition > 0.0:
			draw_arc(p, unit.radius + 14.0, 0.0, TAU, 32, Color("35e7ff"), 4.0)
		if unit.exposed > 0.0:
			draw_circle(p, 8.0, Color("fff2b0"))
		if unit.hp < unit.max_hp and not unit.boss:
			var bar := Rect2(p + Vector2(-18, -unit.radius - 10.0), Vector2(36, 3))
			draw_rect(bar, Color("25152e"))
			bar.size.x *= unit.hp / unit.max_hp
			draw_rect(bar, ENEMY_COLOR)
	_draw_death_animations()

func _draw_enemy_animation(unit: Dictionary, p: Vector2, size: float, tint: Color) -> void:
	var animation_name: String = str(unit.anim_state)
	var config: Dictionary = ENEMY_ANIMATION_CONFIG.get(animation_name, ENEMY_ANIMATION_CONFIG.idle)
	var frame_count: int = int(config.frames)
	var frame: int = mini(int(unit.anim_elapsed * float(config.fps)), frame_count - 1)
	if bool(config.loop):
		frame = int(fposmod(unit.anim_elapsed * float(config.fps), float(frame_count)))
	var key: String = "%s:%s" % [unit.kind, animation_name]
	var sheet: Texture2D = _animation_textures[key]
	draw_texture_rect_region(sheet, Rect2(p - Vector2.ONE * size * 0.5, Vector2.ONE * size), Rect2(frame * 32, 0, 32, 32), tint)

func _draw_boss_animation(unit: Dictionary, p: Vector2, size: float, tint: Color) -> void:
	var animation_name: String = str(unit.anim_state)
	var config: Dictionary = BOSS_ANIMATION_CONFIG.get(animation_name, BOSS_ANIMATION_CONFIG.idle)
	var frame_count: int = int(config.frames)
	var frame: int = mini(int(unit.anim_elapsed * float(config.fps)), frame_count - 1)
	if bool(config.loop):
		frame = int(fposmod(unit.anim_elapsed * float(config.fps), float(frame_count)))
	var key: String = "%s:%s" % [unit.kind, animation_name]
	var sheet: Texture2D = _boss_animation_textures[key]
	draw_texture_rect_region(sheet, Rect2(p - Vector2.ONE * size * 0.5, Vector2.ONE * size), Rect2(frame * 64, 0, 64, 64), tint)

func _draw_death_animations() -> void:
	for death in _death_animations:
		var is_boss: bool = bool(death.get("boss", false))
		var config: Dictionary = BOSS_ANIMATION_CONFIG.death if is_boss else ENEMY_ANIMATION_CONFIG.death
		var frame: int = mini(int(float(death.elapsed) * float(config.fps)), int(config.frames) - 1)
		var key: String = "%s:death" % death.kind
		var animations: Dictionary = _boss_animation_textures if is_boss else _animation_textures
		if not animations.has(key):
			continue
		var p: Vector2 = death.pos
		var source_size: float = 64.0 if is_boss else 32.0
		var display_size: float = BOSS_RENDER_SIZE if is_boss else 40.0
		var sheet: Texture2D = animations[key]
		draw_ellipse_shadow(p + Vector2(0, BOSS_COLLISION_RADIUS * 0.8 if is_boss else 12), BOSS_COLLISION_RADIUS if is_boss else 15.0)
		draw_texture_rect_region(sheet, Rect2(p - Vector2.ONE * display_size * 0.5, Vector2.ONE * display_size), Rect2(frame * source_size, 0, source_size, source_size), Color.WHITE)

func draw_ellipse_shadow(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(16):
		points.append(center + Vector2(cos(TAU * i / 16.0) * radius, sin(TAU * i / 16.0) * radius * 0.35))
	draw_colored_polygon(points, Color(0.02, 0.01, 0.05, 0.7))

func _draw_silhouette(unit: Dictionary, tint: Color) -> void:
	var p: Vector2 = unit.pos
	var r: float = unit.radius
	var color := Color(ENEMY_COLOR, tint.a)
	match unit.kind:
		"drone", "spiral":
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)]), color)
		"charger", "skirmisher":
			draw_colored_polygon(PackedVector2Array([p + Vector2(r, 0), p + Vector2(-r, -r), p + Vector2(-r * 0.5, 0), p + Vector2(-r, r)]), color)
		"support", "splitter":
			for angle in range(4):
				draw_circle(p + Vector2.from_angle(angle * PI * 0.5) * r * 0.6, r * 0.55, color)
		"sniper":
			draw_rect(Rect2(p - Vector2(r * 0.4, r), Vector2(r * 0.8, r * 2.0)), color)
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color("ffd69a"), 4.0)
		_:
			draw_rect(Rect2(p - Vector2.ONE * r, Vector2.ONE * r * 2.0), color)
			draw_rect(Rect2(p - Vector2.ONE * r * 0.6, Vector2.ONE * r * 1.2), Color("241044"))
	draw_circle(p, 4.0 if not unit.boss else 11.0, Color("e6f7ff"))

func _draw_hazard(h: Dictionary) -> void:
	var progress: float = clampf(1.0 - h.remaining / h.warning, 0.0, 1.0)
	var color: Color = Color("fff1dd") if h.fired else h.color
	match h.type:
		"laser", "charge":
			for i in range(h.path.size() - 1):
				var a: Vector2 = h.path[i]
				var b: Vector2 = h.path[i + 1]
				if h.fired and h.type == "laser":
					draw_line(a, b, ENEMY_COLOR, h.radius * 2.0 + 5.0)
					draw_line(a, b, color, h.radius * 2.0)
				else:
					var direction: Vector2 = (b - a).normalized()
					var length: float = a.distance_to(b)
					var offset: float = 0.0
					while offset < length:
						draw_line(a + direction * offset, a + direction * minf(offset + 13.0, length), color, 2.0)
						offset += 23.0
					if h.type == "charge":
						draw_line(a + direction.orthogonal() * h.radius, b + direction.orthogonal() * h.radius, Color(color, 0.25), 1.0)
						draw_line(a - direction.orthogonal() * h.radius, b - direction.orthogonal() * h.radius, Color(color, 0.25), 1.0)
				if h.get("reflected", false) and i == 0:
					draw_rect(Rect2(b - Vector2(9, 9), Vector2(18, 18)), WARNING, false, 3.0)
		"floor":
			draw_circle(h.pos, h.radius, Color(color, 0.23 if h.fired else 0.06))
			draw_arc(h.pos, h.radius, 0.0, TAU, 32, color, 3.0 if h.fired else 1.5)
			draw_arc(h.pos, h.radius * progress, 0.0, TAU, 24, Color(color, 0.65), 2.0)
			var cross: float = 9.0
			draw_line(h.pos - Vector2.ONE * cross, h.pos + Vector2.ONE * cross, color, 2.0)
			draw_line(h.pos + Vector2(cross, -cross), h.pos + Vector2(-cross, cross), color, 2.0)
		"rail":
			draw_rect(h.rect, Color(color, 0.35 if h.fired else 0.08))
			draw_rect(h.rect, color, false, 2.5 if h.fired else 1.0)
			var x: float = h.rect.position.x + 8.0
			while x < h.rect.end.x - 12.0:
				draw_line(Vector2(x, h.rect.end.y - 6), Vector2(x + 12, h.rect.position.y + 6), color, 2.0)
				x += 32.0
		_:
			if not h.fired:
				draw_arc(h.pos, 23.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, TAU * progress), 24, color, 2.0)
				if h.has("angle"):
					var direction := Vector2.from_angle(h.angle)
					draw_line(h.pos + direction * 28.0, h.pos + direction * 44.0, color, 3.0)
