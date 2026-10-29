extends Node
# Headless checks for beatmap parsing (Map.load_beatmap) in the v2, v3 and v4 formats, note jump maths and
# the Mirror Left-Right setting.
# Run: godot --headless --path . res://tests/test_beatmap.tscn
#
# Fixtures (tests/data/beatmap/v*.dat) hold the same tiny map in each format:
#   notes  beat 1 left  x1 y0 down | beat 2 right x2 y0 right | beat 3 left x0 y1 dot | beat 4 right x3 y2 up-left
#   bomb   beat 2.5 x1 y2          wall beat 5 x0 y0 w1 h5 duration 2
#   arc    left, beat 1 x1 y0 down -> beat 3 x0 y1 up
#   chain  right, beat 2 x2 y0 right -> beat 2.5 x2 y1, 4 slices, squish 0.5 (v3/v4 only)
#   events beat 1 type 1 value 3 | beat 2 type 4 value 1 (v2/v3; v4 lights live in a separate lightshow file)

const DATA := "res://tests/data/beatmap/"
const NOTES := [ # beat, x, y, colour, direction
	[1.0, 1, 0, 0, 1],
	[2.0, 2, 0, 1, 3],
	[3.0, 0, 1, 0, 8],
	[4.0, 3, 2, 1, 4],
]
# the direction a cut direction becomes when mirrored left-right
const MIRROR_DIRECTION := [0, 1, 3, 2, 5, 4, 7, 6, 8]

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## the cut angle (radians, 0..TAU) Beat Saber's direction d points the saber to; the dot is pushed past TAU*2
func direction_angle(d: int) -> float:
	if d == 8:
		return Constants.DIRECTION8_OFFSET
	return fposmod(Constants.CUBE_ROTATIONS[d], TAU)

func angle_is(angle: float, d: int) -> bool:
	if d == 8:
		return angle >= Constants.DIRECTION8_COMPARE
	return angle < Constants.DIRECTION8_COMPARE and absf(angle_difference(angle, direction_angle(d))) < 1e-4

func read_map(file: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + file))
	return data if data is Dictionary else {}

func make_info(version: String, bpm: float) -> MapInfo:
	var diffs: Array[DifficultyInfo] = []
	return MapInfo.new(version, "Test", "", "Tester", "Mapper", bpm, 0.0, 0.0, "song.ogg", "", "", 0.0, {}, DATA, diffs)

func make_difficulty(njs: float, offset: float) -> DifficultyInfo:
	return DifficultyInfo.new("Expert", 7, "Expert.dat", njs, offset, {}, "Expert", "Standard")

