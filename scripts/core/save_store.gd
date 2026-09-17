class_name SaveStore
extends RefCounted
## A profile is a single snapshot. Checkpoints are never assembled from two saves.

const SCHEMA_VERSION: int = 1
const PROFILE_PATH: String = "user://profile.json"
const UI_LAYOUT_DEFAULTS_PATH: String = "res://data/ui_layout_defaults.json"
const MAX_FILE_BYTES: int = 524288
const SETTINGS_LAYOUT_GROUP_IDS := ["title", "audio", "controls", "save"]
const HUD_LAYOUT_ITEM_IDS := ["hp", "shield", "energy", "title", "weapon", "pause", "boss"]
const TOUCH_LAYOUT_ITEM_IDS := ["move", "fire", "dash", "pulse"]
const PAUSE_LAYOUT_ITEM_IDS := ["title", "continue", "settings", "menu"]
const REWARD_LAYOUT_ITEM_IDS := [
	"title",
	"card_01", "card_01_title", "card_01_description",
	"card_02", "card_02_title", "card_02_description",
	"card_03", "card_03_title", "card_03_description",
	"repair",
]
const SUPPORT_LAYOUT_ITEM_IDS := [
	"title", "status",
	"card_01", "card_01_icon", "card_01_title", "card_01_description",
	"card_02", "card_02_icon", "card_02_title", "card_02_description",
	"card_03", "card_03_icon", "card_03_title", "card_03_description",
	"back",
]
const ARMORY_LAYOUT_ITEM_IDS := [
	"title",
	"pistol_stt", "pistol_name", "pistol_action",
	"smg_stt", "smg_name", "smg_action",
	"shotgun_stt", "shotgun_name", "shotgun_action",
	"rail_stt", "rail_name", "rail_action",
	"beam_stt", "beam_name", "beam_action",
	"disc_stt", "disc_name", "disc_action",
	"arc_stt", "arc_name", "arc_action",
	"wave_stt", "wave_name", "wave_action",
	"glitch_stt", "glitch_name", "glitch_action",
	"orbit_stt", "orbit_name", "orbit_action",
	"blade_stt", "blade_name", "blade_action",
	"chord_stt", "chord_name", "chord_action",
]
const DEFAULT_SETTINGS: Dictionary = {
	"music": 0.65, "sfx": 0.7, "vibration": true, "screen_shake": 0.4,
	"reduced_flashes": false, "quality": 1, "latency_ms": 0.0,
	"touch_scale": 1.0, "touch_opacity": 0.65, "auto_aim": true,
	"music_enabled": true, "sfx_enabled": true, "settings_layout_positions": {}, "hud_layout": {}, "touch_layout": {}, "pause_layout": {}, "reward_layout": {}, "support_layout": {}, "armory_layout": {},
}
const DEFAULT_META: Dictionary = {
	"shards": 0, "unlocked": ["pistol", "smg", "shotgun", "rail"],
	"wins": 0, "runs": 0, "kills": 0, "starter": "smg",
}

# The optional path lets tests use an isolated user:// file, never the live profile.
var profile_path: String
var last_error: String = ""
var recovered_from_backup: bool = false


func _init(path: String = PROFILE_PATH) -> void:
	profile_path = path if path.begins_with("user://") else PROFILE_PATH


func default_profile() -> Dictionary:
	var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	settings.merge(_load_ui_layout_defaults(), true)
	return {"settings": settings, "meta": DEFAULT_META.duplicate(true), "checkpoint": {}}


func _load_ui_layout_defaults() -> Dictionary:
	var output: Dictionary = {}
	if not FileAccess.file_exists(UI_LAYOUT_DEFAULTS_PATH):
		return output
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(UI_LAYOUT_DEFAULTS_PATH))
	if not parsed is Dictionary:
		return output
	var defaults: Dictionary = parsed
	if _number_between(defaults.get("touch_scale"), 0.7, 1.5):
		output["touch_scale"] = clampf(float(defaults["touch_scale"]), 0.7, 1.5)
	if _number_between(defaults.get("touch_opacity"), 0.2, 1.0):
		output["touch_opacity"] = clampf(float(defaults["touch_opacity"]), 0.2, 1.0)
	if defaults.get("settings_layout_positions") is Dictionary:
		output["settings_layout_positions"] = _normalize_settings_layout_positions(defaults["settings_layout_positions"])
	if defaults.get("hud_layout") is Dictionary:
		output["hud_layout"] = _normalize_hud_layout(defaults["hud_layout"])
	if defaults.get("touch_layout") is Dictionary:
		output["touch_layout"] = _normalize_touch_layout(defaults["touch_layout"])
	if defaults.get("pause_layout") is Dictionary:
		output["pause_layout"] = _normalize_pause_layout(defaults["pause_layout"])
	if defaults.get("reward_layout") is Dictionary:
		output["reward_layout"] = _normalize_reward_layout(defaults["reward_layout"])
	if defaults.get("support_layout") is Dictionary:
		output["support_layout"] = _normalize_support_layout(defaults["support_layout"])
	if defaults.get("armory_layout") is Dictionary:
		output["armory_layout"] = _normalize_armory_layout(defaults["armory_layout"])
	return output


