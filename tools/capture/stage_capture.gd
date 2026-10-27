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
##   hardest)  --start 0 (seconds into the song)  --at 124.6 (capture when the song reaches this second)
##   --notes 1 (with --map: the map's notes, bombs, walls, arcs and chains fly in, spawned, timed and sped as in the game
##   (GameStatePlaying.spawn_due); nobody cuts them, so they pass and are missed, which costs nothing here; 0 leaves them out)
##   --note left|right (one note held still NOTE_AHEAD in front of the eye, to look at its shading; pair with
##   --seconds 600 to keep the window open)  --note-yaw 0 --note-pitch 0 (degrees, turn it to see its sides and top)
##   --wall 1 (with --map: the map's walls in the Classic walls look if --wall classic; otherwise a wall held still: WALL_SIZE, its near face --wall-z metres ahead of the eye (default 3; 0.5 to see the
##   near fade), --wall-x 0.6 to its centre's side; --wall classic for the Classic walls look)  --danger RRGGBB
##   --saber left|right (the default saber turned on, held --saber-dist metres in front of the eye, default 0.35, its
##   blade leaning away to the side, to look at it up close)
##   --bomb 1|classic (with --map: the map's bombs, classic = the two-mesh bomb; otherwise two bombs held still, one
##   --bomb-dist metres ahead (default 0.8) and one at play distance, 6 m)
##   --audit 1 (with --stats: what is drawn, grouped by where it sits in the tree, each visible mesh, MultiMesh or
##   particle system in view counted once, and every viewport that renders)
##   --classic-city 1 (Night City's classic layout instead of the building canyon)
##   --stats 1 (print the frame's triangles, draw calls and objects as drawn, RenderingServer's counters, one view)
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
	&"cube_pool": preload("res://game/notes/BeepCube/BeepCube.tscn"),
	&"link_pool": preload("res://game/notes/Chain/ChainLink.tscn"),
	&"bomb_pool": preload("res://game/notes/Bomb/Bomb.tscn"),
	&"wall_pool": preload("res://game/notes/Wall/Wall.tscn"),
	&"arc_pool": preload("res://game/notes/Arc/Arc.tscn"),
}
var _notes := false
const NOTE_SCENE := preload("res://game/notes/BeepCube/BeepCube.tscn")
const BOMB_SCENE := preload("res://game/notes/Bomb/Bomb.tscn")
const SABER_SCENE := preload("res://game/sabers/default/default_saber.tscn")
## --wall: the held wall's size (metres)
const WALL_SIZE := Vector3(1.2, 1.6, 3.0)
const WALL_SCENE := preload("res://game/notes/Wall/Wall.tscn")
## --note: how far in front of the eye the note is held, metres
const NOTE_AHEAD := 0.9

