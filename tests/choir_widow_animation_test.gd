extends SceneTree
## Asset and runtime-loader coverage for the Zone 3 CHOIR WIDOW boss animation set.

const MainScene = preload("res://scenes/main.tscn")
const ANIMATION_CONFIG := {
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
	game.set_process(false)
	game.set_physics_process(false)
	game.controls.set_process(false)
	_check(game.enemies.BOSS_ANIMATION_IDS.get("boss2", "") == "choir_widow", "EnemySystem maps the Zone 3 boss to the CHOIR WIDOW animation package")
	for animation_name in ANIMATION_CONFIG:
		var config: Dictionary = ANIMATION_CONFIG[animation_name]
		var frame_count: int = int(config.frames)
		var path := "res://assets/sprites/pixel_64/bosses/choir_widow/animations/choir_widow_%s_%dx64.png" % [animation_name, frame_count]
		_check(ResourceLoader.exists(path), "CHOIR WIDOW %s spritesheet is imported" % animation_name)
		var texture: Texture2D = load(path)
		_check(texture != null and texture.get_width() == frame_count * 64 and texture.get_height() == 64, "CHOIR WIDOW %s sheet has %d native 64px frames" % [animation_name, frame_count])
		_check(game.enemies._boss_animation_textures.has("boss2:%s" % animation_name), "EnemySystem preloads CHOIR WIDOW %s for runtime rendering" % animation_name)
	game.stage_index = 2
	game.configure_map_layout()
	game.room_index = 5
	game.combat_active = true
	game.enemies.spawn_room(2, 5, true, 320307)
	_check(game.enemies.units.size() == 1 and game.enemies.units[0].kind == "boss2", "Zone 3 creates the expected CHOIR WIDOW boss unit")
	if not game.enemies.units.is_empty():
		var boss: Dictionary = game.enemies.units[0]
		for animation_name in ANIMATION_CONFIG:
			boss.anim_state = animation_name
			boss.anim_elapsed = 0.0
			_check(game.enemies._boss_animation_textures.has("%s:%s" % [boss.kind, animation_name]), "CHOIR WIDOW can select its %s visual state" % animation_name)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHOIR WIDOW ANIMATION PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("CHOIR WIDOW ANIMATION FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
