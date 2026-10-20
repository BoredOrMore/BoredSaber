extends Node3D
class_name ClassicRig
## The Classic environment's structure, which its lights are mounted on (AGENTS.md "Light", rule 5): a portal
## frame behind each square light frame, so those bars run along steel beams like Beat Saber's tunnel, and a
## pedestal under every diagonal and waving laser fixture, so the beams leave a surface instead of empty air.
## A smaller frame stands around the player, the tunnel's first gate.
## Dark boxes drawn in one MultiMesh with the scenery's fog shader. Sizes in metres; fixture positions come
## from event_driver.tscn. Untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
## the square light frames sit at x +-11 (side bars from y -4.8 to 4.8) and y 11, every 10 m from z -10 to -60;
## the frames just outside them
const FRAME_Z: Array[float] = [-10.0, -20.0, -30.0, -40.0, -50.0, -60.0]
const FRAME_HALF_WIDTH := 11.6
const FRAME_TOP := 11.6
const FRAME_BOTTOM := -5.0
const BEAM := 0.5
## Near the player, out of the note lane and clear of the view ahead, a few pieces stand within a few metres so
## they move against the far scenery as the head moves (parallax), which makes the player feel they stand in the
## place rather than in front of it.
## The gate around the player: its z (the player stands at 1), half width and top.
const NEAR_FRAME := Vector3(0.5, 3.5, 4.5)
## diagonal laser fixtures (x, z) and waving laser fixtures (x, z), with the pedestal under each
const DIAGONAL_FIXTURES: Array[Vector2] = [
	Vector2(4.57, -30.0), Vector2(4.57, -35.0), Vector2(4.57, -40.0), Vector2(4.57, -45.0), Vector2(4.57, -50.0),
	Vector2(-4.43, -30.0), Vector2(-4.43, -35.0), Vector2(-4.43, -40.0), Vector2(-4.43, -45.0), Vector2(-4.43, -50.0),
]
const WAVING_FIXTURES: Array[Vector2] = [
	Vector2(-12.43, -21.0), Vector2(-12.43, -24.0), Vector2(-12.43, -27.0), Vector2(-12.43, -30.0),
	Vector2(12.43, -30.0), Vector2(12.43, -27.0), Vector2(12.43, -24.0), Vector2(12.43, -21.0),
]
const PEDESTAL := Vector3(1.6, 3.0, 1.2)
const PEDESTAL_TOP := 0.05

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	for z in FRAME_Z:
		var height := FRAME_TOP - FRAME_BOTTOM
		for side in [-1.0, 1.0]:
			boxes.append(_box(Vector3(side * FRAME_HALF_WIDTH, FRAME_BOTTOM + height * 0.5, z), Vector3(BEAM, height, BEAM)))
		boxes.append(_box(Vector3(0.0, FRAME_TOP, z), Vector3(FRAME_HALF_WIDTH * 2.0 + BEAM, BEAM, BEAM)))
	var near_height := NEAR_FRAME.z - FRAME_BOTTOM
	for side in [-1.0, 1.0]:
		boxes.append(_box(Vector3(side * NEAR_FRAME.y, FRAME_BOTTOM + near_height * 0.5, NEAR_FRAME.x), Vector3(BEAM, near_height, BEAM)))
	boxes.append(_box(Vector3(0.0, NEAR_FRAME.z, NEAR_FRAME.x), Vector3(NEAR_FRAME.y * 2.0 + BEAM, BEAM, BEAM)))
	for fixture in DIAGONAL_FIXTURES + WAVING_FIXTURES:
		boxes.append(_box(Vector3(fixture.x, PEDESTAL_TOP - PEDESTAL.y * 0.5, fixture.y), PEDESTAL))
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
