class_name EchoPlayer
extends Node2D

const PIXEL_CHARACTER_DIR := "res://assets/characters/overhead_32/"
const PIXEL_WEAPON_DIR := "res://assets/sprites/pixel_32/weapons/"
const PIXEL_WEAPON_ANIMATION_DIR := "res://assets/sprites/pixel_32/weapons/animations/"
const CAMERA_ZOOM := Vector2(2.0, 2.0)
const PIXEL_CHARACTER_SCALE := Vector2(1.0, 1.0)
# The authored overhead frames look toward local up. Weapons are authored to
# point along local right, so rotate only the character art by +90 degrees.
const PIXEL_CHARACTER_FORWARD_OFFSET := PI * 0.5
const PIXEL_CHARACTER_SOURCE_ORIGIN := Vector2(15.0, 16.0)
const PIXEL_CHARACTER_RIGHT_HAND_SOURCE := Vector2(22.0, 17.0)
const PIXEL_WEAPON_GRIP_SOURCE := Vector2(3.0, 17.0)
const PIXEL_WEAPON_MUZZLE_SOURCE := Vector2(29.0, 17.0)
const PIXEL_WEAPON_SOURCE_SIZE := Vector2(32.0, 32.0)
# Its visible rear grip is anchored to the right glove after scaling and the
# model's +90 degree art correction; the barrel still follows the aim axis.
const PIXEL_WEAPON_DRAW_RECT := Rect2(-4, -3, 30, 18)
const PIXEL_WEAPON_FLASH_RECT := Rect2(23, 4, 7, 6)
const WEAPON_RECOIL_DURATION := 0.18
const WEAPON_RECOIL_FPS := 18.0
const ATTACK_ANIMATION_DURATION := 6.0 / 12.0
const PULSE_ANIMATION_DURATION := 6.0 / 12.0
const SHIELD_HIT_ANIMATION_DURATION := 0.42
const PIXEL_ANIMATION_CONFIG := {
	"idle": {"file": "echo_runner_overhead_idle_4x32.png", "frames": 4, "fps": 6.0},
	"run": {"file": "echo_runner_overhead_run_6x32.png", "frames": 6, "fps": 10.0},
	"attack": {"file": "echo_runner_overhead_attack_6x32.png", "frames": 6, "fps": 12.0},
	"run_attack": {"file": "echo_runner_overhead_run_attack_6x32.png", "frames": 6, "fps": 12.0},
	"dash": {"file": "echo_runner_overhead_dash_4x32.png", "frames": 4, "fps": 16.0},
	"hurt": {"file": "echo_runner_overhead_hurt_3x32.png", "frames": 3, "fps": 10.0},
	"pulse": {"file": "echo_runner_overhead_pulse_6x32.png", "frames": 6, "fps": 12.0},
	"death": {"file": "echo_runner_overhead_death_6x32.png", "frames": 6, "fps": 8.0},
}

var game
var radius: float = 11.0
var hp: float = 100.0
var max_hp: float = 100.0
var shield: float = 50.0
var max_shield: float = 50.0
var energy: float = 100.0
var max_energy: float = 100.0
var resonance: float = 0.0
var invulnerable: float = 0.0
var dash_cooldown: float = 0.0
var dash_time: float = 0.0
var dash_direction = Vector2.RIGHT
var move_direction = Vector2.ZERO
var aim_direction = Vector2.RIGHT
var last_move = Vector2.RIGHT
var since_damage: float = 99.0
var animation_time: float = 0.0
var attack_flash: float = 0.0
var regen_announced: bool = true
var perfect_beat: int = -999
var sprite: Texture2D
var animation_sprites: Dictionary = {}
var weapon_textures: Dictionary = {}
var weapon_recoil_sheets: Dictionary = {}
var pixel_animation_sheets: Dictionary = {}
var pixel_animation_frame_counts: Dictionary = {}
var pixel_animation_fps: Dictionary = {}
var pixel_character_enabled: bool = false
var pixel_animation_name: String = ""
var pixel_animation_frame: int = 0
var pixel_animation_elapsed: float = 0.0
var attack_animation_time: float = 0.0
var hurt_animation_time: float = 0.0
var pulse_animation_time: float = 0.0
var pulse_visual_radius: float = 155.0
var shield_hit_animation_time: float = 0.0
var shield_hit_angle: float = 0.0
var shield_hit_broken: bool = false
var dash_visual_time: float = 0.0
var follow_camera: Camera2D
var weapon_recoil_time: float = 0.0

