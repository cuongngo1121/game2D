extends SceneTree
## Protects the LV1 authoring format and the editor's safe discard flow.

const BoundaryData = preload("res://scripts/world/level_one_boundary_data.gd")
const LevelTwoBoundaryData = preload("res://scripts/world/level_two_boundary_data.gd")
const LevelThreeBoundaryData = preload("res://scripts/world/level_three_boundary_data.gd")
const LevelFourBoundaryData = preload("res://scripts/world/level_four_boundary_data.gd")
const LevelFiveBoundaryData = preload("res://scripts/world/level_five_boundary_data.gd")
const CorridorBarrierData = preload("res://scripts/world/corridor_barrier_data.gd")
const MainScene = preload("res://scenes/main.tscn")

var failures: Array[String] = []
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var polygons := BoundaryData.load_room_art_polygons()
	_check(BoundaryData.validate_room_art_polygons(polygons).get("ok", false), "LV1 boundary JSON contains six valid, non-self-intersecting polygons")
	_check(polygons.size() == BoundaryData.ROOM_COUNT, "LV1 boundary data defines every room including support and boss")
	for room in range(BoundaryData.ROOM_COUNT):
		_check(polygons[room].size() >= 3, "%s has a closed polygon with at least three vertices" % BoundaryData.ROOM_NAMES[room])
	var level_two_polygons := LevelTwoBoundaryData.load_room_art_polygons()
	_check(LevelTwoBoundaryData.validate_room_art_polygons(level_two_polygons).get("ok", false), "LV2 boundary JSON contains six valid, non-self-intersecting polygons")
	_check(level_two_polygons.size() == LevelTwoBoundaryData.ROOM_COUNT, "LV2 boundary data defines every room including support and boss")
	var level_three_polygons := LevelThreeBoundaryData.load_room_art_polygons()
	_check(LevelThreeBoundaryData.validate_room_art_polygons(level_three_polygons).get("ok", false), "LV3 boundary JSON contains six valid, non-self-intersecting polygons")
	_check(level_three_polygons.size() == LevelThreeBoundaryData.ROOM_COUNT, "LV3 boundary data defines every room including support and boss")
	var level_four_polygons := LevelFourBoundaryData.load_room_art_polygons()
	_check(LevelFourBoundaryData.validate_room_art_polygons(level_four_polygons).get("ok", false), "LV4 boundary JSON contains six valid, non-self-intersecting polygons")
	_check(level_four_polygons.size() == LevelFourBoundaryData.ROOM_COUNT, "LV4 boundary data defines every room including support and boss")
	var level_five_polygons := LevelFiveBoundaryData.load_room_art_polygons()
	_check(LevelFiveBoundaryData.validate_room_art_polygons(level_five_polygons).get("ok", false), "LV5 boundary JSON contains six valid, non-self-intersecting polygons")
	_check(level_five_polygons.size() == LevelFiveBoundaryData.ROOM_COUNT, "LV5 boundary data defines every room including support and boss")
	var default_gates := CorridorBarrierData.default_stage_art_barriers(0, polygons, BoundaryData.ART_SIZE)
	_check(CorridorBarrierData.validate_stage_art_barriers(default_gates, BoundaryData.ART_SIZE).get("ok", false), "Derived default combat gates stay in native-map bounds and name valid rooms")
	_check(default_gates.size() >= 4, "The default route derives combat gates at its connected room corridors")
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var before: Dictionary = BoundaryData.duplicate_room_art_polygons(game.level_one_art_polygons)
	game.ensure_route_combat_barriers()
	var before_barriers: Array[Dictionary] = CorridorBarrierData.duplicate_stage_art_barriers(game.route_barriers_art)
	game.boundary_editor.open()
	_check(game.boundary_editor.active and game.state == "boundary_editing", "F6 editor mode blocks gameplay while boundaries are edited")
	_check(not game.ui.hud.visible, "Boundary editor hides the gameplay HUD so the map remains readable")
	game.boundary_editor.map_rect = game.boundary_editor._map_fit_rect()
	_check(game.boundary_editor.snap_art_point(Vector2(101.0, 205.0)) == Vector2(104, 208), "Default snap quantizes a pointer coordinate to the nearest eight-pixel grid point")
	game.boundary_editor.set_snap_step(2)
	_check(game.boundary_editor.snap_art_point(Vector2(101.0, 205.0)) == Vector2(102, 206), "Two-pixel snap permits vertices half as far apart as the former four-pixel minimum")
	game.boundary_editor.zoom_at(game.boundary_editor.map_rect.get_center(), 1.25)
	game.boundary_editor.panning = true
	game.boundary_editor.pan_start_screen = game.boundary_editor.map_rect.get_center()
	game.boundary_editor.pan_start_center_art = game.boundary_editor.view_center_art
	game.boundary_editor.pan_to(game.boundary_editor.map_rect.get_center() + Vector2(80, 0))
	game.boundary_editor.panning = false
	game.boundary_editor.selected_room = 3
	var last_view_center: Vector2 = game.boundary_editor.view_center_art
	game.boundary_editor.request_close()
	_check(not game.boundary_editor.active and game.state == "menu", "F6 close exits a clean boundary editor session")
	game.boundary_editor.open()
	_check(game.boundary_editor.snap_step == 2 and game.boundary_editor.selected_room == 3, "Reopening the Boundary Editor keeps the last two-pixel snap setting and selected room")
	_check(game.boundary_editor.zoom_scale == 1.25 and game.boundary_editor.view_center_art == last_view_center, "Reopening the Boundary Editor keeps the last zoom and pan view")
	game.boundary_editor.reset_view()
	game.boundary_editor.selected_room = 0
	game.boundary_editor.set_snap_step(16)
	_check(game.boundary_editor.snap_art_point(Vector2(101.0, 205.0)) == Vector2(96, 208), "Selected sixteen-pixel grid changes the exact discrete coordinate used by a point")
	var editable_polygon: PackedVector2Array = game.boundary_editor.working_polygons[0]
	var first_point: Vector2 = game.boundary_editor.snap_art_point(editable_polygon[0])
	editable_polygon[0] = first_point
	game.boundary_editor.working_polygons[0] = editable_polygon
	game.boundary_editor.selected_vertex = 0
	game.boundary_editor.nudge_selected_vertex(Vector2.RIGHT)
	_check(game.boundary_editor.working_polygons[0][0] == first_point + Vector2(16, 0), "Arrow nudge moves the selected vertex by exactly one configured grid step")
	var visible_before: Rect2 = game.boundary_editor._visible_art_rect()
	game.boundary_editor.zoom_at(game.boundary_editor.map_rect.get_center(), 1.25)
	_check(game.boundary_editor.zoom_scale == 1.25 and game.boundary_editor._visible_art_rect().size.x < visible_before.size.x, "Zoom-in reduces the authored art area shown in the editor viewport")
	var center_before_pan: Vector2 = game.boundary_editor.view_center_art
	game.boundary_editor.panning = true
	game.boundary_editor.pan_start_screen = game.boundary_editor.map_rect.get_center()
	game.boundary_editor.pan_start_center_art = center_before_pan
	game.boundary_editor.pan_to(game.boundary_editor.map_rect.get_center() + Vector2(100, 0))
	_check(game.boundary_editor.view_center_art.x < center_before_pan.x, "Middle-mouse pan translates the zoomed viewport through the background")
	game.boundary_editor.panning = false
	game.boundary_editor.reset_view()
	_check(game.boundary_editor.zoom_scale == 1.0 and game.boundary_editor.view_center_art == BoundaryData.ART_SIZE * 0.5, "One-to-one view reset restores the full native image")
	game.boundary_editor.toggle_edit_mode()
	_check(game.boundary_editor.is_barrier_mode(), "Boundary Editor switches to an explicit combat-gate placement mode without changing collision polygons")
	var barrier_count: int = game.boundary_editor.working_barriers.size()
	var gate_start: Vector2 = game.boundary_editor._art_to_screen(Vector2(120, 690))
	var gate_end: Vector2 = game.boundary_editor._art_to_screen(Vector2(144, 754))
	game.boundary_editor.begin_barrier_draw(gate_start)
	game.boundary_editor.update_barrier_preview(gate_end)
	game.boundary_editor.finish_barrier_draw()
	_check(game.boundary_editor.working_barriers.size() == barrier_count + 1 and game.boundary_editor.working_barriers.back().rooms.has(0), "Dragging in gate mode creates a snapped Combat 1 corridor-gate model")
	game.boundary_editor.remove_barrier_at((gate_start + gate_end) * 0.5)
	_check(game.boundary_editor.working_barriers.size() == barrier_count, "Right-click removal deletes the selected drawn combat-gate model")
	# A designer draws the barrier itself as one line on the room threshold.  The
	# editor must give that line its invisible authoring thickness, then attach it
	# to both rooms whose shared edge it crosses.  The two squares meet exactly at
	# y=96: a point-in-polygon centre test cannot express this user interaction.
	var live_polygons: Dictionary = game.boundary_editor.working_polygons
	game.boundary_editor.working_polygons = {
		0: PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 96), Vector2(0, 96)]),
		1: PackedVector2Array([Vector2(0, 96), Vector2(200, 96), Vector2(200, 200), Vector2(0, 200)]),
	}
	game.boundary_editor.selected_room = 0
	var shared_barrier_count: int = game.boundary_editor.working_barriers.size()
	var shared_start_screen: Vector2 = game.boundary_editor._art_to_screen(Vector2(32, 96))
	var shared_end_screen: Vector2 = game.boundary_editor._art_to_screen(Vector2(168, 96))
	game.boundary_editor.begin_barrier_draw(shared_start_screen)
	game.boundary_editor.update_barrier_preview(shared_end_screen)
	game.boundary_editor.finish_barrier_draw()
	_check(game.boundary_editor.working_barriers.size() == shared_barrier_count + 1, "A one-dimensional drag on a room boundary creates a valid corridor gate")
	if game.boundary_editor.working_barriers.size() == shared_barrier_count + 1:
		var authored_shared_gate: Dictionary = game.boundary_editor.working_barriers.back()
		var authored_shared_rect: Rect2 = authored_shared_gate.get("rect", Rect2())
		_check(authored_shared_rect.size.x >= CorridorBarrierData.MIN_GATE_SIDE and authored_shared_rect.size.y >= CorridorBarrierData.MIN_GATE_SIDE, "A one-dimensional drag on a room boundary receives a valid invisible authoring thickness")
		_check(authored_shared_gate.get("rooms", []) == [0, 1], "A one-dimensional drag on a shared room boundary links the corridor gate to both adjacent rooms")
		game.boundary_editor.working_barriers.remove_at(shared_barrier_count)
	game.boundary_editor.working_polygons = live_polygons
	game.boundary_editor.toggle_edit_mode()
	_check(not game.boundary_editor.is_barrier_mode(), "Boundary Editor returns to normal polygon tracing without closing F6")
	var self_intersecting := PackedVector2Array([
		Vector2(240, 620), Vector2(420, 800), Vector2(240, 800), Vector2(420, 620)])
	_check(not BoundaryData.validate_polygon(self_intersecting).get("ok", true), "Self-intersecting tracing fixture is rejected by boundary validation")
	game.boundary_editor.working_polygons[0] = self_intersecting
	game.boundary_editor.queue_redraw()
	await process_frame
	game.boundary_editor.clear_selected_room()
	_check(not game.boundary_editor.working_polygons[0].is_empty(), "First clear request asks for confirmation and keeps the polygon")
	game.boundary_editor.clear_selected_room()
	_check(game.boundary_editor.working_polygons[0].is_empty(), "Second clear request intentionally removes the selected room's vertices")
	game.boundary_editor.request_close()
	game.boundary_editor.request_close()
	_check(not game.boundary_editor.active and game.state == "menu", "Closing dirty editor twice exits without leaving an editor state behind")
	_check(game.level_one_art_polygons == before, "Closing without save restores the last persisted boundaries instead of losing a playable map")
	_check(game.route_barriers_art == before_barriers, "Closing without save restores the last persisted corridor gates independently from collision boundaries")
	game.start_debug_stage(1)
	var before_level_two: Dictionary = LevelTwoBoundaryData.duplicate_room_art_polygons(game.level_two_art_polygons)
	game.boundary_editor.open()
	_check(game.boundary_editor.active and game.boundary_editor.edited_stage == 1, "F6 opens the matching Bass Foundry boundary editor while Area 2 is active")
	_check(game.boundary_editor.boundary_data == LevelTwoBoundaryData and game.boundary_editor.snap_step == 16, "Area 2 editor selects LV2 data while preserving the prior discrete snap setting")
	_check(game.boundary_editor.view_center_art == LevelTwoBoundaryData.ART_SIZE * 0.5, "Switching route maps resets the editor viewport to the Area 2 native image centre")
	game.boundary_editor.request_close()
	_check(game.level_two_art_polygons == before_level_two, "Closing the clean Area 2 editor leaves its persisted boundaries intact")
	game.start_debug_stage(2)
	var before_level_three: Dictionary = LevelThreeBoundaryData.duplicate_room_art_polygons(game.level_three_art_polygons)
	game.boundary_editor.open()
	_check(game.boundary_editor.active and game.boundary_editor.edited_stage == 2, "F6 opens the matching Luminous Grove boundary editor while Area 3 is active")
	_check(game.boundary_editor.boundary_data == LevelThreeBoundaryData and game.boundary_editor.snap_step == 16, "Area 3 editor selects LV3 data while preserving the prior discrete snap setting")
	_check(game.boundary_editor.view_center_art == LevelThreeBoundaryData.ART_SIZE * 0.5, "Switching route maps resets the editor viewport to the Area 3 native image centre")
	game.boundary_editor.request_close()
	_check(game.level_three_art_polygons == before_level_three, "Closing the clean Area 3 editor leaves its persisted boundaries intact")
	game.start_debug_stage(3)
	var before_level_four: Dictionary = LevelFourBoundaryData.duplicate_room_art_polygons(game.level_four_art_polygons)
	_check(game.arena.size == Vector2(4344, 3258) and game.level_four_art_scale() == Vector2(3, 3), "Area 4 debug route uses the enlarged uniform 3x art-to-world transform")
	game.boundary_editor.open()
	_check(game.boundary_editor.active and game.boundary_editor.edited_stage == 3, "F6 opens the matching Prism Spire boundary editor while Area 4 is active")
	_check(game.boundary_editor.boundary_data == LevelFourBoundaryData and game.boundary_editor.snap_step == 16, "Area 4 editor selects LV4 data while preserving the prior discrete snap setting")
	_check(game.boundary_editor.view_center_art == LevelFourBoundaryData.ART_SIZE * 0.5, "Switching route maps resets the editor viewport to the Area 4 native image centre")
	game.boundary_editor.request_close()
	_check(game.level_four_art_polygons == before_level_four, "Closing the clean Area 4 editor leaves its persisted boundaries intact")
	game.start_debug_stage(4)
	var before_level_five: Dictionary = LevelFiveBoundaryData.duplicate_room_art_polygons(game.level_five_art_polygons)
	_check(game.arena.size == Vector2(4344, 3258) and game.level_five_art_scale() == Vector2(3, 3), "Area 5 debug route uses the enlarged uniform 3x art-to-world transform")
	game.boundary_editor.open()
	_check(game.boundary_editor.active and game.boundary_editor.edited_stage == 4, "F6 opens the matching Silent Core boundary editor while Area 5 is active")
	_check(game.boundary_editor.boundary_data == LevelFiveBoundaryData and game.boundary_editor.snap_step == 16, "Area 5 editor selects LV5 data while preserving the prior discrete snap setting")
	_check(game.boundary_editor.view_center_art == LevelFiveBoundaryData.ART_SIZE * 0.5, "Switching route maps resets the editor viewport to the Area 5 native image centre")
	_check(game.boundary_editor.background.get_size() == Vector2(5792, 4344), "Area 5 editor displays the supplied 4x-native route atlas")
	game.boundary_editor.request_close()
	_check(game.level_five_art_polygons == before_level_five, "Closing the clean Area 5 editor leaves its persisted boundaries intact")
	game.queue_free()
	await process_frame
	# The editor closes UI controls through deferred frees.  Give that second
	# deferred pass a frame before quitting the headless SceneTree so the test
	# runner can report its real assertion status instead of shutdown residue.
	await process_frame
	if failures.is_empty():
		print("MAP BOUNDARY EDITOR: 0 failures")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP BOUNDARY EDITOR: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition and not failures.has(description):
		failures.append(description)
