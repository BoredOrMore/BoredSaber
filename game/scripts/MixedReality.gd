extends Node

## A room scan found the real room: PicoRoom's pieces (walls, floor, furniture) in the XROrigin3D's space.
signal room_found(pieces: Array)
## A room scan found no room.
signal room_missing()

## The rim round each portal, and the world seen through the portals.
const PORTAL_RIM_SHADER := preload("res://game/env/PortalRim.gdshader")
const MR_SPACE_SCENE := preload("res://game/env/MRSpace.tscn")
## How many portals the mask shader takes (portal_mask.gdshaderinc's mr_portal_0..3).
const MAX_PORTALS := 4
## The room scan and its setup panel stay in the code but are off for now (Bored, 2026-11-03): mixed reality opens a
## portal floating in front of the player instead (RoomOutline.floating_portal).
const ROOM_SCAN_ENABLED := false
## How long a 90/360 map's portal takes to grow from its centre when objects start coming from its direction, and to
## shrink back once they have passed (Bored, 2026-11-03: grows from the centre). UNTUNED.
const PORTAL_OPEN_SECONDS := 0.5

var floor_albedo_texture : Texture2D = null
## The real room's outline, made on the first room scan (PICO headsets only).
var _room_outline: RoomOutline = null
## The last scanned room's pieces, or empty.
var _room_pieces: Array = []
## Whether the outline should show when there is a room.
var _outline_shown := false
## One rim per portal, children of XROrigin3D like the room's poses.
var _portal_rims: Array[MeshInstance3D] = []
## The world behind the portals, made with the first portal.
var _space: MRSpace = null
## The loaded map's objects' box (RoomOutline.map_extent), which the floating portal grows to take.
var _map_extent := Rect2()
## A 90/360 map's objects as RoomOutline.map_turns gives them, the index of the next one not yet counted, and the
## counted ones still to pass the player; empty on a map whose lanes don't turn.
var _turns := []
var _next_turn := 0
var _coming := []
## The beat follow_map last saw, to notice a practice run jumping back.
var _last_beat := 0.0
## The open portals while a 90/360 map plays: each {"angle", "spread" (radians), "open" (0 shut to 1 open), "wanted"}.
var _turn_portals: Array[Dictionary] = []


func _ready() -> void:
	set_process(false)


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

	# the platform under the player (its floor and border bars) takes room space: in mixed reality the room shows only the
	# track's two light strips (Bored, 2026-11-03)
	(cut_floor.get_parent() as Node3D).visible = not mr
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
	if mr and ROOM_SCAN_ENABLED and can_scan_room():
		(get_node("/root/BeepSaber") as BeepSaber_Game).open_room_setup()
	elif mr:
		_show_floating_portal()


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


## Drops the scanned room, its outline and its portals.
func _forget_room() -> void:
	_room_pieces = []
	show_room_outline(false)
	_show_portals([])


## Cuts `portals` (RoomOutline.find_portal results, in XROrigin3D's space) into the real walls: a rim round each, and
## the world behind showing only through them; an empty list closes them all, so stages outside mixed reality draw whole.
func _show_portals(portals: Array) -> void:
	assert(portals.size() <= MAX_PORTALS, "the portal mask takes %d portals" % MAX_PORTALS)
	RenderingServer.global_shader_parameter_set(&"mr_portal_count", portals.size())
	if portals.is_empty():
		for rim in _portal_rims:
			rim.hide()
		if _space:
			_space.hide()
		return
	var origin := get_node("/root/BeepSaber/XROrigin3D") as XROrigin3D
	# UNTUNED: the rim takes the right note colour; the map's lights should drive it once the portal is seen on the headset
	var light := (get_node("/root/BeepSaber/event_driver") as EventDriver).right_color
	for i in MAX_PORTALS:
		if i >= portals.size():
			if i < _portal_rims.size():
				_portal_rims[i].hide()
			continue
		if i >= _portal_rims.size():
			var rim := MeshInstance3D.new()
			rim.mesh = QuadMesh.new()
			var material := ShaderMaterial.new()
			material.shader = PORTAL_RIM_SHADER
			# first among the see-through things, so the HUD and menus in front always draw over its glow
			material.render_priority = Material.RENDER_PRIORITY_MIN
			rim.material_override = material
			rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			origin.add_child(rim)
			_portal_rims.append(rim)
		var place := portals[i]["transform"] as Transform3D
		var size := portals[i]["size"] as Vector2
		var rim := _portal_rims[i]
		rim.transform = place
		rim.show()
		var rim_material := rim.material_override as ShaderMaterial
		rim_material.set_shader_parameter(&"portal_size_m", size)
		rim_material.set_shader_parameter(&"light_color", light)
		RenderingServer.global_shader_parameter_set(StringName("mr_portal_%d" % i),
			RoomOutline.portal_mask_transform(origin.global_transform * place, size))
	if _space == null:
		_space = MR_SPACE_SCENE.instantiate() as MRSpace
		get_node("/root/BeepSaber").add_child(_space)
	_space.show()


## Opens the portal floating ahead of the player along the track, for when there is no room scan.
func _show_floating_portal() -> void:
	var origin := get_node("/root/BeepSaber/XROrigin3D") as XROrigin3D
	var spot := origin.to_local(Vector3(0, 0, Constants.PLAYER_Z))
	_show_portals([RoomOutline.floating_portal(spot, origin.global_basis.inverse() * Vector3.FORWARD, _map_extent)])


