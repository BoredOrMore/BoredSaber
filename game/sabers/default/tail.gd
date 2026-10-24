extends Node3D
class_name SaberTail

@onready var material := ($Mesh as MeshInstance3D).material_override as ShaderMaterial
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
	material.set_shader_parameter(&"color", color)

## A cut makes the sheet flare for a moment: FLASH_GAIN times as bright, back to normal over FLASH_SECONDS.
const FLASH_GAIN := 1.8
const FLASH_SECONDS := 0.15
var _base_energy := -1.0
var _flash_tween: Tween

func flash() -> void:
	if _base_energy < 0.0:
		_base_energy = material.get_shader_parameter(&"energy")
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(energy: float) -> void: material.set_shader_parameter(&"energy", energy),
			_base_energy * FLASH_GAIN, _base_energy, FLASH_SECONDS)

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
## The sheet's opacity follows how fast the blade swept, as the player asked: 0 at rest, rising exponentially
## with the tip's speed to 1 at TRAIL_SPEED_FULL (m/s), so the slow wind-up before a swing barely shows and a real
## swing shows fully. TRAIL_CURVE sets how late it rises (at half speed it is 12%, at three quarters 35%). Without
## this a slowly moving blade left a bright band beside it, like a second blade.
const TRAIL_SPEED_FULL := 6.0
const TRAIL_CURVE := 4.0
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
			var raw := (exp(TRAIL_CURVE * clampf(swept / TRAIL_SPEED_FULL, 0.0, 1.0)) - 1.0) / (exp(TRAIL_CURVE) - 1.0)
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
				# UV: x the age along the sheet, y the opacity from how fast the blade swept there (SaberTrail.gdshader)

				if segments < MAX_SEGMENTS:
					var v := segments * 6
					_uvs[v] = Vector2(t, posA.fast)
					_verts[v] = posA.base_pos
					_uvs[v + 1] = Vector2(t, posA.fast)
					_verts[v + 1] = posA.tip_pos
					_uvs[v + 2] = Vector2(offsetted, posB.fast)
					_verts[v + 2] = posB.tip_pos

					_uvs[v + 3] = Vector2(t, posA.fast)
					_verts[v + 3] = posA.base_pos
					_uvs[v + 4] = Vector2(offsetted, posB.fast)
					_verts[v + 4] = posB.base_pos
					_uvs[v + 5] = Vector2(offsetted, posB.fast)
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
