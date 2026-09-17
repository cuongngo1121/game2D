extends SceneTree
## Verifies that every player weapon reaches its authored projectile/effect model.

const MainScene = preload("res://scenes/main.tscn")

var game
var checks: int = 0
var failures: Array[String] = []

const EXPECTED_VISUALS := {
	"pistol": "pulse_orb",
	"smg": "needle_burst",
	"shotgun": "pellet_shard",
	"rail": "rail_spear",
	"beam": "prism_beam",
	"disc": "echo_disc",
	"arc": "chain_lightning",
	"wave": "sonic_wave",
	"glitch": "glitch_charge",
	"orbit": "orbit_satellite",
	"blade": "resonance_slash",
	"chord": "chord_note",
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = MainScene.instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.new_run(20260917)
	game.set_physics_process(false)
	game.controls.set_process(false)
	game.controls.set_physics_process(false)
	_test_data_contract()
	_test_each_weapon_visual()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROJECTILE VISUAL PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PROJECTILE VISUAL FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _test_data_contract() -> void:
	var ids: Array[String] = []
	for weapon in game.content.weapons:
		var id: String = str(weapon.id)
		ids.append(id)
		_check(EXPECTED_VISUALS.has(id), "%s declares a dedicated projectile visual" % id)
		_check(str(weapon.get("visual", "")) == EXPECTED_VISUALS.get(id, ""), "%s data visual matches the renderer contract" % id)
		_check(str(weapon.get("visual_color", "")) != "" and str(weapon.get("visual_accent", "")) != "", "%s declares primary and accent colors" % id)
	_check(ids.size() == 12 and EXPECTED_VISUALS.size() == 12, "The content contract covers exactly twelve weapons")

func _test_each_weapon_visual() -> void:
	for weapon in game.content.weapons:
		var id: String = str(weapon.id)
		game.projectiles.clear()
		game.weapon_system.reset()
		game.weapons = [id, "pistol"]
		game.active_slot = 0
		game.player.energy = game.player.max_energy
		game.weapon_system.cooldown = 0.0
		var muzzle_before: int = game.weapon_system.muzzle_effects.size()
		_check(game.weapon_system.fire(), "%s fires through the real weapon system" % id)
		_check(game.weapon_system.muzzle_effects.size() > muzzle_before and game.weapon_system.muzzle_effects.back().visual == EXPECTED_VISUALS[id], "%s creates its authored muzzle model" % id)
		if id == "beam":
			_check(not game.weapon_system.beam_lines.is_empty() and game.weapon_system.beam_lines.back().style == "prism_beam", "Prism Beam creates the layered beam effect")
		elif id == "arc":
			_check(not game.weapon_system.beam_lines.is_empty() or not game.enemies.units.is_empty(), "Arc Conductor has a live target/effect route")
		elif id == "orbit":
			_check(game.weapon_system.orbit_time > 0.0 and game.weapon_system.orbit_phase != 0.0, "Orbit Driver creates a timed orbit field")
		elif id == "blade":
			_check(not game.weapon_system.slash_effects.is_empty() and game.weapon_system.slash_effects.back().color == Color(str(weapon.visual_color)), "Resonance Blade creates a crescent slash effect")
		else:
			if id == "chord":
				game.weapon_system.update(0.001)
			_check(game.projectiles.count() > 0, "%s creates a live projectile" % id)
			if game.projectiles.count() > 0:
				var shot: Dictionary = game.projectiles.active.back()
				_check(str(shot.visual) == EXPECTED_VISUALS[id], "%s projectile uses its authored shape" % id)
				_check(shot.trail.size() >= 1 and shot.accent == Color(str(weapon.visual_accent)), "%s projectile owns trail and accent data" % id)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
