extends RefCounted
class_name MapStats

# Note count, length, notes per second (NPS), swing gap, swing flow and wall workout of each map difficulty, so the menu can
# show them and filter by them. Counting parses the whole difficulty file, so results are cached in memory
# and in a file, and the song list is counted on a background thread.

static var CACHE_FILEPATH := Constants.CONFIG_ROOT_PATH + "map_stats.json"

# "<map path>|<difficulty file>" -> {notes, seconds, nps, gap, flow, squats, side_steps, sets, set_seconds}
static var _cache := {}
static var _cache_mutex := Mutex.new()
static var _loaded := false
static var _thread: Thread
## Bumped when the counting rules change, so cached entries are counted again.
const STATS_VERSION := 2

## Returns {notes, seconds, nps, gap, flow} for one difficulty, counting it now if it isn't cached yet.
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
	# entries counted by older rules are counted again
	return stats if int(stats.get("version", 0)) == STATS_VERSION else {}

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
	# [beat, cut direction, column] of each hand's notes, left then right
	var hand_notes: Array[Array] = [[], []]
	if map_data != null and map_data.has("_notes"):
		for note: Variant in Utils.get_array(map_data, "_notes", []):
			var type := int((note as Dictionary).get("_type", 0)) if note is Dictionary else 3
			if type == 0 or type == 1:
				var n := note as Dictionary
				notes += 1
				last_beat = maxf(last_beat, float(n.get("_time", 0.0)))
				hand_beats[type].append(float(n.get("_time", 0.0)))
				hand_notes[type].append([float(n.get("_time", 0.0)), int(n.get("_cutDirection", 8)), int(n.get("_lineIndex", 1))])
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
				# v3 keeps direction and column on the note, v4 in colorNotesData
				var data := n
				if 0 <= index and index < note_data.size() and note_data[index] is Dictionary:
					data = note_data[index] as Dictionary
					color = int(data.get("c", color))
				if color == 0 or color == 1:
					hand_beats[color].append(float(n.get("b", 0.0)))
					hand_notes[color].append([float(n.get("b", 0.0)), int(data.get("d", 8)), int(data.get("x", 1))])
	var seconds_per_beat := 60.0 / info.beats_per_minute if info.beats_per_minute > 0.0 else 0.0
	var seconds := last_beat * seconds_per_beat
	var stats := {"version": STATS_VERSION, "notes": notes, "seconds": seconds, "nps": notes / seconds if seconds > 0.0 else 0.0,
		"gap": _swing_gap(hand_beats, seconds_per_beat), "flow": _awkward_percent(hand_notes, seconds_per_beat)}
	stats.merge(_workout(_walls(map_data), seconds_per_beat))
	return stats

## [beat, duration in beats, column, layer, width, height] of each wall, for v2, v3 and v4 maps.
static func _walls(map_data: Variant) -> Array[Array]:
	var walls: Array[Array] = []
	if map_data == null:
		return walls
	if map_data.has("_obstacles"):
		for wall: Variant in Utils.get_array(map_data, "_obstacles", []):
			if wall is Dictionary:
				var w := wall as Dictionary
				# type 0 is full height, 1 a crouch wall, others give their own layer and height
				var type := int(w.get("_type", 0))
				var layer := 0.0 if type == 0 else 2.0 if type == 1 else float(w.get("_lineLayer", 0))
				var height := 5.0 if type == 0 else 3.0 if type == 1 else float(w.get("_height", 0))
				walls.append([float(w.get("_time", 0.0)), float(w.get("_duration", 0.0)), float(w.get("_lineIndex", 0)),
					layer, float(w.get("_width", 0)), height])
	else:
		# v4 keeps the shape in obstaclesData, indexed by "i"
		var wall_data := Utils.get_array(map_data, "obstaclesData", [])
		for wall: Variant in Utils.get_array(map_data, "obstacles", []):
			if wall is Dictionary:
				var w := wall as Dictionary
				var index := int(w.get("i", -1))
				var data: Dictionary = wall_data[index] if 0 <= index and index < wall_data.size() and wall_data[index] is Dictionary else w
				walls.append([float(w.get("b", 0.0)), float(data.get("d", 0.0)), float(data.get("x", 0)),
					float(data.get("y", 0)), float(data.get("w", 0)), float(data.get("h", 0))])
	return walls

## Walls of one move starting closer than this are one move (doc/research/wall-workout.md).
const SAME_MOVE_SECONDS := 0.1
## A set is at least this many moves of one kind, each within SET_GAP_SECONDS of the last (ACSM's 8-12
## repetitions per set; see doc/research/wall-workout.md).
const SET_MOVES := 8
const SET_GAP_SECONDS := 4.0

