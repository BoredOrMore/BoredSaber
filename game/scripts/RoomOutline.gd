class_name RoomOutline
extends MeshInstance3D
## Draws the player's real room (walls, doors, windows, furniture from `PicoRoom`) as thin lines over the passthrough,
## and the frame where notes will come in through the wall ahead. A child of `XROrigin3D`, whose space the room's
## poses are in.

## PicoRoom's labels (PICO's scene labels).
const LABEL_FLOOR := 1
const LABEL_CEILING := 2
const LABEL_WALL := 3
const LABEL_FURNITURE := 7
## UNTUNED placeholders until the portal is sized on the headset: the note path's height above the floor where it
## meets the wall, the share of the wall the frame may take, and its smallest and largest size in metres.
const PORTAL_PATH_HEIGHT := 1.0
const PORTAL_WALL_SHARE := 0.7
const PORTAL_MIN_SIZE := Vector2(1.2, 1.2)
const PORTAL_MAX_SIZE := Vector2(2.4, 2.0)
## Walls closer to parallel with the note path than this (the dot of their normal with it) can't take a portal.
const MIN_FACING := 0.3

var _mesh := ImmediateMesh.new()


## Sets up the line material.
func _ready() -> void:
	mesh = _mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material_override = material


## Draws `pieces` (PicoRoom's room_loaded list) and the portal frame where the track, from `spot` along
## `direction` (both in this node's space), meets a wall.
func show_room(pieces: Array, spot: Vector3, direction: Vector3) -> void:
	_mesh.clear_surfaces()
	visible = not pieces.is_empty()
	if pieces.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for piece: Dictionary in pieces:
		var label := piece["label"] as int
		var place := piece["transform"] as Transform3D
		var size := piece["size"] as Vector3
		if label == LABEL_FURNITURE:
			_add_box(place, size, Constants.UI_TEXT_MUTED)
		elif label != LABEL_FLOOR and label != LABEL_CEILING:
			# The floor and ceiling come as 1 m squares; the walls' edges outline them instead.
			_add_rect(place, Vector2(size.x, size.y), Constants.UI_TEXT)
	var portal := find_portal(pieces, spot, direction)
	if not portal.is_empty():
		_add_rect(portal["transform"] as Transform3D, portal["size"] as Vector2, Constants.UI_ACCENT)
	_mesh.surface_end()


## Returns the portal frame where the note path, from above `spot` on the floor along `direction` (kept level), meets
## the nearest wall: {"transform": its centre on the wall, "size": Vector2}, or {} when no wall is ahead.
static func find_portal(pieces: Array, spot: Vector3, direction: Vector3) -> Dictionary:
	direction = Vector3(direction.x, 0, direction.z).normalized()
	var floor_y := 0.0
	for piece: Dictionary in pieces:
		if piece["label"] == LABEL_FLOOR:
			floor_y = (piece["transform"] as Transform3D).origin.y
	var start := Vector3(spot.x, floor_y + PORTAL_PATH_HEIGHT, spot.z)
	var best := {}
	var best_distance := INF
	for piece: Dictionary in pieces:
		if piece["label"] != LABEL_WALL:
			continue
		var wall := piece["transform"] as Transform3D
		var normal := wall.basis.z.normalized()
		var facing := normal.dot(direction)
		if facing < MIN_FACING:
			continue
		var distance := normal.dot(wall.origin - start) / facing
		var hit := wall.affine_inverse() * (start + direction * distance)
		var wall_size := Vector2((piece["size"] as Vector3).x, (piece["size"] as Vector3).y)
		if distance <= 0.0 or distance >= best_distance or absf(hit.x) > wall_size.x / 2 or absf(hit.y) > wall_size.y / 2:
			continue
		var size := (wall_size * PORTAL_WALL_SHARE).clamp(PORTAL_MIN_SIZE, PORTAL_MAX_SIZE).min(wall_size)
		var room := (wall_size - size) / 2
		var centre := Vector3(clampf(hit.x, -room.x, room.x), clampf(hit.y, -room.y, room.y), 0)
		best = {"transform": wall.translated_local(centre), "size": size}
		best_distance = distance
	return best


## Adds a rectangle lying in `place`'s local XY, centred on it.
func _add_rect(place: Transform3D, size: Vector2, color: Color) -> void:
	var half := size / 2
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, 0), Vector3(half.x, -half.y, 0), Vector3(half.x, half.y, 0), Vector3(-half.x, half.y, 0)]
	for i in corners.size():
		_add_line(place * corners[i], place * corners[(i + 1) % corners.size()], color)


## Adds a box's twelve edges, centred on `place`.
func _add_box(place: Transform3D, size: Vector3, color: Color) -> void:
	var half := size / 2
	for axis in 3:
		var a := (axis + 1) % 3
		var b := (axis + 2) % 3
		for corner in 4:
			var from := Vector3()
			from[axis] = -half[axis]
			from[a] = half[a] if corner & 1 else -half[a]
			from[b] = half[b] if corner & 2 else -half[b]
			var to := from
			to[axis] = half[axis]
			_add_line(place * from, place * to, color)


## Adds one line.
func _add_line(from: Vector3, to: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(from)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(to)
