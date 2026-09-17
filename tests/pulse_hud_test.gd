extends SceneTree
## Pulse HUD contract: the short cyan gauge follows the custom Pulse button,
## mirrors Resonance, and keeps the action unavailable until the meter is full.

const MainScene = preload("res://scenes/main.tscn")
const PULSE_BAR_SIZE := Vector2(72.0, 5.0)
const PULSE_BAR_GAP := 4.0
const CYAN := Color("35e7ff")

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
	game.set_process(false)
	game.set_physics_process(false)
	game.controls.set_process(false)
	game.profile = game.store.default_profile()
	game.settings = game.profile.settings
	game.new_run(482901, true, false, false)
	await _frames(2)

	var resonance_bar: ProgressBar = game.ui.bars.get("resonance")
	_check(resonance_bar != null, "Gameplay HUD creates a dedicated Resonance bar")
	if resonance_bar != null:
		_check(resonance_bar.size == PULSE_BAR_SIZE and _resonance_bar_is_below_pulse(resonance_bar), "Resonance bar uses the short authored rectangle below the saved Pulse transform")
		var fill_style: StyleBoxFlat = resonance_bar.get_theme_stylebox("fill") as StyleBoxFlat
		var shield_style: StyleBoxFlat = game.ui.bars.shield.get_theme_stylebox("fill") as StyleBoxFlat
		_check(fill_style != null and shield_style != null and fill_style.bg_color == CYAN and fill_style.bg_color == shield_style.bg_color, "Resonance fill reuses the shield cyan")

	var pulse_center: Vector2 = game.controls.button_centers["pulse"]
	game.player.resonance = 42.0
	game.ui._process(0.0)
	_check(resonance_bar != null and is_equal_approx(resonance_bar.value, 42.0), "Resonance bar follows a partially filled meter")
	_check(game.controls.action_at(pulse_center).is_empty(), "Pulse button stays unavailable below full Resonance")
	game.controls.trigger("pulse")
	_check(is_equal_approx(game.player.resonance, 42.0), "Unavailable Pulse does not consume Resonance")

	game.player.resonance = 100.0
	game.ui._process(0.0)
	_check(resonance_bar != null and is_equal_approx(resonance_bar.value, 100.0), "Resonance bar reaches its full state at 100")
	_check(game.controls.action_at(pulse_center) == "pulse" and game.controls.pulse_ready(), "Pulse button becomes available only at full Resonance")
	game.controls.trigger("pulse")
	_check(is_equal_approx(game.player.resonance, 0.0), "Activated Pulse consumes the full Resonance meter")
	game.ui._process(0.0)
	_check(resonance_bar != null and is_equal_approx(resonance_bar.value, 0.0), "Resonance bar returns to empty after Pulse")

	var pulse_target: Control = game.controls.touch_layout_target("pulse")
	var old_bar_position: Vector2 = resonance_bar.position if resonance_bar != null else Vector2.ZERO
	if pulse_target != null:
		game.controls.apply_touch_layout_transform("pulse", pulse_target.position + Vector2(-75.0, -20.0), pulse_target.scale * 0.9)
		_check(resonance_bar != null and resonance_bar.position != old_bar_position and _resonance_bar_is_below_pulse(resonance_bar), "Moving and resizing Pulse keeps the Resonance bar attached")

	await _frames(1)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PULSE HUD PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PULSE HUD FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _frames(count: int) -> void:
	for _i in range(count):
		await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)


func _resonance_bar_is_below_pulse(resonance_bar: ProgressBar) -> bool:
	if resonance_bar == null:
		return false
	var pulse_target: Control = game.controls.touch_layout_target("pulse")
	if pulse_target == null:
		return false
	var pulse_rect := Rect2(pulse_target.position, pulse_target.size * pulse_target.scale)
	var pulse_center := pulse_rect.get_center()
	var touch_scale := clampf(float(game.settings.get("touch_scale", 1.0)), 0.1, 4.0)
	var pulse_visual_radius := minf(pulse_rect.size.x, pulse_rect.size.y) * 0.5 * touch_scale
	var expected_position := Vector2(pulse_center.x - PULSE_BAR_SIZE.x * 0.5, pulse_center.y + pulse_visual_radius + PULSE_BAR_GAP)
	var maximum_position := Vector2(1280.0, 720.0) - PULSE_BAR_SIZE
	expected_position = Vector2(clampf(expected_position.x, 0.0, maximum_position.x), clampf(expected_position.y, 0.0, maximum_position.y))
	return resonance_bar.position.is_equal_approx(expected_position) and resonance_bar.size == PULSE_BAR_SIZE
