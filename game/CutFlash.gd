class_name CutFlash
extends Node3D
## Sparks off a cut, as the player drew them: they leave the whole cut line through the note (not one point), most
## thrown back against the swing (up for a down cut) in a fountain that spreads and falls away to the sides under
## gravity, and a few carried on along the swing. Hot white cooling to the saber's colour (CPU particles with
## short trails, SparkStreak.gdshader). COUNT pairs of emitters reused in turn, so a burst of cuts never
## allocates. Nothing stays hanging where the cut was: a flat streak left there looked fake to the player. Sizes
## in metres, untuned.

const COUNT := 6
## a spark's trail: its width and length in metres at scale 1 (two crossed strips along its velocity)
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## half the length of the cut line the sparks leave from, along the swing through the note
const CUT_LINE_HALF := 0.18
## the fountain thrown back against the swing
const FOUNTAIN_SPARKS := 28
const FOUNTAIN_SPEED_MIN := 2.0
const FOUNTAIN_SPEED_MAX := 4.5
const FOUNTAIN_SPREAD_DEG := 40.0
const FOUNTAIN_SECONDS := 0.5
## the few carried on along the swing
const SPRAY_SPARKS := 8
const SPRAY_SPEED_MIN := 2.5
const SPRAY_SPEED_MAX := 5.0
const SPRAY_SPREAD_DEG := 15.0
const SPRAY_SECONDS := 0.4
## pulls the sparks into falling arcs (m/s²)
const SPARK_GRAVITY := 9.0
## The swing drives the sparks: at REFERENCE_SWING (m/s at the blade tip) they fly at the speeds above; a harder or
## softer swing scales their speed (so the fountain's height) by its share of that, within SWING_SCALE_MIN..MAX,
## widens or narrows the fountain toward FOUNTAIN_SPREAD_MAX_DEG, and pulls them down faster or slower.
const REFERENCE_SWING := 5.0
const SWING_SCALE_MIN := 0.5
const SWING_SCALE_MAX := 2.0
const FOUNTAIN_SPREAD_MIN_DEG := 20.0
const FOUNTAIN_SPREAD_MAX_DEG := 60.0
## sparks vary in length (and width) by this much
const SPARK_SCALE_MIN := 0.5
const SPARK_SCALE_MAX := 1.3

var _next := 0
var _fountains: Array[CPUParticles3D] = []
var _sprays: Array[CPUParticles3D] = []

func _ready() -> void:
	for i in COUNT:
		# each emitter's local y is the swing reversed (set per cut), so +y throws back, -y carries on
		var fountain := _make_sparks(FOUNTAIN_SPARKS, FOUNTAIN_SECONDS, FOUNTAIN_SPEED_MIN, FOUNTAIN_SPEED_MAX)
		fountain.spread = FOUNTAIN_SPREAD_DEG
		fountain.direction = Vector3.UP
		_fountains.append(fountain)
		var spray := _make_sparks(SPRAY_SPARKS, SPRAY_SECONDS, SPRAY_SPEED_MIN, SPRAY_SPEED_MAX)
		spray.spread = SPRAY_SPREAD_DEG
		spray.direction = Vector3.DOWN
		_sprays.append(spray)

## A spark with a trail for CPU particles with particle_flag_align_y: two crossed strips along +y (the velocity),
## the head at the top, so it shows from every side but straight along its path.
static func spark_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for across: Vector3 in [Vector3(SPARK_WIDTH * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, SPARK_WIDTH * 0.5)]:
		var tail := Vector3(0.0, -SPARK_TRAIL, 0.0)
		vertices.append_array([tail - across, tail + across, across, tail - across, across, -across])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SPARK_SHADER
	mesh.surface_set_material(0, material)
	return mesh

func _make_sparks(amount: int, seconds: float, speed_min: float, speed_max: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.mesh = spark_mesh()
	sparks.particle_flag_align_y = true
	sparks.amount = amount
	sparks.lifetime = seconds
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.local_coords = false
	sparks.initial_velocity_min = speed_min
	sparks.initial_velocity_max = speed_max
	sparks.scale_amount_min = SPARK_SCALE_MIN
	sparks.scale_amount_max = SPARK_SCALE_MAX
	sparks.gravity = Vector3(0.0, -SPARK_GRAVITY, 0.0)
	# from anywhere along the cut line (the emitter's local y)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.005, CUT_LINE_HALF, 0.005)
	sparks.color_ramp = Gradient.new()
	add_child(sparks)
	return sparks

## The swing as the player sees it: its part across the line of sight to the cut, so the spray flies the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(sight: Vector3, swing: Vector3) -> Vector3:
	var across := swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends sparks off the cut line through `at` along the swing: a fountain back against it and a spray along it.
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	var camera := get_viewport().get_camera_3d()
	var sight := (at - camera.global_position).normalized() if camera else Vector3.FORWARD
	# local y: against the swing as the player sees it; z: toward the player
	var back := -_across_view(sight, swing)
	var toward := -sight
	var basis := Basis(back.cross(toward), back, toward).orthonormalized()
	var swing_scale := clampf(swing.length() / REFERENCE_SWING, SWING_SCALE_MIN, SWING_SCALE_MAX)
	var fountain := _fountains[i]
	var spray := _sprays[i]
	fountain.initial_velocity_min = FOUNTAIN_SPEED_MIN * swing_scale
	fountain.initial_velocity_max = FOUNTAIN_SPEED_MAX * swing_scale
	fountain.spread = lerpf(FOUNTAIN_SPREAD_MIN_DEG, FOUNTAIN_SPREAD_MAX_DEG,
			inverse_lerp(SWING_SCALE_MIN, SWING_SCALE_MAX, swing_scale))
	spray.initial_velocity_min = SPRAY_SPEED_MIN * swing_scale
	spray.initial_velocity_max = SPRAY_SPEED_MAX * swing_scale
	for sparks: CPUParticles3D in [fountain, spray]:
		sparks.gravity = Vector3(0.0, -SPARK_GRAVITY * sqrt(swing_scale), 0.0)
		sparks.global_transform = Transform3D(basis, at)
		sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0))
		sparks.color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
		sparks.restart()
