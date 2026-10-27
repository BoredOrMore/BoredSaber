extends Node
# Headless checks that the HUD's panels are placed from the player's eye (Hud._panel): the same angle and distance
# for any eye, clear of the lanes on the Wide modifiers, grown so the lines keep their size in view.
# Run: godot --headless --path . res://tests/test_hud.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## The panel's yaw and pitch from the eye, in degrees, and its distance.
func seen(eye: Vector3, panel: Transform3D) -> Vector3:
	var to := panel.origin - eye
	return Vector3(rad_to_deg(atan2(to.x, -to.z)), rad_to_deg(asin(to.y / to.length())), to.length())

func _ready() -> void:
	var width: int = Settings.width
	Settings.width = 100
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.01

	for eye: Vector3 in [Hud.HUD_EYE, Vector3(0.0, 1.85, 1.0), Vector3(0.1, 1.4, 1.2)]:
		var right := seen(eye, Hud._panel(eye, 1.0))
		var left := seen(eye, Hud._panel(eye, -1.0))
		check(near.call(right.x, Hud.HUD_YAW) and near.call(left.x, -Hud.HUD_YAW),
				"eye at %s: the panels sit %.0f degrees either side (got %.2f, %.2f)" % [eye, Hud.HUD_YAW, left.x, right.x])
		check(near.call(right.y, Hud.HUD_PITCH) and near.call(right.z, Hud.HUD_DISTANCE),
				"eye at %s: %.1f degrees below level, %.2f m away (got %.2f, %.2f)" % [eye, -Hud.HUD_PITCH, Hud.HUD_DISTANCE, right.y, right.z])
		var basis := Hud._panel(eye, 1.0).basis
		check(near.call(basis.get_scale().x, Hud.HUD_DISTANCE / Hud.HUD_LAID_OUT_DISTANCE),
				"eye at %s: the panel grows by its distance over the laid-out one" % eye)
		check(basis.z.normalized().dot((eye - Hud._panel(eye, 1.0).origin).normalized()) > 0.999, "eye at %s: the panel faces the eye" % eye)

	# Wide 200%: the lanes reach out further; the panels turn out to stay clear of them
	Settings.width = 200
	var clear := 1.5 * Settings.LANE_DISTANCE_X + Hud.HUD_LANE_MARGIN
	var wide := Hud._panel(Hud.HUD_EYE, 1.0)
	check(wide.origin.x >= clear - 0.001 and seen(Hud.HUD_EYE, wide).x > Hud.HUD_YAW,
			"Wide 200%%: the panel turns out past the outer lane (x %.2f, needs %.2f)" % [wide.origin.x, clear])
	check(near.call(seen(Hud.HUD_EYE, wide).z, Hud.HUD_DISTANCE), "Wide 200%: still HUD_DISTANCE from the eye")
	Settings.width = width

	check(Hud.grade_rises("A", "S") and Hud.grade_rises("B", "SS") and not Hud.grade_rises("S", "A")
			and not Hud.grade_rises("", "SS") and not Hud.grade_rises("A", "A"),
			"the live grade pops when it goes up, not when it stays or drops")
	check(Hud.shown_grade(1.0, 0) == "F" and Hud.shown_grade(1.0, 4) == "F" and Hud.shown_grade(1.0, 5) == "D"
			and Hud.shown_grade(1.0, 30) == "SS" and Hud.shown_grade(0.7, 100) == "A" and Hud.shown_grade(0.7, 10) == "C",
			"the live grade starts at F and climbs a step every 5 notes, never above the accuracy's grade")
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
