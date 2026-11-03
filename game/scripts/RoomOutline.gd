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
## UNTUNED placeholders until the portal is sized on the headset: how far past the outer lanes' and rows' centres the
## frame must reach so whole notes pass through it (Bored, 2026-11-03: notes came through the wall beside the frame),
## the share of the wall the frame may take, and its largest size in metres (never smaller than the notes' corridor).
const PORTAL_NOTE_REACH := 0.35
const PORTAL_WALL_SHARE := 0.7
const PORTAL_MAX_SIZE := Vector2(2.4, 2.0)
## Without a room scan (MixedReality.ROOM_SCAN_ENABLED off) the portal floats this far ahead of the player's standing
## point (Bored, 2026-11-03: first 3 m, then 6 m, then 10 m).
const FLOATING_PORTAL_DISTANCE := 10.0
## The floating portal reaches from the floor this high, and across the track's curbs, so walls (from the floor up),
## arcs (which bulge past the note rows) and bombs come in through its hole, not beside it (Bored, 2026-11-03). UNTUNED.
const FLOATING_PORTAL_HEIGHT := 3.0
## When a song starts the floating portal grows to take every object of the map (map_extent), with this much room round
## a wall's edges (Bored, 2026-11-03: "always big enough for all objects to pass"). UNTUNED.
const FLOATING_PORTAL_WALL_MARGIN := 0.1
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
	var corridor := note_corridor()
	var start := Vector3(spot.x, floor_y + (Constants.ROW_Y[0] + Constants.ROW_Y[-1]) / 2.0, spot.z)
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
		var size := (wall_size * PORTAL_WALL_SHARE).clamp(corridor, PORTAL_MAX_SIZE.max(corridor)).min(wall_size)
		var room := (wall_size - size) / 2
		var centre := Vector3(clampf(hit.x, -room.x, room.x), clampf(hit.y, -room.y, room.y), 0)
		best = {"transform": wall.translated_local(centre), "size": size}
		best_distance = distance
	return best


## Returns the size of the notes' corridor: four lanes across, the note rows up, each reached past by PORTAL_NOTE_REACH.
static func note_corridor() -> Vector2:
	return Vector2(3.0 * Settings.LANE_DISTANCE_X, Constants.ROW_Y[-1] - Constants.ROW_Y[0]) \
		+ Vector2.ONE * PORTAL_NOTE_REACH * 2.0


## Returns a portal standing FLOATING_PORTAL_DISTANCE along `direction` (kept level) from `spot` on the floor, centred
## on the track, in find_portal's form (+z along `direction`): across the curbs' outer edges (never narrower than the
## notes' corridor) and from the floor FLOATING_PORTAL_HEIGHT up, grown to take `extent` (map_extent: across the track
## and up from the floor, metres; it always stands on the floor).
static func floating_portal(spot: Vector3, direction: Vector3, extent := Rect2()) -> Dictionary:
	var out := Vector3(direction.x, 0, direction.z).normalized()
	var across := Vector3.UP.cross(out)
	var half := maxf(maxf(note_corridor().x, 2.0 * (2.0 * Settings.LANE_DISTANCE_X + TrackDeck.EDGE_REACH)) / 2.0,
		maxf(-extent.position.x, extent.end.x))
	var size := Vector2(half * 2.0, maxf(FLOATING_PORTAL_HEIGHT, extent.end.y))
	var centre := spot + out * FLOATING_PORTAL_DISTANCE + Vector3.UP * size.y / 2.0
	return {"transform": Transform3D(Basis(across, Vector3.UP, out), centre), "size": size}


## Returns the box (across the track, up from the floor; metres) that every note, bomb, chain, arc and wall of the
## loaded map (Map's stacks) takes as it comes down the track: notes, bombs, chains and arcs PORTAL_NOTE_REACH round
## their places (an arc by its curve's points and handles, which bound it), walls FLOATING_PORTAL_WALL_MARGIN round
## their edges. An empty Rect2 when the map has nothing.
static func map_extent() -> Rect2:
	var points := PackedVector2Array()
	for note: ColorNoteInfo in Map.note_stack:
		points.append(_lane_point(note.line_index, note.line_layer))
	for bomb: BombInfo in Map.bomb_stack:
		points.append(_lane_point(bomb.line_index, bomb.line_layer))
	for chain: ChainInfo in Map.chain_stack:
		points.append(_lane_point(chain.head_line_index, chain.head_line_layer))
		points.append(_lane_point(chain.tail_line_index, chain.tail_line_layer))
	for arc: ArcInfo in Map.arc_stack:
		for i in arc.curve.point_count:
			var p := arc.curve.get_point_position(i) + arc.tail_pos
			for handle: Vector3 in [Vector3.ZERO, arc.curve.get_point_in(i), arc.curve.get_point_out(i)]:
				points.append(Vector2(p.x + handle.x, p.y + handle.y))
	var box := Rect2()
	for p in points:
		var reach := Rect2(p - Vector2.ONE * PORTAL_NOTE_REACH, Vector2.ONE * PORTAL_NOTE_REACH * 2.0)
		box = reach if box.size == Vector2.ZERO else box.merge(reach)
	for wall: ObstacleInfo in Map.obstacle_stack:
		var left := (wall.line_index - 2.0) * Settings.LANE_DISTANCE_X
		var right := left + wall.width * Settings.LANE_DISTANCE_X
		var low := Constants.wall_y(wall.line_layer)
		var high := Constants.wall_y(wall.line_layer + wall.height)
		var edges := Rect2(Vector2(minf(left, right), minf(low, high)), Vector2(absf(right - left), absf(high - low))) \
			.grow(FLOATING_PORTAL_WALL_MARGIN)
		box = edges if box.size == Vector2.ZERO else box.merge(edges)
	return box


## Returns a note's place across the track and up from the floor for its lane `index` and row `layer`.
static func _lane_point(index: float, layer: float) -> Vector2:
	return Vector2(Settings.LANE_DISTANCE_X * index + Settings.LANE_ZERO_X, Constants.layer_y(layer))


## Returns the transform from world space into the space portal_mask.gdshaderinc reads: the portal at `place` (world
## space, +z out of the room) of `size` becomes the square |x|, |y| <= 0.5 on z = 0.
static func portal_mask_transform(place: Transform3D, size: Vector2) -> Transform3D:
	return place.scaled_local(Vector3(size.x, size.y, 1.0)).affine_inverse()


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
