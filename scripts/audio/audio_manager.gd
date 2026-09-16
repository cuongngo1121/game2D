class_name GameAudio
extends Node
## One synchronized music player keeps all intensity layers on the same sample clock.

const MODES: Array[String] = ["explore", "combat", "boss"]
const MAX_SFX_VOICES: int = 12
const SILENT_DB: float = -80.0

var music: AudioStreamPlayer
var current_intensity: String = "explore"
var pending_intensity: String = "explore"
var stage_index: int = 0
var bpm: float = 120.0
var _synchronized: AudioStreamSynchronized
var _sfx_voices: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _next_voice: int = 0
var _music_volume: float = 0.65
var _sfx_volume: float = 0.7
var _music_enabled: bool = true
var _sfx_enabled: bool = true
var _paused: bool = false
var _loop_seconds: float = 8.0
var _clock_last: float = 0.0
var _clock_loops: int = 0
var _clock_tick: int = 0
var _clock_unbounded: bool = false
var _last_bar: int = -1
var _output_latency: float = 0.0


func setup() -> void:
	if is_instance_valid(music):
		return
	music = AudioStreamPlayer.new()
	music.name = "SynchronizedMusic"
	add_child(music)
	for index: int in range(MAX_SFX_VOICES):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "SfxVoice%d" % index
		voice.max_polyphony = 1
		add_child(voice)
		_sfx_voices.append(voice)
	set_volumes(_music_volume, _sfx_volume)


func start_stage(new_stage_index: int, new_bpm: float) -> void:
	setup()
	stage_index = clampi(new_stage_index, 0, 4)
	bpm = clampf(new_bpm, 40.0, 240.0)
	_loop_seconds = 16.0 * 60.0 / bpm
	_clock_last = 0.0
	_clock_loops = 0
	_clock_tick = Time.get_ticks_usec()
	_clock_unbounded = false
	_output_latency = AudioServer.get_output_latency()
	_last_bar = -1
	_paused = false
	current_intensity = "explore"
	pending_intensity = "explore"
	_synchronized = AudioStreamSynchronized.new()
	_synchronized.stream_count = MODES.size()
	var loaded_count: int = 0
	for index: int in range(MODES.size()):
		var path: String = "res://assets/audio/stage_%d_%s.wav" % [stage_index + 1, MODES[index]]
		var stream: AudioStreamWAV = _load_wav(path, true)
		if stream != null:
			_synchronized.set_sync_stream(index, stream)
			if index == 0:
				_loop_seconds = stream.get_length()
			loaded_count += 1
		_synchronized.set_sync_stream_volume(index, 0.0 if index == 0 else SILENT_DB)
	music.stop()
	music.stream = _synchronized if loaded_count > 0 else null
	music.stream_paused = false
	if music.stream != null:
		music.play()
	# Starting another area must retain the player's on-screen Music/SFX choice.
	_apply_volumes()


func request_intensity(mode: String) -> void:
	if mode in MODES:
		pending_intensity = mode


func on_bar(index: int) -> void:
	if index <= _last_bar:
		return
	_last_bar = index
	if pending_intensity == current_intensity or _synchronized == null:
		return
	current_intensity = pending_intensity
	for layer: int in range(MODES.size()):
		_synchronized.set_sync_stream_volume(layer, 0.0 if MODES[layer] == current_intensity else SILENT_DB)


func play_sfx(event_name: String) -> void:
	setup()
	# Callers pass event names, never filesystem paths.
	if not _sfx_enabled or not _valid_event_name(event_name):
		return
	if not _sfx_cache.has(event_name):
		_sfx_cache[event_name] = _load_wav("res://assets/audio/sfx_%s.wav" % event_name, false)
	var stream: AudioStreamWAV = _sfx_cache[event_name] as AudioStreamWAV
	if stream == null or _sfx_volume <= 0.0:
		return
	var selected: AudioStreamPlayer = _sfx_voices[_next_voice]
	for voice: AudioStreamPlayer in _sfx_voices:
		if not voice.playing:
			selected = voice
			break
	_next_voice = (_next_voice + 1) % MAX_SFX_VOICES
	selected.stop()
	selected.stream = stream
	selected.volume_linear = _sfx_volume
	selected.play()