## loads the fixture and checks every stack against the map above, mirrored left-right when mirror is set
func check_map(tag: String, file: String, version: String, has_chain: bool, has_events: bool, mirror: bool) -> void:
	tag = tag + (" mirrored" if mirror else "")
	var info := make_info(version, 120.0)
	var ok := Map.load_beatmap(info, make_difficulty(16.0, 0.0), read_map(file))
	check(ok, "%s: load_beatmap returns true" % tag)
	var mx := func(x: float) -> float: return 3.0 - x if mirror else x
	var mc := func(c: int) -> int: return 1 - c if mirror else c
	var md := func(d: int) -> int: return MIRROR_DIRECTION[d] if mirror else d

	# notes: the stack is popped from the back, so the earliest note is last
	check(Map.note_stack.size() == NOTES.size(), "%s: %d notes (got %d)" % [tag, NOTES.size(), Map.note_stack.size()])
	if Map.note_stack.size() == NOTES.size():
		for i in NOTES.size():
			var want: Array = NOTES[i]
			var n: ColorNoteInfo = Map.note_stack[Map.note_stack.size() - 1 - i]
			var what := "%s: note %d is popped %d%s" % [tag, i, i + 1, ["st", "nd", "rd", "th"][mini(i, 3)]]
			check(is_equal_approx(n.beat, want[0]), "%s, beat %s (got %s)" % [what, want[0], n.beat])
			check(is_equal_approx(n.line_index, mx.call(want[1])) and is_equal_approx(n.line_layer, want[2]),
				"%s, lane %s layer %s (got %s, %s)" % [what, mx.call(want[1]), want[2], n.line_index, n.line_layer])
			check(n.color == mc.call(want[3]), "%s, colour %d (got %d)" % [what, mc.call(want[3]), n.color])
			check(angle_is(n.cut_angle, md.call(want[4])),
				"%s, direction %d (got angle %s)" % [what, md.call(want[4]), n.cut_angle])

	check(Map.bomb_stack.size() == 1, "%s: 1 bomb (got %d)" % [tag, Map.bomb_stack.size()])
	if Map.bomb_stack.size() == 1:
		var b := Map.bomb_stack[0]
		check(is_equal_approx(b.beat, 2.5) and is_equal_approx(b.line_index, mx.call(1)) and is_equal_approx(b.line_layer, 2),
			"%s: bomb at beat 2.5 lane %s layer 2 (got %s, %s, %s)" % [tag, mx.call(1), b.beat, b.line_index, b.line_layer])

	check(Map.obstacle_stack.size() == 1, "%s: 1 wall (got %d)" % [tag, Map.obstacle_stack.size()])
	if Map.obstacle_stack.size() == 1:
		var o := Map.obstacle_stack[0]
		# a mirrored wall keeps its width, so its left lane is 4 - x - width
		var want_x := 3.0 if mirror else 0.0
		check(is_equal_approx(o.beat, 5) and is_equal_approx(o.duration, 2) and is_equal_approx(o.line_index, want_x)
			and is_equal_approx(o.line_layer, 0) and is_equal_approx(o.width, 1) and is_equal_approx(o.height, 5),
			"%s: wall beat 5 duration 2 lane %s layer 0 width 1 height 5 (got %s %s %s %s %s %s)"
			% [tag, want_x, o.beat, o.duration, o.line_index, o.line_layer, o.width, o.height])

	check(Map.arc_stack.size() == 1, "%s: 1 arc (got %d)" % [tag, Map.arc_stack.size()])
	if Map.arc_stack.size() == 1:
		var a := Map.arc_stack[0]
		check(a.color == mc.call(0), "%s: arc colour %d (got %d)" % [tag, mc.call(0), a.color])
		check(is_equal_approx(a.head_beat, 1) and is_equal_approx(a.head_line_index, mx.call(1)) and is_equal_approx(a.head_line_layer, 0)
			and angle_is(a.head_cut_angle, md.call(1)),
			"%s: arc head beat 1 lane %s layer 0 down (got %s %s %s %s)" % [tag, mx.call(1), a.head_beat, a.head_line_index, a.head_line_layer, a.head_cut_angle])
		check(is_equal_approx(a.tail_beat, 3) and is_equal_approx(a.tail_line_index, mx.call(0)) and is_equal_approx(a.tail_line_layer, 1)
			and angle_is(a.tail_cut_angle, md.call(0)),
			"%s: arc tail beat 3 lane %s layer 1 up (got %s %s %s %s)" % [tag, mx.call(0), a.tail_beat, a.tail_line_index, a.tail_line_layer, a.tail_cut_angle])

	var want_chains := 1 if has_chain else 0
	check(Map.chain_stack.size() == want_chains, "%s: %d chain(s) (got %d)" % [tag, want_chains, Map.chain_stack.size()])
	if has_chain and Map.chain_stack.size() == 1:
		var c := Map.chain_stack[0]
		check(c.color == mc.call(1), "%s: chain colour %d (got %d)" % [tag, mc.call(1), c.color])
		check(is_equal_approx(c.head_beat, 2) and is_equal_approx(c.head_line_index, mx.call(2)) and is_equal_approx(c.head_line_layer, 0)
			and angle_is(c.head_cut_angle, md.call(3)),
			"%s: chain head beat 2 lane %s layer 0 direction %d (got %s %s %s %s)" % [tag, mx.call(2), md.call(3), c.head_beat, c.head_line_index, c.head_line_layer, c.head_cut_angle])
		check(is_equal_approx(c.tail_beat, 2.5) and is_equal_approx(c.tail_line_index, mx.call(2)) and is_equal_approx(c.tail_line_layer, 1)
			and c.slice_count == 4 and is_equal_approx(c.squish_factor, 0.5),
			"%s: chain tail beat 2.5 lane %s layer 1, 4 slices, squish 0.5 (got %s %s %s %d %s)" % [tag, mx.call(2), c.tail_beat, c.tail_line_index, c.tail_line_layer, c.slice_count, c.squish_factor])

	if has_events:
		check(Map.event_stack.size() == 2, "%s: 2 light events (got %d)" % [tag, Map.event_stack.size()])
		if Map.event_stack.size() == 2:
			var first := Map.event_stack[1]
			var second := Map.event_stack[0]
			check(is_equal_approx(first.beat, 1) and first.type == 1 and first.value == 3,
				"%s: first event popped is beat 1 type 1 value 3 (got %s %d %d)" % [tag, first.beat, first.type, first.value])
			check(is_equal_approx(second.beat, 2) and second.type == 4 and second.value == 1,
				"%s: second event popped is beat 2 type 4 value 1 (got %s %d %d)" % [tag, second.beat, second.type, second.value])

	# last beat: the wall ends at 5 + 2, after the last note (4 + 0.5)
	check(is_equal_approx(info.last_beat, 7.0), "%s: last beat is the wall's end, 7 (got %s)" % [tag, info.last_beat])

