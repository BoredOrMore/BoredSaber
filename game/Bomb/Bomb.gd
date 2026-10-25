extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D
## The bomb is drawn in one draw call: its body and glow hull merged into one mesh (merged_mesh) with
## BombMerged.gdshader, instead of BombMesh.tscn's two (body and hull), which classic brings back to compare
## (stage_capture --bomb classic).
const MERGED_MATERIAL := preload("res://game/Bomb/bomb_merged.tres")
static var classic := false
static var _merged: ArrayMesh

func _ready() -> void:
	if classic:
		return
	var body := $BombAnimation/Mesh/Icosphere as MeshInstance3D
	var glow := $BombAnimation/Mesh/Icosphere2 as MeshInstance3D
	body.mesh = merged_mesh(body.mesh, glow.mesh)
	body.material_override = MERGED_MATERIAL
	glow.queue_free()

## One mesh of `body` and `hull` (each one surface, the same transform): the hull's triangles wound the other way and
## flagged with UV2.x = 1, for BombMerged.gdshader. Made once and shared.
static func merged_mesh(body: Mesh, hull: Mesh) -> ArrayMesh:
	if _merged:
		return _merged
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var flags := PackedVector2Array()
	var indices := PackedInt32Array()
	for part in 2:
		var arrays := (body if part == 0 else hull).surface_get_arrays(0)
		var base := verts.size()
		var part_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		verts.append_array(part_verts)
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for i in part_verts.size():
			flags.append(Vector2(part, 0.0))
		var part_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, part_indices.size(), 3):
			indices.append(base + part_indices[t])
			# the hull's triangles turned round: cull_back then draws its back faces
			indices.append(base + part_indices[t + (2 if part == 1 else 1)])
			indices.append(base + part_indices[t + (1 if part == 1 else 2)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = flags
	arrays[Mesh.ARRAY_INDEX] = indices
	_merged = ArrayMesh.new()
	_merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _merged

func set_collision_disabled(value: bool) -> void:
	collision_shape.disabled = value

@warning_ignore("unused_parameter")
func cut(saber: LightSaber, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	Scoreboard.bad_cut(transform.origin, lane_rotation, "bomb")
	hide_pooled()
	release()

func on_miss() -> void:
	hide_pooled()
	release()

## Hides the bomb and stops its processing while it waits in the pool.
func hide_pooled() -> void:
	visible = false
	set_collision_disabled(true)
	($AnimationPlayer as AnimationPlayer).stop()
	process_mode = Node.PROCESS_MODE_DISABLED

# call this when clearing the track
func clear_from_track() -> void:
	hide_pooled()
	if not is_released():
		release()

func spawn(info: BombInfo, current_beat: float) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	speed = Map.beat_distance * Map.beats_per_second()
	beat = info.beat
	
	var distance: float = info.beat - current_beat
	
	transform.origin.x = Settings.LANE_DISTANCE_X * float(info.line_index) + Settings.LANE_ZERO_X
	transform.origin.y = Constants.layer_y(float(info.line_layer))
	transform.origin.z = -distance * Map.beat_distance
	
	add_lane_rotation(info.rotation)
	
	var anim := $AnimationPlayer as AnimationPlayer
	var anim_speed := Map.current_difficulty.note_jump_movement_speed / 9.0
	anim.speed_scale = maxf(min_speed, anim_speed)
	anim.play(&"Spawn")
