extends Node3D
class_name NightCityRig
## The Night City environment's structure, which its lights are mounted on (AGENTS.md "Light", rule 5): dark
## buildings in a row on each side of the track, their inner faces 19 m out, so the skyline straight ahead stays
## clear. Searchlights (the waving lasers) stand on the roofs, the diagonal lasers cross from the roofs' inner
## edges, and the square bars trim the roof edges facing the track. Dark boxes in one MultiMesh with the scenery's
## fog shader. Sizes in metres, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const INNER_FACE_X := 19.0
const DEPTH_X := 7.0
## [z centre, length along the track, height] of each building, left side then right side
const LEFT: Array[Vector3] = [Vector3(-20.0, 9.0, 10.0), Vector3(-32.0, 10.0, 14.0), Vector3(-44.0, 9.0, 11.0), Vector3(-56.0, 10.0, 16.0)]
## The player stands on a rooftop: a low parapet runs along each side of it.
## Near the player, out of the note lane and clear of the view ahead, a few pieces stand within a few metres so
## they move against the far scenery as the head moves (parallax), which makes the player feel they stand in the
## place rather than in front of it.
const PARAPET_X := 4.0
const PARAPET_HEIGHT := 1.0
const PARAPET_THICKNESS := 0.3
## the parapet's z from and to; the player stands at 1
const PARAPET_Z := Vector2(5.0, -5.0)
const RIGHT: Array[Vector3] = [Vector3(-20.0, 9.0, 13.0), Vector3(-32.0, 10.0, 10.0), Vector3(-44.0, 9.0, 15.0), Vector3(-56.0, 10.0, 11.0)]

## The buildings of one side (-1 left, 1 right) as [z centre, length, height].
static func buildings(side: float) -> Array[Vector3]:
	return LEFT if side < 0.0 else RIGHT

## The roof height at a point along the track on one side, or 0 between buildings.
static func roof_at(side: float, z: float) -> float:
	for b in buildings(side):
		if absf(z - b.x) <= b.y * 0.5:
			return b.z
	return 0.0

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for b in buildings(side):
			var centre := Vector3(side * (INNER_FACE_X + DEPTH_X * 0.5), b.z * 0.5 - 1.0, b.x)
			boxes.append(Transform3D(Basis.from_scale(Vector3(DEPTH_X, b.z + 2.0, b.y)), centre))
	for side in [-1.0, 1.0]:
		var length := PARAPET_Z.x - PARAPET_Z.y
		boxes.append(Transform3D(Basis.from_scale(Vector3(PARAPET_THICKNESS, PARAPET_HEIGHT + 1.0, length)),
			Vector3(side * PARAPET_X, (PARAPET_HEIGHT - 1.0) * 0.5, (PARAPET_Z.x + PARAPET_Z.y) * 0.5)))
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
