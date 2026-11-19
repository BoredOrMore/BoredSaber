extends Node
# Headless checks for MRPortal: the portal floating ahead in mixed reality, grown to the map's objects, the portals of a
# 90/360 map, and the portal mask's transform.
# Run: godot --headless --path . res://tests/test_mr_portal.tscn

var failures := 0

## Records one check.
func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## Runs every check and quits with the failure count.
func _ready() -> void:
	var floating := MRPortal.floating_portal(Vector3(0, 0, 1), Vector3(0, -0.3, -2))
	var floating_place := floating["transform"] as Transform3D
	check(floating_place.origin.is_equal_approx(Vector3(0, MRPortal.FLOATING_PORTAL_HEIGHT / 2.0, 1.0 - MRPortal.FLOATING_PORTAL_DISTANCE)),
		"floating portal ahead, standing on the floor: %s" % floating_place.origin)
	check(floating_place.basis.z.is_equal_approx(Vector3(0, 0, -1)) and floating_place.basis.determinant() > 0.0,
		"floating portal faces out along the track, level")
	var floating_size := floating["size"] as Vector2
	check(floating_size.x >= MRPortal.note_corridor().x and floating_size.x / 2.0 >= 2.0 * Settings.LANE_DISTANCE_X
		+ TrackDeck.EDGE_REACH and floating_size.y == MRPortal.FLOATING_PORTAL_HEIGHT,
		"floating portal spans the curbs and the floor to %.1f m: %s" % [MRPortal.FLOATING_PORTAL_HEIGHT, floating_size])
	# the map's objects: a note in the bottom-left lane and a wall far out on the right, from the floor to the top
	Map.note_stack = [ColorNoteInfo.new(1.0, 0, 0, 0, 0, 0)]
	Map.obstacle_stack = [ObstacleInfo.new(2.0, 1.0, 5, 0, 2, 5, 0)]
	Map.bomb_stack = []
	Map.chain_stack = []
	Map.arc_stack = []
	var extent := MRPortal.map_extent()
	var wall_right := 5.0 * Settings.LANE_DISTANCE_X + MRPortal.FLOATING_PORTAL_WALL_MARGIN
	check(is_equal_approx(extent.end.x, wall_right) and is_equal_approx(extent.end.y, Constants.wall_y(5.0)
		+ MRPortal.FLOATING_PORTAL_WALL_MARGIN) and is_equal_approx(extent.position.x, Settings.LANE_ZERO_X
		- MRPortal.PORTAL_NOTE_REACH), "the map's box spans the note and the wall: %s" % extent)
	var grown := MRPortal.floating_portal(Vector3(0, 0, 1), Vector3(0, 0, -1), extent)
	var grown_size := grown["size"] as Vector2
	check(is_equal_approx(grown_size.x / 2.0, wall_right) and grown_size.y >= extent.end.y
		and is_equal_approx((grown["transform"] as Transform3D).origin.y, grown_size.y / 2.0),
		"the floating portal grows to take the map, centred on the track and standing on the floor: %s" % grown_size)
	check(MRPortal.map_turns().is_empty(), "a map whose lanes don't turn keeps the one portal ahead")
	# a 90/360 map: a note ahead, then a wall turned 90° to the right, held for 4 beats
	Map.note_stack = [ColorNoteInfo.new(3.0, 1, 0, 0, 0, 0)]
	Map.obstacle_stack = [ObstacleInfo.new(1.0, 4.0, 0, 0, 1, 5, 90)]
	var turns := MRPortal.map_turns()
	check(turns.size() == 2 and turns[0][0] == 1.0 and turns[0][1] == 5.0 and is_equal_approx(turns[0][2], PI / 2.0)
		and turns[1][2] == 0.0, "a turning map's objects in beat order, a wall until its end: %s" % [turns])
	Map.note_stack = []
	Map.obstacle_stack = []
	var near := MRPortal.turn_portals([0.0, deg_to_rad(15.0), deg_to_rad(90.0)], 4)
	check(near.size() == 2 and is_equal_approx(near[0].x, deg_to_rad(7.5)) and is_equal_approx(near[0].y, deg_to_rad(7.5))
		and is_equal_approx(near[1].x, deg_to_rad(90.0)), "directions within 30° share a portal: %s" % [near])
	var wrapped := MRPortal.turn_portals([deg_to_rad(350.0), deg_to_rad(10.0)], 4)
	check(wrapped.size() == 1 and absf(angle_difference(wrapped[0].x, 0.0)) < 0.001
		and is_equal_approx(wrapped[0].y, deg_to_rad(10.0)), "a portal across 0° isn't split: %s" % [wrapped])
	var many := MRPortal.turn_portals([0.0, PI / 3.0, 2.0 * PI / 3.0, PI, 4.0 * PI / 3.0, 5.0 * PI / 3.0], 4)
	check(many.size() == 4, "never more portals than the mask takes: %s" % [many])
	var spread := MRPortal.floating_portal(Vector3(0, 0, 1), Vector3(0, 0, -1), Rect2(), deg_to_rad(15.0))
	check(is_equal_approx((spread["size"] as Vector2).x - floating_size.x,
		2.0 * MRPortal.FLOATING_PORTAL_DISTANCE * tan(deg_to_rad(15.0))),
		"a shared portal widens to take lanes 15° either way: %s" % spread["size"])
	var mask := MRPortal.portal_mask_transform(floating_place, floating_size)
	var corner := mask * (floating_place * Vector3(floating_size.x / 2, floating_size.y / 2, 0))
	check(corner.distance_to(Vector3(0.5, 0.5, 0)) < 0.001, "the mask maps the portal's corner to (0.5, 0.5, 0)")
	check((mask * Vector3.ZERO).z < 0.0, "the player is on the room side (z < 0) of the mask")
	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
