class_name RoomView
extends Node2D

const TERMINAL_BACKDROP: Texture2D = preload("res://assets/backgrounds/echo_terminal_backdrop.png")
# This atlas restores the authored route one room/corridor crop at a time, then
# feathers the crops back over the original layout. It preserves the map rather
# than replacing walls or floors with a generic material.
const TERMINAL_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/echo_terminal_route_background_tiled_restored_hd.png")
# Area 2 owns an authored amber route plate as well. It is drawn from the same
# native map that its continuous collision polygons use in Main.
const BASS_FOUNDRY_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/bass_foundry_route_background_concept_v5_amber_foundry_tiled_restored_hd.png")
# Luminous Grove uses the user-approved complete HD atlas as one texture.
# This draw never adds a runtime overlay; collision stays in the native
# 1448 × 1086 art space.
const LUMINOUS_GROVE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/luminous_grove_route_background_user_final_fixed_hd_v29.png")
# Prism Spire uses the user-supplied 4x-native route atlas. Its 4:3 aspect
# ratio matches the 1448 x 1086 collision-authoring plate exactly, so drawing
# it into `arena` does not change the playable route.
const PRISM_SPIRE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/prism_spire_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v4.png")
# SILENT CORE uses the user-supplied 4x-native route atlas. Its 4:3 aspect
# ratio matches the 1448 x 1086 collision-authoring plate exactly, so drawing
# it into `arena` does not change the playable route.
const SILENT_CORE_ROUTE_BACKDROP: Texture2D = preload("res://assets/backgrounds/silent_core_route_background_concept_v1_refined_room_detail_safe_junctions_hd_v2.png")
# Each support room keeps its existing gameplay station, but receives a distinct
# transparent chest prop that belongs to that area's visual language.
const ECHO_TERMINAL_SUPPORT_CHEST: Texture2D = preload("res://assets/props/support_chests/echo_terminal_support_chest_v1.png")
const BASS_FOUNDRY_SUPPORT_CHEST: Texture2D = preload("res://assets/props/support_chests/bass_foundry_support_chest_v1.png")
const LUMINOUS_GROVE_SUPPORT_CHEST: Texture2D = preload("res://assets/props/support_chests/luminous_grove_support_chest_v1.png")
const PRISM_SPIRE_SUPPORT_CHEST: Texture2D = preload("res://assets/props/support_chests/prism_spire_support_chest_v1.png")
const SILENT_CORE_SUPPORT_CHEST: Texture2D = preload("res://assets/props/support_chests/silent_core_support_chest_v1.png")
# One shared gate silhouette for every region. The artwork remains identical
# everywhere; only the runtime reveal, rings and sparks animate it.
const TELEPORT_GATE_COMMON: Texture2D = preload("res://assets/props/warp_gates/teleport_gate_common_blue_v1.png")

const SUPPORT_CHEST_DISPLAY_SIZE := Vector2(104.0, 84.0)
const WARP_GATE_DISPLAY_SIZE := Vector2(75.0, 97.0)
const WARP_GATE_EFFECT_SCALE := 0.5
# Combat gates and the authoritative map-boundary overlay use the same outer
# stroke so a closed corridor reads as part of the map, not as a thick prop.
const MAP_BOUNDARY_STROKE_WIDTH := 3.0
const COMBAT_BARRIER_STROKE_WIDTH := MAP_BOUNDARY_STROKE_WIDTH

var game
var tick: float = 0
var decoration_seed: int = 0

func setup(owner_game) -> void:
	game = owner_game
	# The composition-locked restored source is denser than the gameplay viewport,
	# Nearest keeps the enlarged route atlas free of final interpolation haze.
	# Mip levels only engage for the much denser local tile when it is minified,
	# preventing its fine vine/plate marks from sparkling during camera movement.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	# Mirroring makes the local material continuous at every tile edge.  Full route
	# backdrops retain their normal 0..1 UV range, so this does not alter them.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR

