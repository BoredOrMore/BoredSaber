extends Node3D
## Captures a stage as the player sees it, on the desktop, with the game's own scenery, lights and shaders: the
## environment scene (event_driver.tscn), the game's WorldEnvironment, the platform and a camera at the player's eye.
## For checking the look without the headset (doc/assets, the rhythm-world and asset-pipeline reviews). Colours and
## brightness on the Pico's LCD differ somewhat; the headset stays the final check.
## Run (a window opens for a moment; headless can't render):
##   godot --path . res://tools/capture/stage_capture.tscn -- --out /tmp/stage.png [options]
## Options: --env classic|neon_grid|night_city|pulse_void|metal_factory  --built 0..1 (how much of the stage the crew has put up)
##   --lights on|off|menu  --left RRGGBB --right RRGGBB  --eye 1.6 (eye height, m)  --pitch 0 (degrees, up +)
##   --yaw 0 (degrees, left +)  --fov 90 (vertical, degrees)  --size 1920x1080  --seconds 2.5 (settle time)
##   --beat 0 (Metal Factory: the pistons at this beat of a 120 BPM song at full intensity; 0 is a hammer landing)
##   --animate 1 (Metal Factory: the pistons keep slamming at that tempo while the window is open; pair with --seconds)
##   --map <folder or song name> (play a Beat Saber map: its song, light show, colours and show intensity drive the stage
##   as in the game; a name without a / is a folder or song name in the game's Songs folder, e.g. --map Psycho; the stage is the one the map picks on Auto
##   unless --env is given; runs to the song's end unless --seconds is given)  --difficulty ExpertPlus (default the
##   hardest)  --start 0 (seconds into the song)
##   --notes 1 (with --map: the map's notes, bombs, walls, arcs and chains fly in, spawned, timed and sped as in the game
##   (GameStatePlaying.spawn_due); nobody cuts them, so they pass and are missed, which costs nothing here; 0 leaves them out)
##   --note left|right (one note held still NOTE_AHEAD in front of the eye, to look at its shading; pair with
##   --seconds 600 to keep the window open)  --note-yaw 0 --note-pitch 0 (degrees, turn it to see its sides and top)
##   --dot 1 (a dot note)  --note-style 2 (0 Solid, 1 Neon: the Classic notes looks; 2 the glossy default)

const ENVIRONMENT_SCENE := preload("res://game/event_driver.tscn")
const FLOOR_SCENE := preload("res://game/floor.tscn")
const GAME_SCENE := "res://game/BeepSaber_Game.tscn"
## where the player stands (XROrigin3D)
const PLAYER := Vector3(0.0, 0.0, 1.0)
## the tempo --beat is read at
const CAPTURE_BPM := 120.0

## the stage while --animate plays its beat, and the beat it is at
var _animated: EventDriver
var _beat := 0.0
## the stage --map drives, the song playing and its tempo
var _show: EventDriver
var _song: AudioStreamPlayer
var _bpm := 0.0
## --notes: the notes' pools (BeepSaber_Game.tscn's) and the track they fly along
const POOL_SCENE := preload("res://game/scripts/ScenePool/ScenePool.tscn")
const NOTE_SCENES := {
	&"cube_pool": preload("res://game/BeepCube/BeepCube.tscn"),
	&"link_pool": preload("res://game/Chain/ChainLink.tscn"),
	&"bomb_pool": preload("res://game/Bomb/Bomb.tscn"),
	&"wall_pool": preload("res://game/Wall/Wall.tscn"),
	&"arc_pool": preload("res://game/Arc/Arc.tscn"),
}
var _notes := false
const NOTE_SCENE := preload("res://game/BeepCube/BeepCube.tscn")
## --note: how far in front of the eye the note is held, metres
const NOTE_AHEAD := 0.9

