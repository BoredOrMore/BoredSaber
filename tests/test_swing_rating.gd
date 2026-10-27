extends Node
# Headless checks for scoring as Beat Saber does it: swing angles (LightSaber.swept) and modifier shares.
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

	# modifier shares (Constants.score_share): Beat Saber's points, our speeds and sizes on lines through them
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 1e-4
	check(near.call(Constants.score_share(Constants.SPEED_SCORE, 85), -0.30), "Speed 85% is Beat Saber's Slower Song, -30%")
	check(near.call(Constants.score_share(Constants.SPEED_SCORE, 100), 0.0), "Speed 100% changes nothing")
	check(near.call(Constants.score_share(Constants.SPEED_SCORE, 125), 0.08 + 0.02 * 5.0 / 30.0), "Speed 125% is between Faster (+8%) and Super Fast (+10%)")
	check(near.call(Constants.score_share(Constants.SPEED_SCORE, 150), 0.10), "Speed 150% is Super Fast, +10%")
	check(near.call(Constants.score_share(Constants.SPEED_SCORE, 175), 0.10 + 0.02 * 25.0 / 30.0), "Speed 175% carries the line on (+11.7%)")
	check(near.call(Constants.score_share(Constants.BLOCK_SIZE_SCORE, 50), 0.0), "Small blocks change nothing (Beat Saber's Small Notes)")
	check(near.call(Constants.score_share(Constants.BLOCK_SIZE_SCORE, 225), -0.10), "Giant blocks -10%")
	check(near.call(Constants.score_share(Constants.WIDTH_SCORE, 150), -0.05), "150% width -5%")

	# block size goes into the highscore key, so each size keeps its own table
	var size_before: int = Settings.block_size
	for size: Array in Constants.SIZES:
		Settings.block_size = size[0]
		var key := HighscoreTable.get_rank_key(1)
		var expected: int = {50: Constants.DIFFICULTY_BLOCK_SIZE_SMALL, 150: Constants.DIFFICULTY_BLOCK_SIZE_BIG,
			225: Constants.DIFFICULTY_BLOCK_SIZE_GIANT}.get(size[0], 0)
		check(key & Constants.DIFFICULTY_BLOCK_SIZE_MASK == expected, "%s are kept in their own highscore table" % size[1])
	Settings.block_size = size_before

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
