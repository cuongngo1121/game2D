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
const BOSS_REFRACTOR_SPEED_BONUS := 18.0
const BOSS_REFRACTOR_DESIRED_DISTANCE_REDUCTION := 34.0
const BOSS_REFRACTOR_ATTACK_BEATS := 4
const BOSS_NULL_MAESTRO_SPEED_BONUS := 24.0
const BOSS_NULL_MAESTRO_DESIRED_DISTANCE_REDUCTION := 40.0
const BOSS_NULL_MAESTRO_ATTACK_BEATS := 3
const BOSS_LUNGE_SPEED := 480.0
const BOSS_LUNGE_MIN_DISTANCE := 72.0
# Hurt sheets are three-frame reads. Under automatic fire, finish every frame
# before briefly returning to the live action, rather than holding frame zero
# or the final Hurt frame indefinitely.
const BOSS_HURT_PULSE_PERIOD := 0.36
const BOSS_HURT_PULSE_DURATION := 0.24
const BOSS_ATTACK_RING_DURATION := 0.48
const BOSS_HIT_RING_DURATION := 0.42
const ENEMY_FIRE_ANIMATION_DURATION := 0.26
const ENEMY_SPAWN_ANIMATION_MIN_RADIUS := 14.0
# Keep each boss beam's palette, animation tuning, and cadence in one profile.
# All five bosses use the same map-spanning renderer; the cadence becomes
# denser from Area 1 to Area 5 while the warning/collision contract stays shared.
const BOSS_BEAM_PROFILES = [
	{"color": Color("35e7ff"), "accent": Color("f5ffff"), "telegraph": Color("ff916d"),
		"style": "rhythm", "pulse_speed": 9.0, "travel_speed": 260.0, "pulse_count": 3,
		"pulse_length": 24.0, "marker_step": 54.0, "marker_speed": 48.0,
		"stripe_step": 30.0, "stripe_speed": 42.0,
		"attack_interval": 5, "phase2_interval": 4, "beam_count": 1},
	{"color": Color("ffab64"), "accent": Color("fff1b0"), "telegraph": Color("ff846f"),
		"style": "pressure", "pulse_speed": 7.0, "travel_speed": 190.0, "pulse_count": 2,
		"pulse_length": 32.0, "marker_step": 68.0, "marker_speed": 34.0,
		"stripe_step": 36.0, "stripe_speed": 28.0,
		"attack_interval": 4, "phase2_interval": 3, "beam_count": 1},
	{"color": Color("88ffc9"), "accent": Color("effff7"), "telegraph": Color("ff916d"),
		"style": "echo", "pulse_speed": 11.0, "travel_speed": 230.0, "pulse_count": 4,
		"pulse_length": 20.0, "marker_step": 48.0, "marker_speed": 56.0,
		"stripe_step": 27.0, "stripe_speed": 38.0,
		"attack_interval": 3, "phase2_interval": 2, "beam_count": 1},
	{"color": Color("9b87ff"), "accent": Color("f3e8ff"), "telegraph": Color("ff916d"),
		"style": "prism", "pulse_speed": 13.0, "travel_speed": 310.0, "pulse_count": 4,
		"pulse_length": 18.0, "marker_step": 42.0, "marker_speed": 66.0,
		"stripe_step": 25.0, "stripe_speed": 48.0,
		"attack_interval": 2, "phase2_interval": 1, "beam_count": 1},
	{"color": Color("ff6a91"), "accent": Color("fff0f7"), "telegraph": Color("ff846f"),
		"style": "void", "pulse_speed": 8.0, "travel_speed": 165.0, "pulse_count": 2,
		"pulse_length": 40.0, "marker_step": 76.0, "marker_speed": 30.0,
		"stripe_step": 40.0, "stripe_speed": 24.0,
		"attack_interval": 1, "phase2_interval": 1, "beam_count": 2},
]
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
var fire_effects: Array[Dictionary] = []
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
	fire_effects.clear()
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
		if unit.boss:
			# A separate orange hit ring makes damage readable without replacing the
			# boss Hurt sheet or the cyan phase shield.
			unit.hit_ring_anim = BOSS_HIT_RING_DURATION
			unit.hit_ring_phase = fposmod(float(unit.get("hit_ring_phase", 0.0)) + 0.62, TAU)
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
	for i in range(fire_effects.size() - 1, -1, -1):
		fire_effects[i].time = maxf(0.0, float(fire_effects[i].time) - delta)
		if fire_effects[i].time <= 0.0:
			fire_effects.remove_at(i)
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
		unit.fire_anim = maxf(0.0, unit.fire_anim - delta)
		unit.fire_flash = maxf(0.0, unit.fire_flash - delta)
		unit.hurt_anim = maxf(0.0, unit.hurt_anim - delta)
		unit.hit_ring_anim = maxf(0.0, float(unit.get("hit_ring_anim", 0.0)) - delta)
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
	var boss_speed: float = BOSS_CHASE_SPEED + float(_stage) * 2.0
	var boss_attack_beats: int = 6
	if boss and kind == "boss3":
		boss_speed += BOSS_REFRACTOR_SPEED_BONUS
		boss_attack_beats = BOSS_REFRACTOR_ATTACK_BEATS
	elif boss and kind == "boss4":
		boss_speed += BOSS_NULL_MAESTRO_SPEED_BONUS
		boss_attack_beats = BOSS_NULL_MAESTRO_ATTACK_BEATS
	units.append({"id": _next_id, "kind": kind, "pos": pos, "hp": max_hp, "max_hp": max_hp,
		"radius": radius, "boss": boss, "phase": 1, "name": stats.get("name", kind.to_upper()),
		"speed": float(stats.get("speed", 35.0)) if not boss else boss_speed,
		"damage": float(stats.get("damage", 12.0 + _stage * 2.0)),
		"bullet_speed": float(stats.get("bullet_speed", 155.0 + _stage * 9.0)),
		"attack_beats": int(stats.get("attack_beats", 8)) if not boss else boss_attack_beats,
		"spawn_grace": _warning_time(), "hit_flash": 0.0, "transition": 0.0,
		"exposed": 0.0, "contact_cd": 0.0, "charge_left": 0.0, "charge_dir": Vector2.ZERO,
		"path": [], "path_age": 0.0, "stuck": 0.0, "last_pos": pos,
		"turn": 0, "summoner": summoner, "reward_scale": 0.35 if summoner >= 0 else 1.0,
		"anim_state": "idle", "anim_elapsed": 0.0, "attack_anim": 0.0, "hurt_anim": 0.0,
		"hurt_pulse_started": 0.0, "hit_ring_anim": 0.0,
		"hit_ring_phase": _rng.randf_range(0.0, TAU), "fire_anim": 0.0, "fire_flash": 0.0,
		"fire_angle": 0.0, "spawn_phase": _rng.randf_range(0.0, TAU)})
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
		if hazard.owner == unit.id and not hazard.fired and hazard.type in ["charge", "laser", "boss_beam"]:
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
		var desired_distance: float = 230.0 - float(unit.phase - 1) * 28.0
		if unit.kind == "boss3":
			# Refractor is the first boss that actively collapses the ring. Its
			# direct approach leaves less idle circling time while the lateral
			# component keeps a readable dodge lane instead of making contact
			# damage unavoidable.
			desired_distance -= BOSS_REFRACTOR_DESIRED_DISTANCE_REDUCTION
			if distance > desired_distance + 18.0:
				direction = (player_direction * 0.98 + strafe_direction * 0.20).normalized()
			elif distance < desired_distance - 30.0:
				direction = (-player_direction * 0.90 + strafe_direction * 0.35).normalized()
			else:
				direction = (player_direction * 0.35 + strafe_direction * 0.80).normalized()
		elif unit.kind == "boss4":
			# NULL MAESTRO compresses the ring one more step. It keeps enough
			# lateral movement to leave a dodge lane, but does not spend the
			# opening phase circling at the edge of the arena.
			desired_distance -= BOSS_NULL_MAESTRO_DESIRED_DISTANCE_REDUCTION
			if distance > desired_distance + 12.0:
				direction = (player_direction * 0.99 + strafe_direction * 0.26).normalized()
			elif distance < desired_distance - 24.0:
				direction = (-player_direction * 0.92 + strafe_direction * 0.38).normalized()
			else:
				direction = (player_direction * 0.48 + strafe_direction * 0.78).normalized()
		elif distance > desired_distance + 28.0:
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
	unit.fire_angle = angle
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
	unit.attack_anim = BOSS_ATTACK_RING_DURATION
	var angle: float = (game.player.position - unit.pos).angle()
	unit.fire_angle = angle
	match unit.kind:
		"boss0":
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 9, "spread": 2.0, "skip_middle": true})
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
			# Refractor is a composite boss: it borrows the earlier volley,
			# ring, support and lunge vocabulary, then layers its own prism field
			# over the pattern. Queue the lunge first so the extra projectiles do
			# not accidentally suppress the approach attack through the heavy-
			# hazard safety cap.
			_try_boss_lunge(unit)
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 7, "spread": 1.55, "echo": true})
			if unit.turn % 2 == 0:
				_warn({"type": "ring", "owner": unit.id, "pos": unit.pos, "angle": unit.turn * 0.28, "count": 18, "gap": angle, "speed": 155.0})
			if unit.phase >= 2 and unit.turn % 3 == 0:
				_warn({"type": "support", "owner": unit.id, "pos": unit.pos, "summon": true})
			if unit.phase == 2 and unit.turn % 2 == 0:
				_warn({"type": "spiral", "owner": unit.id, "pos": unit.pos, "angle": beat * 0.25, "count": 15, "speed": 130.0})
			if unit.phase >= 2 and unit.turn % 4 == 0:
				_warn_prism_burst(unit)
		"boss4":
			# NULL MAESTRO is the full pressure version of the previous boss
			# patterns: a fast volley, a denser map-spanning beam cadence, split
			# bombs and ring/spiral pressure on alternating turns, then a lunge
			# that is queued first so extra hazards cannot suppress it.
			_try_boss_lunge(unit)
			_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 9, "spread": 1.85, "echo": true, "speed": 175.0})
			if unit.turn % 2 == 0:
				_warn({"type": "volley", "owner": unit.id, "pos": unit.pos, "angle": angle, "count": 5, "spread": 1.35, "behavior": "split", "bomb_pattern": true, "speed": 132.0})
				_warn({"type": "ring", "owner": unit.id, "pos": unit.pos, "angle": unit.turn * 0.22, "count": 24, "gap": angle, "speed": 160.0})
			if unit.phase >= 2 and unit.turn % 2 == 0:
				_warn({"type": "spiral", "owner": unit.id, "pos": unit.pos, "angle": beat * 0.32, "count": 17, "speed": 145.0})
			if unit.phase >= 2:
				_warn({"type": "floor", "owner": unit.id, "pos": game.player.position, "radius": 78.0, "damage": unit.damage * 1.1})
			if unit.phase >= 2 and unit.turn % 3 == 0:
				_warn({"type": "support", "owner": unit.id, "pos": unit.pos, "summon": true})
			if unit.phase >= 2 and unit.turn % 4 == 0:
				_warn_prism_burst(unit)
	# Schedule the shared beam after the boss-specific pattern. Lunge selection
	# intentionally runs first, so the new beam cadence cannot suppress the
	# existing approach attack through the heavy-hazard safety cap.
	_try_boss_beams(unit)

