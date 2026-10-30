extends Node
# Headless checks for Scoreboard: the combo multiplier, points and max points, modifiers, No Fail,
# misses, bombs, bad cuts, walls, chain links and restart.
# Run: godot --headless --path . res://tests/test_scoreboard.tscn

## Stands in for the game scene Scoreboard calls into (health, sounds, time, event driver), recording health changes.
class FakeGame extends BeepSaber_Game:
	var health_calls: Array = []
	var time := 0.0

	func update_health(delta: float, mistake: bool = false) -> void:
		health_calls.append([delta, mistake])

	func get_current_time() -> float:
		return time

	func play_mistake_sound(_bomb: bool, _at: Vector3) -> void:
		pass

	func play_miss_sound(_at: Vector3) -> void:
		pass

## Settings this test changes; saved in _ready and put back at the end.
const SETTING_KEYS := [&"music_speed", &"width", &"block_size", &"walls_enabled", &"bombs_enabled",
	&"arrows_enabled", &"health_mode", &"fail_mode", &"damage_scale", &"swing_scoring", &"explain"]

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 1e-4

func neutral_modifiers() -> void:
	Settings.music_speed = 100
	Settings.width = 100
	Settings.block_size = 100
	Settings.walls_enabled = true
	Settings.bombs_enabled = true
	Settings.arrows_enabled = true
	Settings.health_mode = false
	Settings.fail_mode = Constants.FAIL_MODE_BAR
	Settings.damage_scale = 1.0
	Settings.explain = false

func hit(amount: int, best := 0.0) -> void:
	Scoreboard.add_points(Vector3.ZERO, 0.0, amount, "", best)

## The multiplier a perfect combo has on note n (1-based): x1, then x2 for 2-5, x4 for 6-13, x8 after.
func perfect_multiplier(n: int) -> int:
	return 1 if n == 1 else 2 if n <= 5 else 4 if n <= 13 else 8

func _ready() -> void:
	var saved := {}
	for key: StringName in SETTING_KEYS:
		saved[key] = Settings.get(key)
	var saved_game := GlobalReferences.main_game_scene
	var game := FakeGame.new()
	game.event_driver = EventDriver.new()
	GlobalReferences.main_game_scene = game

	neutral_modifiers()
	Settings.swing_scoring = false
	_test_multiplier_and_perfect_run()
	_test_points()
	_test_modifiers()
	_test_no_fail()
	_test_bad_cuts(game)
	_test_walls(game)
	_test_chain_links()
	_test_restart()
	_test_song_progress()
	Settings.swing_scoring = true
	neutral_modifiers()
	_test_swing_scoring_perfect_run()

	GlobalReferences.main_game_scene = null
	Scoreboard.restart()
	var before := Scoreboard.max_points
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "miss")
	check(Scoreboard.max_points == before and Scoreboard.full_combo, "with no game scene (stage preview) a miss changes nothing")

	GlobalReferences.main_game_scene = saved_game
	# BeepSaber_Game makes a few nodes in var initializers that _ready (never run here) would adopt; they leak at exit, harmlessly
	game.event_driver.free()
	game.free()
	for key: StringName in SETTING_KEYS:
		Settings.set(key, saved[key])
	Scoreboard.restart()

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

