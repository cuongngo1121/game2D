extends SceneTree
## Contract for the temporary Settings placement editor. It moves complete
## runtime groups, supports mouse/touch drags, clamps them to the design frame,
## and can always restore the authored starting coordinates.

const SettingsLayoutEditor = preload("res://scripts/ui/settings_layout_editor.gd")
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)

var host: Control
var editor
var groups: Dictionary = {}
var defaults: Dictionary = {}
var checks: int = 0
var failures: Array[String] = []
var moved_groups: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	host = Control.new()
	host.size = VIEWPORT_SIZE
	root.add_child(host)
	_add_group("title", Vector2(400.0, 39.0), Vector2(480.0, 65.0))
	_add_group("audio", Vector2(78.0, 139.0), Vector2(515.0, 396.0))
	_add_group("controls", Vector2(687.0, 139.0), Vector2(515.0, 409.0))
	_add_group("save", Vector2(443.0, 596.0), Vector2(394.0, 58.0))
	editor = SettingsLayoutEditor.new()
	editor.size = VIEWPORT_SIZE
	host.add_child(editor)
	editor.configure([
		{"id": "title", "target": groups.title, "label": "TIÊU ĐỀ", "accent": Color("35e7ff"), "default_position": defaults.title},
		{"id": "audio", "target": groups.audio, "label": "ÂM THANH", "accent": Color("35e7ff"), "default_position": defaults.audio},
		{"id": "controls", "target": groups.controls, "label": "ĐIỀU KHIỂN", "accent": Color("d65dff"), "default_position": defaults.controls},
		{"id": "save", "target": groups.save, "label": "LƯU", "accent": Color("35e7ff"), "default_position": defaults.save},
	], load("res://assets/fonts/NotoSans-Regular.ttf"), load("res://assets/fonts/NotoSans-Bold.ttf"))
	editor.group_moved.connect(func(group_id: String, _position: Vector2): moved_groups.append(group_id))
	editor.set_editor_active(true)
	await process_frame

	_check(editor.is_editor_active(), "Layout editor starts active when explicitly enabled")
	_check(editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_STOP, "Active editor captures the Settings area before runtime controls")
	_check(editor.group_position("audio") == defaults.audio, "Editor reports the authored audio-group position")

	_drag_mouse(groups.audio.position + Vector2(40.0, 40.0), groups.audio.position + Vector2(140.0, 110.0))
	_check(groups.audio.position == defaults.audio + Vector2(100.0, 70.0), "Mouse drag moves the entire audio group by the pointer delta")
	_check(moved_groups.has("audio"), "Mouse drag emits the moved group identifier")

	editor.reset_layout()
	_check(_all_groups_at_defaults(), "Reset restores every group to its authored position")

	_drag_touch(groups.title.position + Vector2(100.0, 25.0), groups.title.position + Vector2(170.0, 65.0))
	_check(groups.title.position == defaults.title + Vector2(70.0, 40.0), "Touch drag moves the title group without moving the rest of the layout")
	_check(groups.audio.position == defaults.audio and groups.controls.position == defaults.controls, "Touch title drag preserves the other group positions")

	editor.reset_layout()
	_drag_mouse(groups.save.position + Vector2(30.0, 20.0), Vector2(3000.0, 3000.0))
	_check(groups.save.position == VIEWPORT_SIZE - groups.save.size, "Drag is clamped so the save group stays within the 1280x720 design frame")

	editor.reset_layout()
	editor.set_editor_active(false)
	var audio_before: Vector2 = groups.audio.position
	_drag_mouse(groups.audio.position + Vector2(40.0, 40.0), groups.audio.position + Vector2(180.0, 180.0))
	_check(not editor.visible and editor.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Inactive editor becomes visually and interactively transparent")
	_check(groups.audio.position == audio_before, "Inactive editor does not intercept or move a Settings group")

	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("SETTINGS LAYOUT EDITOR PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SETTINGS LAYOUT EDITOR FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)

func _add_group(group_id: String, at: Vector2, group_size: Vector2) -> void:
	var group := Control.new()
	group.name = "Test_%s" % group_id.capitalize()
	group.position = at
	group.size = group_size
	host.add_child(group)
	groups[group_id] = group
	defaults[group_id] = at

func _all_groups_at_defaults() -> bool:
	for group_id in defaults:
		var group: Control = groups[group_id]
		if group.position != defaults[group_id]:
			return false
	return true

func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	editor._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	editor._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	editor._gui_input(release)

func _drag_touch(from: Vector2, to: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = from
	editor._gui_input(press)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = to
	editor._gui_input(drag)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = to
	editor._gui_input(release)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
