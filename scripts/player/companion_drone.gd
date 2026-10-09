class_name CompanionDrone
extends Node2D

const SPRITE_SIZE := Vector2(48.0, 48.0)
const DRONE_SCALE := Vector2(0.75, 0.75)

const DRONE_CONFIGS := {
	"plasma": {
		"name": "DRONE PLASMA",
		"range": 420.0, "cooldown": 0.65, "damage": 14.0, "bullet_speed": 640.0,
		"accent": Color("35e7ff"),
		"textures": {
			"idle": "res://assets/sprites/drone/combat/Idle.png",
			"forward": "res://assets/sprites/drone/combat/Forward.png",
			"fire1": "res://assets/sprites/drone/combat/Fire1.png",
			"fire2": "res://assets/sprites/drone/combat/Fire2.png",
			"fire3": "res://assets/sprites/drone/combat/Fire3.png",
			"death": "res://assets/sprites/drone/combat/Death.png",
		},
		"anims": {
			"idle": {"frames": 4, "fps": 8.0, "loop": true},
			"forward": {"frames": 4, "fps": 10.0, "loop": true},
			"fire1": {"frames": 16, "fps": 24.0, "loop": false},
			"fire2": {"frames": 16, "fps": 24.0, "loop": false},
			"fire3": {"frames": 16, "fps": 24.0, "loop": false},
			"death": {"frames": 8, "fps": 12.0, "loop": false}
		}
	},
	"scout": {
		"name": "DRONE TRINH SÁT",
		"range": 380.0, "cooldown": 2.2, "damage": 12.0, "bullet_speed": 0.0,
		"accent": Color("ff916d"),
		"textures": {
			"idle": "res://assets/sprites/drone/scout/Idle.png",
			"forward": "res://assets/sprites/drone/scout/Walk.png",
			"fire1": "res://assets/sprites/drone/scout/Scan.png",
			"death": "res://assets/sprites/drone/scout/Death.png",
		},
		"anims": {
			"idle": {"frames": 4, "fps": 8.0, "loop": true},
			"forward": {"frames": 4, "fps": 10.0, "loop": true},
			"fire1": {"frames": 8, "fps": 12.0, "loop": false},
			"death": {"frames": 6, "fps": 10.0, "loop": false}
		}
	},
	"bomb": {
		"name": "DRONE NÉM BOM",
		"range": 360.0, "cooldown": 2.5, "damage": 45.0, "bullet_speed": 0.0,
		"accent": Color("ff4d6d"),
		"textures": {
			"idle": "res://assets/sprites/drone/bomb/Bomb.png",
			"forward": "res://assets/sprites/drone/bomb/Bomb.png",
			"fire1": "res://assets/sprites/drone/bomb/Drop.png",
		},
		"anims": {
			"idle": {"frames": 6, "fps": 6.0, "loop": true},
			"forward": {"frames": 6, "fps": 6.0, "loop": true},
			"fire1": {"frames": 6, "fps": 16.0, "loop": false},
		}
	},
	"laser": {
		"name": "DRONE SENTINEL",
		"range": 320.0, "cooldown": 0.12, "damage": 3.2, "bullet_speed": 0.0,
		"accent": Color("b366ff"),
		"textures": {
			"idle": "res://assets/sprites/drone/laser/Idle.png",
			"forward": "res://assets/sprites/drone/laser/Walk.png",
			"death": "res://assets/sprites/drone/laser/Death.png",
		},
		"anims": {
			"idle": {"frames": 6, "fps": 8.0, "loop": true},
			"forward": {"frames": 4, "fps": 8.0, "loop": true},
		}
	},
	"support": {
		"name": "DRONE HỖ TRỢ",
		"range": 0.0, "cooldown": 3.6, "damage": 0.0, "bullet_speed": 0.0,
		"accent": Color("88ffc9"),
		"textures": {
			"idle": "res://assets/sprites/drone/support/Walk.png",
			"forward": "res://assets/sprites/drone/support/Walk.png",
			"fire1": "res://assets/sprites/drone/support/Drop.png",
		},
		"anims": {
			"idle": {"frames": 4, "fps": 8.0, "loop": true},
			"forward": {"frames": 4, "fps": 8.0, "loop": true},
			"fire1": {"frames": 6, "fps": 10.0, "loop": false},
		}
	}
}

