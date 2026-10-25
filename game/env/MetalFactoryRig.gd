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
## the metal pieces' sheen (EnvSolid layer 8, the matcap made by tools/make_matcap.py); the same for the track's edges here
## (TrackDeck.METAL_BY_STAGE). At 1 with the first matcap the pieces read as grey-lifted, brighter than the walls
## (owner, 2026-10-25). Untuned.
const METAL_SHEEN := 0.5
const MATCAP := preload("res://game/env/metal_matcap.png")
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
## anvil's strike die, where the hammer lands.
const PISTON_X := 8.0
const PISTON_Z: Array[float] = [-12.0, -20.0, -28.0, -36.0, -44.0]
const ANVIL_MODEL := preload("res://game/models/anvil_base.glb")
const ANVIL_TOP := 1.5
const HOUSING_MODEL := preload("res://game/models/piston_housing.glb")
const HAMMER_MODEL := preload("res://game/models/piston_hammer.glb")
const HAMMER_BOTTOM := 3.8
const HEADER_Y := 9.0
## Slamming (doc/world/GAME_BIBLE.md, owner 2026-10-25): the hammers land on their anvils on the map's beat: every beat,
## or every 2 beats when a beat is shorter than SLAM_MIN_CYCLE_SECONDS (doubled again only for extreme tempos), and only
## while the show's intensity is high: the stroke grows from nothing at SLAM_FROM to full at SLAM_FULL. After landing a
## hammer rests SLAM_REST_SECONDS, rises slowly, easing in and out, and drops over the last SLAM_FALL_SECONDS of the
## cycle, speeding up like a falling weight, so the blow is heavy. Untuned.
## Almost but not quite together (owner, 2026-10-25): each hammer lands SLAM_LAG_SECONDS after the beat (left row
## near to far, then the right), a fixed ripple, never random. All lag the beat, none leads it, and the last lands
## within 70 ms: a sight lagging its sound by under about 100 ms still reads as in sync, while one leading it is noticed
## sooner (Vroomen & Keetels 2010, "Perception of intersensory synchrony: a tutorial review").
const STROKE := HAMMER_BOTTOM - ANVIL_TOP
const SLAM_MIN_CYCLE_SECONDS := 0.5
const SLAM_FROM := 0.6
const SLAM_FULL := 0.9
const SLAM_REST_SECONDS := 0.06
const SLAM_FALL_SECONDS := 0.15
const SLAM_LAG_SECONDS: Array[float] = [0.0, 0.035, 0.015, 0.06, 0.025, 0.05, 0.005, 0.04, 0.07, 0.02]
## Sparks on a blow (owner, 2026-10-25): as each hammer lands they burst out all round the anvil (owner: every way, not
## in a few jets), from SPARK_DIRECTIONS even angles on the die's top edge, each straight out from its centre, and
## fall away; hot white cooling to the note colour of that side's lights (left row left, right row
## right), as the cut sparks do (CutFlash). Only a blow of at least SPARK_FROM of the full stroke throws them, as that
## hammer lands, at most once a slam cycle per anvil, so never more than 2 bursts a second from any one (Light rule 8).
## One emitter per anvil. The cut sparks' streak mesh, SPARK_SCALE times larger to read at 10-45 m. Untuned.
const SPARK_FROM := 0.5
const SPARK_DIRECTIONS := 24
const SPARK_LIFT := 0.05
const SPARKS_PER_ANVIL := 20
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
## Gear rings around the track (gear_ring.glb, tools/models/gears.py: 13.6 m across at the rim, 12 teeth), their
## centres RING_Y up, running down through the floor. They turn on the map's ring-spin events like Classic's rings
## (EventDriver.ring_rot_speed), RING_SPIN of its speed, neighbours in opposite directions as meshed gears do, so the
## view round the track never all flows one way.
const RING_MODEL := preload("res://game/models/gear_ring.glb")
const RING_Y := 2.0
const RING_SPIN := 0.5
const RING_Z: Array[float] = [-15.0, -23.0, -31.0, -39.0, -47.0, -55.0]
## Energy rails either side of the track, from just behind the player to near the track's end; the square bars run as
## light strips flush on their tops (EventDriver).
const RAIL_X := 4.0
const RAIL_TOP := 0.3
const RAIL_WIDTH := 0.4
const RAIL_Z := Vector2(2.0, -48.0)
## Machinery walls: a solid wall from x WALL_X.x to WALL_X.y, up to the vault's springline (WALL_TOP); a catwalk ledge along its inner face
## (a walkway along the machinery). Against the wall's face, the wall kit (tools/models/wall_kit.py,
## doc/assets/wall_kit): an I-beam column at every COLUMN_Z, and in each bay between (BAY_Z) a framed, louvered panel
## above the catwalk (its foot PANEL_Y up), a run of pipes under the catwalk (centred PIPES_Y up) and a machine on the
## floor, tall and low in turn. Each piece's front faces the track: the right wall's are turned half round.
const WALL_X := Vector2(18.0, 20.0)
const WALL_TOP := 17.0
const WALL_Z := Vector2(6.0, -68.0)
const LEDGE_X := 16.0
const LEDGE_TOP := 8.0
const LEDGE_THICKNESS := 0.6
const COLUMN_Z: Array[float] = [0.0, -8.0, -16.0, -24.0, -32.0, -40.0, -48.0, -56.0]
const BAY_Z: Array[float] = [-4.0, -12.0, -20.0, -28.0, -36.0, -44.0, -52.0]
const PANEL_Y := 8.5
## The hall has no laser beams or moving heads (owner, 2026-10-25: they read as a concert, not a plant): the light groups
## glow in the panels' vent louvers instead (EnvSolid layer 6, the louvers marked in tools/models/wall_kit.py), set each
## frame from EventDriver: the upper row on both walls in the diagonal lasers' colour, the lower row in the left or
## right waving lasers' by wall (the shader tells by the panel's side of the track). The panels have their own copy of
## the hall's material, so this adds no draw call.
## The walls breathe (plan doc, owner 2026-10-25): while the show's intensity is high the panels push out toward the
## track and settle back, BREATH_DEPTH at full, growing from nothing at BREATH_FROM to full at BREATH_FULL. One breath
## every 4 beats, halved or doubled until a breath lasts BREATH_SECONDS.x to .y seconds, so it follows the song but
## never comes near 0.2 Hz, where slow motion makes people sickest (O'Hanlon & McCauley 1974). Untuned.
const BREATH_DEPTH := 0.12
const BREATH_FROM := 0.5
const BREATH_FULL := 0.9
const BREATH_BEATS := 4.0
const BREATH_SECONDS := Vector2(1.4, 3.0)
const PIPES_Y := 6.7
const WALL_KIT := {
	"column": preload("res://game/models/wall_column.glb"),
	"panel": preload("res://game/models/wall_panel.glb"),
	"pipes": preload("res://game/models/wall_pipes.glb"),
	"machine": preload("res://game/models/wall_machine.glb"),
	"machine_low": preload("res://game/models/wall_machine_low.glb"),
}
## The vault over the hall (owner's sketch, 2026-10-25: the top half of an octagon tube): from the walls' tops (the
## springline, WALL_TOP) each side turns in at 45 degrees for VAULT_RUN metres, then a flat crown, all a solid shell
## VAULT_SHELL thick, so no sky shows overhead: the hall is underground. Ribs follow that outline at every TRUSS_Z (the
## columns' spacing and on to the far end), standing RIB proud of the shell, and beams run along the hall at its four
## corner lines. Nothing spans the hall below the vault (the owner had the old ceiling's cross beams taken out).
const VAULT_RUN := 9.0
const VAULT_SHELL := 1.0
const RIB := Vector2(0.6, 0.6)
const CORNER_BEAM := 0.6
const TRUSS_Z: Array[float] = [0.0, -8.0, -16.0, -24.0, -32.0, -40.0, -48.0, -56.0, -64.0]
## Drive gears at the far end, facing the player (drive_gear_large/small.glb, tools/models/gears.py): a large one each
## side (centre, left first), half in the wall's end pier, and a small one meshing below it in the pit, its top just
## above the floor. Each has an axle back into the foundation or the pier. The view straight ahead stays open above the
## foundation.
const LARGE_GEARS: Array[Vector3] = [Vector3(-17.0, 2.0, -58.0), Vector3(17.0, 2.0, -58.0)]
const SMALL_GEARS: Array[Vector3] = [Vector3(-9.0, -6.0, -62.0), Vector3(9.0, -6.0, -62.0)]
const LARGE_GEAR_MODEL := preload("res://game/models/drive_gear_large.glb")
const SMALL_GEAR_MODEL := preload("res://game/models/drive_gear_small.glb")
const AXLE := 1.0
## They turn with the show (owner, 2026-10-25): still while it is quiet, slowly as it builds, full speed at the drop:
## GEAR_SPEED radians a second for the large gears, scaled from nothing at intensity GEAR_FROM to full at GEAR_FULL.
## Each small gear turns the other way, faster by the tooth ratio (24 to 18), as meshed gears do; the right pair
## mirrors the left. Kept slow (about 20 degrees a second at most) and far off (58-62 m): only side and far pieces
## turn, never the floor or the track (vection, plan doc). Untuned.
const GEAR_SPEED := 0.35
const GEAR_FROM := 0.1
const GEAR_FULL := 0.9
const GEAR_RATIO := 24.0 / 18.0
## the foundation the pit's gears turn in, across the far end, its top at the floor (half width, bottom, near z, far z);
## the walls reach down to its bottom past the pit, and end in piers
const FOUNDATION := Vector4(24.0, -14.0, -66.0, -70.0)
const PIER_X := Vector2(14.0, 20.0)