func _ready() -> void:
	var args := _args()
	var size := (args.get("size", "1920x1080") as String).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	var left := Color(args.get("left", Settings.color_left.to_html(false)) as String)
	var right := Color(args.get("right", Settings.color_right.to_html(false)) as String)
	RenderingServer.global_shader_parameter_set(&"shadow_tint", Constants.SHADOW_TINT)
	RenderingServer.global_shader_parameter_set(&"left_saber_color", left)
	RenderingServer.global_shader_parameter_set(&"right_saber_color", right)
	RenderingServer.global_shader_parameter_set(&"note_style", int(args.get("note-style", "2")))

	var world := WorldEnvironment.new()
	world.environment = _game_environment()
	add_child(world)
	add_child(FLOOR_SCENE.instantiate())
	var stage := ENVIRONMENT_SCENE.instantiate() as EventDriver
	add_child(stage)

	var camera := Camera3D.new()
	camera.fov = float(args.get("fov", "90"))
	camera.position = PLAYER + Vector3.UP * float(args.get("eye", "1.6"))
	camera.rotation_degrees = Vector3(float(args.get("pitch", "0")), float(args.get("yaw", "0")), 0.0)
	add_child(camera)
	camera.make_current()

	await get_tree().process_frame
	# set_environment skips an environment that is already current (classic at start), which would leave every
	# rig's scenery showing; clear it first so the chosen one is applied in full
	stage.environment = ""
	stage.set_environment(args.get("env", "classic") as String)
	stage.update_left_color(left)
	stage.update_right_color(right)
	match args.get("lights", "on"):
		"off": stage.set_all_off()
		"menu": stage.set_menu_focus(true)
		_: stage.set_all_on(left, right)
	stage.classic_rig.set_built(float(args.get("built", "1")))
	if args.has("beat"):
		_beat = float(args["beat"])
		stage.metal_factory_rig.slam(_beat, CAPTURE_BPM, 1.0)
	if args.has("animate"):
		_animated = stage
	if args.has("note"):
		_hold_note(camera, left if args["note"] == "left" else right, args)
	if args.has("map") and not _play_map(stage, args):
		get_tree().quit(1)
		return

	if _song and not args.has("seconds"):
		await _song.finished
	else:
		await get_tree().create_timer(float(args.get("seconds", "2.5"))).timeout
	await RenderingServer.frame_post_draw
	var out := args.get("out", "user://stage_capture.png") as String
	var error := get_viewport().get_texture().get_image().save_png(out)
	print("stage_capture %s -> %s" % [error_string(error), out])
	get_tree().quit(0 if error == OK else 1)

## Plays the beat on the stage for --animate, or the song's light show for --map (as GameStatePlaying does).
func _process(delta: float) -> void:
	if _animated:
		_beat += delta * CAPTURE_BPM / 60.0
		_animated.metal_factory_rig.slam(_beat, CAPTURE_BPM, 1.0)
	if _song:
		var beat := _song.get_playback_position() * _bpm / 60.0
		_show.show_beat = beat
		if _notes:
			GameStatePlaying.spawn_due(beat)
		while not Map.event_stack.is_empty() and Map.event_stack[-1].beat <= beat:
			_show.process_event(Map.event_stack.pop_back() as EventInfo)

## Loads the map --map names and starts its song and show on `stage`, as BeepSaber_Game.start_map does; false if it
## can't be read.
func _play_map(stage: EventDriver, args: Dictionary) -> bool:
	var folder := args["map"] as String
	if not folder.contains("/"):
		folder = _find_song(folder)
	var info := Map.load_map_info(folder.trim_suffix("/") + "/")
	if info == null or info.difficulty_beatmaps.is_empty():
		push_error("stage_capture: no map in " + folder)
		return false
	var difficulty: DifficultyInfo = info.difficulty_beatmaps[-1]
	for d in info.difficulty_beatmaps:
		if d.difficulty == args.get("difficulty", ""):
			difficulty = d
	var map_data := Utils.binary_to_json(Utils.read_binary_file(info.filepath, difficulty.beatmap_filename))
	if not Map.load_beatmap(info, difficulty, map_data):
		push_error("stage_capture: can't read %s of %s" % [difficulty.beatmap_filename, folder])
		return false
	if not args.has("env"):
		stage.set_environment(EventDriver.pick_environment(info))
	stage.set_menu_focus(false)
	stage.update_left_color(Map.color_left)
	stage.update_right_color(Map.color_right)
	stage.set_background()
	# the show plays whatever the desktop's own Background setting is ("static" there would drop every light and ring
	# event); the saved setting is left alone
	stage.disabled = false
	stage.set_all_off()
	stage.start_show(Map.event_stack, info.beats_per_minute)
	_song = AudioStreamPlayer.new()
	_song.stream = AudioStreamOggVorbis.load_from_file(info.filepath + info.song_filename)
	add_child(_song)
	_song.play(float(args.get("start", "0")))
	_show = stage
	_bpm = info.beats_per_minute
	if args.get("notes", "1") != "0":
		_add_notes(float(args.get("start", "0")) * _bpm / 60.0)
	print("stage_capture: %s (%s), %s, %.0f BPM" % [info.song_name, difficulty.difficulty, stage.environment, _bpm])
	return true

