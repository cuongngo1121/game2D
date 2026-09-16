class_name RhythmManager
extends Node
## Immediate input stays outside this clock; only judgement and beat events use it.

signal beat(index: int)
signal bar(index: int)

const STALLED_AUDIO_FALLBACK_SECONDS := 0.25

var beat_index: int = -1
var bpm: float = 120.0
var offset_ms: float = 0.0
var _audio: Object
var _elapsed: float = 0.0
var _paused: bool = false
var _bar_index: int = -1
var _last_sampled_audio: float = -1.0
var _stalled_audio_seconds: float = 0.0


func setup(audio_manager: Object) -> void:
	if is_instance_valid(_audio) and _audio.has_method("on_bar"):
		var old_callback: Callable = Callable(_audio, "on_bar")
		if bar.is_connected(old_callback):
			bar.disconnect(old_callback)
	_audio = audio_manager
	if is_instance_valid(_audio) and _audio.has_method("on_bar"):
		var callback: Callable = Callable(_audio, "on_bar")
		if not bar.is_connected(callback):
			bar.connect(callback)


func configure(new_bpm: float, new_offset_ms: float = 0.0) -> void:
	bpm = clampf(new_bpm, 40.0, 240.0)
	offset_ms = clampf(new_offset_ms, -300.0, 300.0)
	reset()


func reset() -> void:
	_elapsed = 0.0
	_paused = false
	beat_index = -1
	_bar_index = -1
	_last_sampled_audio = -1.0
	_stalled_audio_seconds = 0.0


func update(delta: float) -> void:
	if _paused:
		return
	var sampled: float = -1.0
	if is_instance_valid(_audio) and _audio.has_method("playback_time"):
		sampled = float(_audio.call("playback_time"))
	if sampled >= 0.0:
		# The audible playhead remains authoritative while it advances. Some Android
		# audio backends can report one frozen value for several frames after an
		# overlay/reward pause is dismissed, though the game itself is running again.
		# Without this bounded fallback no new beat is emitted, which freezes every
		# beat-driven enemy and boss attack in later rooms.
		if _last_sampled_audio < 0.0 or sampled > _last_sampled_audio + 0.0001:
			_elapsed = maxf(_elapsed, sampled)
			_stalled_audio_seconds = 0.0
		else:
			_stalled_audio_seconds += maxf(0.0, delta)
			if _stalled_audio_seconds >= STALLED_AUDIO_FALLBACK_SECONDS:
				_elapsed += maxf(0.0, delta)
		_last_sampled_audio = maxf(_last_sampled_audio, sampled)
	else:
		_elapsed += maxf(0.0, delta)
		_last_sampled_audio = -1.0
		_stalled_audio_seconds = 0.0
	var latest_beat: int = int(floor(_adjusted_time() / beat_seconds()))
	if latest_beat <= beat_index:
		return
	# Emit only the current beat after a slow frame. Replaying missed beats would
	# create simultaneous enemy attacks and punish players for a device stall.
	beat_index = latest_beat
	beat.emit(beat_index)
	var latest_bar: int = int(floor(float(beat_index) / 4.0))
	if latest_bar > _bar_index:
		_bar_index = latest_bar
		bar.emit(_bar_index)


func beat_seconds() -> float:
	return 60.0 / bpm


func phase() -> float:
	return fposmod(_adjusted_time(), beat_seconds()) / beat_seconds()


func is_perfect(window_ms: float = 120.0) -> bool:
	if _paused:
		return false
	var distance_seconds: float = minf(phase(), 1.0 - phase()) * beat_seconds()
	return distance_seconds <= maxf(0.0, window_ms) / 1000.0 + 0.000001


func pause_music() -> void:
	if _paused:
		return
	_paused = true
	if is_instance_valid(_audio) and _audio.has_method("pause_music"):
		_audio.call("pause_music")


func resume_music() -> void:
	if not _paused:
		return
	if is_instance_valid(_audio) and _audio.has_method("resume_music"):
		_audio.call("resume_music")
	_paused = false
	# Give a real audio backend a short chance to publish its new sample before
	# treating a still value as stalled. Explicit pause time is never caught up.
	_stalled_audio_seconds = 0.0


func _adjusted_time() -> float:
	# Positive calibration means the player hears/sees the beat later.
	return _elapsed - offset_ms / 1000.0
