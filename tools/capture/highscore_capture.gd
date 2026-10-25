extends Control
## Renders the song menu's highscore list (game/HighscorePanel.tscn) at its in-game size, to check nothing spills off
## its board. Records come from a highscores.json (e.g. pulled from the headset) or are made up.
## Run: godot --path . res://tools/capture/highscore_capture.tscn -- --out /tmp/hs.png [--table highscores.json
##   --key "[artist,song,,mapper]" --rank 1793] [--names long] [--rows 10] [--mods 1]

func _ready() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var panel := (load("res://game/HighscorePanel.tscn") as PackedScene).instantiate() as HighscorePanel
	# as in BeepSaber_Game.tscn's song menu
	panel.offset_right = 600.0
	panel.show_song_info = false
	add_child(panel)
	DisplayServer.window_set_size(Vector2i(700, 600))
	var no_levels: Array[DifficultyInfo] = []
	var info := MapInfo.new("2", "Song", "", "Artist", "Mapper", 120.0, 0.0, 10.0, "song.ogg", "cover.jpg", "", 0.0, {}, "",
		no_levels)
	var rank := int(args.get("rank", "1"))
	if args.get("mods", "0") == "1":
		# every modifier on: the longest title
		rank = 4 | Constants.DIFFICULTY_NO_WALLS | Constants.DIFFICULTY_CLAWS
	if args.has("table"):
		var table: Variant = JSON.parse_string(FileAccess.get_file_as_string(args["table"]))
		Highscores._hs_table = table
		var key: String = args["key"]
		var parts := key.trim_prefix("[").trim_suffix("]").split(",")
		info.song_author_name = parts[0]
		info.song_name = ",".join(parts.slice(1, parts.size() - 2))
		info.song_sub_name = parts[parts.size() - 2]
		info.level_author_name = parts[parts.size() - 1]
	else:
		var rows := []
		var name := "Bartholomew Longname-Smithson the Third" if args.get("names", "") == "long" else "Bomb"
		for i in int(args.get("rows", "10")):
			rows.append({"player_name": name if i % 2 == 0 else "Anfield", "score": 1234567 - i * 100000, "epoch_time": 0})
		Highscores._hs_table = {info.get_key(): {str(HighscoreTable.get_rank_key(rank)): rows}}
	panel.load_highscores(info, rank)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	print("panel size ", panel.size, " title ", panel.get_node(^"Margin/VBox/Title").size)
	get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/hs.png"))
	get_tree().quit()
