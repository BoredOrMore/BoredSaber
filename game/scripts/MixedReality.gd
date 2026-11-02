extends Node

## A room scan found the real room: PicoRoom's pieces (walls, floor, furniture) in the XROrigin3D's space.
signal room_found(pieces: Array)
## A room scan found no room.
signal room_missing()

var floor_albedo_texture : Texture2D = null
## The real room's outline, made on the first room scan (PICO headsets only).
var _room_outline: RoomOutline = null
## The last scanned room's pieces, or empty.
var _room_pieces: Array = []
## Whether the outline should show when there is a room.
var _outline_shown := false


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

	_forget_room()
	if mr and can_scan_room():
		(get_node("/root/BeepSaber") as BeepSaber_Game).open_room_setup()


## Returns whether this headset can scan the real room (PICO's room functions, through the PicoRoom plugin).
func can_scan_room() -> bool:
	return Engine.has_singleton("PicoRoom") and Engine.get_singleton("PicoRoom").call("is_supported")


## Opens PICO's room scan; ends in room_found or room_missing (Bored, 2026-11-02: every time mixed reality turns on).
func scan_room() -> void:
	var room := Engine.get_singleton("PicoRoom")
	if not room.is_connected("room_loaded", _on_room_loaded):
		room.connect("room_loaded", _on_room_loaded)
		room.connect("room_not_found", _on_room_not_found)
		vr.pose_recentered.connect(_on_recentered)
	_forget_room()
	room.call("scan_room")


## Shows or hides the room's outline (shown while the player checks the room).
func show_room_outline(shown: bool) -> void:
	_outline_shown = shown
	if _room_outline:
		_room_outline.visible = shown and not _room_pieces.is_empty()


## Drops the scanned room and its outline.
func _forget_room() -> void:
	_room_pieces = []
	show_room_outline(false)


## Keeps the scanned room and redraws its outline, with the portal where the track meets the wall.
func _on_room_loaded(pieces: Array) -> void:
	if not Settings.mixed_reality:
		return
	_room_pieces = pieces
	if _room_outline == null:
		_room_outline = RoomOutline.new()
		get_node("/root/BeepSaber/XROrigin3D").add_child(_room_outline)
	# the track runs along the scene's -z from the player's standing point; the room's poses are in the origin's space
	var origin := _room_outline.get_parent() as XROrigin3D
	var spot := origin.to_local(Vector3(0, 0, Constants.PLAYER_Z))
	_room_outline.show_room(pieces, spot, origin.global_basis.inverse() * Vector3.FORWARD)
	show_room_outline(_outline_shown)
	room_found.emit(pieces)


## Reads the room again after a recenter, which moves the play space the room's poses are in.
func _on_recentered() -> void:
	if Settings.mixed_reality and not _room_pieces.is_empty():
		Engine.get_singleton("PicoRoom").call("reload_room")


## Tells the room setup that no room was found.
func _on_room_not_found() -> void:
	_forget_room()
	room_missing.emit()