func set_volumes(music_value: float, sfx_value: float) -> void:
	_music_volume = clampf(music_value, 0.0, 1.0)
	_sfx_volume = clampf(sfx_value, 0.0, 1.0)
	_apply_volumes()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	_apply_volumes()


func music_enabled() -> bool:
	return _music_enabled


func set_sfx_enabled(enabled: bool) -> void:
	_sfx_enabled = enabled
	if not _sfx_enabled:
		for voice: AudioStreamPlayer in _sfx_voices:
			voice.stop()
	_apply_volumes()


func sfx_enabled() -> bool:
	return _sfx_enabled


func _apply_volumes() -> void:
	if is_instance_valid(music):
		# Muting must never stop the playback clock or the visual beat.
		music.volume_linear = _music_volume if _music_enabled else 0.0
	for voice: AudioStreamPlayer in _sfx_voices:
		voice.volume_linear = _sfx_volume if _sfx_enabled else 0.0


func pause_music() -> void:
	if _paused:
		return
	playback_time()
	_paused = true
	if is_instance_valid(music):
		music.stream_paused = true
	for voice: AudioStreamPlayer in _sfx_voices:
		voice.stop()


func resume_music() -> void:
	if not _paused:
		return
	_paused = false
	_clock_tick = Time.get_ticks_usec()
	_output_latency = AudioServer.get_output_latency()
	if is_instance_valid(music):
		music.stream_paused = false


func playback_time() -> float:
	# A Dummy/headless audio device has no useful audible clock. RhythmManager
	# advances from its supplied delta in this case, making simulations deterministic.
	if DisplayServer.get_name() == "headless" or AudioServer.get_driver_name() == "Dummy":
		return -1.0
	if not is_instance_valid(music) or music.stream == null:
		return -1.0
	if _paused:
		return _clock_last
	if not music.playing:
		return -1.0
	var now: int = Time.get_ticks_usec()
	var elapsed: float = maxf(0.0, float(now - _clock_tick) / 1000000.0)
	_clock_tick = now
	return _sample_clock(music.get_playback_position(), AudioServer.get_time_since_last_mix(), _output_latency, elapsed)


func _sample_clock(position: float, mix_age: float, output_latency: float, wall_delta: float) -> float:
	# Godot's sample position is corrected to what has reached the speakers.
	# AudioStreamSynchronized may expose a continuous clock; WAV positions wrap.
	# Wall time is only used to disambiguate missed complete loops after a stall.
	var raw: float = maxf(0.0, position)
	if raw >= _loop_seconds and _loop_seconds > 0.0:
		_clock_unbounded = true
	if not _clock_unbounded and _loop_seconds > 0.0:
		var predicted: float = _clock_last + maxf(0.0, wall_delta) + output_latency - mix_age
		var possible_loops: int = maxi(0, int(round((predicted - raw) / _loop_seconds)))
		_clock_loops = maxi(_clock_loops, possible_loops)
		# Also detect a wrap when sampling close to the boundary with jitter.
		if raw + float(_clock_loops) * _loop_seconds + mix_age - output_latency < _clock_last - _loop_seconds * 0.5:
			_clock_loops += 1
	var unwrapped: float = raw + (float(_clock_loops) * _loop_seconds if not _clock_unbounded else 0.0)
	_clock_last = maxf(_clock_last, maxf(0.0, unwrapped + mix_age - output_latency))
	return _clock_last


func _load_wav(path: String, looping: bool) -> AudioStreamWAV:
	var loaded: AudioStreamWAV = null
	if ResourceLoader.exists(path):
		loaded = load(path) as AudioStreamWAV
	elif FileAccess.file_exists(path):
		loaded = AudioStreamWAV.load_from_file(path)
	if loaded == null:
		push_warning("Audio asset unavailable: %s" % path)
		return null
	var stream: AudioStreamWAV = loaded.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	if looping:
		stream.loop_begin = 0
		stream.loop_end = int(round(stream.get_length() * float(stream.mix_rate)))
	return stream


func _valid_event_name(value: String) -> bool:
	if value.is_empty() or value.length() > 40:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not ((code >= 97 and code <= 122) or (code >= 48 and code <= 57) or code == 95):
			return false
	return true