func _process(delta: float) -> void:
	tick += delta
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var accent = Color(game.content.stages[game.stage_index].color)
	var frame_only: bool = game.is_open_route_stage()
	if frame_only:
		# The complete authored map remains the visible source for both floor and
		# wall detail. Collision polygons below only communicate route state.
		var backdrop: Texture2D = TERMINAL_ROUTE_BACKDROP
		match game.stage_index:
			0: backdrop = TERMINAL_ROUTE_BACKDROP
			1: backdrop = BASS_FOUNDRY_ROUTE_BACKDROP
			2: backdrop = LUMINOUS_GROVE_ROUTE_BACKDROP
			3: backdrop = PRISM_SPIRE_ROUTE_BACKDROP
			4: backdrop = SILENT_CORE_ROUTE_BACKDROP
		draw_texture_rect(backdrop, game.arena, false)
	else:
		draw_rect(game.arena, Color("0b0718"))
		# The camera can reveal the whole room; keep the outer space dark between branches.
		for x in range(int(game.arena.position.x), int(game.arena.end.x), 64):
			draw_line(Vector2(x, game.arena.position.y), Vector2(x + 80, game.arena.end.y), Color("130d28"), 1)
	if frame_only:
		for route_region in game.route_regions():
			draw_level_one_region(route_region.polygon, accent, game.is_route_room_open(int(route_region.room)), game.show_route_boundaries)
	else:
		for region in game.walkable_regions:
			draw_rect(Rect2(region.position + Vector2(0, 12), region.size), Color("03020a"))
			draw_rect(region.grow(9), Color("211638"))
			draw_rect(region.grow(3), accent.darkened(0.6), false, 2)
			draw_rect(region, Color("100d22"))
			for row in range(int(ceil(region.size.y / 32.0))):
				for column in range(int(ceil(region.size.x / 32.0))):
					var p = region.position + Vector2(column * 32, row * 32)
					var shade: String = "17122d" if (row + column) % 2 == 0 else "151029"
					draw_rect(Rect2(p + Vector2.ONE, Vector2(30, 30)), Color(shade))
	if not frame_only:
		match game.stage_index:
			2: draw_grove(accent)
			3: draw_spire(accent)
			4: draw_core(accent)
	for obstacle in game.obstacles:
		draw_rect(Rect2(obstacle.position + Vector2(6, 10), obstacle.size), Color(0, 0, 0, 0.4))
		var obstacle_fill := Color("29203d")
		if game.stage_index == 0:
			obstacle_fill = Color("202344")
		draw_rect(obstacle, obstacle_fill)
		var obstacle_led := accent.darkened(0.52)
		if game.stage_index == 0:
			obstacle_led = Color("347dff")
		draw_rect(Rect2(obstacle.position, Vector2(obstacle.size.x, 7)), obstacle_led)
		draw_rect(obstacle.grow(-6), Color("1b162f"), false, 2)
		draw_rect(Rect2(obstacle.position + Vector2(8, 11), Vector2(minf(16, obstacle.size.x - 16), 4)), accent.darkened(0.2))
		if game.stage_index == 0:
			# Modular cyan LED strips make collision blocks read as station hardware.
			var strip_color := Color("35e7ff")
			strip_color.a = 0.78
			draw_line(obstacle.position + Vector2(8, obstacle.size.y - 8), obstacle.end - Vector2(8, 8), strip_color, 2)
			for x in range(int(obstacle.position.x) + 14, int(obstacle.end.x) - 8, 28):
				draw_rect(Rect2(x, obstacle.position.y + 15, 12, 3), Color("9b87ff", 0.7))
		elif game.stage_index == 1:
			for y in range(int(obstacle.position.y) + 12, int(obstacle.end.y) - 5, 13):
				draw_line(Vector2(obstacle.position.x + 5, y), Vector2(obstacle.end.x - 5, y), Color("4a3448"), 3)
		elif game.stage_index == 2:
			draw_line(obstacle.get_center(), obstacle.get_center() + Vector2(0, -25), Color("32666a"), 6)
			draw_colored_polygon(PackedVector2Array([obstacle.get_center() + Vector2(-19, -20), obstacle.get_center() + Vector2(0, -45), obstacle.get_center() + Vector2(20, -20)]), Color("305568"))
		elif game.stage_index == 3:
			draw_line(obstacle.position + Vector2(5, 5), obstacle.end - Vector2(5, 5), Color("4b5e87"), 3)
	if game.is_assignment_demo():
		draw_assignment_demo_room()
	draw_collision_boundaries()
	draw_combat_barriers()
	for portal in game.portals:
		var portal_kind: String = str(portal.get("kind", ""))
		if portal_kind == "boss_exit" or portal_kind == "debug_exit":
			draw_boss_exit_portal(portal)
			continue
		var at: Vector2 = portal.pos
		var open: bool = not game.combat_active
		var color = accent if open else Color("ff846f").darkened(0.4)
		draw_rect(Rect2(at - Vector2(18, 32), Vector2(36, 64)), Color("080814"))
		draw_rect(Rect2(at - Vector2(18, 32), Vector2(36, 64)), color, false, 3)
		if open:
			draw_line(at + Vector2(-8, -10), at + Vector2(6, 0), color, 3)
			draw_line(at + Vector2(6, 0), at + Vector2(-8, 10), color, 3)
		else:
			draw_line(at + Vector2(-10, -20), at + Vector2(10, 20), color, 3)
			draw_line(at + Vector2(10, -20), at + Vector2(-10, 20), color, 3)
	if game.room_index == 4:
		draw_support_chest(game.support_station_position(), accent)