func _boss_beam_profile(stage: int) -> Dictionary:
	return BOSS_BEAM_PROFILES[clampi(stage, 0, BOSS_BEAM_PROFILES.size() - 1)]

func _boss_beam_interval(unit: Dictionary) -> int:
	var profile: Dictionary = _boss_beam_profile(_stage)
	var profile_key: String = "phase2_interval" if int(unit.get("phase", 1)) >= 2 else "attack_interval"
	return maxi(1, int(profile.get(profile_key, 1)))

func _should_fire_boss_beam(unit: Dictionary) -> bool:
	var turn: int = int(unit.get("turn", 0))
	# Guarantee that every boss introduces the mechanic during a short playtest;
	# later turns follow the authored, progressively denser cadence.
	return turn == 1 or turn % _boss_beam_interval(unit) == 0

func _boss_beam_count(unit: Dictionary) -> int:
	var profile: Dictionary = _boss_beam_profile(_stage)
	var configured_count: int = maxi(1, int(profile.get("beam_count", 1)))
	# Only the final boss opens the second axis, and only after its phase shift.
	# This gives Area 5 a clear escalation without creating two simultaneous
	# legacy/new sources in the earlier rooms.
	if unit.kind != "boss4" or int(unit.get("phase", 1)) < 2:
		return 1
	return configured_count

func _try_boss_beams(unit: Dictionary) -> void:
	if not _should_fire_boss_beam(unit):
		return
	for beam_index in range(_boss_beam_count(unit)):
		_warn_boss_beam(unit, beam_index)

func _boss_lunge_interval(unit: Dictionary) -> int:
	match unit.kind:
		"boss0": return 2 if unit.phase >= 2 else 3
		"boss1": return 3 if unit.phase >= 2 else 4
		"boss2": return 3 if unit.phase >= 2 else 4
		"boss3": return 2 if unit.phase >= 2 else 3
		"boss4": return 1 if unit.phase >= 3 else (2 if unit.phase >= 2 else 3)
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
	if unit.attack_anim > 0.0 or unit.fire_anim > 0.0 or unit.charge_left > 0.0:
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
		"color": WARNING, "radius": 40.0, "preparing": true,
		"prepare_phase": fposmod(_time + float(_next_id) * 0.73, TAU)}
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

func _warn_prism_burst(unit: Dictionary) -> void:
	# This is deliberately a local floor lock, not a map-spanning beam. The
	# player can leave the recorded point during the readable warning and the
	# existing floor collision path handles the final hit exactly once.
	var target: Vector2 = game.player.position
	_warn({"type": "floor", "owner": unit.id, "pos": target, "target_position": target,
		"radius": 88.0, "damage": unit.damage * 1.35, "shape": "prism_burst",
		"prism_burst": true, "active_time": 0.52})

func _arena_edge_endpoint(origin: Vector2, direction: Vector2) -> Vector2:
	# Unlike the obstacle-aware targeting ray, this endpoint intentionally ignores
	# cover: the boss attack is a visible map-spanning lane. Collision still uses
	# the exact recorded segment, so the visual and damage path cannot diverge.
	var area: Rect2 = game.arena
	var distance: float = INF
	if direction.x > 0.000001:
		distance = minf(distance, (area.end.x - origin.x) / direction.x)
	elif direction.x < -0.000001:
		distance = minf(distance, (area.position.x - origin.x) / direction.x)
	if direction.y > 0.000001:
		distance = minf(distance, (area.end.y - origin.y) / direction.y)
	elif direction.y < -0.000001:
		distance = minf(distance, (area.position.y - origin.y) / direction.y)
	return origin + direction * maxf(0.0, distance)

func _map_spanning_boss_beam_path(origin: Vector2, direction: Vector2) -> Array[Vector2]:
	var safe_direction: Vector2 = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var start: Vector2 = _arena_edge_endpoint(origin, -safe_direction)
	var end: Vector2 = _arena_edge_endpoint(origin, safe_direction)
	# A boss can be spawned close to a room edge. Extend the same recorded line
	# outside that edge when its visible chord would otherwise look like a short
	# local shot; the playable part still begins at the arena boundary.
	var minimum_span: float = minf(game.arena.size.x, game.arena.size.y)
	var current_span: float = start.distance_to(end)
	if current_span < minimum_span:
		var extension: float = (minimum_span - current_span) * 0.5
		start -= safe_direction * extension
		end += safe_direction * extension
	return [start, end]

func _warn_boss_beam(unit: Dictionary, beam_index: int = 0) -> void:
	# Lock the first axis toward the player's position at warning time, then
	# extend it from arena edge to arena edge. Area 5's second axis crosses the
	# boss, giving the final phase a readable crossfire instead of a duplicate
	# implementation or a recycled horizontal rail strip.
	var target: Vector2 = game.player.position
	var direction: Vector2 = (target - unit.pos).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	direction = direction.rotated(float(beam_index) * PI * 0.5).normalized()
	var path: Array[Vector2] = _map_spanning_boss_beam_path(unit.pos, direction)
	_warn({"type": "boss_beam", "owner": unit.id, "pos": unit.pos,
		"path": path, "target_position": target, "map_spanning": true, "boss_xray": true,
		"beam_index": beam_index, "beam_interval": _boss_beam_interval(unit),
		"radius": 8.0, "damage": unit.damage * 1.4, "beam_stage": _stage,
		"beam_phase": fposmod(_time + float(unit.id) * 0.43, TAU),
		"beam_elapsed": 0.0, "active_time": 0.44})

