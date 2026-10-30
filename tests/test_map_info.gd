extends Node
# Headless checks for beatmap Info.dat parsing.
# Run: godot --headless --path . res://tests/test_map_info.tscn

const V4_DIR := "user://test_maps/v4/"
const V4_INFO := {
	"version": "4.0.1",
	"song": {"title": "Test Song", "subTitle": "", "author": "Tester"},
	"audio": {
		"songFilename": "song.ogg",
		"songDuration": 60.0,
		"audioDataFilename": "BPMInfo.dat",
		"bpm": 128.0,
		"lufs": 0.0,
		"previewStartTime": 12.0,
		"previewDuration": 10.0,
	},
	"songPreviewFilename": "song.ogg",
	"coverImageFilename": "cover.png",
	"environmentNames": ["DefaultEnvironment"],
	"colorSchemes": [],
	"difficultyBeatmaps": [{
		"characteristic": "Standard",
		"difficulty": "Expert",
		"beatmapAuthors": {"mappers": ["Mapper"], "lighters": []},
		"environmentNameIdx": 0,
		"beatmapColorSchemeIdx": 0,
		"noteJumpMovementSpeed": 16.0,
		"noteJumpStartBeatOffset": 0.0,
		"beatmapDataFilename": "Expert.dat",
		"lightshowDataFilename": "Lightshow.dat",
	}],
}

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

func _ready() -> void:
	var v2 := Map.load_map_info("res://game/data/maps/Songs/TheFatRat_Timelapse/")
	check(v2 != null, "v2 bundled song loads")
	if v2:
		check(is_equal_approx(v2.beats_per_minute, 127.0), "v2 BPM is read from _beatsPerMinute (got %s)" % v2.beats_per_minute)

	DirAccess.make_dir_recursive_absolute(V4_DIR)
	var f := FileAccess.open(V4_DIR + "Info.dat", FileAccess.WRITE)
	f.store_string(JSON.stringify(V4_INFO))
	f.close()
	var v4 := Map.load_map_info(V4_DIR)
	check(v4 != null, "v4 Info.dat loads")
	if v4:
		check(v4.version.begins_with("4."), "v4 version is kept")
		check(is_equal_approx(v4.beats_per_minute, 128.0), "v4 BPM is read from audio.bpm (got %s)" % v4.beats_per_minute)
		check(is_equal_approx(v4.preview_start_time, 12.0), "v4 preview start is read")
		check(v4.difficulty_beatmaps.size() == 1, "v4 difficulty list is read")
		if v4.difficulty_beatmaps.size() == 1:
			check(v4.difficulty_beatmaps[0].lightshow_filename == "Lightshow.dat",
				"v4 lightshow file name is read (got %s)" % v4.difficulty_beatmaps[0].lightshow_filename)

	# Mapping Extensions' precise values, as the mod places them (Kylemc1413/MappingExtensions)
	check(is_equal_approx(Utils.precise_measurement(1500), 0.5) and is_equal_approx(Utils.precise_measurement(-2000), -1.0)
			and is_equal_approx(Utils.precise_measurement(2), 2.0), "precise lanes: 1500 is 0.5, -2000 is -1, 2 stays")
	check(is_equal_approx(Utils.adjust_horizontal(0.5), 0.5), "a precise lane isn't rounded (got %s)" % Utils.adjust_horizontal(0.5))
	check(is_equal_approx(Utils.precise_layer(1500), 0.5) and is_equal_approx(Utils.precise_layer(-1000), -2.0),
			"precise rows: 1500 is 0.5, -1000 is -2")
	check(is_equal_approx(Utils.precise_angle_rad(1090, 0), Utils.precise_angle_rad(2, 0))
			and is_equal_approx(Utils.precise_angle_rad(1000, 0), Utils.precise_angle_rad(1, 0)),
			"precise angles: 1090 points left as direction 2, 1000 down as direction 1")
	# a difficulty requiring a mod the game lacks says which; Mapping Extensions and Chroma play here
	var needs := func(reqs: Array) -> String:
		return DifficultyInfo.new("Expert", 7, "E.dat", 16.0, 0.0, {"_requirements": reqs}, "", "Standard").missing_mod()
	check(needs.call(["Noodle Extensions"]) == "Noodle Extensions", "Noodle Extensions is missing")
	check(needs.call(["Mapping Extensions", "Chroma"]) == "", "Mapping Extensions and Chroma play here")
	check(DifficultyInfo.new("Expert", 7, "E.dat", 16.0, 0.0, {"requirements": ["Vivify"]}, "", "Standard").missing_mod() == "Vivify",
			"v4's requirements are read too")

	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)
