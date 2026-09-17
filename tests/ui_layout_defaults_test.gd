extends SceneTree
## The shipped layout contract is a UI-only snapshot of the current PC profile.
## A fresh device receives it without inheriting progress or other profile data.

const SaveScript = preload("res://scripts/core/save_store.gd")
const DEFAULTS_PATH := "res://data/ui_layout_defaults.json"

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var store: RefCounted = SaveScript.new("user://tests/ui_layout_defaults_%d.json" % OS.get_process_id())
	var profile: Dictionary = store.load_profile()
	var settings: Dictionary = profile["settings"]

	_check(FileAccess.file_exists(DEFAULTS_PATH), "The PC layout snapshot is shipped as project data")
	_check(profile["checkpoint"].is_empty(), "A fresh profile keeps gameplay progress empty")
	_check(int(profile["meta"]["shards"]) == 0 and int(profile["meta"]["wins"]) == 0 and int(profile["meta"]["runs"]) == 0, "A fresh profile does not inherit PC progression")
	_check(is_equal_approx(float(settings["touch_scale"]), 1.1) and is_equal_approx(float(settings["touch_opacity"]), 1.0), "The PC touch scale and opacity are part of the shipped UI defaults")

	_check_layout(settings.get("settings_layout_positions"), ["title", "audio", "controls", "save"], 2, "Settings layout")
	_check_layout(settings.get("hud_layout"), ["hp", "shield", "energy", "title", "weapon", "pause", "boss"], 4, "Gameplay HUD layout")
	_check_layout(settings.get("touch_layout"), ["move", "fire", "dash", "pulse"], 4, "Touch layout")
	_check_layout(settings.get("pause_layout"), ["title", "continue", "settings", "menu"], 4, "Pause layout")
	_check_layout(settings.get("reward_layout"), [
		"title",
		"card_01", "card_01_title", "card_01_description",
		"card_02", "card_02_title", "card_02_description",
		"card_03", "card_03_title", "card_03_description",
		"repair",
	], 4, "Reward layout")
	_check_layout(settings.get("support_layout"), [
		"title", "status",
		"card_01", "card_01_icon", "card_01_title", "card_01_description",
		"card_02", "card_02_icon", "card_02_title", "card_02_description",
		"card_03", "card_03_icon", "card_03_title", "card_03_description",
		"back",
	], 4, "Support layout")
	_check_layout(settings.get("armory_layout"), [
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
	], 4, "Armory layout")

	var hp: Array = settings["hud_layout"]["hp"]
	var pulse: Array = settings["touch_layout"]["pulse"]
	var audio: Array = settings["settings_layout_positions"]["audio"]
	_check(is_equal_approx(float(hp[0]), 109.212890625) and is_equal_approx(float(hp[2]), 0.773235857486725), "The shipped HP transform matches the current PC profile")
	_check(is_equal_approx(float(pulse[0]), 1099.60034179688) and is_equal_approx(float(pulse[2]), 1.50378727912903), "The shipped Pulse transform matches the current PC profile")
	_check(is_equal_approx(float(audio[0]), 100.130493164063) and is_equal_approx(float(audio[1]), 150.417251586914), "The shipped Settings transform matches the current PC profile")

	var partial_profile: Dictionary = {
		"settings": {"hud_layout": {"hp": [201.0, 202.0, 1.0, 1.0]}},
		"meta": {},
		"checkpoint": {},
	}
	var normalized: Dictionary = store._normalize_profile(partial_profile)
	var normalized_hud: Dictionary = normalized["settings"]["hud_layout"]
	_check(is_equal_approx(float(normalized_hud["hp"][0]), 201.0), "A saved custom HUD item overrides the shipped default")
	_check(normalized_hud.has("shield") and normalized_hud.has("energy"), "Missing HUD items retain the shipped defaults")
	var normalized_pause: Dictionary = normalized["settings"]["pause_layout"]
	_check(normalized_pause.has("title") and normalized_pause.has("continue") and normalized_pause.has("settings") and normalized_pause.has("menu"), "Missing pause items retain the shipped defaults")
	var normalized_reward: Dictionary = normalized["settings"]["reward_layout"]
	_check(normalized_reward.has("title") and normalized_reward.has("card_01") and normalized_reward.has("card_01_title") and normalized_reward.has("card_01_description") and normalized_reward.has("card_02") and normalized_reward.has("card_02_title") and normalized_reward.has("card_02_description") and normalized_reward.has("card_03") and normalized_reward.has("card_03_title") and normalized_reward.has("card_03_description") and normalized_reward.has("repair"), "Missing reward items retain the shipped defaults")
	var normalized_support: Dictionary = normalized["settings"]["support_layout"]
	_check(normalized_support.has("title") and normalized_support.has("status") and normalized_support.has("card_01") and normalized_support.has("card_01_icon") and normalized_support.has("card_01_title") and normalized_support.has("card_01_description") and normalized_support.has("card_02") and normalized_support.has("card_02_icon") and normalized_support.has("card_02_title") and normalized_support.has("card_02_description") and normalized_support.has("card_03") and normalized_support.has("card_03_icon") and normalized_support.has("card_03_title") and normalized_support.has("card_03_description") and normalized_support.has("back"), "Missing support items retain the shipped defaults")

	if failures.is_empty():
		print("UI LAYOUT DEFAULTS PASS: %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("UI LAYOUT DEFAULTS FAIL: %d/%d checks" % [failures.size(), checks])
	quit(1)


func _check_layout(value: Variant, expected_ids: Array, encoded_size: int, label: String) -> void:
	_check(value is Dictionary, "%s is present in a fresh profile" % label)
	if not value is Dictionary:
		return
	var layout: Dictionary = value
	for item_id: String in expected_ids:
		var encoded: Variant = layout.get(item_id)
		_check(encoded is Array and encoded.size() == encoded_size, "%s contains %s" % [label, item_id])


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
