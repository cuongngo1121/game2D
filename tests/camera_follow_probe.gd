extends SceneTree
## Regression coverage for direct camera follow and the five-stage branched room layouts.

const MainScene = preload("res://scenes/main.tscn")
const LEVEL_ONE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/echo_terminal_route_background_tiled_restored_hd.png")
const LEVEL_THREE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/luminous_grove_route_background_user_final_fixed_hd_v29.png")
const LEVEL_FOUR_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png")
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
	game.player.visible = true
	game.player.position = Vector2(500, 350)
	game.player.reset_follow_camera()
	game.player.move_direction = Vector2.RIGHT
	await frames(4)
	for i in range(24):
		game.player.position += Vector2(4, 0)
		await process_frame
		var current: Vector2 = game.player.get_global_transform_with_canvas().origin
		_check(current.distance_to(Vector2(640, 360)) <= 0.75, "Camera keeps the moving player centered without follow lag")
	for stage in range(5):
		game.stage_index = stage
		# Each stage is a fresh route. Clear the prior stage's progress so rooms that
		# were deliberately opened by the LV1 checks cannot leak into LV2/LV3.
		game.cleared.clear()
		game.rewarded.clear()
		game.combat_active = false
		game.graph = game.GraphScript.generate(77991, stage)
		game.enter_room(0)
		_check(game.arena.size.x > 1280 and game.arena.size.y > 720, "Stage %d uses a world larger than the viewport" % (stage + 1))
		if stage == 0:
			_check(game.arena.size == Vector2(4320, 2304), "LV1 world is 2.25x its former 1920 x 1024 dimensions")
			var route_texels_per_screen_pixel := minf(
				LEVEL_ONE_ROUTE_BACKDROP.get_width() / (game.arena.size.x * game.player.CAMERA_ZOOM.x),
				LEVEL_ONE_ROUTE_BACKDROP.get_height() / (game.arena.size.y * game.player.CAMERA_ZOOM.y))
			_check(LEVEL_ONE_ROUTE_BACKDROP.get_width() >= 6000 and LEVEL_ONE_ROUTE_BACKDROP.get_height() >= 3200, "LV1 keeps its authored route plate in a high-resolution restored texture")
			_check(route_texels_per_screen_pixel >= 1.0, "LV1 authored route plate stays at or above one source texel per screen pixel at gameplay zoom")
			_check(game.room_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "LV1 route plate avoids final linear-filter haze at gameplay zoom")
			var polygons: Array[PackedVector2Array] = []
			for route_region in game.level_one_route_regions():
				polygons.append(route_region.polygon)
			_check(game.walkable_polygons == game.level_one_room_polygons(0), "Stage 1 starts with only its first combat chamber open")
			# The plate and collision regions use the same native image coordinate
			# system. Test an interior anchor for every room instead of assuming that
			# separately-authored room polygons overlap at every doorway.
			game.cleared = [0, 1, 2, 3]
			game.combat_active = false
			game.configure_map_layout()
			var collision_radius := 11.0
			var room_entry_art := {
				0: Vector2(140, 760), 1: Vector2(560, 610), 2: Vector2(920, 590),
				3: Vector2(1300, 520), 4: Vector2(610, 290), 5: Vector2(1485, 250)}
			for room in room_entry_art:
				game.room_index = int(room)
				var entry: Vector2 = game.level_one_art_to_world_point(room_entry_art[room])
				_check(game.is_combat_position(entry, collision_radius), "LV1 room %d entry remains inside its collision polygon after world scaling" % (int(room) + 1))
			game.room_index = 0
			_check(not game.is_walkable_position(game.level_one_art_to_world_point(Vector2(110, 350)), collision_radius), "LV1 exterior floor remains blocked after world scaling")
			var start: Vector2 = game.level_one_art_to_world_point(Vector2(140, 760))
			var beyond_left_wall: Vector2 = game.level_one_art_to_world_point(Vector2(-200, 760))
			var blocked_left: Vector2 = game.move_actor(start, beyond_left_wall - start, collision_radius)
			# The authored wall begins at art x=82. The stopping point must retain the
			# actor's world-space radius from that exact wall, rather than using the
			# old approximate art x=88 threshold that changed with map scale.
			var left_wall_x: float = game.level_one_art_to_world_point(Vector2(82, 760)).x
			_check(blocked_left.x >= left_wall_x + collision_radius - 1.0, "LV1 movement cannot escape through the left wall of Combat 1")
			_check(polygons.size() >= 5, "Stage %d contains multiple connected floor shapes" % (stage + 1))
		elif stage <= 4:
			_check(game.walkable_polygons.size() == 1, "Stage %d starts with only its first connected floor polygon open" % (stage + 1))
			if stage == 1:
				_check(game.arena.size == Vector2(2896, 2172), "LV2 keeps its authored 2896 x 2172 route world")
				_check(game.level_two_art_scale() == Vector2(2, 2), "LV2 art, wall collisions and spawn points share a uniform 2x transform")
			elif stage == 2:
				_check(game.arena.size == Vector2(4344, 3258), "LV3 route world is 50% larger than its former 2896 x 2172 layout")
				_check(game.level_three_art_scale() == Vector2(3, 3), "LV3 art, wall collisions and spawn points share a uniform 3x transform")
				_check(LEVEL_THREE_ROUTE_BACKDROP.get_width() >= 5120 and LEVEL_THREE_ROUTE_BACKDROP.get_height() >= 3840, "LV3 keeps its restored high-resolution route texture")
				_check(game.room_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "LV3 route plate avoids final linear-filter haze at gameplay zoom")
			elif stage == 3:
				_check(game.arena.size == Vector2(4344, 3258), "LV4 route world is 50% larger than its former 2896 x 2172 layout")
				_check(game.level_four_art_scale() == Vector2(3, 3), "LV4 art, wall collisions and spawn points share a uniform 3x transform")
				_check(LEVEL_FOUR_ROUTE_BACKDROP.get_width() >= 5120 and LEVEL_FOUR_ROUTE_BACKDROP.get_height() >= 3840, "LV4 keeps its restored high-resolution route texture")
				_check(game.room_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "LV4 route plate avoids final linear-filter haze at gameplay zoom")
			elif stage == 4:
				_check(game.arena.size == Vector2(4344, 3258), "LV5 route world is 50% larger than its former 2896 x 2172 layout")
				_check(game.level_five_art_scale() == Vector2(3, 3), "LV5 art, wall collisions and spawn points share a uniform 3x transform")
				_check(LEVEL_FIVE_ROUTE_BACKDROP.get_width() >= 5120 and LEVEL_FIVE_ROUTE_BACKDROP.get_height() >= 3840, "LV5 keeps its continuous high-resolution route texture")
				_check(game.room_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "LV5 route plate avoids final linear-filter haze at gameplay zoom")
				_check(game.graph.branch == 3, "LV5 Support follows the authored Combat 4 branch")
				game.cleared = [0, 1, 2, 3]
				game.combat_active = false
				game.configure_map_layout()
				_check(game.is_route_room_open(4) and game.is_route_room_open(5), "LV5 opens Support and Boss only after Combat 4 clears")
				var silent_core_collision_radius := 11.0
				var silent_core_room_entry_art := {0: Vector2(168, 895), 1: Vector2(482, 670), 2: Vector2(842, 574), 3: Vector2(905, 262), 4: Vector2(630, 260), 5: Vector2(1265, 262)}
				for room in silent_core_room_entry_art:
					game.room_index = int(room)
					_check(game.is_combat_position(game.level_five_art_to_world_point(silent_core_room_entry_art[room]), silent_core_collision_radius), "LV5 room %d entry remains inside its collision polygon" % (int(room) + 1))
				game.room_index = 0
		else:
			var regions: Array[Rect2] = game.walkable_regions
			_check(regions.size() >= 5, "Stage %d contains multiple connected chambers" % (stage + 1))
			_check(_regions_connected(regions), "Stage %d keeps every chamber connected" % (stage + 1))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("CAMERA/MAP REGRESSION: 0 failures")
		quit(0)
	for failure in failures:
		push_error(failure)
	print("CAMERA/MAP REGRESSION: %d failures" % failures.size())
	quit(1)

func _check(condition: bool, description: String) -> void:
	if not condition and not failures.has(description):
		failures.append(description)

func _regions_connected(regions: Array[Rect2]) -> bool:
	var visited: Array[int] = [0]
	var pending: Array[int] = [0]
	while not pending.is_empty():
		var current: int = pending.pop_front()
		for index in range(regions.size()):
			if visited.has(index):
				continue
			if regions[current].grow(12).intersects(regions[index].grow(12)):
				visited.append(index)
				pending.append(index)
	return visited.size() == regions.size()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
