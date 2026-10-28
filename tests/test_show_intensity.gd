extends Node
# Headless checks for the show's intensity curve (EventDriver.intensity_curve), which builds the stage as the song builds.
# Run: godot --headless --path . res://tests/test_show_intensity.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## light events of type 0 every `step` beats from `from` to `to`
func lights(from: float, to: float, step: float) -> Array[EventInfo]:
	var out: Array[EventInfo] = []
	var beat := from
	while beat < to:
		out.append(EventInfo.new(beat, EventInfo.TYPE_DIAGONAL_LASERS, 1, 1.0))
		beat += step
	return out

func _ready() -> void:
	# 120 BPM: a calm part (one event a beat) for 64 beats, then a dense part (eight a beat) for 32
	var song := lights(0.0, 64.0, 1.0)
	song.append_array(lights(64.0, 96.0, 0.125))
	var curve := EventDriver.intensity_curve(song, 120.0)
	check(curve.size() > 0, "a map with light events has a curve")
	var calm := curve[int(40.0 / EventDriver.INTENSITY_STEP)]
	var dense := curve[int(94.0 / EventDriver.INTENSITY_STEP)]
	check(calm < 0.2, "the calm part is low (got %.2f)" % calm)
	check(dense > 0.9, "the dense part is high (got %.2f)" % dense)
	var in_range := true
	for v in curve:
		in_range = in_range and v >= 0.0 and v <= 1.0
	check(in_range, "every value is between 0 and 1")

	# events that are not lights (ring spins, type 8) don't count
	var rings_only: Array[EventInfo] = [EventInfo.new(4.0, 8, 0, 1.0), EventInfo.new(8.0, 8, 0, 1.0)]
	check(EventDriver.intensity_curve(rings_only, 120.0).is_empty(), "a map without light events has no curve")

	# the build-up sweep: nothing far from the drop (where the curve first passes STRIP_DROP), rising as it nears
	var drop := 0.0
	for i in curve.size():
		if curve[i] > EventDriver.STRIP_DROP:
			drop = i * EventDriver.INTENSITY_STEP
			break
	var window := EventDriver.BUILD_UP_SECONDS * 2.0
	check(EventDriver.build_up(curve, drop - window * 1.5, 120.0) == 0.0, "no build-up far from the drop")
	var nearing := EventDriver.build_up(curve, drop - window * 0.9, 120.0)
	var arriving := EventDriver.build_up(curve, drop - window * 0.1, 120.0)
	check(nearing > 0.0 and arriving > nearing, "the build-up rises toward the drop (%.2f then %.2f)" % [nearing, arriving])
	var none: Array[EventInfo] = []
	check(EventDriver.intensity_curve(none, 120.0).is_empty(), "an empty map has no curve")

	# a song whose lights never change still gives finite values in range
	var flat := EventDriver.intensity_curve(lights(0.0, 64.0, 1.0), 120.0)
	var finite := true
	for v in flat:
		finite = finite and is_finite(v) and v >= 0.0 and v <= 1.0
	check(finite, "a flat light show gives finite values in range")

	# Metal Factory's hammers (MetalFactoryRig.hammer_drop): on the anvil at the beat, raised mid-cycle, falling
	# faster near the end
	var cycle := 0.5
	check(MetalFactoryRig.hammer_drop(0.0, cycle) == 1.0, "a hammer is on the anvil on the beat")
	check(MetalFactoryRig.hammer_drop(cycle - 0.0001, cycle) > 0.99, "a hammer lands just as the next beat comes")
	var top := MetalFactoryRig.hammer_drop(cycle - MetalFactoryRig.SLAM_FALL_SECONDS, cycle)
	check(top < 0.01, "a hammer is raised before it falls (got %.2f)" % top)
	var fall := MetalFactoryRig.SLAM_FALL_SECONDS
	var early := MetalFactoryRig.hammer_drop(cycle - fall * 0.75, cycle) - MetalFactoryRig.hammer_drop(cycle - fall, cycle)
	var late := MetalFactoryRig.hammer_drop(cycle - 0.0001, cycle) -MetalFactoryRig.hammer_drop(cycle - fall * 0.25, cycle)
	check(late > early, "a hammer speeds up as it falls")
	var in_sync := true
	for lag in MetalFactoryRig.SLAM_LAG_SECONDS:
		in_sync = in_sync and lag >= 0.0 and lag <= 0.08
	check(in_sync, "every hammer lands after the beat and within 80 ms of it")
	# the walls' breath stays between 1.4 and 3 s (far from 0.2 Hz) at any tempo
	var steady := true
	for bpm in [40.0, 60.0, 90.0, 120.0, 174.0, 240.0, 400.0]:
		var seconds: float = MetalFactoryRig.breath_beats(bpm) * 60.0 / bpm
		steady = steady and seconds >= MetalFactoryRig.BREATH_SECONDS.x and seconds <= MetalFactoryRig.BREATH_SECONDS.y
	check(steady, "the walls breathe once every 1.4 to 3 s at any tempo")

	# on Auto, metal, dubstep and drum-and-bass songs (BeatSaver's tag spellings) play in the Metal Factory, which the
	# environment menu lists too
	var heavy := true
	for tag in ["metal", "dubstep", "drum-and-bass"]:
		heavy = heavy and Constants.TAG_ENVIRONMENTS.get(tag) == "metal_factory"
	check(heavy, "metal, dubstep and drum-and-bass pick the Metal Factory")
	check(Settings.ENVIRONMENTS.any(func(e: Array) -> bool: return e[0] == "metal_factory"), "the menu offers the Metal Factory")

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
