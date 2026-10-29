extends RefCounted
class_name Map

# this would have basically been impossible to figure out without constantly
# referencing the beat saber modding group wiki.
# https://bsmg.wiki/mapping/map-format.html

static var current_info: MapInfo
static var current_difficulty: DifficultyInfo
# metres a note travels per beat, and how many beats before its beat it appears;
# set from the map's note jump speed before the loader threads start
static var beat_distance := Constants.BEAT_DISTANCE
static var half_jump_beats := 4.0

static var note_stack: Array[ColorNoteInfo]
static var bomb_stack: Array[BombInfo]
static var obstacle_stack: Array[ObstacleInfo]
static var arc_stack: Array[ArcInfo]
static var chain_stack: Array[ChainInfo]
static var event_stack: Array[EventInfo]

static var _color_left: Color
## The danger colour of walls and bombs: the map's wall colour, or Constants.DANGER_COLOR
static var color_obstacle := Constants.DANGER_COLOR
static var _color_right: Color
static var color_left: Color :
	get():
		if Settings.handedness == Constants.HANDEDNESS_FORCE_RIGHT:
			return _color_right
		elif Settings.handedness == Constants.HANDEDNESS_IGNORE:
			return (_color_left+_color_right)/2
		else:
			return _color_left
	set(c):
		_color_left = c
static var color_right: Color :
	get():
		if Settings.handedness == Constants.HANDEDNESS_FORCE_LEFT:
			return _color_left
		elif Settings.handedness == Constants.HANDEDNESS_IGNORE:
			return (_color_left+_color_right)/2
		else:
			return _color_right
	set(c):
		_color_right = c
static var last_beat := 0.
static var one_saber := false
## the characteristics whose lanes turn: 90 and 360 degree maps
const TURNING_CHARACTERISTICS: Array[String] = ["90Degree", "360Degree"]
## Where the track points through the song on 90/360 maps (get_turns): the beats at which the lanes' direction changes
## and the direction (radians, as the objects' lane rotation) from each on. Empty when it never turns.
static var turn_beats := PackedFloat64Array()
static var turn_angles := PackedFloat64Array()
## Where the turn cue points (get_turns, EventDriver): the map's rotation events, which come at or before the first
## object on the turned lane, so the cue can lead the lanes; radians as the lanes'.
static var cue_beats := PackedFloat64Array()
static var cue_angles := PackedFloat64Array()

const ROTATIONS_V2 := [ -60., -45., -30., -15., 15., 30., 45., 60. ]
const ROTATE_ALL := 0. # for testing

# some simple multithreading, since larger maps can take a very long time to
# load.  one particulary notable outlier is the beatmap of shrek, which took
# around 48 milliseconds to load before even on a 7800x3d, and now takes around
# 29 milliseconds.  takes just over half as long as before, very worth the
# nightmare code i've written.
#
# long story short, each beatmap-element loading func splits into two threads:
# one for parsing the top half of the array of dicts, and one for parsing the
# bottom half.  these run concurrently, not quite halfing the time, but
# getting pretty close to halfing it.
static var note_thread_0 := Thread.new()
static var note_thread_1 := Thread.new()
static var bomb_thread_0 := Thread.new()
static var bomb_thread_1 := Thread.new()
static var obstacle_thread_0 := Thread.new()
static var obstacle_thread_1 := Thread.new()
static var arc_thread_0 := Thread.new()
static var arc_thread_1 := Thread.new()
static var chain_thread_0 := Thread.new()
static var chain_thread_1 := Thread.new()
static var event_thread_0 := Thread.new()
static var event_thread_1 := Thread.new()

# not officially part of the spec, but used by mods a lot
static func set_colors_from_custom_data() -> void:
	if Settings.disable_map_color:
		Map.color_left = Settings.color_left
		Map.color_right = Settings.color_right
		Map.color_obstacle = Constants.DANGER_COLOR
		return
	var colors := note_colors(current_info, current_difficulty)
	Map.color_left = colors[0]
	Map.color_right = colors[1]
	var info_data := current_info.custom_data
	var diff_data := current_difficulty.custom_data
	Map.color_obstacle = Constants.DANGER_COLOR
	for data: Dictionary in [info_data, diff_data]:
		for key: String in ["_obstacleColor", "obstacleColor"]:
			if data.get(key) is Dictionary:
				@warning_ignore("unsafe_cast")
				var color := data[key] as Dictionary
				Map.color_obstacle = Color(
					Utils.get_float(color, "r", Constants.DANGER_COLOR.r),
					Utils.get_float(color, "g", Constants.DANGER_COLOR.g),
					Utils.get_float(color, "b", Constants.DANGER_COLOR.b)
				)

