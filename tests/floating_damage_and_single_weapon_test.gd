extends SceneTree

func _init() -> void:
	print("[TEST] Initializing Floating Damage Numbers & Single-Weapon Inventory Test...")
	var main_scene = load("res://scenes/main.tscn")
	var game = main_scene.instantiate()
	root.add_child(game)
	
	await process_frame
	await process_frame
	
	game.new_run(9999)
	await process_frame
	
	# -------------------------------------------------------------
	# 1. Single Weapon Slot Verification
	# -------------------------------------------------------------
	assert(game.weapons.size() == 1, "Weapons array must contain exactly 1 weapon slot!")
	assert(game.active_slot == 0, "Active slot must be 0 for single weapon loadout!")
	assert(game.weapons[0] == game.starter, "Single weapon must match equipped starter!")
	print("[PASS] Single weapon inventory verified: ", game.weapons)
	
	# Verify weapon swapping is a no-op (player cannot carry 2 or 3 weapons)
	game.swap_weapon()
	assert(game.weapons.size() == 1, "Weapons array remains single-slot after swap attempt")
	assert(game.active_slot == 0, "Active slot remains 0")
	print("[PASS] Weapon swap is safely disabled in single-weapon mode")
	
	# -------------------------------------------------------------
	# 2. Floating Damage Numbers Verification
	# -------------------------------------------------------------
	assert(game.damage_numbers.is_empty(), "Damage numbers array should start empty")
	
	# Spawn a test enemy
	game.enemies._spawn("rusher", Vector2(400, 300), false)
	assert(game.enemies.units.size() > 0, "Enemy should be spawned")
	var test_enemy = game.enemies.units[0]
	test_enemy.spawn_grace = 0.0
	var enemy_id = test_enemy.id
	
	# Deal damage to enemy
	game.enemies.damage_enemy(enemy_id, 35.0)
	assert(game.damage_numbers.size() > 0, "Damage number must be spawned after hitting enemy!")
	var dn = game.damage_numbers[0]
	assert(dn.text == "-35", "Damage text should display correct rounded damage: %s" % dn.text)
	assert(dn.time > 0.0, "Damage number must have positive lifespan")
	assert(dn.vel.y < 0, "Damage number must float upward (negative y velocity)")
	print("[PASS] Floating damage number generated successfully: ", dn.text, " at ", dn.pos)
	
	# Test critical / exposed damage formatting
	test_enemy.exposed = 2.0
	game.enemies.damage_enemy(enemy_id, 20.0)
	var crit_dn = game.damage_numbers[game.damage_numbers.size() - 1]
	assert(crit_dn.text.ends_with("!"), "Crit/exposed damage should have exclamation point: %s" % crit_dn.text)
	assert(crit_dn.color == Color("ff4444"), "Crit/exposed damage number should be colored red")
	print("[PASS] Critical floating damage number verified: ", crit_dn.text)
	
	# Test update loop - numbers float and expire
	var initial_y = dn.pos.y
	game._update_damage_numbers(0.2)
	assert(dn.pos.y < initial_y, "Damage number should move upward during update")
	
	# Expire damage number
	game._update_damage_numbers(1.5)
	assert(game.damage_numbers.is_empty(), "Damage numbers should expire after lifetime")
	print("[PASS] Floating damage numbers float upward and expire properly")
	
	# -------------------------------------------------------------
	# 3. Armory Coin-Locked Weapon System Verification
	# -------------------------------------------------------------
	game.ui.show_unlocks()
	await process_frame
	
	# Verify non-starter weapons are locked
	var smg_state = game.ui.armory_loadout_state(false, false, game.profile.meta.unlocked.has("smg"))
	if not game.profile.meta.unlocked.has("smg"):
		assert(smg_state == WeaponLoadoutState.State.LOCKED, "SMG must be locked if not purchased")
		var price_text = game.ui.armory_loadout_text(smg_state, true)
		assert("50" in price_text or "🪙" in price_text, "Armory must display 50 Coin price for locked weapons")
		print("[PASS] Armory locked weapon displays coin price: ", price_text)
	
	print("[ALL FLOATING DAMAGE & SINGLE WEAPON TESTS PASSED!]")
	game.queue_free()
	quit(0)
