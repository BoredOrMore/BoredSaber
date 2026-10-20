class_name SongTags
extends RefCounted
## BeatSaver tags of the songs in the library (genre, style), kept in a file so "Auto" can pick an environment
## by genre offline (EventDriver.map_environment). Map files have no tags: they are saved when a song is
## downloaded, and songs already in the library are looked up on BeatSaver once, the first time the game is online.

## Saved tags, keyed by song folder name; an empty list means looked up and BeatSaver had none.
const CACHE_FILE := "song_tags.json"
## Songs looked up per request, BeatSaver's limit for /maps/hash.
const BATCH := 50
const HASH_URL := "https://api.beatsaver.com/maps/hash/%s"

static var _cache: Dictionary = {}
static var _loaded := false
## A lookup ran this session; it is not tried again until the next start.
static var _looked_up := false

## Folder (or zip) name of a song in Songs/, which is its BeatSaver hash when it was downloaded here.
static func folder_of(map: MapInfo) -> String:
	return map.filepath.trim_suffix("/").get_file().trim_suffix(".zip")

## Tags saved for a song, empty when none are known.
static func tags_of(map: MapInfo) -> PackedStringArray:
	return PackedStringArray(_load().get(folder_of(map), []))

## Saves the tags of a song just downloaded into this folder.
static func remember(folder: String, tags: PackedStringArray) -> void:
	_load()[folder] = Array(tags)
	_save()

## Looks up on BeatSaver the tags of the songs that have none saved, once per session; done is called after each
## batch that arrives. Without a connection nothing is saved, so the next start tries again.
static func look_up_missing(parent: Node, maps: Array[MapInfo], done: Callable) -> void:
	if _looked_up:
		return
	_looked_up = true
	var folders := {}
	for map in maps:
		var folder := folder_of(map)
		if not _load().has(folder):
			var hash := _beatsaver_hash(map)
			if not hash.is_empty():
				folders[hash] = folder
	if folders.is_empty():
		return
	var request := HTTPRequest.new()
	request.use_threads = OS.get_name() != "Web"
	parent.add_child(request)
	var hashes: Array = folders.keys()
	for start in range(0, hashes.size(), BATCH):
		var batch := hashes.slice(start, start + BATCH)
		if request.request(HASH_URL % ",".join(batch)) != OK:
			break
		var response: Array = await request.request_completed
		var result: int = response[0]
		var code: int = response[1]
		if result != HTTPRequest.RESULT_SUCCESS or (code != 200 and code != 404):
			break
		var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8()) if code == 200 else null
		for hash: String in batch:
			# one hash returns the map itself, several return the maps keyed by hash (null when not found)
			var info: Variant = parsed if batch.size() == 1 else (parsed as Dictionary).get(hash) if parsed is Dictionary else null
			_cache[folders[hash]] = Utils.get_array(info as Dictionary, "tags", []) if info is Dictionary else []
		_save()
		done.call()
	request.queue_free()

## The song's BeatSaver hash: its folder name when it is one, else the SHA-1 of Info.dat followed by its
## difficulty files, as BeatSaver computes it for v2 and v3 maps. Empty when it can't be worked out (v4 maps
## hash more files).
static func _beatsaver_hash(map: MapInfo) -> String:
	var folder := folder_of(map)
	if folder.length() == 40 and folder.is_valid_hex_number():
		return folder.to_lower()
	if map.version.begins_with("4"):
		return ""
	var info := Utils.read_binary_file(map.filepath, "Info.dat")
	if info.is_empty():
		info = Utils.read_binary_file(map.filepath, "info.dat")
	if info.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	context.update(info)
	for difficulty in map.difficulty_beatmaps:
		var data := Utils.read_binary_file(map.filepath, difficulty.beatmap_filename)
		if data.is_empty():
			return ""
		context.update(data)
	return context.finish().hex_encode()

## The saved tags, read from the file the first time.
static func _load() -> Dictionary:
	if not _loaded:
		_loaded = true
		var text := FileAccess.get_file_as_string(Constants.APPDATA_PATH + CACHE_FILE)
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		_cache = parsed as Dictionary if parsed is Dictionary else {}
	return _cache

## Writes the saved tags to the file.
static func _save() -> void:
	var file := FileAccess.open(Constants.APPDATA_PATH + CACHE_FILE, FileAccess.WRITE)
	if file == null:
		vr.log_file_error(FileAccess.get_open_error(), Constants.APPDATA_PATH + CACHE_FILE, "SongTags._save")
		return
	file.store_string(JSON.stringify(_cache))