var game
var player
var enabled: bool = true
var drone_type: String = "plasma"

var textures: Dictionary = {}
var current_anim: String = "idle"
var anim_frame: int = 0
var anim_elapsed: float = 0.0
var facing_right: bool = true

var hover_time: float = 0.0
var fire_timer: float = 0.0
var target_pos: Vector2 = Vector2.ZERO
var has_target: bool = false
var target_unit: Dictionary = {}
var current_fire_type: String = "fire1"
var laser_active: bool = false

func setup(owner_game, owner_player) -> void:
	game = owner_game
	player = owner_player
	z_index = 10
	
	_load_textures()
	if player != null:
		position = player.position + Vector2(-32, -28)
	visible = true

func set_drone_type(type_id: String) -> void:
	drone_type = type_id if DRONE_CONFIGS.has(type_id) else "plasma"
	_load_textures()
	reset_position()

func _current_cfg() -> Dictionary:
	return DRONE_CONFIGS.get(drone_type, DRONE_CONFIGS["plasma"])

func _load_textures() -> void:
	textures.clear()
	var cfg := _current_cfg()
	var files: Dictionary = cfg.get("textures", {})
	for anim_name in files:
		var path: String = files[anim_name]
		if ResourceLoader.exists(path):
			textures[anim_name] = load(path)

func update(delta: float) -> void:
	var is_owned: bool = bool(game.has_drone if (game != null and "has_drone" in game) else true)
	if not enabled or not is_owned or player == null or not is_instance_valid(player):
		visible = false
		return
	
	visible = player.visible
	if not visible:
		return
		
	hover_time += delta
	fire_timer = maxf(0.0, fire_timer - delta)
	
	# 1. Update Position & Following
	_update_movement(delta)
	
	# 2. Target Acquisition & Combat
	_update_combat(delta)
	
	# 3. Update Animation Frame
	_update_animation(delta)
	
	queue_redraw()

func _update_movement(delta: float) -> void:
	var desired_offset := Vector2(-30.0, -26.0)
	if player.move_direction.length_squared() > 0.01:
		desired_offset = -player.move_direction.normalized() * 34.0 + Vector2(0.0, -18.0)
	else:
		var float_x := cos(hover_time * 1.8) * 8.0
		var float_y := sin(hover_time * 2.6) * 6.0
		desired_offset += Vector2(float_x, float_y)
		
	var desired_pos: Vector2 = player.position + desired_offset
	var follow_speed: float = 8.5 if player.move_direction.length_squared() > 0.01 else 6.0
	position = position.lerp(desired_pos, clampf(delta * follow_speed, 0.0, 1.0))
	
	if has_target:
		facing_right = (target_pos.x >= position.x)
	elif player.move_direction.length_squared() > 0.01:
		facing_right = (player.move_direction.x >= 0.0)
	elif player.aim_direction.length_squared() > 0.01:
		facing_right = (player.aim_direction.x >= 0.0)

func _update_combat(delta: float) -> void:
	has_target = false
	target_unit = {}
	laser_active = false
	
	if game == null:
		return
	
	# Special Support Drone: heals player periodically without needing enemy target
	if drone_type == "support":
		if fire_timer <= 0.0 and player != null:
			_heal_player()
		return
		
	if game.enemies == null:
		return
		
	var cfg := _current_cfg()
	var attack_range: float = float(cfg.get("range", 420.0))
	var found: Dictionary = game.enemies.nearest_target(position, attack_range)
	if not found.is_empty():
		has_target = true
		target_unit = found
		target_pos = target_unit.pos
		
		if drone_type == "laser":
			laser_active = true
			if fire_timer <= 0.0:
				_fire_laser(delta)
		elif fire_timer <= 0.0:
			_fire_at_target()

