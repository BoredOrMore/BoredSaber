@tool
extends Node3D
class_name MetalFactoryRig
## The Metal Factory environment's structure (doc/world/GAME_BIBLE.md: an underground power plant that the player's
## signal wakes up), which its lights are mounted on (AGENTS.md "Light", rule 5). Blockout (approved 2026-10-25):
## plain dark boxes for silhouette and composition, standing in for the detail models to come; the pistons and anvils
## are models.
## Two rows of pistons over anvils beside the track, gear rings around it, energy rails along it, machinery walls and a
## ceiling truss closing the hall, and drive gears at the far end, beside and below the horizon. Everything stands on
## the floor, a wall or the far foundation; nothing enters the note corridor (lanes +-1.2 m, y 0 to 2.5).
## Dark boxes in one MultiMesh, and each piston part and the anvils in their own, all with the scenery's fog shader.
## Sizes in metres; untuned.
## A tool script, so the hall also shows in the editor's viewport (event_driver.tscn); its parts are built at load and
## never saved into the scene (they have no owner).

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
## How much of the lights' colour the hall's faces take (EnvSolid light_spill, 1 elsewhere): at 1 the big wall and
## ceiling faces turned toward the track read as grey sheets (luma about 39 of 255 in the eye capture with the lights
## on), against "blacks stay black" (doc/world/VISUAL_STYLE.md). Untuned.
const LIGHT_SPILL := 0.3
## how far below the floor (y 0) structure that stands on it starts, so no base shows a gap
const SINK := 1.0
## the factory floor either side of the track (the track floor is about 7 m wide): from x INNER to OUTER, from z
## NEAR to FAR, where the drive gears' pit opens
const FLOOR_X := Vector2(3.6, 18.0)
const FLOOR_Z := Vector2(4.0, -56.0)
## The factory floor also runs under the track and the player's platform, this far below their surface, so no sky shows
## between or past them.
const UNDER_TRACK := 0.02
const FLOOR_THICKNESS := 0.5
## Pistons: one over each anvil, a row each side, every 8 m. The anvil takes the blow; the hammer hangs raised from its
## housing, under a header beam carried by posts between the pistons (models made by tools/models/piston_hammer.py and
## anvil_base.py, records in doc/assets/). The anvil's origin is its foot, on the floor; the housing's is its top,
## against the header's underside; the hammer's is its striking face, HAMMER_BOTTOM up when raised. ANVIL_TOP is the
## anvil's strike die, where the hammer lands; ANVIL_SHELF the top of its body around the die (height, half width).
const PISTON_X := 8.0
const PISTON_Z: Array[float] = [-12.0, -20.0, -28.0, -36.0, -44.0]
const ANVIL_MODEL := preload("res://game/models/anvil_base.glb")
const ANVIL_TOP := 1.5
const ANVIL_SHELF := Vector2(1.2, 1.7)
const HOUSING_MODEL := preload("res://game/models/piston_housing.glb")
const HAMMER_MODEL := preload("res://game/models/piston_hammer.glb")
const HAMMER_BOTTOM := 3.8
const HEADER_Y := 9.0
## Slamming (doc/world/GAME_BIBLE.md, owner 2026-10-25): every hammer lands on its anvil together, on the map's beat:
## every beat, or every 2 beats when a beat is shorter than SLAM_MIN_CYCLE_SECONDS (doubled again only for extreme
## tempos), and only while the show's intensity is high: the stroke grows from nothing at SLAM_FROM to full at
## SLAM_FULL. After landing a hammer rests SLAM_REST_SECONDS, rises slowly, easing in and out, and drops over the last
## SLAM_FALL_SECONDS of the cycle, speeding up like a falling weight, so the blow is heavy and lands on the beat. All
## hammers move as one, so one node moves, not ten instances. Untuned.
const STROKE := HAMMER_BOTTOM - ANVIL_TOP
const SLAM_MIN_CYCLE_SECONDS := 0.5
const SLAM_FROM := 0.6
const SLAM_FULL := 0.9
const SLAM_REST_SECONDS := 0.06
const SLAM_FALL_SECONDS := 0.15
## Sparks on a blow (owner, 2026-10-25): as each hammer lands they burst out all round the anvil (owner: every way, not
## in a few jets), from SPARK_DIRECTIONS even angles on the die's top edge, each straight out from its centre, and
## fall away; hot white cooling to the note colour of that side's lights (left row left, right row
## right), as the cut sparks do (CutFlash). Only a blow of at least SPARK_FROM of the full stroke throws them, at most
## once a slam cycle, so never more than 2 bursts a second (Light rule 8). One emitter per side, firing from points
## round every die on that side. The cut sparks' streak mesh, SPARK_SCALE times larger to read at 10-45 m. Untuned.
const SPARK_FROM := 0.5
const SPARK_DIRECTIONS := 24
const SPARK_LIFT := 0.05
const SPARKS_PER_SIDE := 100
const SPARK_SECONDS := 0.7
const SPARK_SPEED := Vector2(2.5, 5.0)
const SPARK_SPREAD_DEG := 12.0
## how far the sparks lean upward from flat as they leave the edge
const SPARK_RISE := 0.3
const SPARK_GRAVITY := 9.8
const SPARK_SCALE := 4.0
## (at most about 3.5 m out from the die's edge before they fade, so from the inner edge (x ±6.8) they stay beyond the
## energy rails (x ±4) and well clear of the note corridor)
## the die's half width (tools/models/anvil_base.py DIE)
const DIE_HALF := 1.2
const HEADER := 0.6
const POST_Z: Array[float] = [-8.0, -16.0, -24.0, -32.0, -40.0, -48.0]
## the diagonal lasers stand on each anvil's shelf at its inner corner nearest the player, this far in from both edges:
## clear of the die and of the hammer's face
const ANVIL_FIXTURE_INSET := 0.3
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
const WALL_TOP := 19.0
const WALL_Z := Vector2(6.0, -68.0)
const LEDGE_X := 16.0
const LEDGE_TOP := 8.0
const LEDGE_THICKNESS := 0.6
const WAVING_Z: Array[float] = [-16.0, -24.0, -32.0, -40.0]
const MACHINE_X := 15.0
const MACHINE_DEPTH := 4.0
const MACHINE_HEIGHTS: Array[float] = [5.5, 3.5]
const MACHINE_Z: Array[float] = [-4.0, -12.0, -20.0, -28.0, -36.0, -44.0, -52.0]
## Ceiling truss: cross beams from wall to wall every 8 m and two chords along the hall on top of them, at TRUSS_Y,
## under a solid ceiling slab resting on the walls (WALL_TOP), so no sky shows overhead: the hall is underground.
const TRUSS_Y := 18.1
const CEILING_THICKNESS := 1.0
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

