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
		"pierce": 0, "bounces": 0, "behavior": "normal", "clearable": true,
		"age": 0.0, "hit_ids": {}, "returning": false, "armed": false,
		"fuse": 0.45, "explosion_radius": 68.0, "phase": 0.0})
	shot.merge(spec, true)
	shot["base_vel"] = shot.vel
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
			for angle in [-0.36, 0.36]:
				spawn({"pos": shot.pos, "vel": base.rotated(angle), "enemy": true,
					"damage": shot.damage, "color": shot.color, "life": shot.life, "radius": 4.5})
			_recycle(i)
			continue
		var retired: bool = _advance(shot, delta)
		# Damage may end the run or start a boss intermission, clearing this pool.
		if update_epoch != _epoch:
			queue_redraw()
			return
		if retired:
			_recycle(i)
	queue_redraw()

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
	game.add_fx(shot.pos, Color("9b4dff"), 13.0)

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
		var radius: float = shot.radius
		var color: Color = shot.color
		if shot.armed:
			var progress: float = clampf(1.0 - shot.fuse / 0.45, 0.0, 1.0)
			draw_circle(p, shot.explosion_radius, Color(color, 0.09))
			draw_arc(p, shot.explosion_radius * progress, 0.0, TAU, 24, Color(color, 0.75), 2.0)
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), color, false, 2.0)
			continue
		if shot.enemy:
			draw_circle(p, radius + 2.2, Color("271024"))
			draw_circle(p, radius + 0.8, color)
			draw_circle(p, maxf(1.5, radius * 0.46), Color("fff3ed"))
			if not shot.clearable:
				draw_rect(Rect2(p - Vector2.ONE * (radius + 3.0), Vector2.ONE * (radius + 3.0) * 2.0), Color.WHITE, false, 1.0)
		elif shot.behavior == "disc":
			draw_arc(p, radius + 2.0, shot.age * 14.0, shot.age * 14.0 + TAU * 0.8, 12, color, 3.0)
		elif shot.behavior == "wave":
			var angle: float = shot.vel.angle()
			draw_arc(p, radius, angle - 1.1, angle + 1.1, 10, color, 5.0)
		elif shot.behavior == "glitch":
			draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), color)
		else:
			draw_line(p - shot.vel.normalized() * 7.0, p + shot.vel.normalized() * 3.0, color, radius * 1.45)
