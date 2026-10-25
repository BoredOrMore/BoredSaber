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

const ENVIRONMENT_SCENE := preload("res://game/event_driver.tscn")
const FLOOR_SCENE := preload("res://game/floor.tscn")
const GAME_SCENE := "res://game/BeepSaber_Game.tscn"
## where the player stands (XROrigin3D)
const PLAYER := Vector3(0.0, 0.0, 1.0)

func _ready() -> void:
	var args := _args()
	var size := (args.get("size", "1920x1080") as String).split("x")
	DisplayServer.window_set_size(Vector2i(int(size[0]), int(size[1])))
	var left := Color(args.get("left", Settings.color_left.to_html(false)) as String)
	var right := Color(args.get("right", Settings.color_right.to_html(false)) as String)
	RenderingServer.global_shader_parameter_set(&"shadow_tint", Constants.SHADOW_TINT)
	RenderingServer.global_shader_parameter_set(&"left_saber_color", left)
	RenderingServer.global_shader_parameter_set(&"right_saber_color", right)

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

	await get_tree().create_timer(float(args.get("seconds", "2.5"))).timeout
	await RenderingServer.frame_post_draw
	var out := args.get("out", "user://stage_capture.png") as String
	var error := get_viewport().get_texture().get_image().save_png(out)
	print("stage_capture %s -> %s" % [error_string(error), out])
	get_tree().quit(0 if error == OK else 1)

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
