extends PooledNode3D
class_name Wall

var despawn_z: float
var speed: float
## the default wall (FramedWall.gdshader on frame_mesh(), scaled to the wall) and the classic one (the scene's own box
## with DangerWall.gdshader), which Settings.classic_walls brings back
const FRAMED_MATERIAL := preload("res://game/notes/Wall/framed_wall.tres")
const CLASSIC_MATERIAL := preload("res://game/notes/Wall/danger_wall.tres")
static var _frame_mesh: ArrayMesh
var _box: BoxMesh

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
	if _box == null:
		_box = mesh.mesh as BoxMesh
	var m := _box
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
	if Settings.classic_walls:
		mesh.mesh = _box
		mesh.material_override = CLASSIC_MATERIAL
		mesh.scale = Vector3.ONE
	else:
		mesh.mesh = frame_mesh()
		mesh.material_override = FRAMED_MATERIAL
		mesh.scale = Vector3(x_size, y_size, maxf(z_size, 0.001))
	
	var x := (0.5 * wall_info.width + wall_info.line_index - 2) * Settings.LANE_DISTANCE_X
	var y := bottom + 0.5 * y_size
	_fit_over_curb(mesh, x, x_size, bottom, y_size)
	var z := (current_beat - wall_info.beat) * Map.beat_distance - depth
	
	var c := cos(wall_info.rotation)
	var s := sin(wall_info.rotation)
	
	transform.origin.x = c * x - s * z
	transform.origin.y = y
	transform.origin.z = s * x + c * z
		
	rotation.y = -wall_info.rotation
	
	speed = Map.beat_distance * Map.beats_per_second()
	($AnimationPlayer as AnimationPlayer).play(&"Spawn")

## A wall standing on the track's level with part of it over the curb beside the deck (TrackDeck: outside the lanes, a
## lighting or decor wall) is drawn from the edge strip's top up, so the curb and strip don't run through its bottom
## (owner, 2026-10-25). Only its look: its hitbox keeps the whole height. Lane walls, walls wholly past the curb and
## raised walls stay as they are, and nothing changes with the old track sheet (Old track, mixed reality), which has no
## curb. `x` is its middle across the track and `x_size` its width, `bottom` and `y_size` its base and height.
func _fit_over_curb(mesh: MeshInstance3D, x: float, x_size: float, bottom: float, y_size: float) -> void:
	var lift := TrackDeck.CURB_RISE + TrackDeck.STRIP_PROUD
	var edge := 2.0 * Settings.LANE_DISTANCE_X
	var reach := absf(x) + absf(x_size) * 0.5
	var inner := absf(x) - absf(x_size) * 0.5
	var over := reach > edge + 0.001 and inner < edge + TrackDeck.CURB_OUT and bottom < 0.01 and y_size > lift \
		and not (Settings.old_track or Settings.mixed_reality)
	var height := y_size - lift if over else y_size
	mesh.position.y = lift * 0.5 if over else 0.0
	if mesh.mesh == _box:
		_box.size.y = height
	else:
		mesh.scale.y = height

## The default wall's mesh, shared by every wall: a unit box (the glass, its faces with their normals) and a bar on each
## of its twelve edges, all drawn by FramedWall.gdshader in one draw call. Each vertex sits at a corner of the unit box;
## a bar's vertices keep their offset from the edge (-1 to 1 in the bar's two cross directions) in their UVs (x, y in
## UV, z in UV2; a colour would be read as sRGB and lose the exact 0 of the glass), for
## the shader to widen them to the frame's width in metres. The bars' ends meet inside the corners and are left open.
static func frame_mesh() -> ArrayMesh:
	if _frame_mesh:
		return _frame_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var none := Vector3.ZERO
	# the glass: each face of the unit box
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 0.5
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 0.5
			var c := n * 0.5
			_quad(st, [c - u - v, c + u - v, c + u + v, c - u + v], [none, none, none, none], n, n)
	# the bars: along each axis, at each of the box's four edges along it, four sides
	for axis in 3:
		var b := (axis + 1) % 3
		var c := (axis + 2) % 3
		for sb: float in [-1.0, 1.0]:
			for sc: float in [-1.0, 1.0]:
				var corner := Vector3.ZERO
				corner[b] = sb * 0.5
				corner[c] = sc * 0.5
				var along := Vector3.ZERO
				along[axis] = 0.5
				for cross: int in [b, c]:
					var other := c if cross == b else b
					for side: float in [-1.0, 1.0]:
						var out := Vector3.ZERO
						out[cross] = side
						var o0 := out
						o0[other] = -1.0
						var o1 := out
						o1[other] = 1.0
						_quad(st, [corner - along, corner + along, corner + along, corner - along], [o0, o0, o1, o1], out, Vector3.ZERO)
	_frame_mesh = st.commit()
	return _frame_mesh

## Adds a quad of `corners` with the bar offsets `offsets`, wound to face `out` (Godot's front faces are clockwise) and
## with `normal` for the shader.
static func _quad(st: SurfaceTool, corners: Array, offsets: Array, out: Vector3, normal: Vector3) -> void:
	# where the corners land with a wide bar, to see which way the quad faces
	var p: Array[Vector3] = []
	for i in 4:
		p.append(corners[i] + offsets[i] * 0.1)
	var order := [0, 1, 2, 0, 2, 3]
	if (p[1] - p[0]).cross(p[2] - p[0]).dot(out) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(normal)
		st.set_uv(Vector2(offsets[i].x, offsets[i].y))
		st.set_uv2(Vector2(offsets[i].z, 0.0))
		st.add_vertex(corners[i])
