class_name CutFlash
extends Node3D
## Sparks off a cut, as in Beat Saber: dozens of hair-thin streaks bursting out all round the cut, across the
## player's view, and a narrower spray flying on along the swing. Hot white cooling to the saber's colour, gone in
## well under half a second (CPU particles with short trails, SparkStreak.gdshader). COUNT pairs of emitters
## reused in turn, so a burst of cuts never allocates. Nothing stays hanging where the cut was: a flat streak left
## there looked fake to the player. Sizes in metres, untuned.

const COUNT := 6
## a spark's trail: its width and length in metres at scale 1 (two crossed strips along its velocity)
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## the burst all round the cut, flattened into the plane facing the player
const BURST_SPARKS := 48
const BURST_SPEED_MIN := 1.5
const BURST_SPEED_MAX := 4.0
const BURST_SECONDS := 0.3
## the spray along the swing
const SPRAY_SPARKS := 16
const SPRAY_SPEED_MIN := 3.0
const SPRAY_SPEED_MAX := 6.0
const SPRAY_SPREAD_DEG := 15.0
const SPRAY_SECONDS := 0.4
## sparks vary in length (and width) by this much
const SPARK_SCALE_MIN := 0.5
const SPARK_SCALE_MAX := 1.3

var _next := 0
var _bursts: Array[CPUParticles3D] = []
var _sprays: Array[CPUParticles3D] = []

func _ready() -> void:
	for i in COUNT:
		var burst := _make_sparks(BURST_SPARKS, BURST_SECONDS, BURST_SPEED_MIN, BURST_SPEED_MAX)
		burst.spread = 180.0
		burst.flatness = 1.0
		burst.direction = Vector3.RIGHT
		_bursts.append(burst)
		var spray := _make_sparks(SPRAY_SPARKS, SPRAY_SECONDS, SPRAY_SPEED_MIN, SPRAY_SPEED_MAX)
		spray.spread = SPRAY_SPREAD_DEG
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
	sparks.gravity = Vector3(0.0, -3.0, 0.0)
	sparks.color_ramp = Gradient.new()
	add_child(sparks)
	return sparks

## The swing as the player sees it: its part across the line of sight to the cut, so the spray flies the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(sight: Vector3, swing: Vector3) -> Vector3:
	var across := swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends sparks from a point on the cut: a burst all round it and a spray along the swing.
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	var camera := get_viewport().get_camera_3d()
	var sight := (at - camera.global_position).normalized() if camera else Vector3.FORWARD
	var burst := _bursts[i]
	var spray := _sprays[i]
	# the burst's plane (its local x-y, as flatness keeps it) faces the player
	var up := Vector3.UP if absf(sight.y) < 0.99 else Vector3.FORWARD
	burst.global_transform = Transform3D(Basis.looking_at(sight, up), at)
	spray.global_position = at
	spray.direction = _across_view(sight, swing)
	for sparks: CPUParticles3D in [burst, spray]:
		sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0))
		sparks.color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
		sparks.restart()