func _warn_laser(unit: Dictionary, reflected: bool) -> void:
	if bool(unit.get("boss", false)):
		# Boss map beams use _warn_boss_beam(). Keep this guard so an old generic
		# laser caller cannot create a second, differently animated boss source.
		return
	var direction: Vector2 = (game.player.position - unit.pos).normalized()
	var start: Vector2 = unit.pos
	var contact: Dictionary = _ray_contact(start, direction)
	var points: Array[Vector2] = [start, contact.pos]
	if reflected and contact.normal != Vector2.ZERO:
		var reflected_direction: Vector2 = direction.bounce(contact.normal)
		points.append(_ray_endpoint(contact.pos + reflected_direction * 1.0, reflected_direction, 0.0))
	_warn({"type": "laser", "owner": unit.id, "pos": start, "path": points,
		"radius": 7.0 if unit.boss else 5.0, "damage": unit.damage * 1.3, "reflected": reflected,
		"beam_phase": fposmod(_time + float(unit.id) * 0.43, TAU),
		"beam_elapsed": 0.0})
func _heavy_hazard_count() -> int:
	var count: int = 0
	for hazard in hazards:
		if hazard.type in ["floor", "rail", "laser", "boss_beam", "charge"]:
			count += 1
	return count

func _stage_trap(beat: int) -> void:
	match _stage:
		0:
			# The former stage trap was a pair of map-spanning rail strips. Replace it
			# with one local floor warning so it cannot be mistaken for another boss ray.
			_warn({"type": "floor", "pos": game.player.position, "radius": 65.0,
				"damage": 17.0, "shape": "rail_trap_replaced"})
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
			# This former stage trap was a map-spanning laser. Keep it out of boss
			# gameplay; normal rooms retain a local floor warning so the stage rhythm
			# remains dangerous without another beam.
			if _boss_room:
				return
			_warn({"type": "floor", "pos": game.player.position, "radius": 65.0,
				"damage": 17.0, "shape": "xray_trap_replaced"})
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
		if hazard.type in ["laser", "boss_beam"]:
			hazard.beam_elapsed = float(hazard.get("beam_elapsed", 0.0)) + delta
		if hazard.owner >= 0 and _unit(hazard.owner).is_empty():
			hazards.remove_at(i)
			continue
		hazard.remaining -= delta
		if not hazard.fired and hazard.remaining <= 0.0:
			hazard.fired = true
			hazard.preparing = false
			hazard.remaining = hazard.active_time
			_fire_hazard(hazard)
		if hazard.fired:
			_damage_hazard(hazard)
			if update_epoch != _epoch:
				return
			if hazard.remaining <= 0.0:
				hazards.remove_at(i)

func _fire_hazard(hazard: Dictionary) -> void:
	hazard.preparing = false
	var unit: Dictionary = _unit(hazard.owner)
	var damage: float = unit.get("damage", hazard.damage)
	var speed: float = hazard.get("speed", unit.get("bullet_speed", 155.0))
	if not unit.is_empty() and hazard.type in ["volley", "ring", "spiral", "laser", "boss_beam", "charge"]:
		_trigger_fire_visual(unit, hazard)
	var projectile_visual: String = _hazard_projectile_visual(hazard)
	match hazard.type:
		"volley":
			var count: int = hazard.count
			for i in range(count):
				if hazard.get("skip_middle", false) and i == count / 2:
					continue
				var angle: float = hazard.angle + (float(i) / maxf(1.0, count - 1.0) - 0.5) * hazard.spread
				_bullet(hazard.pos, angle, speed, damage, hazard.get("behavior", "normal"), projectile_visual)
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
					_bullet(hazard.pos, angle, speed, damage, "normal", projectile_visual)
		"spiral":
			for i in range(hazard.count):
				# Two opposite sectors stay empty; slow staggered spokes leave lanes.
				if i % 6 == 0 or i % 6 == 1:
					continue
				var angle: float = hazard.angle + TAU * float(i) / hazard.count
				_bullet(hazard.pos, angle, speed * (0.8 + (i % 3) * 0.08), damage, "normal", projectile_visual)
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
		"laser", "boss_beam", "rail", "floor":
			game.audio.play_sfx("boss" if not unit.is_empty() and unit.boss else "hit")

func _hazard_projectile_visual(hazard: Dictionary) -> String:
	if str(hazard.get("behavior", "normal")) == "split":
		return "enemy_bomb"
	match str(hazard.get("type", "volley")):
		"ring": return "enemy_ring"
		"spiral": return "enemy_spiral"
		"laser", "boss_beam": return "enemy_laser"
	return "enemy_orb"

func _hazard_direction(hazard: Dictionary) -> Vector2:
	if hazard.has("angle"):
		return Vector2.from_angle(float(hazard.angle))
	if hazard.has("direction"):
		var direction: Vector2 = hazard.direction
		return direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	var path: Array = hazard.get("path", [])
	if path.size() > 1:
		var path_direction: Vector2 = path[1] - path[0]
		return path_direction.normalized() if path_direction.length_squared() > 0.001 else Vector2.RIGHT
	return Vector2.RIGHT

func _trigger_fire_visual(unit: Dictionary, hazard: Dictionary) -> void:
	var direction: Vector2 = _hazard_direction(hazard)
	var visual: String = _hazard_projectile_visual(hazard)
	var color := Color("ff647c")
	var accent := Color("ffd9ad")
	if visual == "enemy_bomb":
		color = Color("ffc279")
		accent = Color("fff1b0")
	elif visual == "enemy_ring":
		color = Color("ff7db8")
		accent = Color("ffe0f2")
	elif visual == "enemy_spiral":
		color = Color("be8aff")
		accent = Color("f3e2ff")
	elif visual == "enemy_laser":
		color = Color("ff647c")
		accent = Color("e6f7ff")
	unit.fire_anim = maxf(float(unit.get("fire_anim", 0.0)), ENEMY_FIRE_ANIMATION_DURATION)
	unit.fire_flash = 0.18
	unit.fire_angle = direction.angle()
	var muzzle_pos: Vector2 = unit.pos + direction * (unit.radius * 0.72)
	fire_effects.append({"pos": muzzle_pos, "direction": direction, "visual": visual,
		"color": color, "accent": accent, "time": 0.20, "duration": 0.20,
		"phase": float(unit.get("spawn_phase", 0.0))})

func _bullet(origin: Vector2, angle: float, speed: float, damage: float,
		behavior: String = "normal", visual: String = "enemy_orb") -> void:
	var direction := Vector2.from_angle(angle)
	# A muzzle may be near a rushing player; the full preceding marker warns them.
	var color := Color("ffc279") if behavior == "split" else ENEMY_COLOR
	var accent := Color("fff1b0") if behavior == "split" else Color("ffd9ad")
	game.projectiles.spawn({"pos": origin + direction * 20.0, "vel": direction * speed,
		"damage": damage, "enemy": true, "radius": 4.5, "life": 6.5,
		"color": color, "accent": accent, "trail_color": color,
		"visual": visual, "behavior": behavior, "phase": angle * 0.73,
		"split_after": 0.65 if behavior == "split" else 0.0})

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
		"laser", "boss_beam":
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
			var spawn_progress: float = clampf(1.0 - unit.spawn_grace / _warning_time(), 0.0, 1.0)
			var spawn_eased: float = 1.0 - pow(1.0 - spawn_progress, 2.0)
			tint.a = lerpf(0.18, 1.0, spawn_eased)
			_draw_spawn_animation(unit, p, spawn_progress)
		if unit.boss and int(unit.get("phase", 1)) >= 2:
			_draw_boss_phase_shield(unit, p)
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
		if unit.boss and float(unit.get("attack_anim", 0.0)) > 0.0:
			_draw_boss_attack_animation(unit, p)
		if unit.fire_flash > 0.0:
			var fire_fade: float = clampf(unit.fire_flash / 0.18, 0.0, 1.0)
			var fire_direction := Vector2.from_angle(float(unit.get("fire_angle", 0.0)))
			var fire_pos: Vector2 = p + fire_direction * (unit.radius * 0.72)
			draw_circle(fire_pos, 4.0 + fire_fade * 3.0, Color("fff1b0", 0.32 * fire_fade))
			draw_line(fire_pos, fire_pos + fire_direction * (10.0 + fire_fade * 8.0), Color("fff7df", 0.88 * fire_fade), 2.0, true)
		if unit.hit_flash > 0.0:
			draw_arc(p, unit.radius + 3.0, 0.0, TAU, 16, Color.WHITE, 3.0)
		if unit.boss and float(unit.get("hit_ring_anim", 0.0)) > 0.0:
			_draw_boss_hit_ring(unit, p)
		if unit.transition > 0.0:
			draw_arc(p, unit.radius + 14.0, 0.0, TAU, 32, Color("35e7ff"), 4.0)
		if unit.exposed > 0.0:
			draw_circle(p, 8.0, Color("fff2b0"))
		if unit.hp < unit.max_hp and not unit.boss:
			var bar := Rect2(p + Vector2(-18, -unit.radius - 10.0), Vector2(36, 3))
			draw_rect(bar, Color("25152e"))
			bar.size.x *= unit.hp / unit.max_hp
			draw_rect(bar, ENEMY_COLOR)
	for effect in fire_effects:
		_draw_fire_effect(effect)
	_draw_death_animations()

