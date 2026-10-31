extends RefCounted
class_name ArcInfo

const MID_ANCHOR_MODE_STRAIGHT := 0
const MID_ANCHOR_MODE_CLOCKWISE := 1
const MID_ANCHOR_MODE_COUNTERCLOCKWISE := 2

const arc_angle_force := 2.0
const mid_points := 3

const MESH_RADIUS := 0.04
const MESH_INTERVAL := 0.13
# diamond cross-section, same as the old CSGPolygon3D polygon
const MESH_POLYGON: Array[Vector2] = [Vector2(-MESH_RADIUS, 0), Vector2(0, MESH_RADIUS), Vector2(MESH_RADIUS, 0), Vector2(0, -MESH_RADIUS)]

var color: int
var head_beat: float
var head_line_index: float
var head_line_layer: float
var head_cut_angle: float
var head_control_point_length_multiplier: float
var tail_beat: float
var tail_line_index: float
var tail_line_layer: float
var tail_cut_angle: float
var tail_control_point_length_multiplier: float
var mid_anchor_mode: int
var head_rotation: float
var tail_rotation: float
var curve: Curve3D
var tail_pos: Vector3
var head_pos: Vector3
var mesh_arrays: Array

@warning_ignore("shadowed_variable")
func _init(
	color: int, head_beat: float, head_line_index: float, head_line_layer: float,
	head_cut_angle: float, head_control_point_length_multiplier: float,
	tail_beat: float, tail_line_index: float, tail_line_layer: float,
	tail_cut_angle: float, tail_control_point_length_multiplier: float,
	mid_anchor_mode: int, head_rotation_degrees: float, tail_rotation_degrees: float
) -> void:
	self.color = Utils.adjust_color(color)
	self.head_beat = head_beat
	self.head_line_index = Utils.adjust_horizontal(head_line_index)
	self.head_line_layer = Utils.adjust_vertical(head_line_layer)
	self.head_cut_angle = head_cut_angle
	self.head_control_point_length_multiplier = head_control_point_length_multiplier
	self.tail_beat = tail_beat
	self.tail_line_index = Utils.adjust_horizontal(tail_line_index)
	self.tail_line_layer = Utils.adjust_vertical(tail_line_layer)
	self.tail_cut_angle = tail_cut_angle
	self.tail_control_point_length_multiplier = tail_control_point_length_multiplier
	self.mid_anchor_mode = mid_anchor_mode
	self.head_rotation = Utils.adjust_lane_rotation(head_rotation_degrees * (PI/180.))
	self.tail_rotation = Utils.adjust_lane_rotation(tail_rotation_degrees * (PI/180.))
	if abs(Settings.gradual_rotation) > 1e-5:
		self.head_rotation += Settings.gradual_rotation * head_beat
		self.tail_rotation += Settings.gradual_rotation * tail_beat
		
	create_curve()
	build_mesh_arrays()
	
func create_curve() -> void:
	head_pos = Vector3(
		Settings.LANE_DISTANCE_X * float(head_line_index) + Settings.LANE_ZERO_X,
		Constants.layer_y(float(head_line_layer)),
		-head_beat * Map.beat_distance
	)
	tail_pos = Vector3(
		Settings.LANE_DISTANCE_X * float(tail_line_index) + Settings.LANE_ZERO_X,
		Constants.layer_y(float(tail_line_layer)),
		-tail_beat * Map.beat_distance
	)	
	
	var head_cut_rotation: Vector2
	var tail_cut_rotation: Vector2
	if head_cut_angle >= Constants.DIRECTION8_COMPARE:
		head_cut_rotation = Vector2.ZERO
	else:
		head_cut_rotation = Utils.rotation_unit_vector(head_cut_angle) * head_control_point_length_multiplier
	if tail_cut_angle >= Constants.DIRECTION8_COMPARE:
		tail_cut_rotation = Vector2.ZERO
	else:
		tail_cut_rotation = -Utils.rotation_unit_vector(tail_cut_angle) * tail_control_point_length_multiplier
		
	curve = Curve3D.new()
	
	curve.add_point(head_pos - tail_pos, Vector3.ZERO, Vector3(head_cut_rotation.x, head_cut_rotation.y, 0.0) * arc_angle_force)
	
	if mid_anchor_mode > 0:
		for midpoint_id in range(mid_points):
			var range : float = (float(midpoint_id+1) / (mid_points+1))
			#var head_rot := Utils.rotation_unit_vector(info.head_cut_angle)
			## TODO: head_rot not used?!
			
			var point_pos :=  head_pos.lerp(tail_pos, range)
			point_pos += Vector3(head_cut_rotation.x, head_cut_rotation.y, 0.0).rotated(Vector3(0,0,1), 
					(
						(PI if Utils.close_angle(head_cut_angle, tail_cut_angle) else TAU)
						*(-range if mid_anchor_mode == 1 else range)
					)
				) * arc_angle_force
			
			curve.add_point(point_pos - tail_pos, Vector3.ZERO, Vector3.ZERO)
	
	# the tail goes in before smoothing, which reads each midpoint's next point
	curve.add_point(tail_pos - tail_pos, Vector3(tail_cut_rotation.x, tail_cut_rotation.y, 0.0) * arc_angle_force, Vector3.ZERO)
	
	if mid_anchor_mode > 0:
		# calculate smooth in out directions after all points have been set
		for smoothpoint_id in range(mid_points):
			var prev_point_pos := curve.get_point_position(smoothpoint_id)
			var current_point_pos := curve.get_point_position(smoothpoint_id + 1)
			var next_point_pos := curve.get_point_position(smoothpoint_id + 2)
			# Calculate vectors to previous and next points and the average direction
			var to_prev := (prev_point_pos - current_point_pos).normalized()
			var to_next := (next_point_pos - current_point_pos).normalized()
			var smooth_dir := (to_next - to_prev).normalized()
			var distance := (prev_point_pos.distance_to(current_point_pos) + 
							current_point_pos.distance_to(next_point_pos)) * 0.25
			curve.set_point_in(smoothpoint_id + 1, smooth_dir * -distance)
			curve.set_point_out(smoothpoint_id + 1, smooth_dir * distance)

