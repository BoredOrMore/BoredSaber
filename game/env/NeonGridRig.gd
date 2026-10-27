@tool
extends Node3D
class_name NeonGridRig
## The Neon Grid environment (owner, 2026-10-26: concept 2, megastructure arches; blockout): the endless grid at
## sunset is the building site of arches far bigger than anything human. Three arches, all different, none in front of
## the sun: A, 300 m tall, spans the grid behind the player (they have passed under it); B, 350 m, stands far ahead on
## the left, its span along the track, leaning out; C, on the right, is unfinished, its half-built curve ending in a
## tower crane. Near the player, site clutter at human size (a site cabin, barrier blocks, stacked girders) and the
## survey masts makes the arches read as enormous. Nothing mirrors across the track.
## The lights hang on things that belong to the site (AGENTS.md "Light", rule 5: the carrier belongs to the world):
## the diagonal lasers are floodlights at B's and C's footings, fanning up and away from the sun; the left waving
## lasers are survey beacons on masts along the grid; the right ones the crane's work lights along its jib; the square
## bars' light runs in strips along the arches' inner edges (_add_strips). The sun and horizon stay clear.
## Dark boxes in one MultiMesh with the scenery's shader. Positions shared with EventDriver's Neon Grid rig.
## Sizes in metres, blockout, untuned. A tool script, so the arches show in the editor too (built, not saved: no owner).

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const ARCH_STRIP := preload("res://game/env/ArchStrip.gdshader")
## The arches' light strips (ArchStrip.gdshader): a segment on each of an arch's boxes, along its inner face, this wide
## (part of the arch's width) and thick; one MultiMesh, one draw call. EventDriver sets the material's light and level.
const STRIP_WIDTH := 0.3
const STRIP_THICK := 0.6
var strip_material: ShaderMaterial
## An arch: [centre of its span on the ground (x, z), radius, span direction (0 across the track, 1 along it), lean
## (degrees, turned about its span's line: + tips its top toward -x, or toward +z for an arch across the track), how
## much of the half circle is built (1 all), section (width, depth)].
const ARCH_A := [Vector2(110.0, 160.0), 300.0, 0.0, -6.0, 1.0, Vector2(18.0, 12.0)]
const ARCH_B := [Vector2(-450.0, -420.0), 350.0, 1.0, 15.0, 1.0, Vector2(26.0, 18.0)]
const ARCH_C := [Vector2(450.0, -450.0), 260.0, 1.0, -8.0, 0.62, Vector2(16.0, 12.0)]
## boxes along each arch's half circle
const ARCH_SEGMENTS := 28
## the arch's parts (doc/assets/arch_parts/spec.md); the section model's axes (Blender's x, z up, -y along: in Godot x,
## y along, -z outward) turned to the boxes' (x across, y inward, z along); the scaffold's foot this far below C's end
const ARCH_SECTION := preload("res://game/models/arch_section.glb")
const ARCH_FOOTING := preload("res://game/models/arch_footing.glb")
const ARCH_SCAFFOLD := preload("res://game/models/arch_scaffold.glb")
const ARCH_SECTION_AXES := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, -1.0, 0.0))
const SCAFFOLD_BELOW_END := 20.0
## The tower crane at C's unfinished end (doc/assets/tower_crane/spec.md): the model stands on the end; its jib's root
## is CRANE_JIB_Y above its foot, the jib CRANE_JIB.x long toward the track, the work lights CRANE_JIB.y under it.
const TOWER_CRANE := preload("res://game/models/tower_crane.glb")
const CRANE_JIB_Y := 32.6
const CRANE_JIB := Vector2(70.0, 3.0)
## Survey masts on the left (x, z, height), uneven, carrying the left waving lasers' beacons at their tops
## (doc/assets/survey_mast/spec.md: modelled SURVEY_MAST_HEIGHT tall, scaled to each height; one MultiMesh).
const SURVEY_MAST := preload("res://game/models/survey_mast.glb")
const SURVEY_MAST_HEIGHT := 10.0
const SURVEY_MASTS: Array[Vector3] = [Vector3(-9.0, -6.0, 9.0), Vector3(-15.0, -19.0, 12.0), Vector3(-11.0, -33.0, 8.0),
	Vector3(-24.0, -46.0, 14.0)]
## each mast turned differently, so their guys and panels don't line up
const SURVEY_MAST_TURNS: Array[float] = [0.4, 2.1, 1.0, 3.6]
## The site's props near the player, for scale (doc/assets/site_props/spec.md): a container behind on the left,
## barriers and a pile of beams on the right, one mesh built where they stand.
const SITE_PROPS := preload("res://game/models/site_props.glb")

func _ready() -> void:
	var boxes: Array[Transform3D] = []
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
	var masts := MultiMesh.new()
	masts.transform_format = MultiMesh.TRANSFORM_3D
	masts.mesh = LaserFixtures._model_mesh(SURVEY_MAST)
	masts.instance_count = SURVEY_MASTS.size()
	for i in SURVEY_MASTS.size():
		var m := SURVEY_MASTS[i]
		masts.set_instance_transform(i, Transform3D(Basis(Vector3.UP, SURVEY_MAST_TURNS[i % SURVEY_MAST_TURNS.size()])
			.scaled(Vector3.ONE * m.z / SURVEY_MAST_HEIGHT), Vector3(m.x, 0.0, m.y)))
	var mast_instance := MultiMeshInstance3D.new()
	mast_instance.multimesh = masts
	mast_instance.material_override = material
	mast_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mast_instance)
	_add_arches(material)
	var props := MeshInstance3D.new()
	props.mesh = LaserFixtures._model_mesh(SITE_PROPS)
	props.material_override = material
	props.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(props)
	var crane := MeshInstance3D.new()
	crane.mesh = LaserFixtures._model_mesh(TOWER_CRANE)
	crane.position = arch_point(ARCH_C, PI * float(ARCH_C[4])).origin
	crane.material_override = material
	crane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crane)
	_add_strips()