func _draw_spawn_animation(unit: Dictionary, p: Vector2, progress: float) -> void:
	var color := Color("d9a3ff") if unit.boss else Color("35e7ff")
	var accent := Color("fff0ff") if unit.boss else Color("b8ffff")
	var phase: float = float(unit.get("spawn_phase", 0.0))
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var radius: float = lerpf(ENEMY_SPAWN_ANIMATION_MIN_RADIUS, unit.radius + 26.0, eased)
	var alpha: float = 0.80 - progress * 0.36
	draw_circle(p, radius * 0.72, Color(color, 0.06 * alpha))
	draw_arc(p, radius, phase + _time * 2.6, phase + _time * 2.6 + TAU * 0.82, 32, Color(color, alpha), 2.5, true)
	draw_arc(p, radius * 0.68, -phase - _time * 3.2, -phase - _time * 3.2 + TAU * 0.62, 24, Color(accent, alpha * 0.76), 1.2, true)
	for index in range(6):
		var angle: float = phase + _time * 1.8 + float(index) * TAU / 6.0
		var direction := Vector2.from_angle(angle)
		var start: Vector2 = p + direction * (radius + 3.0)
		var finish: Vector2 = p + direction * (radius + 13.0 + progress * 6.0)
		draw_line(start, finish, Color(accent, alpha * 0.62), 1.5, true)
	var scan: float = fposmod(progress * 2.0 + 0.08, 1.0)
	draw_line(p + Vector2(-unit.radius * 1.5, lerpf(-unit.radius, unit.radius, scan)),
		p + Vector2(unit.radius * 1.5, lerpf(-unit.radius, unit.radius, scan)), Color(accent, alpha * 0.48), 1.0, true)

func _draw_boss_attack_animation(unit: Dictionary, p: Vector2) -> void:
	var remaining: float = float(unit.get("attack_anim", 0.0))
	var progress: float = clampf(1.0 - remaining / BOSS_ATTACK_RING_DURATION, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var fade: float = clampf(1.0 - progress * 0.78, 0.0, 1.0)
	var phase: float = float(unit.get("spawn_phase", 0.0)) + _time * 2.0 + float(unit.get("turn", 0)) * 0.18
	var radius: float = lerpf(unit.radius + 18.0, unit.radius + 31.0, eased)
	var cyan := Color("35e7ff")
	var white := Color("f3f7ff")
	var accent := Color("b8ffff")
	draw_circle(p, radius, Color(cyan, 0.045 * fade))
	draw_arc(p, radius, phase, phase + TAU * 0.94, 48, Color(white, 0.84 * fade), 2.6, true)
	var inner_radius: float = radius - 12.0
	for index in range(4):
		var start: float = phase + float(index) * PI * 0.5 + 0.12
		draw_arc(p, inner_radius, start, start + PI * 0.5 - 0.28, 14, Color(cyan, 0.96 * fade), 5.5, true)
		var marker_direction := Vector2.from_angle(start + PI * 0.24)
		draw_line(p + marker_direction * (inner_radius - 4.0),
			p + marker_direction * (inner_radius + 7.0), Color(accent, 0.9 * fade), 3.0, true)
	var center_radius: float = lerpf(11.0, 17.0, eased)
	draw_circle(p, center_radius, Color(cyan, 0.10 * fade))
	draw_arc(p, center_radius, phase, phase + TAU * 0.82, 24, Color(accent, 0.9 * fade), 2.2, true)
	draw_circle(p, 4.0 + eased * 2.0, Color(cyan, 0.94 * fade))
	var cross_length: float = 9.0 + eased * 5.0
	for index in range(4):
		var cross_direction := Vector2.from_angle(phase + float(index) * PI * 0.5)
		draw_line(p + cross_direction * (center_radius + 3.0),
			p + cross_direction * (center_radius + cross_length), Color(white, 0.88 * fade), 2.5, true)

func _draw_boss_hit_ring(unit: Dictionary, p: Vector2) -> void:
	var remaining: float = float(unit.get("hit_ring_anim", 0.0))
	var progress: float = clampf(1.0 - remaining / BOSS_HIT_RING_DURATION, 0.0, 1.0)
	var fade: float = clampf(remaining / BOSS_HIT_RING_DURATION, 0.0, 1.0)
	var phase: float = float(unit.get("hit_ring_phase", 0.0))
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 26.0 + phase)
	var orange := Color("ff916d")
	var accent := Color("fff1b0")
	# This is a damage read, not a new shield or collision shape. The centre stays
	# open so the boss sprite and the existing Hurt animation remain readable.
	# The effect behaves like a shattered halo: a bright impact, three delayed
	# shockwave fragments, then energy shards that separate and burn out.
	var impact_fade: float = clampf(1.0 - progress * 1.55, 0.0, 1.0)
	draw_circle(p, 7.0 + pulse * 2.0, Color(orange, 0.12 * impact_fade))
	draw_circle(p, 2.4 + pulse * 1.2, Color(accent, 0.96 * impact_fade))

	for wave in range(3):
		var wave_start: float = float(wave) * 0.18
		if progress < wave_start:
			continue
		var wave_progress: float = clampf((progress - wave_start) / (1.0 - wave_start), 0.0, 1.0)
		var wave_eased: float = 1.0 - pow(1.0 - wave_progress, 2.0)
		var wave_fade: float = (1.0 - wave_progress) * fade * (0.78 - float(wave) * 0.14)
		var wave_radius: float = unit.radius + 5.0 + wave_eased * (20.0 + float(wave) * 7.0)
		var wave_phase: float = phase + _time * (4.2 if wave % 2 == 0 else -3.1) + float(wave) * 0.9
		var wave_span: float = TAU * (0.58 + pulse * 0.12)
		draw_arc(p, wave_radius, wave_phase, wave_phase + wave_span, 28 + wave * 8,
			Color(orange, 0.72 * wave_fade), 3.6 - float(wave) * 0.55 + pulse * 0.6, true)
		draw_arc(p, wave_radius - 4.0, wave_phase + PI * 0.18,
			wave_phase + wave_span + PI * 0.18, 22 + wave * 6,
			Color(accent, 0.36 * wave_fade), 1.2, true)

	var halo_radius: float = unit.radius + 9.0 + eased * 10.0 + pulse * 1.5
	var halo_phase: float = phase - _time * 5.2
	draw_arc(p, halo_radius, halo_phase, halo_phase + TAU * 0.94, 48,
		Color(orange, 0.16 * fade), 5.5, true)
	for segment in range(8):
		var segment_angle: float = halo_phase + float(segment) * TAU / 8.0 + 0.08
		var segment_span: float = TAU / 8.0 * (0.34 + pulse * 0.16)
		var segment_radius: float = halo_radius + sin(_time * 8.0 + float(segment)) * 1.4
		var segment_alpha: float = fade * (0.66 if segment % 2 == 0 else 0.42)
		draw_arc(p, segment_radius, segment_angle, segment_angle + segment_span, 10,
			Color(orange, segment_alpha), 2.5 + pulse * 0.8, true)

	var inner_radius: float = unit.radius + 4.0 + eased * 8.0
	var inner_phase: float = phase + _time * 6.4
	for bracket in range(4):
		var bracket_start: float = inner_phase + float(bracket) * PI * 0.5 + 0.14
		draw_arc(p, inner_radius, bracket_start, bracket_start + PI * 0.27, 12,
			Color(accent, 0.88 * fade), 1.8 + pulse * 0.5, true)

	for shard in range(8):
		var shard_angle: float = phase + float(shard) * TAU / 8.0 + sin(_time * 7.0 + float(shard)) * 0.035
		var shard_direction := Vector2.from_angle(shard_angle)
		var shard_start: float = unit.radius + 7.0 + eased * 9.0
		var shard_end: float = shard_start + 6.0 + eased * 7.0 + pulse * 3.0
		draw_line(p + shard_direction * shard_start, p + shard_direction * shard_end,
			Color(accent, 0.76 * fade), 1.8 + pulse * 0.7, true)
		draw_circle(p + shard_direction * shard_end, 1.4 + pulse * 0.9,
			Color(orange, 0.72 * fade))

	var scan_angle: float = phase - _time * 18.0
	var scan_direction := Vector2.from_angle(scan_angle)
	draw_line(p + scan_direction * (unit.radius + 2.0),
		p + scan_direction * (halo_radius + 7.0), Color(accent, 0.86 * fade), 2.0, true)

