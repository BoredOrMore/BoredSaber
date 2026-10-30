extends PooledNode3D
class_name Arc

static var left_material := load("res://game/notes/Arc/Arc.material").duplicate() as ShaderMaterial
static var right_material := left_material.duplicate() as ShaderMaterial

static var left_material_magnet := left_material.duplicate() as ShaderMaterial
static var right_material_magnet := right_material.duplicate() as ShaderMaterial

@onready var visual: MeshInstance3D = $Path3D/Visual

var arc_info: ArcInfo
var activator_cube: BeepCube

var speed: float
var despawn_z: float
# how far ahead of the hit plane its head was at spawn, and how far it has moved since (for its fly-in)
var _head_ahead := 0.0
var _travelled := 0.0

func spawn(info: ArcInfo, current_beat: float, _activator_cube: BeepCube = null) -> void:
	arc_info = info
	
	if abs(arc_info.head_rotation-arc_info.tail_rotation) > Constants.ROTATION_EPS: # or abs(arc_info.tail_rotation) > Constants.ROTATION_EPS:
		# TODO: arcs will twist if rotations are different
		release()
		return
	
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	speed = Map.beat_distance * Map.beats_per_second()
	var path := $Path3D as Path3D
	visual = $Path3D/Visual
	visual.material_override = right_material if arc_info.color == 1 else left_material
	activator_cube = _activator_cube
	if activator_cube:
		activator_cube.cutted.connect(_on_activator_cube_cutted)
	else:
		start_magnet()
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, info.mesh_arrays)
	visual.mesh = mesh
	despawn_z = Constants.MISS_Z - info.tail_pos.z - current_beat*Map.beat_distance
	_head_ahead = (info.head_beat - current_beat) * Map.beat_distance
	_travelled = 0.0
	
	# sets the origin of the tail at the tail point to use in the shader for a fade out effect
	path.position =  info.tail_pos + Vector3(0,0,current_beat*Map.beat_distance)
	# a pooled arc kept the place it moved to last time; the path below is laid out from the track's origin
	transform = Transform3D.IDENTITY
	rotation.y = -arc_info.head_rotation
	# turned about the player's standing point, as notes (Cuttable.add_lane_rotation)
	var pivot := Vector3(0.0, 0.0, Constants.LANE_PIVOT_Z)
	transform.origin = pivot - transform.basis * pivot

func _on_activator_cube_cutted(correct_saber: bool) -> void:
	if activator_cube and activator_cube.cutted.is_connected(_on_activator_cube_cutted):
		activator_cube.cutted.disconnect(_on_activator_cube_cutted)
	if correct_saber:
		start_magnet()

# sets the magnet version of the material (and ensures correct magnet parameter)
func start_magnet() -> void:
	visual.material_override = right_material_magnet if arc_info.color == 1 else left_material_magnet
	visual.material_override.set_shader_parameter(&"saber_magnet", arc_info.color+1)

func _process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	transform.origin += speed * delta * transform.basis.z
	_travelled += speed * delta
	# it flies in with its head note (Cuttable.fly_offset)
	visual.position = Vector3(0.0, 0.0, -Cuttable.fly_offset(_head_ahead - _travelled))
	if _travelled >= despawn_z:
		hide_pooled()
		release()

## Hides the arc, drops its mesh and stops its processing while it waits in the pool.
func hide_pooled() -> void:
	if activator_cube and activator_cube.cutted.is_connected(_on_activator_cube_cutted):
		activator_cube.cutted.disconnect(_on_activator_cube_cutted)
	activator_cube = null
	visible = false
	visual.mesh = null
	process_mode = Node.PROCESS_MODE_DISABLED

# call this when clearing the track
func clear_from_track() -> void:
	hide_pooled()
	if not is_released():
		release()
