@tool
class_name MonolithRig
extends Node3D
## Monolith (doc/world/GAME_BIBLE.md "Monolith"; owner, 2026-10-31): standing before something that was here before you.
## Abstract, no story. The player stands on a tall pillar in the middle of a valley (owner, 2026-10-31): the valley
## floor lies VALLEY_Y below, filled by a sea of low stylized clouds, with smooth hills rising out of it on both sides
## (owner, 2026-11-01: the cloud sea and hills made with GPT in stylized-3d-agent, picked over the 3D banks and
## mountains after a headset comparison). One colossal black slab (SLAB, 1:4:9) stands on the valley floor
## SLAB_DISTANCE away, down the valley SLAB_YAW off straight ahead, its broad face turned to the player: tiny beside
## something massive, not inside it or at its centre. Nothing within the notes' fly-in (Cuttable.FLY_DISTANCE, r 320 m)
## rises above y -5 in any direction (the sea stays below y -10 there, the hills stand beyond it), so it serves 90 and
## 360 degree maps too. Light only on the slab (AGENTS.md "Light", rule 5), drawn in its face's own shader
## (MonolithFace.gdshader; flush strip meshes would fight for depth this far out): its two vertical edges in the left
## and right lasers' colours, horizontal seams in the square bars' colour lit from the foot up as the show builds, a
## slit up the middle in the floor lights' colour; beams up its face from fixtures on a ledge LEDGE_HEIGHT up, clear
## above the clouds (the diagonal and waving lasers, LightRig; owner, 2026-10-31: moved up out of the clouds, the
## ledge's own light strip taken off). Behind it the horizon glows faintly (MonolithSky) so it stands as a silhouette,
## and its shadow falls down the valley toward the player (MonolithFloor.gdshader, on the valley and the pillar). The
## cloud sea is MonolithCloudSea; the slab, the valley, the pillar and the hills sink into it below its surface
## (monolith_cloud_sea.gdshaderinc). Far edges stay sharp in the blockout: the soft-edge layer (AGENTS.md "Soft far
## edges") goes on the slab's outline once the look is agreed, never across its per-seam lights. A tool script, so it
## shows in the editor too. Sizes in metres, untuned.

const FACE_SHADER := preload("res://game/env/MonolithFace.gdshader")
const FLOOR_SHADER := preload("res://game/env/MonolithFloor.gdshader")
const HILL_SHADER := preload("res://game/env/MonolithHill.gdshader")
## the slab: its size (across, up, deep), its front face's distance from the player and its turn left of straight ahead
## (radians), which is also the way the valley runs; its top front corners stand about 950 m away, inside the camera's
## far plane (1024 m)
const SLAB := Vector3(360.0, 810.0, 90.0)
const SLAB_DISTANCE := 520.0
const SLAB_YAW := deg_to_rad(30.0)
## the ledge across the slab's face carrying the lasers' fixtures: metres up from its foot, above the cloud sea round
## the slab (up to about +67 m)
const LEDGE_HEIGHT := 150.0
## the pillar the player stands on: from under the platform (PILLAR_TOP) down to the valley floor, PILLAR_RADIUS wide
const PILLAR_TOP := -TrackDeck.DECK_DEPTH
const PILLAR_RADIUS := 10.0
const PILLAR_SIDES := 6
## the valley floor's height, under the clouds, reaching VALLEY_RADIUS from the player (past the last hill)
const VALLEY_Y := -80.0
const VALLEY_RADIUS := 980.0
## the hills (owner, 2026-11-01, from GPT's review scene in stylized-3d-agent, tools/cloud_shading_review.gd): one
## upright ring per entry of HILL_RINGS (radius, the top's height down the valley, its height at the valley's sides),
## all beyond the notes' fly-in (r 320 m); between the valley's line and its sides the top follows |sin| of the angle
## off the valley to the power HILL_VALLEY_POWER, plus a wobble of HILL_WOBBLE of the ring's height range HILL_WOBBLES
## times round. Each ring has HILL_SEGMENTS segments, stands from the valley floor and is a flat grey, HILL_TONE.x for
## the nearest and HILL_TONE.y more per ring out.
const HILL_RINGS := [Vector3(380.0, -30.0, 100.0), Vector3(650.0, -10.0, 220.0), Vector3(950.0, 10.0, 380.0)]
const HILL_VALLEY_POWER := 1.5
const HILL_WOBBLE := 0.08
const HILL_WOBBLES := 17.0
const HILL_SEGMENTS := 128
const HILL_TONE := Vector2(0.006, 0.007)

## the slab face's material (light colours, build-up and slit set each frame by EventDriver) and the floor's
var face_material: ShaderMaterial
var floor_material: ShaderMaterial

