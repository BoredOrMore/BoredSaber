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
	var none: Array[EventInfo] = []
	check(EventDriver.intensity_curve(none, 120.0).is_empty(), "an empty map has no curve")

	# a song whose lights never change still gives finite values in range
	var flat := EventDriver.intensity_curve(lights(0.0, 64.0, 1.0), 120.0)
	var finite := true
	for v in flat:
		finite = finite and is_finite(v) and v >= 0.0 and v <= 1.0
	check(finite, "a flat light show gives finite values in range")

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
