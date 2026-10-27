class_name Loudness
## Plays every song at the same loudness (as streaming services do): a song's integrated loudness (ITU-R BS.1770-4,
## the LUFS of ffmpeg's ebur128) is measured once on a worker thread, cached by the audio's size and length, and its
## bus (Music, MusicPreview) gets the gain that brings it to TARGET_LUFS. The songs played most measured -13.5 to
## -3.6 LUFS (median -7.9, doc/research loudness notes); the sound effects are levelled against TARGET_LUFS.

const TARGET_LUFS := -14.0
## Gain until a new song is measured: the median song's.
const DEFAULT_GAIN_DB := -6.0
## A very quiet song is raised at most this much (the Master limiter catches its peaks).
const MAX_BOOST_DB := 6.0
## The audio is decoded this many times faster than real time for measuring: it reads 0.2-0.3 LU lower than ffmpeg on
## the songs tried, for a quarter of the work (about 0.7 s for a 3 minute song on a Mac).
const RATE_SCALE := 4.0
const FADE_SECONDS := 1.0
const CACHE_PATH := "user://loudness.json"

## key -> LUFS
static var _cache := {}
static var _cache_loaded := false
## bus -> the key whose gain it should have
static var _bus_keys := {}
## key -> buses waiting for its measurement
static var _measuring := {}
## key -> its measurement's WorkerThreadPool task, waited for once it is done; the game closing stops them and waits
## (a task still decoding at exit crashed the engine)
static var _tasks := {}
static var _stopping := false

## The cache key of a song's audio: its byte size and length, the same for the song and its preview.
static func key(byte_size: int, stream: AudioStream) -> String:
	return "%d|%.2f" % [byte_size, stream.get_length()]

## Sets bus to the gain that brings this song to TARGET_LUFS: at once when it was measured before, else the default
## now and the measured gain (faded over FADE_SECONDS) once a worker thread has measured it.
static func apply(bus: StringName, stream: AudioStream, song_key: String) -> void:
	_load_cache()
	_bus_keys[bus] = song_key
	if _cache.has(song_key):
		_amplify(bus).volume_db = gain_db(_cache[song_key])
		return
	_amplify(bus).volume_db = DEFAULT_GAIN_DB
	if _measuring.has(song_key):
		(_measuring[song_key] as Array).append(bus)
		return
	_measuring[song_key] = [bus]
	var root := (Engine.get_main_loop() as SceneTree).root
	if not root.tree_exiting.is_connected(_stop):
		root.tree_exiting.connect(_stop)
	_tasks[song_key] = WorkerThreadPool.add_task(func() -> void:
		var lufs := measure(stream)
		if not _stopping:
			_measured.call_deferred(song_key, lufs), false, "Loudness")

static func _stop() -> void:
	_stopping = true
	for task: int in _tasks.values():
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()

## The gain for a song of this loudness.
static func gain_db(lufs: float) -> float:
	return minf(TARGET_LUFS - lufs, MAX_BOOST_DB) if is_finite(lufs) else DEFAULT_GAIN_DB

static func _measured(song_key: String, lufs: float) -> void:
	print("Loudness: %s %.1f LUFS, gain %.1f dB" % [song_key, lufs, gain_db(lufs)])
	_cache[song_key] = lufs
	var file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_cache))
	for bus: StringName in _measuring[song_key]:
		if _bus_keys.get(bus) == song_key:
			var tween := (Engine.get_main_loop() as SceneTree).create_tween()
			tween.tween_property(_amplify(bus), ^"volume_db", gain_db(lufs), FADE_SECONDS)
	_measuring.erase(song_key)
	if _tasks.has(song_key):
		WorkerThreadPool.wait_for_task_completion(_tasks[song_key])
		_tasks.erase(song_key)

static func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	if FileAccess.file_exists(CACHE_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_PATH))
		if saved is Dictionary:
			_cache = saved

## The bus's gain effect, added first in its chain when missing.
static func _amplify(bus: StringName) -> AudioEffectAmplify:
	var index := AudioServer.get_bus_index(bus)
	for i in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, i) is AudioEffectAmplify:
			return AudioServer.get_bus_effect(index, i)
	var amplify := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(index, amplify, 0)
	return amplify

