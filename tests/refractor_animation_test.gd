extends SceneTree
## Asset and runtime-loader coverage for the Zone 4 REFACTOR boss animation set.

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
	_check(game.enemies.BOSS_ANIMATION_IDS.get("boss3", "") == "refractor", "EnemySystem maps the Zone 4 boss to the REFACTOR animation package")
	for animation_name in ANIMATION_CONFIG:
		var config: Dictionary = ANIMATION_CONFIG[animation_name]
		var frame_count: int = int(config.frames)
		var path := "res://assets/sprites/pixel_64/bosses/refractor/animations/refractor_%s_%dx64.png" % [animation_name, frame_count]
		_check(ResourceLoader.exists(path), "REFACTOR %s spritesheet is imported" % animation_name)
		var texture: Texture2D = load(path)
		_check(texture != null and texture.get_width() == frame_count * 64 and texture.get_height() == 64, "REFACTOR %s sheet has %d native 64px frames" % [animation_name, frame_count])
		_check(game.enemies._boss_animation_textures.has("boss3:%s" % animation_name), "EnemySystem preloads REFACTOR %s for runtime rendering" % animation_name)
	game.stage_index = 3
	game.configure_map_layout()
	game.room_index = 5
	game.combat_active = true
	game.enemies.spawn_room(3, 5, true, 410409)
	_check(game.enemies.units.size() == 1 and game.enemies.units[0].kind == "boss3", "Zone 4 creates the expected REFACTOR boss unit")
	if not game.enemies.units.is_empty():
		var boss: Dictionary = game.enemies.units[0]
		for animation_name in ANIMATION_CONFIG:
			boss.anim_state = animation_name
			boss.anim_elapsed = 0.0
			_check(game.enemies._boss_animation_textures.has("%s:%s" % [boss.kind, animation_name]), "REFACTOR can select its %s visual state" % animation_name)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("REFACTOR ANIMATION PASS: %d checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("REFACTOR ANIMATION FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