func setup(owner_game) -> void:
	game = owner_game
	sprite = load("res://assets/sprites/player.svg")
	z_index = 9
	for pose in ["idle", "run_0", "run_1", "attack", "dash", "hurt", "death"]:
		animation_sprites[pose] = load("res://assets/sprites/player_%s.svg" % pose)
	for weapon in game.content.weapons:
		var pixel_path: String = str(weapon.get("model", PIXEL_WEAPON_DIR + "weapon_%s_32.png" % weapon.id))
		var recoil_path: String = PIXEL_WEAPON_ANIMATION_DIR + "weapon_%s_recoil_3x32.png" % weapon.id
		var fallback_path: String = "res://assets/sprites/weapon_%s.svg" % weapon.id
		if ResourceLoader.exists(pixel_path):
			weapon_textures[weapon.id] = load(pixel_path)
		elif ResourceLoader.exists(fallback_path):
			weapon_textures[weapon.id] = load(fallback_path)
		if ResourceLoader.exists(recoil_path):
			weapon_recoil_sheets[weapon.id] = load(recoil_path)
	load_pixel_character()
	setup_follow_camera()
	reset_visual_animation()

func setup_follow_camera() -> void:
	if follow_camera != null:
		return
	follow_camera = Camera2D.new()
	follow_camera.name = "FollowCamera"
	follow_camera.enabled = true
	follow_camera.zoom = CAMERA_ZOOM
	# The camera is parented to the player. Smoothing here double-integrates movement
	# and makes the player drift across the screen while the world scrolls.
	follow_camera.position_smoothing_enabled = false
	follow_camera.limit_left = 0
	follow_camera.limit_top = 0
	follow_camera.limit_right = 1280
	follow_camera.limit_bottom = 720
	add_child(follow_camera)

func configure_follow_camera(bounds: Rect2) -> void:
	if follow_camera == null:
		return
	follow_camera.limit_left = floori(bounds.position.x)
	follow_camera.limit_top = floori(bounds.position.y)
	follow_camera.limit_right = ceili(bounds.end.x)
	follow_camera.limit_bottom = ceili(bounds.end.y)
	follow_camera.reset_smoothing()

func reset_follow_camera() -> void:
	if follow_camera != null:
		follow_camera.reset_smoothing()

func load_pixel_character() -> void:
	pixel_animation_sheets.clear()
	pixel_animation_frame_counts.clear()
	pixel_animation_fps.clear()
	pixel_character_enabled = true
	for animation_name in PIXEL_ANIMATION_CONFIG:
		var config: Dictionary = PIXEL_ANIMATION_CONFIG[animation_name]
		var path: String = PIXEL_CHARACTER_DIR + str(config.file)
		if not ResourceLoader.exists(path):
			pixel_character_enabled = false
			break
		var sheet: Texture2D = load(path) as Texture2D
		var frame_count: int = int(config.frames)
		if sheet == null or sheet.get_width() != frame_count * 32 or sheet.get_height() != 32:
			pixel_character_enabled = false
			break
		pixel_animation_sheets[animation_name] = sheet
		pixel_animation_frame_counts[animation_name] = frame_count
		pixel_animation_fps[animation_name] = float(config.fps)
	if not pixel_character_enabled:
		pixel_animation_sheets.clear()
		pixel_animation_frame_counts.clear()
		pixel_animation_fps.clear()

func reset_visual_animation() -> void:
	pixel_animation_name = ""
	pixel_animation_frame = 0
	pixel_animation_elapsed = 0.0
	attack_animation_time = 0.0
	hurt_animation_time = 0.0
	pulse_animation_time = 0.0
	pulse_visual_radius = 155.0
	shield_hit_animation_time = 0.0
	shield_hit_angle = 0.0
	shield_hit_broken = false
	dash_visual_time = 0.0
	weapon_recoil_time = 0.0

