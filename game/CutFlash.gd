class_name CutFlash
extends Node3D
## A burst of sparks flying off a cut along the swing, hot white cooling to the saber's colour (SPARKS per cut, CPU
## particles with short trails). COUNT emitters reused in turn, so a burst of cuts never allocates. A flat streak
## left hanging where the cut was looked fake to the player and was taken out. Sizes in metres, untuned.

const COUNT := 6
const SPARKS := 20
## a spark's trail: its width and length in metres (two crossed strips along its velocity, SparkStreak.gdshader)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
const SPARK_SPEED_MIN := 3.0
const SPARK_SPEED_MAX := 6.75
const SPARK_SPREAD_DEG := 15.0

var _next := 0
var _sparks: Array[CPUParticles3D] = []

func _ready() -> void:
	for i in COUNT:
		_sparks.append(_make_sparks())

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

func _make_sparks() -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.mesh = spark_mesh()
	sparks.particle_flag_align_y = true
	sparks.amount = SPARKS
	sparks.lifetime = 0.4
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.local_coords = false
	sparks.spread = SPARK_SPREAD_DEG
	sparks.initial_velocity_min = SPARK_SPEED_MIN
	sparks.initial_velocity_max = SPARK_SPEED_MAX
	sparks.gravity = Vector3(0.0, -4.0, 0.0)
	sparks.color_ramp = Gradient.new()
	add_child(sparks)
	return sparks

## The swing as the player sees it: its part across the line of sight to the cut, so the sparks fly the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(at: Vector3, swing: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var across := swing
	if camera:
		var sight := (at - camera.global_position).normalized()
		across = swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends a burst of sparks from a point on the cut along the swing.
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	var sparks := _sparks[i]
	sparks.global_position = at
	sparks.direction = _across_view(at, swing)
	sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0))
	sparks.color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	sparks.restart()