func _draw_boss_phase_shield(unit: Dictionary, p: Vector2) -> void:
	var transition_duration: float = _warning_time() + 0.7
	var transition_progress: float = 1.0
	if unit.transition > 0.0:
		transition_progress = clampf(1.0 - float(unit.transition) / transition_duration, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_time * 8.0 + float(unit.get("spawn_phase", 0.0)))
	var phase: float = float(unit.get("spawn_phase", 0.0)) - _time * 1.35
	var radius: float = lerpf(unit.radius + 10.0, maxf(unit.radius + 18.0, BOSS_RENDER_SIZE * 0.60), transition_progress) + pulse * 2.0
	var alpha: float = lerpf(0.35, 0.86, transition_progress)
	var cyan := Color("35e7ff")
	var bright := Color("b8ffff")
	draw_circle(p, radius, Color(cyan, 0.035 * alpha))
	draw_arc(p, radius, phase, phase + TAU * 0.92, 52, Color(cyan, alpha), 3.2, true)
	draw_arc(p, radius - 6.0, phase + PI * 0.18, phase + PI * 1.04, 28, Color(bright, alpha * 0.72), 1.4, true)
	for index in range(4):
		var start: float = phase + float(index) * PI * 0.5 + 0.16
		draw_arc(p, radius - 1.0, start, start + PI * 0.5 - 0.34, 16, Color(cyan, alpha), 5.0, true)
		var marker_direction := Vector2.from_angle(start + PI * 0.24)
		draw_line(p + marker_direction * (radius + 1.0),
			p + marker_direction * (radius + 8.0), Color(bright, alpha * 0.9), 2.0, true)

func _draw_fire_effect(effect: Dictionary) -> void:
	var duration: float = maxf(0.001, float(effect.get("duration", 0.20)))
	var progress: float = clampf(1.0 - float(effect.get("time", 0.0)) / duration, 0.0, 1.0)
	var fade: float = 1.0 - progress
	var p: Vector2 = effect.pos
	var direction: Vector2 = effect.direction
	var normal := direction.orthogonal()
	var color: Color = effect.color
	var accent: Color = effect.accent
	var visual: String = str(effect.get("visual", "enemy_orb"))
	var reach: float = 11.0 + progress * 18.0
	if visual == "enemy_bomb":
		draw_circle(p, 8.0 + progress * 4.0, Color(color, 0.16 * fade))
		draw_arc(p, 9.0 + progress * 5.0, 0.0, TAU, 20, Color(color, 0.86 * fade), 2.0, true)
		for index in range(5):
			var angle: float = direction.angle() + (float(index) - 2.0) * 0.42
			draw_line(p + Vector2.from_angle(angle) * 5.0, p + Vector2.from_angle(angle) * reach,
				Color(accent, 0.82 * fade), 1.6, true)
	elif visual == "enemy_laser":
		draw_line(p, p + direction * reach, Color(color, 0.24 * fade), 9.0, true)
		draw_line(p, p + direction * (reach + 5.0), Color(accent, 0.9 * fade), 2.5, true)
	else:
		draw_circle(p, 5.0 + progress * 3.0, Color(color, 0.18 * fade))
		draw_circle(p, 3.0 + progress * 1.5, Color(accent, 0.88 * fade))
		for index in range(3):
			var offset: float = (float(index) - 1.0) * 0.34
			var ray := direction.rotated(offset)
			draw_line(p + ray * 4.0, p + ray * reach, Color(color, 0.7 * fade), 1.5, true)
	# A short cross reads as a muzzle aperture without adding a new gameplay node.
	draw_line(p - normal * 4.0, p + normal * 4.0, Color(accent, 0.72 * fade), 1.0, true)

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
	if not h.fired and h.type in ["volley", "ring", "spiral", "laser", "boss_beam"] and str(h.get("behavior", "normal")) != "split":
		_draw_projectile_prepare(h, progress)
	match h.type:
		"laser", "boss_beam":
			_draw_laser_hazard(h, progress)
		"charge":
			_draw_dash_path(h, progress)
		"floor":
			_draw_floor_hazard(h, progress)
		"rail":
			draw_rect(h.rect, Color(color, 0.35 if h.fired else 0.08))
			draw_rect(h.rect, color, false, 2.5 if h.fired else 1.0)
			var x: float = h.rect.position.x + 8.0
			while x < h.rect.end.x - 12.0:
				draw_line(Vector2(x, h.rect.end.y - 6), Vector2(x + 12, h.rect.position.y + 6), color, 2.0)
				x += 32.0
		_:
			if str(h.get("behavior", "normal")) == "split":
				_draw_split_bomb_hazard(h, progress, color)
			elif not h.fired:
				draw_arc(h.pos, 23.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, TAU * progress), 24, color, 2.0)
				if h.has("angle"):
					var direction := Vector2.from_angle(h.angle)
					draw_line(h.pos + direction * 28.0, h.pos + direction * 44.0, color, 3.0)

