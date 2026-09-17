class_name ProjectileSystem
extends Node2D
## Single batched canvas and reusable dictionaries; no gameplay population cap.

var game
var active: Array[Dictionary] = []
var _pool: Array[Dictionary] = []
var total_allocated: int = 0
var _epoch: int = 0

func setup(owner_game) -> void:
	game = owner_game
	z_index = 12

func spawn(spec: Dictionary) -> void:
	var shot: Dictionary = _pool.pop_back() if not _pool.is_empty() else {}
	if shot.is_empty():
		total_allocated += 1
	shot.clear()
	shot.merge({"pos": Vector2.ZERO, "vel": Vector2.ZERO, "damage": 10.0,
		"enemy": false, "radius": 4.0, "life": 3.0, "color": Color("35e7ff"),
		"accent": Color("e6f7ff"), "trail_color": Color("35e7ff", 0.45),
		"visual": "enemy_orb", "weapon_id": "",
		"pierce": 0, "bounces": 0, "behavior": "normal", "clearable": true,
		"age": 0.0, "hit_ids": {}, "returning": false, "armed": false,
		"fuse": 0.45, "explosion_radius": 68.0, "phase": 0.0,
		"trail": [], "trail_max": 8})
	shot.merge(spec, true)
	shot["base_vel"] = shot.vel
	shot["previous_pos"] = shot.pos
	shot["trail"] = [shot.pos]
	shot["phase"] = float(shot.get("phase", 0.0))
	# Each projectile owns its hit ledger, including when callers reuse a spec.
	shot["hit_ids"] = {}
	active.append(shot)

func count() -> int:
	return active.size()

func clear() -> void:
	_epoch += 1
	for shot in active:
		_pool.append(shot)
	active.clear()
	queue_redraw()

func erase_in_radius(center: Vector2, radius: float) -> void:
	for i in range(active.size() - 1, -1, -1):
		var shot: Dictionary = active[i]
		if shot.enemy and shot.clearable and center.distance_squared_to(shot.pos) <= radius * radius:
			_recycle(i)
	queue_redraw()

func update(delta: float) -> void:
	var update_epoch: int = _epoch
	for i in range(active.size() - 1, -1, -1):
		var shot: Dictionary = active[i]
		shot.age += delta
		shot.life -= delta
		if shot.armed:
			shot.fuse -= delta
			if shot.fuse <= 0.0:
				_explode(shot)
				if update_epoch != _epoch:
					queue_redraw()
					return
				_recycle(i)
			continue
		if shot.life <= 0.0:
			if shot.behavior == "glitch":
				_arm(shot)
			else:
				_recycle(i)
			continue
		if shot.behavior == "disc":
			if shot.age >= float(shot.get("return_after", 0.55)) and not shot.returning:
				shot.returning = true
				shot.hit_ids.clear() # Deliberate second hit on the return trip.
			if shot.returning:
				var to_player: Vector2 = game.player.position - shot.pos
				if to_player.length() < 19.0:
					_recycle(i)
					continue
				shot.vel = to_player.normalized() * maxf(320.0, shot.base_vel.length())
		elif shot.behavior == "chord":
			var basis: Vector2 = shot.base_vel
			shot.vel = basis + basis.orthogonal().normalized() * sin(shot.age * 13.0 + shot.phase) * 95.0
		elif shot.behavior == "split" and shot.age >= float(shot.get("split_after", 0.65)):
			var base: Vector2 = shot.vel
			for child_index in range(2):
				var angle: float = -0.36 if child_index == 0 else 0.36
				spawn({"pos": shot.pos, "vel": base.rotated(angle), "enemy": true,
					"damage": shot.damage, "color": shot.color, "accent": shot.accent,
					"trail_color": shot.get("trail_color", shot.color), "visual": "enemy_shard",
					"life": shot.life, "radius": 4.5, "phase": shot.phase + angle})
			_recycle(i)
			continue
		var retired: bool = _advance(shot, delta)
		# Damage may end the run or start a boss intermission, clearing this pool.
		if update_epoch != _epoch:
			queue_redraw()
			return
		if not retired:
			_record_trail(shot)
		if retired:
			_recycle(i)
	queue_redraw()

