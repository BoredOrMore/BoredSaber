extends PooledNode3D
class_name Wall

var despawn_z: float
var speed: float

func _physics_process(delta: float) -> void:
	if Scoreboard.paused: return
	
	#transform.origin.z += speed * delta
	
	# remove children that go to far
	#if transform.origin.z > despawn_z:
	#	queue_free()
	
	transform.origin += speed * delta * transform.basis.z
	var rz := global_transform.origin.dot(transform.basis.z)
	
	if rz > despawn_z:
		hide_pooled()
		release()

	#transform.origin.x += speed * delta * sin(rotation.y)
	#transform.origin.z += speed * delta * cos(rotation.y)
	#
	#var rz := global_transform.rotated(Vector3(0,1,0), -rotation.y).origin.z
	#if rz > despawn_z:
	#	queue_free()
	

## Hides the wall and stops its processing while it waits in the pool.
func hide_pooled() -> void:
	visible = false
	($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).set_deferred(&"disabled", true)
	($AnimationPlayer as AnimationPlayer).stop()
	process_mode = Node.PROCESS_MODE_DISABLED

# call this when clearing the track
func clear_from_track() -> void:
	hide_pooled()
	if not is_released():
		release()

func spawn(wall_info: ObstacleInfo, current_beat: float) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).set_deferred(&"disabled", false)
	var mesh := $WallMeshOrientation/WallMesh as MeshInstance3D
	var m := mesh.mesh as BoxMesh
	var shape := ($WallMeshOrientation/WallArea/CollisionShape3D as CollisionShape3D).shape as BoxShape3D
	
	var x_size := wall_info.width * Settings.LANE_DISTANCE_X
	var bottom := Constants.wall_y(wall_info.line_layer)
	var y_size := Constants.wall_y(wall_info.line_layer + wall_info.height) - bottom
	var z_size := wall_info.duration * Map.beat_distance
	var depth := z_size * 0.5
	m.size.x = x_size
	shape.size.x = x_size
	m.size.y = y_size
	shape.size.y = y_size
	m.size.z = z_size
	shape.size.z = z_size
	despawn_z = Constants.MISS_Z + depth
	
	var x := (0.5 * wall_info.width + wall_info.line_index - 2) * Settings.LANE_DISTANCE_X
	var y := bottom + 0.5 * y_size
	var z := (current_beat - wall_info.beat) * Map.beat_distance - depth
	
	var c := cos(wall_info.rotation)
	var s := sin(wall_info.rotation)
	
	transform.origin.x = c * x - s * z
	transform.origin.y = y
	transform.origin.z = s * x + c * z
		
	rotation.y = -wall_info.rotation
	
	speed = Map.beat_distance * Map.beats_per_second()
	($AnimationPlayer as AnimationPlayer).play(&"Spawn")
