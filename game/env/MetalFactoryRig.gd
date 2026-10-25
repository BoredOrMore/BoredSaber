extends Node3D
class_name MetalFactoryRig
## The Metal Factory environment's structure (doc/world/GAME_BIBLE.md: an underground power plant that the player's
## signal wakes up), which its lights are mounted on (AGENTS.md "Light", rule 5). Blockout: plain dark boxes for
## silhouette and composition only (tools/asset_pipeline stage 2), standing in for the detail models to come.
## Two rows of pistons over anvils beside the track, gear rings around it, energy rails along it, machinery walls and a
## ceiling truss closing the hall, and drive gears at the far end, beside and below the horizon. Everything stands on
## the floor, a wall or the far foundation; nothing enters the note corridor (lanes +-1.2 m, y 0 to 2.5).
## Dark boxes drawn in one MultiMesh with the scenery's fog shader. Sizes in metres; untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
## how far below the floor (y 0) structure that stands on it starts, so no base shows a gap
const SINK := 1.0
## the factory floor either side of the track (the track floor is about 7 m wide): from x INNER to OUTER, from z
## NEAR to FAR, where the drive gears' pit opens
const FLOOR_X := Vector2(3.6, 18.0)
const FLOOR_Z := Vector2(4.0, -56.0)
## the track floor ends at z -48 (SPATIAL_LAYOUT.md); the factory floor closes the gap between its end and the pit
const TRACK_END_Z := -48.0
const FLOOR_THICKNESS := 0.5
## Pistons: one over each anvil, a row each side, every 8 m. The anvil (width x, height above the floor, depth z)
## takes the blow; the hammer hangs raised from its housing, under a header beam carried by posts between the pistons.
const PISTON_X := 8.0
const PISTON_Z: Array[float] = [-12.0, -20.0, -28.0, -36.0, -44.0]
const ANVIL := Vector3(3.6, 1.5, 3.6)
const HAMMER := Vector3(2.2, 1.2, 2.2)
const HAMMER_BOTTOM := 3.8
const ROD := 0.5
const HOUSING := Vector3(1.4, 3.0, 1.4)
const HEADER_Y := 9.0
const HEADER := 0.6
const POST_Z: Array[float] = [-8.0, -16.0, -24.0, -32.0, -40.0, -48.0]
## the diagonal lasers stand on each anvil's inner corner nearest the player, clear of the hammer
const ANVIL_FIXTURE_INSET := 0.35
## Gear rings around the track: centre height, radius to the rim's middle, rim thickness and depth, how many
## straight pieces make the rim, and the teeth on its outer edge. The rims run down through the floor.
const RING_Y := 2.0
const RING_RADIUS := 6.5
const RING_RIM := Vector2(0.6, 0.6)
const RING_SEGMENTS := 12
const RING_TOOTH := 0.6
const RING_Z: Array[float] = [-15.0, -23.0, -31.0, -39.0, -47.0, -55.0]
## Energy rails either side of the track, from just behind the player to near the track's end; the square bars run as
## light strips flush on their tops (EventDriver).
const RAIL_X := 4.0
const RAIL_TOP := 0.3
const RAIL_WIDTH := 0.4
const RAIL_Z := Vector2(2.0, -48.0)
## Machinery walls: a solid wall from x WALL_X.x to WALL_X.y, WALL_TOP high; a catwalk ledge along its inner face
## (the waving lasers stand on it); and machine blocks on the floor against the wall, every 8 m, two heights in turn.
const WALL_X := Vector2(18.0, 20.0)
const WALL_TOP := 18.0
const WALL_Z := Vector2(6.0, -68.0)
const LEDGE_X := 16.0
const LEDGE_TOP := 8.0
const LEDGE_THICKNESS := 0.6
const WAVING_Z: Array[float] = [-16.0, -24.0, -32.0, -40.0]
const MACHINE_X := 15.0
const MACHINE_DEPTH := 4.0
const MACHINE_HEIGHTS: Array[float] = [5.5, 3.5]
const MACHINE_Z: Array[float] = [-4.0, -12.0, -20.0, -28.0, -36.0, -44.0, -52.0]
## Ceiling truss: cross beams from wall to wall every 8 m and two chords along the hall, at TRUSS_Y.
const TRUSS_Y := 18.0
const TRUSS_BEAM := 0.6
const TRUSS_Z: Array[float] = [0.0, -8.0, -16.0, -24.0, -32.0, -40.0, -48.0, -56.0, -64.0]
const TRUSS_CHORD_X := 9.0
## Drive gears at the far end, facing the player (x, y centre, z, radius): a big one each side, half in the wall's end
## pier, and a smaller one meshing below it in the pit, its top just above the floor. Each has an axle back into the
## foundation or the pier. The view straight ahead stays open above the foundation.
const DRIVE_GEARS: Array[Vector4] = [
	Vector4(-17.0, 2.0, -58.0, 10.0), Vector4(17.0, 2.0, -58.0, 10.0),
	Vector4(-9.0, -6.0, -62.0, 7.5), Vector4(9.0, -6.0, -62.0, 7.5),
]
const GEAR_RIM := Vector2(1.2, 1.0)
const GEAR_SEGMENTS := 16
const GEAR_TOOTH := 1.2
const GEAR_HUB := 2.0
const AXLE := 1.0
## the foundation the pit's gears turn in, across the far end, its top at the floor (half width, bottom, near z, far z);
## the walls reach down to its bottom past the pit, and end in piers
const FOUNDATION := Vector4(24.0, -14.0, -66.0, -70.0)
const PIER_X := Vector2(14.0, 20.0)