func _record_trail(shot: Dictionary) -> void:
	var trail: Array = shot.get("trail", [])
	var last: Vector2 = trail.back() if not trail.is_empty() else shot.pos
	if last.distance_squared_to(shot.pos) >= 9.0:
		trail.append(shot.pos)
	var trail_max: int = maxi(3, int(shot.get("trail_max", 8)))
	while trail.size() > trail_max:
		trail.pop_front()
	shot["trail"] = trail

func _advance(shot: Dictionary, delta: float) -> bool:
	var advance_epoch: int = _epoch
	var remaining: float = delta
	for iteration in range(8):
		if remaining <= 0.00001:
			return false
		var start: Vector2 = shot.pos
		var finish: Vector2 = start + shot.vel * remaining
		var wall: Dictionary = _first_wall(start, finish, shot.radius)
		var wall_t: float = wall.get("t", 1.01)
		var hits: Array[Dictionary] = []
		if shot.enemy:
			var player_t: float = _segment_circle(start, finish, game.player.position, float(game.player.radius) + shot.radius)
			if player_t >= 0.0 and player_t < wall_t:
				hits.append({"t": player_t, "id": -1})
		else:
			for unit in game.enemies.units:
				if shot.hit_ids.has(unit.id) or unit.get("spawn_grace", 0.0) > 0.0:
					continue
				var hit_t: float = _segment_circle(start, finish, unit.pos, float(unit.radius) + shot.radius)
				if hit_t >= 0.0 and hit_t < wall_t:
					hits.append({"t": hit_t, "id": unit.id})
		hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
		for hit in hits:
			shot.pos = start.lerp(finish, hit.t)
			if shot.behavior == "glitch":
				_arm(shot)
				return false
			if shot.enemy:
				game.player.take_damage(shot.damage)
				return true
			shot.hit_ids[hit.id] = true
			game.enemies.damage_enemy(hit.id, shot.damage)
			if advance_epoch != _epoch:
				return true
			if shot.pierce <= 0:
				return true
			shot.pierce -= 1
		if wall_t <= 1.0:
			shot.pos = start.lerp(finish, wall_t) + wall.normal * 0.2
			if shot.behavior == "glitch":
				_arm(shot)
				return false
			if shot.behavior == "disc" and not shot.returning:
				shot.returning = true
				shot.hit_ids.clear()
				shot.vel = (game.player.position - shot.pos).normalized() * maxf(320.0, shot.base_vel.length())
			elif shot.bounces > 0:
				shot.bounces -= 1
				shot.vel = shot.vel.bounce(wall.normal)
				shot.base_vel = shot.vel
			else:
				return true
			remaining *= 1.0 - wall_t
		else:
			shot.pos = finish
			return false
	# Stop at the last contact if an unusually long frame consumes eight rebounds.
	return false

func _arm(shot: Dictionary) -> void:
	shot.armed = true
	shot.vel = Vector2.ZERO
	shot.life = 2.0
	game.add_fx(shot.pos, shot.color, 18.0)

func _explode(shot: Dictionary) -> void:
	game.add_fx(shot.pos, shot.color, shot.explosion_radius)
	game.audio.play_sfx("hit")
	if shot.enemy:
		if shot.pos.distance_to(game.player.position) < shot.explosion_radius + game.player.radius and game.has_line_of_sight(shot.pos, game.player.position):
			game.player.take_damage(shot.damage)
	else:
		game.enemies.damage_in_radius(shot.pos, shot.explosion_radius, shot.damage)

func _recycle(index: int) -> void:
	_pool.append(active[index])
	active.remove_at(index)

func _first_wall(a: Vector2, b: Vector2, radius: float) -> Dictionary:
	var area: Rect2 = game.arena.grow(-radius)
	var motion: Vector2 = b - a
	if a.x < area.position.x or a.y < area.position.y or a.x > area.end.x or a.y > area.end.y:
		return {"t": 0.0, "normal": -motion.normalized()}
	var best: Dictionary = {}
	var best_t: float = 1.01
	# Inner arena boundary: unlike obstacle intersections, we need the exit time.
	for axis in range(2):
		if absf(motion[axis]) < 0.000001:
			continue
		var boundary: float = area.end[axis] if motion[axis] > 0.0 else area.position[axis]
		var t: float = (boundary - a[axis]) / motion[axis]
		if t >= 0.0 and t <= 1.0 and t < best_t:
			var normal := Vector2.ZERO
			normal[axis] = -signf(motion[axis])
			best = {"t": t, "normal": normal}
			best_t = t
	for rect in game.obstacles:
		var hit: Dictionary = _segment_rect(a, b, rect.grow(radius))
		if not hit.is_empty() and hit.t < best_t:
			best = hit
			best_t = hit.t
	return best