var _hammers: MultiMesh
var _rings: MultiMesh
var _large_gears: MultiMesh
var _small_gears: MultiMesh
## the wall panels and where each rests
var _panels: MultiMesh
var _panel_rest: Array[Transform3D] = []
var _vent_material: ShaderMaterial
## each anvil's sparks (left row first, near to far) and the slam cycle each hammer last landed in
var _sparks: Array[CPUParticles3D] = []
var _landed := PackedFloat32Array()

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
	_vault(boxes)
	for gear in LARGE_GEARS + SMALL_GEARS:
		var axle_end := FOUNDATION.z
		boxes.append(_box(Vector3(gear.x, gear.y, (gear.z + axle_end) * 0.5), Vector3(AXLE, AXLE, gear.z - axle_end)))
	boxes.append(_span(Vector3(-FLOOR_X.x, -FLOOR_THICKNESS, FLOOR_Z.x), Vector3(FLOOR_X.x, -UNDER_TRACK, FLOOR_Z.y)))
	boxes.append(_box(Vector3(0.0, FOUNDATION.y * 0.5, (FOUNDATION.z + FOUNDATION.w) * 0.5),
		Vector3(FOUNDATION.x * 2.0, -FOUNDATION.y, FOUNDATION.z - FOUNDATION.w)))
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	material.set_shader_parameter(&"light_spill", LIGHT_SPILL)
	# the metal pieces (pistons, anvils, gears) get the metal sheen (EnvSolid layer 8); walls and plain boxes don't
	var metal_material := material.duplicate() as ShaderMaterial
	metal_material.set_shader_parameter(&"metal", METAL_SHEEN)
	metal_material.set_shader_parameter(&"matcap", MATCAP)
	_add_multimesh(BoxMesh.new(), boxes, material)
	_add_multimesh(LaserFixtures._model_mesh(HOUSING_MODEL), housings, metal_material)
	_hammers = _add_multimesh(LaserFixtures._model_mesh(HAMMER_MODEL), hammers, metal_material).multimesh
	_add_multimesh(LaserFixtures._model_mesh(ANVIL_MODEL), anvils, metal_material)
	var rings: Array[Transform3D] = []
	for z in RING_Z:
		rings.append(Transform3D(Basis.IDENTITY, Vector3(0.0, RING_Y, z)))
	_rings = _add_multimesh(LaserFixtures._model_mesh(RING_MODEL), rings, metal_material).multimesh
	var large: Array[Transform3D] = []
	var small: Array[Transform3D] = []
	for i in LARGE_GEARS.size():
		large.append(Transform3D(Basis.IDENTITY, LARGE_GEARS[i]))
		small.append(Transform3D(Basis.IDENTITY, SMALL_GEARS[i]))
	_large_gears = _add_multimesh(LaserFixtures._model_mesh(LARGE_GEAR_MODEL), large, metal_material).multimesh
	var kit := {}
	for piece: String in WALL_KIT:
		kit[piece] = [] as Array[Transform3D]
	for side in [-1.0, 1.0]:
		# the left wall's pieces face +x as built; the right wall's are turned half round to face -x
		var basis := Basis.IDENTITY if side < 0.0 else Basis(Vector3.UP, PI)
		var face: float = side * WALL_X.x
		for z in COLUMN_Z:
			kit["column"].append(Transform3D(basis, Vector3(face, 0.0, z)))
		for i in BAY_Z.size():
			var z := BAY_Z[i]
			kit["panel"].append(Transform3D(basis, Vector3(face, PANEL_Y, z)))
			kit["pipes"].append(Transform3D(basis, Vector3(face, PIPES_Y, z)))
			kit["machine" if i % 2 == 0 else "machine_low"].append(Transform3D(basis, Vector3(face, 0.0, z)))
	_vent_material = material.duplicate() as ShaderMaterial
	for piece: String in WALL_KIT:
		if piece == "panel":
			_panels = _add_multimesh(LaserFixtures._model_mesh(WALL_KIT[piece]), kit[piece], _vent_material).multimesh
			_panel_rest.assign(kit[piece])
		else:
			_add_multimesh(LaserFixtures._model_mesh(WALL_KIT[piece]), kit[piece], material)
	_small_gears = _add_multimesh(LaserFixtures._model_mesh(SMALL_GEAR_MODEL), small, metal_material).multimesh
	assert(SLAM_LAG_SECONDS.size() == anvils.size(), "one SLAM_LAG_SECONDS per piston")
	for anvil in anvils:
		_sparks.append(_add_sparks(anvil.origin))
	_landed.resize(anvils.size())
	_landed.fill(-1.0)