## The note colours [left, right] a map difficulty asks for in its custom data (the last one found, in the order
## below), or the player's when it asks for none or Map colors is off.
static func note_colors(info: MapInfo, difficulty: DifficultyInfo) -> Array[Color]:
	var colors: Array[Color] = [Settings.color_left, Settings.color_right]
	if Settings.disable_map_color:
		return colors
	var read_colors := func(data: Dictionary, color_name: String) -> void:
		var left_name := color_name % "Left"
		var right_name := color_name % "Right"
		if (
			data.has(left_name) and data.has(right_name)
			and data[left_name] is Dictionary and data[right_name] is Dictionary
		):
			@warning_ignore("unsafe_cast")
			var left := data[left_name] as Dictionary
			@warning_ignore("unsafe_cast")
			var right := data[right_name] as Dictionary
			colors[0] = Color(
				Utils.get_float(left, "r", Settings.color_left.r),
				Utils.get_float(left, "g", Settings.color_left.g),
				Utils.get_float(left, "b", Settings.color_left.b)
			)
			colors[1] = Color(
				Utils.get_float(right, "r", Settings.color_right.r),
				Utils.get_float(right, "g", Settings.color_right.g),
				Utils.get_float(right, "b", Settings.color_right.b)
			)
	for color_name: String in ["_envColor%sBoost", "envColor%sBoost", "_envColor%s", "envColor%s", "_color%s", "color%s"]:
		read_colors.call(info.custom_data, color_name)
		read_colors.call(difficulty.custom_data, color_name)
	return colors

static func load_map_info(load_path: String) -> MapInfo:
	var info_dict := {}
	var info_dat := Utils.read_binary_file(load_path, "Info.dat")
	if len(info_dat) == 0:
		info_dat = Utils.read_binary_file(load_path, "info.dat")
		if len(info_dat) == 0:
			info_dat = Utils.read_binary_file(load_path, "INFO.DAT")
	info_dict = Utils.binary_to_json(info_dat)
	if (info_dict.is_empty()):
		vr.log_error("Invalid info.dat found in " + load_path)
		return null
	
	if info_dict.has("_version"):
		return MapInfo.new_v2(info_dict, load_path)
	elif info_dict.has("version"):
		return MapInfo.new_v4(info_dict, load_path)
	else:
		vr.log_warning("%s is an unknown beatmap version" % load_path)
		return null

# speed for the speed gods.  please forgive me for this.
# - steve hocktail
static func load_note_stack_v2(note_data: Array, rotations: Array) -> void:
	var load_range := func(start: int, end: int) -> Array[Array]:
		var note_array: Array[ColorNoteInfo] = []
		var bomb_array: Array[BombInfo] = []
		var i := start
		while i < end:
			if not note_data[i] is Dictionary:
				i += 1
				continue
			@warning_ignore("unsafe_cast")
			var note_dict := note_data[i] as Dictionary
			var note_type := int(Utils.get_float(note_dict, "_type", -1.0))
			note_dict["r"] = get_rotation(rotations, Utils.get_float(note_dict, "_time", 0.))
			if note_type == 3 and Settings.bombs_enabled:
				bomb_array.append(BombInfo.new_v2(note_dict))
			elif note_type == 0 or note_type == 1:
				note_array.append(ColorNoteInfo.new_v2(note_dict))
			i += 1
		return [note_array, bomb_array]
	var midpoint := note_data.size() >> 1
	#note_thread_1.start(load_range.bind(0, midpoint))
	Utils.custom_thread_call(note_thread_1, load_range, [0, midpoint])
	var total_second_half : Array[Array] = load_range.bind(midpoint, note_data.size()).call()
	#var total_first_half : Array[Array] = note_thread_1.wait_to_finish()
	var total_first_half : Array[Array] = Utils.custom_thread_wait_to_finish(note_thread_1)
	note_stack = total_first_half[0] + total_second_half[0]
	bomb_stack = total_first_half[1] + total_second_half[1]
	note_stack.reverse()
	bomb_stack.reverse()