func draw_boss_exit_portal(portal: Dictionary) -> void:
	var at: Vector2 = portal.pos
	var appear: float = float(game.exit_portal_appear_progress())
	# Ease the device from a small core into its final silhouette. RoomView's
	# independent tick keeps the idle rings alive even while the reward overlay
	# is shown after the boss defeat.
	var eased: float = 1.0 - pow(1.0 - appear, 3.0)
	var pulse: float = sin(tick * 4.2) * 0.5 + 0.5
	var spin: float = tick * 1.75
	# Once fully visible, the gate keeps its place but breathes very slightly
	# while the inner rings and sparks continue to circulate.
	var idle_breathe: float = 1.0 + sin(tick * 2.15) * 0.018 if appear >= 1.0 else 1.0
	var gate_scale: float = lerpf(0.18, 1.0, eased) * idle_breathe
	var gate_size: Vector2 = WARP_GATE_DISPLAY_SIZE * gate_scale
	var alpha: float = lerpf(0.0, 1.0, eased)
	var energy_cyan := Color("37eaff")
	var floor_glow: Color = Color(energy_cyan, (0.05 + pulse * 0.08) * alpha)
	draw_circle(at + Vector2(0, 18) * WARP_GATE_EFFECT_SCALE, (50.0 + pulse * 7.0) * gate_scale * WARP_GATE_EFFECT_SCALE, floor_glow)
	var ring_color: Color = Color(energy_cyan.lightened(0.18), (0.28 + pulse * 0.26) * alpha)
	draw_arc(at + Vector2(0, 12) * WARP_GATE_EFFECT_SCALE, (46.0 + pulse * 5.0) * gate_scale * WARP_GATE_EFFECT_SCALE, spin, spin + TAU * 0.78, 40, ring_color, 1.4)
	draw_arc(at + Vector2(0, 12) * WARP_GATE_EFFECT_SCALE, (33.0 - pulse * 2.0) * gate_scale * WARP_GATE_EFFECT_SCALE, -spin * 1.4, -spin * 1.4 + TAU * 0.64, 32, Color("eafcff", 0.48 * alpha), 1.0)
	var gate_rect: Rect2 = Rect2(at - gate_size * 0.5 + Vector2(0, -12.0 * gate_scale * WARP_GATE_EFFECT_SCALE), gate_size)
	draw_texture_rect(TELEPORT_GATE_COMMON, gate_rect, false, Color(1.0, 1.0, 1.0, alpha))
	if appear >= 1.0:
		for index in range(4):
			var angle: float = spin + TAU * float(index) / 4.0
			var spark: Vector2 = at + Vector2(cos(angle), sin(angle) * 0.65) * (58.0 + pulse * 5.0) * WARP_GATE_EFFECT_SCALE
			draw_circle(spark, 1.0 + pulse * 0.5, Color(energy_cyan.lightened(0.35), 0.76))

