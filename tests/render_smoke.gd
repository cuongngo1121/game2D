extends SceneTree
## Desktop render and synthetic UI touch check. Saves actual Godot viewport PNGs.
var game
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.profile.checkpoint = {}
	game.ui.show_menu()
	await frames(5)
	await capture("01-menu-16x9")
	await touch(Vector2(640, 388))
	check(game.state == "unlocks", "ScreenTouch opens the weapon armory")
	await frames(4)
	await capture("01b-armory-16x9")
	await touch(Vector2(640, 663))
	check(game.state == "menu", "ScreenTouch returns from the weapon armory")
	await touch(Vector2(640, 412))
	check(game.ui.overlay.visible and game.state == "menu", "ScreenTouch opens the debug-area chooser without starting a run")
	await frames(4)
	await capture("01c-debug-zones-16x9")
	await touch(Vector2(1054, 392))
	check(game.state == "playing" and game.stage_index == 3 and game.room_index == 0, "ScreenTouch enters the selected debug area at its first room")
	game.return_to_menu()
	game.profile.checkpoint = {}
	game.ui.show_menu()
	await frames(2)
	await touch(Vector2(640, 282))
	check(game.state == "playing", "ScreenTouch starts new run through Godot Button")
	if game.state != "playing":
		game.new_run(6062026)
	game.set_physics_process(false)
	game.controls.mouse_aim_active = false
	game.controls.is_touch = true
	game.player.position = game.room_entry_position(0)
	game.enemies.update(1.5)
	game.player.resonance = 62
	game.enemies.on_beat(4)
	await frames(4)
	await capture("02-combat-16x9")
	# LV1 is scaled in world space; keep the smoke-test camera on an authored
	# floor coordinate rather than an obsolete fixed world pixel.
	game.player.position = game.level_one_art_to_world_point(Vector2(140, 760))
	await frames(4)
	await capture("02b-map-scroll-16x9")
	game.boundary_editor.open()
	await frames(4)
	check(game.boundary_editor.active and game.state == "boundary_editing", "Boundary editor opens as a focused non-gameplay overlay")
	game.boundary_editor.selected_room = 1
	game.boundary_editor.set_snap_step(16)
	game.boundary_editor.zoom_at(game.boundary_editor._art_to_screen(Vector2(560, 610)), 1.75)
	await frames(3)
	check(game.boundary_editor.zoom_scale > 1.0 and game.boundary_editor.snap_step == 16, "Boundary editor applies an explicit discrete snap grid and cursor-focused zoom")
	await capture("02c-map-boundary-editor-snap-zoom-16x9")
	game.boundary_editor.reset_view()
	game.boundary_editor.request_close()
	check(not game.boundary_editor.active and game.state == "playing", "Boundary editor closes back to the active run without changing the map")
	game.player.position = game.level_one_art_to_world_point(Vector2(140, 760))
	game.pause_game()
	check(game.state == "paused", "Pause reaches overlay")
	await touch(Vector2(986, 343))
	check(game.state == "settings", "ScreenTouch opens settings")
	await frames(4)
	await capture("03-settings-16x9")
	await touch(Vector2(640, 651))
	check(game.state == "paused", "ScreenTouch saves settings and returns")
	game.resume_game()
	game.enemies.clear()
	game.complete_room()
	await frames(3)
	await capture("04-rewards-16x9")
	await touch(Vector2(257, 568))
	check(game.state == "playing" and game.rewarded.has(0), "ScreenTouch selects reward exactly once")
	game.show_map()
	await frames(3)
	await capture("05-map-16x9")
	game.resume_game()
	game.stage_index = 4
	game.graph = game.GraphScript.generate(game.seed_value, 4)
	game.set_stage_music()
	game.enter_room(5)
	game.enemies.update(1.7)
	game.enemies.on_beat(4)
	await frames(4)
	await capture("06-final-boss-16x9")
	root.size = Vector2i(1600, 720)
	await frames(7)
	print("20:9 native window: ", root.size, " logical viewport: ", root.get_visible_rect().size)
	await capture("07-final-boss-20x9")
	game.ui.show_settings("paused")
	await frames(4)
	await capture("08-settings-20x9")
	game.end_run(true)
	await frames(3)
	await capture("09-victory-20x9")
	root.size = Vector2i(1280, 720)
	await frames(5)
	game.return_to_menu()
	game.profile.checkpoint = {}
	game.ui.show_menu()
	var safe_transform: Transform2D = preload("res://scripts/ui/safe_area.gd").fit_transform(Rect2(90, 24, 1190, 680), Transform2D.IDENTITY)
	root.global_canvas_transform = safe_transform
	await frames(4)
	await capture("10-menu-simulated-notch")
	await touch(safe_transform * Vector2(640, 282))
	check(game.state == "playing", "Transformed safe-area canvas preserves GUI ScreenTouch mapping")
	await frames(3)
	await capture("11-combat-simulated-notch")
	root.global_canvas_transform = Transform2D.IDENTITY
	# Area 2 now uses the authored amber route plate and its matching polygon
	# collision instead of the legacy rectangular conveyor arena.
	game.stage_index = 1
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	game.enemies.clear()
	game.player.position = game.room_entry_position(0)
	await frames(4)
	check(game.is_open_route_stage() and game.portals.is_empty(), "Bass Foundry renders as a continuous route without legacy room portals")
	check(game.is_walkable_position(game.player.position, game.player.radius), "Bass Foundry entry remains inside the new authored collision floor")
	await capture("12-bass-foundry-route-16x9")
	# Capture the same Luminous Grove starting chamber that exposes a section
	# junction at gameplay camera zoom. This is a visual regression fixture for
	# the route texture, not a boundary-editor preview.
	game.stage_index = 2
	game.graph = game.GraphScript.generate(game.seed_value, game.stage_index)
	game.set_stage_music()
	game.enter_room(0)
	game.enemies.clear()
	game.player.position = game.level_three_art_to_world_point(Vector2(150, 860))
	await frames(4)
	check(game.is_open_route_stage(), "Luminous Grove renders as a continuous route")
	check(game.is_walkable_position(game.player.position, game.player.radius), "Luminous Grove capture position remains inside Combat 1 collision")
	await capture("13-luminous-grove-c1-section-junction-16x9")
	# The final Boss approach is where the Boss and Combat 4 source exports meet.
	# Capture the actual gameplay camera here so a black cutout at that stitch
	# cannot be hidden by an atlas-only inspection.
	game.enter_room(5)
	game.enemies.clear()
	game.player.position = game.level_three_art_to_world_point(Vector2(1305, 230))
	await frames(4)
	check(game.is_walkable_position(game.player.position, game.player.radius), "Luminous Grove Boss capture position remains inside Boss collision")
	await capture("14-luminous-grove-boss-junction-16x9")
	game.stage_index = 4
	game.enter_room(5)
	game.enemies.units[0].transition = 1.5
	game._on_beat(8)
	check(game.audio.pending_intensity == "explore", "Boss phase intermission requests quiet bar-aligned music")
	print("RENDER SMOKE: %d failures" % failures.size())
	for failure in failures:
		push_error(failure)
	game.queue_free()
	await frames(2)
	quit(1 if failures.size() > 0 else 0)

func touch(point: Vector2) -> void:
	var press = InputEventScreenTouch.new()
	press.index = 0
	press.position = point
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release = InputEventScreenTouch.new()
	release.index = 0
	release.position = point
	release.pressed = false
	Input.parse_input_event(release)
	await frames(3)

func frames(count: int) -> void:
	for i in range(count):
		await process_frame

func capture(id: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://builds/screenshots")
	var output: String = "res://builds/screenshots/%s.png" % id
	var result: int = root.get_texture().get_image().save_png(output)
	check(result == OK, "Viewport capture " + id)
	print("CAPTURE ", output)

func check(condition: bool, description: String) -> void:
	print("PASS " if condition else "FAIL ", description)
	if not condition: failures.append(description)