func _draw_floor_hazard(h: Dictionary, progress: float) -> void:
	# Resonance Ground Lock: the telegraph is intentionally procedural so it
	# remains crisp at every viewport scale and can be shared by bosses, Warden,
	# and stage traps without introducing a second collision representation.
	var radius: float = float(h.get("radius", 40.0))
	var base_color: Color = h.get("color", WARNING)
	var accent_color := Color("fff1b0")
	var shape: String = str(h.get("shape", ""))
	var owner: Dictionary = _unit(int(h.get("owner", -1)))
	if not owner.is_empty() and bool(owner.get("boss", false)):
		base_color = Color("ff6a91")
		accent_color = Color("fff0f7")
	else:
		match shape:
			"piston":
				base_color = Color("ffab64")
				accent_color = Color("fff1b0")
			"tile":
				base_color = Color("9b87ff")
				accent_color = Color("f3e8ff")
			"xray_trap_replaced":
				base_color = Color("ff846f")
				accent_color = Color("fff1dd")
			"rail_trap_replaced":
				base_color = Color("ffb067")
				accent_color = Color("fff1b0")
	if shape == "prism_burst":
		# Keep Refractor's signature field in its purple Prism palette even
		# though the generic boss floor branch normally uses the pink boss tint.
		base_color = Color("9b87ff")
		accent_color = Color("f3e8ff")
	var phase: float = float(h.get("prepare_phase", 0.0))
	var pulse: float = 0.5 + 0.5 * sin(_time * 11.0 + phase)
	var spin: float = phase + _time * 1.65
	var fired: bool = bool(h.get("fired", false))
	var active_progress: float = 0.0
	if fired:
		active_progress = clampf(1.0 - float(h.get("remaining", 0.0)) /
			maxf(0.01, float(h.get("active_time", 0.5))), 0.0, 1.0)

	if not fired:
		# A quiet fill gives the player the safe/unsafe boundary without washing
		# out the authored floor. The breathing glow makes an idle warning feel
		# alive even when the beat interval is long.
		draw_circle(h.pos, radius, Color(base_color, 0.035 + pulse * 0.018))
		draw_circle(h.pos, radius * (0.30 + progress * 0.12), Color(base_color, 0.025 + pulse * 0.018))
		draw_arc(h.pos, radius + 3.0 + pulse * 2.0, 0.0, TAU, 48,
			Color(base_color, 0.18 + pulse * 0.14), 4.0, true)
		# The segmented perimeter rotates slowly; the bright sweep still communicates
		# the actual countdown independently of the decorative motion.
		for index in range(8):
			var segment_angle: float = spin + float(index) * TAU / 8.0
			var segment_span: float = 0.22 + pulse * 0.045
			var segment_alpha: float = 0.30 + progress * 0.38 + pulse * 0.12
			draw_arc(h.pos, radius + 1.0, segment_angle, segment_angle + segment_span,
				10, Color(base_color, segment_alpha), 2.4, true)
		# Countdown ring: it grows toward the outside edge and ends in a hot
		# lock-on flash rather than appearing as a static second circle.
		var eased_progress: float = 1.0 - pow(1.0 - progress, 2.0)
		var lock_radius: float = lerpf(radius * 0.18, radius * 0.78, eased_progress)
		draw_arc(h.pos, lock_radius, -PI * 0.5 - spin * 0.12,
			-PI * 0.5 - spin * 0.12 + TAU * 0.76, 32,
			Color(accent_color, 0.26 + pulse * 0.16), 1.5, true)
		draw_arc(h.pos, radius - 1.0, -PI * 0.5,
			-PI * 0.5 + maxf(0.025, TAU * progress), 48,
			Color(accent_color, 0.86 + pulse * 0.10), 3.2 + pulse * 0.8, true)
		# Eight direction ticks make the radius readable against busy backgrounds.
		for index in range(8):
			var tick_angle: float = spin + float(index) * TAU / 8.0
			var tick_direction := Vector2.from_angle(tick_angle)
			var tick_start: Vector2 = h.pos + tick_direction * (radius + 5.0)
			var tick_end: Vector2 = h.pos + tick_direction * (radius + 11.0 + pulse * 3.0)
			draw_line(tick_start, tick_end, Color(accent_color, 0.38 + pulse * 0.22), 1.8, true)
		# Replace the old X with a rotating four-prong lock reticle and a small
		# diamond core. It stays legible, but no longer looks like a placeholder.
		var core_radius: float = 5.0 + pulse * 2.0
		draw_circle(h.pos, core_radius + 7.0 + pulse * 2.0, Color(base_color, 0.08 + pulse * 0.05))
		draw_circle(h.pos, core_radius, Color(base_color, 0.86))
		var diamond: float = 3.0 + pulse * 1.2
		var diamond_points := [
			h.pos + Vector2(0.0, -diamond), h.pos + Vector2(diamond, 0.0),
			h.pos + Vector2(0.0, diamond), h.pos + Vector2(-diamond, 0.0)]
		for index in range(4):
			draw_line(diamond_points[index], diamond_points[(index + 1) % 4],
				accent_color, 1.8, true)
		for index in range(4):
			var prong_angle: float = phase + float(index) * PI * 0.5 + _time * 0.55
			var prong_direction := Vector2.from_angle(prong_angle)
			draw_line(h.pos + prong_direction * (core_radius + 4.0),
				h.pos + prong_direction * (core_radius + 12.0 + pulse * 2.0),
				Color(accent_color, 0.86), 2.0, true)
		# A moving scan slice ties the rings together without becoming a damaging
		# beam. This is render-only; collision still uses the original circle.
		var scan_angle: float = spin * 2.2
		draw_arc(h.pos, radius * 0.70, scan_angle, scan_angle + 0.22, 8,
			Color(accent_color, 0.76), 2.2, true)
		if shape == "prism_burst":
			# Four short prism shards make the signature readable without drawing
			# an unsafe full-screen X-ray. The damage model remains this one circle.
			var shard_angle: float = spin * 1.35
			for index in range(4):
				var shard_direction := Vector2.from_angle(shard_angle + float(index) * PI * 0.5)
				var shard_start: Vector2 = h.pos + shard_direction * (radius * 0.25)
				var shard_end: Vector2 = h.pos + shard_direction * (radius * 0.78)
				draw_line(shard_start, shard_end, Color(accent_color, 0.62 + pulse * 0.20), 2.2, true)
				draw_circle(shard_end, 2.5 + pulse * 1.2, Color(accent_color, 0.88))
		return

	# Active state: keep the boundary clear, then send two delayed shockwaves
	# outward. The short active window now reads as a real impact instead of a
	# white static disk.
	var active_pulse: float = 0.5 + 0.5 * sin(_time * 19.0 + phase)
	var impact_flash: float = clampf(1.0 - active_progress * 5.0, 0.0, 1.0)
	draw_circle(h.pos, radius, Color(base_color, 0.065 + active_pulse * 0.035))
	draw_circle(h.pos, radius * (0.26 + impact_flash * 0.12),
		Color(accent_color, 0.12 + impact_flash * 0.16))
	draw_arc(h.pos, radius + 2.0 + active_pulse * 2.0, spin, spin + TAU * 0.94,
			48, Color(accent_color, 0.72 + active_pulse * 0.20), 3.6 + active_pulse, true)
	for wave in range(2):
		var wave_delay: float = float(wave) * 0.16
		if active_progress <= wave_delay:
			continue
		var wave_progress: float = clampf((active_progress - wave_delay) / (1.0 - wave_delay), 0.0, 1.0)
		var wave_eased: float = 1.0 - pow(1.0 - wave_progress, 2.0)
		var wave_radius: float = lerpf(radius * 0.16, radius * (1.02 + float(wave) * 0.12), wave_eased)
		var wave_alpha: float = (1.0 - wave_progress) * (0.82 - float(wave) * 0.18)
		var wave_angle: float = spin * (1.0 if wave == 0 else -0.72) + float(wave) * 1.2
		draw_arc(h.pos, wave_radius, wave_angle, wave_angle + TAU * 0.78,
			36, Color(accent_color, wave_alpha), 3.0 - float(wave) * 0.7, true)
		draw_arc(h.pos, wave_radius - 5.0, wave_angle + PI * 0.22,
			wave_angle + PI * 0.22 + TAU * 0.36, 18,
			Color(base_color, wave_alpha * 0.72), 1.6, true)
	# Rotating energy spokes break up the active field and make the centre of the
	# hit area obvious without drawing a full-screen line.
	for index in range(8):
		var spoke_angle: float = spin + float(index) * TAU / 8.0
		var spoke_direction := Vector2.from_angle(spoke_angle)
		var spoke_length: float = radius * (0.58 + 0.12 * sin(_time * 8.0 + index))
		var spoke_start: Vector2 = h.pos + spoke_direction * (radius * 0.22)
		var spoke_end: Vector2 = h.pos + spoke_direction * spoke_length
		draw_line(spoke_start, spoke_end,
			Color(base_color, 0.26 + active_pulse * 0.18), 1.5, true)
		var tip: Vector2 = h.pos + spoke_direction * minf(radius + 7.0, spoke_length + 7.0)
		draw_circle(tip, 2.0 + active_pulse * 0.8, Color(accent_color, 0.72))
	if shape == "prism_burst":
		var active_shard_angle: float = spin * 1.35 - active_progress * 0.7
		for index in range(4):
			var shard_direction := Vector2.from_angle(active_shard_angle + float(index) * PI * 0.5)
			draw_line(h.pos + shard_direction * (radius * 0.18),
				h.pos + shard_direction * (radius * 0.86),
				Color(accent_color, 0.82 - active_progress * 0.22), 2.4, true)
	var core_radius_active: float = 7.0 + impact_flash * 4.0 + active_pulse * 1.5
	draw_circle(h.pos, core_radius_active + 5.0, Color(base_color, 0.15 + impact_flash * 0.10))
	draw_circle(h.pos, core_radius_active, Color(accent_color, 0.74 + impact_flash * 0.20))
	draw_circle(h.pos, core_radius_active * 0.34, Color(base_color, 0.95))
	for index in range(4):
		var spoke_angle: float = phase + float(index) * PI * 0.5 - _time * 1.1
		var spoke_direction := Vector2.from_angle(spoke_angle)
		draw_line(h.pos + spoke_direction * (core_radius_active + 4.0),
			h.pos + spoke_direction * (core_radius_active + 12.0 + impact_flash * 7.0),
			Color(accent_color, 0.90), 2.0, true)
	if impact_flash > 0.0:
		draw_arc(h.pos, radius * (0.34 + impact_flash * 0.30), -PI * 0.5,
			-PI * 0.5 + TAU * (0.72 + impact_flash * 0.18), 32,
			Color("ffffff", 0.36 * impact_flash), 2.4, true)

