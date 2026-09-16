extends SceneTree
## A player must be able to read every CONDUCTOR-01 Hurt frame immediately.
## In particular, the first hit cannot resolve to an unchanged copy of the
## standing model, because the short boss-hurt pulse begins on frame zero.

const MODEL: Texture2D = preload("res://assets/sprites/pixel_64/bosses/conductor_01/conductor_01_model_64.png")
const HURT_FRAMES: Array[Texture2D] = [
	preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_hurt_3x64_0.png"),
	preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_hurt_3x64_1.png"),
	preload("res://assets/sprites/pixel_64/bosses/conductor_01/animations/conductor_01_hurt_3x64_2.png"),
]

const MIN_VISIBLE_PIXEL_DIFFERENCE := 24

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for frame_index in HURT_FRAMES.size():
		var changed_pixels := _changed_pixel_count(MODEL.get_image(), HURT_FRAMES[frame_index].get_image())
		_check(
			changed_pixels >= MIN_VISIBLE_PIXEL_DIFFERENCE,
			"CONDUCTOR-01 hurt frame %d visibly differs from its standing model (%d changed pixels)" % [frame_index, changed_pixels]
		)
	if failures.is_empty():
		print("CONDUCTOR-01 HURT VISIBILITY PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("CONDUCTOR-01 HURT VISIBILITY FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _changed_pixel_count(reference: Image, candidate: Image) -> int:
	if reference.get_size() != candidate.get_size():
		return 0
	var changed := 0
	for y in reference.get_height():
		for x in reference.get_width():
			if reference.get_pixel(x, y) != candidate.get_pixel(x, y):
				changed += 1
	return changed

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition and not failures.has(description):
		failures.append(description)