## Sets the sparks' colours: the left row cools to `left`, the right to `right`.
func set_spark_colors(left: Color, right: Color) -> void:
	for i in _sparks.size():
		var color := left if i < PISTON_Z.size() else right
		_sparks[i].color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))

## The spark emitter of the anvil whose foot is at `foot`: directed points round its die's top edge, at even angles,
## each pointing straight out from the die's centre and a little up.
func _add_sparks(foot: Vector3) -> CPUParticles3D:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var centre := foot + Vector3.UP * (ANVIL_TOP + SPARK_LIFT)
	for k in SPARK_DIRECTIONS:
		var angle := TAU * k / SPARK_DIRECTIONS
		var out := Vector3(cos(angle), 0.0, sin(angle))
		# on the square edge: stretched out to the side it meets
		points.append(centre + out / maxf(absf(out.x), absf(out.z)) * DIE_HALF)
		normals.append((out + Vector3.UP * SPARK_RISE).normalized())
	var sparks := CPUParticles3D.new()
	sparks.mesh = CutFlash.spark_mesh()
	sparks.particle_flag_align_y = true
	sparks.amount = SPARKS_PER_ANVIL
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
	var seconds := 0.0
	var cycle := 1.0
	var stroke := 0.0
	if bpm > 0.0:
		var beats := 1.0
		while beats * 60.0 / bpm < SLAM_MIN_CYCLE_SECONDS:
			beats *= 2.0
		seconds = beat * 60.0 / bpm
		cycle = beats * 60.0 / bpm
		stroke = smoothstep(SLAM_FROM, SLAM_FULL, intensity)
	for i in _sparks.size():
		var t := seconds - SLAM_LAG_SECONDS[i]
		var drop := hammer_drop(fposmod(t, cycle), cycle) * stroke
		var place := _hammers.get_instance_transform(i)
		place.origin.y = HAMMER_BOTTOM - STROKE * drop
		_hammers.set_instance_transform(i, place)
		# a new cycle has started for this hammer: it has just landed
		var landed := floorf(t / cycle)
		if bpm > 0.0 and landed != _landed[i]:
			_landed[i] = landed
			if stroke >= SPARK_FROM:
				_sparks[i].color_ramp.set_color(0, Color(1.0, 1.0, 1.0, stroke))
				_sparks[i].restart()