static func _segment_rect(a: Vector2, b: Vector2, rect: Rect2) -> Dictionary:
	var direction: Vector2 = b - a
	var enter: float = 0.0
	var leave: float = 1.0
	var normal := Vector2.ZERO
	for axis in range(2):
		if absf(direction[axis]) < 0.000001:
			if a[axis] < rect.position[axis] or a[axis] > rect.end[axis]:
				return {}
			continue
		var t1: float = (rect.position[axis] - a[axis]) / direction[axis]
		var t2: float = (rect.end[axis] - a[axis]) / direction[axis]
		var entering: float = minf(t1, t2)
		if entering >= enter:
			enter = entering
			normal = Vector2.ZERO
			normal[axis] = -signf(direction[axis])
		leave = minf(leave, maxf(t1, t2))
		if enter > leave:
			return {}
	if leave < 0.0 or enter > 1.0:
		return {}
	if normal == Vector2.ZERO:
		normal = -direction.normalized()
	return {"t": maxf(0.0, enter), "normal": normal}

static func _segment_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> float:
	var offset: Vector2 = a - center
	if offset.length_squared() <= radius * radius:
		return 0.0
	var d: Vector2 = b - a
	var length_squared: float = d.length_squared()
	if length_squared < 0.000001:
		return -1.0
	var projection: float = offset.dot(d)
	var discriminant: float = projection * projection - length_squared * (offset.length_squared() - radius * radius)
	if discriminant < 0.0:
		return -1.0
	var t: float = (-projection - sqrt(discriminant)) / length_squared
	return t if t >= 0.0 and t <= 1.0 else -1.0

func _draw() -> void:
	for shot in active:
		var p: Vector2 = shot.pos
		var radius: float = float(shot.radius)
		var color: Color = shot.color
		var accent: Color = shot.get("accent", Color("e6f7ff"))
		if shot.armed:
			_draw_armed(shot, color, accent)
			continue
		if shot.enemy:
			_draw_enemy_shot(shot, p, radius, color, accent)
			continue
		var visual: String = str(shot.get("visual", shot.behavior))
		match visual:
			"pulse_orb":
				_draw_pulse_orb(shot, p, radius, color, accent)
			"needle_burst":
				_draw_needle_burst(shot, p, radius, color, accent)
			"pellet_shard":
				_draw_pellet_shard(shot, p, radius, color, accent)
			"rail_spear":
				_draw_rail_spear(shot, p, radius, color, accent)
			"echo_disc":
				_draw_echo_disc(shot, p, radius, color, accent)
			"sonic_wave":
				_draw_sonic_wave(shot, p, radius, color, accent)
			"glitch_charge":
				_draw_glitch_charge(shot, p, radius, color, accent)
			"chord_note":
				_draw_chord_note(shot, p, radius, color, accent)
			_:
				_draw_generic_shot(shot, p, radius, color, accent)

func _draw_trail(shot: Dictionary, color: Color, width: float = 3.0, alpha: float = 0.32) -> void:
	var trail: Array = shot.get("trail", [])
	if trail.size() < 2:
		return
	var last_index: int = trail.size() - 1
	for index in range(1, trail.size()):
		var from: Vector2 = trail[index - 1]
		var to: Vector2 = trail[index]
		var strength: float = float(index) / float(last_index)
		draw_line(from, to, Color(color, alpha * strength), maxf(1.0, width * strength), true)

func _shot_direction(shot: Dictionary) -> Vector2:
	var velocity: Vector2 = shot.vel
	return velocity.normalized() if velocity.length_squared() > 0.0001 else Vector2.RIGHT

