extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/licenses")
	var output = FileAccess.open("res://assets/licenses/Godot.txt", FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(Engine.get_license_text())
	output.close()
	print("Godot license copied from the engine into assets/licenses/Godot.txt")
	quit(0)