## Squats, side steps and sets the walls ask for (doc/research/wall-workout.md). The player stands between
## the middle columns 1 and 2: a wall over the head row with room below (bottom at layer 1 or 2, top above 2)
## across both middle columns is a squat; one from the floor at least 3 high over one middle column is a step
## to the other side. Sets are runs of one kind of move (SET_MOVES, SET_GAP_SECONDS); set_seconds is the time
## from the first to the last move of each set.
static func _workout(walls: Array[Array], seconds_per_beat: float) -> Dictionary:
	walls.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	# [start, kind] of each move: 0 squat, 1 step right (wall on the left), 2 step left
	var moves: Array[Array] = []
	for wall in walls:
		var x: float = wall[2]
		var y: float = wall[3]
		var width: float = wall[4]
		var height: float = wall[5]
		var covers_left := x <= 1.0 and 1.0 < x + width
		var covers_right := x <= 2.0 and 2.0 < x + width
		var kind := -1
		if y >= 1.0 and y <= 2.0 and 2.0 < y + height and covers_left and covers_right:
			kind = 0
		elif y < 0.5 and height >= 3.0 and covers_left != covers_right:
			kind = 1 if covers_left else 2
		if kind < 0:
			continue
		var start: float = wall[0] * seconds_per_beat
		if moves.is_empty() or moves[-1][1] != kind or start - moves[-1][0] >= SAME_MOVE_SECONDS:
			moves.append([start, kind])
	var squats := 0
	var sets := 0
	var set_seconds := 0.0
	var run_start := 0
	for i in moves.size() + 1:
		if i < moves.size() and moves[i][1] == 0:
			squats += 1
		# a run of one kind (squats, or steps to either side) ends at a change of kind or a long gap
		var ends: bool = i == moves.size() or (moves[i][1] == 0) != (moves[run_start][1] == 0) \
			or moves[i][0] - moves[i - 1][0] > SET_GAP_SECONDS
		if i > 0 and ends:
			if i - run_start >= SET_MOVES:
				sets += 1
				set_seconds += moves[i - 1][0] - moves[run_start][0]
			run_start = i
	return {"squats": squats, "side_steps": moves.size() - squats, "sets": sets, "set_seconds": set_seconds}

## Index in Constants.WORKOUT_LEVELS for a difficulty's stats: none, some sets, or mostly sets.
static func workout_level(stats: Dictionary) -> int:
	if int(stats.get("sets", 0)) == 0:
		return 0
	var seconds := float(stats.get("seconds", 0.0))
	return 2 if seconds > 0.0 and float(stats.get("set_seconds", 0.0)) / seconds >= Constants.WORKOUT_SET_SHARE else 1

## Swings further apart than this leave time to reposition, so they are never awkward (untuned).
const AWKWARD_WITHIN_SECONDS := 1.0
## Unit vector of each cut direction (0 up, 1 down, 2 left, 3 right, 4 up-left, 5 up-right, 6 down-left,
## 7 down-right); 8 (any direction, a dot) has none.
const CUT_VECTORS: Array[Vector2] = [Vector2(0, 1), Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0),
	Vector2(-0.7071, 0.7071), Vector2(0.7071, 0.7071), Vector2(-0.7071, -0.7071), Vector2(0.7071, -0.7071)]

## Percent of swings that don't flow, from doc/research/swing-flow.md: within AWKWARD_WITHIN_SECONDS of the
## same hand's last swing, a swing that turns 90 degrees from the natural follow-through (the reverse of the
## last swing) counts 1, one that turns further (a reset: down then down again) counts 2, and reaching the far
## column of the other hand's side (left hand in column 3, right hand in column 0) counts 1.
static func _awkward_percent(hand_notes: Array[Array], seconds_per_beat: float) -> float:
	var swings := 0
	var awkward := 0
	for hand in hand_notes.size():
		var hand_list := hand_notes[hand]
		hand_list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var last_time := -INF
		var last_vector := Vector2.ZERO
		var i := 0
		while i < hand_list.size():
			# notes this close together are one swing (a stack or a window); its first arrow sets the direction
			var time: float = hand_list[i][0] * seconds_per_beat
			var vector := Vector2.ZERO
			var crosses := false
			while i < hand_list.size() and hand_list[i][0] * seconds_per_beat - time < SAME_SWING_SECONDS:
				var direction: int = hand_list[i][1]
				if vector == Vector2.ZERO and direction >= 0 and direction < CUT_VECTORS.size():
					vector = CUT_VECTORS[direction]
				crosses = crosses or hand_list[i][2] == (3 if hand == 0 else 0)
				i += 1
			swings += 1
			if crosses:
				awkward += 1
			if time - last_time < AWKWARD_WITHIN_SECONDS and vector != Vector2.ZERO and last_vector != Vector2.ZERO:
				var turn := rad_to_deg(vector.angle_to(-last_vector))
				if absf(turn) > 112.5:
					awkward += 2
				elif absf(turn) > 67.5:
					awkward += 1
			# a dot is cut along the natural follow-through
			last_vector = vector if vector != Vector2.ZERO else -last_vector
			last_time = time
	return 100.0 * awkward / swings if swings > 0 else 0.0

