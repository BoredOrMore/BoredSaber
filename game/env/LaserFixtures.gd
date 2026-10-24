extends MultiMeshInstance3D
class_name LaserFixtures
## A moving-head light at the pivot of every laser (AGENTS.md "Light", rule 5): the beam leaves from its lens, and the
## head turns with the beam around its own centre, as a real moving head does. All drawn in one MultiMesh; each frame
## every head copies its laser's place and turn, and its lens takes the beam's colour (black when the light is off).
## A head whose laser is hidden shrinks to nothing. The model is game/models/laser_fixture.glb, made by
## tools/models/laser_fixture.py; LaserFixture.gdshader draws it.

const MODEL := preload("res://game/models/laser_fixture.glb")
const SHADER := preload("res://game/env/LaserFixture.gdshader")

var _lasers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []

## One head per laser; `materials[i]` is the beam material whose light_color laser i shows.
func setup(lasers: Array[Node3D], materials: Array[ShaderMaterial]) -> void:
	_lasers = lasers
	_materials = materials
	var model := MODEL.instantiate()
	var mesh := (model.find_children("*", "MeshInstance3D")[0] as MeshInstance3D).mesh
	model.free()
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = lasers.size()

func _process(_delta: float) -> void:
	for i in _lasers.size():
		var laser := _lasers[i]
		if laser.is_visible_in_tree():
			multimesh.set_instance_transform(i, Transform3D(laser.global_basis.orthonormalized(), laser.global_position))
			multimesh.set_instance_custom_data(i, _materials[i].get_shader_parameter(&"light_color") as Color)
		else:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), laser.global_position))