## Puts one note (the game's own BeepCube) NOTE_AHEAD in front of `camera`, in `color`, turned by --note-yaw and
## --note-pitch. Without a map it doesn't move.
func _hold_note(camera: Camera3D, color: Color, args: Dictionary) -> void:
	var note := NOTE_SCENE.instantiate() as BeepCube
	add_child(note)
	note.position = camera.position + Vector3.FORWARD * NOTE_AHEAD
	note.rotation_degrees = Vector3(float(args.get("note-pitch", "0")), float(args.get("note-yaw", "0")), 0.0)
	var material := note.mi.material_override as ShaderMaterial
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"is_dot", args.get("dot", "0") == "1")
	# the Classic notes looks come with the classic mesh, as in the game
	if args.get("note-style", "2") != "2":
		note._set_mesh(note._classic)

## Sets up the notes' pools on a track at the hit plane, as BeepSaber_Game does, and drops what comes before
## `start_beat` (the song starts there; they would all fly in at once).
func _add_notes(start_beat: float) -> void:
	var track := Node3D.new()
	track.position.z = Constants.HIT_PLANE_Z
	add_child(track)
	for pool_name: StringName in NOTE_SCENES:
		var pool := POOL_SCENE.instantiate() as ScenePool
		pool.scene = NOTE_SCENES[pool_name]
		pool.new_scene_instanced.connect(func(obj: Node3D, _presizing: bool) -> void: track.add_child(obj))
		add_child(pool)
		GlobalReferences.set(pool_name, pool)
	for stack: Array in [Map.note_stack, Map.bomb_stack, Map.obstacle_stack]:
		while not stack.is_empty() and stack[-1].beat < start_beat:
			stack.pop_back()
	for stack: Array in [Map.arc_stack, Map.chain_stack]:
		while not stack.is_empty() and stack[-1].head_beat < start_beat:
			stack.pop_back()
	_notes = true

## The folder in the game's Songs folder named `name`, or else of the first song whose name contains it (any case).
func _find_song(name: String) -> String:
	var songs := Constants.APPDATA_PATH + "Songs/"
	if DirAccess.dir_exists_absolute(songs + name):
		return songs + name
	for folder in DirAccess.get_directories_at(songs):
		var info := Map.load_map_info(songs + folder + "/")
		if info and info.song_name.containsn(name):
			return songs + folder
	return songs + name

## The game scene's WorldEnvironment resource, read from the packed scene without instancing the game (XR and all).
func _game_environment() -> Environment:
	var state := (load(GAME_SCENE) as PackedScene).get_state()
	for node in state.get_node_count():
		if state.get_node_type(node) != &"WorldEnvironment":
			continue
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == &"environment":
				return state.get_node_property_value(node, i) as Environment
	push_warning("stage_capture: no WorldEnvironment in the game scene; using a plain one")
	return Environment.new()

## --key value pairs after the "--" on the command line.
func _args() -> Dictionary:
	var out := {}
	var user := OS.get_cmdline_user_args()
	for i in range(0, user.size() - 1, 2):
		out[user[i].trim_prefix("--")] = user[i + 1]
	return out