var _hammers: MultiMeshInstance3D
## the sparks of the left and right rows, and the slam cycle that last threw them
var _sparks: Array[CPUParticles3D] = []
var _sparked_cycle := -1.0

## Builds the boxes into one MultiMesh and the pistons and anvils into one per part, all with the hall's material.
func _ready() -> void:
	var boxes: Array[Transform3D] = []
	var housings: Array[Transform3D] = []
	var hammers: Array[Transform3D] = []
	var anvils: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for z in PISTON_Z:
			anvils.append(Transform3D(Basis.IDENTITY, Vector3(side * PISTON_X, 0.0, z)))
			housings.append(Transform3D(Basis.IDENTITY, Vector3(side * PISTON_X, HEADER_Y, z)))
			hammers.append(Transform3D(Basis.IDENTITY, Vector3(side * PISTON_X, HAMMER_BOTTOM, z)))
	for side in [-1.0, 1.0]:
		_side(boxes, side)
	for z in TRUSS_Z:
		boxes.append(_box(Vector3(0.0, TRUSS_Y, z), Vector3(WALL_X.x * 2.0, TRUSS_BEAM, TRUSS_BEAM)))
	boxes.append(_span(Vector3(-WALL_X.y, WALL_TOP, WALL_Z.x), Vector3(WALL_X.y, WALL_TOP + CEILING_THICKNESS, WALL_Z.y)))
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
	boxes.append(_span(Vector3(-FLOOR_X.x, -FLOOR_THICKNESS, FLOOR_Z.x), Vector3(FLOOR_X.x, -UNDER_TRACK, FLOOR_Z.y)))
	boxes.append(_box(Vector3(0.0, FOUNDATION.y * 0.5, (FOUNDATION.z + FOUNDATION.w) * 0.5),
		Vector3(FOUNDATION.x * 2.0, -FOUNDATION.y, FOUNDATION.z - FOUNDATION.w)))
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	material.set_shader_parameter(&"light_spill", LIGHT_SPILL)
	_add_multimesh(BoxMesh.new(), boxes, material)
	_add_multimesh(LaserFixtures._model_mesh(HOUSING_MODEL), housings, material)
	_hammers = _add_multimesh(LaserFixtures._model_mesh(HAMMER_MODEL), hammers, material)
	_add_multimesh(LaserFixtures._model_mesh(ANVIL_MODEL), anvils, material)
	for side in [-1.0, 1.0]:
		_sparks.append(_add_sparks(side))

## Sets the sparks' colours: the left row cools to `left`, the right to `right`.
func set_spark_colors(left: Color, right: Color) -> void:
	for i in 2:
		var color := left if i == 0 else right
		_sparks[i].color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))

