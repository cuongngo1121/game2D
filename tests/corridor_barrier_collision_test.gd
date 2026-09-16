extends SceneTree
## A visible combat gate must also be a physical movement blocker.  Area 1's
## boss route is the critical case because its boss polygon includes the long
## approach corridor for exploration and would otherwise allow a walk-through.

const MainScene = preload("res://scenes/main.tscn")

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
	_prepare_area_one_boss_combat()
	var gates: Array[Rect2] = game.active_combat_barrier_rects()
	_check(game.combat_active and not gates.is_empty(), "Area 1 boss combat activates its authored corridor gate")
	if not gates.is_empty():
		var gate: Rect2 = gates[0]
		var normal := Vector2.RIGHT if gate.size.x < gate.size.y else Vector2.DOWN
		# Use a wide legal floor around the real authored gate.  This isolates the
		# gate collider from nearby boss-room polygon walls: without gate physics,
		# this movement necessarily crosses from one side of the red bar to the other.
		var fixture_rect := Rect2(gate.get_center() - Vector2(180, 180), Vector2(360, 360))
		var fixture_floor := PackedVector2Array([
			fixture_rect.position,
			Vector2(fixture_rect.end.x, fixture_rect.position.y),
			fixture_rect.end,
			Vector2(fixture_rect.position.x, fixture_rect.end.y),
		])
		var fixture_polygons: Array[PackedVector2Array] = [fixture_floor]
		var chamber_start: Vector2 = gate.get_center() - normal * 96.0
		var start_side := _barrier_side(chamber_start, gate, normal)
		var after_move: Vector2 = game._move_actor_in_polygons(chamber_start, normal * 192.0, game.player.radius, fixture_polygons)
		var end_side := _barrier_side(after_move, gate, normal)
		_check(signf(end_side) == signf(start_side) and absf(end_side) >= game.player.radius, "Area 1 boss combat cannot move the player through its active corridor gate")
		game.combat_active = false
		var after_clear: Vector2 = game._move_actor_in_polygons(chamber_start, normal * 192.0, game.player.radius, fixture_polygons)
		_check(signf(_barrier_side(after_clear, gate, normal)) != signf(start_side), "Area 1 boss corridor gate stops blocking immediately after combat clears")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CORRIDOR BARRIER COLLISION PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CORRIDOR BARRIER COLLISION FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _prepare_area_one_boss_combat() -> void:
	game.new_run(881155)
	game.stage_index = 0
	game.graph = game.GraphScript.generate(game.seed_value, 0)
	game.set_stage_music()
	game.cleared = [0, 1, 2, 3]
	game.enter_room(5)
	game.player.position = game.boss_spawn_position()

func _barrier_side(point: Vector2, gate: Rect2, normal: Vector2) -> float:
	return (point - gate.get_center()).dot(normal)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