## Builds the boxes into one MultiMesh.
func _ready() -> void:
	var boxes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		_side(boxes, side)
	for z in TRUSS_Z:
		boxes.append(_box(Vector3(0.0, TRUSS_Y, z), Vector3(WALL_X.x * 2.0, TRUSS_BEAM, TRUSS_BEAM)))
	for side in [-1.0, 1.0]:
		boxes.append(_span(Vector3(side * TRUSS_CHORD_X - TRUSS_BEAM * 0.5, TRUSS_Y + TRUSS_BEAM * 0.5, TRUSS_Z[0]),
			Vector3(side * TRUSS_CHORD_X + TRUSS_BEAM * 0.5, TRUSS_Y + TRUSS_BEAM * 1.5, TRUSS_Z[-1])))
	for z in RING_Z:
		_gear(boxes, Vector3(0.0, RING_Y, z), RING_RADIUS, RING_RIM, RING_SEGMENTS, RING_TOOTH)
	for gear in DRIVE_GEARS:
		var centre := Vector3(gear.x, gear.y, gear.z)
		_gear(boxes, centre, gear.w, GEAR_RIM, GEAR_SEGMENTS, GEAR_TOOTH)
		for angle in [0.0, PI * 0.5]:
			boxes.append(Transform3D(Basis(Vector3.BACK, angle) * Basis.from_scale(Vector3(gear.w * 2.0, GEAR_RIM.x, GEAR_RIM.y)), centre))
		boxes.append(_box(centre, Vector3(GEAR_HUB, GEAR_HUB, GEAR_HUB)))
		var axle_end := FOUNDATION.z
		boxes.append(_box(Vector3(gear.x, gear.y, (gear.z + axle_end) * 0.5), Vector3(AXLE, AXLE, gear.z - axle_end)))
	boxes.append(_span(Vector3(-FLOOR_X.x, -FLOOR_THICKNESS, TRACK_END_Z), Vector3(FLOOR_X.x, 0.0, FLOOR_Z.y)))
	boxes.append(_box(Vector3(0.0, FOUNDATION.y * 0.5, (FOUNDATION.z + FOUNDATION.w) * 0.5),
		Vector3(FOUNDATION.x * 2.0, -FOUNDATION.y, FOUNDATION.z - FOUNDATION.w)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		multimesh.set_instance_transform(i, boxes[i])
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## Adds one side's floor, rail, pistons, wall, ledge, machines and end pier (side -1 left, 1 right).
static func _side(boxes: Array[Transform3D], side: float) -> void:
	boxes.append(_span(Vector3(side * FLOOR_X.x, -FLOOR_THICKNESS, FLOOR_Z.x), Vector3(side * FLOOR_X.y, 0.0, FLOOR_Z.y)))
	boxes.append(_span(Vector3(side * (RAIL_X - RAIL_WIDTH * 0.5), -SINK, RAIL_Z.x), Vector3(side * (RAIL_X + RAIL_WIDTH * 0.5), RAIL_TOP, RAIL_Z.y)))
	for z in PISTON_Z:
		boxes.append(_box(Vector3(side * PISTON_X, (ANVIL.y - SINK) * 0.5, z), Vector3(ANVIL.x, ANVIL.y + SINK, ANVIL.z)))
		boxes.append(_box(Vector3(side * PISTON_X, HAMMER_BOTTOM + HAMMER.y * 0.5, z), HAMMER))
		var housing_bottom := HEADER_Y - HOUSING.y
		var rod_bottom := HAMMER_BOTTOM + HAMMER.y
		boxes.append(_box(Vector3(side * PISTON_X, (rod_bottom + housing_bottom) * 0.5, z), Vector3(ROD, housing_bottom - rod_bottom, ROD)))
		boxes.append(_box(Vector3(side * PISTON_X, housing_bottom + HOUSING.y * 0.5, z), HOUSING))
	for z in POST_Z:
		boxes.append(_box(Vector3(side * PISTON_X, (HEADER_Y - SINK) * 0.5, z), Vector3(HEADER, HEADER_Y + SINK, HEADER)))
	boxes.append(_span(Vector3(side * (PISTON_X - HEADER * 0.5), HEADER_Y, POST_Z[0]), Vector3(side * (PISTON_X + HEADER * 0.5), HEADER_Y + HEADER, POST_Z[-1])))
	boxes.append(_span(Vector3(side * WALL_X.x, FOUNDATION.y, WALL_Z.x), Vector3(side * WALL_X.y, WALL_TOP, WALL_Z.y)))
	boxes.append(_span(Vector3(side * LEDGE_X, LEDGE_TOP - LEDGE_THICKNESS, WALL_Z.x), Vector3(side * WALL_X.x, LEDGE_TOP, WALL_Z.y)))
	for i in MACHINE_Z.size():
		var z := MACHINE_Z[i]
		var height := MACHINE_HEIGHTS[i % MACHINE_HEIGHTS.size()]
		boxes.append(_span(Vector3(side * MACHINE_X, -SINK, z + MACHINE_DEPTH * 0.5), Vector3(side * WALL_X.x, height, z - MACHINE_DEPTH * 0.5)))
	boxes.append(_span(Vector3(side * PIER_X.x, FOUNDATION.y, FOUNDATION.z + 2.0), Vector3(side * PIER_X.y, WALL_TOP, FOUNDATION.w)))

## Adds a gear facing the player (axis along z): a rim of straight pieces with a tooth on each, outside.
static func _gear(boxes: Array[Transform3D], centre: Vector3, radius: float, rim: Vector2, segments: int, tooth: float) -> void:
	var chord := 2.0 * radius * sin(PI / segments)
	for i in segments:
		var angle := TAU * (i + 0.5) / segments
		var basis := Basis(Vector3.BACK, angle + PI * 0.5)
		var out := Vector3(cos(angle), sin(angle), 0.0)
		boxes.append(Transform3D(basis * Basis.from_scale(Vector3(chord, rim.x, rim.y)), centre + out * radius))
		boxes.append(Transform3D(basis * Basis.from_scale(Vector3(tooth, tooth, rim.y)), centre + out * (radius + (rim.x + tooth) * 0.5)))

## Where a diagonal laser stands on anvil `i` (left row first), its foot on the anvil's top.
static func anvil_fixture(i: int) -> Vector3:
	var side := -1.0 if i < PISTON_Z.size() else 1.0
	var z := PISTON_Z[i % PISTON_Z.size()]
	return Vector3(side * (PISTON_X - ANVIL.x * 0.5 + ANVIL_FIXTURE_INSET), ANVIL.y, z + ANVIL.z * 0.5 - ANVIL_FIXTURE_INSET)

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)

## A box between two opposite corners.
static func _span(a: Vector3, b: Vector3) -> Transform3D:
	return _box((a + b) * 0.5, (b - a).abs())