func play_attack_animation() -> void:
	if hp <= 0:
		return
	if pixel_animation_name not in ["attack", "run_attack"]:
		pixel_animation_elapsed = 0.0
	attack_animation_time = maxf(attack_animation_time, ATTACK_ANIMATION_DURATION)

func play_weapon_fire_animation() -> void:
	weapon_recoil_time = maxf(weapon_recoil_time, WEAPON_RECOIL_DURATION)

func play_hurt_animation() -> void:
	if hp <= 0:
		return
	if pixel_animation_name != "hurt":
		pixel_animation_elapsed = 0.0
	hurt_animation_time = maxf(hurt_animation_time, 0.3)

func play_pulse_animation(reach: float = 155.0) -> void:
	if hp <= 0:
		return
	if pixel_animation_name != "pulse":
		pixel_animation_elapsed = 0.0
	pulse_animation_time = maxf(pulse_animation_time, PULSE_ANIMATION_DURATION)
	pulse_visual_radius = maxf(60.0, reach)

func visual_animation() -> String:
	if hp <= 0:
		return "death"
	if dash_time > 0 or dash_visual_time > 0:
		return "dash"
	if hurt_animation_time > 0:
		return "hurt"
	if pulse_animation_time > 0:
		return "pulse"
	if attack_animation_time > 0:
		return "run_attack" if move_direction.length_squared() > 0.01 else "attack"
	if move_direction.length_squared() > 0.01:
		return "run"
	return "idle"

func pixel_character_draw_angle() -> float:
	return aim_direction.angle() + PIXEL_CHARACTER_FORWARD_OFFSET

func pixel_weapon_draw_rect() -> Rect2:
	return PIXEL_WEAPON_DRAW_RECT

func pixel_character_right_hand_position() -> Vector2:
	var hand_from_center := (PIXEL_CHARACTER_RIGHT_HAND_SOURCE - PIXEL_CHARACTER_SOURCE_ORIGIN) * PIXEL_CHARACTER_SCALE
	return hand_from_center.rotated(PIXEL_CHARACTER_FORWARD_OFFSET)

func pixel_weapon_grip_position() -> Vector2:
	var grip_in_draw: Vector2 = PIXEL_WEAPON_GRIP_SOURCE / PIXEL_WEAPON_SOURCE_SIZE * PIXEL_WEAPON_DRAW_RECT.size
	return PIXEL_WEAPON_DRAW_RECT.position + grip_in_draw

func pixel_weapon_muzzle_local_position() -> Vector2:
	var muzzle_in_draw: Vector2 = PIXEL_WEAPON_MUZZLE_SOURCE / PIXEL_WEAPON_SOURCE_SIZE * PIXEL_WEAPON_DRAW_RECT.size
	return PIXEL_WEAPON_DRAW_RECT.position + muzzle_in_draw

func weapon_muzzle_position() -> Vector2:
	return position + pixel_weapon_muzzle_local_position().rotated(aim_direction.angle())

func weapon_projectile_spawn_position() -> Vector2:
	return weapon_muzzle_position()

func weapon_beam_origin() -> Vector2:
	return weapon_muzzle_position()

func _process(delta: float) -> void:
	if game == null or (game.state != "playing" and hp > 0):
		return
	animation_time += delta
	attack_flash = maxf(0, attack_flash - delta)
	attack_animation_time = maxf(0, attack_animation_time - delta)
	hurt_animation_time = maxf(0, hurt_animation_time - delta)
	pulse_animation_time = maxf(0, pulse_animation_time - delta)
	shield_hit_animation_time = maxf(0, shield_hit_animation_time - delta)
	dash_visual_time = maxf(0, dash_visual_time - delta)
	weapon_recoil_time = maxf(0, weapon_recoil_time - delta)
	if pixel_character_enabled:
		var next_animation: String = visual_animation()
		if next_animation != pixel_animation_name:
			pixel_animation_name = next_animation
			pixel_animation_frame = 0
			pixel_animation_elapsed = 0.0
		else:
			pixel_animation_elapsed += delta
		var frames: int = int(pixel_animation_frame_counts.get(pixel_animation_name, 1))
		var fps: float = float(pixel_animation_fps.get(pixel_animation_name, 1.0))
		pixel_animation_frame = mini(int(pixel_animation_elapsed * fps), frames - 1)
		if pixel_animation_name in ["idle", "run", "run_attack"]:
			pixel_animation_frame = int(pixel_animation_elapsed * fps) % frames
	queue_redraw()