static func load_obstacle_stack_v2(obstacle_data: Array, rotations: Array) -> void:
	if not Settings.walls_enabled:
		obstacle_stack.clear()
		return
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var o := obstacle_data[i] as Dictionary
				o["r"] = get_rotation(rotations, Utils.get_float(o, "_time", 0.))
				obstacle_stack[last_index - i] = ObstacleInfo.new_v2(o)
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	#obstacle_thread_1.start(load_range.bind(0, midpoint))
	Utils.custom_thread_call(obstacle_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, obstacle_data.size()).call()
	#obstacle_thread_1.wait_to_finish()
	Utils.custom_thread_wait_to_finish(obstacle_thread_1)

static func load_arc_stack_v2(arc_data: Array, rotations: Array) -> void:
	var last_index := arc_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if arc_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var a := arc_data[i] as Dictionary
				a["hr"] = get_rotation(rotations, Utils.get_float(a, "_time", 0.))
				a["tr"] = a["hr"]
				arc_stack[last_index - i] = ArcInfo.new_v2(a)
			i += 1
	var midpoint := arc_data.size() >> 1
	arc_stack.resize(arc_data.size())
	Utils.custom_thread_call(arc_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, arc_data.size()).call()
	Utils.custom_thread_wait_to_finish(arc_thread_1)
	