func _fire_at_target() -> void:
	var overclock: int = int(game.upgrades.get("drone_overclock", 0)) if (game != null and "upgrades" in game) else 0
	var cfg := _current_cfg()
	var base_cooldown: float = float(cfg.get("cooldown", 0.65))
	var base_damage: float = float(cfg.get("damage", 14.0))
	var current_cooldown: float = maxf(0.24, base_cooldown - overclock * 0.10)
	var current_damage: float = base_damage + overclock * 5.0
	fire_timer = current_cooldown
	
	_play_anim("fire1", true)
	
	match drone_type:
		"plasma":
			var fire_types := ["fire1", "fire2", "fire3"]
			current_fire_type = fire_types[randi() % fire_types.size()] if textures.has("fire2") else "fire1"
			_play_anim(current_fire_type, true)
			
			var aim_dir: Vector2 = (target_pos - position).normalized()
			if aim_dir.length_squared() < 0.001:
				aim_dir = Vector2.RIGHT if facing_right else Vector2.LEFT
				
			var muzzle_offset := Vector2(aim_dir.x * 16.0, aim_dir.y * 12.0)
			var spawn_pos: Vector2 = position + muzzle_offset
			
			if game.projectiles != null:
				game.projectiles.spawn({
					"pos": spawn_pos,
					"vel": aim_dir * float(cfg.get("bullet_speed", 640.0)),
					"damage": current_damage,
					"enemy": false,
					"radius": 4.0,
					"life": 1.2,
					"color": Color("35e7ff"),
					"accent": Color("ffffff"),
					"trail_color": Color("35e7ff", 0.45),
					"visual": "pulse_orb",
					"weapon_id": "drone_plasma",
					"clearable": false
				})
			if game.audio != null:
				game.audio.play_sfx("shoot")
			if game.has_method("add_fx"):
				game.add_fx(spawn_pos, Color("35e7ff"), 18.0)
				
		"scout":
			# Radar scan: marks target and nearby enemies as exposed (+60% damage taken)
			if game.has_method("add_fx"):
				game.add_fx(position, Color("ff916d"), 70.0)
				game.add_fx(target_pos, Color("35e7ff"), 40.0)
			if game.enemies != null:
				for unit in game.enemies.units:
					if unit.pos.distance_to(position) <= float(cfg.get("range", 380.0)):
						unit.exposed = 3.2
						game.enemies.damage_enemy(unit.id, current_damage)
			if game.audio != null:
				game.audio.play_sfx("pulse")
			game.flash_text("📡 RADAR SCAN: MỤC TIÊU LỘ DIỆN (+60% DMG)!", Color("ff916d"))
			
		"bomb":
			# Drops a heavy cluster bomb explosion on the enemy target
			if game.has_method("add_fx"):
				game.add_fx(position, Color("ff4d6d"), 25.0)
				game.add_fx(target_pos, Color("ff4444"), 95.0)
			if game.enemies != null:
				game.enemies.damage_in_radius(target_pos, 90.0, current_damage)
			if game.audio != null:
				game.audio.play_sfx("hit")
			game.screen_shake = maxf(game.screen_shake, 3.5)

func _fire_laser(delta: float) -> void:
	var overclock: int = int(game.upgrades.get("drone_overclock", 0)) if (game != null and "upgrades" in game) else 0
	var cfg := _current_cfg()
	var dmg: float = float(cfg.get("damage", 3.2)) + overclock * 1.2
	fire_timer = 0.12
	if target_unit.has("id"):
		game.enemies.damage_enemy(target_unit.id, dmg)
		if game.has_method("add_fx") and randf() < 0.35:
			game.add_fx(target_pos, Color("b366ff"), 14.0)

func _heal_player() -> void:
	var overclock: int = int(game.upgrades.get("drone_overclock", 0)) if (game != null and "upgrades" in game) else 0
	var heal_amt: float = 14.0 + overclock * 6.0
	fire_timer = 3.6
	_play_anim("fire1", true)
	
	if player != null:
		if player.shield < player.max_shield:
			player.shield = minf(player.max_shield, player.shield + heal_amt)
			game.flash_text("🛡️ DRONE NANO: +%d KHIÊN" % int(heal_amt), Color("88ffc9"))
		else:
			player.hp = minf(player.max_hp, player.hp + 8.0)
			game.flash_text("💚 DRONE NANO: +8 HP", Color("88ffc9"))
			
	if game.audio != null:
		game.audio.play_sfx("pickup")
	if game.has_method("add_fx"):
		game.add_fx(player.position, Color("88ffc9"), 45.0)

func _play_anim(anim_name: String, force_restart: bool = false) -> void:
	if current_anim == anim_name and not force_restart:
		return
	if not textures.has(anim_name) and anim_name != "idle":
		return
	current_anim = anim_name
	anim_frame = 0
	anim_elapsed = 0.0