## Index in Constants.FLOW_LEVELS for a percent of awkward swings.
static func flow_level(percent: float) -> int:
	var level := 0
	for i in Constants.FLOW_LEVELS.size():
		if percent >= float(Constants.FLOW_LEVELS[i][1]):
			level = i
	return level

## True when a difficulty's swings are too tangled to list it (Constants.FLOW_HIDDEN_PERCENT).
static func is_unplayable(stats: Dictionary) -> bool:
	return float(stats.get("flow", 0.0)) >= Constants.FLOW_HIDDEN_PERCENT

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

## Index in Constants.DIFFICULTY_LEVELS that a reaction time in seconds reads like.
static func reaction_level(seconds: float) -> int:
	for i in Constants.DIFFICULTY_LEVELS.size():
		if seconds >= float(Constants.DIFFICULTY_LEVELS[i][2]):
			return i
	return Constants.DIFFICULTY_LEVELS.size() - 1

## Index in Constants.DIFFICULTY_LEVELS that a median swing gap in seconds swings like.
static func swing_pace_level(gap: float) -> int:
	for i in Constants.DIFFICULTY_LEVELS.size():
		if gap >= float(Constants.DIFFICULTY_LEVELS[i][3]):
			return i
	return Constants.DIFFICULTY_LEVELS.size() - 1

## Reaction time level of one difficulty, at the current Speed modifier.
static func reaction_level_of(info: MapInfo, difficulty: DifficultyInfo) -> int:
	return reaction_level(reaction_seconds(info, difficulty))

## Difficulty of one map difficulty as the song list shows it (an index in Constants.DIFFICULTY_LEVELS): the
## harder of its reaction time level and its swing pace level, at the current Speed modifier, one level up
## when its swings are Tangled. Mappers' own labels and reaction time alone ranked maps that swing fast or
## twist as easy. Without counted stats only reaction time counts.
static func level_of(info: MapInfo, difficulty: DifficultyInfo, stats: Dictionary) -> int:
	var level := reaction_level_of(info, difficulty)
	var gap := float(stats.get("gap", 0.0)) / _speed()
	if gap > 0.0:
		level = maxi(level, swing_pace_level(gap))
	if flow_level(float(stats.get("flow", 0.0))) == Constants.FLOW_LEVELS.size() - 1:
		level += 1
	return mini(level, Constants.DIFFICULTY_LEVELS.size() - 1)

## The saved length filter entry [id, label, min, max] from Constants.LENGTH_FILTERS.
static func length_filter() -> Array:
	return Constants.LENGTH_FILTERS[clampi(Settings.song_filter_length, 0, Constants.LENGTH_FILTERS.size() - 1)]

## True if value is inside a filter entry; max <= 0 means no upper limit.
static func in_filter(value: float, filter: Array) -> bool:
	return value >= float(filter[2]) and (float(filter[3]) <= 0.0 or value < float(filter[3]))

## Formats a difficulty in plain words: "3:24 · Notes 0.72 s ahead · Swings every 0.45 s" (per hand) over
## "Swing flow: Twisty · Map's label: Hard", and "Workout: 3 sets · 28 side steps · 12 squats" when walls make
## the player move.
static func describe(info: MapInfo, difficulty: DifficultyInfo, stats: Dictionary) -> String:
	var seconds := int(stats.get("seconds", 0.0))
	var text := "%d:%02d · Notes %.2f s ahead" % [seconds / 60, seconds % 60, reaction_seconds(info, difficulty)]
	var gap := float(stats.get("gap", 0.0)) / _speed()
	if gap > 0.0:
		text += " · Swings every %.2f s" % gap
	text += "\n"
	if stats.has("flow"):
		text += "Swing flow: %s · " % Constants.FLOW_LEVELS[flow_level(float(stats.flow))][0]
	text += "Map's label: %s" % difficulty.get_display_name()
	var level := workout_level(stats)
	if level > 0:
		text += "\n%s: %d %s" % [Constants.WORKOUT_LEVELS[level], stats.sets, "set" if stats.sets == 1 else "sets"]
		for move: Array in [["side_steps", "side step"], ["squats", "squat"]]:
			var count := int(stats.get(move[0], 0))
			if count > 0:
				text += " · %d %s%s" % [count, move[1], "" if count == 1 else "s"]
	return text

## The difficulty filter choices for a dropdown: [id, label], id 0 being any difficulty.
static func difficulty_filters() -> Array:
	var filters := [[0, Constants.ANY_DIFFICULTY_LABEL]]
	for i in Constants.DIFFICULTY_LEVELS.size():
		filters.append([i + 1, Constants.DIFFICULTY_LEVELS[i][0]])
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