## The HUD's percent: 0 before any note, climbing to the accuracy at the song's end; chain links count in the song's best.
func _test_song_progress() -> void:
	var saved_notes := Map.note_stack
	var saved_chains := Map.chain_stack
	var best := int(Scoreboard.note_best_score())
	Map.note_stack = []
	for i in 20:
		Map.note_stack.append(ColorNoteInfo.new(float(i), 1, 0, 0, 1, 0))
	Map.chain_stack = []
	Scoreboard.restart()
	check(Scoreboard.song_best == best * (8 * 20 - 63), "the song's best is best x (8n-63) for 20 notes (got %d)" % Scoreboard.song_best)
	check(near(Scoreboard.song_progress(), 0.0), "the percent starts at 0 (got %.4f)" % Scoreboard.song_progress())
	for i in 10:
		hit(best)
	check(near(Scoreboard.song_progress(), float(Scoreboard.points) / Scoreboard.song_best),
		"halfway, the percent is points over the song's best (got %.4f)" % Scoreboard.song_progress())
	check(Scoreboard.song_progress() < Scoreboard.accuracy(), "halfway through a perfect run the percent is below the accuracy")
	for i in 10:
		hit(best)
	check(near(Scoreboard.song_progress(), 1.0), "a perfect run ends at 100% (got %.4f)" % Scoreboard.song_progress())

	# a chain on the first note: the head gives a note's best, each of its 2 links the link's best
	Map.note_stack = [ColorNoteInfo.new(0.0, 1, 0, 0, 1, 0)]
	Map.chain_stack = [ChainInfo.new(0, 0.0, 1, 0, 0, 1.0, 1, 2, 3, 1.0, 0)]
	Scoreboard.restart()
	var link := int(Scoreboard.chain_link_best_score())
	check(Scoreboard.song_best == best + link * 2 * 2, "a chain head plus 2 links at x2 (got %d)" % Scoreboard.song_best)

	Map.note_stack = saved_notes
	Map.chain_stack = saved_chains
	Scoreboard.restart()

func _test_multiplier_and_perfect_run() -> void:
	Scoreboard.restart()
	var best := Scoreboard.note_best_score()
	check(near(best, 150.0), "OpenSaber scoring: a note's best is 50+50+50 (got %.1f)" % best)
	check(Scoreboard.multiplier == 1 and Scoreboard.combo == 0 and near(Scoreboard.accuracy(), 1.0),
		"a new song starts at x1, combo 0, accuracy 1")
	# hit counts after which the multiplier should be: x2 needs 2 hits at x1, x4 4 at x2, x8 8 at x4
	var expected := {1: 1, 2: 2, 5: 2, 6: 4, 13: 4, 14: 8, 20: 8}
	for n in range(1, 21):
		hit(int(best))
		if expected.has(n):
			check(Scoreboard.multiplier == expected[n], "after %d perfect hits the multiplier is x%d (got x%d)" % [n, expected[n], Scoreboard.multiplier])
	check(Scoreboard.combo == 20, "combo counts 20 hits (got %d)" % Scoreboard.combo)
	check(near(Scoreboard.multiplier_progress(), 1.0), "at x8 the multiplier progress shows full")
	# Beat Saber's max score for n >= 14 notes: best x (8n - 63)
	check(Scoreboard.max_points == int(best) * (8 * 20 - 63), "max points for 20 notes is best x (8n-63) (got %d)" % Scoreboard.max_points)
	check(Scoreboard.points == Scoreboard.max_points, "a perfect run scores the max (%d / %d)" % [Scoreboard.points, Scoreboard.max_points])
	check(near(Scoreboard.accuracy(), 1.0), "a perfect run's accuracy is 1.0 (got %.4f)" % Scoreboard.accuracy())
	check(Scoreboard.full_combo, "a perfect run keeps the full combo")

	# a miss halves the multiplier, ends the combo, and the next step needs 2 x multiplier hits again
	Scoreboard.reset_combo(true, "miss")
	check(Scoreboard.multiplier == 4 and Scoreboard.combo == 0 and not Scoreboard.full_combo,
		"reset_combo: x8 -> x4, combo 0, full combo lost")
	check(near(Scoreboard.multiplier_progress(), 0.0), "reset_combo clears the progress toward the next multiplier")
	for i in 7:
		hit(int(best))
	check(Scoreboard.multiplier == 4, "7 hits at x4 are not enough for x8")
	hit(int(best))
	check(Scoreboard.multiplier == 8, "the 8th hit at x4 raises it to x8")
	Scoreboard.reset_combo(true, "miss")
	Scoreboard.reset_combo(true, "miss")
	Scoreboard.reset_combo(true, "miss")
	check(Scoreboard.multiplier == 1, "three misses take x8 down to x1")
	Scoreboard.reset_combo(true, "miss")
	check(Scoreboard.multiplier == 1, "the multiplier never drops below x1")