func _ready() -> void:
	var saved := {}
	for key: String in ["flip", "gradual_rotation", "bombs_enabled", "walls_enabled", "handedness", "disable_map_color"]:
		saved[key] = Settings.get(key)
	Settings.flip = 0
	Settings.gradual_rotation = 0.0
	Settings.bombs_enabled = true
	Settings.walls_enabled = true

	# note jump: 4 beats, halved while the half jump is over 18 m, plus the offset, never under 0.25
	check(is_equal_approx(Map.half_jump_beats_for(120, 8, 0), 4.0), "half jump: 120 BPM NJS 8 is 4 beats (16 m)")
	check(is_equal_approx(Map.half_jump_beats_for(120, 10, 0), 2.0), "half jump: 120 BPM NJS 10 halves to 2 beats (20 m > 18 m)")
	check(is_equal_approx(Map.half_jump_beats_for(60, 20, 0), 0.5), "half jump: 60 BPM NJS 20 halves three times to 0.5")
	check(is_equal_approx(Map.half_jump_beats_for(120, 8, -1), 3.0), "half jump: offset -1 is added")
	check(is_equal_approx(Map.half_jump_beats_for(120, 8, -10), 0.25), "half jump: never below 0.25 beats")
	check(is_equal_approx(Map.half_jump_beats_for(120, 0, 1), 4.0), "half jump: no NJS falls back to 4 beats")
	check(is_equal_approx(Map.half_jump_beats_for(0, 16, 1), 4.0), "half jump: no BPM falls back to 4 beats")

	Map.set_note_jump(make_info("3.3.0", 120), make_difficulty(16, 0.5))
	check(is_equal_approx(Map.beat_distance, 8.0), "set_note_jump: NJS 16 at 120 BPM is 8 m per beat (got %s)" % Map.beat_distance)
	check(is_equal_approx(Map.half_jump_beats, 2.5), "set_note_jump: half jump 2 beats (32 m halved to 16 m) + offset 0.5 (got %s)" % Map.half_jump_beats)
	Map.set_note_jump(make_info("3.3.0", 120), make_difficulty(0, 0.5))
	check(is_equal_approx(Map.beat_distance, Constants.BEAT_DISTANCE) and is_equal_approx(Map.half_jump_beats, 4.0),
		"set_note_jump: no NJS keeps %s m per beat, 4 beats ahead (got %s, %s)" % [Constants.BEAT_DISTANCE, Map.beat_distance, Map.half_jump_beats])

	for mirror in [false, true]:
		Settings.flip = Constants.FLIP_HORIZONTAL if mirror else 0
		check_map("v2", "v2.dat", "2.6.0", false, true, mirror)
		check_map("v3", "v3.dat", "3.3.0", true, true, mirror)
		# v4 lights live in a lightshow file that isn't read yet: a v4 map must not keep the previous map's lights
		check_map("v4", "v4.dat", "4.0.0", true, false, mirror)
		check(Map.event_stack.is_empty(), "v4%s: no light events left over from the previous (v3) map (got %d)"
			% [" mirrored" if mirror else "", Map.event_stack.size()])
	Settings.flip = 0

	# an entry that isn't an object is skipped (load_note_stack_v2 once looped on it forever)
	Map.load_beatmap(make_info("2.6.0", 120), make_difficulty(16, 0.0), read_map("v2.dat"))
	var clean_notes := Map.note_stack.size()
	var stray := read_map("v2.dat")
	(stray["_notes"] as Array).insert(0, 1)
	Map.load_beatmap(make_info("2.6.0", 120), make_difficulty(16, 0.0), stray)
	check(Map.note_stack.size() == clean_notes, "v2: a stray non-object note entry is skipped (%d notes, %d without it)"
		% [Map.note_stack.size(), clean_notes])

	# load_beatmap sets the note jump from the map it loads
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), read_map("v3.dat"))
	check(is_equal_approx(Map.beat_distance, 8.0) and is_equal_approx(Map.half_jump_beats, 2.0),
		"load_beatmap applies the map's NJS (got %s m per beat, %s beats)" % [Map.beat_distance, Map.half_jump_beats])

	# Gradual rotation turns everything by the same angle per beat.
	# (bombs once turned twice as far: BombInfo added it twice)
	Settings.gradual_rotation = 0.01
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), read_map("v3.dat"))
	if Map.bomb_stack.size() == 1:
		check(is_equal_approx(Map.bomb_stack[0].rotation, 0.025),
			"gradual rotation: bomb at beat 2.5 turns 0.025 rad like a note (got %s)" % Map.bomb_stack[0].rotation)
	if Map.note_stack.size() > 0:
		check(is_equal_approx(Map.note_stack[-1].rotation, 0.01), "gradual rotation: note at beat 1 turns 0.01 rad (got %s)" % Map.note_stack[-1].rotation)

	# v2 rotation events (numbers as JSON gives them, floats) add up in degrees, kept in 0..360 (they once wrapped at TAU, so 15 + 15 read as 23.7)
	var turns := Map.get_rotations_v2([{"_time": 1.0, "_type": 14.0, "_value": 4.0}, {"_time": 2.0, "_type": 14.0, "_value": 4.0},
		{"_time": 3.0, "_type": 15.0, "_value": 7.0}, {"_time": 4.0, "_type": 14.0, "_value": 7.0}, {"_time": 5.0, "_type": 14.0,
		"_value": 7.0}, {"_time": 6.0, "_type": 14.0, "_value": 7.0}, {"_time": 7.0, "_type": 14.0, "_value": 0.0}])
	var angles := turns.map(func(t: Array) -> float: return t[1])
	check(angles == [15.0, 30.0, 90.0, 150.0, 210.0, 270.0, 210.0], "v2 rotations add up in degrees (got %s)" % [angles])
	check(is_equal_approx(Map.get_rotation(turns, 3.0), 30.0) and is_equal_approx(Map.get_rotation(turns, 3.5), 90.0),
		"a late rotation event (15) turns just after its beat (%s at 3, %s at 3.5)" % [Map.get_rotation(turns, 3.0),
		Map.get_rotation(turns, 3.5)])
	var back := Map.get_rotations_v2([{"_time": 1.0, "_type": 14.0, "_value": 0.0}])
	check(is_equal_approx(back[0][1], 300.0), "a v2 turn left from 0 is 300 degrees (got %s)" % back[0][1])

	# the track turns at the first object on a turned lane, and points that way until the next turn (Map.get_turns)
	Settings.gradual_rotation = 0.0
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), read_map("v3.dat"))
	check(Map.turn_beats.is_empty() and Map.track_rotation(3.0) == 0.0,
		"a map without rotation never turns the track (turns at %s)" % Map.turn_beats)
	var turning := read_map("v3.dat")
	turning["rotationEvents"] = [{"b": 2.0, "e": 0.0, "r": 90.0}, {"b": 4.0, "e": 0.0, "r": -90.0}]
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), turning)
	check(Map.turn_beats == PackedFloat64Array([2.0, 4.0]), "the track turns at beats 2 and 4 (got %s)" % Map.turn_beats)
	check(Map.track_rotation(1.9) == 0.0 and is_equal_approx(Map.track_rotation(2.0), PI * 0.5)
		and is_equal_approx(Map.track_rotation(3.9), PI * 0.5) and is_equal_approx(Map.track_rotation(4.0), 0.0),
		"it points ahead, then 90 degrees from beat 2, then ahead again from beat 4 (%s, %s, %s, %s)" % [
		Map.track_rotation(1.9), Map.track_rotation(2.0), Map.track_rotation(3.9), Map.track_rotation(4.0)])
	check(Map.chain_stack.size() == 1 and is_equal_approx(Map.chain_stack[0].rotation, PI * 0.5),
		"a v3 chain at beat 2 is on the turned lane (%s)" % [Map.chain_stack.map(func(c: ChainInfo) -> float: return c.rotation)])
	# the turn cue goes by the rotation events, so it leads the lanes when an event comes before its first note
	var early := read_map("v3.dat")
	early["rotationEvents"] = [{"b": 1.5, "e": 0.0, "r": 90.0}]
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), early)
	check(is_equal_approx(Map.cue_rotation(1.6), PI * 0.5) and Map.track_rotation(1.6) == 0.0
		and is_equal_approx(Map.track_rotation(2.0), PI * 0.5),
		"a rotation event at beat 1.5 turns the cue at 1.5 and the track at the next note, 2 (cue %s, track %s at 1.6)" % [
		Map.cue_rotation(1.6), Map.track_rotation(1.6)])
	Map.load_beatmap(make_info("3.3.0", 120), make_difficulty(16, 0.0), turning)

	for key: String in saved:
		Settings.set(key, saved[key])
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
