extends SceneTree
## Focused contract for combat-gate state.  This does not pretend to be a PC or
## Android visual test; it verifies the same route/combat state RoomView draws.

const MainScene = preload("res://scenes/main.tscn")
const RoomView = preload("res://scripts/world/room_view.gd")

var failures: Array[String] = []
var checks := 0
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	_check(is_equal_approx(RoomView.COMBAT_BARRIER_STROKE_WIDTH, RoomView.MAP_BOUNDARY_STROKE_WIDTH), "Combat-gate model uses the same maximum stroke width as the map collision boundary")
	for stage in range(5):
		game.new_run(730001 + stage)
		game.stage_index = stage
		game.graph = game.GraphScript.generate(game.seed_value, stage)
		game.set_stage_music()
		game.enter_room(0)
		var authored_gate_count: int = int(game.route_barriers_art.size())
		_check(authored_gate_count > 0, "Area %d has authored corridor gates to activate during combat" % (stage + 1))
		var first_gates: Array[Rect2] = game.active_combat_barrier_rects()
		_check(game.combat_active and first_gates.size() == authored_gate_count, "Area %d Combat 1 activates every authored map barrier while enemies remain" % (stage + 1))
		for gate in first_gates:
			_check(game.arena.encloses(gate), "Area %d active gate remains inside the authored world bounds" % (stage + 1))
		game.combat_active = false
		_check(game.active_combat_barrier_rects().is_empty(), "Area %d hides all corridor gates when the encounter is complete" % (stage + 1))
		game.cleared = [0]
		game.enter_room(1)
		var middle_gates: Array[Rect2] = game.active_combat_barrier_rects()
		_check(game.combat_active and middle_gates.size() == authored_gate_count, "Area %d Combat 2 keeps every authored map barrier active" % (stage + 1))
		game.cleared = [0, 1]
		game.enter_room(2)
		var room_three_gates: Array[Rect2] = game.active_combat_barrier_rects()
		_check(game.combat_active and room_three_gates.size() == authored_gate_count, "Area %d Combat 3 keeps every authored map barrier visible, including gates from earlier rooms" % (stage + 1))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CORRIDOR BARRIERS: 0 failures (%d checks)" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CORRIDOR BARRIERS: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
