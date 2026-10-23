extends Node3D

const MISS_POP_SECONDS := 0.08
const MISS_HOLD_SECONDS := 0.12
const MISS_FADE_SECONDS := 0.3
const MISS_DRIFT := Vector3(0, -0.08, 0)

var text_mesh: TextMesh
var player: AnimationPlayer
var miss_mark: MeshInstance3D
var miss_material: ShaderMaterial
var _miss_tween: Tween

func _ready():
	player = $AnimationPlayer as AnimationPlayer
	# gotta make a new text mesh for each one, otherwise they will all ref
	# the same one.  the result of that is if you change the text of one, you
	# change the text of all.
	var instance := $mesh_instance as MeshInstance3D
	instance.mesh = instance.mesh.duplicate(true) as TextMesh
	text_mesh = instance.mesh as TextMesh
	miss_mark = $miss_mark as MeshInstance3D
	miss_mark.mesh = miss_mark.mesh.duplicate(true) as QuadMesh
	miss_material = (miss_mark.mesh as QuadMesh).material as ShaderMaterial

func show_points(_position: Vector3, _rotation:float, value: String, color: Color):
	global_position = _position
	rotation.y = -_rotation
	if _miss_tween:
		_miss_tween.kill()
	miss_mark.visible = false
	if value == "x":
		_show_miss(color)
		return
	($mesh_instance as MeshInstance3D).visible = true
	text_mesh.text = value
	(text_mesh.material as StandardMaterial3D).albedo_color = color
	player.stop()
	player.play("hit")

## Pops a clean X in, holds it briefly, then fades it out while it sinks a little.
func _show_miss(color: Color) -> void:
	player.stop()
	($mesh_instance as MeshInstance3D).visible = false
	miss_material.set_shader_parameter(&"color", color)
	miss_material.set_shader_parameter(&"alpha", 1.0)
	miss_mark.position = Vector3.ZERO
	miss_mark.scale = Vector3.ONE * 0.6
	miss_mark.visible = true
	_miss_tween = create_tween()
	_miss_tween.tween_property(miss_mark, ^"scale", Vector3.ONE, MISS_POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_miss_tween.tween_interval(MISS_HOLD_SECONDS)
	_miss_tween.set_parallel()
	_miss_tween.tween_property(miss_mark, ^"position", MISS_DRIFT, MISS_FADE_SECONDS)
	_miss_tween.tween_method(func(a: float) -> void: miss_material.set_shader_parameter(&"alpha", a), 1.0, 0.0, MISS_FADE_SECONDS)
	_miss_tween.chain().tween_callback(miss_mark.hide)