## The spark emitter of one row (side -1 left, 1 right): directed points round the top edges of its dies, at even
## angles, each pointing straight out from its die's centre and a little up.
func _add_sparks(side: float) -> CPUParticles3D:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	for z in PISTON_Z:
		var centre := Vector3(side * PISTON_X, ANVIL_TOP + SPARK_LIFT, z)
		for k in SPARK_DIRECTIONS:
			var angle := TAU * k / SPARK_DIRECTIONS
			var out := Vector3(cos(angle), 0.0, sin(angle))
			# on the square edge: stretched out to the side it meets
			points.append(centre + out / maxf(absf(out.x), absf(out.z)) * DIE_HALF)
			normals.append((out + Vector3.UP * SPARK_RISE).normalized())
	var sparks := CPUParticles3D.new()
	sparks.mesh = CutFlash.spark_mesh()
	sparks.particle_flag_align_y = true
	sparks.amount = SPARKS_PER_SIDE
	sparks.lifetime = SPARK_SECONDS
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_DIRECTED_POINTS
	sparks.emission_points = points
	sparks.emission_normals = normals
	# directed points turn `direction` into each point's frame, whose z is the normal: +z flies out along it (the
	# default +x flew along the die's edge, across the anvil)
	sparks.direction = Vector3.BACK
	sparks.spread = SPARK_SPREAD_DEG
	sparks.initial_velocity_min = SPARK_SPEED.x
	sparks.initial_velocity_max = SPARK_SPEED.y
	sparks.gravity = Vector3(0.0, -SPARK_GRAVITY, 0.0)
	sparks.scale_amount_min = SPARK_SCALE
	sparks.scale_amount_max = SPARK_SCALE
	sparks.color_ramp = Gradient.new()
	sparks.color_ramp.set_color(0, Color.WHITE)
	add_child(sparks)
	return sparks

## Moves the hammers for the song's `beat` at `bpm` and the show's `intensity` (0 to 1); a bpm of 0 rests them raised.
func slam(beat: float, bpm: float, intensity: float) -> void:
	var drop := 0.0
	if bpm > 0.0:
		var beats := 1.0
		while beats * 60.0 / bpm < SLAM_MIN_CYCLE_SECONDS:
			beats *= 2.0
		var stroke := smoothstep(SLAM_FROM, SLAM_FULL, intensity)
		drop = hammer_drop(fposmod(beat, beats) * 60.0 / bpm, beats * 60.0 / bpm) * stroke
		# a new cycle has started: the hammers have just landed
		var cycle := floorf(beat / beats)
		if cycle != _sparked_cycle:
			_sparked_cycle = cycle
			if stroke >= SPARK_FROM:
				for sparks in _sparks:
					sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0, stroke))
					sparks.restart()
	_hammers.position.y = -STROKE * drop

## How far down a hammer is, 1 on the anvil to 0 raised, `t` seconds after it last landed in a slam every `cycle` seconds.
static func hammer_drop(t: float, cycle: float) -> float:
	var fall_start := cycle - SLAM_FALL_SECONDS
	if t < SLAM_REST_SECONDS:
		return 1.0
	if t >= fall_start:
		var u := (t - fall_start) / SLAM_FALL_SECONDS
		return u * u
	return 1.0 - smoothstep(SLAM_REST_SECONDS, fall_start, t)

## Draws `mesh` once at each of `places` in one MultiMesh, without shadows; returns its node.
func _add_multimesh(mesh: Mesh, places: Array[Transform3D], material: ShaderMaterial) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = places.size()
	for i in places.size():
		multimesh.set_instance_transform(i, places[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

## Adds one side's floor, rail, piston posts and header, wall, ledge, machines and end pier (side -1 left, 1 right).
static func _side(boxes: Array[Transform3D], side: float) -> void:
	boxes.append(_span(Vector3(side * FLOOR_X.x, -FLOOR_THICKNESS, FLOOR_Z.x), Vector3(side * FLOOR_X.y, 0.0, FLOOR_Z.y)))
	boxes.append(_span(Vector3(side * (RAIL_X - RAIL_WIDTH * 0.5), -SINK, RAIL_Z.x), Vector3(side * (RAIL_X + RAIL_WIDTH * 0.5), RAIL_TOP, RAIL_Z.y)))
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

## Where a diagonal laser stands on anvil `i` (left row first), its foot on the anvil's shelf.
static func anvil_fixture(i: int) -> Vector3:
	var side := -1.0 if i < PISTON_Z.size() else 1.0
	var z := PISTON_Z[i % PISTON_Z.size()]
	var offset := ANVIL_SHELF.y - ANVIL_FIXTURE_INSET
	return Vector3(side * (PISTON_X - offset), ANVIL_SHELF.x, z + offset)

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)

## A box between two opposite corners.
static func _span(a: Vector3, b: Vector3) -> Transform3D:
	return _box((a + b) * 0.5, (b - a).abs())