func load_profile() -> Dictionary:
	last_error = ""
	recovered_from_backup = false
	var primary: Dictionary = _read_envelope(profile_path)
	var backup: Dictionary = _read_envelope(profile_path + ".bak")
	var selected: Dictionary = primary
	if primary.is_empty() or (not backup.is_empty() and int(backup["revision"]) > int(primary["revision"])):
		selected = backup
		recovered_from_backup = not backup.is_empty()
	if selected.is_empty():
		if FileAccess.file_exists(profile_path) or FileAccess.file_exists(profile_path + ".bak"):
			last_error = "Profile copies were invalid; safe defaults loaded."
		return default_profile()
	if recovered_from_backup:
		# Repair the primary from the exact verified envelope, preserving its revision.
		_replace_file(profile_path, JSON.stringify(selected))
	var payload: Dictionary = JSON.parse_string(String(selected["payload_json"])) as Dictionary
	return _normalize_profile(payload)


func save_profile(profile: Dictionary) -> bool:
	last_error = ""
	var checkpoint_value: Variant = profile.get("checkpoint", {})
	if not checkpoint_value is Dictionary or (not checkpoint_value.is_empty() and not validate_checkpoint(checkpoint_value)):
		last_error = "Checkpoint rejected: incomplete or inconsistent run snapshot."
		return false
	var snapshot: Dictionary = _normalize_profile(profile)
	var primary: Dictionary = _read_envelope(profile_path)
	var backup: Dictionary = _read_envelope(profile_path + ".bak")
	var revision: int = maxi(int(primary.get("revision", 0)), int(backup.get("revision", 0))) + 1
	var payload_json: String = JSON.stringify(snapshot)
	var envelope: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"revision": revision,
		"payload_json": payload_json,
		"sha256": payload_json.sha256_text(),
	}
	var serialized: String = JSON.stringify(envelope)
	# Commit the fresh backup first, then the primary. Loading chooses the highest
	# valid revision. Thus a crash between renames cannot resurrect a dead run from
	# yesterday's backup after a checkpoint clear. Each copy is flushed, parsed,
	# and checksum-verified before its atomic rename in the same directory.
	if not _replace_file(profile_path + ".bak", serialized):
		return false
	if not _replace_file(profile_path, serialized):
		# The newest complete snapshot is already durable in the backup.
		last_error = "Primary save unavailable; snapshot committed to recovery copy."
	return true


func clear_checkpoint(profile: Dictionary) -> bool:
	var snapshot: Dictionary = profile.duplicate(true)
	snapshot["checkpoint"] = {}
	if not save_profile(snapshot):
		return false
	profile["checkpoint"] = {}
	return true


func validate_checkpoint(checkpoint: Dictionary) -> bool:
	if checkpoint.is_empty():
		return true
	if not _safe_json(checkpoint, 0):
		return false
	for key: String in ["seed", "stage", "room", "cleared", "rewarded", "player", "coins", "upgrades", "weapons", "elapsed"]:
		if not checkpoint.has(key):
			return false
	if not _integer_between(checkpoint["seed"], -9007199254740991, 9007199254740991):
		return false
	if not _integer_between(checkpoint["stage"], 0, 4) or not _integer_between(checkpoint["room"], 0, 63):
		return false
	if not _integer_between(checkpoint["coins"], 0, 100000000) or not _number_between(checkpoint["elapsed"], 0.0, 1000000000.0):
		return false
	if not _valid_rooms(checkpoint["cleared"]) or not _valid_rooms(checkpoint["rewarded"]):
		return false
	for room: Variant in checkpoint["rewarded"]:
		if not room in checkpoint["cleared"]:
			return false
	if not checkpoint["player"] is Dictionary or not checkpoint["upgrades"] is Dictionary:
		return false
	var player: Dictionary = checkpoint["player"]
	for key: String in ["hp", "shield", "energy", "resonance"]:
		if not player.has(key) or not _number_between(player[key], 0.0, 100000.0):
			return false
	# Dead runs must be cleared by the caller before returning to the menu.
	if float(player["hp"]) <= 0.0:
		return false
	for key: Variant in checkpoint["upgrades"]:
		if not key is String or not _identifier(key) or not _integer_between(checkpoint["upgrades"][key], 0, 99):
			return false
	if not checkpoint["weapons"] is Array:
		return false
	var weapons: Array = checkpoint["weapons"]
	if weapons.is_empty() or weapons.size() > 2:
		return false
	for weapon: Variant in weapons:
		if not weapon is String or not _identifier(weapon):
			return false
	if checkpoint.has("active_slot") and not _integer_between(checkpoint["active_slot"], 0, weapons.size() - 1):
		return false
	if checkpoint.has("run_kills") and not _integer_between(checkpoint["run_kills"], 0, 100000000):
		return false
	if checkpoint.has("branch_position") and not _integer_between(checkpoint["branch_position"], 0, 63):
		return false
	if checkpoint.has("starter") and (not checkpoint["starter"] is String or not _identifier(checkpoint["starter"])):
		return false
	return true