static func load_event_stack_v2(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				event_stack[last_index - i] = EventInfo.new_v2(event_data[i] as Dictionary)
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	Utils.custom_thread_call(event_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, event_data.size()).call()
	Utils.custom_thread_wait_to_finish(event_thread_1)
	
static func get_rotation(rotations: Array, beat: float, start := 0, end := -1) -> float:
	if rotations.size() == 0:
		return 0
	if end < 0:
		end = rotations.size() - 1
	if end <= start+1:
		if rotations[end][0] <= beat:
			return rotations[end][1]
		elif rotations[start][0] <= beat:
			return rotations[start][1]
		elif start > 0:
			return rotations[start-1][1]
		else:
			return 0
	var midpoint = (end + start) / 2
	var mt := rotations[midpoint][0] as float
	if mt == beat:
		return rotations[midpoint][1]
	if mt < beat:
		return get_rotation(rotations, beat, midpoint, end)
	else:
		return get_rotation(rotations, beat, start, midpoint)

static func load_note_stack_v3_v4(note_data: Array, meta: Array, rotations: Array) -> void:
	var last_index := note_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if note_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var n := note_data[i] as Dictionary
				var beat := Utils.get_float(n, "b", 0.)
				n["r"] = Utils.get_float(n, "r", 0.) + get_rotation(rotations, beat)
				var index := int(Utils.get_float(n, "i", -1))
				if 0 <= index and index < meta.size() and meta[index] is Dictionary:
					n.merge(meta[index])
				note_stack[last_index - i] = ColorNoteInfo.new_v3(n as Dictionary)
			i += 1
	var midpoint := note_data.size() >> 1
	note_stack.resize(note_data.size())
	Utils.custom_thread_call(note_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, note_data.size()).call()
	Utils.custom_thread_wait_to_finish(note_thread_1)

static func load_bomb_stack_v3_v4(bomb_data: Array, meta: Array, rotations: Array) -> void:
	if not Settings.bombs_enabled:
		bomb_stack.clear()
		return
	var last_index := bomb_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if bomb_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var b := bomb_data[i] as Dictionary
				var beat := Utils.get_float(b, "b", 0.)
				b["r"] = Utils.get_float(b, "r", 0.) + get_rotation(rotations, beat)
				var index := int(Utils.get_float(b, "i", -1))
				if 0 <= index and index < meta.size() and meta[index] is Dictionary:
					b.merge(meta[index])
				bomb_stack[last_index - i] = BombInfo.new_v3(b)
			i += 1
	var midpoint := bomb_data.size() >> 1
	bomb_stack.resize(bomb_data.size())
	Utils.custom_thread_call(bomb_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, bomb_data.size()).call()
	Utils.custom_thread_wait_to_finish(bomb_thread_1)

static func load_obstacle_stack_v3_v4(obstacle_data: Array, meta: Array, rotations: Array) -> void:
	if not Settings.walls_enabled:
		obstacle_stack.clear()
		return
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var o := obstacle_data[i] as Dictionary
				var beat := Utils.get_float(o, "b", 0.)
				o["r"] = Utils.get_float(o, "r", 0.) + get_rotation(rotations, beat)
				var index := int(Utils.get_float(o, "i", -1))
				if 0 <= index and index < meta.size() and meta[index] is Dictionary:
					o.merge(meta[index])
				obstacle_stack[last_index - i] = ObstacleInfo.new_v3(o)
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	Utils.custom_thread_call(obstacle_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, obstacle_data.size()).call()
	Utils.custom_thread_wait_to_finish(obstacle_thread_1)

static func load_arc_stack_v3(arc_data: Array, rotations: Array) -> void:
	var last_index := arc_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if arc_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var a := arc_data[i] as Dictionary
				var beat := Utils.get_float(a, "b", 0.)
				a["hr"] = Utils.get_float(a, "r", 0.) + get_rotation(rotations, beat)
				a["tr"] = a["hr"]
				arc_stack[last_index - i] = ArcInfo.new_v3(arc_data[i] as Dictionary)
			i += 1
	var midpoint := arc_data.size() >> 1
	arc_stack.resize(arc_data.size())
	Utils.custom_thread_call(arc_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, arc_data.size()).call()
	Utils.custom_thread_wait_to_finish(arc_thread_1)

static func load_arc_stack_v4(arc_data: Array, meta: Array, meta_notes: Array) -> void:
	var last_index := arc_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if arc_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var a := arc_data[i] as Dictionary
				var a3 := {}
				if a.has("hb"):
					a3["b"] = a["hb"] # head beat
				if a.has("tb"):
					a3["tb"] = a["tb"] # tail beat
				var index := int(Utils.get_float(a, "ai", -1))
				if 0 <= index and index < meta.size() and meta[index] is Dictionary:
					a3["mu"] = Utils.get_float(meta[index], "m", 1.)
					a3["tmu"] = Utils.get_float(meta[index], "tm", 1.)
					a3["m"] = Utils.get_float(meta[index], "a", 1.)
				index = int(Utils.get_float(a, "hi", -1))
				if 0 <= index and index < meta_notes.size() and meta_notes[index] is Dictionary:
					var m := meta_notes[index] as Dictionary
					a3["x"] = Utils.get_float(m, "x", 0)
					a3["y"] = Utils.get_float(m, "y", 0)
					a3["c"] = Utils.get_float(m, "c", 0)
					a3["d"] = Utils.get_float(m, "d", 0)
					a3["head_angle_offset"]= Utils.get_float(m, "a", 0)
				index = int(Utils.get_float(a, "ti", -1))
				if 0 <= index and index < meta_notes.size() and meta_notes[index] is Dictionary:
					var m := meta_notes[index] as Dictionary
					a3["tx"] = Utils.get_float(m, "x", 0)
					a3["ty"] = Utils.get_float(m, "y", 0)
					a3["tc"] = Utils.get_float(m, "d", 0)
					a3["tail_angle_offset"]= Utils.get_float(m, "a", 0)
				
				if abs(ROTATE_ALL) > Constants.ROTATION_EPS_DEGREES:
					a3["hr"] = ROTATE_ALL
					a3["tr"] = ROTATE_ALL
				arc_stack[last_index - i] = ArcInfo.new_v3(a3)
			i += 1
	var midpoint := arc_data.size() >> 1
	arc_stack.resize(arc_data.size())
	Utils.custom_thread_call(arc_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, arc_data.size()).call()
	Utils.custom_thread_wait_to_finish(arc_thread_1)

static func load_chain_stack_v4(chain_data: Array, meta: Array, meta_notes: Array) -> void:
	var last_index := chain_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if chain_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var c := chain_data[i] as Dictionary
				var c3 := {}
				if c.has("hb"):
					c3["b"] = c["hb"] # head beat
				if c.has("tb"):
					c3["tb"] = c["tb"] # tail beat
				var index := int(Utils.get_float(c, "ci", -1))
				if 0 <= index and index < meta.size() and meta[index] is Dictionary:
					c3["tx"] = Utils.get_float(meta[index], "tx", 0.)
					c3["ty"] = Utils.get_float(meta[index], "ty", 0.)
					c3["sc"] = Utils.get_float(meta[index], "c", 0)
					c3["s"] = Utils.get_float(meta[index], "s", 1.)
				index = int(Utils.get_float(c, "i", -1))
				if 0 <= index and index < meta_notes.size() and meta_notes[index] is Dictionary:
					var m := meta_notes[index] as Dictionary
					c3["x"] = Utils.get_float(m, "x", 0)
					c3["y"] = Utils.get_float(m, "y", 0)
					c3["c"] = Utils.get_float(m, "c", 0)
					c3["d"] = Utils.get_float(m, "d", 0)
				chain_stack[last_index - i] = ChainInfo.new_v3(c3)
			i += 1
	var midpoint := chain_data.size() >> 1
	chain_stack.resize(chain_data.size())
	Utils.custom_thread_call(chain_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, chain_data.size()).call()
	Utils.custom_thread_wait_to_finish(chain_thread_1)

static func load_chain_stack_v3(chain_data: Array, rotations: Array) -> void:
	var last_index := chain_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if chain_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var c := chain_data[i] as Dictionary
				var beat := Utils.get_float(c, "b", 0.)
				# ChainInfo.new_v3 reads the lane rotation from "r" (it once got "hr", so chains never turned)
				c["r"] = Utils.get_float(c, "r", 0.) + get_rotation(rotations, beat)
				chain_stack[last_index - i] = ChainInfo.new_v3(chain_data[i] as Dictionary)
			i += 1
	var midpoint := chain_data.size() >> 1
	chain_stack.resize(chain_data.size())
	Utils.custom_thread_call(chain_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, chain_data.size()).call()
	Utils.custom_thread_wait_to_finish(chain_thread_1)

static func load_event_stack_v3(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				event_stack[last_index - i] = EventInfo.new_v3(event_data[i] as Dictionary)
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	Utils.custom_thread_call(event_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, event_data.size()).call()
	Utils.custom_thread_wait_to_finish(event_thread_1)
	
## Sets how far ahead notes appear and how fast they fly from the map's note jump speed (NJS)
## and offset, as Beat Saber does: a note appears half a jump before its beat. Maps without
## an NJS keep the old fixed 4 m per beat, 4 beats ahead.
static func set_note_jump(info: MapInfo, difficulty: DifficultyInfo) -> void:
	var njs := difficulty.note_jump_movement_speed
	if njs <= 0.0:
		beat_distance = Constants.BEAT_DISTANCE
		half_jump_beats = 4.0
		return
	half_jump_beats = half_jump_beats_for(info.beats_per_minute, njs, difficulty.note_jump_start_beat_offset)
	beat_distance = njs * 60.0 / info.beats_per_minute

## Beats between a note appearing and reaching the player: 4, halved while the half jump would be
## longer than 18 m, plus the map's offset. Maps without an NJS use 4.
static func half_jump_beats_for(bpm: float, njs: float, offset: float) -> float:
	if njs <= 0.0 or bpm <= 0.0:
		return 4.0
	var seconds_per_beat := 60.0 / bpm
	var hjd := 4.0
	while njs * seconds_per_beat * hjd > 17.999:
		hjd /= 2.0
	return maxf(hjd + offset, 0.25)

## Beats that pass per real second: the map's BPM sped up by the Speed modifier.
## The song's playback position stays in song seconds, which use the plain BPM.
static func beats_per_second() -> float:
	return current_info.beats_per_minute * Settings.music_speed / 6000.

## Finds where the track turns, from the loaded notes, bombs and walls (a chain starts on a note): the direction changes at the beat of the
## first object on a lane turned another way (after the map's rotation events, the Mirror and Gradual rotation
## modifiers, whatever the format: v4 has no rotation events, only each object's own). The turn cue follows the map's
## rotation events `rotations` ([beat, degrees], get_rotations_v2/v3), or the track where there are none (v4) or Gradual
## rotation turns every object its own way.
static func get_turns(rotations: Array) -> void:
	var objects := []
	for o in note_stack:
		objects.append([o.beat, o.rotation])
	for o in bomb_stack:
		objects.append([o.beat, o.rotation])
	for o in obstacle_stack:
		objects.append([o.beat, o.rotation])
	objects.sort_custom(compare_times)
	turn_beats.clear()
	turn_angles.clear()
	var angle := 0.0
	for o: Array in objects:
		if absf(angle_difference(angle, o[1])) > Constants.ROTATION_EPS:
			angle = o[1]
			turn_beats.append(o[0])
			turn_angles.append(angle)
	cue_beats = turn_beats
	cue_angles = turn_angles
	if not rotations.is_empty() and absf(Settings.gradual_rotation) <= Constants.ROTATION_EPS:
		cue_beats = PackedFloat64Array()
		cue_angles = PackedFloat64Array()
		for r: Array in rotations:
			cue_beats.append(r[0])
			cue_angles.append(Utils.adjust_lane_rotation(deg_to_rad(r[1])))

## The way the track points at `beat` (radians): the direction of the last turn at or before it, 0 before any.
static func track_rotation(beat: float) -> float:
	var i := turn_beats.bsearch(beat, false)
	return turn_angles[i - 1] if i > 0 else 0.0

## Where the turn cue points at `beat` (radians): the last rotation event at or before it, 0 before any.
static func cue_rotation(beat: float) -> float:
	var i := cue_beats.bsearch(beat, false)
	return cue_angles[i - 1] if i > 0 else 0.0

static func get_last_beat() -> void:
	current_info.last_beat = 0.
	for note_info in note_stack:
		if note_info.beat + 0.5 > current_info.last_beat:
			current_info.last_beat = note_info.beat + 0.5
	for obstacle in obstacle_stack:
		var beat := obstacle.beat + obstacle.duration
		if beat > current_info.last_beat:
			current_info.last_beat = beat
	for bomb in bomb_stack:
		if bomb.beat > current_info.last_beat:
			current_info.last_beat = bomb.beat
	
static func compare_times(a: Array, b: Array):
	return a[0] < b[0]
			
static func get_rotations_v2(events: Array) -> Array:
	if abs(ROTATE_ALL) > Constants.ROTATION_EPS * 180/PI:
		return [[0.,ROTATE_ALL]]
	var r := []
	var angle := 0.
	for e in events:
		if e is Dictionary:
			var t := Utils.get_float(e, "_time", 0.)
			var type := int(Utils.get_float(e, "_type", 0))
			if type != 14 and type != 15:
				continue
			if type == 15:
				t += 1.e-5
			var index := int(Utils.get_float(e, "_value", -1))
			if index < 0 or index > 7:
				continue
			angle += ROTATIONS_V2[index]
			if angle < 0:
				angle += 360
			elif angle >= 360:
				angle -= 360
			r.append([t, angle])
	r.sort_custom(compare_times)
	return r

static func get_rotations_v3(events: Array) -> Array:
	if abs(ROTATE_ALL) > Constants.ROTATION_EPS * 180 / PI:
		return [[0.,ROTATE_ALL]]
	var r := []
	var angle := 0.
	for e in events:
		if e is Dictionary:
			var t := Utils.get_float(e, "b", 0.)
			if Utils.get_float(e, "e", 0.) > 0:
				t += 1.e-5
			angle += Utils.get_float(e, "r", 0.)
			if angle < 0:
				angle += 360
			elif angle >= 360:
				angle -= 360
			r.append([t, angle])
	r.sort_custom(compare_times)
	return r

static func load_beatmap(info: MapInfo, difficulty: DifficultyInfo, map_data: Dictionary) -> bool:
	set_note_jump(info, difficulty)
	
	# Ensures the map_data dict has a version (some maps include the version only on info but not in the data)
	if !map_data.has("_version") and !map_data.has("version"):
		if info.version.begins_with("2.") or info.version.begins_with("1."):
			map_data["_version"] = info.version
		else:
			map_data["version"] = info.version
	
	if map_data.has("_version"):
		var rotations := get_rotations_v2(Utils.get_array(map_data, "_events", []))
		Utils.custom_thread_call(note_thread_0, load_note_stack_v2, [Utils.get_array(map_data, "_notes", []), rotations])
		Utils.custom_thread_call(obstacle_thread_0, load_obstacle_stack_v2, [Utils.get_array(map_data, "_obstacles", []), rotations])
		Utils.custom_thread_call(event_thread_0, load_event_stack_v2, [Utils.get_array(map_data, "_events", [])])
		Utils.custom_thread_call(arc_thread_0, load_arc_stack_v2, [Utils.get_array(map_data, "_sliders", []), rotations])
		chain_stack.clear()
		current_info = info
		current_difficulty = difficulty
		one_saber = difficulty.characteristic == "OneSaber"
		Map.set_colors_from_custom_data()
		Utils.custom_thread_wait_to_finish(note_thread_0)
		Utils.custom_thread_wait_to_finish(obstacle_thread_0)
		Utils.custom_thread_wait_to_finish(event_thread_0)
		Utils.custom_thread_wait_to_finish(arc_thread_0)
		get_last_beat()
		get_turns(rotations)
		return true
	elif map_data.has("version"):
		var version := Utils.get_str(map_data, "version", "")
		if version.begins_with("3.") or version.begins_with("4."):
			var v4 := version.begins_with("4.")
			var rotations : Array
			if v4:
				rotations = [] if abs(ROTATE_ALL) <= Constants.ROTATION_EPS_DEGREES else [[0.,ROTATE_ALL]]
			else:
				rotations = get_rotations_v3(Utils.get_array(map_data, "rotationEvents", []))
			Utils.custom_thread_call(note_thread_0, load_note_stack_v3_v4, 
				[Utils.get_array(map_data, "colorNotes", []),
				 Utils.get_array(map_data, "colorNotesData", []) if v4 else [],
				 rotations
				])
			Utils.custom_thread_call(bomb_thread_0, load_bomb_stack_v3_v4, 
				[Utils.get_array(map_data, "bombNotes", []),
				 Utils.get_array(map_data, "bombNotesData", []) if v4 else [],
				 rotations
				])
			Utils.custom_thread_call(obstacle_thread_0, load_obstacle_stack_v3_v4, 
				[Utils.get_array(map_data, "obstacles", []),
				 Utils.get_array(map_data, "obstaclesData", []) if v4 else [],
				 rotations
				])
			if v4:
				Utils.custom_thread_call(arc_thread_0, load_arc_stack_v4, 
					[Utils.get_array(map_data, "arcs", []),
					Utils.get_array(map_data, "arcsData", []),
					Utils.get_array(map_data, "colorNotesData", [])
					])
			else:
				Utils.custom_thread_call(arc_thread_0, load_arc_stack_v3, 
					[Utils.get_array(map_data, "sliders", []), rotations])
			if v4:
				Utils.custom_thread_call(chain_thread_0, load_chain_stack_v4, 
					[Utils.get_array(map_data, "chains", []),
					Utils.get_array(map_data, "chainsData", []),
					Utils.get_array(map_data, "colorNotesData", [])
					])
			else:
				Utils.custom_thread_call(chain_thread_0, load_chain_stack_v3, 
					[Utils.get_array(map_data, "burstSliders", []),
					rotations
					])
			if v4:
				# v4 keeps its lights in a separate lightshow file, which isn't read yet: no events rather than the
				# last map's
				event_stack.clear()
			else:
				Utils.custom_thread_call(event_thread_0, load_event_stack_v3, [Utils.get_array(map_data, "basicBeatmapEvents", [])])
			current_info = info
			current_difficulty = difficulty
			one_saber = difficulty.characteristic == "OneSaber"
			Map.set_colors_from_custom_data()
			Utils.custom_thread_wait_to_finish(note_thread_0)
			Utils.custom_thread_wait_to_finish(bomb_thread_0)
			Utils.custom_thread_wait_to_finish(obstacle_thread_0)
			Utils.custom_thread_wait_to_finish(arc_thread_0)
			Utils.custom_thread_wait_to_finish(chain_thread_0)
			Utils.custom_thread_wait_to_finish(event_thread_0)
			get_last_beat()
			get_turns(rotations)
			return true
	vr.log_warning("selected map is an unsupported version")
	return false
