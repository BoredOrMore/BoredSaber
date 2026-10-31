@tool
class_name MonolithRig
extends Node3D
## Monolith (doc/world/GAME_BIBLE.md "Monolith"; owner, 2026-10-31): standing before something that was here before you.
## Abstract, no story. The player stands on an open dark plain; one colossal black slab (SLAB, 1:4:9) stands SLAB_DISTANCE
## away, SLAB_YAW off straight ahead, its broad face turned to the player: tiny beside something massive, not inside it
## or at its centre (owner, 2026-10-31). Nothing stands within the notes' fly-in (Cuttable.FLY_DISTANCE) in any
## direction, so it serves 90 and 360 degree maps too. Light only on the slab (AGENTS.md "Light", rule 5), drawn in its
## face's own shader (MonolithFace.gdshader; flush strip meshes would fight for depth this far out): its two vertical
## edges in the left and right lasers' colours, horizontal seams in the square bars' colour lit from the foot up as the
## show builds, a slit up the middle and a strip along the foot in the floor lights' colour; beams up its face from
## fixtures at its foot (the diagonal and waving lasers, LightRig). Behind it the horizon glows faintly (MonolithSky)
## so it stands as a silhouette, and its shadow falls across the plain toward the player (MonolithFloor.gdshader).
## Far edges stay sharp in the blockout: the soft-edge layer (AGENTS.md "Soft far edges") goes on the slab's outline
## once the look is agreed, never across its per-seam lights.
## BLOCKOUT: one box and a disc. A tool script, so it shows in the editor too. Sizes in metres, untuned.

const FACE_SHADER := preload("res://game/env/MonolithFace.gdshader")
const FLOOR_SHADER := preload("res://game/env/MonolithFloor.gdshader")
## the slab: its size (across, up, deep), its front face's distance from the player and its turn left of straight ahead
## (radians); its top front corners stand about 980 m away, inside the camera's far plane (1024 m)
const SLAB := Vector3(360.0, 810.0, 90.0)
const SLAB_DISTANCE := 520.0
const SLAB_YAW := deg_to_rad(30.0)
## the floor: a disc FLOOR_RADIUS out, its top FLOOR_Y below the track, under the platform's base
const FLOOR_RADIUS := 1000.0
const FLOOR_Y := -TrackDeck.DECK_DEPTH
const FLOOR_SEGMENTS := 96

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
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = FLOOR_RADIUS
	disc.bottom_radius = FLOOR_RADIUS
	disc.height = 0.0
	disc.radial_segments = FLOOR_SEGMENTS
	disc.rings = 0
	disc.cap_bottom = false
	floor_disc.mesh = disc
	floor_disc.position = _around_player(Vector3(0.0, FLOOR_Y, 0.0))
	floor_disc.material_override = floor_material
	floor_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_disc)

## The slab's turn round the player: straight ahead (-z) turned SLAB_YAW to the left.
static func slab_basis() -> Basis:
	return Basis(Vector3.UP, SLAB_YAW)

## Where the slab stands: its front face SLAB_DISTANCE from the player, facing them, its foot on the floor.
static func slab_place() -> Transform3D:
	var centre := Vector3(0.0, FLOOR_Y + SLAB.y * 0.5, -SLAB_DISTANCE - SLAB.z * 0.5)
	return Transform3D(slab_basis(), _around_player(slab_basis() * centre))

## Where a light stands at the slab's foot, just in front of its face, `share` of the way across from its left edge to
## its right as the player sees it (LightRig: the lasers' fixtures, shining up the face).
static func foot_spot(share: float) -> Vector3:
	var across := (share - 0.5) * SLAB.x
	return _around_player(slab_basis() * Vector3(across, FLOOR_Y, -SLAB_DISTANCE + 2.0))

## The way up the slab's face, leaning back onto it by `lean` (0 straight up), for the beams at its foot.
static func up_face(lean: float) -> Vector3:
	return (slab_basis() * Vector3(0.0, 1.0, -lean)).normalized()

## A point given round the player's standing point (Constants.PLAYER_Z) in the stage's space.
static func _around_player(offset: Vector3) -> Vector3:
	return offset + Vector3(0.0, 0.0, Constants.PLAYER_Z)
