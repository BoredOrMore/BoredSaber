extends Node
## Checks SongSearch: the song menu's search matches kana and romaji, case, spaces, punctuation and long vowels
## alike, every typed word, and the song's tags; and Get songs' shorter retry of a search that found nothing.

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		print("FAIL: ", what)

## A map with this name and artist (nothing else is read).
func song(name: String, artist: String) -> MapInfo:
	return MapInfo.new("2.0.0", name, "", artist, "Mapper", 120.0, 0.0, 10.0, "song.ogg", "cover.jpg", "", 0.0, {},
		"user://test_search/%s/" % name, [] as Array[DifficultyInfo])

func _ready() -> void:
	var keys := {
		"うっせぇわ": "usewa", "Usseewa": "usewa", "ussewa": "usewa",
		"夜に駆ける": "夜ni駆keru", "アイドル": "aidoru", "きゃりーぱみゅぱみゅ": "kyaripamyupamyu",
		"しゃ": "sha", "ちょっと": "choto", "Tokyo Flash!": "tokyoflash", "Kyouryuu": "kyoryu",
	}
	for text: String in keys:
		check(SongSearch.key(text) == keys[text], "key(%s) is %s (got %s)" % [text, keys[text], SongSearch.key(text)])
	var usseewa := song("うっせぇわ", "Ado")
	check(SongSearch.matches("usseewa", usseewa, PackedStringArray()), "romaji finds a kana title")
	check(SongSearch.matches("USSEWA ado", usseewa, PackedStringArray()), "every word, any case, a long vowel short")
	check(not SongSearch.matches("usseewa vaundy", usseewa, PackedStringArray()), "a word that isn't there finds nothing")
	var odoriko := song("Odoriko", "Vaundy")
	check(SongSearch.matches("j-pop", odoriko, PackedStringArray(["j-pop", "dance-style"])), "a tag finds the song")
	check(SongSearch.matches("jpop", odoriko, PackedStringArray(["j-pop"])), "a tag without its dash finds it")
	check(not SongSearch.matches("anime", odoriko, PackedStringArray(["j-pop"])), "a tag the song lacks doesn't")
	# an AI-made map keeps the AI mark with its tags, so the song menu can label it
	check(SongTags.tags_from({"tags": ["anime"], "automapper": true}) == ["anime", SongTags.AI_TAG],
			"an AI map's saved tags carry the AI mark")
	check(SongTags.tags_from({"tags": ["anime"], "automapper": false}) == ["anime"], "a person's map's don't")
	# Get songs lists a 360°-only map by its 360° difficulties, a Standard one by Standard, and drops one with neither
	var diff := func(mode: String) -> Dictionary: return {"characteristic": mode, "notes": 100, "nps": 3.0, "njs": 16.0, "offset": 0.0}
	var only_360 := BeatSaverPanel.BeatSaverSongInfo.new({"versions": [{"hash": "a", "diffs": [diff.call("360Degree")]}]})
	check(only_360.is_playable() and only_360.mode == "360Degree" and only_360.estimated_levels(1.0).size() == 1,
			"a 360°-only map is listed, rated by its 360° difficulty (mode %s)" % only_360.mode)
	var both := BeatSaverPanel.BeatSaverSongInfo.new({"versions": [{"hash": "b", "diffs": [diff.call("90Degree"), diff.call("Standard")]}]})
	check(both.mode == "Standard", "a map with Standard is listed by Standard (got %s)" % both.mode)
	var lights := BeatSaverPanel.BeatSaverSongInfo.new({"versions": [{"hash": "c", "diffs": [diff.call("Lightshow")]}]})
	check(not lights.is_playable(), "a map with no Standard, 360° or 90° isn't")
	# Get songs: a search that found nothing tries each word cut to its start once
	var close := {"ussewa": "usse", "yoru ni kakeu": "yoru ni kake", "blindng lights": "blind ligh", "ado": "ado",
		"senbonzakra": "senbonza", "gurenga": "guren"}
	for text: String in close:
		check(BeatSaverPanel.close_query(text) == close[text], "close_query(%s) is %s (got %s)" % [
				text, close[text], BeatSaverPanel.close_query(text)])
	print("%d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)
