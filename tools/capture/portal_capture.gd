extends Node3D
## Renders a portal in a stand-in room wall from the player's eye, to judge the mixed-reality portal rim
## (game/env/PortalRim.gdshader) and, with --world, the scene behind it, on the desktop. The grey wall stands in for
## the camera's view of the real room; the headset stays the final check.
## Run (a window opens for a moment; headless can't render; under xvfb add Godot's --resolution WxH):
##   godot --path . res://tools/capture/portal_capture.tscn -- --out /tmp/portal.png [options]
## Options: --portal 1.6x1.4 (width x height, m)  --wall 2.5 (m ahead of the eye)
##   --centre 1.5 (the portal's centre height, m)  --eye 1.6  --yaw 0 --pitch 0 (degrees)  --fov 90 (vertical)
##   --color RRGGBB (the rim's light colour)  --world res://path.tscn (a scene placed behind the wall, root at the
##   origin; default a dark backdrop)  --size 1280x720  --seconds 0.5

const RIM_SHADER := preload("res://game/env/PortalRim.gdshader")
## the stand-in wall: its colour (a mid grey like a lit room through the cameras), how far it reaches each way and how
## thick it is (m)
const WALL_GREY := Color(0.42, 0.41, 0.4)
const WALL_REACH := 12.0
const WALL_THICK := 0.12
## the default backdrop behind the wall, and how far behind the wall it hangs (m)
const BACKDROP := Color(0.02, 0.02, 0.03)
const BACKDROP_BEHIND := 400.0
## the rim sits this far in front of the wall's face so it never fights it (m)
const RIM_LIFT := 0.002

## Builds the room, the portal and the camera from the command line, waits, saves the frame and quits.
func _ready() -> void:
	var args := {}
	var raw := OS.get_cmdline_user_args()
	for i in range(0, raw.size() - 1, 2):
		args[raw[i].trim_prefix("--")] = raw[i + 1]
	var portal := _pair(args.get("portal", "1.6x1.4"))
	var wall_z := -float(args.get("wall", "2.5"))
	var centre := float(args.get("centre", "1.5"))
	_build_wall(portal, wall_z, centre)
	var rim := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	rim.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = RIM_SHADER
	material.set_shader_parameter(&"portal_size_m", portal)
	material.set_shader_parameter(&"light_color", Color(args.get("color", "ffffff")))
	rim.material_override = material
	rim.position = Vector3(0.0, centre, wall_z + WALL_THICK * 0.5 + RIM_LIFT)
	add_child(rim)
	if args.has("world"):
		add_child((load(args["world"]) as PackedScene).instantiate())
	else:
		var backdrop := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2.ONE * BACKDROP_BEHIND * 4.0
		backdrop.mesh = plane
		backdrop.material_override = _flat(BACKDROP)
		backdrop.position = Vector3(0.0, 0.0, wall_z - BACKDROP_BEHIND)
		add_child(backdrop)
	var camera := Camera3D.new()
	camera.fov = float(args.get("fov", "90"))
	camera.far = BACKDROP_BEHIND * 3.0
	camera.position = Vector3(0.0, float(args.get("eye", "1.6")), 0.0)
	camera.rotation_degrees = Vector3(float(args.get("pitch", "0")), float(args.get("yaw", "0")), 0.0)
	add_child(camera)
	var size := _pair(args.get("size", "1280x720"))
	get_window().size = Vector2i(size)
	await get_tree().create_timer(float(args.get("seconds", "0.5"))).timeout
	await RenderingServer.frame_post_draw
	var out: String = args.get("out", "user://portal_capture.png")
	var error := get_viewport().get_texture().get_image().save_png(out)
	print("portal_capture %s -> %s" % ["OK" if error == OK else "FAILED", out])
	get_tree().quit(0 if error == OK else 1)

## The wall round the hole: four boxes and the floor, the hole `portal` wide and high, its centre `centre` up, the wall's face at z.
func _build_wall(portal: Vector2, z: float, centre: float) -> void:
	var half := portal * 0.5
	var boxes := [
		[Vector3(0.0, (centre - half.y) * 0.5, z), Vector3(WALL_REACH * 2.0, centre - half.y, WALL_THICK)],
		[Vector3(0.0, (centre + half.y + WALL_REACH) * 0.5, z), Vector3(WALL_REACH * 2.0, WALL_REACH - centre - half.y, WALL_THICK)],
		[Vector3(-(half.x + WALL_REACH) * 0.5, centre, z), Vector3(WALL_REACH - half.x, portal.y, WALL_THICK)],
		[Vector3((half.x + WALL_REACH) * 0.5, centre, z), Vector3(WALL_REACH - half.x, portal.y, WALL_THICK)],
	]
	# the room's floor, from the wall back past the eye
	boxes.append([Vector3(0.0, -WALL_THICK * 0.5, z * 0.5 + WALL_REACH * 0.5), Vector3(WALL_REACH * 2.0, WALL_THICK, WALL_REACH - z)])
	for box in boxes:
		var mesh := BoxMesh.new()
		mesh.size = box[1]
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _flat(WALL_GREY)
		instance.position = box[0]
		add_child(instance)

## An unshaded material of one colour.
func _flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

## "AxB" as a Vector2.
func _pair(text: String) -> Vector2:
	var parts := text.split("x")
	return Vector2(float(parts[0]), float(parts[1]))