## Extrudes the diamond along the curve once at map load, so spawning an arc
## only uploads a ready mesh instead of running CSG. Matches the old
## CSGPolygon3D: rings every ~MESH_INTERVAL, u = distance along the curve,
## sides in the top half of v, caps in the bottom half.
func build_mesh_arrays() -> void:
	var length := curve.get_baked_length()
	var rings := maxi(1, ceili(length / MESH_INTERVAL))
	var step := length / rings
	var sides := MESH_POLYGON.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_bases: Array[Basis] = []
	var ring_points: Array[Vector3] = []
	var prev_point := curve.sample_baked(0.0)
	for i in rings + 1:
		var offset := i * step
		var point := curve.sample_baked(offset)
		var direction := point - prev_point if i > 0 else curve.sample_baked(step) - point
		var basis := Basis.looking_at(direction, curve.sample_baked_up_vector(offset, true))
		ring_bases.append(basis)
		ring_points.append(point)
		for j in sides + 1:
			var p := MESH_POLYGON[j % sides]
			var local := basis * Vector3(p.x, p.y, 0.0)
			verts.append(point + local)
			normals.append(local.normalized())
			uvs.append(Vector2(offset, j * 0.5 / sides))
		if i > 0:
			var a := (i - 1) * (sides + 1)
			var b := i * (sides + 1)
			for j in sides:
				indices.append_array([a + j, b + j, a + j + 1, b + j, b + j + 1, a + j + 1])
		prev_point = point
	# caps, with polygon coordinates mapped into the bottom half of the texture
	for end in 2:
		var basis := ring_bases[0 if end == 0 else rings]
		var start := verts.size()
		for p in MESH_POLYGON:
			verts.append(ring_points[0 if end == 0 else rings] + basis * Vector3(p.x, p.y, 0.0))
			normals.append(basis.z if end == 0 else -basis.z)
			var n := (p + Vector2(MESH_RADIUS, MESH_RADIUS)) / (2.0 * MESH_RADIUS)
			uvs.append(Vector2(0.5 * n.x if end == 0 else 1.0 - 0.5 * n.x, 1.0 - 0.5 * n.y))
		if end == 0:
			indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
		else:
			indices.append_array([start, start + 2, start + 1, start, start + 3, start + 2])
	mesh_arrays = []
	mesh_arrays.resize(Mesh.ARRAY_MAX)
	mesh_arrays[Mesh.ARRAY_VERTEX] = verts
	mesh_arrays[Mesh.ARRAY_NORMAL] = normals
	mesh_arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh_arrays[Mesh.ARRAY_INDEX] = indices

static func new_v2(arc_dict: Dictionary) -> ArcInfo:
	return ArcInfo.new(
		int(Utils.get_float(arc_dict, "_colorType", 0)),
		Utils.get_float(arc_dict, "_headTime", 0.0),
		Utils.precise_measurement(Utils.get_float(arc_dict, "_headLineIndex", 0)),
		Utils.precise_layer(Utils.get_float(arc_dict, "_headLineLayer", 0)),
		Utils.precise_angle_rad(Utils.get_float(arc_dict, "_headCutDirection", 0.), 0.),
		Utils.get_float(arc_dict, "_headControlPointLengthMultiplier", 1.0),
		Utils.get_float(arc_dict, "_tailTime", 0.0),
		Utils.precise_measurement(Utils.get_float(arc_dict, "_tailLineIndex", 0)),
		Utils.precise_layer(Utils.get_float(arc_dict, "_tailLineLayer", 0)),
		Utils.precise_angle_rad(Utils.get_float(arc_dict, "_tailCutDirection", 0), 0),
		Utils.get_float(arc_dict, "_tailControlPointLengthMultiplier", 1.0),
		int(Utils.get_float(arc_dict, "_sliderMidAnchorMode", 0)),
		Utils.get_float(arc_dict, "hr", 0),
		Utils.get_float(arc_dict, "tr", 0)
	)

static func new_v3(arc_dict: Dictionary) -> ArcInfo:
	return ArcInfo.new(
		int(Utils.get_float(arc_dict, "c", 0)),
		Utils.get_float(arc_dict, "b", 0.0),
		Utils.precise_measurement(Utils.get_float(arc_dict, "x", 0)),
		Utils.precise_layer(Utils.get_float(arc_dict, "y", 0)),
		Utils.precise_angle_rad(Utils.get_float(arc_dict, "d", 0), Utils.get_float(arc_dict, "head_angle_offset", 0)),
		Utils.get_float(arc_dict, "mu", 1.0),
		Utils.get_float(arc_dict, "tb", 0.0),
		Utils.precise_measurement(Utils.get_float(arc_dict, "tx", 0)),
		Utils.precise_layer(Utils.get_float(arc_dict, "ty", 0)),
		Utils.precise_angle_rad(Utils.get_float(arc_dict, "tc", 0), Utils.get_float(arc_dict, "tail_angle_offset", 0)),
		Utils.get_float(arc_dict, "tmu", 1.0),
		int(Utils.get_float(arc_dict, "m", 0)),
		Utils.get_float(arc_dict, "hr", 0),
		Utils.get_float(arc_dict, "tr", 0)
	)
