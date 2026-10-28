extends Node3D
## Renders the score screen (game/ui/EndScore.tscn) with given text, to check that nothing spills off its board.
## Run: godot --path . res://tools/capture/endscore_capture.tscn -- --out /tmp/end.png [--song "name"] [--author "x"]
##   [--level "Expert+"] [--mapper "y"] [--card "text"] [--card-change 1] [--percent 0.87] [--record 1] [--fc 1]
##   [--failed-at 102 --length 190] (with --percent -1: a fail at that second of a song that long)

func _ready() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	DisplayServer.window_set_size(Vector2i(1600, 1000))
	var end := (load("res://game/ui/EndScore.tscn") as PackedScene).instantiate() as EndScore
	add_child(end)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 1.25)
	camera.fov = 60.0
	add_child(camera)
	camera.make_current()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.08)
	add_child(env)
	var song := "%s By %s\n%s     Map author: %s" % [args.get("song", "Silhouette (TV Size) (2023 Remap)"),
		args.get("author", "KANA-BOON"), args.get("level", "Normal"), args.get("mapper", "Joetastic & Someone Else")]
	if args.has("before"):
		# a song before this one, its screen shown and closed, as when playing songs in a row; then capture this
		# song's screen on its first frames
		end.show_score(999999, 999999, float(args["before"]), song, true, true)
		end._show()
		await get_tree().create_timer(4.0).timeout
		end._hide()
		await get_tree().create_timer(0.5).timeout
		end.show_score(123456, 234567, float(args.get("percent", "0.87")), song, args.get("fc", "0") == "1", args.get("record", "0") == "1",
			float(args.get("failed-at", "102")), float(args.get("length", "190")))
		end._show()
		for frame in int(args.get("frames", "1")):
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/end.png"))
		get_tree().quit()
		return
	end.show_score(123456, 234567, float(args.get("percent", "0.87")), song, args.get("fc", "0") == "1", args.get("record", "0") == "1",
			float(args.get("failed-at", "102")), float(args.get("length", "190")))
	if args.has("card"):
		end.show_name_card(args["card"], args.get("card-change", "0") == "1")
	await get_tree().create_timer(4.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args.get("out", "/tmp/end.png"))
	get_tree().quit()
