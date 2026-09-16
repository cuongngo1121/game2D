class_name WeaponSystem
extends RefCounted

var game
var cooldown: float = 0
var orbit_time: float = 0
var orbit_tick: float = 0
var beam_lines: Array = []
var sequence: Array = []
var sequence_timer: float = 0
var shot_index: int = 0

func setup(owner_game) -> void:
	game = owner_game

func definition(id: String) -> Dictionary:
	for weapon in game.content.weapons:
		if weapon.id == id:
			return weapon
	return game.content.weapons[0]

func reset() -> void:
	cooldown = 0
	orbit_time = 0
	beam_lines.clear()
	sequence.clear()

func update(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	for line in beam_lines:
		line.time -= delta
	beam_lines = beam_lines.filter(func(line): return line.time > 0)
	if not sequence.is_empty():
		sequence_timer -= delta
		if sequence_timer <= 0:
			var note: Dictionary = sequence.pop_front()
			bullet(note.weapon, note.direction, "chord", 0, 0, note.get("speed_factor", 1.0))
			sequence_timer = 0.085
	if orbit_time > 0:
		orbit_time -= delta
		orbit_tick -= delta
		if orbit_tick <= 0:
			orbit_tick = 0.23
			for i in range(3):
				var offset = Vector2.from_angle(game.elapsed * 4.5 + i * TAU / 3) * 64
				var center = game.player.position + offset
				if game.has_line_of_sight(game.player.position, center):
					game.enemies.damage_in_radius(center, 23, definition("orbit").damage)
					game.projectiles.erase_in_radius(center, 16)
	var direction: Vector2 = game.controls.aim_direction(game.player.position)
	if game.settings.get("auto_aim", true) and (game.controls.is_touch or not game.controls.mouse_aim_active):
		var target: Dictionary = game.enemies.nearest_target(game.player.position, 750)
		if not target.is_empty():
			direction = (target.pos - game.player.position).normalized()
	if direction.length_squared() > 0.01:
		game.player.aim_direction = direction
	if game.controls.firing() and cooldown <= 0:
		fire()

func fire() -> bool:
	var weapon: Dictionary = definition(game.weapons[game.active_slot])
	if game.player.energy < float(weapon.energy):
		weapon = definition("pistol")
	game.player.energy = maxf(0, game.player.energy - float(weapon.energy))
	cooldown = float(weapon.cooldown)
	game.player.attack_flash = 0.055
	game.player.play_attack_animation()
	game.player.play_weapon_fire_animation()
	game.audio.play_sfx("weapon_" + str(weapon.id))
	var direction: Vector2 = game.player.aim_direction
	var piercing: int = int(game.upgrades.get("pierce", 0))
	var bounce: int = int(game.upgrades.get("bounce", 0))
	match str(weapon.id):
		"pistol", "smg":
			var spread: float = game.rng.randf_range(-0.09, 0.09) if weapon.id == "smg" else 0.0
			bullet(weapon, direction.rotated(spread), "normal", piercing, bounce)
		"shotgun":
			for i in range(7):
				bullet(weapon, direction.rotated((i - 3) * 0.12), "normal", piercing, bounce)
		"rail":
			bullet(weapon, direction, "normal", 5 + piercing, bounce, 1.0, 4.0)
		"beam":
			var start: Vector2 = game.player.weapon_beam_origin()
			var finish: Vector2 = start + direction * float(weapon.range)
			finish = clipped_line(start, finish)
			beam_lines.append({"from": start, "to": finish, "time": 0.12, "color": Color("35e7ff")})
			for enemy in game.enemies.units.duplicate():
				if Geometry2D.get_closest_point_to_segment(enemy.pos, start, finish).distance_to(enemy.pos) < float(enemy.radius) + 5:
					game.enemies.damage_enemy(enemy.id, weapon.damage)
		"disc":
			bullet(weapon, direction, "disc", 8 + piercing, 0, 1.0, 10)
		"arc":
			var target: Dictionary = game.enemies.nearest_target(game.player.position, weapon.range)
			var previous: Vector2 = game.player.position
			var hit: Array = []
			for i in range(3 + int(game.upgrades.get("chain", 0)) * 2):
				if target.is_empty():
					break
				hit.append(target.id)
				beam_lines.append({"from": previous, "to": target.pos, "time": 0.20, "color": Color("9b4dff")})
				game.enemies.damage_enemy(target.id, float(weapon.damage) * pow(0.83, i))
				previous = target.pos
				target = {}
				var distance_limit: float = 145.0 + int(game.upgrades.get("chain", 0)) * 25
				for candidate in game.enemies.units:
					var distance: float = candidate.pos.distance_to(previous)
					if not hit.has(candidate.id) and distance < distance_limit and game.has_line_of_sight(previous, candidate.pos):
						target = candidate
						distance_limit = distance
		"wave":
			bullet(weapon, direction, "wave", 3 + piercing, bounce, 1, 23)
		"glitch":
			bullet(weapon, direction, "glitch", 0, 0, 1, 7)
		"orbit":
			orbit_time = 4.0
			orbit_tick = 0
		"blade":
			var center: Vector2 = game.player.position + direction * 38
			game.add_fx(center, Color("35e7ff"), 53)
			game.projectiles.erase_in_radius(center, 58)
			for enemy in game.enemies.units.duplicate():
				if enemy.pos.distance_to(center) < 64 + enemy.radius and game.has_line_of_sight(game.player.position, enemy.pos):
					game.enemies.damage_enemy(enemy.id, weapon.damage)
		"chord":
			for i in range(3):
				sequence.append({"weapon": weapon, "direction": direction.rotated((i - 1) * 0.15), "speed_factor": 1.0 + i * 0.14})
			sequence_timer = 0
	shot_index += 1
	return true

func bullet(weapon: Dictionary, direction: Vector2, behavior: String, pierce: int, bounces: int, speed_factor: float = 1.0, bullet_radius: float = 4.0) -> void:
	var speed: float = float(weapon.speed) * speed_factor
	game.projectiles.spawn({"pos": game.player.weapon_projectile_spawn_position(), "vel": direction * speed,
		"damage": float(weapon.damage), "enemy": false, "radius": bullet_radius,
		"life": float(weapon.range) / maxf(speed, 1.0), "color": Color("67b9d4"),
		"pierce": pierce, "bounces": bounces, "behavior": behavior, "clearable": true})

func clipped_line(from: Vector2, to: Vector2) -> Vector2:
	var result = to
	for i in range(1, 81):
		var point = from.lerp(to, float(i) / 80.0)
		if not game.arena.has_point(point):
			return from.lerp(to, float(i - 1) / 80.0)
		for obstacle in game.obstacles:
			if obstacle.has_point(point):
				return from.lerp(to, float(i - 1) / 80.0)
	return result
