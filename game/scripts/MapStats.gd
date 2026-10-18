extends RefCounted
class_name MapStats

# Note count, length and notes per second (NPS) of each map difficulty, so the menu can show them
# and filter by them. Counting parses the whole difficulty file, so results are cached in memory
# and in a file, and the song list is counted on a background thread.

static var CACHE_FILEPATH := Constants.CONFIG_ROOT_PATH + "map_stats.json"

# "<map path>|<difficulty file>" -> {notes, seconds, nps}
static var _cache := {}
static var _cache_mutex := Mutex.new()
static var _loaded := false
static var _thread: Thread

## Returns {notes, seconds, nps} for one difficulty, counting it now if it isn't cached yet.
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
	return stats

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
	if map_data != null and map_data.has("_notes"):
		for note: Variant in Utils.get_array(map_data, "_notes", []):
			if note is Dictionary and int((note as Dictionary).get("_type", 0)) != 3:
				notes += 1
				last_beat = maxf(last_beat, float((note as Dictionary).get("_time", 0.0)))
	elif map_data != null:
		for note: Variant in Utils.get_array(map_data, "colorNotes", []):
			if note is Dictionary:
				notes += 1
				last_beat = maxf(last_beat, float((note as Dictionary).get("b", 0.0)))
	var seconds := last_beat * 60.0 / info.beats_per_minute if info.beats_per_minute > 0.0 else 0.0
	return {"notes": notes, "seconds": seconds, "nps": notes / seconds if seconds > 0.0 else 0.0}

## Formats stats as "3:24 · 5.2 NPS".
static func describe(stats: Dictionary) -> String:
	var seconds := int(stats.get("seconds", 0.0))
	return "%d:%02d · %.1f NPS" % [seconds / 60, seconds % 60, float(stats.get("nps", 0.0))]

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