func stacks(id: String) -> int:
	return int(game.upgrades.get(id, 0))

func refresh_stats() -> void:
	max_hp = 100.0 + 25.0 * stacks("health")
	max_shield = 50.0 + 20.0 * stacks("shield")
	max_energy = 100.0 + 30.0 * stacks("energy")
	hp = minf(hp, max_hp)
	shield = minf(shield, max_shield)
	energy = minf(energy, max_energy)

func dash_period() -> float:
	return maxf(0.65, 1.65 - stacks("dash") * 0.23)

func update(delta: float) -> void:
	invulnerable = maxf(0, invulnerable - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	since_damage += delta
	if since_damage > maxf(1.2, 4.0 - stacks("shield_delay") * 0.7) and shield < max_shield:
		shield = minf(max_shield, shield + 13.0 * delta)
		if not regen_announced:
			game.flash_text("Khiên đang hồi", Color("35e7ff"))
			regen_announced = true
	energy = minf(max_energy, energy + (5.0 + 3.5 * stacks("regen")) * delta)
	move_direction = game.controls.movement()
	if move_direction.length_squared() > 0.01:
		last_move = move_direction.normalized()
	if dash_time > 0:
		dash_time -= delta
		position = game.move_actor(position, dash_direction * 680.0 * delta, radius)
	else:
		var speed_multiplier: float = game.assignment_demo_speed_multiplier() if game.has_method("assignment_demo_speed_multiplier") else 1.0
		position = game.move_actor(position, move_direction * (205.0 + 23.0 * stacks("speed")) * speed_multiplier * delta, radius)
	queue_redraw()

func dash() -> bool:
	if dash_cooldown > 0 or hp <= 0:
		return false
	dash_direction = move_direction.normalized() if move_direction.length_squared() > 0.01 else last_move
	dash_time = 0.19
	dash_visual_time = 4.0 / 16.0
	invulnerable = maxf(invulnerable, 0.23)
	dash_cooldown = dash_period()
	game.audio.play_sfx("dash")
	game.add_fx(position, Color("35e7ff"), 24.0)
	if game.combat_active and game.rhythm.is_perfect() and perfect_beat != game.rhythm.beat_index:
		perfect_beat = game.rhythm.beat_index
		resonance = minf(100, resonance + 18)
		game.perfect_count += 1
		game.flash_text("PERFECT DASH  +18", Color("35e7ff"))
		game.audio.play_sfx("perfect")
		if stacks("perfect_wave") > 0:
			resonance = minf(100, resonance + 4 * stacks("perfect_wave"))
			for enemy in game.enemies.units:
				if enemy.pos.distance_to(position) < 100 and not enemy.boss and game.has_line_of_sight(position, enemy.pos):
					var push: Vector2 = (enemy.pos - position).normalized() * 40 * stacks("perfect_wave")
					enemy.pos = game.move_actor(enemy.pos, push, float(enemy.radius))
			game.enemies.damage_in_radius(position, 100.0, 14.0 * stacks("perfect_wave"))
			game.projectiles.erase_in_radius(position, 70.0)
			game.add_fx(position, Color("35e7ff"), 100.0)
	return true

func pulse() -> bool:
	if resonance < 100 or hp <= 0:
		return false
	resonance = 0
	var reach: float = 155 + 32 * stacks("pulse")
	play_pulse_animation(reach)
	game.enemies.damage_in_radius(position, reach, 95 + 30 * stacks("pulse"))
	game.projectiles.erase_in_radius(position, reach)
	game.add_fx(position, Color("9b4dff"), reach)
	game.audio.play_sfx("pulse")
	game.flash_text("PULSE BURST", Color("9b4dff"))
	return true

func take_damage(amount: float) -> void:
	if invulnerable > 0 or hp <= 0 or not game.combat_active or game.state != "playing":
		return
	var absorbed: float = minf(shield, amount)
	shield -= absorbed
	hp = maxf(0, hp - (amount - absorbed))
	shield_hit_animation_time = SHIELD_HIT_ANIMATION_DURATION
	shield_hit_angle = fposmod(animation_time * 2.3 + amount * 0.031, TAU)
	shield_hit_broken = shield <= 0.0 and absorbed > 0.0
	invulnerable = 0.85
	since_damage = 0
	regen_announced = false
	resonance = maxf(0, resonance - 14)
	play_hurt_animation()
	game.audio.play_sfx("hurt")
	game.add_fx(position, Color("ff846f"), 35)
	if shield <= 0 and absorbed > 0:
		game.flash_text("KHIÊN ĐÃ VỠ", Color("ff846f"))
	if game.settings.get("vibration", true) and OS.has_feature("android"):
		Input.vibrate_handheld(65)
	game.screen_shake = 0.18
	if hp <= 0:
		game.end_run(false)

func snapshot() -> Dictionary:
	return {"hp": hp, "shield": shield, "energy": energy, "resonance": resonance}

func restore(snapshot_data: Dictionary) -> void:
	refresh_stats()
	hp = clampf(float(snapshot_data.get("hp", 100)), 1, max_hp)
	shield = clampf(float(snapshot_data.get("shield", max_shield)), 0, max_shield)
	energy = clampf(float(snapshot_data.get("energy", max_energy)), 0, max_energy)
	resonance = clampf(float(snapshot_data.get("resonance", 0)), 0, 100)
	dash_time = 0
	dash_cooldown = 0
	invulnerable = 1.2
	since_damage = 0
	reset_visual_animation()

func _draw() -> void:
	if not pixel_character_enabled:
		draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO)
	if shield > 0.0:
		_draw_shield_model()
	_draw_pulse_animation()
	_draw_shield_hit_animation()
	var tint = Color.WHITE
	if invulnerable > 0 and int(animation_time * 16) % 2 == 0:
		tint.a = 0.45
	var bob: float = 0.0 if pixel_character_enabled else (sin(animation_time * 17) * 2 if move_direction.length_squared() > 0.01 else sin(animation_time * 3) * 0.6)
	if dash_time > 0 and not pixel_character_enabled:
		for i in range(1, 4):
			draw_rect(Rect2(-dash_direction * i * 9 + Vector2(-9, -9), Vector2(18, 20)), Color(0.2, 0.9, 1, 0.15 / i))
	var pose: String = visual_animation()
	var fallback_pose: String = "run_%d" % (int(animation_time * 8) % 2) if pose in ["run", "run_attack"] else pose
	var aim_angle: float = aim_direction.angle()
	var character_angle: float = pixel_character_draw_angle()
	if pixel_character_enabled and pixel_animation_sheets.has(pose):
		draw_set_transform(Vector2.ZERO, character_angle, PIXEL_CHARACTER_SCALE)
		var sheet: Texture2D = pixel_animation_sheets[pose]
		var source_rect := Rect2(pixel_animation_frame * 32, 0, 32, 32)
		draw_texture_rect_region(sheet, Rect2(-15, -16 + bob, 32, 32), source_rect, tint)
		draw_set_transform(Vector2.ZERO)
	elif sprite:
		draw_texture_rect(animation_sprites.get(fallback_pose, sprite), Rect2(-18, -23 + bob, 36, 36), false, tint)
	else:
		draw_rect(Rect2(-10, -16 + bob, 20, 26), Color("35e7ff"))
	draw_set_transform(Vector2(0, 0), aim_angle)
	var weapon_id: String = game.weapons[game.active_slot]
	var weapon_draw_rect: Rect2 = pixel_weapon_draw_rect()
	if weapon_recoil_time > 0.0 and weapon_recoil_sheets.has(weapon_id):
		var recoil_sheet: Texture2D = weapon_recoil_sheets[weapon_id]
		var recoil_frame: int = mini(int((WEAPON_RECOIL_DURATION - weapon_recoil_time) * WEAPON_RECOIL_FPS), 2)
		draw_texture_rect_region(recoil_sheet, weapon_draw_rect, Rect2(recoil_frame * 32, 0, 32, 32), Color.WHITE)
	elif weapon_textures.has(weapon_id):
		draw_texture_rect(weapon_textures[weapon_id], weapon_draw_rect, false)
	else:
		draw_rect(Rect2(-1, 3, 23, 8), Color("e6f7ff"))
	if attack_flash > 0:
		draw_rect(PIXEL_WEAPON_FLASH_RECT, Color("e6f7ff"))
	draw_set_transform(Vector2.ZERO)
	if not pixel_character_enabled:
		draw_circle(Vector2.ZERO, 2, Color("e6f7ff"))