func _test_points() -> void:
	Scoreboard.restart()
	hit(100)
	check(Scoreboard.points == 100, "first hit counts at x1 (got %d)" % Scoreboard.points)
	hit(100)
	check(Scoreboard.points == 300, "second hit raises to x2 and counts at x2 (got %d)" % Scoreboard.points)
	check(Scoreboard.max_points == 150 * 1 + 150 * 2, "max points follow each note's best at a perfect combo's multiplier")
	check(near(Scoreboard.accuracy(), 300.0 / 450.0), "accuracy is points over max points (got %.4f)" % Scoreboard.accuracy())
	hit(0)
	check(Scoreboard.points == 300 and Scoreboard.combo == 3, "a 0-point hit still counts toward the combo")

func _test_modifiers() -> void:
	neutral_modifiers()
	check(near(Scoreboard._modifier_scale(), 1.0), "no modifiers: scale 1")
	Settings.music_speed = 85
	check(near(Scoreboard._modifier_scale(), 0.70), "Speed 85%%: scale 0.70 (got %.4f)" % Scoreboard._modifier_scale())
	Settings.arrows_enabled = false
	check(near(Scoreboard._modifier_scale(), 0.40), "Speed 85%% + No Arrows: scale 0.40 (got %.4f)" % Scoreboard._modifier_scale())
	Settings.walls_enabled = false
	Settings.bombs_enabled = false
	check(near(Scoreboard._modifier_scale(), 0.25), "+ No Walls + No Bombs: scale 0.25 (got %.4f)" % Scoreboard._modifier_scale())
	Settings.walls_enabled = true
	Settings.bombs_enabled = true
	Settings.health_mode = true
	Settings.damage_scale = 0.5
	check(near(Scoreboard._modifier_scale(), 0.30), "+ half damage on the health bar: scale 0.30 (got %.4f)" % Scoreboard._modifier_scale())
	Settings.health_mode = false
	Settings.damage_scale = 1.0

	Scoreboard.restart()
	hit(100)
	check(Scoreboard.points == 40, "a 100 cut at x1 with scale 0.40 gives 40 (got %d)" % Scoreboard.points)
	hit(100)
	check(Scoreboard.points == 40 + 80, "the next at x2 gives 80 (got %d)" % Scoreboard.points)
	Scoreboard.restart()
	for i in 20:
		hit(150)
	check(Scoreboard.points == Scoreboard.max_points and near(Scoreboard.accuracy(), 1.0),
		"with modifiers a perfect run still has accuracy 1.0 (%d / %d)" % [Scoreboard.points, Scoreboard.max_points])
	check(Scoreboard.max_points == roundi(150 * (8 * 20 - 63) * 0.4), "modifiers scale max points too (got %d)" % Scoreboard.max_points)
	neutral_modifiers()

func _test_no_fail() -> void:
	Scoreboard.restart()
	for i in 6:
		hit(101)
	var points := Scoreboard.points
	var max_points := Scoreboard.max_points
	Scoreboard.spend_no_fail()
	check(Scoreboard.no_fail_spent, "spend_no_fail marks No Fail spent")
	check(Scoreboard.points == roundi(points * 0.5) and Scoreboard.max_points == roundi(max_points * 0.5),
		"spend_no_fail halves points and max points (%d/%d -> %d/%d)" % [points, max_points, Scoreboard.points, Scoreboard.max_points])
	check(near(Scoreboard._modifier_scale(), 0.5), "after spending No Fail the scale is 0.5")
	var after_once := Scoreboard.points
	var max_once := Scoreboard.max_points
	Scoreboard.spend_no_fail()
	check(Scoreboard.points == after_once and Scoreboard.max_points == max_once, "spend_no_fail halves only once")
	var mult := Scoreboard.multiplier
	hit(100)
	check(Scoreboard.points == after_once + roundi(100 * Scoreboard.multiplier * 0.5),
		"hits after No Fail is spent count half (x%d -> x%d)" % [mult, Scoreboard.multiplier])