func support_chest_texture() -> Texture2D:
	match game.stage_index:
		0:
			return ECHO_TERMINAL_SUPPORT_CHEST
		1:
			return BASS_FOUNDRY_SUPPORT_CHEST
		2:
			return LUMINOUS_GROVE_SUPPORT_CHEST
		3:
			return PRISM_SPIRE_SUPPORT_CHEST
		4:
			return SILENT_CORE_SUPPORT_CHEST
	return ECHO_TERMINAL_SUPPORT_CHEST

func draw_support_chest(station: Vector2, accent: Color) -> void:
	# This is visual-only: the established interaction radius and navigation
	# remain owned by Main, so a larger illustration cannot alter collision.
	var pulse := sin(tick * 3.2) * 0.5 + 0.5
	var floor_glow := Color(accent, 0.09 + pulse * 0.06)
	draw_circle(station + Vector2(0, 14), 45.0 + pulse * 4.0, floor_glow)
	var ring_color := Color(accent, 0.27 + pulse * 0.18)
	if game.support_purchased:
		ring_color = Color("a9b7ca", 0.18)
	draw_arc(station + Vector2(0, 14), 40.0 + pulse * 2.0, 0.0, TAU, 32, ring_color, 1.5)
	var chest_rect := Rect2(station - SUPPORT_CHEST_DISPLAY_SIZE * 0.5 + Vector2(0, -8), SUPPORT_CHEST_DISPLAY_SIZE)
	draw_texture_rect(support_chest_texture(), chest_rect, false)
	if game.support_purchased:
		draw_arc(station + Vector2(0, 14), 21.0, 0.0, TAU, 24, Color("e6f7ff", 0.42), 1.0)

func draw_level_one_region(polygon: PackedVector2Array, accent: Color, is_open: bool, show_outline: bool) -> void:
	# This is the cyan/purple frame painted over the playable map, not the
	# collision-data overlay or the Boundary Editor. Hiding it must leave the
	# background, room topology and movement polygons unchanged.
	if not show_outline:
		return
	var outline: PackedVector2Array = polygon.duplicate()
	outline.append(polygon[0])
	if is_open:
		# The frame follows the same floor polygon used by player collision. This
		# prevents a rectangular frame from advertising walkable empty corners.
		draw_colored_polygon(polygon, Color(0.015, 0.04, 0.08, 0.15))
		var outer_edge := Color(accent, 0.78)
		draw_polyline(outline, outer_edge, 2.0)
		var inner_edge := Color("fff1ad", 0.2) if game.stage_index == 1 else Color("b8f8ff", 0.18)
		draw_polyline(outline, inner_edge, 1.0)
		return
	# Locked areas remain visible as a route preview, but the red dashed boundary
	# and muted fill distinguish them from a place the player may enter now.
	draw_colored_polygon(polygon, Color(0.08, 0.015, 0.035, 0.65))
	var locked_edge := Color("ff605c", 0.82)
	for edge in range(polygon.size()):
		draw_dashed_line(polygon[edge], polygon[(edge + 1) % polygon.size()], locked_edge, 2.0, 10.0)

func draw_collision_boundaries() -> void:
	if not game.show_collision_boundaries:
		return
	var fill := Color("ffe56b", 0.12)
	var outline := Color("fff3a0", 0.96)
	if game.is_open_route_stage():
		var polygons: Array[PackedVector2Array] = game.combat_walkable_polygons() if game.combat_active else game.walkable_polygons
		for polygon in polygons:
			if polygon.size() < 3:
				continue
			var closed_outline: PackedVector2Array = polygon.duplicate()
			closed_outline.append(polygon[0])
			draw_colored_polygon(polygon, fill)
			draw_polyline(closed_outline, outline, MAP_BOUNDARY_STROKE_WIDTH, true)
		return
	var regions: Array[Rect2] = game.combat_walkable_regions() if game.combat_active else game.walkable_regions
	for region in regions:
		draw_rect(region, fill)
		draw_rect(region, outline, false, MAP_BOUNDARY_STROKE_WIDTH)

