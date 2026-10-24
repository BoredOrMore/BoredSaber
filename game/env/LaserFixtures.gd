extends Node3D
class_name LaserFixtures
## A moving-head light at the pivot of every laser (AGENTS.md "Light", rule 5), built like a real one: a yoke standing
## on the pedestal that only turns around the vertical toward the beam's heading, and the head between its arms that
## tilts to the beam, its lens where the beam leaves. A soft glow in the beam's colour sits in front of each lens,
## always facing the player, so the bright spot where the beam leaves shows even when the lens faces away (from the
## player's place the heads point up and away; Blender render, 2026-10-24). Each part is one MultiMesh; every frame
## they copy their laser's place and turn, and lens and glow take the beam's colour (black when the light is off).
## The heads and yokes are objects, not light: they stay when their light turns off (which hides the beam's node) and
## only go with the rest of the scenery (EventDriver: mixed reality, simple background).
## Models: game/models/laser_fixture(_yoke).glb, made by tools/models/laser_fixture.py; shaders LaserFixture.gdshader
## (head and yoke) and LaserFlare.gdshader (glow).

const HEAD := preload("res://game/models/laser_fixture.glb")
const YOKE := preload("res://game/models/laser_fixture_yoke.glb")
const BODY_SHADER := preload("res://game/env/LaserFixture.gdshader")
const FLARE_SHADER := preload("res://game/env/LaserFlare.gdshader")
## how far in front of the head's centre the glow sits (the lens is 0.26 m out), and its size in metres; halved with the
## fixture (tools/models/laser_fixture.py SIZE). Untuned.
const FLARE_FORWARD := 0.3
const FLARE_SIZE := 0.8

var _lasers: Array[Node3D] = []
var _materials: Array[ShaderMaterial] = []
var _heads: MultiMesh
var _yokes: MultiMesh
var _flares: MultiMesh

## One fixture per laser; `materials[i]` is the beam material whose light_color laser i shows.
func setup(lasers: Array[Node3D], materials: Array[ShaderMaterial]) -> void:
	_lasers = lasers
	_materials = materials
	var body := ShaderMaterial.new()
	body.shader = BODY_SHADER
	var flare := ShaderMaterial.new()
	flare.shader = FLARE_SHADER
	var quad := QuadMesh.new()
	_heads = _add_part(_model_mesh(HEAD), body)
	_yokes = _add_part(_model_mesh(YOKE), body)
	_flares = _add_part(quad, flare)

static func _model_mesh(scene: PackedScene) -> Mesh:
	var model: Node = scene.instantiate()
	var mesh: Mesh = (model.find_children("*", "MeshInstance3D")[0] as MeshInstance3D).mesh
	model.free()
	return mesh

func _add_part(mesh: Mesh, material: ShaderMaterial) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = _lasers.size()
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh

func _process(_delta: float) -> void:
	for i in _lasers.size():
		var laser := _lasers[i]
		var at := laser.global_position
		var beam := -laser.global_basis.z.normalized()
		var heading := Vector3(beam.x, 0.0, beam.z)
		if heading.length_squared() < 1e-4:
			heading = Vector3.FORWARD
		var color := _materials[i].get_shader_parameter(&"light_color") as Color
		_heads.set_instance_transform(i, Transform3D(
				Basis.looking_at(beam, Vector3.UP if absf(beam.y) < 0.999 else Vector3.FORWARD), at))
		_yokes.set_instance_transform(i, Transform3D(Basis.looking_at(heading.normalized(), Vector3.UP), at))
		_flares.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * FLARE_SIZE), at + beam * FLARE_FORWARD))
		for part in [_heads, _yokes, _flares]:
			(part as MultiMesh).set_instance_custom_data(i, color)
