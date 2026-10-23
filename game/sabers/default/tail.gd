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

func set_color(color: Color) -> void:
	material.albedo_color = color
	material.emission = color

## A cut makes the sheet flare for a moment: FLASH_GAIN times as bright, back to normal over FLASH_SECONDS.
const FLASH_GAIN := 2.5
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
	
	func _init(base: Vector3, tip: Vector3):
		base_pos = base
		tip_pos = tip

var last_pos: Array[HistoricalPositions] = []
## how long the swept sheet behind the blade lasts; its gradient (tail.tscn) keeps the leading edge bright and fades
## the rest evenly, as in Beat Saber (it dropped to a fifth right behind the blade and lasted 0.15 s, too faint)
const MAX_AGE := 0.22 as float
func _process(delta: float) -> void:
	if visible and size > 0:
		var pos := HistoricalPositions.new(global_position, to_global(position + Vector3(0,size,0)))
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