func _draw_shield_model() -> void:
	var shield_ratio: float = clampf(shield / maxf(1.0, max_shield), 0.0, 1.0)
	var active: bool = invulnerable > 0.0 or shield_hit_animation_time > 0.0
	var pulse: float = 0.5 + 0.5 * sin(animation_time * (8.0 if active else 3.5))
	var phase: float = animation_time * (0.72 if active else 0.38)
	var radius: float = 24.0 + pulse * (1.5 if active else 0.8)
	var alpha: float = (0.70 + pulse * 0.18) if active else (0.38 + pulse * 0.10)
	alpha *= 0.52 + shield_ratio * 0.48
	var cyan := Color("35e7ff")
	var bright := Color("b8ffff")
	var deep := Color("146d9b")
	# A very light membrane gives the shield a body without hiding the player art.
	draw_circle(Vector2.ZERO, radius - 1.0, Color(cyan, 0.025 * alpha))
	# Six separated plates make this read as a shield device, instead of one
	# generic circle. The plates rotate slowly and brighten while invulnerable.
	for index in range(6):
		var plate_start: float = phase + float(index) * TAU / 6.0 + 0.08
		var plate_end: float = plate_start + TAU / 6.0 - 0.18
		draw_arc(Vector2.ZERO, radius, plate_start, plate_end, 12,
			Color(cyan, alpha), 2.4 if active else 1.8, true)
		var node_angle: float = (plate_start + plate_end) * 0.5
		var node_direction := Vector2.from_angle(node_angle)
		draw_circle(node_direction * (radius + 0.5), 1.5 if active else 1.1,
			Color(bright, alpha * 0.92))
	# Faceted outer membrane and inner hex core provide a visible model even
	# between damage events, while preserving the circular silhouette at game scale.
	var shell := PackedVector2Array()
	for index in range(8):
		var angle: float = phase * 0.72 + float(index) * TAU / 8.0
		var facet_radius: float = radius - 5.0 + (1.5 if index % 2 == 0 else -0.5)
		shell.append(Vector2.from_angle(angle) * facet_radius)
	# Close the polygon explicitly after constructing the eight facets.
	if shell.size() > 0:
		shell.append(shell[0])
		draw_polyline(shell, Color(bright, alpha * 0.52), 1.0 if not active else 1.4, true)
	var core := PackedVector2Array()
	for index in range(6):
		core.append(Vector2.from_angle(-phase * 1.1 + float(index) * TAU / 6.0) * 13.0)
	if core.size() > 0:
		core.append(core[0])
		draw_polyline(core, Color(deep, alpha * 0.76), 1.0, true)
	for index in range(6):
		var spoke_direction := Vector2.from_angle(-phase * 1.1 + float(index) * TAU / 6.0)
		draw_line(spoke_direction * 7.0, spoke_direction * (radius - 7.0),
			Color(bright, alpha * (0.34 if index % 2 else 0.52)), 1.0, true)
	# Small energy ticks pulse around the membrane and expose low shield charge.
	for index in range(8):
		var tick_angle: float = phase * 1.35 + float(index) * TAU / 8.0
		var tick_direction := Vector2.from_angle(tick_angle)
		var tick_length: float = 4.0 + pulse * 2.0
		draw_line(tick_direction * (radius - 3.0), tick_direction * (radius - 3.0 - tick_length),
			Color(cyan if index % 2 else bright, alpha * 0.72), 1.4, true)