func _draw_enemy_shot(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	var visual: String = str(shot.get("visual", "enemy_orb"))
	match visual:
		"enemy_bomb":
			_draw_enemy_bomb(shot, p, radius, color, accent, direction)
		"enemy_shard":
			_draw_enemy_shard(shot, p, radius, color, accent, direction)
		"enemy_ring":
			_draw_enemy_ring(shot, p, radius, color, accent, direction)
		"enemy_spiral":
			_draw_enemy_spiral(shot, p, radius, color, accent, direction)
		"enemy_laser":
			_draw_enemy_laser(shot, p, radius, color, accent, direction)
		_:
			_draw_enemy_orb(shot, p, radius, color, accent, direction)

func _enemy_trail_color(shot: Dictionary, fallback: Color) -> Color:
	var trail_color: Color = shot.get("trail_color", fallback)
	return trail_color

func _draw_enemy_orb(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	var trail_color := _enemy_trail_color(shot, color)
	_draw_trail(shot, trail_color, 3.5, 0.28)
	var pulse: float = 0.75 + 0.25 * sin(float(shot.age) * 18.0 + float(shot.phase))
	draw_circle(p, radius + 4.0 * pulse, Color(color, 0.12))
	draw_circle(p, radius + 1.2, Color("271024"))
	draw_circle(p, radius, color)
	draw_circle(p, maxf(1.5, radius * 0.46), accent)
	draw_arc(p, radius + 4.0, direction.angle() - 0.85, direction.angle() + 0.85, 12, Color(accent, 0.76), 1.5, true)
	var normal: Vector2 = direction.orthogonal()
	draw_line(p - normal * (radius + 2.0), p + normal * (radius + 2.0), Color(accent, 0.55), 1.0, true)
	if not shot.clearable:
		draw_line(p - direction * (radius + 3.0), p + direction * (radius + 3.0), Color.WHITE, 1.0, true)

func _draw_enemy_bomb(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	var trail_color := _enemy_trail_color(shot, color)
	_draw_trail(shot, trail_color, 5.5, 0.30)
	var split_after: float = maxf(0.05, float(shot.get("split_after", 0.65)))
	var countdown: float = clampf(1.0 - float(shot.age) / split_after, 0.0, 1.0)
	var spin: float = float(shot.phase) + float(shot.age) * 10.0
	var shell_radius: float = radius + 2.5 + sin(float(shot.age) * 20.0) * 1.2
	draw_circle(p, shell_radius + 5.0, Color(color, 0.11 + (1.0 - countdown) * 0.10))
	draw_circle(p, shell_radius + 1.0, Color("2b1830"))
	draw_circle(p, shell_radius, color)
	draw_circle(p, shell_radius * 0.42, accent)
	draw_arc(p, shell_radius + 5.0, spin, spin + TAU * (0.45 + countdown * 0.45), 18, accent, 1.8, true)
	for index in range(4):
		var angle: float = spin + float(index) * TAU / 4.0
		var ray := Vector2.from_angle(angle)
		draw_line(p + ray * (shell_radius + 3.0), p + ray * (shell_radius + 8.0), Color(accent, 0.78), 1.4, true)
	var normal: Vector2 = direction.orthogonal()
	draw_line(p - direction * 3.0 - normal * 3.0, p + direction * 3.0 + normal * 3.0, Color(accent, 0.88), 1.2, true)

func _draw_enemy_shard(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	_draw_trail(shot, _enemy_trail_color(shot, color), 3.0, 0.24)
	var normal: Vector2 = direction.orthogonal()
	var points := PackedVector2Array([
		p + direction * 7.0,
		p + normal * (radius + 1.0),
		p - direction * 5.0,
		p - normal * (radius + 1.0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("2b1830"), 1.2, true)
	draw_line(p - direction * 1.0, p + direction * 5.0, accent, 1.2, true)

func _draw_enemy_ring(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	_draw_trail(shot, _enemy_trail_color(shot, color), 3.0, 0.22)
	var spin: float = float(shot.age) * 11.0 + float(shot.phase)
	draw_circle(p, radius + 3.0, Color(color, 0.10))
	draw_arc(p, radius + 2.5, spin, spin + PI * 1.35, 16, color, 2.6, true)
	draw_arc(p, radius - 1.0, spin + PI, spin + PI * 1.65, 14, accent, 1.3, true)
	draw_circle(p, maxf(1.3, radius * 0.28), accent)

func _draw_enemy_spiral(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	_draw_trail(shot, _enemy_trail_color(shot, color), 4.0, 0.25)
	var phase: float = float(shot.age) * 12.0 + float(shot.phase)
	for index in range(3):
		var ring_radius: float = radius + 2.0 + float(index) * 2.0
		draw_arc(p, ring_radius, phase + float(index) * 0.9, phase + float(index) * 0.9 + PI * 0.72, 12, Color(color, 0.78 - float(index) * 0.16), 1.4, true)
	draw_circle(p, maxf(1.5, radius * 0.34), accent)

func _draw_enemy_laser(shot: Dictionary, p: Vector2, radius: float, color: Color,
		accent: Color, direction: Vector2) -> void:
	_draw_trail(shot, _enemy_trail_color(shot, color), 5.0, 0.28)
	draw_line(p - direction * 11.0, p + direction * 8.0, Color(color, 0.25), radius * 1.8, true)
	draw_line(p - direction * 9.0, p + direction * 8.0, color, 2.8, true)
	draw_line(p - direction * 5.0, p + direction * 5.0, accent, 1.1, true)

func _draw_armed(shot: Dictionary, color: Color, accent: Color) -> void:
	var p: Vector2 = shot.pos
	var progress: float = clampf(1.0 - float(shot.fuse) / 2.0, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(float(shot.age) * 24.0 + float(shot.phase))
	var radius: float = float(shot.explosion_radius)
	draw_circle(p, radius * (0.20 + progress * 0.16), Color(color, 0.10 + pulse * 0.06))
	draw_arc(p, radius * (0.34 + progress * 0.66), -PI * 0.5, TAU - PI * 0.5, 32, Color(color, 0.78), 2.0, true)
	draw_arc(p, radius * (0.22 + pulse * 0.08), 0.0, TAU, 16, Color(accent, 0.88), 1.5, true)
	for index in range(6):
		var angle: float = float(index) * TAU / 6.0 + float(shot.phase) * 0.2
		var start: Vector2 = p + Vector2.from_angle(angle) * (10.0 + progress * 5.0)
		var finish: Vector2 = p + Vector2.from_angle(angle) * (18.0 + progress * 20.0)
		draw_line(start, finish, Color(color, 0.55), 1.5, true)
	_draw_glitch_shape(p, 8.0 + pulse * 2.0, color, accent, float(shot.phase) + shot.age * 6.0)

func _draw_pulse_orb(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	_draw_trail(shot, color, 7.0, 0.26)
	var pulse: float = 0.88 + 0.12 * sin(float(shot.age) * 18.0 + float(shot.phase))
	draw_circle(p, radius + 4.0 * pulse, Color(color, 0.12))
	draw_circle(p, radius + 1.2, Color("071827"))
	draw_circle(p, radius, color)
	draw_circle(p, maxf(1.8, radius * 0.48), accent)
	draw_arc(p, radius + 3.0, float(shot.age) * 8.0, float(shot.age) * 8.0 + PI * 1.25, 12, Color(accent, 0.8), 1.2, true)

func _draw_needle_burst(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	var normal: Vector2 = direction.orthogonal()
	_draw_trail(shot, color, 4.5, 0.28)
	draw_line(p - direction * 10.0, p + direction * 5.0, Color(color, 0.55), radius + 2.0, true)
	draw_line(p - direction * 7.0, p + direction * 7.0, accent, 1.5, true)
	draw_line(p - normal * 2.0, p + normal * 2.0, accent, 1.0, true)

func _draw_pellet_shard(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	var normal: Vector2 = direction.orthogonal()
	_draw_trail(shot, color, 4.0, 0.22)
	var points := PackedVector2Array([
		p + direction * 6.0,
		p + normal * (radius + 1.0),
		p - direction * 4.0,
		p - normal * (radius + 1.0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("2b1830"), 1.5, true)
	draw_line(p - direction * 1.0, p + direction * 4.0, accent, 1.1, true)

func _draw_rail_spear(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	var normal: Vector2 = direction.orthogonal()
	_draw_trail(shot, color, 9.0, 0.24)
	draw_line(p - direction * 17.0, p + direction * 9.0, Color(color, 0.32), 7.0, true)
	draw_line(p - direction * 15.0, p + direction * 8.0, color, 3.0, true)
	draw_line(p - direction * 11.0 + normal * 2.8, p + direction * 5.0 + normal * 2.8, accent, 1.0, true)
	draw_line(p - direction * 11.0 - normal * 2.8, p + direction * 5.0 - normal * 2.8, accent, 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		p + direction * 10.0,
		p + normal * 2.8,
		p - direction * 4.0,
		p - normal * 2.8,
	]), accent)

func _draw_echo_disc(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	_draw_trail(shot, color, 6.0, 0.24)
	var spin: float = float(shot.age) * 15.0 + float(shot.phase)
	draw_circle(p, radius + 4.0, Color(color, 0.10))
	draw_arc(p, radius + 3.0, spin, spin + TAU * 0.74, 18, color, 3.0, true)
	draw_arc(p, radius - 1.0, spin + PI, spin + PI + TAU * 0.54, 16, accent, 2.0, true)
	draw_circle(p, maxf(1.5, radius * 0.24), Color("180e2a"))
	for index in range(4):
		var angle: float = spin + float(index) * TAU / 4.0
		draw_line(p + Vector2.from_angle(angle) * (radius * 0.35), p + Vector2.from_angle(angle) * (radius + 1.5), Color(accent, 0.78), 1.0, true)

func _draw_sonic_wave(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	_draw_trail(shot, color, 10.0, 0.20)
	var angle: float = direction.angle()
	var pulse: float = 0.5 + 0.5 * sin(float(shot.age) * 12.0 + float(shot.phase))
	for index in range(3):
		var offset: Vector2 = -direction * float(index) * 5.0
		var arc_radius: float = radius * (0.55 + float(index) * 0.18) + pulse * 2.0
		draw_arc(p + offset, arc_radius, angle - 1.08, angle + 1.08, 14, Color(color, 0.72 - float(index) * 0.16), 4.0 - float(index) * 0.7, true)
	draw_circle(p + direction * 3.0, 3.0, accent)

func _draw_glitch_charge(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	_draw_trail(shot, color, 6.0, 0.25)
	var jitter: float = sin(float(shot.age) * 31.0 + float(shot.phase)) * 2.0
	_draw_glitch_shape(p + Vector2(jitter, 0), radius + 3.0, color, accent, float(shot.phase) + shot.age * 8.0)
	for index in range(3):
		var y: float = p.y - 5.0 + float(index) * 5.0
		draw_line(Vector2(p.x - 7.0 + jitter, y), Vector2(p.x + 7.0 - jitter, y), Color(accent, 0.58), 1.0, true)

func _draw_glitch_shape(center: Vector2, radius: float, color: Color, accent: Color, phase: float) -> void:
	var points := PackedVector2Array()
	for index in range(8):
		var angle: float = float(index) * TAU / 8.0 + phase * 0.11
		var wobble: float = 1.0 + 0.12 * sin(phase * 2.0 + float(index) * 2.3)
		points.append(center + Vector2.from_angle(angle) * radius * wobble)
	draw_colored_polygon(points, Color(color, 0.86))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(accent, 0.9), 1.4, true)
	draw_circle(center, radius * 0.28, accent)

func _draw_chord_note(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	_draw_trail(shot, color, 4.5, 0.24)
	var phase: float = float(shot.age) * 13.0 + float(shot.phase)
	var wobble: Vector2 = direction.orthogonal() * sin(phase) * 2.0
	draw_circle(p + wobble, radius + 3.0, Color(color, 0.12))
	draw_circle(p + wobble, radius, color)
	draw_circle(p + wobble, maxf(1.5, radius * 0.42), accent)
	draw_arc(p + wobble, radius + 4.0, phase, phase + PI * 1.3, 12, Color(accent, 0.8), 1.2, true)
	draw_line(p + direction * 1.0 + wobble, p + direction * 1.0 + wobble - direction.orthogonal() * 8.0, accent, 1.2, true)

func _draw_generic_shot(shot: Dictionary, p: Vector2, radius: float, color: Color, accent: Color) -> void:
	var direction: Vector2 = _shot_direction(shot)
	_draw_trail(shot, color, radius * 1.5, 0.22)
	draw_line(p - direction * 8.0, p + direction * 4.0, color, radius * 1.45, true)
	draw_circle(p, maxf(1.0, radius * 0.35), accent)
