extends SceneTree
## Confirms every support room resolves a loadable, distinct visual chest while
## retaining the existing non-purchased support interaction.

const MainScene = preload("res://scenes/main.tscn")
const CHESTS: Array[Texture2D] = [
	preload("res://assets/props/support_chests/echo_terminal_support_chest_v1.png"),
	preload("res://assets/props/support_chests/bass_foundry_support_chest_v1.png"),
	preload("res://assets/props/support_chests/luminous_grove_support_chest_v1.png"),
	preload("res://assets/props/support_chests/prism_spire_support_chest_v1.png"),
	preload("res://assets/props/support_chests/silent_core_support_chest_v1.png"),
]

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
	for stage in range(CHESTS.size()):
		game.start_debug_stage(stage)
		game.travel(4)
		var expected: Texture2D = CHESTS[stage]
		var resolved: Texture2D = game.room_view.support_chest_texture()
		_check(game.room_index == 4, "Area %d debug tour enters its support room" % (stage + 1))
		_check(resolved == expected, "Area %d resolves its own support chest texture" % (stage + 1))
		_check(resolved.get_width() >= 1000 and resolved.get_height() >= 1000, "Area %d support chest remains a high-resolution source asset" % (stage + 1))
		# Debug-map tours intentionally mark every support reward as claimed. Restore
		# only this fixture flag so the normal first-visit interaction can be checked.
		game.support_purchased = false
		game.player.position = game.support_station_position()
		_check(game.interaction_label() == "E · Mở hòm hỗ trợ", "Area %d exposes the chest interaction without changing its support room" % (stage + 1))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("SUPPORT CHEST VISUAL PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SUPPORT CHEST VISUAL FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