func _draw_split_bomb_hazard(h: Dictionary, progress: float, color: Color) -> void:
	var accent := Color("fff1b0")
	var pulse: float = 0.5 + 0.5 * sin(_time * 16.0)
	var bomb_radius: float = 8.0 + pulse * 2.0
	var marker_fade: float = 0.84 if not h.fired else 0.38
	var marker_radius: float = 54.0 + progress * 28.0
	draw_circle(h.pos, marker_radius, Color("fff1dd", 0.035 * marker_fade))
	draw_arc(h.pos, marker_radius, -PI * 0.5 + _time * 0.35,
		-PI * 0.5 + TAU * 0.82 + _time * 0.35, 48, Color("fff1dd", marker_fade), 2.6, true)
	draw_arc(h.pos, marker_radius * 0.66, PI * 0.16 - _time * 0.28,
		PI * 0.16 + TAU * 0.72 - _time * 0.28, 36, Color("fff1dd", marker_fade * 0.75), 1.8, true)
	var cross_size: float = 10.0 + progress * 7.0
	draw_line(h.pos - Vector2.ONE * cross_size, h.pos + Vector2.ONE * cross_size, Color("fff1dd", marker_fade), 2.2, true)
	draw_line(h.pos + Vector2(cross_size, -cross_size), h.pos + Vector2(-cross_size, cross_size), Color("fff1dd", marker_fade), 2.2, true)
	if h.fired:
		draw_circle(h.pos, 24.0 + progress * 18.0, Color(color, 0.10))
		draw_arc(h.pos, 22.0 + progress * 18.0, 0.0, TAU, 28, Color(accent, 0.84), 2.0, true)
		for index in range(6):
			var ray := Vector2.from_angle(float(index) * TAU / 6.0 + _time)
			draw_line(h.pos + ray * 9.0, h.pos + ray * (17.0 + progress * 9.0), Color(color, 0.75), 2.0, true)
		return
	draw_circle(h.pos, 30.0, Color(color, 0.045))
	draw_arc(h.pos, 30.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, TAU * progress), 28, color, 2.0, true)
	draw_circle(h.pos, bomb_radius, Color(color, 0.92))
	draw_circle(h.pos, bomb_radius * 0.46, accent)
	draw_arc(h.pos, bomb_radius + 4.0, _time * 5.0, _time * 5.0 + PI * 1.35, 16, accent, 1.4, true)
	var count: int = int(h.get("count", 3))
	var spread: float = float(h.get("spread", 0.9))
	for index in range(count):
		var shard_angle: float = float(h.get("angle", 0.0)) + (float(index) / maxf(1.0, count - 1.0) - 0.5) * spread
		var shard_direction := Vector2.from_angle(shard_angle)
		var shard_pos: Vector2 = h.pos + shard_direction * (42.0 + progress * 12.0)
		draw_dashed_line(h.pos + shard_direction * 13.0, shard_pos, Color(color, 0.28), 1.0, 5.0, true)
		draw_colored_polygon(PackedVector2Array([
			shard_pos + shard_direction * 5.0,
			shard_pos + shard_direction.orthogonal() * 3.0,
			shard_pos - shard_direction * 4.0,
			shard_pos - shard_direction.orthogonal() * 3.0,
		]), Color(accent, 0.52))

func _draw_projectile_prepare(h: Dictionary, progress: float) -> void:
	var direction: Vector2 = _hazard_direction(h)
	var aim_angle: float = direction.angle()
	var phase: float = float(h.get("prepare_phase", 0.0))
	var pulse: float = 0.5 + 0.5 * sin(_time * 15.0 + phase)
	var orange := Color("ff916d")
	var accent := Color("fff1b0")
	var owner: Dictionary = _unit(int(h.get("owner", -1)))
	var source_radius: float = float(owner.get("radius", 15.0)) if not owner.is_empty() else 15.0
	var ring_radius: float = source_radius * 1.22 + 10.0 + progress * 2.0
	var ring_start: float = aim_angle + 0.56 + sin(_time * 2.0 + phase) * 0.04
	var ring_end: float = ring_start + TAU * (0.69 + progress * 0.045)
	var ring_alpha: float = 0.66 + pulse * 0.20
	# The large C-shaped charge ring hugs the shooter, leaving an opening toward
	# the muzzle so the player can immediately read the firing direction.
	draw_circle(h.pos, ring_radius - 2.0, Color(orange, 0.035 * ring_alpha))
	draw_arc(h.pos, ring_radius, ring_start, ring_end, 34, Color(orange, ring_alpha * 0.34), 5.0, true)
	draw_arc(h.pos, ring_radius, ring_start, ring_end, 34, Color(orange, ring_alpha), 2.2, true)
	var inner_ring_radius: float = ring_radius - 5.0
	draw_arc(h.pos, inner_ring_radius, ring_start + 0.10, ring_end - 0.18, 28,
		Color(accent, ring_alpha * 0.42), 1.0, true)
	# A bright core and two small crossbars make the charge readable even when
	# the enemy sprite is dark or visually busy.
	draw_circle(h.pos, 3.2 + pulse * 1.4, Color(orange, 0.86))
	draw_line(h.pos - direction.orthogonal() * (4.0 + pulse * 1.5),
		h.pos + direction.orthogonal() * (4.0 + pulse * 1.5), Color(accent, 0.92), 1.4, true)
	draw_line(h.pos - direction * (4.0 + pulse * 1.5),
		h.pos + direction * (4.0 + pulse * 1.5), Color(orange, 0.90), 1.4, true)
	# Energy is pulled from the ring into a short muzzle rail before the actual
	# projectile exists. This is a visual telegraph only; it does not collide.
	var rail_start: Vector2 = h.pos + direction * (source_radius * 0.62)
	var rail_end: Vector2 = h.pos + direction * (ring_radius + 17.0 + progress * 8.0)
	draw_line(rail_start, rail_end, Color(orange, 0.30 + pulse * 0.14), 6.0, true)
	draw_line(rail_start, rail_end, Color(accent, 0.86), 2.2, true)
	var muzzle_center: Vector2 = h.pos + direction * (ring_radius + 24.0 + progress * 8.0)
	var muzzle_radius: float = 8.0 + progress * 3.0
	var muzzle_start: float = aim_angle - 1.05
	var muzzle_end: float = aim_angle + 1.05
	draw_arc(muzzle_center, muzzle_radius, muzzle_start, muzzle_end, 18,
		Color(accent, 0.28 + pulse * 0.14), 5.5, true)
	draw_arc(muzzle_center, muzzle_radius, muzzle_start, muzzle_end, 18,
		Color(accent, 0.94), 2.0, true)
	draw_circle(muzzle_center, 2.6 + pulse * 1.4, Color(accent, 0.98))
	# Three loose orange fragments sell the charge as an animated energy build-up.
	for index in range(3):
		var fragment_angle: float = aim_angle + (float(index) - 1.0) * 0.62 + sin(_time * 2.4 + phase + index) * 0.08
		var fragment_direction := Vector2.from_angle(fragment_angle)
		var fragment_distance: float = ring_radius + 10.0 + fposmod(_time * 10.0 + float(index) * 7.0 + phase, 12.0)
		var fragment_pos: Vector2 = h.pos + fragment_direction * fragment_distance
		var fragment_normal := fragment_direction.orthogonal()
		draw_line(fragment_pos - fragment_normal * 4.5, fragment_pos + fragment_normal * 4.5,
			Color(orange, 0.64 + pulse * 0.20), 2.5, true)
	# A moving scan point travels along the large charge ring.
	var scan: float = fposmod(progress * 1.4 + _time * 0.55 + phase * 0.08, 1.0)
	var scan_angle: float = lerpf(ring_start, ring_end, scan)
	var scan_pos: Vector2 = h.pos + Vector2.from_angle(scan_angle) * ring_radius
	draw_circle(scan_pos, 2.2 + pulse * 1.2, Color(accent, 0.98))

func _draw_dash_path(h: Dictionary, progress: float) -> void:
	var is_boss_lunge: bool = bool(h.get("boss_lunge", false))
	var base := Color("35e7ff") if is_boss_lunge else Color("fff1dd")
	var accent := Color("b8ffff") if is_boss_lunge else Color("ff916d")
	var phase: float = float(h.get("prepare_phase", 0.0))
	for i in range(h.path.size() - 1):
		var a: Vector2 = h.path[i]
		var b: Vector2 = h.path[i + 1]
		var direction: Vector2 = (b - a).normalized()
		var normal := direction.orthogonal()
		var length: float = a.distance_to(b)
		if h.fired:
			draw_line(a, b, Color(base, 0.24), 5.0, true)
		var dash_length: float = 19.0 if is_boss_lunge else 15.0
		var gap: float = 13.0 if is_boss_lunge else 11.0
		var offset: float = fposmod(_time * 38.0 + phase * 9.0, dash_length + gap) - (dash_length + gap)
		while offset < length:
			var start_distance: float = maxf(0.0, offset)
			var end_distance: float = minf(length, offset + dash_length)
			if end_distance > start_distance:
				draw_line(a + direction * start_distance, a + direction * end_distance,
					Color(base, 0.72 if not h.fired else 0.9), 2.8 if is_boss_lunge else 2.2, true)
			offset += dash_length + gap
		if is_boss_lunge:
			draw_line(a + normal * (h.radius + 7.0), b + normal * (h.radius + 7.0), Color(base, 0.20), 1.0, true)
			draw_line(a - normal * (h.radius + 7.0), b - normal * (h.radius + 7.0), Color(base, 0.20), 1.0, true)
		if i == h.path.size() - 2:
			var arrow_size: float = 11.0 if is_boss_lunge else 8.0
			draw_line(b, b - direction * arrow_size + normal * arrow_size * 0.62, Color(accent, 0.92), 2.0, true)
			draw_line(b, b - direction * arrow_size - normal * arrow_size * 0.62, Color(accent, 0.92), 2.0, true)
		if h.get("reflected", false) and i == 0:
			draw_rect(Rect2(b - Vector2(9, 9), Vector2(18, 18)), accent, false, 3.0)

