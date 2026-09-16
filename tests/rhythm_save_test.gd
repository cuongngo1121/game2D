extends SceneTree
## Run: godot --headless --path . --script tests/rhythm_save_test.gd

const RhythmScript: Script = preload("res://scripts/audio/rhythm_manager.gd")
const AudioScript: Script = preload("res://scripts/audio/audio_manager.gd")
const SaveScript: Script = preload("res://scripts/core/save_store.gd")

class FakeAudio:
	extends RefCounted
	var time: float = -1.0
	var paused: bool = false
	func playback_time() -> float:
		return time
	func pause_music() -> void:
		paused = true
	func resume_music() -> void:
		paused = false

var failures: Array[String] = []
var checks: int = 0
var beats: Array[int] = []
var bars: Array[int] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rhythm()
	_test_audio_clock()
	_test_music_layers()
	_test_save()
	if failures.is_empty():
		print("RHYTHM_SAVE PASS: %d checks" % checks)
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("RHYTHM_SAVE FAIL: %d/%d checks" % [failures.size(), checks])
		quit(1)


func _test_rhythm() -> void:
	var rhythm: Node = RhythmScript.new()
	var fake: FakeAudio = FakeAudio.new()
	rhythm.setup(fake)
	rhythm.beat.connect(func(index: int) -> void: beats.append(index))
	rhythm.bar.connect(func(index: int) -> void: bars.append(index))
	rhythm.configure(120.0)
	rhythm.update(0.0)
	_check(beats == [0] and bars == [0], "Initial beat and bar are emitted once")
	rhythm.update(0.5)
	_check(rhythm.beat_index == 1, "120 BPM advances one beat in 500 ms")
	var before_stall: int = beats.size()
	rhythm.update(2.1)
	_check(rhythm.beat_index == 5 and beats.size() == before_stall + 1, "Slow frame coalesces missed beats instead of firing attack flood")
	_check(bars == [0, 1], "A skipped bar is delivered once")
	rhythm.configure(120.0, 100.0)
	rhythm.update(0.1)
	_check(is_zero_approx(rhythm.phase()) and rhythm.is_perfect(), "Positive 100 ms calibration delays judgement to 100 ms")
	rhythm.configure(120.0)
	rhythm.update(0.120)
	_check(rhythm.is_perfect(120.0), "Perfect window includes +120 ms boundary")
	rhythm.update(0.001)
	_check(not rhythm.is_perfect(120.0), "Perfect window excludes +121 ms")
	rhythm.update(0.259)
	_check(rhythm.is_perfect(120.0), "Perfect window wraps to -120 ms before the next beat")
	var before_pause: float = rhythm.phase()
	var before_pause_beats: int = beats.size()
	rhythm.pause_music()
	rhythm.update(60.0)
	_check(fake.paused and is_equal_approx(rhythm.phase(), before_pause), "Pause freezes audio and visual clock")
	_check(not rhythm.is_perfect() and beats.size() == before_pause_beats, "Paused actions cannot earn rhythm rewards")
	rhythm.resume_music()
	rhythm.update(0.12)
	_check(not fake.paused and beats.size() == before_pause_beats + 1, "Resume has no pause-time catch-up burst")
	rhythm.configure(120.0, -100.0)
	rhythm.update(0.4)
	_check(is_zero_approx(rhythm.phase()), "Negative calibration advances judgement")
	rhythm.configure(120.0)
	fake.time = 2.0
	rhythm.update(0.01)
	_check(rhythm.beat_index == 4, "Audible playback clock takes priority over frame delta")
	fake.time = 1.9
	rhythm.update(0.01)
	_check(rhythm.beat_index == 4 and is_zero_approx(rhythm.phase()), "Audio clock jitter never moves the rhythm backwards")
	# A platform audio player can resume visually yet leave its reported playhead at
	# one value. Combat attacks are beat-driven, so a permanently stale sample must
	# not freeze every enemy and boss after the reward/pause transition.
	rhythm.configure(120.0)
	fake.time = 0.0
	rhythm.update(0.0)
	rhythm.pause_music()
	rhythm.resume_music()
	for tick in range(10):
		rhythm.update(0.1)
	_check(rhythm.beat_index >= 1, "A resumed but stalled audio playhead falls back to delta so later-room combat beats continue")
	rhythm.free()


func _test_audio_clock() -> void:
	var audio: Node = AudioScript.new()
	audio._loop_seconds = 8.0
	var time: float = audio._sample_clock(0.2, 0.01, 0.05, 0.2)
	_check(is_equal_approx(time, 0.16), "Audio time includes last mix age minus output latency")
	audio._sample_clock(7.9, 0.01, 0.05, 7.7)
	time = audio._sample_clock(0.1, 0.01, 0.05, 0.2)
	_check(is_equal_approx(time, 8.06), "WAV loop crossing produces a continuous clock")
	var jitter: float = audio._sample_clock(0.08, 0.01, 0.05, 0.001)
	_check(is_equal_approx(jitter, time), "Sub-frame jitter is clamped monotonically")
	time = audio._sample_clock(0.2, 0.01, 0.05, 24.1)
	_check(is_equal_approx(time, 32.16), "A device stall spanning several full loops retains phase and loop count")
	audio.free()
	var continuous: Node = AudioScript.new()
	continuous._loop_seconds = 8.0
	time = continuous._sample_clock(10.2, 0.01, 0.05, 10.2)
	_check(is_equal_approx(time, 10.16), "Continuous synchronized stream clocks are not unwrapped twice")
	continuous.free()