## Grows the floating portal to take every object of the map just loaded (BeepSaber_Game._start_map), so none comes in
## beside it (Bored, 2026-11-03).
func fit_portal_to_map() -> void:
	_map_extent = RoomOutline.map_extent()
	_turns = RoomOutline.map_turns()
	_next_turn = 0
	_coming = []
	_last_beat = 0.0
	if Settings.mixed_reality and not ROOM_SCAN_ENABLED:
		_show_floating_portal()


## While a 90/360 map plays (GameStatePlaying, each frame at `current_beat`), opens a portal toward each direction its
## objects are coming from, from just before the first of them flies in until the last has passed the player (Bored,
## 2026-11-03); a map whose lanes don't turn keeps its one portal ahead.
func follow_map(current_beat: float) -> void:
	if _turns.is_empty() or not Settings.mixed_reality or ROOM_SCAN_ENABLED:
		return
	if not is_processing():
		# the one portal ahead becomes the first of them, closing unless objects come from ahead
		_turn_portals = [{"angle": 0.0, "spread": 0.0, "open": 1.0, "wanted": false}]
	if current_beat < _last_beat:
		_next_turn = 0
		_coming = []
	_last_beat = current_beat
	# as Playing.spawn_due's look-ahead, plus the time the portal takes to open
	var horizon := current_beat + Map.half_jump_beats + (Cuttable.FLY_SECONDS + PORTAL_OPEN_SECONDS) \
		* Map.beats_per_second()
	while _next_turn < _turns.size() and _turns[_next_turn][0] <= horizon:
		_coming.append(_turns[_next_turn])
		_next_turn += 1
	_coming = _coming.filter(func(turn: Array) -> bool: return turn[1] >= current_beat)
	var wanted := RoomOutline.turn_portals(_coming.map(func(turn: Array) -> float: return turn[2]), MAX_PORTALS)
	for portal in _turn_portals:
		portal["wanted"] = false
	for want in wanted:
		var match_index := -1
		for i in _turn_portals.size():
			var gap := absf(angle_difference(_turn_portals[i]["angle"], want.x))
			if not _turn_portals[i]["wanted"] and gap <= RoomOutline.PORTAL_TURN_MERGE \
					and (match_index < 0 or gap < absf(angle_difference(_turn_portals[match_index]["angle"], want.x))):
				match_index = i
		if match_index < 0:
			# a new direction takes the place of the most shut portal still closing
			if _turn_portals.size() >= MAX_PORTALS:
				var shut := -1
				for i in _turn_portals.size():
					if not _turn_portals[i]["wanted"] and (shut < 0 or _turn_portals[i]["open"] < _turn_portals[shut]["open"]):
						shut = i
				_turn_portals.remove_at(shut)
			_turn_portals.append({"angle": want.x, "spread": want.y, "open": 0.0, "wanted": true})
		else:
			_turn_portals[match_index].merge({"angle": want.x, "spread": want.y, "wanted": true}, true)
	set_process(true)


## Grows and shrinks a 90/360 map's portals (follow_map) and draws them; back to the one portal ahead once none is open.
func _process(delta: float) -> void:
	var step := delta / PORTAL_OPEN_SECONDS
	for portal in _turn_portals:
		portal["open"] = clampf(portal["open"] + (step if portal["wanted"] else -step), 0.0, 1.0)
	_turn_portals = _turn_portals.filter(func(portal: Dictionary) -> bool: return portal["wanted"] or portal["open"] > 0.0)
	_show_turn_portals()


## Draws a 90/360 map's portals, each grown from its centre by how open it is.
func _show_turn_portals() -> void:
	var origin := get_node("/root/BeepSaber/XROrigin3D") as XROrigin3D
	var portals := []
	for portal in _turn_portals:
		var open := ease(portal["open"], -2.0)
		if open <= 0.0:
			continue
		var angle: float = portal["angle"]
		# a lane turned `angle` about the player's standing point (Cuttable.add_lane_rotation) comes in from this way
		var inward := Vector3(sin(angle), 0.0, -cos(angle))
		var spot := Vector3(0.0, 0.0, Constants.LANE_PIVOT_Z) - inward * (Constants.PLAYER_Z - Constants.LANE_PIVOT_Z)
		var place := RoomOutline.floating_portal(origin.to_local(spot), origin.global_basis.inverse() * inward,
			_map_extent, portal["spread"])
		place["size"] = (place["size"] as Vector2) * open
		portals.append(place)
	_show_portals(portals)


## Puts the one portal ahead back when a 90/360 map stops playing (BeepSaber_Game._transition_game_state).
func stop_following_map() -> void:
	if not is_processing():
		return
	set_process(false)
	_turn_portals.clear()
	if Settings.mixed_reality and not ROOM_SCAN_ENABLED:
		_show_floating_portal()


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
	var direction := origin.global_basis.inverse() * Vector3.FORWARD
	_room_outline.show_room(pieces, spot, direction)
	show_room_outline(_outline_shown)
	var portal := RoomOutline.find_portal(pieces, spot, direction)
	_show_portals([] if portal.is_empty() else [portal])
	room_found.emit(pieces)


## Reads the room again after a recenter, which moves the play space the room's poses are in.
func _on_recentered() -> void:
	if Settings.mixed_reality and not _room_pieces.is_empty():
		Engine.get_singleton("PicoRoom").call("reload_room")


## Puts the floating portal back in front of the track after BeepSaber_Game.recenter moved the play space (its rim
## rides on XROrigin3D, its mask is in world space); the game recenters at start and from Settings, not only on the
## headset's recenter. A 90/360 map's portals redraw each frame anyway.
func play_space_moved() -> void:
	if Settings.mixed_reality and not ROOM_SCAN_ENABLED and not is_processing():
		_show_floating_portal()


## Tells the room setup that no room was found.
func _on_room_not_found() -> void:
	_forget_room()
	room_missing.emit()