func _ready() -> void:
	var args := _args()
	var size := (args.get("size", "1920x1080") as String).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	var left := Color(args.get("left", Settings.color_left.to_html(false)) as String)
	var right := Color(args.get("right", Settings.color_right.to_html(false)) as String)
	RenderingServer.global_shader_parameter_set(&"left_saber_color", left)
	RenderingServer.global_shader_parameter_set(&"right_saber_color", right)
	RenderingServer.global_shader_parameter_set(&"note_style", int(args.get("note-style", "2")))

	# Night City's classic layout (in memory only; the saved setting is left alone)
	Settings.classic_night_city = args.get("classic-city", "0") == "1"
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
	# the Classic walls look for the map's walls too (in memory only; the saved setting is left alone)
	Settings.classic_walls = args.get("wall", "") == "classic"
	if args.has("wall") and not args.has("map"):
		_hold_wall(camera, args)
	Bomb.classic = args.get("bomb", "") == "classic"
	(Bomb.MERGED_MATERIAL as ShaderMaterial).set_shader_parameter(&"danger_color", Color(args.get("danger", "ff3030") as String))
	(load("res://game/notes/Bomb/bomb_glow.tres") as ShaderMaterial).set_shader_parameter(&"danger_color", Color(args.get("danger", "ff3030") as String))
	if args.has("bomb") and not args.has("map"):
		for z: float in [float(args.get("bomb-dist", "0.8")), 6.0]:
			var bomb := BOMB_SCENE.instantiate() as Bomb
			add_child(bomb)
			bomb.position = camera.position + Vector3(0.0 if z < 2.0 else 0.6, -0.15, -z)
			# where its fly-in ends (Bomb.tscn starts it small and further out)
			var anim := bomb.get_node(^"AnimationPlayer") as AnimationPlayer
			anim.play(&"Spawn")
			anim.seek(anim.current_animation_length, true)
			anim.pause()
	if args.has("saber"):
		_hold_saber(camera, left if args["saber"] == "left" else right, float(args.get("saber-dist", "0.35")))
	if args.has("note"):
		_hold_note(camera, left if args["note"] == "left" else right, args)
	if args.has("map") and not _play_map(stage, args):
		get_tree().quit(1)
		return

	if _song and args.has("at"):
		# the song's own clock, so the moment doesn't drift with load time
		while _song.playing and _song.get_playback_position() < float(args["at"]):
			await get_tree().process_frame
	elif _song and not args.has("seconds"):
		await _song.finished
	else:
		await get_tree().create_timer(float(args.get("seconds", "2.5"))).timeout
	await RenderingServer.frame_post_draw
	if args.get("stats", "0") == "1":
		var vp := get_viewport().get_viewport_rid()
		var info := func(kind: RenderingServer.ViewportRenderInfo) -> int:
			return RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, kind)
		print("stage_capture stats: %d triangles, %d draw calls, %d objects" % [
			info.call(RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
			info.call(RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			info.call(RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)])
		var walls := get_tree().get_nodes_in_group(&"wall").filter(func(w: Node) -> bool: return w is Wall and w.is_visible_in_tree())
		var seen := walls.filter(func(w: Wall) -> bool:
			var mesh := w.get_node(^"WallMeshOrientation/WallMesh") as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			for i in 8:
				if camera.is_position_in_frustum(box.get_endpoint(i)):
					return true
			return false)
		print("stage_capture walls: %d spawned, %d in view" % [walls.size(), seen.size()])
		if args.get("audit", "0") == "1":
			_audit(camera)
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

## Turns on one saber `distance` in front of `camera` in `color`, its hilt low and its blade leaning up and away.
func _hold_saber(camera: Camera3D, color: Color, distance: float) -> void:
	var saber := SABER_SCENE.instantiate() as DefaultSaber
	add_child(saber)
	saber.position = camera.position + Vector3(0.08, -0.25, -distance)
	saber.rotation_degrees = Vector3(-50.0, 0.0, -25.0)
	saber.set_color(color)
	saber._show()

## Prints the drawn instances in view of `camera`, grouped by the first two names of their path under this node, the
## material's shader where it tells more, and every viewport and how often it renders.
func _audit(camera: Camera3D) -> void:
	var groups := {}
	for node: Node in find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		# culled only when all its box's corners lie outside one of the frustum's planes
		var local := g.custom_aabb if g.custom_aabb.has_volume() else g.get_aabb()
		var box := g.global_transform * local.grow(g.extra_cull_margin)
		var culled := false
		for plane: Plane in camera.get_frustum():
			var outside := 0
			for i in 8:
				if plane.is_point_over(box.get_endpoint(i)):
					outside += 1
			if outside == 8:
				culled = true
				break
		if culled:
			groups["(culled) " + String(get_path_to(g)).get_slice("/", 0) + "/" + String(get_path_to(g)).get_slice("/", 1) + "/" + String(get_path_to(g)).get_slice("/", 2)] = groups.get("(culled) " + String(get_path_to(g)).get_slice("/", 0) + "/" + String(get_path_to(g)).get_slice("/", 1) + "/" + String(get_path_to(g)).get_slice("/", 2), 0) + 1
			continue
		if g is MeshInstance3D and (g as MeshInstance3D).mesh == null:
			continue
		var path := String(get_path_to(g)).split("/")
		var key := path[0] if not path[0].begins_with("@") else "(spawned)"
		if path.size() > 2 and path[0] == "event_driver":
			key += "/" + path[1] + "/" + path[2]
		var shader := ""
		var material := g.material_override as ShaderMaterial
		if material and material.shader:
			shader = material.shader.resource_path.get_file()
		key += " [%s %s]" % [g.get_class(), shader]
		groups[key] = groups.get(key, 0) + 1
	var keys := groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a] > groups[b])
	for key: String in keys:
		print("audit %4d  %s" % [groups[key], key])
	for vp: Node in get_tree().root.find_children("*", "SubViewport", true, false):
		var sub := vp as SubViewport
		print("audit viewport %s: update mode %d, size %s" % [get_path_to(sub), sub.render_target_update_mode, sub.size])

## Puts one wall (the game's own) in front of `camera` as --wall says. Without a map it doesn't move.
func _hold_wall(camera: Camera3D, args: Dictionary) -> void:
	var wall := WALL_SCENE.instantiate() as Wall
	add_child(wall)
	var mesh := wall.get_node(^"WallMeshOrientation/WallMesh") as MeshInstance3D
	var danger := Color(args.get("danger", "ff3030") as String)
	if args["wall"] == "classic":
		(mesh.mesh as BoxMesh).size = WALL_SIZE
		mesh.material_override = Wall.CLASSIC_MATERIAL
	else:
		mesh.mesh = Wall.frame_mesh()
		mesh.material_override = Wall.FRAMED_MATERIAL
		mesh.scale = WALL_SIZE
	(mesh.material_override as ShaderMaterial).set_shader_parameter(&"danger_color", danger)
	wall.position = Vector3(float(args.get("wall-x", "0.6")), WALL_SIZE.y * 0.5,
		camera.position.z - float(args.get("wall-z", "3")) - WALL_SIZE.z * 0.5)

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
	for stack: Array in [Map.note_stack, Map.bomb_stack]:
		while not stack.is_empty() and stack[-1].beat < start_beat:
			stack.pop_back()
	# a wall that began earlier but still runs past the start is kept: it spawns part way through, as in the game
	Map.obstacle_stack = Map.obstacle_stack.filter(func(w: ObstacleInfo) -> bool: return w.beat + w.duration >= start_beat)
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