func _update_animation(delta: float) -> void:
	var cfg := _current_cfg()
	var anim_table: Dictionary = cfg.get("anims", {})
	var anim_info: Dictionary = anim_table.get(current_anim, anim_table.get("idle", {"frames": 4, "fps": 8.0, "loop": true}))
	var total_frames: int = int(anim_info.get("frames", 4))
	var fps: float = float(anim_info.get("fps", 8.0))
	var loop: bool = bool(anim_info.get("loop", true))
	
	anim_elapsed += delta
	var frame_duration: float = 1.0 / maxf(1.0, fps)
	
	if anim_elapsed >= frame_duration:
		anim_elapsed -= frame_duration
		anim_frame += 1
		
		if anim_frame >= total_frames:
			if loop:
				anim_frame = 0
			else:
				anim_frame = total_frames - 1
				var is_moving: bool = position.distance_squared_to(player.position) > 40.0 * 40.0 or player.move_direction.length_squared() > 0.01
				_play_anim("forward" if is_moving else "idle")
	
	if current_anim == "idle" or current_anim == "forward":
		var is_moving: bool = player.move_direction.length_squared() > 0.01 or position.distance_squared_to(player.position) > 45.0 * 45.0
		var desired_anim: String = "forward" if is_moving else "idle"
		if current_anim != desired_anim and textures.has(desired_anim):
			_play_anim(desired_anim)

func reset_position() -> void:
	if player != null:
		position = player.position + Vector2(-32, -28)
	fire_timer = 0.2
	_play_anim("idle")

func _draw() -> void:
	var cfg := _current_cfg()
	var accent: Color = cfg.get("accent", Color("35e7ff"))
	
	# 1. Subtle Thruster Neon Glow underneath
	var hover_pulse := 0.7 + 0.3 * sin(hover_time * 8.0)
	var thruster_pos := Vector2(0.0, 10.0 * DRONE_SCALE.y)
	draw_circle(thruster_pos, 7.0 * hover_pulse, Color(accent.r, accent.g, accent.b, 0.22))
	draw_circle(thruster_pos, 3.5 * hover_pulse, Color("ffffff", 0.45))
	
	# 2. Laser beam if Laser Sentinel Drone is active
	if laser_active and has_target:
		var local_target := to_local(target_pos)
		var beam_pulse := 0.65 + 0.35 * sin(hover_time * 24.0)
		draw_line(Vector2(0, -2), local_target, Color("b366ff", beam_pulse), 3.0, true)
		draw_line(Vector2(0, -2), local_target, Color("ffffff", beam_pulse * 0.9), 1.2, true)
		draw_circle(local_target, 5.0 * beam_pulse, Color("b366ff", 0.8))
	elif has_target and is_instance_valid(game):
		# Subtle lock-on reticle
		var local_target := to_local(target_pos)
		var beam_alpha := 0.15 + 0.10 * sin(hover_time * 16.0)
		draw_line(Vector2(0, -2), local_target, Color(accent.r, accent.g, accent.b, beam_alpha), 1.0, true)
		draw_arc(local_target, 6.0, 0.0, TAU, 12, Color(accent.r, accent.g, accent.b, beam_alpha * 1.5), 1.2, true)
	
	# 3. Draw Drone Sprite Frame
	var tex: Texture2D = textures.get(current_anim, null)
	if tex == null:
		tex = textures.get("idle", null)
	if tex == null:
		draw_circle(Vector2.ZERO, 10.0, accent)
		return
		
	var anim_table: Dictionary = cfg.get("anims", {})
	var anim_info: Dictionary = anim_table.get(current_anim, anim_table.get("idle", {"frames": 4}))
	var total_frames: int = int(anim_info.get("frames", 4))
	var frame_idx: int = clampi(anim_frame, 0, total_frames - 1)
	
	var frame_w: float = float(tex.get_width()) / maxf(1.0, float(total_frames))
	var frame_h: float = float(tex.get_height())
	
	var src_rect := Rect2(frame_idx * frame_w, 0.0, frame_w, frame_h)
	var draw_size := Vector2(frame_w, frame_h) * DRONE_SCALE
	if drone_type == "bomb":
		draw_size = SPRITE_SIZE * DRONE_SCALE
	var dest_rect := Rect2(-draw_size.x * 0.5, -draw_size.y * 0.5, draw_size.x, draw_size.y)
	
	if not facing_right:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(tex, dest_rect, src_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(tex, dest_rect, src_rect)