## Lights the vents: the upper row in `upper` (the diagonal lasers' colour), the lower in `left` or `right` (the
## waving lasers') by wall; black is off.
func set_vent_colors(upper: Color, left: Color, right: Color) -> void:
	_vent_material.set_shader_parameter(&"vent_upper_color", upper)
	_vent_material.set_shader_parameter(&"vent_left_color", left)
	_vent_material.set_shader_parameter(&"vent_right_color", right)

## Moves the wall panels for the song's `beat` at `bpm` and the show's `intensity` (0 to 1).
func breathe(beat: float, bpm: float, intensity: float) -> void:
	var depth := 0.0
	if bpm > 0.0:
		var beats := breath_beats(bpm)
		depth = BREATH_DEPTH * smoothstep(BREATH_FROM, BREATH_FULL, intensity) * (0.5 - 0.5 * cos(TAU * beat / beats))
	for i in _panel_rest.size():
		var rest := _panel_rest[i]
		# each panel's front is its local +x, toward the track
		_panels.set_instance_transform(i, Transform3D(rest.basis, rest.origin + rest.basis.x * depth))

## How many beats one breath of the walls takes at `bpm`: BREATH_BEATS, halved or doubled into BREATH_SECONDS.
static func breath_beats(bpm: float) -> float:
	var beats := BREATH_BEATS
	while beats * 60.0 / bpm > BREATH_SECONDS.y:
		beats *= 0.5
	while beats * 60.0 / bpm < BREATH_SECONDS.x:
		beats *= 2.0
	return beats

