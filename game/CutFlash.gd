class_name CutFlash
extends Node3D
## A thin bright streak across a note where a saber cut it, along the swing, in the saber's colour; it flashes
## and fades in FADE_SECONDS. A small burst of sparks flies off the cut along the swing, hot white cooling to the
## saber's colour (SPARKS per cut, CPU particles). A few quads reused in turn, so a burst of cuts never allocates. Unshaded and added
## on top, so it costs only the pixels it covers. Sizes in metres, untuned.

const SHADER := preload("res://game/CutFlash.gdshader")
const COUNT := 6
const LENGTH := 0.9
const WIDTH := 0.05
const FADE_SECONDS := 0.18
const SPARKS := 20
## a spark's trail: its width and length in metres (two crossed strips along its velocity, SparkStreak.gdshader)
const SPARK_WIDTH := 0.016
const SPARK_TRAIL := 0.2
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
const SPARK_SPEED_MIN := 2.0
const SPARK_SPEED_MAX := 4.5
const SPARK_SPREAD_DEG := 35.0

var _quads: Array[MeshInstance3D] = []
var _tweens: Array[Tween] = []
var _next := 0
var _sparks: Array[CPUParticles3D] = []

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(LENGTH, WIDTH)
	for i in COUNT:
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = SHADER
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visible = false
		add_child(instance)
		_quads.append(instance)
		_tweens.append(null)
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

## Shows a streak centred at a point on the cut, lying along the swing's direction (seen from the front).
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	var quad := _quads[i]
	var material := quad.material_override as ShaderMaterial
	if _tweens[i]:
		_tweens[i].kill()
	quad.global_position = at
	quad.rotation = Vector3(0.0, 0.0, atan2(swing.y, swing.x))
	material.set_shader_parameter(&"color", color)
	quad.visible = true
	var tween := quad.create_tween()
	tween.tween_method(func(v: float) -> void: material.set_shader_parameter(&"fade", v), 1.0, 0.0, FADE_SECONDS)
	tween.tween_callback(quad.hide)
	_tweens[i] = tween
	var sparks := _sparks[i]
	sparks.global_position = at
	sparks.direction = swing.normalized() if swing.length() > 1e-4 else Vector3.UP
	sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0))
	sparks.color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	sparks.restart()
