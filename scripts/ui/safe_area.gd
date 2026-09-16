class_name SafeAreaLayout
extends Node
## Fits the complete 1280x720 canvas inside Android's usable display rectangle.
## The root viewport transform also maps incoming touch/GUI coordinates back to
## logical gameplay units, so neither actors nor touch hitboxes need to move.

const DESIGN_SIZE: Vector2 = Vector2(1280.0, 720.0)

signal layout_changed

var _window: Window
var _base_canvas_transform: Transform2D = Transform2D.IDENTITY
var _reset_inputs: Callable
var _refresh_elapsed: float = 0.0
var last_safe_rect: Rect2i = Rect2i()


func setup(target_window: Window, reset_inputs: Callable = Callable()) -> void:
	_window = target_window
	_base_canvas_transform = _window.global_canvas_transform
	_reset_inputs = reset_inputs
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(OS.has_feature("android"))
	if not OS.has_feature("android"):
		return
	_window.size_changed.connect(_queue_refresh)
	_window.focus_entered.connect(_queue_refresh)
	_queue_refresh()


func _process(delta: float) -> void:
	# System navigation insets can change without a viewport-size signal.
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.5:
		_refresh_elapsed = 0.0
		refresh()


func _queue_refresh() -> void:
	call_deferred("refresh")


func refresh() -> void:
	if not is_instance_valid(_window) or not OS.has_feature("android"):
		return
	_apply_display_rect(DisplayServer.get_display_safe_area())


func _apply_display_rect(display_safe_rect: Rect2i) -> void:
	if not is_instance_valid(_window):
		return
	var current: Transform2D = _window.global_canvas_transform
	if is_zero_approx(current.determinant()):
		return
	# get_screen_transform contains the current global canvas transform. Remove
	# our previous fit first, so periodic refresh never shrinks the game repeatedly.
	var baseline_to_window: Transform2D = _window.get_screen_transform() * current.affine_inverse() * _base_canvas_transform
	# Android safe-area coordinates are relative to the physical display, whereas
	# the root viewport's screen transform is relative to its native window.
	var window_position: Vector2 = Vector2(DisplayServer.window_get_position(_window.get_window_id()))
	var safe_in_window: Rect2 = Rect2(display_safe_rect)
	safe_in_window.position -= window_position
	var fit: Transform2D = fit_transform(safe_in_window, baseline_to_window)
	var desired: Transform2D = _base_canvas_transform * fit
	last_safe_rect = display_safe_rect
	# Matrix inversion may vary by tiny fractions of one logical pixel. Ignore that
	# numerical noise; otherwise polling could repeatedly cancel a held joystick.
	var changed: bool = not desired.x.is_equal_approx(current.x) or not desired.y.is_equal_approx(current.y) or desired.origin.distance_to(current.origin) > 0.01
	if changed:
		_window.global_canvas_transform = desired
		if _reset_inputs.is_valid():
			_reset_inputs.call()
		layout_changed.emit()


static func fit_transform(safe_in_window: Rect2, baseline_to_window: Transform2D, design_size: Vector2 = DESIGN_SIZE) -> Transform2D:
	if design_size.x <= 0.0 or design_size.y <= 0.0 or not safe_in_window.has_area() or is_zero_approx(baseline_to_window.determinant()):
		return Transform2D.IDENTITY
	var logical_rect: Rect2 = Rect2(Vector2.ZERO, design_size)
	var existing_content: Rect2 = baseline_to_window * logical_rect
	# Existing letterboxing already protects many wide phones. Use its intersection
	# with the safe area; never place content outside the viewport's current clip.
	var available_screen: Rect2 = existing_content.intersection(safe_in_window)
	if not available_screen.has_area():
		return Transform2D.IDENTITY
	var available_logical: Rect2 = baseline_to_window.affine_inverse() * available_screen
	available_logical = available_logical.intersection(logical_rect)
	if not available_logical.has_area():
		return Transform2D.IDENTITY
	var uniform_scale: float = minf(1.0, minf(available_logical.size.x / design_size.x, available_logical.size.y / design_size.y))
	var offset: Vector2 = available_logical.position + (available_logical.size - design_size * uniform_scale) * 0.5
	return Transform2D(Vector2(uniform_scale, 0.0), Vector2(0.0, uniform_scale), offset)


func _exit_tree() -> void:
	if not is_instance_valid(_window):
		return
	if _window.size_changed.is_connected(_queue_refresh):
		_window.size_changed.disconnect(_queue_refresh)
	if _window.focus_entered.is_connected(_queue_refresh):
		_window.focus_entered.disconnect(_queue_refresh)
	_window.global_canvas_transform = _base_canvas_transform
	_reset_inputs = Callable()