## Turns the drive gears for `delta` seconds at the show's `intensity` (0 to 1).
func turn_gears(delta: float, intensity: float) -> void:
	var turn := GEAR_SPEED * smoothstep(GEAR_FROM, GEAR_FULL, intensity) * delta
	for i in _large_gears.instance_count:
		# the left pair one way, the right pair mirrored
		var side := 1.0 if i == 0 else -1.0
		_turn(_large_gears, i, turn * side)
		_turn(_small_gears, i, -turn * side * GEAR_RATIO)

## Turns instance `i` of `gears` by `angle` radians about its axle (z).
static func _turn(gears: MultiMesh, i: int, angle: float) -> void:
	var place := gears.get_instance_transform(i)
	place.basis = place.basis.rotated(Vector3.BACK, angle)
	gears.set_instance_transform(i, place)

## Turns the gear rings for `delta` seconds at `speed` radians a second (EventDriver.ring_rot_speed, signed), each
## the other way from its neighbours.
func spin_rings(delta: float, speed: float) -> void:
	for i in _rings.instance_count:
		var direction := 1.0 if i % 2 == 0 else -1.0
		_turn(_rings, i, speed * RING_SPIN * direction * delta)

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

## Adds the vault: its shell along the whole hall, the ribs at every TRUSS_Z and the corner beams.
static func _vault(boxes: Array[Transform3D]) -> void:
	var crown_x := WALL_X.x - VAULT_RUN
	var crown_y := WALL_TOP + VAULT_RUN
	var hall := WALL_Z.x - WALL_Z.y
	var hall_z := (WALL_Z.x + WALL_Z.y) * 0.5
	# the crown, its underside at crown_y, overlapping the chamfers' ends
	boxes.append(_box(Vector3(0.0, crown_y + VAULT_SHELL * 0.5, hall_z), Vector3((crown_x + VAULT_SHELL) * 2.0, VAULT_SHELL, hall)))
	for side in [-1.0, 1.0]:
		var foot := Vector3(side * WALL_X.x, WALL_TOP, 0.0)
		var head := Vector3(side * crown_x, crown_y, 0.0)
		# the chamfer's shell, its inner face on the line from the wall's top to the crown's edge
		boxes.append(_slab(foot, head, side, VAULT_SHELL, VAULT_SHELL, hall, hall_z))
		for z in TRUSS_Z:
			boxes.append(_slab(foot, head, -side, RIB.x, 0.0, RIB.y, z))
		for corner in [foot, head]:
			var beam := Vector3(corner.x - side * CORNER_BEAM * 0.5, corner.y - CORNER_BEAM * 0.5, hall_z)
			boxes.append(_box(beam, Vector3(CORNER_BEAM, CORNER_BEAM, hall)))
	for z in TRUSS_Z:
		boxes.append(_box(Vector3(0.0, crown_y - RIB.x * 0.5, z), Vector3(crown_x * 2.0, RIB.x, RIB.y)))

