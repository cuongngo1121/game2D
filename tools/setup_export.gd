@tool
extends SceneTree
## Called by export_android.ps1 with --editor and a workspace-local _sc_ marker.


func _initialize() -> void:
	call_deferred("_configure")


func _configure() -> void:
	if not Engine.is_editor_hint():
		push_error("Export setup requires --editor.")
		quit(1)
		return
	var paths: EditorPaths = EditorInterface.get_editor_paths()
	if not paths.is_self_contained():
		push_error("Use a portable Godot executable with an _sc_ file beside it; user editor settings must remain unchanged.")
		quit(1)
		return
	var sdk_path: String = OS.get_environment("NEON_ANDROID_SDK")
	var java_path: String = OS.get_environment("NEON_JAVA_SDK")
	var key_path: String = OS.get_environment("GODOT_ANDROID_KEYSTORE_DEBUG_PATH")
	if sdk_path.is_empty() or java_path.is_empty() or key_path.is_empty():
		push_error("NEON_ANDROID_SDK, NEON_JAVA_SDK, and debug key path must be provided by export_android.ps1.")
		quit(1)
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	settings.set_setting("export/android/android_sdk_path", sdk_path)
	settings.set_setting("export/android/java_sdk_path", java_path)
	settings.set_setting("export/android/debug_keystore", key_path)
	settings.set_setting("export/android/debug_keystore_user", "androiddebugkey")
	settings.set_setting("export/android/debug_keystore_pass", "android")
	var config_path: String = paths.get_config_dir().path_join("editor_settings-4.5.tres")
	var error: Error = ResourceSaver.save(settings, config_path)
	if error != OK:
		push_error("Cannot save portable export settings: %s" % error_string(error))
		quit(1)
		return
	print("EXPORT_SETUP_OK: %s" % config_path)
	# The headless editor starts its filesystem scan after script initialization.
	# Let that worker finish before exit so setup does not abort asset import.
	await process_frame
	await process_frame
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning():
		await process_frame
	await process_frame
	quit(0)
