extends SceneTree

const SafeArea = preload("res://scripts/ui/safe_area.gd")
class InputProbe:
	extends Node
	var position: Vector2 = Vector2(-1, -1)
	func _input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			position = event.position

var checks: int = 0
var errors: int = 0
var clicked: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		errors += 1
		push_error(detail)

func run() -> void:
	var baseline: Transform2D = Transform2D(Vector2(1.5, 0), Vector2(0, 1.5), Vector2.ZERO)
	check(SafeArea.fit_transform(Rect2(0, 0, 1920, 1080), baseline).is_equal_approx(Transform2D.IDENTITY), "16:9 full-screen stays unchanged")
	var wide_baseline: Transform2D = Transform2D(Vector2(1.5, 0), Vector2(0, 1.5), Vector2(240, 0))
	check(SafeArea.fit_transform(Rect2(100, 0, 2300, 1080), wide_baseline).is_equal_approx(Transform2D.IDENTITY), "20:9 letterbox already protects a left notch")
	for safe_rect: Rect2 in [Rect2(100, 0, 1820, 1032), Rect2(0, 0, 1800, 1080), Rect2(0, 45, 1920, 1035), Rect2(0, 0, 1920, 1000)]:
		var fit: Transform2D = SafeArea.fit_transform(safe_rect, baseline)
		var mapped: Rect2 = baseline * fit * Rect2(0, 0, 1280, 720)
		check(safe_rect.grow(0.01).encloses(mapped), "Every edge is inside asymmetric Android safe area")
		check(is_equal_approx(fit.x.length(), fit.y.length()), "Safe fit uses uniform scale")
	check(SafeArea.fit_transform(Rect2(), baseline).is_equal_approx(Transform2D.IDENTITY), "Unavailable safe area leaves ordinary layout intact")
	var world: Node2D = Node2D.new()
	world.position = Vector2(500, 320)
	root.add_child(world)
	var layer: CanvasLayer = CanvasLayer.new()
	root.add_child(layer)
	var button: Button = Button.new()
	button.position = Vector2(950, 550)
	button.size = Vector2(100, 100)
	layer.add_child(button)
	button.pressed.connect(func() -> void: clicked = true)
	var probe: InputProbe = InputProbe.new()
	root.add_child(probe)
	var helper: Node = SafeArea.new()
	root.add_child(helper)
	helper.setup(root)
	# Dummy display uses a real 64x64 surface with a 1280x720 logical viewport.
	var initial_pixels: Rect2 = root.get_screen_transform() * Rect2(0, 0, 1280, 720)
	var safe_pixels: Rect2i = Rect2i(initial_pixels.position + Vector2(4, 0), initial_pixels.size - Vector2(4, 2))
	helper._apply_display_rect(safe_pixels)
	var first_fit: Transform2D = root.global_canvas_transform
	check(not first_fit.is_equal_approx(Transform2D.IDENTITY), "Android rectangle changes global canvas fit")
	helper._apply_display_rect(safe_pixels)
	check(root.global_canvas_transform.is_equal_approx(first_fit), "Repeated refresh cannot compound scaling")
	check(world.position.is_equal_approx(Vector2(500, 320)), "Physics/world coordinates remain unchanged")
	var button_on_screen: Vector2 = root.get_screen_transform() * button.get_global_transform_with_canvas() * Vector2(50, 50)
	check(Rect2(safe_pixels).has_point(button_on_screen), "CanvasLayer UI is fitted by the same transform")
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = root.get_final_transform() * Vector2(1000, 600)
	root.push_input(touch, false)
	check(probe.position.distance_to(Vector2(1000, 600)) < 0.001, "Viewport automatically restores raw touch events to 1280x720 logical units")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_final_transform() * Vector2(1000, 600)
	root.push_input(click, false)
	click.pressed = false
	root.push_input(click, false)
	check(clicked, "Built-in GUI button receives mapped physical click correctly")
	helper.free()
	check(root.global_canvas_transform.is_equal_approx(Transform2D.IDENTITY), "Removing helper restores original transform")
	probe.free()
	layer.free()
	world.free()
	print("SAFE_AREA %s: %d checks" % ["PASS" if errors == 0 else "FAIL", checks])
	quit(0 if errors == 0 else 1)