func draw_combat_barriers() -> void:
	# Every gate authored for this map appears while an encounter is active. This
	# keeps the whole connected route visibly locked until its current enemies are
	# cleared, even when a gate was placed at an earlier room boundary.
	var barriers: Array[Rect2] = game.active_combat_barrier_rects()
	if barriers.is_empty():
		return
	var beat_pulse := sin(tick * 6.4) * 0.5 + 0.5
	var warning := Color("ff4e59")
	for gate in barriers:
		# A gate is deliberately rendered as a single thin bar on its long axis.
		# The thin Rect2 kept in data only records its placement and orientation;
		# it is no longer shown as a bulky object that obscures the corridor.
		var center := gate.get_center()
		var from: Vector2
		var to: Vector2
		if gate.size.y > gate.size.x:
			from = Vector2(center.x, gate.position.y)
			to = Vector2(center.x, gate.end.y)
		else:
			from = Vector2(gate.position.x, center.y)
			to = Vector2(gate.end.x, center.y)
		# Keep the gate's maximum footprint exactly equal to a map boundary. The
		# overlapping colour layers pulse without widening the single red bar.
		draw_line(from, to, Color("07040a", 0.90), COMBAT_BARRIER_STROKE_WIDTH, true)
		draw_line(from, to, Color(warning, 0.64 + beat_pulse * 0.20), COMBAT_BARRIER_STROKE_WIDTH, true)
		draw_line(from, to, Color("ffb4a8", 0.84 + beat_pulse * 0.10), 1.0, true)