func _draw_pulse_animation() -> void:
	if pulse_animation_time <= 0.0:
		return
	var progress: float = clampf(1.0 - pulse_animation_time / PULSE_ANIMATION_DURATION, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var fade: float = 1.0 - progress * 0.68
	var radius: float = lerpf(12.0, pulse_visual_radius, eased)
	var wave_color := Color("9b4dff")
	var accent := Color("e8c8ff")
	for index in range(3):
		var ring_progress: float = clampf(progress - float(index) * 0.10, 0.0, 1.0)
		var ring_radius: float = lerpf(12.0, radius, ring_progress)
		var ring_alpha: float = maxf(0.0, (0.72 - float(index) * 0.15) * fade)
		draw_arc(Vector2.ZERO, ring_radius, -PI * 0.5 + animation_time * 1.8,
			TAU - PI * 0.5 + animation_time * 1.8, 36, Color(wave_color, ring_alpha),
			3.2 - float(index) * 0.7, true)
	var aura_radius: float = 15.0 + progress * 11.0
	draw_circle(Vector2.ZERO, aura_radius, Color(wave_color, 0.08 * fade))
	for index in range(8):
		var angle: float = animation_time * 2.4 + float(index) * TAU / 8.0
		var direction := Vector2.from_angle(angle)
		var start: Vector2 = direction * (aura_radius + 4.0)
		var finish: Vector2 = direction * (radius + 8.0)
		draw_line(start, finish, Color(accent, 0.55 * fade), 1.5, true)
		draw_circle(finish, 2.0 + progress * 1.5, Color(accent, 0.82 * fade))

func _draw_shield_hit_animation() -> void:
	if shield_hit_animation_time <= 0.0:
		return
	var progress: float = clampf(1.0 - shield_hit_animation_time / SHIELD_HIT_ANIMATION_DURATION, 0.0, 1.0)
	var impact_fade: float = 1.0 - minf(1.0, progress * 1.45)
	var ring_fade: float = 1.0 - progress * 0.72
	var ring_color := Color("ff846f") if shield_hit_broken else Color("35e7ff")
	var impact_color := Color("ff4d6e")
	var accent := Color("fff1b0")
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	var radius: float = lerpf(22.0, 34.0, eased)
	var rotation: float = shield_hit_angle + animation_time * 2.2
	draw_circle(Vector2.ZERO, radius, Color(ring_color, 0.055 * ring_fade))
	draw_arc(Vector2.ZERO, radius, rotation, rotation + TAU * 0.90, 40, Color(ring_color, 0.92 * ring_fade), 2.8, true)
	draw_arc(Vector2.ZERO, radius - 5.0, rotation + PI * 0.18,
		rotation + PI * 1.28, 24, Color("b8ffff", 0.70 * ring_fade), 1.3, true)
	var impact_direction := Vector2.from_angle(shield_hit_angle)
	var impact_center: Vector2 = impact_direction * (14.0 + progress * 4.0)
	draw_circle(impact_center, 6.0 + impact_fade * 5.0, Color(impact_color, 0.12 * impact_fade))
	draw_arc(impact_center, 7.0 + impact_fade * 4.0, rotation, rotation + TAU * 0.82,
		20, Color(impact_color, 0.9 * impact_fade), 2.0, true)
	for index in range(8):
		var fragment_angle: float = shield_hit_angle + (float(index) - 3.5) * 0.27 + progress * 0.75
		var fragment_direction := Vector2.from_angle(fragment_angle)
		var start: Vector2 = impact_center + fragment_direction * (5.0 + progress * 2.0)
		var finish: Vector2 = impact_center + fragment_direction * (13.0 + impact_fade * 13.0)
		draw_line(start, finish, Color(accent if index % 3 == 0 else impact_color, 0.86 * impact_fade), 1.8, true)
		draw_circle(finish, 1.5 + impact_fade * 1.8, Color(accent, 0.9 * impact_fade))
	var normal := impact_direction.orthogonal()
	draw_line(impact_center - normal * (4.0 + impact_fade * 4.0),
		impact_center + normal * (4.0 + impact_fade * 4.0), Color(accent, 0.86 * impact_fade), 1.6, true)
