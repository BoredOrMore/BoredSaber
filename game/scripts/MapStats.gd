extends RefCounted
class_name MapStats

# Note count, length, notes per second (NPS) and swing gap of each map difficulty, so the menu can
# show them and filter by them. Counting parses the whole difficulty file, so results are cached in memory
# and in a file, and the song list is counted on a background thread.

static var CACHE_FILEPATH := Constants.CONFIG_ROOT_PATH + "map_stats.json"

# "<map path>|<difficulty file>" -> {notes, seconds, nps, gap}
static var _cache := {}
static var _cache_mutex := Mutex.new()
static var _loaded := false
static var _thread: Thread

## Returns {notes, seconds, nps, gap} for one difficulty, counting it now if it isn't cached yet.
static func get_stats(info: MapInfo, difficulty: DifficultyInfo) -> Dictionary:
	var stats := get_cached(info, difficulty)
	if stats.is_empty():
		stats = _count(info, difficulty)
		_store(info, difficulty, stats)
	return stats

## Returns the cached stats for one difficulty, or an empty dictionary if it hasn't been counted.
static func get_cached(info: MapInfo, difficulty: DifficultyInfo) -> Dictionary:
	_load_cache()
	_cache_mutex.lock()
	var stats: Dictionary = _cache.get(_key(info, difficulty), {})
	_cache_mutex.unlock()
	# entries saved before the swing gap existed are counted again
	return stats if stats.has("gap") else {}

## Counts every uncounted difficulty of the songs on a background thread, then saves the cache
## and calls on_done on the main thread. Does nothing while a previous pass is still running.
static func count_all_async(songs: Array[MapInfo], on_done: Callable) -> void:
	_load_cache()
	if _thread != null:
		if _thread.is_alive():
			return
		_thread.wait_to_finish()
	_thread = Thread.new()
	_thread.start(_count_all.bind(songs.duplicate(), on_done))

## Thread body for count_all_async.
static func _count_all(songs: Array[MapInfo], on_done: Callable) -> void:
	var counted := false
	for info in songs:
		for difficulty in info.difficulty_beatmaps:
			if get_cached(info, difficulty).is_empty():
				_store(info, difficulty, _count(info, difficulty))
				counted = true
	if counted:
		_save_cache.call_deferred()
	on_done.call_deferred()

## Parses one difficulty file and counts its notes (bombs excluded) up to the last one.
static func _count(info: MapInfo, difficulty: DifficultyInfo) -> Dictionary:
	var map_data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, difficulty.beatmap_filename))
	var notes := 0
	var last_beat := 0.0
	# beats of each hand's notes, left then right
	var hand_beats: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
	if map_data != null and map_data.has("_notes"):
		for note: Variant in Utils.get_array(map_data, "_notes", []):
			var type := int((note as Dictionary).get("_type", 0)) if note is Dictionary else 3
			if type == 0 or type == 1:
				notes += 1
				last_beat = maxf(last_beat, float((note as Dictionary).get("_time", 0.0)))
				hand_beats[type].append(float((note as Dictionary).get("_time", 0.0)))
	elif map_data != null:
		# v4 keeps the colour in colorNotesData, indexed by "i"
		var note_data := Utils.get_array(map_data, "colorNotesData", [])
		for note: Variant in Utils.get_array(map_data, "colorNotes", []):
			if note is Dictionary:
				var n := note as Dictionary
				notes += 1
				last_beat = maxf(last_beat, float(n.get("b", 0.0)))
				var color := int(n.get("c", -1))
				var index := int(n.get("i", -1))
				if 0 <= index and index < note_data.size() and note_data[index] is Dictionary:
					color = int((note_data[index] as Dictionary).get("c", color))
				if color == 0 or color == 1:
					hand_beats[color].append(float(n.get("b", 0.0)))
	var seconds_per_beat := 60.0 / info.beats_per_minute if info.beats_per_minute > 0.0 else 0.0
	var seconds := last_beat * seconds_per_beat
	return {"notes": notes, "seconds": seconds, "nps": notes / seconds if seconds > 0.0 else 0.0,
		"gap": _swing_gap(hand_beats, seconds_per_beat)}

## Same-hand notes closer than this are one swing (a stack or a window), not two. From
## doc/research/reaction-time-and-swing-gap.md, like the median below.
const SAME_SWING_SECONDS := 0.05

## Median seconds between two swings of one hand, or 0 with too few notes.
static func _swing_gap(hand_beats: Array[PackedFloat32Array], seconds_per_beat: float) -> float:
	var gaps := PackedFloat32Array()
	for beats in hand_beats:
		beats.sort()
		for i in range(1, beats.size()):
			var gap := (beats[i] - beats[i - 1]) * seconds_per_beat
			if gap >= SAME_SWING_SECONDS:
				gaps.append(gap)
	if gaps.is_empty():
		return 0.0
	gaps.sort()
	return gaps[gaps.size() / 2]

