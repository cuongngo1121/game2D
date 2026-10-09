extends Node2D
## The composition root owns flow; actors, patterns, input, audio and persistence are separate.

const PlayerScript = preload("res://scripts/player/player.gd")
const DroneScript = preload("res://scripts/player/companion_drone.gd")
const WeaponScript = preload("res://scripts/player/weapon_system.gd")
const InputScript = preload("res://scripts/player/touch_controls.gd")
const RoomScript = preload("res://scripts/world/room_view.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
const EnemyScript = preload("res://scripts/combat/enemy_system.gd")
const ProjectileScript = preload("res://scripts/combat/projectile_system.gd")
const AudioScript = preload("res://scripts/audio/audio_manager.gd")
const RhythmScript = preload("res://scripts/audio/rhythm_manager.gd")
const SaveScript = preload("res://scripts/core/save_store.gd")
const GraphScript = preload("res://scripts/core/level_graph.gd")
const BoundaryDataScript = preload("res://scripts/world/level_one_boundary_data.gd")
const LevelTwoBoundaryDataScript = preload("res://scripts/world/level_two_boundary_data.gd")
const LevelThreeBoundaryDataScript = preload("res://scripts/world/level_three_boundary_data.gd")
const LevelFourBoundaryDataScript = preload("res://scripts/world/level_four_boundary_data.gd")
const LevelFiveBoundaryDataScript = preload("res://scripts/world/level_five_boundary_data.gd")
const CorridorBarrierDataScript = preload("res://scripts/world/corridor_barrier_data.gd")
const BoundaryEditorScript = preload("res://scripts/world/map_boundary_editor.gd")

# Development convenience switch. It deliberately keeps the normal campaign
# progression code intact, but exposes every test target from the main menu.
const DEBUG_TEST_CONTENT_ENABLED := true

var content: Dictionary = {}
var profile: Dictionary = {}
var settings: Dictionary = {}
var store
var player
var companion_drone
var has_drone: bool = false
var selected_drone: String = ""
var weapon_system
var controls
var room_view
var ui
var enemies
var projectiles
var audio
var rhythm
var world: Node2D
var rng = RandomNumberGenerator.new()
var arena = Rect2(0, 0, 2048, 1024)
var walkable_regions: Array[Rect2] = []
var walkable_polygons: Array[PackedVector2Array] = []
var obstacles: Array[Rect2] = []
var portals: Array[Dictionary] = []
var level_one_art_polygons: Dictionary = {}
var level_two_art_polygons: Dictionary = {}
var level_three_art_polygons: Dictionary = {}
var level_four_art_polygons: Dictionary = {}
var level_five_art_polygons: Dictionary = {}
var boundary_editor
var show_collision_boundaries: bool = false
# Visual route frames are separate from gameplay collision and Boundary Editor
# polygons.  They are the cyan/purple lines visible over the map itself.
var show_route_boundaries: bool = false
# Combat gates are authored separately from collision polygons.  The polygon
# stays authoritative for movement, while these rectangles identify the exact
# corridor where the player sees the combat lock close.
var route_barriers_art: Array[Dictionary] = []
var route_barrier_stage := -1

# LV1's navigation data is authored in the native pixels of its background
# plate. RoomView stretches that same plate to `arena`, so transforming these
# values with the same scale prevents art and collision from drifting apart.
const LEVEL_ONE_ART_SIZE := Vector2(1672.0, 941.0)
# The first route is deliberately more than twice as large in each direction
# as its original 1920 x 1024 world. Keep this as one world-size authority:
# art, collision polygons, portals and player entry points all transform from
# the native plate through `level_one_art_to_world_point` below.
const LEVEL_ONE_WORLD_SIZE := Vector2(4320.0, 2304.0)
# Bass Foundry uses the native 4:3 amber route plate. Keeping its world aspect
# ratio identical prevents the wall texture and its collision polygons drifting.
const LEVEL_TWO_ART_SIZE := Vector2(1448.0, 1086.0)
const LEVEL_TWO_WORLD_SIZE := Vector2(2896.0, 2172.0)
# Luminous Grove shares the 4:3 authoring plate used by Bass Foundry, but owns
# separate texture and collision data. Its route is deliberately 50% larger
# than the former 2x layout, so the 5120 x 3840 stitched atlas occupies more
# of the gameplay view. Art, collision polygons, support point and room-entry
# coordinates all continue to use this single scale authority.
const LEVEL_THREE_ART_SIZE := Vector2(1448.0, 1086.0)
const LEVEL_THREE_WORLD_SCALE := 3.0
const LEVEL_THREE_WORLD_SIZE := Vector2(
	LEVEL_THREE_ART_SIZE.x * LEVEL_THREE_WORLD_SCALE,
	LEVEL_THREE_ART_SIZE.y * LEVEL_THREE_WORLD_SCALE
)
# Prism Spire keeps the same 4:3 collision-authoring space as its route plate.
# Its world is 50% larger than the previous 2x route so the map reads larger at
# gameplay zoom. Texture, floor polygon, support point and room entry all use
# this single 3x transform, so none of them can drift apart.
const LEVEL_FOUR_ART_SIZE := Vector2(1448.0, 1086.0)
const LEVEL_FOUR_WORLD_SCALE := 3.0
const LEVEL_FOUR_WORLD_SIZE := Vector2(
	LEVEL_FOUR_ART_SIZE.x * LEVEL_FOUR_WORLD_SCALE,
	LEVEL_FOUR_ART_SIZE.y * LEVEL_FOUR_WORLD_SCALE
)
# SILENT CORE shares the 4:3 native authoring space of LV2/LV4. The HD atlas
# is display-only. Its world is likewise 50% larger than its former 2x layout;
# collision, room entries and editor vertices retain native art coordinates and
# are transformed together, so the art cannot shift a real wall or doorway.
const LEVEL_FIVE_ART_SIZE := Vector2(1448.0, 1086.0)
const LEVEL_FIVE_WORLD_SCALE := 3.0
const LEVEL_FIVE_WORLD_SIZE := Vector2(
	LEVEL_FIVE_ART_SIZE.x * LEVEL_FIVE_WORLD_SCALE,
	LEVEL_FIVE_ART_SIZE.y * LEVEL_FIVE_WORLD_SCALE
)
# Every combat-room polygon includes both its chamber and the connecting
# corridor. These inner rectangles begin at the actual chamber threshold, so a
# newly opened corridor stays quiet until the player genuinely steps into the
# next combat space. Values stay in the source map's native art coordinates.
const COMBAT_CHAMBER_TRIGGER_ART_RECTS := {
	0: {
		1: Rect2(474.0, 510.0, 248.0, 188.0),
		2: Rect2(842.0, 510.0, 192.0, 162.0),
		3: Rect2(1188.0, 420.0, 248.0, 168.0),
	},
	1: {
		1: Rect2(354.0, 526.0, 196.0, 162.0),
		2: Rect2(686.0, 394.0, 204.0, 170.0),
		3: Rect2(880.0, 58.0, 224.0, 158.0),
	},
	2: {
		1: Rect2(356.0, 542.0, 224.0, 106.0),
		2: Rect2(738.0, 434.0, 150.0, 124.0),
		3: Rect2(1030.0, 388.0, 182.0, 172.0),
	},
	3: {
		1: Rect2(486.0, 518.0, 158.0, 148.0),
		2: Rect2(760.0, 364.0, 204.0, 148.0),
		3: Rect2(854.0, 84.0, 162.0, 182.0),
	},
	4: {
		1: Rect2(396.0, 598.0, 172.0, 142.0),
		2: Rect2(724.0, 484.0, 234.0, 170.0),
		3: Rect2(838.0, 170.0, 142.0, 182.0),
	},
}
# Each final-room polygon intentionally includes the approach corridor so the
# player can walk continuously through the authored route. These inner regions
# start just inside the actual boss chamber, keeping the corridor safe while
# making the encounter begin as soon as the player has genuinely entered it.
const BOSS_CHAMBER_TRIGGER_ART_RECTS := {
	0: Rect2(1392.0, 96.0, 196.0, 208.0),
	1: Rect2(1166.0, 326.0, 216.0, 200.0),
	2: Rect2(1238.0, 184.0, 120.0, 112.0),
	3: Rect2(1200.0, 115.0, 180.0, 165.0),
	4: Rect2(1174.0, 145.0, 182.0, 200.0),
}
# These are chamber centres in each route plate's native coordinates. They are
# deliberately independent from the generic arena size, which differs between
# Areas 1–5 after the HD atlas/world-scale changes.
const BOSS_SPAWN_ART_POINTS := {
	0: Vector2(1490.0, 200.0),
	1: Vector2(1274.0, 426.0),
	2: Vector2(1285.0, 240.0),
	3: Vector2(1290.0, 198.0),
	4: Vector2(1265.0, 245.0),
}
const EXIT_PORTAL_APPEAR_SECONDS := 0.85
const EXIT_PORTAL_ENTER_RADIUS := 74.0
const EXIT_PORTAL_LEAVE_RADIUS := 118.0
var pickups: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var state: String = "menu"
var combat_active: bool = false
var combat_chamber_pending: bool = false
var boss_chamber_pending: bool = false
var exit_portal_active: bool = false
var exit_portal_elapsed: float = 0.0
var exit_portal_player_has_left: bool = false
var stage_index: int = 0
var room_index: int = 0
var seed_value: int = 0
var graph: Dictionary = {}
var cleared: Array = []
var rewarded: Array = []
var weapons: Array = ["pistol"]
var active_slot: int = 0
var damage_numbers: Array = []
var upgrades: Dictionary = {}
var coins: int = 0
var elapsed: float = 0
var run_kills: int = 0
var perfect_count: int = 0
var screen_shake: float = 0
var flash_message: String = ""
var flash_color = Color("35e7ff")
var flash_time: float = 0
var tutorial_step: int = 0
var tutorial_timer: float = 0
var room_clear_wait: float = 0
var support_purchased: bool = false
var pending_reward: Array = []
var end_recorded: bool = false
var save_error: String = ""
var starter: String = "pistol"
var test_mode: bool = false
var debug_session: bool = false
# Map-tour is narrower than the general temporary debug-session guard. It is
# enabled only from the developer zone menu and must never alter a normal run.
var debug_map_tour: bool = false
# Developer-only visual preview.  It lets an author inspect the same combat
# gates in a monster-free Debug Map without changing movement collision.
var debug_show_combat_barriers: bool = false
## Self-contained, teacher-checkable room reached from Debug Zones. It never
## writes campaign progression but uses the live player/projectile/enemy/audio systems.
var assignment_demo_active: bool = false
var assignment_demo_props: Array[Dictionary] = []
var assignment_forbidden_zone := Rect2(1050, 440, 260, 230)
var assignment_intruder_id: int = -1
var assignment_intruder_entered_forbidden: bool = false
var assignment_intruder_completed_intro_route: bool = false
var assignment_warning_remaining: int = 0
var assignment_warning_timer: float = 0.0
var assignment_warning_count: int = 0
var assignment_shield_time: float = 0.0
var assignment_shield_cooldown: float = 0.0
var assignment_emp_time: float = 0.0
var assignment_emp_cooldown: float = 0.0
var assignment_speed_boost_time: float = 0.0
var assignment_slow_time: float = 0.0
var quality_frames: int = 0

func _exit_tree() -> void:
	# RefCounted orchestration objects may otherwise retain callbacks/data on teardown.
	if weapon_system != null:
		weapon_system.reset()
		weapon_system.game = null
	weapon_system = null
	store = null

func _ready() -> void:
	level_one_art_polygons = BoundaryDataScript.load_room_art_polygons()
	level_two_art_polygons = LevelTwoBoundaryDataScript.load_room_art_polygons()
	level_three_art_polygons = LevelThreeBoundaryDataScript.load_room_art_polygons()
	level_four_art_polygons = LevelFourBoundaryDataScript.load_room_art_polygons()
	level_five_art_polygons = LevelFiveBoundaryDataScript.load_room_art_polygons()
	for key in ["weapons", "upgrades", "stages", "enemies"]:
		content[key] = JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % key))
	store = SaveScript.new()
	profile = store.load_profile()
	settings = profile.settings
	starter = str(profile.meta.get("starter", starter))
	coins = int(profile.meta.get("coins", 0))
	selected_drone = str(profile.meta.get("selected_drone", ""))
	has_drone = (selected_drone != "") or bool(profile.meta.get("has_drone", false))
	var debug_content_changed := unlock_debug_test_content()
	audio = AudioScript.new()
	add_child(audio)
	audio.setup()
	audio.set_volumes(settings.music, settings.sfx)
	audio.set_music_enabled(bool(settings.get("music_enabled", true)))
	audio.set_sfx_enabled(bool(settings.get("sfx_enabled", true)))
	rhythm = RhythmScript.new()
	add_child(rhythm)
	rhythm.setup(audio)
	rhythm.beat.connect(_on_beat)
	world = Node2D.new()
	add_child(world)
	room_view = RoomScript.new()
	world.add_child(room_view)
	room_view.setup(self)
	projectiles = ProjectileScript.new()
	world.add_child(projectiles)
	projectiles.setup(self)
	enemies = EnemyScript.new()
	world.add_child(enemies)
	enemies.setup(self)
	player = PlayerScript.new()
	world.add_child(player)
	player.setup(self)
	player.position = Vector2(1010, 359)
	player.visible = false
	companion_drone = DroneScript.new()
	world.add_child(companion_drone)
	companion_drone.setup(self, player)
	companion_drone.enabled = false
	companion_drone.visible = false
	weapon_system = WeaponScript.new()
	weapon_system.setup(self)
	var effects_view = preload("res://scripts/world/effects_view.gd").new()
	effects_view.game = self
	effects_view.z_index = 13
	world.add_child(effects_view)
	ui = UIScript.new()
	add_child(ui)
	ui.setup(self)
	controls = InputScript.new()
	ui.root.add_child(controls)
	controls.setup(self)
	ui.move_overlay_to_front()
	ui.show_hud_layout_editor()
	boundary_editor = BoundaryEditorScript.new()
	ui.root.add_child(boundary_editor)
	boundary_editor.setup(self)
	var safe_layout = preload("res://scripts/ui/safe_area.gd").new()
	add_child(safe_layout)
	safe_layout.setup(get_window(), controls.reset)
	set_stage_music()
	ui.show_menu()
	if debug_content_changed:
		persist_profile()
	get_tree().auto_accept_quit = false