## A slab along the line from `a` to `b` (in x and y), `thickness` thick off the line on the side whose x sign is
## `toward` (away from the hall's middle for the shell, toward it for a rib), `extra` longer at each end so the joints
## close, `depth` along the hall, centred on `z`.
static func _slab(a: Vector3, b: Vector3, toward: float, thickness: float, extra: float, depth: float, z: float) -> Transform3D:
	var along := Vector3(b.x - a.x, b.y - a.y, 0.0)
	var length := along.length() + extra * 2.0
	along = along.normalized()
	# the normal on the chosen side, in the x-y plane
	var normal := Vector3(-along.y, along.x, 0.0)
	if signf(normal.x) != signf(toward):
		normal = -normal
	var centre := (a + b) * 0.5 + normal * thickness * 0.5
	centre.z = z
	# a right-handed basis, so the box isn't mirrored (its faces would turn inside out)
	return Transform3D(Basis(along, normal, along.cross(normal)) * Basis.from_scale(Vector3(length, thickness, depth)), centre)

## Adds one side's floor, rail, piston posts and header, wall, ledge and end pier (side -1 left, 1 right).
static func _side(boxes: Array[Transform3D], side: float) -> void:
	boxes.append(_span(Vector3(side * FLOOR_X.x, -FLOOR_THICKNESS, FLOOR_Z.x), Vector3(side * FLOOR_X.y, 0.0, FLOOR_Z.y)))
	boxes.append(_span(Vector3(side * (RAIL_X - RAIL_WIDTH * 0.5), -SINK, RAIL_Z.x), Vector3(side * (RAIL_X + RAIL_WIDTH * 0.5), RAIL_TOP, RAIL_Z.y)))
	for z in POST_Z:
		boxes.append(_box(Vector3(side * PISTON_X, (HEADER_Y - SINK) * 0.5, z), Vector3(HEADER, HEADER_Y + SINK, HEADER)))
	boxes.append(_span(Vector3(side * (PISTON_X - HEADER * 0.5), HEADER_Y, POST_Z[0]), Vector3(side * (PISTON_X + HEADER * 0.5), HEADER_Y + HEADER, POST_Z[-1])))
	boxes.append(_span(Vector3(side * WALL_X.x, FOUNDATION.y, WALL_Z.x), Vector3(side * WALL_X.y, WALL_TOP, WALL_Z.y)))
	boxes.append(_span(Vector3(side * LEDGE_X, LEDGE_TOP - LEDGE_THICKNESS, WALL_Z.x), Vector3(side * WALL_X.x, LEDGE_TOP, WALL_Z.y)))
	boxes.append(_span(Vector3(side * PIER_X.x, FOUNDATION.y, FOUNDATION.z + 2.0), Vector3(side * PIER_X.y, WALL_TOP, FOUNDATION.w)))

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)

## A box between two opposite corners.
static func _span(a: Vector3, b: Vector3) -> Transform3D:
	return _box((a + b) * 0.5, (b - a).abs())