## Seconds a note is visible before it reaches the player, at the current Speed modifier.
static func reaction_seconds(info: MapInfo, difficulty: DifficultyInfo) -> float:
	return reaction_seconds_for(info.beats_per_minute, difficulty.note_jump_movement_speed, difficulty.note_jump_start_beat_offset)

## Seconds a note is visible before it reaches the player for a map's BPM, note speed and offset, at
## the current Speed modifier; 0 without a BPM.
static func reaction_seconds_for(bpm: float, njs: float, offset: float) -> float:
	if bpm <= 0.0:
		return 0.0
	return Map.half_jump_beats_for(bpm, njs, offset) * 60.0 / bpm / _speed()

## The Speed modifier as a factor.
static func _speed() -> float:
	return maxf(Settings.music_speed / 100.0, 0.01)

## Index in Constants.REACTION_LEVELS for a reaction time in seconds.
static func reaction_level(seconds: float) -> int:
	for i in Constants.REACTION_LEVELS.size():
		if seconds >= float(Constants.REACTION_LEVELS[i][2]):
			return i
	return Constants.REACTION_LEVELS.size() - 1

## Index in Constants.SWING_PACE_LEVELS for a median swing gap in seconds.
static func swing_pace_level(gap: float) -> int:
	for i in Constants.SWING_PACE_LEVELS.size():
		if gap >= float(Constants.SWING_PACE_LEVELS[i][1]):
			return i
	return Constants.SWING_PACE_LEVELS.size() - 1

## Reaction time level of one difficulty, at the current Speed modifier.
static func reaction_level_of(info: MapInfo, difficulty: DifficultyInfo) -> int:
	return reaction_level(reaction_seconds(info, difficulty))

## The saved NPS filter entry [id, label, min, max] from Constants.NPS_FILTERS.
static func nps_filter() -> Array:
	return Constants.NPS_FILTERS[clampi(Settings.song_filter_nps, 0, Constants.NPS_FILTERS.size() - 1)]

## The saved length filter entry [id, label, min, max] from Constants.LENGTH_FILTERS.
static func length_filter() -> Array:
	return Constants.LENGTH_FILTERS[clampi(Settings.song_filter_length, 0, Constants.LENGTH_FILTERS.size() - 1)]

## True if value is inside a filter entry; max <= 0 means no upper limit.
static func in_filter(value: float, filter: Array) -> bool:
	return value >= float(filter[2]) and (float(filter[3]) <= 0.0 or value < float(filter[3]))

## Formats a difficulty as "3:24 · Reaction time: Quick (0.72 s)" over "Swing pace: Brisk".
static func describe(info: MapInfo, difficulty: DifficultyInfo, stats: Dictionary) -> String:
	var seconds := int(stats.get("seconds", 0.0))
	var reaction := reaction_seconds(info, difficulty)
	var text := "%d:%02d · Reaction time: %s (%.2f s)" % [seconds / 60, seconds % 60,
		Constants.REACTION_LEVELS[reaction_level(reaction)][0], reaction]
	var gap := float(stats.get("gap", 0.0)) / _speed()
	if gap > 0.0:
		text += "\nSwing pace: %s" % Constants.SWING_PACE_LEVELS[swing_pace_level(gap)][0]
	return text

## The reaction time filter choices for a dropdown: [id, label], id 0 being any reaction time.
static func reaction_filters() -> Array:
	var filters := [[0, Constants.ANY_REACTION_LABEL]]
	for i in Constants.REACTION_LEVELS.size():
		filters.append([i + 1, Constants.REACTION_LEVELS[i][0]])
	return filters

## Cache key of one difficulty.
static func _key(info: MapInfo, difficulty: DifficultyInfo) -> String:
	return info.filepath + "|" + difficulty.beatmap_filename

## Puts one difficulty's stats in the in-memory cache.
static func _store(info: MapInfo, difficulty: DifficultyInfo, stats: Dictionary) -> void:
	_cache_mutex.lock()
	_cache[_key(info, difficulty)] = stats
	_cache_mutex.unlock()

## Reads the cache file once.
static func _load_cache() -> void:
	_cache_mutex.lock()
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(CACHE_FILEPATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_FILEPATH))
			if parsed is Dictionary:
				_cache = parsed
	_cache_mutex.unlock()

## Writes the cache file.
static func _save_cache() -> void:
	_cache_mutex.lock()
	var text := JSON.stringify(_cache)
	_cache_mutex.unlock()
	var file := FileAccess.open(CACHE_FILEPATH, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