func _test_music_layers() -> void:
	var audio: Node = AudioScript.new()
	root.add_child(audio)
	audio.setup()
	audio.start_stage(0, 90.0)
	var music: AudioStreamPlayer = audio.music
	_check(music.stream is AudioStreamSynchronized, "Music has a single sample-synchronized player")
	var synchronized: AudioStreamSynchronized = music.stream as AudioStreamSynchronized
	if synchronized != null:
		_check(synchronized.stream_count == 3, "Explore, combat, and boss layers share one stream")
		for layer: int in range(3):
			var wav: AudioStreamWAV = synchronized.get_sync_stream(layer) as AudioStreamWAV
			_check(wav != null and wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music layer %d is a real looping WAV" % layer)
			if wav != null:
				_check(absf(wav.get_length() - 16.0 * 60.0 / 90.0) < 0.005, "Music layer %d is exactly sixteen beats" % layer)
	audio.request_intensity("combat")
	_check(audio.current_intensity == "explore", "An intensity request waits for the bar boundary")
	audio.on_bar(0)
	_check(audio.current_intensity == "combat", "Combat layer switches at a bar boundary")
	audio.request_intensity("boss")
	audio.on_bar(0)
	_check(audio.current_intensity == "combat", "The same bar cannot switch intensity twice")
	audio.on_bar(1)
	_check(audio.current_intensity == "boss" and music.stream == synchronized, "Boss switch keeps the same playback stream and phase")
	audio.set_volumes(0.0, 0.7)
	_check(music.playing and is_zero_approx(music.volume_linear), "Muted music continues its clock")
	for index: int in range(30):
		audio.play_sfx("shoot")
	_check(audio._sfx_voices.size() == 12, "SFX voice pool stays bounded under repeated shots")
	audio.pause_music()
	_check(music.stream_paused, "Music player actually pauses")
	audio.resume_music()
	_check(not music.stream_paused, "Music resumes from the existing stream")
	audio.free()


func _test_save() -> void:
	var path: String = "user://tests/rhythm_save_%d.json" % OS.get_process_id()
	var store: RefCounted = SaveScript.new(path)
	var profile: Dictionary = store.load_profile()
	_check(profile["settings"]["music"] == 0.65 and profile["meta"]["shards"] == 0, "New profile receives independent safe defaults")
	profile["settings"]["latency_ms"] = 85.0
	profile["meta"]["shards"] = 137
	profile["checkpoint"] = {
		"seed": 4294967295, "stage": 2, "room": 3, "cleared": [0, 1, 2, 3], "rewarded": [1, 2, 3],
		"player": {"hp": 73.5, "shield": 12.0, "energy": 61.0, "resonance": 42.0},
		"coins": 57, "upgrades": {"damage": 2}, "weapons": ["pistol", "rail"], "elapsed": 723.125,
		"active_slot": 1, "run_kills": 81, "branch_position": 2, "starter": "pistol",
	}
	_check(store.save_profile(profile), "Complete checkpoint can be committed")
	var loaded: Dictionary = store.load_profile()
	_check(loaded["meta"]["shards"] == 137 and loaded["settings"]["latency_ms"] == 85.0, "Settings and meta round-trip together")
	_check(loaded["checkpoint"] == profile["checkpoint"], "Seed, rewards, inventory, player and elapsed time round-trip as one snapshot")
	_write_text(path, "{interrupted")
	loaded = store.load_profile()
	_check(store.recovered_from_backup and loaded["checkpoint"] == profile["checkpoint"], "A corrupt primary recovers the whole valid backup checkpoint")
	_check(not store._read_envelope(path).is_empty(), "Recovery repairs the primary copy")
	var invalid: Dictionary = profile.duplicate(true)
	invalid["checkpoint"]["rewarded"] = [62]
	_check(not store.save_profile(invalid), "A reward for an uncleared room is rejected")
	invalid = profile.duplicate(true)
	invalid["checkpoint"]["player"]["hp"] = 0.0
	_check(not store.save_profile(invalid), "A dead player cannot be committed as a resumable run")
	invalid = profile.duplicate(true)
	invalid["checkpoint"].erase("elapsed")
	_check(not store.save_profile(invalid), "A partial checkpoint cannot overwrite a valid snapshot")
	_check(store.clear_checkpoint(profile), "Ending a run durably clears its checkpoint")
	_check(profile["checkpoint"].is_empty(), "Caller sees the cleared checkpoint only after commit")
	_write_text(path, "corrupt after death")
	loaded = store.load_profile()
	_check(loaded["checkpoint"].is_empty() and loaded["meta"]["shards"] == 137, "Backup recovery after death cannot resurrect an old run or lose meta")
	# Simulate a process exit after the fresh backup rename but before primary rename.
	var old_primary: String = FileAccess.get_file_as_string(path)
	profile["meta"]["shards"] = 201
	_check(store.save_profile(profile), "A subsequent profile update succeeds")
	_write_text(path, old_primary)
	loaded = store.load_profile()
	_check(loaded["meta"]["shards"] == 201 and store.recovered_from_backup, "The newest committed revision wins after a crash between file renames")
	_write_text(path, "corrupt primary")
	_write_text(path + ".bak", "corrupt backup")
	loaded = store.load_profile()
	_check(loaded["checkpoint"].is_empty() and loaded["meta"]["shards"] == 0, "Two invalid files recover to safe defaults")
	for suffix: String in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _write_text(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(contents)
		file.close()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