func _physics_process(delta: float) -> void:
	if state != "playing":
		return
	elapsed += delta
	player.update(delta)
	if companion_drone != null:
		companion_drone.update(delta)
	if is_open_route_stage() and not combat_active:
		update_route_exploration()
	if not combat_active:
		update_boss_exit_portal()
	weapon_system.update(delta)
	enemies.update(delta)
	projectiles.update(delta)
	update_pickups(delta)
	_update_damage_numbers(delta)
	update_assignment_demo(delta)
	if combat_active and enemies.living_count() == 0:
		room_clear_wait += delta
		if room_clear_wait >= enemies.clear_animation_delay():
			complete_room()
	else:
		room_clear_wait = 0
	if tutorial_step < 4 and stage_index == 0 and room_index == 0:
		tutorial_timer += delta
		if (tutorial_step == 0 and player.position.distance_to(room_entry_position(0)) > 80) or (tutorial_step == 1 and weapon_system.shot_index > 3) or (tutorial_step == 2 and player.dash_cooldown > 0) or (tutorial_step == 3 and tutorial_timer > 13):
			tutorial_step += 1
			tutorial_timer = 0

func _process(delta: float) -> void:
	if rhythm != null and (state == "playing" or state == "menu" or state == "victory"):
		rhythm.update(delta)
	flash_time = maxf(0, flash_time - delta)
	if exit_portal_active:
		exit_portal_elapsed += delta
	if state == "playing":
		for effect in effects:
			effect.time -= delta
		effects = effects.filter(func(effect): return effect.time > 0)
		screen_shake = maxf(0, screen_shake - delta)
	if world != null:
		var amount: float = screen_shake * 17 * float(settings.get("screen_shake", 0.4))
		world.position = Vector2(sin(Time.get_ticks_msec() * 0.13), cos(Time.get_ticks_msec() * 0.17)) * amount if state == "playing" else Vector2.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if controls != null:
			controls.reset()
		if state == "playing":
			pause_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == "playing":
			pause_game()
		get_tree().quit()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "playing":
		pause_game()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if is_assignment_demo() and state == "playing":
		match event.physical_keycode:
			KEY_1:
				trigger_assignment_attack("pistol")
				get_viewport().set_input_as_handled()
				return
			KEY_2:
				trigger_assignment_attack("glitch")
				get_viewport().set_input_as_handled()
				return
			KEY_3:
				trigger_assignment_attack("beam")
				get_viewport().set_input_as_handled()
				return
			KEY_F:
				activate_assignment_shield()
				get_viewport().set_input_as_handled()
				return
			KEY_H:
				activate_assignment_emp()
				get_viewport().set_input_as_handled()
				return
			KEY_N:
				reset_assignment_demo()
				get_viewport().set_input_as_handled()
				return
	# Debug boss controls are deliberately direct actions. Walking through the
	# connected route does not re-enter a room scene, so they cannot rely on the
	# `enter_room(5)` hook used by a Map jump.
	if event.physical_keycode == KEY_T:
		if trigger_debug_boss_exit_portal_preview():
			get_viewport().set_input_as_handled()
			return
	if event.physical_keycode == KEY_U:
		if trigger_debug_boss_combat_preview():
			get_viewport().set_input_as_handled()
		return
	if boundary_editor == null:
		return
	if event.physical_keycode == KEY_F6:
		if boundary_editor.active:
			boundary_editor.request_close()
		else:
			boundary_editor.open()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_O and state == "playing" and not boundary_editor.active:
		if toggle_debug_combat_barrier_preview():
			get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_G and state == "playing" and not boundary_editor.active:
		if trigger_debug_room_combat_wave():
			get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_Y and state == "playing" and not boundary_editor.active:
		show_route_boundaries = not show_route_boundaries
		room_view.queue_redraw()
		flash_text("VIỀN MAP: BẬT" if show_route_boundaries else "VIỀN MAP: TẮT", Color("35e7ff"))
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_B and not boundary_editor.active:
		if state == "shop":
			resume_game()
			get_viewport().set_input_as_handled()
			return
		elif state == "playing":
			open_cyber_shop()
			get_viewport().set_input_as_handled()
			return
	if event.physical_keycode == KEY_ESCAPE and state == "shop":
		resume_game()
		get_viewport().set_input_as_handled()
		return
	if event.physical_keycode == KEY_T and state == "playing" and not boundary_editor.active:
		if not has_drone:
			flash_text("BẠN CHƯA SỞ HỮU DRONE! HÃY MUA TẠI CỬA HÀNG [B]", Color("ff846f"))
			get_viewport().set_input_as_handled()
			return
		if companion_drone != null:
			companion_drone.enabled = not companion_drone.enabled
			flash_text("DRONE TRỢ CHIẾN: BẬT" if companion_drone.enabled else "DRONE TRỢ CHIẾN: TẮT", Color("35e7ff"))
			get_viewport().set_input_as_handled()
			return
	if boundary_editor.active and boundary_editor.handle_key(event):
		get_viewport().set_input_as_handled()

func set_stage_music() -> void:
	var bpm: float = float(content.stages[stage_index].bpm)
	rhythm.configure(bpm, float(settings.latency_ms))
	audio.start_stage(stage_index, bpm)
	audio.request_intensity("explore")

func all_weapon_ids() -> Array[String]:
	var ids: Array[String] = []
	for weapon: Dictionary in content.weapons:
		ids.append(str(weapon.id))
	return ids

func unlock_debug_test_content() -> bool:
	if not DEBUG_TEST_CONTENT_ENABLED:
		return false
	var changed := false
	for id in all_weapon_ids():
		if not profile.meta.unlocked.has(id):
			profile.meta.unlocked.append(id)
			changed = true
	if not profile.meta.unlocked.has(starter):
		starter = "pistol" if profile.meta.unlocked.has("pistol") else str(profile.meta.unlocked[0])
	if profile.meta.get("starter", "") != starter:
		profile.meta.starter = starter
		changed = true
	return changed

func new_run(chosen_seed: int = 0, is_debug_session: bool = false, enable_debug_map_tour: bool = false, enable_assignment_demo: bool = false) -> void:
	debug_session = is_debug_session
	debug_map_tour = is_debug_session and enable_debug_map_tour
	assignment_demo_active = is_debug_session and enable_assignment_demo
	debug_show_combat_barriers = false
	show_route_boundaries = false
	assignment_demo_props.clear()
	assignment_intruder_id = -1
	assignment_intruder_entered_forbidden = false
	assignment_intruder_completed_intro_route = false
	assignment_warning_remaining = 0
	assignment_warning_timer = 0.0
	assignment_warning_count = 0
	assignment_shield_time = 0.0
	assignment_shield_cooldown = 0.0
	assignment_emp_time = 0.0
	assignment_emp_cooldown = 0.0
	assignment_speed_boost_time = 0.0
	assignment_slow_time = 0.0
	combat_chamber_pending = false
	boss_chamber_pending = false
	exit_portal_active = false
	exit_portal_elapsed = 0.0
	exit_portal_player_has_left = false
	seed_value = chosen_seed if chosen_seed > 0 else int(Time.get_unix_time_from_system()) % 2147483647
	rng.seed = seed_value
	stage_index = 0
	room_index = 0
	coins = 0
	elapsed = 0
	run_kills = 0
	perfect_count = 0
	upgrades.clear()
	cleared.clear()
	rewarded.clear()
	if assignment_demo_active:
		# The demo owns its own recurring enemy set, so entering the room must not
		# auto-start an authored campaign wave before the setup below runs.
		cleared.append(0)
	weapons = [starter]
	active_slot = 0
	end_recorded = false
	selected_drone = str(profile.meta.get("selected_drone", ""))
	has_drone = (selected_drone != "") or bool(profile.meta.get("has_drone", false))
	if has_drone and selected_drone == "":
		selected_drone = "plasma"
	if companion_drone != null:
		companion_drone.enabled = has_drone
		companion_drone.visible = has_drone
		if has_drone:
			companion_drone.set_drone_type(selected_drone)
			companion_drone.reset_position()
	player.hp = 100
	player.refresh_stats()
	player.shield = player.max_shield
	player.energy = player.max_energy
	player.resonance = 0
	player.perfect_beat = -999
	player.reset_visual_animation()
	tutorial_step = 0
	tutorial_timer = 0
	graph = GraphScript.generate(seed_value, stage_index)
	if not debug_session:
		profile.meta.runs = int(profile.meta.get("runs", 0)) + 1
	set_stage_music()
	enter_room(0)
	save_checkpoint()
	flash_text("NOCTIS mất tiếng. Hãy tìm lại từng lớp nhạc.", Color("35e7ff"))

func start_debug_stage(target_stage: int) -> void:
	if not DEBUG_TEST_CONTENT_ENABLED:
		return
	var selected_stage := clampi(target_stage, 0, content.stages.size() - 1)
	# Start from the same clean run state as the normal Play action, then replace
	# only the campaign location. This avoids test sessions inheriting enemies,
	# portals, rewards, or collision data from a prior area.
	new_run(0, true, true)
	stage_index = selected_stage
	room_index = 0
	# Every authored room is physically open in a map tour. `enter_room()` still
	# keeps the player inside the selected room when a route is in combat mode,
	# but map-tour never starts combat or spawns an encounter.
	cleared = [0, 1, 2, 3, 4, 5]
	rewarded.clear()
	combat_active = false
	tutorial_step = 4
	tutorial_timer = 0.0
	graph = GraphScript.generate(seed_value, stage_index)
	set_stage_music()
	enter_room(0)
	save_checkpoint()
	flash_text("DEBUG MAP · %s · O: rào · G: 1 đợt quái · U: boss" % content.stages[stage_index].name, Color("35e7ff"))


func start_assignment_demo() -> void:
	if not DEBUG_TEST_CONTENT_ENABLED:
		return
	# It is a temporary debug session: no campaign checkpoint, rewards, kills, or
	# unlock state can be written by this room.
	new_run(128041, true, false, true)
	setup_assignment_demo()
	flash_text("SANDBOX · 1 Đạn · 2 Tên lửa · 3 Tia · F Khiên · H EMP", Color("35e7ff"))


func is_assignment_demo() -> bool:
	return debug_session and assignment_demo_active


func short_effects_enabled() -> bool:
	return audio != null and audio.sfx_enabled()


func background_music_enabled() -> bool:
	return audio != null and audio.music_enabled()


func toggle_short_effects() -> void:
	if audio == null:
		return
	var enabled: bool = not audio.sfx_enabled()
	settings["sfx_enabled"] = enabled
	audio.set_sfx_enabled(enabled)
	if ui != null:
		ui.refresh_runtime_audio_controls()
	flash_text("HIỆU ỨNG ÂM THANH: BẬT" if enabled else "HIỆU ỨNG ÂM THANH: TẮT", Color("35e7ff") if enabled else Color("ff846f"))


func toggle_background_music() -> void:
	if audio == null:
		return
	var enabled: bool = not audio.music_enabled()
	settings["music_enabled"] = enabled
	audio.set_music_enabled(enabled)
	if ui != null:
		ui.refresh_runtime_audio_controls()
	flash_text("NHẠC NỀN: BẬT" if enabled else "NHẠC NỀN: TẮT", Color("9b4dff") if enabled else Color("ff846f"))


func setup_assignment_demo() -> void:
	if not is_assignment_demo():
		return
	projectiles.clear()
	enemies.clear()
	effects.clear()
	assignment_demo_props = [
		{"id": "X", "kind": "boost", "label": "X · PIN TỐC ĐỘ + TÍN DỤNG", "pos": Vector2(1500, 720), "radius": 30.0},
		{"id": "Y", "kind": "armor", "label": "Y · LÕI GIÁP + HỒI MÁU", "pos": Vector2(1300, 720), "radius": 30.0},
		{"id": "Z", "kind": "trap", "label": "Z · BẪY NỔ + LÀM CHẬM", "pos": Vector2(1100, 720), "radius": 30.0},
	]
	assignment_forbidden_zone = Rect2(1050, 440, 260, 230)
	assignment_intruder_id = -1
	assignment_intruder_entered_forbidden = false
	assignment_intruder_completed_intro_route = false
	assignment_warning_remaining = 0
	assignment_warning_timer = 0.0
	assignment_warning_count = 0
	assignment_shield_time = 0.0
	assignment_shield_cooldown = 0.0
	assignment_emp_time = 0.0
	assignment_emp_cooldown = 0.0
	assignment_speed_boost_time = 0.0
	assignment_slow_time = 0.0
	weapons = ["glitch"]
	active_slot = 0
	weapon_system.reset()
	player.position = room_entry_position(0)
	player.hp = player.max_hp
	player.shield = player.max_shield
	player.energy = player.max_energy
	player.resonance = 100.0
	player.invulnerable = 1.2
	player.reset_visual_animation()
	if companion_drone != null:
		companion_drone.reset_position()
	combat_active = true
	spawn_assignment_demo_enemies()
	audio.request_intensity("combat")
	room_view.queue_redraw()


func reset_assignment_demo() -> void:
	if not is_assignment_demo():
		return
	setup_assignment_demo()
	flash_text("SANDBOX ĐÃ LÀM LẠI · NPC sẽ đi vào vùng cấm", Color("35e7ff"))


func spawn_assignment_demo_enemies() -> void:
	if not is_assignment_demo():
		return
	enemies.clear()
	enemies._stage = 0
	enemies._room = 0
	enemies._boss_room = false
	enemies._grace = 0.25
	# A, the warning NPC, and the complete red zone are deliberately composed
	# inside the initial camera frame. This makes the core teacher-checkable event
	# visible without asking the tester to hunt across a large debug arena.
	enemies._spawn("drone", Vector2(1010, 560), false)
	var intruder: Dictionary = enemies.units.back()
	intruder["name"] = "NPC CẢNH BÁO"
	intruder["speed"] = 160.0
	intruder["spawn_grace"] = 0.25
	assignment_intruder_id = int(intruder.id)
	enemies._spawn("skirmisher", Vector2(1160, 742), false)
	enemies._spawn("charger", Vector2(1510, 520), false)
	room_view.queue_redraw()


func reset_assignment_demo_enemies() -> void:
	if not is_assignment_demo():
		return
	projectiles.clear()
	assignment_intruder_entered_forbidden = false
	assignment_intruder_completed_intro_route = false
	assignment_warning_remaining = 0
	assignment_warning_timer = 0.0
	assignment_warning_count = 0
	spawn_assignment_demo_enemies()
	combat_active = true
	flash_text("MỤC TIÊU ĐÃ HỒI · tiếp tục test 3 đòn và 2 phòng thủ", Color("35e7ff"))


func assignment_demo_speed_multiplier() -> float:
	if not is_assignment_demo():
		return 1.0
	if assignment_slow_time > 0.0:
		return 0.62
	if assignment_speed_boost_time > 0.0:
		return 1.35
	return 1.0


func assignment_demo_intruder_waypoint(unit_id: int) -> Vector2:
	if is_assignment_demo() and unit_id == assignment_intruder_id and not assignment_intruder_completed_intro_route:
		# The special NPC must visibly enter the red zone once before it resumes the
		# ordinary EnemySystem chase. This removes player-position randomness from
		# the warning demonstration.
		return assignment_forbidden_zone.get_center()
	return Vector2.ZERO