func _normalize_profile(profile: Dictionary) -> Dictionary:
	var output: Dictionary = default_profile()
	if profile.get("settings") is Dictionary:
		var settings: Dictionary = profile["settings"]
		var ranges: Dictionary = {
			"music": [0.0, 1.0], "sfx": [0.0, 1.0], "screen_shake": [0.0, 1.0],
			"latency_ms": [-300.0, 300.0], "touch_scale": [0.7, 1.5], "touch_opacity": [0.2, 1.0],
		}
		for key: String in ranges:
			if _finite_number(settings.get(key)):
				output["settings"][key] = clampf(float(settings[key]), float(ranges[key][0]), float(ranges[key][1]))
		for key: String in ["vibration", "reduced_flashes", "auto_aim", "music_enabled", "sfx_enabled"]:
			if settings.get(key) is bool:
				output["settings"][key] = settings[key]
		if _integer_between(settings.get("quality"), 0, 2):
			output["settings"]["quality"] = int(settings["quality"])
		if settings.get("settings_layout_positions") is Dictionary:
			var normalized_settings_layout := _normalize_settings_layout_positions(settings["settings_layout_positions"])
			output["settings"]["settings_layout_positions"].merge(normalized_settings_layout, true)
		if settings.get("hud_layout") is Dictionary:
			var normalized_hud_layout := _normalize_hud_layout(settings["hud_layout"])
			output["settings"]["hud_layout"].merge(normalized_hud_layout, true)
		if settings.get("touch_layout") is Dictionary:
			var normalized_touch_layout := _normalize_touch_layout(settings["touch_layout"])
			output["settings"]["touch_layout"].merge(normalized_touch_layout, true)
		if settings.get("pause_layout") is Dictionary:
			var normalized_pause_layout := _normalize_pause_layout(settings["pause_layout"])
			output["settings"]["pause_layout"].merge(normalized_pause_layout, true)
		if settings.get("reward_layout") is Dictionary:
			var normalized_reward_layout := _normalize_reward_layout(settings["reward_layout"])
			output["settings"]["reward_layout"].merge(normalized_reward_layout, true)
		if settings.get("support_layout") is Dictionary:
			var normalized_support_layout := _normalize_support_layout(settings["support_layout"])
			output["settings"]["support_layout"].merge(normalized_support_layout, true)
		if settings.get("armory_layout") is Dictionary:
			var normalized_armory_layout := _normalize_armory_layout(settings["armory_layout"])
			output["settings"]["armory_layout"].merge(normalized_armory_layout, true)
	if profile.get("meta") is Dictionary:
		var meta: Dictionary = profile["meta"]
		for key: String in ["shards", "wins", "runs", "kills"]:
			if _integer_between(meta.get(key), 0, 1000000000):
				output["meta"][key] = int(meta[key])
		if meta.get("unlocked") is Array:
			for item: Variant in meta["unlocked"]:
				if item is String and _identifier(item) and not item in output["meta"]["unlocked"]:
					output["meta"]["unlocked"].append(item)
		if meta.get("starter") is String and _identifier(meta["starter"]):
			output["meta"]["starter"] = meta["starter"]
	var checkpoint: Variant = profile.get("checkpoint", {})
	if checkpoint is Dictionary and validate_checkpoint(checkpoint):
		output["checkpoint"] = _normalize_checkpoint(checkpoint)
	return output


func _normalize_settings_layout_positions(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for group_id in SETTINGS_LAYOUT_GROUP_IDS:
		var encoded: Variant = value.get(group_id)
		if not encoded is Array or encoded.size() != 2:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		output[group_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0)]
	return output


func _normalize_hud_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in HUD_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	# Migrate the former combined resources frame into three independent bars.
	# Only fill missing new entries, so an already-customized bar remains intact.
	var legacy: Variant = value.get("resources")
	if legacy is Array and legacy.size() == 4 and _number_between(legacy[0], 0.0, 1280.0) and _number_between(legacy[1], 0.0, 720.0) and _number_between(legacy[2], 0.55, 2.0) and _number_between(legacy[3], 0.55, 2.0):
		var legacy_position := Vector2(float(legacy[0]), float(legacy[1]))
		var legacy_scale := Vector2(clampf(float(legacy[2]), 0.55, 2.0), clampf(float(legacy[3]), 0.55, 2.0))
		var offsets := {"hp": Vector2(84, 31), "shield": Vector2(84, 49), "energy": Vector2(84, 67)}
		for item_id: String in offsets:
			if output.has(item_id):
				continue
			var position: Vector2 = legacy_position + offsets[item_id] * legacy_scale
			output[item_id] = [clampf(position.x, 0.0, 1280.0), clampf(position.y, 0.0, 720.0), legacy_scale.x, legacy_scale.y]
	return output