## The arches (doc/assets/arch_parts/spec.md): their sections along each curve (one MultiMesh, the section model
## turned from Blender's axes to the boxes' x across, y inward, z along: ARCH_SECTION_AXES), the footings under each
## built leg (one MultiMesh) and the scaffold round C's unfinished end.
func _add_arches(material: ShaderMaterial) -> void:
	var sections: Array[Transform3D] = []
	var footings: Array[Transform3D] = []
	for arch: Array in [ARCH_A, ARCH_B, ARCH_C]:
		for box in arch_boxes(arch):
			sections.append(Transform3D(box.basis * ARCH_SECTION_AXES, box.origin))
		var section: Vector2 = arch[5]
		var legs := [0.0, PI] if float(arch[4]) >= 1.0 else [0.0]
		for angle: float in legs:
			var foot := arch_point(arch, angle).origin
			footings.append(Transform3D(Basis.from_scale(Vector3.ONE * maxf(section.x, section.y)), Vector3(foot.x, 0.0, foot.z)))
	for pair: Array in [[ARCH_SECTION, sections], [ARCH_FOOTING, footings]]:
		var placed: Array[Transform3D] = []
		placed.assign(pair[1])
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = LaserFixtures._model_mesh(pair[0])
		multimesh.instance_count = placed.size()
		for i in placed.size():
			multimesh.set_instance_transform(i, placed[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	var scaffold := MeshInstance3D.new()
	scaffold.mesh = LaserFixtures._model_mesh(ARCH_SCAFFOLD)
	scaffold.position = arch_point(ARCH_C, PI * float(ARCH_C[4])).origin - Vector3(0.0, SCAFFOLD_BELOW_END, 0.0)
	scaffold.material_override = material
	scaffold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scaffold)

## The strips' MultiMesh: a segment per arch box, custom data its height on the arch and whether the arch is B.
func _add_strips() -> void:
	var spots: Array[Transform3D] = []
	var data: Array[Color] = []
	for arch: Array in [ARCH_A, ARCH_B, ARCH_C]:
		var radius: float = arch[1]
		var section: Vector2 = arch[5]
		var step := PI / ARCH_SEGMENTS
		for i in int(ceil(ARCH_SEGMENTS * float(arch[4]))):
			var angle := (i + 0.5) * step
			var t := arch_point(arch, angle)
			var size := Vector3(section.x * STRIP_WIDTH, STRIP_THICK, radius * step * 1.02)
			spots.append(Transform3D(t.basis * Basis.from_scale(size), t.origin + t.basis.y * (section.y * 0.5 + STRIP_THICK * 0.5)))
			data.append(Color(sin(angle), 1.0 if arch == ARCH_B else 0.0, 0.0, 0.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, spots[i])
		multimesh.set_instance_custom_data(i, data[i])
	strip_material = ShaderMaterial.new()
	strip_material.shader = ARCH_STRIP
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = strip_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## Where a point at `angle` (0 one footing, PI the other) on an arch's centre line is, and the way along the curve.
static func arch_point(arch: Array, angle: float) -> Transform3D:
	var centre: Vector2 = arch[0]
	var radius: float = arch[1]
	var along := Vector3(1.0, 0.0, 0.0) if float(arch[2]) == 0.0 else Vector3(0.0, 0.0, 1.0)
	var lean := deg_to_rad(float(arch[3]))
	var local := (along * (-cos(angle) * radius) + Vector3.UP * (sin(angle) * radius)).rotated(along, lean)
	var tangent := (along * sin(angle) + Vector3.UP * cos(angle)).rotated(along, lean)
	# the box's y toward the arch's middle (its inner face), z along the curve
	var inward := -local.normalized()
	var basis := Basis.looking_at(tangent, inward)
	return Transform3D(basis, Vector3(centre.x, 0.0, centre.y) + local)

## An arch's boxes: ARCH_SEGMENTS along its half circle, as much of it as is built.
static func arch_boxes(arch: Array) -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var radius: float = arch[1]
	var section: Vector2 = arch[5]
	var built := int(ceil(ARCH_SEGMENTS * float(arch[4])))
	var step := PI / ARCH_SEGMENTS
	for i in built:
		var t := arch_point(arch, (i + 0.5) * step)
		# a little longer than its share of the curve, so neighbours overlap at the bends
		var length := radius * step * 1.08
		boxes.append(Transform3D(t.basis * Basis.from_scale(Vector3(section.x, section.y, length)), t.origin))
	return boxes

## Where the crane's jib starts, above C's unfinished end.
static func crane_top() -> Vector3:
	var end := arch_point(ARCH_C, PI * float(ARCH_C[4]))
	return end.origin + Vector3(0.0, CRANE_JIB_Y, 0.0)

## The crane's work lights along its jib (the right waving lasers), `count` of them.
static func crane_lights(count: int) -> Array[Vector3]:
	var lights: Array[Vector3] = []
	for i in count:
		lights.append(crane_top() + Vector3(-CRANE_JIB.x * (0.25 + 0.7 * i / maxf(count - 1, 1)), -CRANE_JIB.y, 0.0))
	return lights

## The floodlights at the footings the diagonal lasers fan from: B's near footing on the left, C's (its far one, the
## end it is built up from) on the right.
static func floodlight_bases() -> Array[Vector3]:
	return [arch_point(ARCH_B, PI).origin, arch_point(ARCH_C, 0.0).origin]

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)
