extends Node3D
class_name NeonGridRig
## The Neon Grid environment's structure, which its lights are mounted on (AGENTS.md "Light", rule 5): two low
## stages on the horizon, one each side of the sun, that the diagonal lasers fan out of, and poles along the grid's
## edges with a lamp housing on top for each waving laser, joined by light rails (the square bars). Nothing stands
## in front of the horizon and sky, and no beam crosses the sun: that view is the environment's signature, and
## lights over the sun made the player dizzy (they asked for the sun to be the focal point).
## Dark boxes in one MultiMesh with the scenery's fog shader. Positions shared with EventDriver's Neon Grid rig.
## Sizes in metres, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
## The sun (tools/bake_neon_grid_sky.py) spans about 11.5 degrees around straight ahead and its glow about 9
## more; the stages stand 28 degrees to each side, so their fans start clear of it and only spread outward.
const STAGE_X := 38.0
const STAGE_CENTRE_Z := -72.0
const STAGE_SIZE := Vector3(10.0, 1.0, 5.0)
## the top of the stage, where the fan's fixtures sit
const STAGE_TOP := 0.1
const POLE_X := 14.0
## Close enough that a waving laser leaning in toward the track crosses it high overhead, not over the sun.
const POLE_Z: Array[float] = [-8.0, -14.0, -20.0, -26.0]
const POLE_HEIGHT := 3.0
const POLE_SIZE := 0.3
const LAMP_SIZE := Vector3(0.6, 0.4, 0.6)
## Near the player, out of the note lane and clear of the view ahead, a few pieces stand within a few metres so
## they move against the far scenery as the head moves (parallax), which makes the player feel they stand in the
## place rather than in front of it.
## Two more poles stand on each side of the player, the grid's near edge; they hold no laser.
const NEAR_POLE_X := 4.0
const NEAR_POLE_Z: Array[float] = [3.0, -3.0]

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		boxes.append(_box(Vector3(side * STAGE_X, -0.4, STAGE_CENTRE_Z), STAGE_SIZE))
	for z in POLE_Z:
		for side in [-1.0, 1.0]:
			boxes.append(_box(Vector3(side * POLE_X, POLE_HEIGHT * 0.5 - 0.5, z), Vector3(POLE_SIZE, POLE_HEIGHT + 1.0, POLE_SIZE)))
			boxes.append(_box(Vector3(side * POLE_X, POLE_HEIGHT, z), LAMP_SIZE))
	for z in NEAR_POLE_Z:
		for side in [-1.0, 1.0]:
			boxes.append(_box(Vector3(side * NEAR_POLE_X, POLE_HEIGHT * 0.5 - 0.5, z), Vector3(POLE_SIZE, POLE_HEIGHT + 1.0, POLE_SIZE)))
			boxes.append(_box(Vector3(side * NEAR_POLE_X, POLE_HEIGHT, z), LAMP_SIZE))
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