func _normalize_touch_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in TOUCH_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	return output


func _normalize_pause_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in PAUSE_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	return output


func _normalize_reward_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in REWARD_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	return output


func _normalize_support_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in SUPPORT_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	return output


func _normalize_armory_layout(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for item_id: String in ARMORY_LAYOUT_ITEM_IDS:
		var encoded: Variant = value.get(item_id)
		if not encoded is Array or encoded.size() != 4:
			continue
		if not _number_between(encoded[0], 0.0, 1280.0) or not _number_between(encoded[1], 0.0, 720.0):
			continue
		if not _number_between(encoded[2], 0.55, 2.0) or not _number_between(encoded[3], 0.55, 2.0):
			continue
		output[item_id] = [clampf(float(encoded[0]), 0.0, 1280.0), clampf(float(encoded[1]), 0.0, 720.0), clampf(float(encoded[2]), 0.55, 2.0), clampf(float(encoded[3]), 0.55, 2.0)]
	return output


func _normalize_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var output: Dictionary = checkpoint.duplicate(true)
	if output.is_empty():
		return output
	# JSON represents numbers as floats. Restore discrete gameplay fields before
	# room membership and weapon-slot checks consume the loaded snapshot.
	for key: String in ["seed", "stage", "room", "coins", "active_slot", "run_kills", "branch_position"]:
		if output.has(key):
			output[key] = int(output[key])
	for key: String in ["cleared", "rewarded"]:
		var rooms: Array[int] = []
		for room: Variant in output[key]:
			rooms.append(int(room))
		output[key] = rooms
	for key: String in output["upgrades"]:
		output["upgrades"][key] = int(output["upgrades"][key])
	return output


func _replace_file(path: String, serialized: String) -> bool:
	var directory: String = ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Cannot create profile directory."
		return false
	var temporary: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open temporary save: %s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(serialized)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or _read_envelope(temporary).is_empty():
		last_error = "Temporary save failed integrity verification."
		return false
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		last_error = "Cannot commit save: %s" % error_string(rename_error)
		return false
	return true


func _read_envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() <= 0 or file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {}
	var contents: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return {}
	var envelope: Dictionary = parser.data
	if not _integer_between(envelope.get("schema_version"), SCHEMA_VERSION, SCHEMA_VERSION):
		return {}
	if not _integer_between(envelope.get("revision"), 1, 9007199254740991):
		return {}
	if not envelope.get("payload_json") is String or not envelope.get("sha256") is String:
		return {}
	var payload_json: String = envelope["payload_json"]
	if payload_json.sha256_text() != String(envelope["sha256"]):
		return {}
	var payload_parser: JSON = JSON.new()
	if payload_parser.parse(payload_json) != OK or not payload_parser.data is Dictionary:
		return {}
	var payload: Dictionary = payload_parser.data
	if not payload.get("settings") is Dictionary or not payload.get("meta") is Dictionary or not payload.get("checkpoint") is Dictionary:
		return {}
	if not _safe_json(payload, 0):
		return {}
	return envelope


func _valid_rooms(value: Variant) -> bool:
	if not value is Array or value.size() > 64:
		return false
	var seen: Dictionary = {}
	for item: Variant in value:
		if not _integer_between(item, 0, 63) or seen.has(int(item)):
			return false
		seen[int(item)] = true
	return true


func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _number_between(value: Variant, minimum: float, maximum: float) -> bool:
	return _finite_number(value) and float(value) >= minimum and float(value) <= maximum


func _integer_between(value: Variant, minimum: int, maximum: int) -> bool:
	return _number_between(value, float(minimum), float(maximum)) and float(value) == floor(float(value))


func _identifier(value: String) -> bool:
	if value.is_empty() or value.length() > 40:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return true


func _safe_json(value: Variant, depth: int) -> bool:
	if depth > 8:
		return false
	if value == null or value is bool:
		return true
	if value is int or value is float:
		return is_finite(float(value))
	if value is String:
		return value.length() <= 1024
	if value is Array:
		if value.size() > 256:
			return false
		for item: Variant in value:
			if not _safe_json(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		if value.size() > 128:
			return false
		for key: Variant in value:
			if not key is String or key.length() > 64 or not _safe_json(value[key], depth + 1):
				return false
		return true
	return false
