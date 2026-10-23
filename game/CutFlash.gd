class_name CutFlash
extends Node3D
## A thin bright streak across a note where a saber cut it, along the swing, in the saber's colour; it flashes
## and fades in FADE_SECONDS. A few quads reused in turn, so a burst of cuts never allocates. Unshaded and added
## on top, so it costs only the pixels it covers. Sizes in metres, untuned.

const SHADER := preload("res://game/CutFlash.gdshader")
const COUNT := 6
const LENGTH := 0.9
const WIDTH := 0.05
const FADE_SECONDS := 0.18

var _quads: Array[MeshInstance3D] = []
var _tweens: Array[Tween] = []
var _next := 0

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