func trigger_assignment_attack(weapon_id: String) -> bool:
	if not is_assignment_demo() or state != "playing" or weapon_system.cooldown > 0.0:
		return false
	if not weapon_id in ["pistol", "glitch", "beam"]:
		return false
	var target: Dictionary = enemies.nearest_target(player.position, 900.0)
	if not target.is_empty():
		player.aim_direction = (target.pos - player.position).normalized()
	elif player.aim_direction.length_squared() < 0.01:
		player.aim_direction = Vector2.LEFT
	weapons[active_slot] = weapon_id
	var fired: bool = weapon_system.fire()
	if fired:
		var display_name := "ĐẠN PULSE" if weapon_id == "pistol" else ("TÊN LỬA NỔ" if weapon_id == "glitch" else "TIA PRISM")
		flash_text("ĐÒN %s · hiệu ứng âm thanh đã gọi" % display_name, Color("35e7ff"))
	return fired


func activate_assignment_shield() -> bool:
	if not is_assignment_demo() or state != "playing" or assignment_shield_cooldown > 0.0:
		return false
	assignment_shield_time = 3.0
	assignment_shield_cooldown = 6.0
	player.shield = player.max_shield
	player.invulnerable = maxf(player.invulnerable, assignment_shield_time)
	projectiles.erase_in_radius(player.position, 92.0)
	add_fx(player.position, Color("35e7ff"), 98.0)
	audio.play_sfx("shield_regen")
	flash_text("PHÒNG THỦ 1 · KHIÊN 3 GIÂY · chặn sát thương / đạn gần", Color("35e7ff"))
	return true


func activate_assignment_emp() -> bool:
	if not is_assignment_demo() or state != "playing" or assignment_emp_cooldown > 0.0:
		return false
	assignment_emp_time = 2.5
	assignment_emp_cooldown = 6.0
	for unit in enemies.units:
		if unit.pos.distance_to(player.position) <= 520.0:
			# EnemySystem treats exposed units as unable to move or attack. This makes
			# EMP a genuine short disable, not merely a visual effect.
			unit.exposed = maxf(float(unit.get("exposed", 0.0)), assignment_emp_time)
			unit.charge_left = 0.0
	projectiles.erase_in_radius(player.position, 520.0)
	add_fx(player.position, Color("9b4dff"), 520.0)
	audio.play_sfx("pulse")
	flash_text("PHÒNG THỦ 2 · EMP 2.5 GIÂY · vô hiệu NPC trong vùng", Color("9b4dff"))
	return true


func update_assignment_demo(delta: float) -> void:
	if not is_assignment_demo():
		return
	assignment_shield_time = maxf(0.0, assignment_shield_time - delta)
	assignment_shield_cooldown = maxf(0.0, assignment_shield_cooldown - delta)
	assignment_emp_time = maxf(0.0, assignment_emp_time - delta)
	assignment_emp_cooldown = maxf(0.0, assignment_emp_cooldown - delta)
	assignment_speed_boost_time = maxf(0.0, assignment_speed_boost_time - delta)
	assignment_slow_time = maxf(0.0, assignment_slow_time - delta)
	update_assignment_demo_collisions()
	var intruder_in_forbidden_zone := false
	for unit in enemies.units:
		if int(unit.id) == assignment_intruder_id:
			intruder_in_forbidden_zone = assignment_forbidden_zone.has_point(unit.pos)
			break
	if intruder_in_forbidden_zone:
		if not assignment_intruder_entered_forbidden:
			assignment_intruder_entered_forbidden = true
			assignment_intruder_completed_intro_route = true
			start_assignment_warning_sequence()
	elif assignment_intruder_entered_forbidden:
		# Re-arm only after this NPC has actually left the red zone. The current
		# four-cue alert is intentionally allowed to finish: the violation already
		# happened, but the next outside -> inside crossing starts a fresh alert.
		assignment_intruder_entered_forbidden = false
	if assignment_warning_remaining > 0:
		assignment_warning_timer -= delta
		if assignment_warning_timer <= 0.0:
			audio.play_sfx("ui")
			assignment_warning_count += 1
			assignment_warning_remaining -= 1
			assignment_warning_timer = 0.34
			flash_text("CẢNH BÁO NPC · vùng cấm · %d / 4" % (4 - assignment_warning_remaining), Color("ff846f"))


func start_assignment_warning_sequence() -> bool:
	if not is_assignment_demo() or assignment_warning_remaining > 0:
		return false
	assignment_warning_remaining = 4
	assignment_warning_timer = 0.0
	return true


func update_assignment_demo_collisions() -> void:
	for index in range(assignment_demo_props.size() - 1, -1, -1):
		var prop: Dictionary = assignment_demo_props[index]
		if player.position.distance_to(prop.pos) > player.radius + float(prop.get("radius", 30.0)):
			continue
		var kind: String = str(prop.get("kind", ""))
		match kind:
			"boost":
				coins += 20
				player.energy = player.max_energy
				assignment_speed_boost_time = 6.0
				add_fx(prop.pos, Color("35e7ff"), 64.0)
				audio.play_sfx("pickup")
				flash_text("X · +20 TÍN DỤNG · TỐC ĐỘ +35% trong 6 giây", Color("35e7ff"))
			"armor":
				player.shield = minf(player.max_shield, player.shield + 32.0)
				player.hp = minf(player.max_hp, player.hp + 18.0)
				add_fx(prop.pos, Color("9b4dff"), 64.0)
				audio.play_sfx("shield_regen")
				flash_text("Y · HỒI 18 HP · +32 GIÁP/KHIÊN", Color("9b4dff"))
			"trap":
				player.shield = maxf(0.0, player.shield - 25.0)
				player.hp = maxf(1.0, player.hp - 13.0)
				player.invulnerable = maxf(player.invulnerable, 0.7)
				assignment_slow_time = 5.0
				add_fx(prop.pos, Color("ff846f"), 92.0)
				audio.play_sfx("hurt")
				screen_shake = 0.22
				flash_text("Z · NỔ · -13 HP / -25 KHIÊN · CHẬM 5 GIÂY", Color("ff846f"))
		assignment_demo_props.remove_at(index)
	room_view.queue_redraw()

func is_debug_map_tour() -> bool:
	return debug_session and debug_map_tour

func continue_run() -> void:
	var checkpoint: Dictionary = profile.get("checkpoint", {})
	if checkpoint.is_empty():
		return
	debug_session = false
	assignment_demo_active = false
	show_route_boundaries = false
	seed_value = int(checkpoint.seed)
	stage_index = int(checkpoint.stage)
	room_index = int(checkpoint.room)
	cleared = checkpoint.cleared.duplicate()
	rewarded = checkpoint.rewarded.duplicate()
	# JSON numbers arrive as floats; normalize room identifiers before matching.
	cleared = cleared.map(func(value): return int(value))
	rewarded = rewarded.map(func(value): return int(value))
	weapons = checkpoint.weapons.duplicate()
	upgrades = checkpoint.upgrades.duplicate()
	selected_drone = str(checkpoint.get("selected_drone", profile.meta.get("selected_drone", "")))
	has_drone = bool(checkpoint.get("has_drone", profile.meta.get("has_drone", false)))
	if selected_drone == "" and int(upgrades.get("drone", 0)) > 0:
		has_drone = true
	if has_drone and selected_drone == "":
		selected_drone = "plasma"
	profile.meta["selected_drone"] = selected_drone
	profile.meta["has_drone"] = has_drone
	if companion_drone != null:
		companion_drone.enabled = has_drone
		companion_drone.visible = has_drone
		if has_drone:
			companion_drone.set_drone_type(selected_drone)
			companion_drone.reset_position()
	active_slot = clampi(int(checkpoint.get("active_slot", 0)), 0, weapons.size() - 1)
	coins = int(checkpoint.coins)
	elapsed = float(checkpoint.elapsed)
	run_kills = int(checkpoint.get("run_kills", 0))
	perfect_count = int(checkpoint.get("perfect_count", 0))
	end_recorded = false
	tutorial_step = 4
	rng.seed = seed_value + stage_index * 104729 + room_index * 991
	graph = GraphScript.generate(seed_value, stage_index)
	player.restore(checkpoint.player)
	set_stage_music()
	enter_room(room_index)
	flash_text("Đã tiếp tục tại checkpoint phòng gần nhất", Color("35e7ff"))