## Integrated loudness in LUFS (BS.1770-4: K-weighted, 400 ms blocks every 100 ms, gated at -70 LUFS and 10 LU
## under the ungated mean); -INF for silence. Runs on any thread.
static func measure(stream: AudioStream) -> float:
	var playback := stream.instantiate_playback()
	if playback == null:
		return -INF
	playback.start(0.0)
	var fs := AudioServer.get_mix_rate() / RATE_SCALE
	var shelf := _shelf(fs)
	var highpass := _highpass(fs)
	var state := PackedFloat64Array()
	state.resize(16)
	# mean square of every 100 ms
	var tenths := PackedFloat64Array()
	var left := int(stream.get_length() * fs)
	while left > 0 and not _stopping:
		var frames := playback.mix_audio(RATE_SCALE, int(fs * 0.1))
		if frames.is_empty():
			break
		tenths.append(_k_weighted_power(frames, shelf, highpass, state))
		left -= frames.size()
	playback.stop()
	var blocks := PackedFloat64Array()
	for i in tenths.size() - 3:
		var power := (tenths[i] + tenths[i + 1] + tenths[i + 2] + tenths[i + 3]) / 4.0
		if power > pow(10.0, (-70.0 + 0.691) / 10.0):
			blocks.append(power)
	if blocks.is_empty():
		return -INF
	var relative := _mean(blocks) / 10.0
	var gated := PackedFloat64Array()
	for power in blocks:
		if power > relative:
			gated.append(power)
	return -0.691 + 10.0 * log(_mean(gated)) / log(10.0)

static func _mean(values: PackedFloat64Array) -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum / values.size()

## The K-weighting's high shelf and high pass as biquads [b0, b1, b2, a1, a2] at fs (BS.1770's analog designs, as
## pyloudnorm builds them for any rate).
static func _shelf(fs: float) -> PackedFloat64Array:
	var a := pow(10.0, 3.99984385397 / 40.0)
	var w := TAU * 1681.9744509555319 / fs
	var alpha := sin(w) / (2.0 * 0.7071752369554193)
	var s := 2.0 * sqrt(a) * alpha
	var a0 := (a + 1.0) - (a - 1.0) * cos(w) + s
	return PackedFloat64Array([a * ((a + 1.0) + (a - 1.0) * cos(w) + s) / a0, -2.0 * a * ((a - 1.0) + (a + 1.0) * cos(w)) / a0,
			a * ((a + 1.0) + (a - 1.0) * cos(w) - s) / a0, 2.0 * ((a - 1.0) - (a + 1.0) * cos(w)) / a0,
			((a + 1.0) - (a - 1.0) * cos(w) - s) / a0])

static func _highpass(fs: float) -> PackedFloat64Array:
	var w := TAU * 38.13547087613982 / fs
	var alpha := sin(w) / (2.0 * 0.5003270373253953)
	var a0 := 1.0 + alpha
	return PackedFloat64Array([(1.0 + cos(w)) / 2.0 / a0, -(1.0 + cos(w)) / a0, (1.0 + cos(w)) / 2.0 / a0,
			-2.0 * cos(w) / a0, (1.0 - alpha) / a0])

## Mean square of the K-weighted left plus right; state carries both filters' memory for both channels between calls.
static func _k_weighted_power(frames: PackedVector2Array, h: PackedFloat64Array, p: PackedFloat64Array,
		state: PackedFloat64Array) -> float:
	var hb0 := h[0]; var hb1 := h[1]; var hb2 := h[2]; var ha1 := h[3]; var ha2 := h[4]
	var pb0 := p[0]; var pb1 := p[1]; var pb2 := p[2]; var pa1 := p[3]; var pa2 := p[4]
	var lx1 := state[0]; var lx2 := state[1]; var ly1 := state[2]; var ly2 := state[3]
	var lu1 := state[4]; var lu2 := state[5]; var lv1 := state[6]; var lv2 := state[7]
	var rx1 := state[8]; var rx2 := state[9]; var ry1 := state[10]; var ry2 := state[11]
	var ru1 := state[12]; var ru2 := state[13]; var rv1 := state[14]; var rv2 := state[15]
	var sum := 0.0
	for frame in frames:
		var ly := hb0 * frame.x + hb1 * lx1 + hb2 * lx2 - ha1 * ly1 - ha2 * ly2
		lx2 = lx1; lx1 = frame.x; ly2 = ly1; ly1 = ly
		var lv := pb0 * ly + pb1 * lu1 + pb2 * lu2 - pa1 * lv1 - pa2 * lv2
		lu2 = lu1; lu1 = ly; lv2 = lv1; lv1 = lv
		var ry := hb0 * frame.y + hb1 * rx1 + hb2 * rx2 - ha1 * ry1 - ha2 * ry2
		rx2 = rx1; rx1 = frame.y; ry2 = ry1; ry1 = ry
		var rv := pb0 * ry + pb1 * ru1 + pb2 * ru2 - pa1 * rv1 - pa2 * rv2
		ru2 = ru1; ru1 = ry; rv2 = rv1; rv1 = rv
		sum += lv * lv + rv * rv
	var values := [lx1, lx2, ly1, ly2, lu1, lu2, lv1, lv2, rx1, rx2, ry1, ry2, ru1, ru2, rv1, rv2]
	for i in 16:
		state[i] = values[i]
	return sum / frames.size()
