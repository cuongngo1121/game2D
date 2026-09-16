extends SceneTree
## The authored overhead frames face local up, while weapons use local right.
## Keep their visual forward axes aligned for every desktop aim direction.

const PlayerScript = preload("res://scripts/player/player.gd")

func _initialize() -> void:
	var player = PlayerScript.new()
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		player.aim_direction = direction
		var expected_angle: float = direction.angle() + PI * 0.5
		if not is_equal_approx(player.pixel_character_draw_angle(), expected_angle):
			push_error("Overhead character artwork faces the same direction as its weapon for %s aim" % direction)
			player.free()
			quit(1)
			return
	var hand_position: Vector2 = player.pixel_character_right_hand_position()
	var grip_position: Vector2 = player.pixel_weapon_grip_position()
	if hand_position.distance_to(grip_position) > 1.0:
		push_error("Weapon rear grip stays within one pixel of the character's right-hand anchor")
		player.free()
		quit(1)
		return
	player.position = Vector2(320, 240)
	player.aim_direction = Vector2.RIGHT
	var muzzle_position: Vector2 = player.weapon_muzzle_position()
	if player.weapon_projectile_spawn_position().distance_to(muzzle_position) > 1.0 or player.weapon_beam_origin().distance_to(muzzle_position) > 1.0:
		push_error("Projectile and beam origins match the visible muzzle instead of the player center")
		player.free()
		quit(1)
		return
	player.free()
	quit(0)