func enter_room(index: int, preserve_player_position: bool = false) -> void:
	room_index = index
	# Route polygons deliberately include their approach corridors. A physical
	# walk-in keeps the next room quiet until its inner chamber trigger is
	# crossed; direct entries and restored encounters retain immediate combat.
	combat_chamber_pending = is_open_route_stage() and preserve_player_position and index >= 1 and index <= 3 and not cleared.has(index)
	boss_chamber_pending = is_open_route_stage() and index == 5 and preserve_player_position and not cleared.has(5)
	exit_portal_active = false
	exit_portal_elapsed = 0.0
	exit_portal_player_has_left = false
	projectiles.clear()
	enemies.clear()
	weapon_system.reset()
	pickups.clear()
	effects.clear()
	obstacles.clear()
	portals.clear()
	room_clear_wait = 0
	player.invulnerable = 1.5
	player.visible = true
	player.dash_time = 0
	player.dash_cooldown = 0
	player.reset_visual_animation()
	configure_map_layout()
	if not preserve_player_position:
		player.position = room_entry_position(index)
	if companion_drone != null:
		companion_drone.reset_position()
		companion_drone.visible = has_drone and player.visible
	player.configure_follow_camera(arena)
	var stage: Dictionary = content.stages[stage_index]
	var rectangles: Array = []
	if not is_open_route_stage() and not is_assignment_demo():
		if index == 5:
			rectangles = stage.get("boss_obstacles", [])
		elif index < 4:
			rectangles = stage.room_templates[int(graph.templates[index])]
	for rect in rectangles:
		obstacles.append(Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
	if not is_open_route_stage() and not is_assignment_demo():
		var links: Array = graph.links[index]
		for i in range(links.size()):
			var destination: int = int(links[i])
			portals.append({"pos": Vector2(arena.end.x - 112, 392 + i * 72), "room": destination})
		if index == 5:
			portals.append({"pos": Vector2(arena.end.x - 112, 432), "room": 6})
	state = "playing"
	# A connected-route walk-in is still the same live input session. Resetting
	# here clears the touch stick/finger (and disarms held keyboard movement) just
	# as the player crosses the room boundary, which can strand them in the
	# corridor before the pending chamber is reached. Direct room/overlay entries
	# keep the full input reset behavior.
	if not preserve_player_position:
		controls.reset()
	ui.hide_overlay()
	rhythm.resume_music()
	if is_assignment_demo():
		combat_active = false
		support_purchased = true
		audio.request_intensity("explore")
		flash_text("SANDBOX · khu thử độc lập", Color("35e7ff"))
	elif is_debug_map_tour():
		combat_active = false
		support_purchased = true
		audio.request_intensity("explore")
		flash_text("DEBUG MAP · %s · O: rào · G: 1 đợt quái · U: boss" % room_name(index), Color("35e7ff"))
	elif boss_chamber_pending:
		combat_active = false
		audio.request_intensity("explore")
		flash_text("HÀNH LANG BOSS · Tiến vào buồng lõi", Color("b597ff"))
	elif combat_chamber_pending:
		combat_active = false
		audio.request_intensity("explore")
		flash_text("HÀNH LANG · Tiến vào %s" % room_name(index), Color("b597ff"))
	elif index == 4:
		combat_active = false
		support_purchased = rewarded.has(4)
		if not cleared.has(4):
			cleared.append(4)
		audio.request_intensity("explore")
		flash_text("TRẠM HỖ TRỢ · Lại gần thiết bị ở giữa phòng", Color("35e7ff"))
	elif cleared.has(index):
		combat_active = false
		audio.request_intensity("explore")
	elif index == 5:
		combat_active = true
		rng.seed = seed_value + stage_index * 104729 + index * 991
		enemies.spawn_room(stage_index, index, true, seed_value + stage_index * 104729 + index * 991)
		audio.request_intensity("boss")
		flash_text(stage.boss, Color("ff846f"))
	else:
		_start_regular_room_combat()
	# The Debug Map renders this same shared gate in every boss room immediately,
	# but it is display-only: it never moves the developer out of the test area.
	if is_debug_map_tour() and is_open_route_stage() and index == 5:
		spawn_debug_boss_exit_portal()
	# A completed boss checkpoint is a safe room. Restore its exit gate when the
	# player resumes there so progress cannot be stranded between areas.
	elif not is_debug_map_tour() and is_open_route_stage() and index == 5 and cleared.has(5) and rewarded.has(5):
		spawn_boss_exit_portal()
	room_view.queue_redraw()

func configure_map_layout() -> void:
	# A room is a connected collection of chambers and corridors, not one screen-sized box.
	# Route stages follow their authored combat paths. Regions assigned to unopened
	# rooms are visible, but intentionally absent from this physical movement list.
	walkable_regions.clear()
	walkable_polygons.clear()
	if is_assignment_demo():
		arena = Rect2(0, 0, 2048, 1024)
		# One broad, unobstructed chamber makes the three collision objects and the
		# NPC forbidden-zone crossing readable on PC and touch controls alike.
		walkable_regions.append(Rect2(64, 112, 1888, 800))
		return
	if is_open_route_stage():
		arena = Rect2(Vector2.ZERO, route_world_size())
		ensure_route_combat_barriers()
		walkable_polygons = open_route_walkable_polygons()
		return
	arena = Rect2(0, 0, 2048, 1024)
	# The shared east corridor keeps the room exit reachable in every later stage.
	walkable_regions.append(Rect2(64, 112, 1152, 480))
	walkable_regions.append(Rect2(1120, 352, 880, 160))
	match stage_index:
		1:
			walkable_regions.append(Rect2(480, 32, 224, 480))
			walkable_regions.append(Rect2(128, 32, 480, 256))
			walkable_regions.append(Rect2(608, 32, 480, 256))
			walkable_regions.append(Rect2(480, 480, 224, 512))
			walkable_regions.append(Rect2(128, 720, 480, 256))
			walkable_regions.append(Rect2(608, 720, 480, 256))
		2:
			walkable_regions.append(Rect2(736, 32, 416, 256))
			walkable_regions.append(Rect2(1088, 224, 864, 192))
			walkable_regions.append(Rect2(1536, 384, 416, 416))
			walkable_regions.append(Rect2(64, 560, 416, 384))
			walkable_regions.append(Rect2(384, 512, 224, 352))
		3:
			walkable_regions.append(Rect2(512, 32, 224, 256))
			walkable_regions.append(Rect2(1088, 288, 912, 192))
			walkable_regions.append(Rect2(1536, 384, 416, 448))
			walkable_regions.append(Rect2(704, 480, 256, 480))
			walkable_regions.append(Rect2(256, 704, 480, 256))
		4:
			walkable_regions.append(Rect2(512, 0, 256, 320))
			walkable_regions.append(Rect2(256, 0, 512, 192))
			walkable_regions.append(Rect2(512, 480, 256, 544))
			walkable_regions.append(Rect2(256, 832, 512, 192))
			walkable_regions.append(Rect2(0, 288, 512, 192))
			walkable_regions.append(Rect2(1536, 288, 464, 192))

func level_one_room_polygons(index: int) -> Array[PackedVector2Array]:
	var art_polygon := level_one_room_art_polygon(index)
	if art_polygon.is_empty():
		return []
	return [level_one_art_to_world_polygon(art_polygon)]

func level_one_room_art_polygon(index: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = level_one_art_polygons.get(index, PackedVector2Array())
	return polygon.duplicate()

func apply_level_one_boundary_polygons(next_polygons: Dictionary) -> void:
	level_one_art_polygons = BoundaryDataScript.duplicate_room_art_polygons(next_polygons)
	if stage_index == 0:
		configure_map_layout()
		if room_view != null:
			room_view.queue_redraw()

func level_one_art_to_world_point(art_point: Vector2) -> Vector2:
	return arena.position + art_point * level_one_art_scale()

func level_one_art_to_world_polygon(art_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for art_point in art_polygon:
		world_polygon.append(level_one_art_to_world_point(art_point))
	return world_polygon

func level_one_art_scale() -> Vector2:
	return Vector2(arena.size.x / LEVEL_ONE_ART_SIZE.x, arena.size.y / LEVEL_ONE_ART_SIZE.y)

func level_two_room_art_polygon(index: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = level_two_art_polygons.get(index, PackedVector2Array())
	return polygon.duplicate()

func level_two_room_polygons(index: int) -> Array[PackedVector2Array]:
	var art_polygon := level_two_room_art_polygon(index)
	if art_polygon.is_empty():
		return []
	return [level_two_art_to_world_polygon(art_polygon)]

func apply_level_two_boundary_polygons(next_polygons: Dictionary) -> void:
	level_two_art_polygons = LevelTwoBoundaryDataScript.duplicate_room_art_polygons(next_polygons)
	if stage_index == 1:
		configure_map_layout()
		if room_view != null:
			room_view.queue_redraw()

func level_two_art_to_world_point(art_point: Vector2) -> Vector2:
	return arena.position + art_point * level_two_art_scale()

func level_two_art_to_world_polygon(art_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for art_point in art_polygon:
		world_polygon.append(level_two_art_to_world_point(art_point))
	return world_polygon

func level_two_art_scale() -> Vector2:
	return Vector2(arena.size.x / LEVEL_TWO_ART_SIZE.x, arena.size.y / LEVEL_TWO_ART_SIZE.y)

func level_three_room_art_polygon(index: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = level_three_art_polygons.get(index, PackedVector2Array())
	return polygon.duplicate()

func level_three_room_polygons(index: int) -> Array[PackedVector2Array]:
	var art_polygon := level_three_room_art_polygon(index)
	if art_polygon.is_empty():
		return []
	return [level_three_art_to_world_polygon(art_polygon)]

func apply_level_three_boundary_polygons(next_polygons: Dictionary) -> void:
	level_three_art_polygons = LevelThreeBoundaryDataScript.duplicate_room_art_polygons(next_polygons)
	if stage_index == 2:
		configure_map_layout()
		if room_view != null:
			room_view.queue_redraw()

func level_three_art_to_world_point(art_point: Vector2) -> Vector2:
	return arena.position + art_point * level_three_art_scale()

func level_three_art_to_world_polygon(art_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for art_point in art_polygon:
		world_polygon.append(level_three_art_to_world_point(art_point))
	return world_polygon

func level_three_art_scale() -> Vector2:
	return Vector2(arena.size.x / LEVEL_THREE_ART_SIZE.x, arena.size.y / LEVEL_THREE_ART_SIZE.y)

func level_four_room_art_polygon(index: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = level_four_art_polygons.get(index, PackedVector2Array())
	return polygon.duplicate()

func level_four_room_polygons(index: int) -> Array[PackedVector2Array]:
	var art_polygon := level_four_room_art_polygon(index)
	if art_polygon.is_empty():
		return []
	return [level_four_art_to_world_polygon(art_polygon)]

func apply_level_four_boundary_polygons(next_polygons: Dictionary) -> void:
	level_four_art_polygons = LevelFourBoundaryDataScript.duplicate_room_art_polygons(next_polygons)
	if stage_index == 3:
		configure_map_layout()
		if room_view != null:
			room_view.queue_redraw()

func level_four_art_to_world_point(art_point: Vector2) -> Vector2:
	return arena.position + art_point * level_four_art_scale()

func level_four_art_to_world_polygon(art_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for art_point in art_polygon:
		world_polygon.append(level_four_art_to_world_point(art_point))
	return world_polygon

func level_four_art_scale() -> Vector2:
	return Vector2(arena.size.x / LEVEL_FOUR_ART_SIZE.x, arena.size.y / LEVEL_FOUR_ART_SIZE.y)

func level_five_room_art_polygon(index: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = level_five_art_polygons.get(index, PackedVector2Array())
	return polygon.duplicate()

func level_five_room_polygons(index: int) -> Array[PackedVector2Array]:
	var art_polygon := level_five_room_art_polygon(index)
	if art_polygon.is_empty():
		return []
	return [level_five_art_to_world_polygon(art_polygon)]

func apply_level_five_boundary_polygons(next_polygons: Dictionary) -> void:
	level_five_art_polygons = LevelFiveBoundaryDataScript.duplicate_room_art_polygons(next_polygons)
	if stage_index == 4:
		configure_map_layout()
		if room_view != null:
			room_view.queue_redraw()

func level_five_art_to_world_point(art_point: Vector2) -> Vector2:
	return arena.position + art_point * level_five_art_scale()

func level_five_art_to_world_polygon(art_polygon: PackedVector2Array) -> PackedVector2Array:
	var world_polygon := PackedVector2Array()
	for art_point in art_polygon:
		world_polygon.append(level_five_art_to_world_point(art_point))
	return world_polygon

func level_five_art_scale() -> Vector2:
	return Vector2(arena.size.x / LEVEL_FIVE_ART_SIZE.x, arena.size.y / LEVEL_FIVE_ART_SIZE.y)

func is_open_route_stage() -> bool:
	return not assignment_demo_active and stage_index >= 0 and stage_index <= 4

func route_world_size() -> Vector2:
	match stage_index:
		0: return LEVEL_ONE_WORLD_SIZE
		1: return LEVEL_TWO_WORLD_SIZE
		2: return LEVEL_THREE_WORLD_SIZE
		3: return LEVEL_FOUR_WORLD_SIZE
		4: return LEVEL_FIVE_WORLD_SIZE
	return arena.size

func route_art_polygons() -> Dictionary:
	match stage_index:
		0: return level_one_art_polygons
		1: return level_two_art_polygons
		2: return level_three_art_polygons
		3: return level_four_art_polygons
		4: return level_five_art_polygons
	return {}

func apply_route_boundary_polygons(next_polygons: Dictionary) -> void:
	if stage_index == 0:
		apply_level_one_boundary_polygons(next_polygons)
	elif stage_index == 1:
		apply_level_two_boundary_polygons(next_polygons)
	elif stage_index == 2:
		apply_level_three_boundary_polygons(next_polygons)
	elif stage_index == 3:
		apply_level_four_boundary_polygons(next_polygons)
	elif stage_index == 4:
		apply_level_five_boundary_polygons(next_polygons)

func ensure_route_combat_barriers() -> void:
	if not is_open_route_stage() or route_barrier_stage == stage_index:
		return
	route_barrier_stage = stage_index
	route_barriers_art = CorridorBarrierDataScript.load_stage_art_barriers(stage_index, route_art_polygons(), route_art_size())

func apply_route_combat_barriers(next_barriers: Array[Dictionary]) -> void:
	if not is_open_route_stage():
		return
	var validation: Dictionary = CorridorBarrierDataScript.validate_stage_art_barriers(next_barriers, route_art_size())
	if not validation.get("ok", false):
		push_warning("Ignoring invalid combat-gate data: %s" % validation.get("message", "unknown validation error"))
		return
	route_barriers_art = CorridorBarrierDataScript.duplicate_stage_art_barriers(next_barriers)
	route_barrier_stage = stage_index
	if room_view != null:
		room_view.queue_redraw()

func authored_combat_barrier_rects() -> Array[Rect2]:
	if not is_open_route_stage():
		return []
	ensure_route_combat_barriers()
	var barrier_rects: Array[Rect2] = []
	for barrier in route_barriers_art:
		var art_rect: Rect2 = barrier.get("rect", Rect2())
		if art_rect.size.x <= 0.0 or art_rect.size.y <= 0.0:
			continue
		barrier_rects.append(route_art_to_world_rect(art_rect))
	return barrier_rects

func active_combat_barrier_rects() -> Array[Rect2]:
	var debug_preview_active := is_debug_map_tour() and debug_show_combat_barriers and state == "playing"
	if (not combat_active and not debug_preview_active) or not is_open_route_stage():
		return []
	# A combat lock now covers the whole connected map, rather than only gates
	# carrying the current room's editor label.  This prevents an earlier-room
	# gate from disappearing when the player fights farther along the route.
	return authored_combat_barrier_rects()

func is_blocked_by_active_combat_barrier(pos: Vector2, body_radius: float = 0.0) -> bool:
	# F6/O may display gate models outside combat, but only an active encounter
	# turns an authored bar into a physical wall.  The stored thin Rect2 supplies
	# reliable collision thickness while RoomView keeps rendering it as a line.
	if not combat_active or not is_open_route_stage():
		return false
	for barrier in authored_combat_barrier_rects():
		if barrier.grow(body_radius).has_point(pos):
			return true
	return false

func route_room_polygons(index: int) -> Array[PackedVector2Array]:
	match stage_index:
		0: return level_one_room_polygons(index)
		1: return level_two_room_polygons(index)
		2: return level_three_room_polygons(index)
		3: return level_four_room_polygons(index)
		4: return level_five_room_polygons(index)
	return []

func route_regions() -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	# Draw the support branch before the main route so intersecting frame corners
	# remain legible where the lower service corridor meets Combat 2.
	for room in [0, 1, 4, 2, 3, 5]:
		for polygon in route_room_polygons(room):
			route.append({"room": room, "polygon": polygon})
	return route

func open_route_rooms() -> Array[int]:
	if is_debug_map_tour():
		return [0, 1, 2, 3, 4, 5]
	var opened: Array[int] = [0]
	if stage_index == 4:
		# SILENT CORE follows the source topology: Support is the upper-left
		# branch from Combat 4, instead of the standard Combat 2 side-room.
		if cleared.has(0):
			opened.append(1)
		if cleared.has(1):
			opened.append(2)
		if cleared.has(2):
			opened.append(3)
		if cleared.has(3):
			opened.append_array([4, 5])
		if room_index >= 0 and room_index <= 5 and not opened.has(room_index):
			opened.append(room_index)
		return opened
	if cleared.has(0):
		opened.append(1)
	if cleared.has(1):
		opened.append_array([2, 4])
	if cleared.has(2):
		opened.append(3)
	if cleared.has(3):
		opened.append(5)
	# A restored checkpoint and the active room must always remain valid even if
	# the player has a save authored before the route map was introduced.
	if room_index >= 0 and room_index <= 5 and not opened.has(room_index):
		opened.append(room_index)
	return opened

func is_route_room_open(index: int) -> bool:
	return open_route_rooms().has(index)

func open_route_walkable_polygons() -> Array[PackedVector2Array]:
	# Merge doorway overlaps while exploring. During combat we deliberately use
	# only the active room polygon, which closes the next room without a portal.
	var merged: Array[PackedVector2Array] = []
	for room in open_route_rooms():
		for room_polygon in route_room_polygons(room):
			var candidate: PackedVector2Array = room_polygon
			var index := 0
			while index < merged.size():
				var union: Array = Geometry2D.merge_polygons(merged[index], candidate)
				if union.size() == 1:
					candidate = union[0]
					merged.remove_at(index)
					index = 0
				else:
					index += 1
			merged.append(candidate)
	return merged

func level_one_route_regions() -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	# Draw the support branch before the main route so intersecting frame corners
	# remain clean at the Combat 2 junction.
	for room in [0, 1, 4, 2, 3, 5]:
		for polygon in level_one_room_polygons(room):
			route.append({"room": room, "polygon": polygon})
	return route

func level_one_open_rooms() -> Array[int]:
	var opened: Array[int] = [0]
	if cleared.has(0):
		opened.append(1)
	if cleared.has(1):
		opened.append_array([2, 4])
	if cleared.has(2):
		opened.append(3)
	if cleared.has(3):
		opened.append(5)
	# A restored checkpoint and the active room must always remain valid even if
	# it predates this authored route layout.
	if room_index >= 0 and room_index <= 5 and not opened.has(room_index):
		opened.append(room_index)
	return opened

func is_level_one_room_open(index: int) -> bool:
	return level_one_open_rooms().has(index)

func level_one_open_walkable_polygons() -> Array[PackedVector2Array]:
	# Adjacent authored rooms frequently share a thin doorway overlap. Merge
	# them while exploring so that shared internal edges never behave like walls
	# against the player's collision radius. Combat deliberately keeps using only
	# `combat_walkable_polygons()` for the active chamber.
	var merged: Array[PackedVector2Array] = []
	for room in level_one_open_rooms():
		for room_polygon in level_one_room_polygons(room):
			var candidate: PackedVector2Array = room_polygon
			var index := 0
			while index < merged.size():
				var union: Array = Geometry2D.merge_polygons(merged[index], candidate)
				if union.size() == 1:
					candidate = union[0]
					merged.remove_at(index)
					index = 0
				else:
					index += 1
			merged.append(candidate)
	return merged

func room_entry_position(index: int) -> Vector2:
	if is_assignment_demo():
		return Vector2(1320, 620)
	if stage_index == 4:
		match index:
			0: return level_five_art_to_world_point(Vector2(168, 895))
			1: return level_five_art_to_world_point(Vector2(482, 670))
			2: return level_five_art_to_world_point(Vector2(842, 574))
			3: return level_five_art_to_world_point(Vector2(905, 262))
			4: return level_five_art_to_world_point(Vector2(630, 260))
			5: return level_five_art_to_world_point(Vector2(1265, 262))
		return level_five_art_to_world_point(Vector2(168, 895))
	if stage_index > 3:
		return Vector2(130, 352)
	if stage_index == 3:
		match index:
			0: return level_four_art_to_world_point(Vector2(140, 870))
			1: return level_four_art_to_world_point(Vector2(535, 590))
			2: return level_four_art_to_world_point(Vector2(845, 455))
			3: return level_four_art_to_world_point(Vector2(910, 185))
			4: return level_four_art_to_world_point(Vector2(580, 850))
			5: return level_four_art_to_world_point(Vector2(1290, 195))
		return level_four_art_to_world_point(Vector2(140, 870))
	if stage_index == 2:
		match index:
			0: return level_three_art_to_world_point(Vector2(150, 860))
			1: return level_three_art_to_world_point(Vector2(430, 630))
			2: return level_three_art_to_world_point(Vector2(795, 505))
			3: return level_three_art_to_world_point(Vector2(1125, 485))
			4: return level_three_art_to_world_point(Vector2(755, 285))
			5: return level_three_art_to_world_point(Vector2(1305, 230))
		return level_three_art_to_world_point(Vector2(150, 860))
	if stage_index == 1:
		match index:
			0: return level_two_art_to_world_point(Vector2(160, 850))
			1: return level_two_art_to_world_point(Vector2(420, 580))
			2: return level_two_art_to_world_point(Vector2(740, 470))
			3: return level_two_art_to_world_point(Vector2(980, 180))
			4: return level_two_art_to_world_point(Vector2(540, 870))
			5: return level_two_art_to_world_point(Vector2(1260, 435))
		return level_two_art_to_world_point(Vector2(160, 850))
	match index:
		0: return level_one_art_to_world_point(Vector2(140, 760))
		1: return level_one_art_to_world_point(Vector2(560, 610))
		2: return level_one_art_to_world_point(Vector2(920, 590))
		3: return level_one_art_to_world_point(Vector2(1300, 520))
		4: return level_one_art_to_world_point(Vector2(610, 290))
		5: return level_one_art_to_world_point(Vector2(1485, 250))
	return level_one_art_to_world_point(Vector2(140, 760))

func support_station_position() -> Vector2:
	if stage_index == 0:
		return level_one_art_to_world_point(Vector2(610, 290))
	if stage_index == 1:
		return level_two_art_to_world_point(Vector2(540, 870))
	if stage_index == 2:
		return level_three_art_to_world_point(Vector2(755, 285))
	if stage_index == 3:
		return level_four_art_to_world_point(Vector2(580, 850))
	if stage_index == 4:
		return level_five_art_to_world_point(Vector2(630, 260))
	return Vector2(640, 344)

func route_art_to_world_point(art_point: Vector2) -> Vector2:
	match stage_index:
		0: return level_one_art_to_world_point(art_point)
		1: return level_two_art_to_world_point(art_point)
		2: return level_three_art_to_world_point(art_point)
		3: return level_four_art_to_world_point(art_point)
		4: return level_five_art_to_world_point(art_point)
	return art_point

func route_art_to_world_rect(art_rect: Rect2) -> Rect2:
	var origin := route_art_to_world_point(art_rect.position)
	var end := route_art_to_world_point(art_rect.end)
	return Rect2(origin, end - origin)

func route_art_size() -> Vector2:
	match stage_index:
		0: return LEVEL_ONE_ART_SIZE
		1: return LEVEL_TWO_ART_SIZE
		2: return LEVEL_THREE_ART_SIZE
		3: return LEVEL_FOUR_ART_SIZE
		4: return LEVEL_FIVE_ART_SIZE
	return Vector2.ZERO

func boss_spawn_position() -> Vector2:
	if is_open_route_stage():
		return route_art_to_world_point(BOSS_SPAWN_ART_POINTS.get(stage_index, Vector2.ZERO))
	return Vector2(arena.end.x - 180.0, 432.0)

func boss_chamber_trigger_rect() -> Rect2:
	var art_rect: Rect2 = BOSS_CHAMBER_TRIGGER_ART_RECTS.get(stage_index, Rect2())
	var world_origin := route_art_to_world_point(art_rect.position)
	var world_end := route_art_to_world_point(art_rect.end)
	return Rect2(world_origin, world_end - world_origin)

func combat_chamber_trigger_rect(index: int = room_index) -> Rect2:
	var stage_triggers: Dictionary = COMBAT_CHAMBER_TRIGGER_ART_RECTS.get(stage_index, {})
	var art_rect: Rect2 = stage_triggers.get(index, Rect2())
	return route_art_to_world_rect(art_rect)

func has_reached_combat_chamber(pos: Vector2, body_radius: float = 0.0) -> bool:
	if not is_open_route_stage() or room_index < 1 or room_index > 3:
		return false
	var trigger := combat_chamber_trigger_rect(room_index)
	if trigger.size.x <= body_radius * 2.0 or trigger.size.y <= body_radius * 2.0:
		return false
	# Shrink the trigger by the player collider so merely brushing a doorway does
	# not prematurely close the route behind NOCTIS.
	return trigger.grow(-body_radius).has_point(pos) and _is_position_in_polygons(pos, body_radius, route_room_polygons(room_index)) and not is_inside_authored_combat_barrier(pos, body_radius)

func is_inside_authored_combat_barrier(pos: Vector2, body_radius: float = 0.0) -> bool:
	if not is_open_route_stage():
		return false
	for barrier in authored_combat_barrier_rects():
		if barrier.grow(body_radius).has_point(pos):
			return true
	return false

func has_reached_boss_chamber(pos: Vector2, body_radius: float = 0.0) -> bool:
	if not is_open_route_stage() or room_index != 5:
		return false
	# `grow(-radius)` avoids beginning the encounter while only the edge of the
	# player collider crosses the doorway threshold.
	return boss_chamber_trigger_rect().grow(-body_radius).has_point(pos) and _is_position_in_polygons(pos, body_radius, route_room_polygons(5))

func _start_regular_room_combat() -> void:
	combat_chamber_pending = false
	combat_active = true
	rng.seed = seed_value + stage_index * 104729 + room_index * 991
	enemies.spawn_room(stage_index, room_index, false, seed_value + stage_index * 104729 + room_index * 991)
	audio.request_intensity("combat")
	flash_text("PHÒNG %d · Tín hiệu lỗi đã khóa cửa" % (room_index + 1), Color("35e7ff"))
	if room_view != null:
		room_view.queue_redraw()

func start_pending_room_encounter() -> void:
	if not combat_chamber_pending or combat_active or room_index < 1 or room_index > 3 or cleared.has(room_index):
		return
	_start_regular_room_combat()

func start_boss_encounter() -> void:
	if not boss_chamber_pending or combat_active or room_index != 5 or cleared.has(5):
		return
	combat_chamber_pending = false
	boss_chamber_pending = false
	combat_active = true
	rng.seed = seed_value + stage_index * 104729 + room_index * 991
	enemies.spawn_room(stage_index, room_index, true, seed_value + stage_index * 104729 + room_index * 991)
	audio.request_intensity("boss")
	flash_text(content.stages[stage_index].boss, Color("ff846f"))
	room_view.queue_redraw()

func route_room_at_position(pos: Vector2, body_radius: float = 0.0) -> int:
	var opened: Array[int] = open_route_rooms()
	# Prefer a newly opened, unfinished room at shared door thresholds. This
	# records corridor entry for UI/camera state, while the inner trigger below
	# decides when its encounter actually begins. Completed chambers remain
	# freely traversable in either direction.
	for room in opened:
		if room != 4 and cleared.has(room):
			continue
		if _is_position_in_polygons(pos, body_radius, route_room_polygons(room)):
			return room
	if opened.has(room_index) and _is_position_in_polygons(pos, body_radius, route_room_polygons(room_index)):
		return room_index
	for room in opened:
		if _is_position_in_polygons(pos, body_radius, route_room_polygons(room)):
			return room
	return -1

func update_route_exploration() -> void:
	if not is_open_route_stage() or combat_active:
		return
	var next_room := route_room_at_position(player.position, player.radius)
	if next_room < 0:
		return
	if next_room != room_index:
		if next_room == 4 or not cleared.has(next_room):
			# Preserve the current world position: route stages are one connected map, so
			# entering a newly unlocked chamber must never teleport the player.
			enter_room(next_room, true)
			if next_room == 4:
				save_checkpoint()
		else:
			# A player who turns around before reaching an inner trigger returns to a
			# cleared room without leaving a latent encounter armed in the hallway.
			combat_chamber_pending = false
			boss_chamber_pending = false
			room_index = next_room
			save_checkpoint()
			room_view.queue_redraw()
	if boss_chamber_pending:
		if has_reached_boss_chamber(player.position, player.radius):
			start_boss_encounter()
	elif combat_chamber_pending and has_reached_combat_chamber(player.position, player.radius):
		start_pending_room_encounter()

func combat_walkable_polygons() -> Array[PackedVector2Array]:
	return route_room_polygons(room_index)

func combat_walkable_regions() -> Array[Rect2]:
	return walkable_regions

func _is_position_in_regions(pos: Vector2, body_radius: float, regions: Array[Rect2]) -> bool:
	if not arena.grow(-body_radius).has_point(pos):
		return false
	if regions.is_empty():
		return true
	for region in regions:
		if region.grow(-body_radius).has_point(pos):
			return true
	return false

func _is_position_in_polygons(pos: Vector2, body_radius: float, polygons: Array[PackedVector2Array]) -> bool:
	if not arena.grow(-body_radius).has_point(pos):
		return false
	for polygon in polygons:
		if not Geometry2D.is_point_in_polygon(pos, polygon):
			continue
		var has_clearance := true
		for edge in range(polygon.size()):
			var closest := Geometry2D.get_closest_point_to_segment(pos, polygon[edge], polygon[(edge + 1) % polygon.size()])
			if pos.distance_to(closest) < body_radius:
				has_clearance = false
				break
		if has_clearance:
			return true
	return false

func is_walkable_position(pos: Vector2, body_radius: float = 0.0) -> bool:
	if is_open_route_stage():
		var polygons: Array[PackedVector2Array] = combat_walkable_polygons() if combat_active else walkable_polygons
		return _is_position_in_polygons(pos, body_radius, polygons) and not is_blocked_by_active_combat_barrier(pos, body_radius)
	var regions: Array[Rect2] = walkable_regions
	return _is_position_in_regions(pos, body_radius, regions)

func is_combat_position(pos: Vector2, body_radius: float = 0.0) -> bool:
	if is_open_route_stage():
		return _is_position_in_polygons(pos, body_radius, combat_walkable_polygons()) and not is_blocked_by_active_combat_barrier(pos, body_radius)
	return _is_position_in_regions(pos, body_radius, combat_walkable_regions())

func complete_room() -> void:
	if not combat_active:
		return
	if is_assignment_demo():
		reset_assignment_demo_enemies()
		return
	# A Debug Map encounter is live, but its completion is never a campaign room
	# clear: it must not award upgrades, coins, checkpoints, or unlock travel.
	# This applies to both the boss preview and the one-wave room-combat preview.
	if is_debug_map_tour():
		_complete_debug_combat()
		return
	combat_chamber_pending = false
	boss_chamber_pending = false
	combat_active = false
	projectiles.clear()
	for pickup in pickups:
		collect_pickup(pickup)
	pickups.clear()
	if not cleared.has(room_index):
		cleared.append(room_index)
	if is_open_route_stage():
		# The newly eligible destination becomes physically reachable as soon as
		# this room is cleared, before the reward overlay is dismissed.
		configure_map_layout()
		room_view.queue_redraw()
	coins += 15 + stage_index * 5
	audio.play_sfx("door")
	audio.request_intensity("explore")
	if room_index == 5:
		player.hp = minf(100, player.hp + 24)
		spawn_boss_exit_portal()
		flash_text("ĐÃ THU HỒI LỚP NHẠC %d / 5" % (stage_index + 1), Color("35e7ff"))
	if not rewarded.has(room_index):
		show_reward()
	else:
		save_checkpoint()
		if not test_mode:
			open_cyber_shop()

func _complete_debug_combat() -> void:
	var completed_room := room_index
	combat_active = false
	combat_chamber_pending = false
	boss_chamber_pending = false
	room_clear_wait = 0.0
	projectiles.clear()
	pickups.clear()
	enemies.clear()
	audio.request_intensity("explore")
	if completed_room == 5:
		spawn_debug_boss_exit_portal()
		flash_text("DEBUG · %s ĐÃ BỊ HẠ · U để đấu lại" % content.stages[stage_index].boss, Color("35e7ff"))
	else:
		flash_text("DEBUG · %s ĐÃ DỌN · G để gọi một đợt mới" % room_name(completed_room), Color("35e7ff"))
	room_view.queue_redraw()

func show_reward() -> void:
	state = "reward"
	controls.reset()
	rhythm.pause_music()
	pending_reward.clear()
	var reward_rng = RandomNumberGenerator.new()
	reward_rng.seed = seed_value + stage_index * 104729 + room_index * 3001
	var candidates: Array = []
	for upgrade in content.upgrades:
		if int(upgrades.get(upgrade.id, 0)) >= int(upgrade.max_stacks):
			continue
		var compatible: bool = upgrade.compatible.is_empty()
		for weapon in weapons:
			compatible = compatible or upgrade.compatible.has(weapon)
		if compatible:
			candidates.append(upgrade)
	while pending_reward.size() < 3 and not candidates.is_empty():
		var pick: int = reward_rng.randi_range(0, candidates.size() - 1)
		pending_reward.append(candidates.pop_at(pick))
	ui.show_rewards(pending_reward)

func choose_upgrade(id: String) -> void:
	if state != "reward" or rewarded.has(room_index):
		return
	var valid: bool = id == "repair"
	for choice in pending_reward:
		valid = valid or choice.id == id
	if not valid:
		return
	if id == "repair":
		player.hp = minf(100, player.hp + 25)
	else:
		upgrades[id] = int(upgrades.get(id, 0)) + 1
		player.refresh_stats()
		if id == "shield":
			player.shield = minf(player.max_shield, player.shield + 20)
		if id == "energy":
			player.energy = player.max_energy
	rewarded.append(room_index)
	pending_reward.clear()
	audio.play_sfx("pickup")
	save_checkpoint()
	state = "playing"
	ui.hide_overlay()
	controls.reset()
	rhythm.resume_music()
	var safe_room_hint := "Phòng an toàn · Đi tới vùng đã mở hoặc mở bản đồ" if is_open_route_stage() else "Phòng an toàn · Đến cửa sáng hoặc mở bản đồ"
	flash_text(safe_room_hint, Color("35e7ff"))
	if test_mode:
		return
	open_cyber_shop()

func support_offers() -> Array:
	var offers: Array = []
	var offer_rng = RandomNumberGenerator.new()
	offer_rng.seed = seed_value + stage_index * 877 + 731
	var pool: Array = []
	for item in content.weapons:
		if not weapons.has(item.id):
			pool.append(item)
	for i in range(mini(3, pool.size())):
		var pick: int = offer_rng.randi_range(0, pool.size() - 1)
		offers.append(pool.pop_at(pick))
	return offers

func buy_weapon(id: String) -> void:
	if state != "shop" or support_purchased:
		return
	var price: int = 0 if graph.support == "chest" else 55 + stage_index * 12
	if coins < price:
		flash_text("Cần thêm %d tín dụng" % (price - coins), Color("ff846f"))
		return
	var valid: bool = false
	for offer in support_offers():
		valid = valid or offer.id == id
	if not valid:
		return
	coins -= price
	weapons[active_slot] = id
	support_purchased = true
	if not rewarded.has(4):
		rewarded.append(4)
	audio.play_sfx("buy")
	save_checkpoint()
	resume_game()
	flash_text("Đã trang bị " + weapon_system.definition(id).name, Color("35e7ff"))

func heal_support() -> void:
	if support_purchased or state != "shop":
		return
	player.hp = minf(100, player.hp + 45)
	player.shield = player.max_shield
	player.energy = player.max_energy
	support_purchased = true
	if not rewarded.has(4):
		rewarded.append(4)
	audio.play_sfx("pickup")
	save_checkpoint()
	resume_game()

func open_cyber_shop() -> void:
	if state == "shop":
		resume_game()
		return
	if state != "playing":
		return
	if combat_active:
		flash_text("KHÔNG THỂ MỞ CỬA HÀNG KHI ĐANG GIAO TRANH!", Color("ff846f"))
		return
	state = "shop"
	controls.reset()
	rhythm.pause_music()
	ui.show_cyber_shop()

func buy_drone_companion() -> bool:
	if profile.meta.has("unlocked_drones") and profile.meta.unlocked_drones.has("plasma"):
		flash_text("BẠN ĐÃ SỞ HỮU DRONE RỒI!", Color("35e7ff"))
		return false
	return unlock_drone("plasma")

func buy_drone_overclock() -> bool:
	if not has_drone and int(upgrades.get("drone", 0)) == 0:
		flash_text("CẦN MUA DRONE TRƯỚC TIÊN!", Color("ff846f"))
		return false
	var current_lvl: int = int(upgrades.get("drone_overclock", 0))
	if current_lvl >= 3:
		flash_text("DRONE ĐÃ ĐẠT CẤP ĐỘ TỐI ĐA!", Color("35e7ff"))
		return false
	const PRICE := 45
	if coins < PRICE:
		flash_text("Cần thêm %d coin!" % (PRICE - coins), Color("ff846f"))
		return false
	coins -= PRICE
	upgrades["drone_overclock"] = current_lvl + 1
	audio.play_sfx("buy")
	flash_text("DRONE ĐÃ NÂNG CẤP LÊN CẤP %d!" % (current_lvl + 1), Color("35e7ff"))
	save_checkpoint()
	return true

func buy_heal_hp() -> bool:
	if player.hp >= player.max_hp:
		flash_text("MÁU ĐÃ ĐẦY!", Color("35e7ff"))
		return false
	const PRICE := 20
	if coins < PRICE:
		flash_text("Cần thêm %d coin để hồi máu!" % (PRICE - coins), Color("ff846f"))
		return false
	coins -= PRICE
	player.hp = minf(player.max_hp, player.hp + 45.0)
	audio.play_sfx("pickup")
	flash_text("ĐÃ HỒI 45 MÁU!", Color("35e7ff"))
	return true

func buy_max_hp_upgrade() -> bool:
	var lvl: int = int(upgrades.get("health", 0))
	if lvl >= 5:
		flash_text("MÁU TỐI ĐA ĐÃ ĐẠT GIỚI HẠN!", Color("35e7ff"))
		return false
	var price: int = 35 + lvl * 10
	if coins < price:
		flash_text("Cần thêm %d coin!" % (price - coins), Color("ff846f"))
		return false
	coins -= price
	upgrades["health"] = lvl + 1
	player.refresh_stats()
	player.hp = minf(player.max_hp, player.hp + 25.0)
	audio.play_sfx("buy")
	flash_text("+25 MÁU TỐI ĐA! (Tổng: %d)" % int(player.max_hp), Color("35e7ff"))
	save_checkpoint()
	return true

func buy_max_shield_upgrade() -> bool:
	var lvl: int = int(upgrades.get("shield", 0))
	if lvl >= 5:
		flash_text("KHIÊN ĐÃ ĐẠT GIỚI HẠN!", Color("35e7ff"))
		return false
	var price: int = 30 + lvl * 10
	if coins < price:
		flash_text("Cần thêm %d coin!" % (price - coins), Color("ff846f"))
		return false
	coins -= price
	upgrades["shield"] = lvl + 1
	player.refresh_stats()
	player.shield = player.max_shield
	audio.play_sfx("buy")
	flash_text("+20 KHIÊN TỐI ĐA! (Tổng: %d)" % int(player.max_shield), Color("35e7ff"))
	save_checkpoint()
	return true

func buy_damage_upgrade() -> bool:
	var lvl: int = int(upgrades.get("damage", 0))
	if lvl >= 5:
		flash_text("SÁT THƯƠNG ĐÃ ĐẠT GIỚI HẠN!", Color("35e7ff"))
		return false
	var price: int = 40 + lvl * 15
	if coins < price:
		flash_text("Cần thêm %d coin!" % (price - coins), Color("ff846f"))
		return false
	coins -= price
	upgrades["damage"] = lvl + 1
	audio.play_sfx("buy")
	flash_text("+15%% SÁT THƯƠNG VŨ KHÍ! (Cấp %d)" % (lvl + 1), Color("35e7ff"))
	save_checkpoint()
	return true

func buy_magnet_upgrade() -> bool:
	var lvl: int = int(upgrades.get("magnet", 0))
	if lvl >= 3:
		flash_text("NAM CHÂM ĐÃ ĐẠT GIỚI HẠN!", Color("35e7ff"))
		return false
	const PRICE := 25
	if coins < PRICE:
		flash_text("Cần thêm %d coin!" % (PRICE - coins), Color("ff846f"))
		return false
	coins -= PRICE
	upgrades["magnet"] = lvl + 1
	audio.play_sfx("buy")
	flash_text("TĂNG BÁN KÍNH HÚT VẬT PHẨM! (Cấp %d)" % (lvl + 1), Color("35e7ff"))
	save_checkpoint()
	return true

func buy_speed_upgrade() -> bool:
	var lvl: int = int(upgrades.get("speed", 0))
	if lvl >= 3:
		flash_text("TỐC ĐỘ ĐÃ ĐẠT GIỚI HẠN!", Color("35e7ff"))
		return false
	const PRICE := 30
	if coins < PRICE:
		flash_text("Cần thêm %d coin!" % (PRICE - coins), Color("ff846f"))
		return false
	coins -= PRICE
	upgrades["speed"] = lvl + 1
	player.refresh_stats()
	audio.play_sfx("buy")
	flash_text("+23 PX/S TỐC ĐỘ CHẠY! (Cấp %d)" % (lvl + 1), Color("35e7ff"))
	save_checkpoint()
	return true

func nearest_portal() -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = 85
	for portal in portals:
		var current: float = portal.pos.distance_to(player.position)
		if current < distance:
			nearest = portal
			distance = current
	return nearest

func boss_exit_portal() -> Dictionary:
	for portal in portals:
		if str(portal.get("kind", "")) == "boss_exit":
			return portal
	return {}

func spawn_boss_exit_portal() -> void:
	if room_index != 5 or not is_open_route_stage() or not boss_exit_portal().is_empty():
		return
	exit_portal_active = true
	exit_portal_elapsed = 0.0
	exit_portal_player_has_left = false
	# Reuse the centre that was validated for boss spawning, so the gate never
	# alters boss-room collision or needs a map-specific correction.
	portals.append({"pos": boss_spawn_position(), "room": 6, "kind": "boss_exit"})
	room_view.queue_redraw()

func debug_exit_portal() -> Dictionary:
	for portal in portals:
		if str(portal.get("kind", "")) == "debug_exit":
			return portal
	return {}

func toggle_debug_combat_barrier_preview() -> bool:
	if not is_debug_map_tour() or state != "playing":
		return false
	debug_show_combat_barriers = not debug_show_combat_barriers
	room_view.queue_redraw()
	flash_text("DEBUG RÀO: BẬT · %s" % room_name(room_index) if debug_show_combat_barriers else "DEBUG RÀO: TẮT", Color("ff846f") if debug_show_combat_barriers else Color("35e7ff"))
	return true

func trigger_debug_room_combat_wave() -> bool:
	if not is_debug_map_tour() or state != "playing" or combat_active or not is_open_route_stage():
		return false
	# Use the physical room under the tester instead of a stale map-button choice.
	# This makes the debug encounter follow the same local collision room that its
	# enemies and combat gates will use once it starts.
	var physical_room := route_room_at_position(player.position, player.radius)
	if physical_room < 0:
		flash_text("DEBUG · Hãy đứng trong một phòng trước khi gọi quái.", Color("ff846f"))
		return true
	room_index = physical_room
	if room_index == 4:
		flash_text("DEBUG · Trạm hỗ trợ không có đợt quái. Chọn Phòng chiến đấu 1–4.", Color("ff846f"))
		return true
	if room_index == 5:
		flash_text("DEBUG · Phòng Boss dùng U để bắt đầu boss combat.", Color("ff846f"))
		return true
	projectiles.clear()
	enemies.clear()
	weapon_system.reset()
	pickups.clear()
	effects.clear()
	room_clear_wait = 0.0
	combat_chamber_pending = false
	boss_chamber_pending = false
	player.invulnerable = maxf(player.invulnerable, 1.5)
	player.dash_time = 0.0
	player.dash_cooldown = 0.0
	player.reset_visual_animation()
	combat_active = true
	rng.seed = seed_value + stage_index * 104729 + room_index * 991
	# This starts one normal first-wave roster, using EnemySystem's ordinary spawn
	# positions, warning grace and stage scaling, then returns to free Debug Map
	# inspection as soon as the wave is defeated.
	enemies.spawn_debug_wave(stage_index, room_index, seed_value + stage_index * 104729 + room_index * 991)
	audio.request_intensity("combat")
	flash_text("DEBUG COMBAT · %s · 1 đợt quái · rào đã khóa" % room_name(room_index), Color("ff846f"))
	room_view.queue_redraw()
	return true

func spawn_debug_boss_exit_portal() -> void:
	if not is_debug_map_tour() or room_index != 5 or not is_open_route_stage() or not debug_exit_portal().is_empty():
		return
	_place_debug_boss_exit_portal()

func trigger_debug_boss_exit_portal_preview() -> bool:
	if not is_debug_map_tour() or state != "playing" or combat_active or not is_open_route_stage():
		return false
	# On a continuous map, walking into the boss chamber can update the visible
	# location without rebuilding the room. Test against the physical polygon,
	# not only `room_index`, so T works for the exact walk-in path.
	if route_room_at_position(player.position, player.radius) != 5:
		return false
	# The gate and boss use the same verified chamber centre.  A live encounter
	# owns that space, so T is intentionally unavailable until combat completes.
	_remove_debug_boss_exit_portal()
	_place_debug_boss_exit_portal()
	flash_text("DEBUG · CỔNG BOSS ĐÃ HIỆN · T để chạy lại animation", Color("35e7ff"))
	return true

func trigger_debug_boss_combat_preview() -> bool:
	if not is_debug_map_tour() or state != "playing" or combat_active or not is_open_route_stage():
		return false
	# Match the physical walk-in route, not just the last room selected from the
	# map modal. This keeps U unavailable in corridors and non-boss rooms.
	if route_room_at_position(player.position, player.radius) != 5:
		return false
	# U can be pressed on the same frame the player physically crosses from a
	# corridor into the boss chamber.  Route exploration normally updates this
	# on its next physics tick, but boss collision must use room 5 immediately.
	room_index = 5
	_remove_debug_boss_exit_portal()
	exit_portal_active = false
	exit_portal_elapsed = 0.0
	exit_portal_player_has_left = false
	projectiles.clear()
	enemies.clear()
	combat_chamber_pending = false
	boss_chamber_pending = false
	room_clear_wait = 0.0
	# Keep the boss exactly at the authored centre, then move the tester to a
	# legal in-room offset. This avoids an immediate overlap/contact hit without
	# changing the actual boss placement or collision geometry.
	player.position = debug_boss_combat_player_position()
	player.invulnerable = maxf(player.invulnerable, 1.0)
	combat_active = true
	rng.seed = seed_value + stage_index * 104729 + 5 * 991
	enemies.spawn_room(stage_index, 5, true, seed_value + stage_index * 104729 + 5 * 991)
	audio.request_intensity("boss")
	flash_text("DEBUG COMBAT · %s · đánh để xem Idle / Move / Attack / Hurt / Death" % content.stages[stage_index].boss, Color("ffab64"))
	room_view.queue_redraw()
	return true

func debug_boss_combat_player_position() -> Vector2:
	var centre := boss_spawn_position()
	# Test in a stable cardinal offset first. Each candidate honours the active
	# boss-room polygon and all authored obstacle rectangles for all five maps.
	for offset in [Vector2(0, 180), Vector2(-180, 0), Vector2(180, 0), Vector2(0, -180), Vector2(-125, 125), Vector2(125, 125)]:
		var candidate: Vector2 = centre + offset
		if not is_combat_position(candidate, player.radius):
			continue
		var blocked := false
		for obstacle in obstacles:
			if obstacle.grow(player.radius).has_point(candidate):
				blocked = true
				break
		if not blocked:
			return candidate
	return player.position

func _remove_debug_boss_exit_portal() -> void:
	for index in range(portals.size() - 1, -1, -1):
		if str(portals[index].get("kind", "")) == "debug_exit":
			portals.remove_at(index)

func _place_debug_boss_exit_portal() -> void:
	exit_portal_active = true
	exit_portal_elapsed = 0.0
	exit_portal_player_has_left = false
	portals.append({"pos": boss_spawn_position(), "room": 6, "kind": "debug_exit"})
	room_view.queue_redraw()

func exit_portal_appear_progress() -> float:
	return clampf(exit_portal_elapsed / EXIT_PORTAL_APPEAR_SECONDS, 0.0, 1.0)

func update_boss_exit_portal() -> void:
	if is_debug_map_tour() or not exit_portal_active or combat_active or state != "playing" or room_index != 5 or not rewarded.has(5):
		return
	if exit_portal_appear_progress() < 1.0:
		return
	var portal := boss_exit_portal()
	if portal.is_empty():
		return
	var distance: float = player.position.distance_to(portal.pos)
	# A portal can materialize underneath a player who dealt the final blow.
	# Require one intentional step away first, then detect the walk back in.
	if not exit_portal_player_has_left:
		exit_portal_player_has_left = distance >= EXIT_PORTAL_LEAVE_RADIUS
		return
	if distance <= EXIT_PORTAL_ENTER_RADIUS:
		travel(6)

func interaction_label() -> String:
	if state != "playing" or combat_active:
		return ""
	if room_index == 4 and player.position.distance_to(support_station_position()) < 100 and not support_purchased:
		return "E · Mở hòm hỗ trợ"
	var portal: Dictionary = nearest_portal()
	if not portal.is_empty():
		if str(portal.get("kind", "")) == "debug_exit":
			return "DEBUG · Cổng dịch chuyển (xem animation)"
		if str(portal.get("kind", "")) == "boss_exit":
			if not rewarded.has(5):
				return "CỔNG ĐANG ỔN ĐỊNH"
			return "CỔNG DỊCH CHUYỂN · Đi vào để " + ("khôi phục NOCTIS" if stage_index == 4 else "sang khu vực tiếp theo")
		if portal.room == 6:
			return "E · Khôi phục NOCTIS" if stage_index == 4 else "E · Sang khu vực tiếp theo"
		return "E · " + room_name(portal.room)
	return ""

func interact() -> void:
	if state != "playing" or combat_active:
		return
	if room_index == 4 and player.position.distance_to(support_station_position()) < 100 and not support_purchased:
		state = "shop"
		controls.reset()
		rhythm.pause_music()
		ui.show_shop(support_offers())
		return
	var portal: Dictionary = nearest_portal()
	if not portal.is_empty():
		if str(portal.get("kind", "")) == "debug_exit":
			return
		travel(int(portal.room))

func travel(destination: int) -> void:
	if combat_active:
		return
	# Debug Map intentionally permits direct room selection for inspection. The
	# normal campaign never uses it: all five areas are physical connected routes.
	if is_debug_map_tour() and destination >= 0 and destination <= 5:
		enter_room(destination)
		return
	if destination == 6 and room_index == 5 and rewarded.has(5):
		if stage_index == 4:
			end_run(true)
			return
		stage_index += 1
		cleared.clear()
		rewarded.clear()
		graph = GraphScript.generate(seed_value, stage_index)
		set_stage_music()
		enter_room(0)
		save_checkpoint()
		return
	# Route stages are traversed directly through their connected collision
	# polygons. Only the post-boss action above may leave the stage; room-to-room
	# travel buttons and portals are intentionally disabled here.
	if is_open_route_stage():
		return
	if GraphScript.can_enter(room_index, destination, cleared, graph):
		enter_room(destination)
		# Save travel only when destination is safe. Entering combat preserves prior completed checkpoint.
		if cleared.has(destination):
			save_checkpoint()

func room_name(index: int) -> String:
	if index == 4: return "Trạm hỗ trợ"
	if index == 5: return "Đấu trường boss"
	if index == 6: return "Khu vực tiếp theo"
	return "Phòng chiến đấu %d" % (index + 1)

func pause_game() -> void:
	if state != "playing":
		return
	state = "paused"
	controls.reset()
	rhythm.pause_music()
	ui.show_pause()

func resume_game() -> void:
	if state not in ["paused", "shop", "map", "settings"]:
		return
	state = "playing"
	controls.reset()
	rhythm.resume_music()
	enemies.resume_grace(maxf(1.4, rhythm.beat_seconds() * 2))
	player.invulnerable = maxf(player.invulnerable, 1.4)
	ui.hide_overlay()

func show_map() -> void:
	if state != "playing":
		return
	state = "map"
	controls.reset()
	rhythm.pause_music()
	if is_assignment_demo():
		ui.show_assignment_demo_info()
	else:
		ui.show_map()

func return_to_menu() -> void:
	state = "menu"
	combat_active = false
	assignment_demo_active = false
	assignment_demo_props.clear()
	controls.reset()
	projectiles.clear()
	enemies.clear()
	player.visible = false
	weapon_system.reset()
	rhythm.resume_music()
	audio.request_intensity("explore")
	ui.show_menu()

func swap_weapon() -> void:
	if weapons.size() <= 1:
		return
	active_slot = (active_slot + 1) % weapons.size()
	weapon_system.cooldown = maxf(weapon_system.cooldown, 0.12)
	flash_text(weapon_system.definition(weapons[active_slot]).name, Color("35e7ff"))

func recall_pistol() -> void:
	weapons[active_slot] = "pistol"
	flash_text("Pulse Pistol · Năng lượng vô hạn", Color("35e7ff"))

func save_checkpoint() -> bool:
	if debug_session:
		return true
	profile.checkpoint = {"seed": seed_value, "stage": stage_index, "room": room_index,
		"cleared": cleared.duplicate(), "rewarded": rewarded.duplicate(), "player": player.snapshot(),
		"coins": coins, "upgrades": upgrades.duplicate(), "weapons": weapons.duplicate(), "elapsed": elapsed,
		"active_slot": active_slot, "run_kills": run_kills, "perfect_count": perfect_count, "starter": starter,
		"has_drone": has_drone, "selected_drone": selected_drone}
	return persist_profile()

func persist_profile() -> bool:
	if test_mode:
		return true
	profile.settings = settings
	if not profile.has("meta") or not profile["meta"] is Dictionary:
		profile["meta"] = {}
	profile.meta["coins"] = coins
	profile.meta["has_drone"] = has_drone
	profile.meta["selected_drone"] = selected_drone
	var success: bool = store.save_profile(profile)
	if not success:
		save_error = "Chưa lưu được. Kiểm tra dung lượng bộ nhớ."
		flash_text(save_error, Color("ff846f"))
	else:
		save_error = ""
	return success

func end_run(victory: bool) -> void:
	if end_recorded:
		return
	end_recorded = true
	combat_active = false
	state = "victory" if victory else "game_over"
	controls.reset()
	projectiles.clear()
	enemies.clear()
	if not debug_session:
		profile.checkpoint = {}
		profile.meta.kills = int(profile.meta.get("kills", 0)) + run_kills
		profile.meta.shards = int(profile.meta.get("shards", 0)) + maxi(1, stage_index * 4 + run_kills / 12) + (12 if victory else 0)
		if victory:
			profile.meta.wins = int(profile.meta.get("wins", 0)) + 1
		persist_profile()
	if victory:
		audio.request_intensity("boss")
		rhythm.resume_music()
	else:
		rhythm.pause_music()
	ui.show_result(victory)

func unlock_weapon(id: String) -> void:
	if profile.meta.unlocked.has(id):
		return
	const WEAPON_COIN_PRICE := 50
	if coins >= WEAPON_COIN_PRICE:
		coins -= WEAPON_COIN_PRICE
		profile.meta.unlocked.append(id)
		audio.play_sfx("buy")
		flash_text("ĐÃ MUA VŨ KHÍ! (-50 COIN)", Color("35e7ff"))
		persist_profile()
		ui.show_unlocks()
		return
	if int(profile.meta.shards) >= 8:
		profile.meta.shards -= 8
		profile.meta.unlocked.append(id)
		audio.play_sfx("buy")
		flash_text("ĐÃ MỞ KHÓA VŨ KHÍ! (-8 MẢNH)", Color("35e7ff"))
		persist_profile()
		ui.show_unlocks()
		return
	flash_text("Cần 50 Coin hoặc 8 Mảnh để mở khóa!", Color("ff846f"))

func select_starter(id: String) -> void:
	if not profile.meta.unlocked.has(id):
		return
	starter = id
	profile.meta.starter = starter
	persist_profile()
	ui.show_unlocks()

const DRONE_PRICES := {
	"plasma": {"coin": 60, "shard": 10},
	"scout": {"coin": 75, "shard": 12},
	"bomb": {"coin": 90, "shard": 14},
	"laser": {"coin": 110, "shard": 16},
	"support": {"coin": 120, "shard": 18},
}

func unlock_drone(id: String) -> bool:
	if not profile.meta.has("unlocked_drones") or not profile.meta.unlocked_drones is Array:
		profile.meta["unlocked_drones"] = []
	if profile.meta.unlocked_drones.has(id):
		select_drone(id, state != "shop")
		return true
	var cost_info: Dictionary = DRONE_PRICES.get(id, {"coin": 60, "shard": 10})
	var coin_cost: int = int(cost_info.coin)
	var shard_cost: int = int(cost_info.shard)
	
	if coins >= coin_cost:
		coins -= coin_cost
		profile.meta.unlocked_drones.append(id)
		select_drone(id, false)
		audio.play_sfx("buy")
		flash_text("ĐÃ MỞ KHÓA DRONE! (-%d COIN)" % coin_cost, Color("35e7ff"))
		if state != "shop":
			ui.show_unlocks()
		return true
	elif int(profile.meta.get("shards", 0)) >= shard_cost:
		profile.meta.shards -= shard_cost
		profile.meta.unlocked_drones.append(id)
		select_drone(id, false)
		audio.play_sfx("buy")
		flash_text("ĐÃ MỞ KHÓA DRONE! (-%d MẢNH)" % shard_cost, Color("35e7ff"))
		if state != "shop":
			ui.show_unlocks()
		return true
	flash_text("Cần %d Coin hoặc %d Mảnh để mở khóa Drone!" % [coin_cost, shard_cost], Color("ff846f"))
	return false

func _sync_checkpoint_drone_selection() -> void:
	var checkpoint: Variant = profile.get("checkpoint", {})
	if not checkpoint is Dictionary or checkpoint.is_empty():
		return
	checkpoint["selected_drone"] = selected_drone
	checkpoint["has_drone"] = has_drone
	profile["checkpoint"] = checkpoint

func select_drone(id: String, refresh_ui: bool = true) -> void:
	if not profile.meta.has("unlocked_drones") or not profile.meta.unlocked_drones is Array:
		profile.meta["unlocked_drones"] = []
	if id == "":
		selected_drone = ""
		has_drone = false
		profile.meta["selected_drone"] = ""
		profile.meta["has_drone"] = false
		_sync_checkpoint_drone_selection()
		if companion_drone != null:
			companion_drone.enabled = false
			companion_drone.visible = false
		persist_profile()
		if refresh_ui:
			ui.show_unlocks()
		return
	if not profile.meta.unlocked_drones.has(id):
		return
	selected_drone = id
	has_drone = true
	profile.meta["selected_drone"] = id
	profile.meta["has_drone"] = true
	_sync_checkpoint_drone_selection()
	if companion_drone != null:
		companion_drone.enabled = true
		companion_drone.visible = true
		companion_drone.set_drone_type(id)
		companion_drone.reset_position()
	persist_profile()
	if refresh_ui:
		ui.show_unlocks()

func on_enemy_killed(enemy: Dictionary) -> void:
	run_kills += 1
	var is_boss: bool = bool(enemy.get("boss", false))
	player.resonance = minf(100, player.resonance + (20 if is_boss else 7))
	
	# Rewarding coin drops: boss: 60-90, elite/heavy: 14-24, normal: 4-8
	var coin_amt: int = 0
	var base_reward: int = int(enemy.get("reward", 4))
	if is_boss:
		coin_amt = rng.randi_range(60, 90)
	elif base_reward >= 10 or bool(enemy.get("elite", false)):
		coin_amt = rng.randi_range(14, 24)
	else:
		coin_amt = rng.randi_range(base_reward + 2, base_reward + 6)
	
	pickups.append({"pos": enemy.pos, "coins": coin_amt, "energy": 5.0, "time": 0.0})
	audio.play_sfx("hit")
	add_fx(enemy.pos, Color("9b4dff"), 25)
	if int(upgrades.get("explosion", 0)) > 0 and rng.randf() < 0.22 * int(upgrades.explosion):
		# Defer chain damage until the enemy iteration has returned.
		call_deferred("death_explosion", enemy.pos)

func death_explosion(at: Vector2) -> void:
	if state != "playing": return
	enemies.damage_in_radius(at, 75, 28)
	add_fx(at, Color("ff846f"), 75)

func update_pickups(delta: float) -> void:
	for index in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[index]
		pickup.time += delta
		var distance: float = pickup.pos.distance_to(player.position)
		if distance < 65 + 50 * int(upgrades.get("magnet", 0)):
			pickup.pos = pickup.pos.move_toward(player.position, delta * 350)
		if distance < 22:
			collect_pickup(pickup)
			pickups.remove_at(index)

func collect_pickup(pickup: Dictionary) -> void:
	var amt: int = int(pickup.coins)
	coins += amt
	player.energy = minf(player.max_energy, player.energy + float(pickup.energy))
	audio.play_sfx("pickup")
	if amt > 0:
		add_fx(pickup.pos, Color("ffd700"), 18.0)

func _on_beat(index: int) -> void:
	if state == "playing" and combat_active:
		enemies.on_beat(index)
		if room_index == 5:
			for unit in enemies.units:
				if unit.boss:
					# A quieter phrase marks phase intermission, switching only on a bar.
					audio.request_intensity("explore" if unit.transition > 0 else "boss")

func move_actor(pos: Vector2, motion: Vector2, body_radius: float) -> Vector2:
	if is_open_route_stage():
		var polygons: Array[PackedVector2Array] = combat_walkable_polygons() if combat_active else walkable_polygons
		return _move_actor_in_polygons(pos, motion, body_radius, polygons)
	var regions: Array[Rect2] = walkable_regions
	return _move_actor_in_regions(pos, motion, body_radius, regions)

func move_combat_actor(pos: Vector2, motion: Vector2, body_radius: float) -> Vector2:
	if is_open_route_stage():
		return _move_actor_in_polygons(pos, motion, body_radius, combat_walkable_polygons())
	return _move_actor_in_regions(pos, motion, body_radius, combat_walkable_regions())

func _move_actor_in_polygons(pos: Vector2, motion: Vector2, body_radius: float, polygons: Array[PackedVector2Array]) -> Vector2:
	var result = pos
	var steps: int = maxi(1, int(ceil(motion.length() / maxf(4, body_radius * 0.7))))
	var step: Vector2 = motion / steps
	for i in range(steps):
		for axis in [0, 1]:
			var attempt = result
			attempt[axis] += step[axis]
			var blocked: bool = not _is_position_in_polygons(attempt, body_radius, polygons) or is_blocked_by_active_combat_barrier(attempt, body_radius)
			for obstacle in obstacles:
				if obstacle.grow(body_radius).has_point(attempt):
					blocked = true
					break
			if not blocked:
				result = attempt
	return result

func _move_actor_in_regions(pos: Vector2, motion: Vector2, body_radius: float, regions: Array[Rect2]) -> Vector2:
	var result = pos
	var steps: int = maxi(1, int(ceil(motion.length() / maxf(4, body_radius * 0.7))))
	var step: Vector2 = motion / steps
	for i in range(steps):
		for axis in [0, 1]:
			var attempt = result
			attempt[axis] += step[axis]
			var blocked: bool = not _is_position_in_regions(attempt, body_radius, regions)
			for obstacle in obstacles:
				if obstacle.grow(body_radius).has_point(attempt):
					blocked = true
					break
			if not blocked:
				result = attempt
	return result

func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	for obstacle in obstacles:
		if obstacle.has_point(from) or obstacle.has_point(to):
			return false
		var corners: Array = [obstacle.position, Vector2(obstacle.end.x, obstacle.position.y), obstacle.end, Vector2(obstacle.position.x, obstacle.end.y)]
		for index in range(4):
			if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % 4]) != null:
				return false
	return true

func add_fx(at: Vector2, color: Color, effect_radius: float) -> void:
	var limit: int = 32 if int(settings.get("quality", 1)) > 0 else 12
	if effects.size() < limit:
		effects.append({"pos": at, "color": color, "radius": effect_radius, "time": 0.35})

func flash_text(message: String, color: Color = Color("35e7ff")) -> void:
	flash_message = message
	flash_color = color
	flash_time = 2.8

func add_damage_number(at: Vector2, amount: float, is_crit: bool = false) -> void:
	if settings.get("reduced_flashes", false):
		return
	var limit: int = 48 if int(settings.get("quality", 1)) > 0 else 20
	if damage_numbers.size() >= limit:
		return
	var color: Color = Color("ff4444") if is_crit else Color("ffffff")
	var text: String = "-%d!" % int(amount) if is_crit else "-%d" % int(amount)
	damage_numbers.append({
		"pos": at + Vector2(randf_range(-10, 10), 0),
		"text": text,
		"color": color,
		"time": 0.85,
		"vel": Vector2(randf_range(-14, 14), -80.0),
	})

func _update_damage_numbers(delta: float) -> void:
	for i in range(damage_numbers.size() - 1, -1, -1):
		var dn: Dictionary = damage_numbers[i]
		dn.time -= delta
		dn.pos += dn.vel * delta
		dn.vel.y += 60 * delta  # gentle gravity
		if dn.time <= 0:
			damage_numbers.remove_at(i)

func draw_effects(canvas: Node2D) -> void:
	if state in ["menu", "game_over", "victory"]:
		return
	for pickup in pickups:
		var at: Vector2 = pickup.pos
		var time: float = float(pickup.get("time", 0.0))
		var is_coin: bool = int(pickup.get("coins", 0)) > 0
		if is_coin:
			var pulse: float = 0.85 + 0.15 * sin(time * 7.0)
			var coin_r: float = 6.0 * pulse
			# Golden neon coin with glow
			canvas.draw_circle(at, coin_r + 3.0, Color("ffd700", 0.22))
			canvas.draw_circle(at, coin_r, Color("ffd700", 0.95))
			canvas.draw_circle(at, coin_r * 0.55, Color("fff59d"))
		else:
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 0), at + Vector2(0, 6), at + Vector2(-5, 0)]), Color("35e7ff"))
	for effect in effects:
		var progress: float = 1.0 - effect.time / 0.35
		var color: Color = effect.color
		color.a = (1 - progress) * (0.45 if settings.get("reduced_flashes", false) else 0.8)
		canvas.draw_arc(effect.pos, maxf(1, effect.radius * progress), 0, TAU, 32, color, 2)
	# Draw floating damage numbers
	if not settings.get("reduced_flashes", false):
		for dn in damage_numbers:
			var alpha: float = clampf(dn.time / 0.85, 0.0, 1.0)
			var scale_t: float = 1.0 - clampf((0.85 - dn.time) / 0.15, 0.0, 1.0)
			var font_size: int = 18 + int(scale_t * 6)
			var col: Color = dn.color
			col.a = alpha
			# Draw shadow for readability
			var shadow := col
			shadow.r = 0; shadow.g = 0; shadow.b = 0; shadow.a = alpha * 0.55
			canvas.draw_string(ThemeDB.fallback_font, dn.pos + Vector2(1, 1), dn.text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, shadow)
			canvas.draw_string(ThemeDB.fallback_font, dn.pos, dn.text,
				HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, col)
	if weapon_system != null:
		for line in weapon_system.beam_lines:
			var duration: float = maxf(0.001, float(line.get("duration", 0.2)))
			var fade: float = clampf(float(line.get("time", 0.0)) / duration, 0.0, 1.0)
			if str(line.get("style", "prism_beam")) == "chain_lightning":
				_draw_chain_lightning(canvas, line, fade)
			else:
				_draw_prism_beam(canvas, line, fade)
		for slash in weapon_system.slash_effects:
			_draw_resonance_slash(canvas, slash)
		for muzzle in weapon_system.muzzle_effects:
			_draw_weapon_muzzle(canvas, muzzle)
		if weapon_system.orbit_time > 0:
			_draw_orbit_driver(canvas)


func _draw_prism_beam(canvas: Node2D, line: Dictionary, fade: float) -> void:
	var from: Vector2 = line.from
	var to: Vector2 = line.to
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length < 0.1:
		return
	var direction: Vector2 = delta / length
	var color: Color = line.get("color", Color("35e7ff"))
	var accent: Color = line.get("accent", Color("f5ffff"))
	var age: float = float(line.get("age", 0.0))
	var phase: float = float(line.get("phase", 0.0))
	canvas.draw_line(from, to, Color(0.02, 0.04, 0.10, 0.72 * fade), 15.0, true)
	canvas.draw_line(from, to, Color(color, 0.18 * fade), 11.0, true)
	canvas.draw_line(from, to, Color(color, 0.68 * fade), 6.0, true)
	canvas.draw_line(from, to, Color(accent, 0.92 * fade), 2.0, true)
	var scan_distance: float = fposmod(age * 980.0 + phase * 40.0, length)
	var scan: Vector2 = from + direction * scan_distance
	_draw_effect_diamond(canvas, scan, direction, 8.0, Color(accent, 0.86 * fade), 1.7)
	_draw_effect_diamond(canvas, to, direction, 9.0, Color(color, 0.80 * fade), 1.5)

func _draw_chain_lightning(canvas: Node2D, line: Dictionary, fade: float) -> void:
	var from: Vector2 = line.from
	var to: Vector2 = line.to
	var delta: Vector2 = to - from
	var length: float = delta.length()
	if length < 0.1:
		return
	var direction: Vector2 = delta / length
	var normal: Vector2 = direction.orthogonal()
	var color: Color = line.get("color", Color("9b4dff"))
	var accent: Color = line.get("accent", Color("f1d8ff"))
	var phase: float = float(line.get("phase", 0.0))
	var points := PackedVector2Array()
	var segments: int = 5
	for index in range(segments + 1):
		var ratio: float = float(index) / float(segments)
		var offset: float = 0.0
		if index > 0 and index < segments:
			offset = sin(phase + elapsed * 42.0 + float(index) * 2.4) * minf(8.0, length * 0.08)
		points.append(from.lerp(to, ratio) + normal * offset)
	canvas.draw_polyline(points, Color(0.05, 0.02, 0.12, 0.68 * fade), 10.0, true)
	canvas.draw_polyline(points, Color(color, 0.30 * fade), 7.0, true)
	canvas.draw_polyline(points, Color(color, 0.86 * fade), 3.0, true)
	canvas.draw_polyline(points, Color(accent, 0.95 * fade), 1.2, true)
	for index in range(1, segments):
		var node: Vector2 = points[index]
		canvas.draw_circle(node, 3.5, Color(color, 0.28 * fade))
		canvas.draw_circle(node, 1.2, Color(accent, 0.95 * fade))
	canvas.draw_circle(from, 4.0, Color(accent, 0.88 * fade))
	canvas.draw_circle(to, 5.0, Color(color, 0.75 * fade))

func _draw_resonance_slash(canvas: Node2D, slash: Dictionary) -> void:
	var duration: float = maxf(0.001, float(slash.get("duration", 0.24)))
	var progress: float = clampf(float(slash.get("time", 0.0)) / duration, 0.0, 1.0)
	var fade: float = 1.0 - progress
	var center: Vector2 = slash.center
	var direction: Vector2 = slash.direction
	var angle: float = direction.angle()
	var radius: float = float(slash.get("radius", 82.0)) * (0.55 + 0.48 * sqrt(progress))
	var sweep: float = 0.72 + progress * 0.44
	var color: Color = slash.get("color", Color("35e7ff"))
	var accent: Color = slash.get("accent", Color("d7a6ff"))
	var start_angle: float = angle - sweep
	var end_angle: float = angle + sweep
	var wedge := PackedVector2Array([center])
	for index in range(13):
		wedge.append(center + Vector2.from_angle(lerpf(start_angle, end_angle, float(index) / 12.0)) * radius)
	canvas.draw_colored_polygon(wedge, Color(color, 0.055 * fade))
	canvas.draw_arc(center, radius, start_angle, end_angle, 20, Color(color, 0.20 * fade), 12.0, true)
	canvas.draw_arc(center, radius, start_angle, end_angle, 20, Color(color, 0.82 * fade), 5.0, true)
	canvas.draw_arc(center, radius - 7.0, start_angle + 0.06, end_angle - 0.06, 18, Color(accent, 0.95 * fade), 1.8, true)
	var tip: Vector2 = center + direction * radius
	_draw_effect_diamond(canvas, tip, direction, 8.0 + progress * 3.0, Color(accent, 0.88 * fade), 1.5)

func _draw_weapon_muzzle(canvas: Node2D, muzzle: Dictionary) -> void:
	var duration: float = maxf(0.001, float(muzzle.get("duration", 0.13)))
	var progress: float = clampf(float(muzzle.get("time", 0.0)) / duration, 0.0, 1.0)
	var fade: float = 1.0 - progress
	var pos: Vector2 = muzzle.pos
	var direction: Vector2 = muzzle.direction
	var normal: Vector2 = direction.orthogonal()
	var color: Color = muzzle.get("color", Color("35e7ff"))
	var accent: Color = muzzle.get("accent", Color("e6f7ff"))
	var visual: String = str(muzzle.get("visual", "pulse_orb"))
	var length: float = 12.0 + progress * 8.0
	match visual:
		"pellet_shard":
			for index in range(-2, 3):
				var spread: float = float(index) * 0.12
				var ray: Vector2 = direction.rotated(spread)
				canvas.draw_line(pos + ray * 3.0, pos + ray * (length + absf(index) * 3.0), Color(accent, 0.78 * fade), 2.0, true)
		"prism_beam", "rail_spear":
			canvas.draw_line(pos - direction * 4.0, pos + direction * length, Color(color, 0.24 * fade), 10.0, true)
			canvas.draw_line(pos, pos + direction * length, Color(accent, 0.88 * fade), 3.0, true)
			_draw_effect_diamond(canvas, pos + direction * length, direction, 6.0, Color(accent, 0.9 * fade), 1.0)
		"echo_disc":
			canvas.draw_arc(pos + direction * 4.0, 9.0 + progress * 3.0, direction.angle() - 1.5, direction.angle() + 1.5, 16, Color(color, 0.82 * fade), 2.0, true)
		"chain_lightning":
			for index in range(4):
				var ray_angle: float = direction.angle() + (float(index) - 1.5) * 0.28
				canvas.draw_line(pos, pos + Vector2.from_angle(ray_angle) * (10.0 + index * 3.0), Color(accent, 0.76 * fade), 1.2, true)
		"sonic_wave":
			for index in range(2):
				canvas.draw_arc(pos + direction * (4.0 + index * 3.0), 7.0 + index * 4.0, direction.angle() - 1.0, direction.angle() + 1.0, 12, Color(color, (0.82 - index * 0.2) * fade), 2.0, true)
		"glitch_charge":
			for index in range(3):
				var offset: float = (float(index) - 1.0) * 4.0
				canvas.draw_line(pos + normal * offset - direction * 3.0, pos + normal * offset + direction * 6.0, Color(accent, (0.8 - index * 0.12) * fade), 1.5, true)
		"orbit_satellite":
			canvas.draw_arc(pos, 8.0 + progress * 3.0, 0.0, TAU, 16, Color(color, 0.7 * fade), 1.5, true)
		"resonance_slash":
			canvas.draw_arc(pos + direction * 4.0, 13.0 + progress * 6.0, direction.angle() - 0.9, direction.angle() + 0.9, 14, Color(accent, 0.85 * fade), 2.0, true)
		"chord_note":
			canvas.draw_circle(pos + direction * 4.0, 4.0 + progress * 2.0, Color(color, 0.62 * fade))
			canvas.draw_arc(pos + direction * 4.0, 8.0 + progress * 2.0, 0.0, TAU, 12, Color(accent, 0.74 * fade), 1.0, true)
		_:
			canvas.draw_line(pos, pos + direction * length, Color(accent, 0.82 * fade), 2.0, true)
	canvas.draw_circle(pos, 3.0 + progress * 2.0, Color(accent, 0.72 * fade))

func _draw_orbit_driver(canvas: Node2D) -> void:
	var remaining: float = clampf(weapon_system.orbit_time / 4.0, 0.0, 1.0)
	var fade: float = minf(1.0, remaining * 2.2)
	var spin: float = weapon_system.orbit_phase + elapsed * 4.5
	var orbit_center: Vector2 = player.position
	canvas.draw_arc(orbit_center, 64.0, spin, spin + TAU, 40, Color("73ffc7", 0.22 * fade), 2.0, true)
	canvas.draw_arc(orbit_center, 58.0, -spin * 0.7, -spin * 0.7 + TAU * 0.62, 20, Color("e2fff4", 0.32 * fade), 1.0, true)
	for index in range(3):
		var angle: float = spin + float(index) * TAU / 3.0
		var at: Vector2 = orbit_center + Vector2.from_angle(angle) * 64.0
		var tangent: Vector2 = Vector2.from_angle(angle + PI * 0.5)
		canvas.draw_line(at - tangent * 10.0, at + tangent * 10.0, Color("73ffc7", 0.22 * fade), 4.0, true)
		_draw_effect_diamond(canvas, at, Vector2.from_angle(angle), 9.0, Color("73ffc7", 0.9 * fade), 1.5)
		canvas.draw_circle(at, 3.0, Color("e2fff4", 0.95 * fade))

func _draw_effect_diamond(canvas: Node2D, center: Vector2, direction: Vector2, length: float, color: Color, width: float) -> void:
	var normal: Vector2 = direction.orthogonal()
	var points := PackedVector2Array([
		center + direction * length,
		center + normal * (length * 0.42),
		center - direction * length,
		center - normal * (length * 0.42),
		center + direction * length,
	])
	canvas.draw_polyline(points, color, width, true)