func _test_bad_cuts(game: FakeGame) -> void:
	Scoreboard.restart()
	for i in 6:
		hit(150)
	var points := Scoreboard.points
	var max_points := Scoreboard.max_points
	check(Scoreboard.multiplier == 4, "6 hits reach x4")

	game.health_calls.clear()
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "miss")
	check(Scoreboard.points == points, "a miss gives no points")
	check(Scoreboard.max_points == max_points + 150 * perfect_multiplier(7), "a missed note still counts its best toward max points")
	check(Scoreboard.multiplier == 2 and Scoreboard.combo == 0 and not Scoreboard.full_combo, "a miss halves x4 to x2 and ends the combo")
	check(game.health_calls == [[Constants.HEALTH_MISS, true]], "a miss costs HEALTH_MISS health (%s)" % [game.health_calls])
	check(Scoreboard.accuracy() < 1.0, "a miss lowers accuracy (%.4f)" % Scoreboard.accuracy())

	max_points = Scoreboard.max_points
	game.health_calls.clear()
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "bad angle")
	check(Scoreboard.max_points == max_points + 150 * perfect_multiplier(8), "a bad cut counts its note toward max points")
	check(Scoreboard.multiplier == 1, "a bad cut halves x2 to x1")
	check(game.health_calls == [[Constants.HEALTH_BAD_CUT, true]], "a bad cut costs HEALTH_BAD_CUT health (%s)" % [game.health_calls])

	max_points = Scoreboard.max_points
	game.health_calls.clear()
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "wrong saber")
	check(Scoreboard.max_points == max_points + 150 * perfect_multiplier(9), "a wrong-saber cut counts its note toward max points")
	check(game.health_calls == [[Constants.HEALTH_MISS, true]], "a wrong-saber cut costs HEALTH_MISS health (%s)" % [game.health_calls])

	hit(150)
	hit(150)
	check(Scoreboard.multiplier == 2, "two hits after the misses get back to x2")
	max_points = Scoreboard.max_points
	game.health_calls.clear()
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "bomb")
	check(Scoreboard.max_points == max_points, "a bomb is not a note: max points unchanged")
	check(Scoreboard.multiplier == 1 and Scoreboard.combo == 0, "a bomb halves the multiplier and ends the combo")
	check(game.health_calls == [[Constants.HEALTH_BOMB, true]], "a bomb costs HEALTH_BOMB health (%s)" % [game.health_calls])

func _test_walls(game: FakeGame) -> void:
	Scoreboard.restart()
	for i in 6:
		hit(150)
	game.health_calls.clear()
	game.time = 10.0
	Scoreboard.enter_wall()
	check(Scoreboard.in_wall, "enter_wall puts the player in the wall")
	check(Scoreboard.multiplier == 2 and Scoreboard.combo == 0 and not Scoreboard.full_combo, "entering a wall halves x4 to x2 and ends the combo")
	check(game.health_calls.size() == 1 and near(game.health_calls[0][0], Constants.HEALTH_OBSTACLE_PER_SECOND * 0.1) and game.health_calls[0][1] == true,
		"entering a wall costs 0.1 s of obstacle damage, as a mistake (%s)" % [game.health_calls])
	game.time = 10.05
	Scoreboard.enter_wall()
	check(game.health_calls.size() == 1, "staying in a wall under 0.1 s later costs nothing more")
	check(Scoreboard.multiplier == 1, "each enter_wall call halves the multiplier again (x2 -> x1)")
	game.time = 10.25
	Scoreboard.enter_wall()
	check(game.health_calls.size() == 2 and near(game.health_calls[1][0], Constants.HEALTH_OBSTACLE_PER_SECOND * 0.25),
		"staying in a wall costs obstacle damage for the time since the last charge (%s)" % [game.health_calls])
	var points := Scoreboard.points
	hit(100)
	check(Scoreboard.combo == 0 and Scoreboard.multiplier == 1, "a hit inside a wall does not build the combo")
	check(Scoreboard.points == points + 100, "a hit inside a wall still scores at the current multiplier")
	Scoreboard.exit_wall()
	check(not Scoreboard.in_wall and Scoreboard.last_in_wall_time < 0, "exit_wall leaves the wall and resets its timer")
	hit(100)
	check(Scoreboard.combo == 1, "after the wall hits build the combo again")
	check(Scoreboard.summary().contains("walls 1"), "the summary counts one wall entry (%s)" % Scoreboard.summary())