func draw_assignment_demo_room() -> void:
	# The floor remains deliberately simple: the presentation must let a teacher
	# read the forbidden area and X/Y/Z collision objects at a glance.
	var zone: Rect2 = game.assignment_forbidden_zone
	var pulse := sin(tick * 7.0) * 0.5 + 0.5
	draw_rect(zone, Color("6b1327", 0.30 + pulse * 0.10))
	draw_rect(zone, Color("ff4e59", 0.88), false, 3.0)
	for x in range(int(zone.position.x) + 12, int(zone.end.x) - 8, 28):
		draw_line(Vector2(x, zone.position.y + 8), Vector2(x - 18, zone.end.y - 8), Color("ff796d", 0.38), 4.0)
	for prop: Dictionary in game.assignment_demo_props:
		var id: String = str(prop.get("id", "?"))
		var at: Vector2 = prop.get("pos", Vector2.ZERO)
		var color := Color("35e7ff")
		if id == "Y":
			color = Color("9b4dff")
		elif id == "Z":
			color = Color("ff846f")
		draw_circle(at + Vector2(0, 7), 34.0, Color(0.0, 0.0, 0.0, 0.42))
		draw_circle(at, 30.0 + pulse * 2.0, Color(color, 0.18))
		draw_circle(at, 27.0, Color("100b1d"))
		draw_arc(at, 29.0, 0.0, TAU, 28, color, 2.5)
		var id_width: float = game.ui.bold.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string(game.ui.bold, at + Vector2(-id_width * 0.5, 8), id, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
		draw_string(game.ui.font, at + Vector2(-90, 53), str(prop.get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, 180, 14, Color("d9efff"))
	if game.assignment_shield_time > 0.0:
		var shield_color := Color("35e7ff", 0.40 + pulse * 0.28)
		draw_circle(game.player.position, 48.0 + pulse * 4.0, Color(shield_color, 0.10))
		draw_arc(game.player.position, 48.0 + pulse * 4.0, 0.0, TAU, 30, shield_color, 2.5)
	if game.assignment_emp_time > 0.0:
		draw_arc(game.player.position, 280.0 + pulse * 18.0, 0.0, TAU, 48, Color("d65dff", 0.45), 2.0)

func draw_terminal(accent: Color) -> void:
	if TERMINAL_BACKDROP != null:
		draw_terminal_beat_overlay(accent)
		return
	for y in [230, 472]:
		draw_rect(Rect2(68, y, 1144, 34), Color("141e35"))
		for x in range(72, 1210, 26):
			draw_rect(Rect2(x, y + 7, 10, 20), Color("27304a"))
		draw_line(Vector2(68, y + 4), Vector2(1212, y + 4), accent.darkened(0.65), 2)
		draw_line(Vector2(68, y + 30), Vector2(1212, y + 30), accent.darkened(0.65), 2)
	for x in [210, 610, 1010]:
		draw_rect(Rect2(x, 115, 120, 19), Color("30154f"))
		for bar in range(8):
			draw_rect(Rect2(x + 8 + bar * 13, 121, 8, 6), accent.darkened(0.45 + (bar % 3) * 0.12))

func draw_terminal_beat_overlay(accent: Color) -> void:
	# The generated plate supplies the authored architecture; these light pulses
	# make it feel alive and keep the music identity visible during combat.
	var beat_wave: float = sin(tick * 4.0) * 0.5 + 0.5
	var pulse_color := Color("35e7ff")
	pulse_color.a = 0.18 + beat_wave * 0.2
	for center in [Vector2(250, 430), Vector2(1798, 430)]:
		draw_arc(center, 78.0 + beat_wave * 12.0, 0.0, TAU, 48, pulse_color, 2.0)
		draw_arc(center, 102.0 + beat_wave * 18.0, 0.0, TAU, 48, Color("9b87ff", 0.12 + beat_wave * 0.1), 2.0)
	var waveform := PackedVector2Array()
	for i in range(48):
		var x: float = 80.0 + i * 40.0
		var y: float = 552.0 + sin(tick * 3.2 + i * 0.72) * (4.0 + beat_wave * 10.0)
		waveform.append(Vector2(x, y))
	draw_polyline(waveform, Color("9b87ff", 0.18 + beat_wave * 0.18), 2.0)
	for y in [132.0, 892.0]:
		for i in range(18):
			var x: float = 110.0 + i * 106.0
			var height: float = 4.0 + (sin(tick * 3.0 + i * 0.9) * 0.5 + 0.5) * 13.0
			draw_rect(Rect2(x, y - height * 0.5, 30, height), Color("35e7ff", 0.22 + beat_wave * 0.25))
	# Accent the existing stage color without losing the shared blue-violet identity.
	var edge := accent
	edge.a = 0.28
	draw_line(Vector2(68, 104), Vector2(1980, 104), edge, 2.0)
	draw_line(Vector2(68, 920), Vector2(1980, 920), edge, 2.0)

func draw_foundry(accent: Color) -> void:
	for x in [300, 850]:
		draw_rect(Rect2(x, 118, 65, 468), Color("211c2b"))
		for y in range(125, 585, 26):
			var offset: float = fmod(tick * 14, 26)
			draw_line(Vector2(x + 8, y + offset), Vector2(x + 56, y + offset), Color("38314d"), 4)
	for x in range(100, 1200, 100):
		draw_circle(Vector2(x, 133), 12, accent.darkened(0.7))
		draw_circle(Vector2(x, 133), 6, Color("0b0718"))

func draw_grove(accent: Color) -> void:
	for at in [Vector2(175, 165), Vector2(1040, 515), Vector2(810, 195)]:
		draw_set_transform(at, 0, Vector2(1.8, 0.75))
		draw_circle(Vector2.ZERO, 42, Color("112536"))
		draw_arc(Vector2.ZERO, 31, 0, TAU, 18, accent.darkened(0.8), 1)
		draw_set_transform(Vector2.ZERO)
	for i in range(24):
		var at = Vector2(95 + (i * 139) % 1090, 140 + (i * 83) % 410)
		draw_line(at, at + Vector2(0, -9), Color("285457"), 2)
		draw_rect(Rect2(at + Vector2(-3, -12), Vector2(7, 5)), accent.darkened(0.65))

func draw_spire(accent: Color) -> void:
	for x in range(100, 1200, 170):
		draw_line(Vector2(x, 117), Vector2(1280 - x, 586), Color("202941"), 1)
	for x in [90, 1160]:
		for y in range(165, 580, 120):
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 20, y + 25), Vector2(x, y + 50), Vector2(x - 20, y + 25)]), accent.darkened(0.74))

func draw_core(accent: Color) -> void:
	for radius in [80, 150, 230]:
		draw_arc(Vector2(640, 350), radius, 0, TAU, 64, accent.darkened(0.78), 2)
	for i in range(12):
		var direction = Vector2.from_angle(i * TAU / 12)
		draw_line(Vector2(640, 350) + direction * 90, Vector2(640, 350) + direction * 225, Color("2a1c3e"), 2)
	if not game.settings.get("reduced_flashes", false):
		for i in range(8):
			var x: float = fmod(tick * 11 + i * 179, 1100) + 70
			draw_rect(Rect2(x, 140 + i * 57, 32, 2), Color("2f1c42"))