func _draw_laser_hazard(h: Dictionary, progress: float) -> void:
	var owner: Dictionary = _unit(int(h.get("owner", -1)))
	var is_boss_laser: bool = h.type == "boss_beam" or bool(h.get("boss_xray", false)) or (not owner.is_empty() and bool(owner.get("boss", false)))
	var beam_stage: int = int(h.get("beam_stage", _stage))
	var profile: Dictionary = _boss_beam_profile(beam_stage)
	var beam_color: Color = Color("ff647c")
	var accent: Color = Color("e6f7ff")
	var telegraph_color: Color = Color("ff916d")
	var style: String = "enemy"
	if is_boss_laser:
		beam_color = profile.get("color", beam_color)
		accent = profile.get("accent", accent)
		telegraph_color = profile.get("telegraph", telegraph_color)
		style = str(profile.get("style", "steady"))
	var beam_time: float = float(h.get("beam_elapsed", _time))
	var phase: float = float(h.get("beam_phase", h.get("prepare_phase", 0.0)))
	var pulse_speed: float = float(profile.get("pulse_speed", 8.0)) if is_boss_laser else 8.0
	var pulse: float = 0.5 + 0.5 * sin(beam_time * pulse_speed + phase)
	for i in range(h.path.size() - 1):
		var a: Vector2 = h.path[i]
		var b: Vector2 = h.path[i + 1]
		var direction: Vector2 = (b - a).normalized()
		var normal := direction.orthogonal()
		var length: float = a.distance_to(b)
		if length < 0.1:
			continue
		var segment_phase: float = phase + float(i) * 0.73
		if h.fired:
			var breathe: float = 0.84 + pulse * 0.16
			draw_line(a, b, Color(beam_color, 0.12 + pulse * 0.08), h.radius * 2.0 + 18.0 + pulse * 4.0, true)
			draw_line(a, b, Color(beam_color, 0.34 + pulse * 0.14), h.radius * 2.0 + 9.0, true)
			draw_line(a, b, Color(Color("f3f7ff"), 0.72 + pulse * 0.18), h.radius * 2.0 + 5.0, true)
			draw_line(a, b, Color(accent, 0.82 + pulse * 0.13), maxf(1.5, h.radius * 0.45), true)

			# Several short energy packets travel along the beam. Different boss
			# profiles change their cadence and spacing while the collision line stays
			# exactly on the authored path.
			var pulse_count: int = maxi(1, int(profile.get("pulse_count", 2))) if is_boss_laser else 2
			var travel_speed: float = float(profile.get("travel_speed", 170.0)) if is_boss_laser else 170.0
			var pulse_length: float = float(profile.get("pulse_length", 24.0)) if is_boss_laser else 20.0
			for pulse_index in range(pulse_count):
				var packet_phase: float = float(pulse_index) * length / float(pulse_count)
				var packet_distance: float = fposmod(beam_time * travel_speed + segment_phase * 23.0 + packet_phase, length)
				var packet_size: float = minf(pulse_length, length * 0.20)
				var packet_start: float = maxf(0.0, packet_distance - packet_size)
				var packet_end: float = minf(length, packet_distance + packet_size)
				if packet_end > packet_start:
					draw_line(a + direction * packet_start, a + direction * packet_end,
						Color(accent, 0.18 + pulse * 0.24), maxf(2.0, h.radius * 0.82), true)
				var packet_pos: Vector2 = a + direction * packet_distance
				draw_circle(packet_pos, 2.4 + pulse * 1.6, Color(accent, 0.84 * breathe))

			var marker_step: float = float(profile.get("marker_step", 56.0)) if is_boss_laser else 48.0
			var marker_speed: float = float(profile.get("marker_speed", 42.0)) if is_boss_laser else 36.0
			var marker_offset: float = fposmod(beam_time * marker_speed + segment_phase * 11.0, marker_step) - marker_step
			while marker_offset < length:
				if marker_offset >= 0.0:
					var marker_pos: Vector2 = a + direction * marker_offset
					var marker_span: float = h.radius + 4.0 + pulse * 2.0
					draw_line(marker_pos - normal * marker_span, marker_pos + normal * marker_span,
						Color(accent, 0.32 + pulse * 0.26), 1.4, true)
				marker_offset += marker_step

			# Small profile accents make each stage's beam feel alive without adding
			# extra nodes or obscuring the hitbox.
			if style == "echo":
				var echo_distance: float = fposmod(beam_time * travel_speed * 0.72 + length * 0.5 + segment_phase * 17.0, length)
				draw_circle(a + direction * echo_distance, 4.0 + pulse * 1.5, Color(beam_color, 0.28 + pulse * 0.16))
			elif style == "prism":
				var prism_distance: float = fposmod(beam_time * travel_speed * 1.3 + segment_phase * 31.0, length)
				var prism_pos: Vector2 = a + direction * prism_distance
				draw_line(prism_pos - normal * (h.radius + 7.0), prism_pos + normal * (h.radius + 7.0), Color(accent, 0.70 + pulse * 0.22), 1.6, true)
			elif style == "void":
				var void_distance: float = fposmod(beam_time * travel_speed * 0.42 + length * 0.24 + segment_phase * 13.0, length)
				var void_pos: Vector2 = a + direction * void_distance
				draw_circle(void_pos, 4.5 + pulse * 1.5, Color("241044", 0.32 + pulse * 0.18))
		else:
			var charge: float = 0.62 + progress * 0.38
			var half_width: float = h.radius + (12.0 if is_boss_laser else 8.0) + pulse * 1.5
			draw_line(a, b, Color(telegraph_color, 0.14 + pulse * 0.08), half_width * 2.0 + 6.0, true)
			draw_line(a, b, Color(beam_color, 0.16 * charge), half_width * 1.15, true)
			draw_line(a, b, Color(Color("f3f7ff"), 0.58 + pulse * 0.20), 2.0 + pulse * 0.5, true)
			var stripe_step: float = float(profile.get("stripe_step", 29.0)) if is_boss_laser else 29.0
			var stripe_speed: float = float(profile.get("stripe_speed", 22.0)) if is_boss_laser else 22.0
			var offset: float = fposmod(beam_time * stripe_speed + segment_phase * 8.0, stripe_step) - stripe_step
			while offset < length:
				if offset + 6.0 > 0.0 and offset < length:
					var center: Vector2 = a + direction * clampf(offset + 6.0, 0.0, length)
					draw_line(center - normal * half_width * 0.72, center + normal * half_width * 0.72,
						Color(telegraph_color, (0.62 + pulse * 0.26) * charge), 2.6 + pulse * 0.8, true)
					if is_boss_laser:
						draw_line(center - normal * half_width * 0.36, center + normal * half_width * 0.36,
							Color(accent, 0.72 * charge), 1.0, true)
				offset += stripe_step
			var scan_distance: float = fposmod(beam_time * (stripe_speed * 2.8) + segment_phase * 19.0, length)
			var scan_pos: Vector2 = a + direction * scan_distance
			draw_circle(scan_pos, 2.6 + pulse * 1.4, Color(accent, (0.68 + pulse * 0.25) * charge))
		if h.get("reflected", false) and i == 0:
			var reflect_color: Color = telegraph_color if not h.fired else beam_color
			draw_rect(Rect2(b - Vector2(9, 9), Vector2(18, 18)), reflect_color, false, 3.0)
			draw_arc(b, 13.0 + pulse * 3.0, phase, phase + PI * 1.35, 18,
				Color(accent, 0.72 + pulse * 0.20), 1.6, true)
