extends Node3D
class_name NeonGridRig
## The Neon Grid environment's structure, which its lights are mounted on (AGENTS.md "Light", rule 5): a low stage
## on the horizon that the diagonal lasers fan out of, a dark backdrop wall behind it that the square bars run
## across as synthwave stripes, and poles along the grid's edges with a lamp housing on top for each waving laser.
## Dark boxes in one MultiMesh with the scenery's fog shader. Positions shared with EventDriver's Neon Grid rig.
## Sizes in metres, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const STAGE_CENTRE := Vector3(0.0, -0.4, -72.0)
const STAGE_SIZE := Vector3(20.0, 1.0, 5.0)
## the top of the stage, where the fan's fixtures sit
const STAGE_TOP := 0.1
const BACKDROP_CENTRE := Vector3(0.0, 6.0, -82.0)
const BACKDROP_SIZE := Vector3(26.0, 14.0, 0.6)
## the backdrop's front face, where the stripes are mounted
const BACKDROP_FRONT := -81.6
const POLE_X := 14.0
const POLE_Z: Array[float] = [-20.0, -28.0, -36.0, -44.0]
const POLE_HEIGHT := 3.0
const POLE_SIZE := 0.3
const LAMP_SIZE := Vector3(0.6, 0.4, 0.6)

func _ready() -> void:
	var boxes: Array[Transform3D] = [
		_box(STAGE_CENTRE, STAGE_SIZE),
		_box(BACKDROP_CENTRE, BACKDROP_SIZE),
	]
	for z in POLE_Z:
		for side in [-1.0, 1.0]:
			boxes.append(_box(Vector3(side * POLE_X, POLE_HEIGHT * 0.5 - 0.5, z), Vector3(POLE_SIZE, POLE_HEIGHT + 1.0, POLE_SIZE)))
			boxes.append(_box(Vector3(side * POLE_X, POLE_HEIGHT, z), LAMP_SIZE))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		multimesh.set_instance_transform(i, boxes[i])
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)
