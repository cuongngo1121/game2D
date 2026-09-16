extends SceneTree
## Focused LV5 route regression: source-topology unlocks, revisits, combat locks
## and the native-coordinate Boundary Editor must stay aligned to one HD atlas.

const MainScene = preload("res://scenes/main.tscn")
const LevelFiveBoundaryData = preload("res://scripts/world/level_five_boundary_data.gd")
const LEVEL_FIVE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png")

var game
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.state = "playing"
	game.stage_index = 4
	game.cleared.clear()
	game.rewarded.clear()
	game.combat_active = false
	game.graph = game.GraphScript.generate(12805, 4)
	game.enter_room(0)
	# The route assertions below model exploration between encounters. enter_room
	# starts Combat 1 in a normal run, so release that combat-only movement lock
	# before checking the authored post-clear progression states.
	game.combat_active = false

	_check(game.is_open_route_stage(), "LV5 uses the open-route movement model")
	_check(game.graph.branch == 3, "LV5 Support is authored from Combat 4")
	_check(game.arena.size == Vector2(4344, 3258), "LV5 world is 50% larger than its former 2896 x 2172 layout")
	_check(game.level_five_art_scale() == Vector2(3, 3), "LV5 art and collision share a 3x transform")
	_check(LEVEL_FIVE_ROUTE_BACKDROP.get_size() == Vector2(5792, 4344), "LV5 runtime backdrop preserves the supplied 4x-native atlas")
	_check(game.walkable_polygons.size() == 1 and game.is_route_room_open(0), "LV5 starts with Combat 1 only")
	_check(not game.is_route_room_open(1) and not game.is_route_room_open(4) and not game.is_route_room_open(5), "LV5 keeps later rooms closed at run start")

	var radius := 11.0
	var entries := {
		0: Vector2(168, 895), 1: Vector2(482, 670), 2: Vector2(842, 574),
		3: Vector2(905, 262), 4: Vector2(630, 260), 5: Vector2(1265, 262),
	}
	for room in entries:
		game.room_index = int(room)
		_check(game.is_combat_position(game.level_five_art_to_world_point(entries[room]), radius), "LV5 room %d entry stays inside its own floor" % (int(room) + 1))
	game.room_index = 0
	_check(not game.is_walkable_position(game.level_five_art_to_world_point(Vector2(420, 300)), radius), "LV5 black void cannot be walked")

	game.cleared = [0]
	game.configure_map_layout()
	_check(game.is_route_room_open(1) and not game.is_route_room_open(2), "Clearing Combat 1 opens Combat 2 only")
	game.cleared = [0, 1]
	game.configure_map_layout()
	_check(game.is_route_room_open(2) and not game.is_route_room_open(3) and not game.is_route_room_open(4), "Clearing Combat 2 opens Combat 3, not the distant Support branch")
	game.cleared = [0, 1, 2]
	game.configure_map_layout()
	_check(game.is_route_room_open(3) and not game.is_route_room_open(4) and not game.is_route_room_open(5), "Clearing Combat 3 opens Combat 4 only")
	game.cleared = [0, 1, 2, 3]
	game.configure_map_layout()
	_check(game.is_route_room_open(4) and game.is_route_room_open(5), "Clearing Combat 4 opens both its Support branch and Boss")
	_check(game.is_walkable_position(game.level_five_art_to_world_point(entries[0]), radius), "Completed Combat 1 remains revisitable")
	_check(game.is_walkable_position(game.level_five_art_to_world_point(entries[4]), radius), "Opened LV5 Support is reachable from the shared route")

	game.room_index = 3
	game.combat_active = true
	_check(not game.is_walkable_position(game.level_five_art_to_world_point(entries[4]), radius), "Combat 4 seals the Support doorway")
	_check(not game.is_walkable_position(game.level_five_art_to_world_point(entries[5]), radius), "Combat 4 seals the Boss doorway")
	game.room_index = 5
	_check(not game.is_walkable_position(game.level_five_art_to_world_point(entries[3]), radius), "Boss combat cannot leave the Boss room")
	game.combat_active = false

	game.boundary_editor.open()
	_check(game.boundary_editor.boundary_data == LevelFiveBoundaryData, "Boundary Editor selects native LV5 polygon data")
	_check(game.boundary_editor.background == LEVEL_FIVE_ROUTE_BACKDROP, "Boundary Editor displays the same LV5 HD atlas as gameplay")
	_check(game.boundary_editor.boundary_data.ART_SIZE == Vector2(1448, 1086), "Boundary Editor keeps LV5 vertices in native art space")
	game.boundary_editor.request_close()

	game.queue_free()
	await process_frame
	# Boundary Editor releases its temporary controls through deferred frees.
	# Allow the second pass before ending headless execution so shutdown residue
	# cannot turn an otherwise clean assertion run into a non-zero process exit.
	await process_frame
	if failures.is_empty():
		print("SILENT CORE ROUTE: 0 failures")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SILENT CORE ROUTE: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition and not failures.has(description):
		failures.append(description)
