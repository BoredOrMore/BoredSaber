extends Node
# Headless checks for RoomOutline.find_portal (where notes come in through the real room's wall), on the room read on
# the headset on 2026-11-02 (9dd67b0 log): five walls, the floor and a table, poses in the play space.
# Run: godot --headless --path . res://tests/test_room_outline.tscn

var failures := 0

## Records one check.
func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## Returns one piece as PicoRoom sends it, from the logged position and rotation (x, y, z, w).
func piece(label: int, pos: Vector3, rot: Quaternion, size: Vector3) -> Dictionary:
	return {"label": label, "transform": Transform3D(Basis(rot), pos), "size": size}

## The measured room.
func room() -> Array:
	return [
		piece(RoomOutline.LABEL_WALL, Vector3(-2.021, 1.248, -0.843), Quaternion(0, -0.71305, 0, 0.70112), Vector3(5.319, 2.635, 0)),
		piece(RoomOutline.LABEL_WALL, Vector3(0.333, 1.248, 1.634), Quaternion(0, 0.03800, 0, 0.99928), Vector3(4.812, 2.635, 0)),
		piece(RoomOutline.LABEL_WALL, Vector3(2.339, 1.248, 0.895), Quaternion(0, 0.88816, 0, 0.45954), Vector3(1.362, 2.635, 0)),
		piece(RoomOutline.LABEL_WALL, Vector3(1.640, 1.248, -1.746), Quaternion(0, 0.75664, 0, 0.65383), Vector3(4.215, 2.635, 0)),
		piece(RoomOutline.LABEL_WALL, Vector3(-0.321, 1.248, -3.667), Quaternion(0, 0.99877, 0, -0.04960), Vector3(3.327, 2.635, 0)),
		piece(RoomOutline.LABEL_FLOOR, Vector3(0.394, -0.070, -0.746), Quaternion(-0.51916, -0.48007, 0.48007, -0.51916), Vector3(1, 1, 0)),
		piece(RoomOutline.LABEL_FURNITURE, Vector3(-0.104, 0.681, -1.989), Quaternion(0.70707, 0.00701, -0.00701, 0.70707), Vector3(0.913, 3.263, 0.751)),
	]

## Runs every check and quits with the failure count.
func _ready() -> void:
	var portal := RoomOutline.find_portal(room(), Vector3.ZERO, Vector3(0, 0, -1))
	check(not portal.is_empty(), "a wall is ahead")
	var place := portal.get("transform", Transform3D()) as Transform3D
	check(absf(place.origin.z + 3.67) < 0.1, "portal on the front wall, 3.67 m ahead (got %.2f)" % place.origin.z)
	check(absf(place.origin.x) < 0.2, "portal straight ahead (x %.2f)" % place.origin.x)
	var size := portal.get("size", Vector2()) as Vector2
	check(size.x <= 3.327 and size.x >= 3.0 * Settings.LANE_DISTANCE_X + RoomOutline.PORTAL_NOTE_REACH * 2.0 - 0.001, "portal fits the 3.33 m wall (%.2f)" % size.x)
	var bottom := place.origin.y - size.y / 2
	var top := place.origin.y + size.y / 2
	check(bottom >= -0.08 and top <= 2.57, "portal between floor and ceiling (%.2f to %.2f)" % [bottom, top])
	var turned := RoomOutline.find_portal(room(), Vector3(0, 0, 0.5), Vector3(-1, 0.2, 0))
	check(absf((turned.get("transform", Transform3D()) as Transform3D).origin.x + 2.02) < 0.1,
		"facing left (path kept level), the portal is on the left wall")
	check(RoomOutline.find_portal(room(), Vector3.ZERO, Vector3(0, 0, 1)).get("transform", Transform3D()).origin.z > 1.5,
		"facing back, the portal is on the wall behind")
	check(RoomOutline.find_portal([], Vector3.ZERO, Vector3(0, 0, -1)).is_empty(), "no walls, no portal")
	var floating := RoomOutline.floating_portal(Vector3(0, 0, 1), Vector3(0, -0.3, -2))
	var floating_place := floating["transform"] as Transform3D
	check(floating_place.origin.is_equal_approx(Vector3(0, (Constants.ROW_Y[0] + Constants.ROW_Y[-1]) / 2.0, -2)),
		"floating portal 3 m ahead at the note rows' middle: %s" % floating_place.origin)
	check(floating_place.basis.z.is_equal_approx(Vector3(0, 0, -1)) and floating_place.basis.determinant() > 0.0,
		"floating portal faces out along the track, level")
	check(floating["size"] == RoomOutline.note_corridor(), "floating portal is corridor-sized")
	var mask := RoomOutline.portal_mask_transform(place, size)
	var corner := mask * (place * Vector3(size.x / 2, size.y / 2, 0))
	check(corner.distance_to(Vector3(0.5, 0.5, 0)) < 0.001, "the mask maps the portal's corner to (0.5, 0.5, 0)")
	check((mask * Vector3.ZERO).z < 0.0, "the player is on the room side (z < 0) of the mask")
	var outline := RoomOutline.new()
	add_child(outline)
	outline.show_room(room(), Vector3.ZERO, Vector3(0, 0, -1))
	check(outline.mesh.get_surface_count() == 1 and outline.visible, "outline drawn")
	outline.show_room([], Vector3.ZERO, Vector3(0, 0, -1))
	check(not outline.visible, "empty room hides the outline")
	print("FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
