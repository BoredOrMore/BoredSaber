extends Node3D
class_name SaberTail

@onready var material := ($Mesh as MeshInstance3D).material_override as StandardMaterial3D
@onready var mesh_instance := $Mesh as MeshInstance3D

# most trail segments drawn; at 72-120 Hz the trail holds 11-18
const MAX_SEGMENTS := 64

# the trail is written into these and uploaded into one preallocated surface,
# instead of rebuilding an ImmediateMesh every frame
var _verts := PackedVector3Array()
var _uvs := PackedVector2Array()
var _array_mesh := ArrayMesh.new()
var _drawn_segments := 0

@export var size := 1.0

# for the math in _process to work properly and the tail to be drawn in the
# right spot,the mesh has to be reparented to root.
# TODO: reparenting to root like this is difficult for any future coders to
# follow.  the math should be rewritten to work without reparenting.
func _ready() -> void:
	_verts.resize(MAX_SEGMENTS * 6)
	_uvs.resize(MAX_SEGMENTS * 6)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	# vertices are in world space and move every frame
	_array_mesh.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	mesh_instance.mesh = _array_mesh
	remove_child(mesh_instance)
	get_tree().get_root().add_child.call_deferred(mesh_instance)

## The mesh lives under the root (see _ready), so it outlived a freed saber: swapping the saber (Settings > Saber)
## left its last trail frozen in the air for good. It goes with the tail now.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(mesh_instance):
		mesh_instance.queue_free()

func set_color(color: Color) -> void:
	material.albedo_color = color
	material.emission = color

## A cut makes the sheet flare for a moment: FLASH_GAIN times as bright, back to normal over FLASH_SECONDS.
const FLASH_GAIN := 1.8
const FLASH_SECONDS := 0.15
var _base_energy := -1.0
var _flash_tween: Tween

func flash() -> void:
	if _base_energy < 0.0:
		_base_energy = material.emission_energy_multiplier
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, ^"emission_energy_multiplier", _base_energy, FLASH_SECONDS).from(
			_base_energy * FLASH_GAIN)

class HistoricalPositions:
	extends RefCounted
	
	var base_pos := Vector3() # global position of blade at the base (near handle)
	var tip_pos := Vector3()  # blogal position of blade at the tip
	var age := 0.0 as float
	## how fast the blade swept here, 0 (dark) to 1 (full); smoothed over frames
	var fast := 0.0
	
	func _init(base: Vector3, tip: Vector3):
		base_pos = base
		tip_pos = tip

var last_pos: Array[HistoricalPositions] = []
## how long the swept sheet behind the blade lasts; its gradient (tail.tscn) keeps the leading edge bright and fades
## the rest evenly, as in Beat Saber (it dropped to a fifth right behind the blade and lasted 0.15 s, too faint)
const MAX_AGE := 0.22 as float
## The sheet shows only where the blade swept fast, as in Beat Saber: a part swept slower than TRAIL_SPEED_START
## (m/s at the tip) is dark, full from TRAIL_SPEED_FULL. Without this a slowly moving blade left a bright band beside
## it, like a second blade (the player's "trail light bug"); the slower wind-up before a swing (the 0.2 s before
## it) showed too at 1.5 to 4 m/s, so the sheet now starts at 3 m/s.
const TRAIL_SPEED_START := 3.0
const TRAIL_SPEED_FULL := 5.5
## The sweep's speed is smoothed over frames (this share of the new frame's each time) and set per point, not per
## segment, so a slow swing fades smoothly along the sheet instead of breaking into patches.
const TRAIL_SPEED_SMOOTHING := 0.5
## A blade tip that moves further than this (m) in one frame was moved, not swung: recentering (the headset's
## recenter or the game's own), a height change (switching player, Measure, the Height setting) or the controller
## losing and finding tracking. The trail starts again there instead of drawing a full-bright sheet across the jump.
## A hard swing moves the tip about 0.15 m a frame.
const TELEPORT_DISTANCE := 0.5
func _process(delta: float) -> void:
	if visible and size > 0:
		var pos := HistoricalPositions.new(global_position, to_global(position + Vector3(0,size,0)))
		if last_pos.size() > 0 and (pos.tip_pos.distance_to(last_pos[0].tip_pos) > TELEPORT_DISTANCE
				or pos.base_pos.distance_to(last_pos[0].base_pos) > TELEPORT_DISTANCE):
			last_pos.clear()
		if last_pos.size() > 0:
			var swept := pos.tip_pos.distance_to(last_pos[0].tip_pos) / maxf(delta, 1e-4)
			var raw := clampf((swept - TRAIL_SPEED_START) / (TRAIL_SPEED_FULL - TRAIL_SPEED_START), 0.0, 1.0)
			pos.fast = lerpf(last_pos[0].fast, raw, TRAIL_SPEED_SMOOTHING)
		var segments := 0
		if last_pos.size() > 0:
			var new_size = -1 as int
			for i in range(last_pos.size()):
				var posA := pos
				if i > 0:
					posA = last_pos[i-1]
				var posB := last_pos[i]
				
				var t := clampf(last_pos[i].age / MAX_AGE, 0.02, 0.98)
				var offsetted := clampf(t + (1.0/last_pos.size()), 0.02, 0.98)
				# a slow part of the sweep reads as older (darker) on the gradient, by how slow it was there
				t = 1.0 - (1.0 - t) * posA.fast
				offsetted = 1.0 - (1.0 - offsetted) * posB.fast

				if segments < MAX_SEGMENTS:
					var v := segments * 6
					_uvs[v] = Vector2(t,0.98)
					_verts[v] = posA.base_pos
					_uvs[v + 1] = Vector2(t,0.02)
					_verts[v + 1] = posA.tip_pos
					_uvs[v + 2] = Vector2(offsetted,0.02)
					_verts[v + 2] = posB.tip_pos

					_uvs[v + 3] = Vector2(t,0.98)
					_verts[v + 3] = posA.base_pos
					_uvs[v + 4] = Vector2(offsetted,0.98)
					_verts[v + 4] = posB.base_pos
					_uvs[v + 5] = Vector2(offsetted,0.02)
					_verts[v + 5] = posB.tip_pos
					segments += 1
				
				last_pos[i].age += delta
				if new_size < 0 && last_pos[i].age > MAX_AGE:
					new_size = i

			if new_size >= 0:
				last_pos.resize(new_size)

		_upload(segments)
		last_pos.push_front(pos)
	elif last_pos.size() > 0:
		_upload(0)
		last_pos = []

## Collapses the segments left over from the last frame and sends the trail to the GPU.
func _upload(segments: int) -> void:
	for v in range(segments * 6, _drawn_segments * 6):
		_verts[v] = Vector3.ZERO
	_drawn_segments = segments
	_array_mesh.surface_update_vertex_region(0, 0, _verts.to_byte_array())
	_array_mesh.surface_update_attribute_region(0, 0, _uvs.to_byte_array())
