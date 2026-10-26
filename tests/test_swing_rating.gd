extends Node
# Headless checks for the swing angles as Beat Saber measures them (LightSaber.swept).
# Run: godot --headless --path . res://tests/test_swing_rating.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## pointings from the cut going away from it, turning about axis by step degrees each, for count steps
func arc(start: Vector3, axis: Vector3, step: float, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = [start]
	for i in count:
		out.append(out[-1].rotated(axis, deg_to_rad(step)))
	return out

func _ready() -> void:
	var down_cut := Vector3.UP.cross(Vector3.FORWARD).normalized()
	# a 120 degree approach in one plane, sampled 5 degrees a frame, going back from the cut (so turning the other way)
	var approach := arc(Vector3.FORWARD, down_cut, -5.0, 24)
	var reference := approach[1].cross(approach[0]).normalized()
	var swept := LightSaber.swept(approach, reference, true)
	check(absf(swept - 120.0) < 0.5, "a steady 120° approach counts in full (got %.1f)" % swept)

	# the saber came in from the side: the first 60° (nearest the cut) in plane, then the plane turns 100° away
	var bent := arc(Vector3.FORWARD, down_cut, -5.0, 12)
	var side := bent[-1].cross(down_cut).normalized()
	bent.append_array(arc(bent[-1], side, -5.0, 12).slice(1))
	var cut_off := LightSaber.swept(bent, reference, true)
	check(cut_off < 70.0, "steps whose plane turned past 90° end the count (got %.1f)" % cut_off)

	# a follow-through that swings back the way it came stops at the turn
	var follow := arc(Vector3.FORWARD, down_cut, 5.0, 8)
	follow.append_array(arc(follow[-1], down_cut, -5.0, 8).slice(1))
	var follow_through := LightSaber.swept(follow, reference, false)
	check(absf(follow_through - 40.0) < 0.5, "a follow-through stops where the saber turns back (got %.1f)" % follow_through)

	check(LightSaber.swept(approach, Vector3.ZERO, true) == 0.0, "no swing (no plane) counts nothing")

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