func _ready() -> void:
	face_material = ShaderMaterial.new()
	face_material.shader = FACE_SHADER
	face_material.set_shader_parameter(&"size", SLAB)
	var slab := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = SLAB
	slab.mesh = box
	slab.transform = slab_place()
	slab.material_override = face_material
	slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slab)
	floor_material = ShaderMaterial.new()
	floor_material.shader = FLOOR_SHADER
	floor_material.set_shader_parameter(&"slab_centre", Vector2(slab_place().origin.x, slab_place().origin.z))
	floor_material.set_shader_parameter(&"slab_yaw", SLAB_YAW)
	floor_material.set_shader_parameter(&"slab_half_width", SLAB.x * 0.5)
	floor_material.set_shader_parameter(&"slab_distance", SLAB_DISTANCE)
	var valley := MeshInstance3D.new()
	var ground := PlaneMesh.new()
	ground.size = Vector2.ONE * VALLEY_RADIUS * 2.0
	valley.mesh = ground
	valley.position = _around_player(Vector3(0.0, VALLEY_Y, 0.0))
	valley.material_override = floor_material
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(valley)
	var pillar := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = PILLAR_RADIUS
	column.bottom_radius = PILLAR_RADIUS
	column.height = PILLAR_TOP - VALLEY_Y
	column.radial_segments = PILLAR_SIDES
	column.rings = 0
	column.cap_top = false
	column.cap_bottom = false
	pillar.mesh = column
	pillar.position = _around_player(Vector3(0.0, (PILLAR_TOP + VALLEY_Y) * 0.5, 0.0))
	pillar.material_override = floor_material
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pillar)
	var sea := MonolithCloudSea.new()
	sea.position = _around_player(Vector3.ZERO)
	add_child(sea)
	sea.bind_material(face_material)
	sea.bind_material(floor_material)
	for layer in HILL_RINGS.size():
		var material := ShaderMaterial.new()
		material.shader = HILL_SHADER
		material.set_shader_parameter(&"tone", HILL_TONE.x + HILL_TONE.y * layer)
		sea.bind_material(material)
		var hills := MeshInstance3D.new()
		hills.mesh = _hill_ring(HILL_RINGS[layer], layer)
		hills.position = _around_player(Vector3.ZERO)
		hills.material_override = material
		hills.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hills)

## One ring of hills (`ring`: radius, the top's height down the valley, its height at the sides), the `layer`-th out,
## from the valley floor up to a smooth top highest beside the slab.
func _hill_ring(ring: Vector3, layer: int) -> ArrayMesh:
	var positions := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in HILL_SEGMENTS:
		var angle := TAU * i / HILL_SEGMENTS
		var top := ring.y + (ring.z - ring.y) * pow(absf(sin(angle - PI * 0.5 - SLAB_YAW)), HILL_VALLEY_POWER)
		top += (ring.z - ring.y) * HILL_WOBBLE * sin(angle * HILL_WOBBLES + layer)
		positions.append(Vector3(ring.x * cos(angle), top, -ring.x * sin(angle)))
		positions.append(Vector3(ring.x * cos(angle), VALLEY_Y, -ring.x * sin(angle)))
	for i in HILL_SEGMENTS:
		var a := 2 * i
		var b := 2 * ((i + 1) % HILL_SEGMENTS)
		indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The slab's turn round the player: straight ahead (-z) turned SLAB_YAW to the left.
static func slab_basis() -> Basis:
	return Basis(Vector3.UP, SLAB_YAW)

## Where the slab stands: its front face SLAB_DISTANCE from the player, facing them, its foot on the valley floor.
static func slab_place() -> Transform3D:
	var centre := Vector3(0.0, VALLEY_Y + SLAB.y * 0.5, -SLAB_DISTANCE - SLAB.z * 0.5)
	return Transform3D(slab_basis(), _around_player(slab_basis() * centre))

## Where a light stands on the slab's ledge, just in front of its face, `share` of the way across from its left edge to
## its right as the player sees it (LightRig: the lasers' fixtures, shining up the face).
static func ledge_spot(share: float) -> Vector3:
	var across := (share - 0.5) * SLAB.x
	return _around_player(slab_basis() * Vector3(across, VALLEY_Y + LEDGE_HEIGHT, -SLAB_DISTANCE + 2.0))

## The way up the slab's face, leaning back onto it by `lean` (0 straight up), for the beams on its ledge.
static func up_face(lean: float) -> Vector3:
	return (slab_basis() * Vector3(0.0, 1.0, -lean)).normalized()

## A point given round the player's standing point (Constants.PLAYER_Z) in the stage's space.
static func _around_player(offset: Vector3) -> Vector3:
	return offset + Vector3(0.0, 0.0, Constants.PLAYER_Z)