func _test_chain_links() -> void:
	Scoreboard.restart()
	check(near(Scoreboard.chain_link_best_score(), Constants.OPENSABER_CHAIN_LINK_SCORE), "OpenSaber chain link best is OPENSABER_CHAIN_LINK_SCORE")
	Scoreboard.chain_link_cut(Vector3.ZERO, 0.0)
	check(Scoreboard.points == Constants.OPENSABER_CHAIN_LINK_SCORE and Scoreboard.combo == 1, "a chain link gives its score at x1 and builds the combo")
	Scoreboard.chain_link_cut(Vector3.ZERO, 0.0)
	check(Scoreboard.points == Constants.OPENSABER_CHAIN_LINK_SCORE * 3, "the second link counts at x2 (got %d)" % Scoreboard.points)
	check(Scoreboard.max_points == Scoreboard.points and near(Scoreboard.accuracy(), 1.0), "chain links count their own best toward max points")
	Settings.swing_scoring = true
	check(near(Scoreboard.chain_link_best_score(), Constants.SWING_CHAIN_LINK_SCORE), "swing chain link best is SWING_CHAIN_LINK_SCORE")
	Settings.swing_scoring = false

func _test_restart() -> void:
	Scoreboard.restart()
	for i in 10:
		hit(150)
	Scoreboard.bad_cut(Vector3.ZERO, 0.0, "miss")
	Scoreboard.enter_wall()
	Scoreboard.spend_no_fail()
	Scoreboard.restart()
	check(Scoreboard.points == 0 and Scoreboard.max_points == 0 and Scoreboard.combo == 0 and Scoreboard.multiplier == 1,
		"restart zeroes points, max points, combo and multiplier")
	check(Scoreboard.full_combo and not Scoreboard.in_wall and not Scoreboard.no_fail_spent and Scoreboard.last_in_wall_time < 0,
		"restart restores full combo and clears the wall and No Fail")
	check(near(Scoreboard.multiplier_progress(), 0.0) and near(Scoreboard.accuracy(), 1.0) and Scoreboard.summary() == "score_summary none",
		"restart clears multiplier progress, accuracy and the summary")
	hit(150)
	check(Scoreboard.points == 150 and Scoreboard.max_points == 150, "after restart the first hit counts from scratch")

func _test_swing_scoring_perfect_run() -> void:
	Scoreboard.restart()
	var best := Scoreboard.note_best_score()
	check(near(best, 115.0), "swing scoring: a note's best is 15+70+30 = 115 (got %.1f)" % best)
	for i in 14:
		Scoreboard.add_swing_score(Vector3.ZERO, 0.0, Constants.SWING_ACCURACY_SCORE,
			Constants.TARGET_PRESWING_ANGLE, Constants.TARGET_FOLLOWTHROUGH_ANGLE)
	check(Scoreboard.points == 115 * (8 * 14 - 63), "14 perfect swings score 115 x (8n-63) (got %d)" % Scoreboard.points)
	check(near(Scoreboard.accuracy(), 1.0), "14 perfect swings have accuracy 1.0")
