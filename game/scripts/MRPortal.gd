class_name MRPortal
## Where mixed reality's portals stand (MixedReality.gd): the one floating ahead of the player, grown to take every
## object of the loaded map, and on 90/360 maps one toward each direction objects come from; and the transform the
## portal mask (game/env/portal_mask.gdshaderinc) reads. All static.

## UNTUNED placeholder until the portal is sized on the headset: how far past the outer lanes' and rows' centres the
## portal must reach so whole notes pass through it (Bored, 2026-11-03: notes came through the wall beside the frame).
const PORTAL_NOTE_REACH := 0.35
## The portal floats this far ahead of the player's standing point (Bored, 2026-11-03: first 3 m, then 6 m, then 10 m).
const FLOATING_PORTAL_DISTANCE := 10.0
## The floating portal reaches from the floor this high, and across the track's curbs, so walls (from the floor up),
## arcs (which bulge past the note rows) and bombs come in through its hole, not beside it (Bored, 2026-11-03). UNTUNED.
const FLOATING_PORTAL_HEIGHT := 3.0
## When a song starts the floating portal grows to take every object of the map (map_extent), with this much room round
## a wall's edges (Bored, 2026-11-03: "always big enough for all objects to pass"). UNTUNED.
const FLOATING_PORTAL_WALL_MARGIN := 0.1
## On 90/360 maps a portal opens toward each direction objects are coming from; directions this close (radians, 30°)
## share one portal (Bored, 2026-11-03).
const PORTAL_TURN_MERGE := PI / 6.0


## Returns the size of the notes' corridor: four lanes across, the note rows up, each reached past by PORTAL_NOTE_REACH.
static func note_corridor() -> Vector2:
	return Vector2(3.0 * Settings.LANE_DISTANCE_X, Constants.ROW_Y[-1] - Constants.ROW_Y[0]) \
		+ Vector2.ONE * PORTAL_NOTE_REACH * 2.0


## Returns a portal standing FLOATING_PORTAL_DISTANCE along `direction` (kept level) from `spot` on the floor, centred
## on the track, as {"transform": its centre (+z along `direction`), "size": Vector2}: across the curbs' outer edges
## (never narrower than the notes' corridor) and from the floor FLOATING_PORTAL_HEIGHT up, grown to take `extent`
## (map_extent: across the track and up from the floor, metres; it always stands on the floor), widened on each side to
## take lanes turned up to `spread` radians either way of `direction`.
static func floating_portal(spot: Vector3, direction: Vector3, extent := Rect2(), spread := 0.0) -> Dictionary:
	var out := Vector3(direction.x, 0, direction.z).normalized()
	var across := Vector3.UP.cross(out)
	var half := maxf(maxf(note_corridor().x, 2.0 * (2.0 * Settings.LANE_DISTANCE_X + TrackDeck.EDGE_REACH)) / 2.0,
		maxf(-extent.position.x, extent.end.x)) + FLOATING_PORTAL_DISTANCE * tan(spread)
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


## Returns, for a map whose lanes turn (90/360), each object's [first beat, last beat, lane rotation in radians] sorted by
## first beat, from Map's stacks (an arc once for its head's rotation and once for its tail's); empty when nothing turns.
static func map_turns() -> Array:
	var turns := []
	for note: ColorNoteInfo in Map.note_stack:
		turns.append([note.beat, note.beat, note.rotation])
	for bomb: BombInfo in Map.bomb_stack:
		turns.append([bomb.beat, bomb.beat, bomb.rotation])
	for chain: ChainInfo in Map.chain_stack:
		turns.append([chain.head_beat, chain.tail_beat, chain.rotation])
	for arc: ArcInfo in Map.arc_stack:
		turns.append([arc.head_beat, arc.tail_beat, arc.head_rotation])
		turns.append([arc.head_beat, arc.tail_beat, arc.tail_rotation])
	for wall: ObstacleInfo in Map.obstacle_stack:
		turns.append([wall.beat, wall.beat + wall.duration, wall.rotation])
	if turns.all(func(turn: Array) -> bool: return absf(turn[2]) < Constants.ROTATION_EPS):
		return []
	turns.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return turns


## Returns the portals that take lanes turned `angles` (radians): each Vector2(middle angle, half its spread), lanes
## within PORTAL_TURN_MERGE of a portal's first sharing it; past `max_portals`, the closest neighbours merge further.
static func turn_portals(angles: Array, max_portals: int) -> Array[Vector2]:
	var portals: Array[Vector2] = []
	if angles.is_empty():
		return portals
	var sorted: Array = angles.map(func(a: float) -> float: return fposmod(a, TAU))
	sorted.sort()
	# start after the widest gap round the circle, so no portal is split where the angles wrap
	var start := 0
	var widest: float = sorted[0] + TAU - sorted[-1]
	for i in range(1, sorted.size()):
		if sorted[i] - sorted[i - 1] > widest:
			widest = sorted[i] - sorted[i - 1]
			start = i
	var spans: Array[Vector2] = []
	for i in sorted.size():
		var a: float = sorted[(start + i) % sorted.size()] + (TAU if start + i >= sorted.size() else 0.0)
		if spans.is_empty() or a - spans[-1].x > PORTAL_TURN_MERGE:
			spans.append(Vector2(a, a))
		else:
			spans[-1].y = a
	while spans.size() > max_portals:
		var closest := 0
		for i in range(1, spans.size() - 1):
			if spans[i + 1].x - spans[i].y < spans[closest + 1].x - spans[closest].y:
				closest = i
		spans[closest].y = spans[closest + 1].y
		spans.remove_at(closest + 1)
	for span in spans:
		portals.append(Vector2((span.x + span.y) / 2.0, (span.y - span.x) / 2.0))
	return portals


## Returns a note's place across the track and up from the floor for its lane `index` and row `layer`.
static func _lane_point(index: float, layer: float) -> Vector2:
	return Vector2(Settings.LANE_DISTANCE_X * index + Settings.LANE_ZERO_X, Constants.layer_y(layer))


## Returns the transform from world space into the space portal_mask.gdshaderinc reads: the portal at `place` (world
## space, +z out of the room) of `size` becomes the square |x|, |y| <= 0.5 on z = 0.
static func portal_mask_transform(place: Transform3D, size: Vector2) -> Transform3D:
	return place.scaled_local(Vector3(size.x, size.y, 1.0)).affine_inverse()
