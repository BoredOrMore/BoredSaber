extends Node
# Headless checks for cut judgement (BeepCube.right_saber, angle_accuracy, centre_accuracy, beat_accuracy_at) and the
# chain's curve (ChainLink.curve_points, link_place).
# Run: godot --headless --path . res://tests/test_cut.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func _ready() -> void:
	var saved := {&"handedness": Settings.handedness, &"flip": Settings.flip}
	Settings.handedness = 0
	Settings.flip = 0
	var one_saber := Map.one_saber
	Map.one_saber = false

	# which saber may cut
	check(BeepCube.right_saber(0, 0) and BeepCube.right_saber(1, 1), "a saber cuts notes of its own colour")
	check(not BeepCube.right_saber(0, 1), "the other colour's saber is a bad cut")
	Map.one_saber = true
	check(BeepCube.right_saber(0, 1), "One Saber maps take any note with the one saber")
	Map.one_saber = false
	Settings.handedness = Constants.HANDEDNESS_IGNORE
	check(BeepCube.right_saber(0, 1), "Any Saber, Any Color takes any note")
	Settings.handedness = 0

	# the angle: a down arrow (its up points against a downward cut)
	var up := Vector3.UP
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 1e-4
	check(near.call(BeepCube.angle_accuracy(up, Vector3(0, -2, 0), false), 1.0), "a cut straight along the arrow counts in full")
	check(near.call(BeepCube.angle_accuracy(up, Vector3(0, 2, 0), false), 0.0), "a cut against the arrow is a bad angle")
	check(near.call(BeepCube.angle_accuracy(up, Vector3(2, 0, 0), false), 0.0), "a sideways cut (90 degrees off) is a bad angle")
	var off45 := BeepCube.angle_accuracy(up, Vector3(1, -1, 0), false)
	check(near.call(off45, (sqrt(0.5) - BeepCube.GOOD_CUT_DOT) / (1.0 - BeepCube.GOOD_CUT_DOT)),
			"45 degrees off counts in part (got %.3f)" % off45)
	var edge := deg_to_rad(rad_to_deg(acos(BeepCube.GOOD_CUT_DOT)) + 1.0)
	check(near.call(BeepCube.angle_accuracy(up, Vector3(sin(edge), -cos(edge), 0), false), 0.0),
			"just past the allowed cone (%.0f degrees) counts nothing" % rad_to_deg(edge))
	check(BeepCube.angle_accuracy(up, Vector3(2, 0, 0), true) == 1.0, "dots and No Arrows take any direction")
	check(near.call(BeepCube.angle_accuracy(up, Vector3(0, -2, 5), false), 1.0), "speed toward the player doesn't count against the angle")

	# the centre, Beat Saber's 1 - d / 0.3 m
	check(BeepCube.centre_accuracy(0.0, 100) == 1.0, "a cut through the middle gets the full centre points")
	check(near.call(BeepCube.centre_accuracy(0.15, 100), 0.5) and near.call(BeepCube.centre_accuracy(-0.15, 100), 0.5),
			"halfway to the reach gets half, on either side")
	check(BeepCube.centre_accuracy(0.3, 100) == 0.0 and BeepCube.centre_accuracy(0.5, 100) == 0.0, "at the reach or past it gets none")
	check(near.call(BeepCube.centre_accuracy(0.3, 200), 0.5), "bigger blocks scale the distance (0.3 m on a 200% block is half)")

	# the beat (OpenSaber scoring): full within half a metre of the hit plane
	check(BeepCube.beat_accuracy_at(Constants.HIT_PLANE_Z) == 1.0, "a cut on the hit plane is on the beat")
	check(BeepCube.beat_accuracy_at(Constants.HIT_PLANE_Z + 0.5) == 1.0, "half a metre off still counts in full")
	check(near.call(BeepCube.beat_accuracy_at(Constants.HIT_PLANE_Z - 0.75), 0.5), "three quarters of a metre off counts half")
	check(BeepCube.beat_accuracy_at(Constants.HIT_PLANE_Z + 1.0) == 0.0, "a metre off counts nothing")

	# a chain: head on lane 1 row 2 cutting down, tail on lane 1 row 0, 4 slices
	var down := Utils.precise_angle_rad(1, 0)
	var chain := ChainInfo.new(0, 4.0, 1, 2, down, 5.0, 1, 0, 4, 1.0, 0.0)
	var points := ChainLink.curve_points(chain)
	var head: Vector2 = points[0]
	var tail: Vector2 = points[1]
	var mid: Vector2 = points[2]
	var x1 := Settings.LANE_DISTANCE_X + Settings.LANE_ZERO_X
	check(head.is_equal_approx(Vector2(x1, Constants.layer_y(2))) and tail.is_equal_approx(Vector2(x1, Constants.layer_y(0))),
			"the chain's ends sit on the head's and tail's places")
	check(near.call(mid.x, x1) and mid.y < head.y, "the curve's middle point lies along the head's arrow (down)")
	var last: Array = ChainLink.link_place(chain, head, tail, mid, chain.slice_count - 1)
	check(near.call(last[0], 5.0) and (last[1] as Vector2).is_equal_approx(tail), "the last link sits on the tail, on its beat")
	var ys := []
	var beats := []
	for i in range(1, chain.slice_count):
		var place: Array = ChainLink.link_place(chain, head, tail, mid, i)
		beats.append(place[0])
		ys.append((place[1] as Vector2).y)
		check(near.call((place[1] as Vector2).x, x1), "link %d stays in the head's lane on a straight chain" % i)
	check(beats[0] < beats[1] and beats[1] < beats[2] and ys[0] > ys[1] and ys[1] > ys[2],
			"links step on from the head to the tail in beat and down the curve")
	var squished := ChainInfo.new(0, 4.0, 1, 2, down, 5.0, 1, 0, 4, 0.5, 0.0)
	var half: Array = ChainLink.link_place(squished, head, tail, mid, squished.slice_count - 1)
	check(near.call(half[0], 4.5), "a squish of 0.5 ends the links halfway to the tail's beat")

	Map.one_saber = one_saber
	for key: StringName in saved:
		Settings.set(key, saved[key])
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
