extends Node
# Headless checks for the difficulty rating (MapStats._swing_parts, stars, star_level; doc/research/difficulty-rating.md)
# and Get songs' BeatLeader stars (BeatSaverSongInfo.parse_stars, stars_at, level_of, rating).
# Run: godot --headless --path . res://tests/test_map_stats.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## [beat, cut direction, column] notes for one hand, one every `step` beats from `start`, alternating down and up.
func notes(count: int, step: float, column: int, start := 0.0) -> Array:
	var out := []
	for i in count:
		out.append([start + i * step, 1 if i % 2 == 0 else 0, column])
	return out

func _ready() -> void:
	# 120 BPM: half a second a beat. Each hand swings down-up once a beat in its own lane for 20 s.
	var spb := 0.5
	var parts := MapStats._swing_parts([notes(40, 1.0, 1), notes(40, 1.0, 2, 0.5)] as Array[Array], spb)
	check(is_equal_approx(float(parts.turn), 0.0) and is_equal_approx(float(parts.flow), 0.0), "clean down-up swings don't turn")
	check(is_equal_approx(float(parts.cross), 0.0) and is_equal_approx(float(parts.crossed), 0.0),
		"each hand on its own side never crosses (got %s, %s)" % [parts.cross, parts.crossed])
	check(is_equal_approx(float(parts.burst), 4.0), "two swings a second per hand burst at 4 a second (got %s)" % parts.burst)

	# the left hand in the right hand's near column half the time, the right hand in the far left column once in four
	var left := notes(40, 1.0, 1)
	for i in range(0, 40, 2):
		left[i][2] = 2
	var right := notes(40, 1.0, 3, 0.5)
	for i in range(0, 40, 4):
		right[i][2] = 0
	parts = MapStats._swing_parts([left, right] as Array[Array], spb)
	# left: 20 near swings x 0.5; right: 10 far swings x 1 -> 20 of 80 swings
	check(is_equal_approx(float(parts.cross), 25.0), "near columns count half, far ones whole (got %s)" % parts.cross)
	check(float(parts.flow) > 0.0, "far columns still count in the flow percent")
	check(is_equal_approx(float(parts.turn), 0.0), "crossing isn't turning")

	# arms crossed: left hand in column 3, the right in column 0 0.1 s later; each right swing follows a left one closely
	parts = MapStats._swing_parts([notes(10, 1.0, 3), notes(10, 1.0, 0, 0.2)] as Array[Array], spb)
	check(is_equal_approx(float(parts.crossed), 50.0), "swings with the arms crossed count (got %s)" % parts.crossed)

	# down then down again is a reset
	var resets := []
	for i in 20:
		resets.append([i * 1.0, 1, 1])
	parts = MapStats._swing_parts([resets, []] as Array[Array], spb)
	check(float(parts.turn) > 180.0, "a reset counts 2 per swing (got %s)" % parts.turn)

	# the burst is the busy stretch, not the average: 10 s slow then 10 s fast
	var burst := notes(5, 4.0, 1) + notes(40, 0.5, 1, 22.0)
	parts = MapStats._swing_parts([burst, []] as Array[Array], spb)
	check(float(parts.burst) >= 3.5, "a fast stretch sets the burst (got %s)" % parts.burst)

	# stars and levels
	var easy := {"burst": 2.0, "cross": 0.0, "crossed": 0.0, "turn": 0.0}
	check(MapStats.star_level(MapStats.stars(easy, 1.0)) == 0, "a slow smooth map is Easy (%s stars)" % MapStats.stars(easy, 1.0))
	check(MapStats.stars(easy, 1.5) > MapStats.stars(easy, 1.0), "a faster song rates harder")
	var crossy := easy.duplicate()
	crossy.cross = 15.0
	crossy.crossed = 5.0
	check(MapStats.stars(crossy, 1.0) > MapStats.stars(easy, 1.0), "crossing the body rates harder")
	check(MapStats.star_level(3.93) == 0 and MapStats.star_level(3.94) == 1 and MapStats.star_level(6.64) == 4,
		"levels change at Constants.STAR_LEVEL_TOPS")

	# Get songs: BeatLeader's stars for a map, read between its rated speeds
	var body := JSON.stringify({"leaderboards": [
		{"difficulty": {"modeName": "Standard", "difficultyName": "Hard", "stars": 5.51,
			"modifiersRating": {"ssStars": 5.14, "fsStars": 5.90, "sfStars": 6.52}}},
		{"difficulty": {"modeName": "Standard", "difficultyName": "Expert", "stars": 7.31, "modifiersRating": null}},
		{"difficulty": {"modeName": "Generated360Degree", "difficultyName": "Hard", "stars": null}},
	]}).to_utf8_buffer()
	var parsed := []
	BeatSaverPanel.BeatSaverSongInfo.parse_stars(body, parsed)
	check(parsed.size() == 1 and (parsed[0] as Dictionary).size() == 2, "unrated difficulties are left out (got %s)" % [parsed])
	var song := BeatSaverPanel.BeatSaverSongInfo.new({"metadata": {"bpm": 135.0},
		"versions": [{"hash": "x", "diffs": [{"characteristic": "Standard", "difficulty": "Hard", "njs": 13.0, "offset": 1.0, "nps": 3.045}]}]})
	var diff: Dictionary = (song.versions[0] as Dictionary).diffs[0]
	var estimate := song.level_of(diff, 1.0)
	check(song.rating == BeatSaverPanel.BeatSaverSongInfo.Rating.LOADING, "levels wait for BeatLeader at first")
	song.set_stars(parsed[0])
	check(song.rating == BeatSaverPanel.BeatSaverSongInfo.Rating.STARS, "stars for its mode rate it")
	check(is_equal_approx(song.stars_at("Standard/Hard", 1.0), 5.51), "plain speed reads the plain stars")
	check(is_equal_approx(song.stars_at("Standard/Hard", 1.1), (5.51 + 5.90) / 2.0), "speeds between are read between")
	check(song.stars_at("Standard/Hard", 1.75) > 6.52, "past Super Fast carries on up")
	check(song.stars_at("Standard/Expert", 1.0) > 0.0 and song.stars_at("Standard/Expert", 1.25) == 0.0,
		"without speed ratings only the plain speed is known")
	var other := BeatSaverPanel.BeatSaverSongInfo.new({"versions": [{"hash": "y", "diffs": [{"characteristic": "Standard",
		"difficulty": "Hard"}]}]})
	other.set_stars({"360Degree/Hard": [0.0, 5.0, 0.0, 0.0]})
	check(other.rating == BeatSaverPanel.BeatSaverSongInfo.Rating.ESTIMATE, "no stars for its mode: the estimate")
	var lost := BeatSaverPanel.BeatSaverSongInfo.new({"versions": []})
	lost.stars_failed()
	check(lost.rating == BeatSaverPanel.BeatSaverSongInfo.Rating.ESTIMATE, "BeatLeader not reached: the estimate")
	var strip := LevelStrip.strip_image([2], 2, LevelStrip.Mark.LOADING)
	check(strip.get_size() == Vector2i(LevelStrip.WIDTH, LevelStrip.STRIP), "the loading strip keeps the strip's size")
	check(estimate == 2 and song.level_of(diff, 1.0) == 3, "Gurenge Hard: ≈Hard by estimate, Expert by BeatLeader (was %d, now %d)" % [estimate, song.level_of(diff, 1.0)])

	if failures > 0:
		printerr("%d check(s) failed" % failures)
	get_tree().quit(1 if failures > 0 else 0)
