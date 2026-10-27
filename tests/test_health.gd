extends Node
# Headless checks for the health rules (Health.gd): the start in each fail mode, hits and damage in the health bar,
# Half Damage, 4 Lives, Instant, No Fail's hidden bar, and the cap.
# Run: godot --headless --path . res://tests/test_health.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func _ready() -> void:
	var bar := Constants.FAIL_MODE_BAR
	var lives := Constants.FAIL_MODE_LIVES
	var instant := Constants.FAIL_MODE_INSTANT
	var full := Constants.HEALTH_MAX

	check(Health.start_value(true, bar) == Constants.HEALTH_START, "the health bar starts half full")
	check(Health.start_value(true, lives) == full and Health.start_value(true, instant) == full,
			"4 Lives and Instant start full")
	check(Health.start_value(false, bar) == Constants.HEALTH_START, "No Fail's hidden bar starts half full")

	# the health bar: misses and bad cuts take off, hits give back, a wall drains
	var h := Health.next_value(50.0, Constants.HEALTH_MISS, true, true, bar, 1.0)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_MISS), "a miss takes HEALTH_MISS off the bar (got %s)" % h)
	h = Health.next_value(50.0, Constants.HEALTH_HIT, false, true, bar, 1.0)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_HIT), "a hit gives HEALTH_HIT back (got %s)" % h)
	h = Health.next_value(50.0, Constants.HEALTH_OBSTACLE_PER_SECOND * 0.1, false, true, bar, 1.0)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_OBSTACLE_PER_SECOND * 0.1), "a tenth of a second in a wall drains its share (got %s)" % h)
	h = Health.next_value(full - 0.5, Constants.HEALTH_HIT, false, true, bar, 1.0)
	check(h == full, "health never goes past the full bar (got %s)" % h)
	h = Health.next_value(5.0, Constants.HEALTH_MISS, true, true, bar, 1.0)
	check(h <= 0.0, "a miss with little health left empties the bar, which fails the song (got %s)" % h)

	# Half Damage halves what's taken, not what's given
	h = Health.next_value(50.0, Constants.HEALTH_MISS, true, true, bar, 0.5)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_MISS * 0.5), "Half Damage halves a miss (got %s)" % h)
	h = Health.next_value(50.0, Constants.HEALTH_HIT, false, true, bar, 0.5)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_HIT), "Half Damage leaves a hit's gain alone (got %s)" % h)

	# 4 Lives: each mistake costs a life, nothing else counts
	h = full
	for i in Constants.FAIL_LIVES - 1:
		h = Health.next_value(h, Constants.HEALTH_MISS, true, true, lives, 1.0)
	check(h > 0.0 and is_equal_approx(h, full / Constants.FAIL_LIVES), "4 Lives: three mistakes leave one life (got %s)" % h)
	check(Health.next_value(h, Constants.HEALTH_MISS, true, true, lives, 1.0) <= 0.0, "4 Lives: the fourth mistake fails")
	check(Health.next_value(full, Constants.HEALTH_OBSTACLE_PER_SECOND * 0.1, false, true, lives, 1.0) == full,
			"4 Lives: a wall's drain (not a mistake) costs nothing")
	check(Health.next_value(full - full / Constants.FAIL_LIVES, Constants.HEALTH_HIT, false, true, lives, 1.0)
			== full - full / Constants.FAIL_LIVES, "4 Lives: a hit doesn't win a life back")

	# Instant: the first mistake fails
	check(Health.next_value(full, Constants.HEALTH_MISS, true, true, instant, 1.0) <= 0.0, "Instant: one mistake fails")
	check(Health.next_value(full, Constants.HEALTH_HIT, false, true, instant, 1.0) == full, "Instant: hits change nothing")

	# No Fail: the hidden bar runs without Half Damage (running out halves the score, Scoreboard.spend_no_fail)
	h = Health.next_value(50.0, Constants.HEALTH_MISS, true, false, bar, 0.5)
	check(is_equal_approx(h, 50.0 + Constants.HEALTH_MISS), "No Fail's hidden bar takes a full miss (got %s)" % h)
	check(Health.next_value(full, Constants.HEALTH_HIT, false, false, bar, 1.0) == full, "No Fail's hidden bar stops at full")

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
