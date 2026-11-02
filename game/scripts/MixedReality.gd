extends Node

var floor_albedo_texture : Texture2D = null
## The real room's outline, made on the first room scan (PICO headsets only).
var _room_outline: RoomOutline = null


## Turns passthrough and the see-through floor on or off; turning it on scans the real room.
func set_mixed_reality(mr: bool):
	var xr_interface := XRServer.find_interface("OpenXR") as XRInterface
	if xr_interface and xr_interface.is_passthrough_supported():
		if mr:
			if xr_interface.start_passthrough():
				get_viewport().transparent_bg = true
				xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
				print("BeepSaber: MR")
		else:
			xr_interface.stop_passthrough()
			get_viewport().transparent_bg = false
			xr_interface.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
			
			
	var cut_floor := get_node("/root/BeepSaber/StandingGround/Node3D/cutFloor") as MeshInstance3D
	var material := cut_floor.material_override as StandardMaterial3D
	
	if floor_albedo_texture == null:
		floor_albedo_texture = material.albedo_texture

	if mr:
		material.transparency = 1
		material.albedo_texture = null
		material.albedo_color = Color(0,0,0,.6)
		get_node("/root/BeepSaber/event_driver/Level/Sphere").hide()
	else:
		material.transparency = 0
		material.albedo_texture = floor_albedo_texture
		get_node("/root/BeepSaber/event_driver/Level/Sphere").show()
	
	(get_node("/root/BeepSaber/event_driver") as EventDriver).show_scenery_for_mixed_reality()
	material = (get_node("/root/BeepSaber/event_driver/Level/TrackTurn/floor") as MeshInstance3D).material_override as StandardMaterial3D
	var gradient_texture := material.albedo_texture as GradientTexture2D
	var gradient := gradient_texture.gradient
	for i in gradient.get_point_count():
		var c := gradient.get_color(i)
		if Settings.mixed_reality:
			gradient.set_color(i, Color(c.r,c.g,c.b,0.6))
		else:
			gradient.set_color(i, Color(c.r,c.g,c.b))

	_scan_room(mr)


## Opens PICO's room scan when mixed reality turns on (Bored, 2026-11-02: every time), and hides the room's outline
## when it turns off. Headsets without PICO's room functions skip it.
func _scan_room(mr: bool) -> void:
	if _room_outline:
		_room_outline.visible = false
	if not mr or not Engine.has_singleton("PicoRoom"):
		return
	var room := Engine.get_singleton("PicoRoom")
	if not room.call("is_supported"):
		return
	if not room.is_connected("room_loaded", _on_room_loaded):
		room.connect("room_loaded", _on_room_loaded)
		room.connect("room_not_found", _on_room_not_found)
	room.call("scan_room")


## Draws the scanned room over the passthrough.
func _on_room_loaded(pieces: Array) -> void:
	if not Settings.mixed_reality:
		return
	if _room_outline == null:
		_room_outline = RoomOutline.new()
		get_node("/root/BeepSaber/XROrigin3D").add_child(_room_outline)
	_room_outline.show_room(pieces)


## Notes a scan that found no room (the room setup screen will offer to scan again).
func _on_room_not_found() -> void:
	print("PicoRoom: no room found")
