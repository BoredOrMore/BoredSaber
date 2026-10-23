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
const SPARKS := 12
const SPARK_SIZE := 0.012
const SPARK_SPEED_MIN := 1.0
const SPARK_SPEED_MAX := 2.5
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

func _make_sparks() -> CPUParticles3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * SPARK_SIZE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var sparks := CPUParticles3D.new()
	sparks.mesh = mesh
	sparks.amount = SPARKS
	sparks.lifetime = 0.3
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
