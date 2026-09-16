extends SceneTree
## Verifies the first boss resolves every authored 64px animation without
## preserving its attack configuration and stage identity.

const MainScene = preload("res://scenes/main.tscn")
const SHEETS: Dictionary = {
	"idle": preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_idle_4x64.png"),
	"move": preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_move_6x64.png"),
	"attack": preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_attack_4x64.png"),
	"hurt": preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_hurt_3x64.png"),
	"death": preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_death_6x64.png"),
}
const CONFIG: Dictionary = {
	"idle": {"frames": 4, "fps": 6.0},
	"move": {"frames": 6, "fps": 10.0},
	"attack": {"frames": 4, "fps": 12.0},
	"hurt": {"frames": 3, "fps": 10.0},
	"death": {"frames": 6, "fps": 8.0},
}

var game
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.start_debug_stage(0)
	# A debug map deliberately suppresses combat. Disable only that testing mode
	# and its cleared-room list so this fixture can construct the real Area 1
	# boss and its render state.
	game.debug_map_tour = false
	game.cleared.clear()
	game.enter_room(5)
	await process_frame
	_check(game.enemies.units.size() == 1, "Area 1 boss room still creates one combat unit")
	if not game.enemies.units.is_empty():
		var boss: Dictionary = game.enemies.units[0]
		_check(boss.kind == "boss0" and boss.boss, "Area 1 boss keeps the CONDUCTOR-01 gameplay identity")
		_check(boss.radius == game.enemies.BOSS_COLLISION_RADIUS and boss.attack_beats == 6, "150% boss scale updates CONDUCTOR-01 collision radius while preserving beat cadence")
		_check(game.enemies.BOSS_RENDER_SIZE == 120.0, "150% boss scale renders all boss sheets at 120 world pixels")
		for animation_name in CONFIG:
			var config: Dictionary = CONFIG[animation_name]
			var sheet: Texture2D = SHEETS[animation_name]
			_check(sheet.get_width() == int(config.frames) * 64 and sheet.get_height() == 64, "%s sheet has exact 64px frame dimensions" % animation_name)
			_check(game.enemies._boss_animation_textures.get("boss0:%s" % animation_name) == sheet, "%s sheet is loaded by the boss renderer" % animation_name)
			boss.anim_state = animation_name
			boss.anim_elapsed = 0.1
			game.enemies.queue_redraw()
			await process_frame
		boss.spawn_grace = 0.0
		game.enemies.damage_enemy(boss.id, boss.hp + 1.0)
		_check(game.enemies.units.is_empty(), "Defeating CONDUCTOR-01 still removes its combat unit immediately")
		_check(game.enemies._death_animations.size() == 1 and bool(game.enemies._death_animations[0].get("boss", false)), "Defeating CONDUCTOR-01 queues its authored death animation")
		_check(is_equal_approx(game.enemies.clear_animation_delay(), 0.75), "Boss-room clear waits for the full 0.75-second death read")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CONDUCTOR-01 ANIMATION PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CONDUCTOR-01 ANIMATION FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
