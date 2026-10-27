extends Node
# Headless checks for the highscore table (HighscoreTable): order, the 10-record limit, ties, separate tables per map,
# difficulty and modifiers, renaming players, and saving. It writes to a file of its own, never the player's.
# Run: godot --headless --path . res://tests/test_highscores.tscn

const TEST_FILE := "user://test_highscores.json"

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func map(song_name: String) -> MapInfo:
	return MapInfo.new("2.0.0", song_name, "", "Artist", "Mapper", 120.0, 0.0, 10.0, "song.ogg", "cover.jpg", "",
		0.0, {}, "user://no_such_song/", [] as Array[DifficultyInfo])

func table() -> HighscoreTable:
	var hs := HighscoreTable.new()
	hs.HIGHSCORES_FILEPATH = TEST_FILE
	hs.clear_table()
	return hs

## The records of map at rank as add_highscore stores them (the rank folded with the current modifiers).
func records(hs: HighscoreTable, info: MapInfo, rank: int) -> Array:
	return hs.get_records(info, HighscoreTable.get_rank_key(rank))

func _ready() -> void:
	var saved := {}
	for key: StringName in [&"music_speed", &"width", &"walls_enabled", &"health_mode", &"block_size"]:
		saved[key] = Settings.get(key)
	Settings.music_speed = 100
	Settings.width = 100
	Settings.walls_enabled = true
	Settings.block_size = 100
	var a := map("Song A")
	var b := map("Song B")

	var hs := table()
	hs.add_highscore(a, 1, "Player", 10000)
	hs.add_highscore(a, 1, "Player", 20000)
	var r := records(hs, a, 1)
	check(r.size() == 2 and r[0].score == 20000 and r[1].score == 10000, "records are kept highest first")
	check(hs.get_highscore(a, 1) == 20000, "get_highscore gives the best score")
	check(hs.get_highscore(b, 1) == -1, "a map without records has no highscore (-1)")

	hs = table()
	for i in 20:
		hs.add_highscore(a, 1, "Player", i * 100)
	r = records(hs, a, 1)
	check(r.size() == HighscoreTable.MAX_RECORDS_PER_KEY and r[0].score == 1900 and r[-1].score == 1000,
			"only the best %d records stay" % HighscoreTable.MAX_RECORDS_PER_KEY)
	check(not hs.is_new_highscore(a, 1, 500), "a score below the 10th isn't a new highscore")
	check(hs.is_new_highscore(a, 1, 1500), "a score inside the top 10 is a new highscore")
	check(not hs.is_new_highscore(b, 1, 0), "a score of 0 is never a highscore")

	hs = table()
	var first := hs.add_highscore(a, 1, "first", 1000)
	first.epoch_time = 1.0
	hs.add_highscore(a, 1, "lower", 500)
	hs.add_highscore(a, 1, "second", 1000)
	r = records(hs, a, 1)
	check(r.size() == 3 and r[0].player_name == "first" and r[1].player_name == "second", "a tie keeps the older record first")

	hs = table()
	hs.add_highscore(a, 1, "on A", 1000)
	hs.add_highscore(b, 1, "on B", 2000)
	hs.add_highscore(a, 3, "on A hard", 3000)
	check(records(hs, a, 1).size() == 1 and records(hs, a, 1)[0].player_name == "on A", "each map has its own table")
	check(records(hs, b, 1).size() == 1 and records(hs, b, 1)[0].score == 2000, "the other map's record stays apart")
	check(records(hs, a, 3).size() == 1 and records(hs, a, 3)[0].score == 3000, "each difficulty has its own table")

	# modifiers that change the score get their own tables (HighscoreTable.get_rank_key)
	hs = table()
	hs.add_highscore(a, 1, "normal", 1000)
	Settings.music_speed = 150
	hs.add_highscore(a, 1, "fast", 900)
	check(records(hs, a, 1).size() == 1 and records(hs, a, 1)[0].player_name == "fast", "Speed 150% keeps its own table")
	Settings.music_speed = 100
	Settings.width = 150
	check(records(hs, a, 1).is_empty(), "a wider track keeps its own table")
	Settings.width = 100
	Settings.walls_enabled = false
	check(records(hs, a, 1).is_empty(), "No Walls keeps its own table")
	Settings.walls_enabled = true
	check(records(hs, a, 1).size() == 1 and records(hs, a, 1)[0].player_name == "normal", "back to no modifiers finds the first table")

	hs = table()
	hs.add_highscore(a, 1, "Alice", 1000)
	hs.add_highscore(b, 1, "Bob", 1000)
	hs.add_highscore(b, 3, "Alice", 500)
	var names := hs.get_all_player_names()
	check(names.size() == 2 and names.has("Alice") and names.has("Bob"), "every player's name is listed once")
	check(hs.count_records("Alice") == 2, "count_records counts a player's records across maps")
	hs.rename_player("Alice", "Carol")
	check(hs.count_records("Carol") == 2 and hs.count_records("Alice") == 0, "rename_player renames every record")

	# saved and read back
	var again := HighscoreTable.new()
	again.HIGHSCORES_FILEPATH = TEST_FILE
	again.load_hs_table()
	check(again.get_highscore(b, 1) == 1000 and again.count_records("Carol") == 2, "the table reads back as saved")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	for key: StringName in saved:
		Settings.set(key, saved[key])
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
