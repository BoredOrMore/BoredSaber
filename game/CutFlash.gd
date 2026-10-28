class_name CutFlash
extends Node3D
## Sparks off a cut, as Beat Saber's (owner, 2026-10-28; measured frame by frame in the PC recording, 128.6-129.6 s,
## doc/research/cut-dust-plan.md section 7): born white-hot along the whole cut line through the note, they fly out
## sideways from it and along the swing, harder and wider the harder the swing; a strong smooth drag stops them within
## about SPARK_DRAG's 0.2 s, a little gravity lets them sag, and they fade out after SPARK_SECONDS. Each is a crisp
## streak as long as its speed carries it (CutSpark.gdshader), so it shortens as it slows.
## While they hang there the blades push them (owner, 2026-10-28): a blade passing within WAKE_RADIUS drags a spark along
## with it, more the nearer it passes, so a swing through the sparks sweeps them away. A pushed spark is never carried
## into the note lanes ahead of the player (LANE_*): there it can only move out to the side and back.
## Simulated here (CPUParticles3D lets nobody touch a particle) and drawn as one MultiMesh; at most COUNT bursts' sparks
## at once, a new burst taking the oldest sparks' slots, so nothing allocates. A streak left hanging on the cut line
## looked fake (2026-10-22, dd6c828), so the line is only the sparks'. Sizes in metres, untuned until seen on the headset.
const COUNT := 5
## the trail used by other sparks (spark_mesh: the clash, Metal Factory): its width and length in metres at scale 1
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## a cut spark: a streak at most STREAK_LENGTH long and POINT_SIZE wide
const CUT_SPARK_SHADER := preload("res://game/CutSpark.gdshader")
const STREAK_LENGTH := 0.12
const POINT_SIZE := 0.022
## half the length of the cut line the sparks leave from, along the swing through the note
const CUT_LINE_HALF := 0.25
## sparks a burst (Beat Saber shows about 50-80)
const SPARKS := 56
## a spark's start direction: out of the cut line to either side (SIDE), along the swing (ALONG) and a random part
## (SCATTER), each a weight before normalising (the side part random in size, so the burst is one cloud, not two); its speed (m/s) at a full swing
const SIDE := 0.8
const ALONG := 1.0
const SCATTER := 0.6
const SPEED_MIN := 1.5
const SPEED_MAX := 5.0
## drag (speed lost per second, as a rate: e^(-SPARK_DRAG t)), gravity (m/s²), and life (s), each spark between
## SPARK_SECONDS_MIN and SPARK_SECONDS. From the recording: the burst spreads about 0.3-0.5 m in its first 0.2 s and
## hardly moves after, its lower sparks sag a little, it starts to fade at about 0.45 s and is gone by about 0.85 s.
const SPARK_DRAG := 7.0
const SPARK_GRAVITY := 1.5
const SPARK_SECONDS_MIN := 0.7
const SPARK_SECONDS := 1.0
## the colour it cools to: the note colour leaned this far to a grey-white
const SPARK_GREY := 0.35
const SPARK_WHITE := Color(0.86, 0.87, 0.9)
## The swing drives the sparks through one exponential curve, as the saber trail's opacity does: the tip's speed as
## a share x of SWING_FULL (m/s), eased as (e^(SWING_CURVE x) - 1) / (e^SWING_CURVE - 1), so a soft cut gives a
## small, dim, narrow puff and only a real swing a full burst. It scales the sparks' speed from SPEED_SCALE_MIN to 1,
## their brightness from BRIGHTNESS_MIN to 1, and how many fly (from SPARKS_MIN_SHARE of SPARKS).
const SWING_FULL := 6.0
const SWING_CURVE := 3.0
const SPEED_SCALE_MIN := 0.35
const BRIGHTNESS_MIN := 0.2
const SPARKS_MIN_SHARE := 0.4
## sparks vary in size only this much, so the burst looks even
const SPARK_SCALE_MIN := 0.85
const SPARK_SCALE_MAX := 1.15
## the blades' push: how near a spark must be (m), the share of the gap to the blade's speed a spark takes per frame at
## the blade (less toward WAKE_RADIUS), and the slowest blade that pushes anything (m/s)
const WAKE_RADIUS := 0.12
const WAKE_PULL := 0.5
const WAKE_MIN_SPEED := 0.5
## the note lanes ahead of the player a pushed spark may not be carried into: half their width in lanes from the
## middle, their rows' height (m), everything farther than the hit plane, and how hard a pushed spark there is moved out
## to the side and back (m/s²)
const LANE_HALF_LANES := 2.0
const LANE_BOTTOM := 0.5
const LANE_TOP := 2.3
const LANE_CLEAR_ACCEL := 3.0
## floats per spark in the MultiMesh buffer: a 3x4 transform, a colour and the custom data
const STRIDE := 20

## the blades that push the sparks (BeepSaber_Game sets the two sabers)
var sabers: Array[LightSaber] = []
## an extra blade (base, tip) for the benchmark and captures, which have nobody swinging; empty when unused
var test_blade := PackedVector3Array()
## the time spent simulating in the last frame (µs; 0 with no sparks), for the benchmark
var sim_usec := 0
var _multimesh := MultiMesh.new()
var _buffer := PackedFloat32Array()
var _count := 0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _bright := PackedFloat32Array()
var _tint := PackedColorArray()
var _pushed := PackedByteArray()
## each blade's base and tip last frame, by blade (the sabers', then test_blade)
var _blade_past: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]

func _ready() -> void:
	var most := COUNT * SPARKS
	_pos.resize(most)
	_vel.resize(most)
	_age.resize(most)
	_life.resize(most)
	_size.resize(most)
	_bright.resize(most)
	_tint.resize(most)
	_pushed.resize(most)
	_buffer.resize(most * STRIDE)
	var quad := QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = CUT_SPARK_SHADER
	material.set_shader_parameter(&"streak_length", STREAK_LENGTH)
	material.set_shader_parameter(&"point_size", POINT_SIZE)
	quad.material = material
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = most
	_multimesh.visible_instance_count = 0
	# the quads are sized in the shader, so the instances' own box means nothing; never cull the sparks
	_multimesh.custom_aabb = AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.top_level = true
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## A spark with a trail for CPU particles with particle_flag_align_y (the clash, Metal Factory): two crossed strips along +y (the velocity),
## the head at the top, so it shows from every side but straight along its path.
static func spark_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for across: Vector3 in [Vector3(SPARK_WIDTH * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, SPARK_WIDTH * 0.5)]:
		var tail := Vector3(0.0, -SPARK_TRAIL, 0.0)
		vertices.append_array([tail - across, tail + across, across, tail - across, across, -across])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SPARK_SHADER
	mesh.surface_set_material(0, material)
	return mesh

## The swing as the player sees it: its part across the line of sight to the cut, so the sparks fly the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(sight: Vector3, swing: Vector3) -> Vector3:
	var across := swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends sparks off the cut line through `at`: out to both sides of it and along the swing, harder the harder the swing.
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var camera := get_viewport().get_camera_3d()
	var sight := (at - camera.global_position).normalized() if camera else Vector3.FORWARD
	var along := _across_view(sight, swing)
	var side := along.cross(sight).normalized()
	var x := clampf(swing.length() / SWING_FULL, 0.0, 1.0)
	var power := (exp(SWING_CURVE * x) - 1.0) / (exp(SWING_CURVE) - 1.0)
	var speed_scale := lerpf(SPEED_SCALE_MIN, 1.0, power)
	var tint := color.lerp(SPARK_WHITE, SPARK_GREY)
	var bright := lerpf(BRIGHTNESS_MIN, 1.0, power)
	for n in roundi(SPARKS * lerpf(SPARKS_MIN_SHARE, 1.0, power)):
		var i := _count
		if _count < _pos.size():
			_count += 1
		else:
			i = _oldest()
		var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var out := side * SIDE * randf_range(-1.0, 1.0) + along * ALONG + scatter * SCATTER
		_pos[i] = at + along * randf_range(-CUT_LINE_HALF, CUT_LINE_HALF)
		_vel[i] = out.normalized() * randf_range(SPEED_MIN, SPEED_MAX) * speed_scale
		_age[i] = 0.0
		_life[i] = randf_range(SPARK_SECONDS_MIN, SPARK_SECONDS)
		_size[i] = randf_range(SPARK_SCALE_MIN, SPARK_SCALE_MAX)
		_bright[i] = bright
		_tint[i] = tint
		_pushed[i] = 0

## The slot of the spark nearest its end.
func _oldest() -> int:
	var oldest := 0
	for i in _count:
		if _age[i] / _life[i] > _age[oldest] / _life[oldest]:
			oldest = i
	return oldest

## The blades this frame as [base, tip, base velocity, tip velocity], only those out and moving.
func _blades(delta: float) -> Array[PackedVector3Array]:
	var blades: Array[PackedVector3Array] = []
	for b in sabers.size() + 1:
		var now := test_blade
		if b < sabers.size():
			var saber := sabers[b]
			var out := saber.is_extended() and saber.is_visible_in_tree()
			now = PackedVector3Array([saber.global_position, saber.saber_end]) if out else PackedVector3Array()
		var past := _blade_past[b]
		_blade_past[b] = now
		if now.size() != 2 or past.size() != 2 or delta <= 0.0:
			continue
		var base_speed := (now[0] - past[0]) / delta
		var tip_speed := (now[1] - past[1]) / delta
		if maxf(base_speed.length(), tip_speed.length()) >= WAKE_MIN_SPEED:
			blades.append(PackedVector3Array([now[0], now[1], base_speed, tip_speed]))
	return blades

## Moves every spark (drag, gravity, the blades' push), drops the spent ones and hands the rest to the MultiMesh.
func _process(delta: float) -> void:
	if _count == 0:
		_blades(delta)
		sim_usec = 0
		return
	var started := Time.get_ticks_usec()
	var blades := _blades(delta)
	var reach: Array[AABB] = []
	for blade in blades:
		reach.append(AABB(blade[0], Vector3.ZERO).expand(blade[1]).grow(WAKE_RADIUS))
	var keep := exp(-SPARK_DRAG * delta)
	var fall := Vector3.DOWN * SPARK_GRAVITY * delta
	var lane_half := LANE_HALF_LANES * Settings.LANE_DISTANCE_X
	var i := 0
	while i < _count:
		var age := _age[i] + delta
		if age >= _life[i]:
			_count -= 1
			_move(_count, i)
			continue
		_age[i] = age
		var p := _pos[i]
		var v := _vel[i] * keep + fall
		for b in blades.size():
			if not reach[b].has_point(p):
				continue
			var blade := blades[b]
			var on := Geometry3D.get_closest_point_to_segment(p, blade[0], blade[1])
			var gap := p.distance_to(on)
			if gap >= WAKE_RADIUS:
				continue
			var length := blade[0].distance_to(blade[1])
			var share := on.distance_to(blade[0]) / length if length > 1e-4 else 1.0
			v += (blade[2].lerp(blade[3], share) - v) * WAKE_PULL * (1.0 - gap / WAKE_RADIUS)
			_pushed[i] = 1
		var moved := p + v * delta
		if _pushed[i] == 1 and absf(moved.x) < lane_half and moved.y > LANE_BOTTOM and moved.y < LANE_TOP \
				and moved.z < Constants.HIT_PLANE_Z:
			# in the lanes ahead a pushed spark only goes out to the side and back
			var out := 1.0 if p.x >= 0.0 else -1.0
			if (moved.x - p.x) * out < 0.0:
				moved.x = p.x
			moved.z = maxf(moved.z, p.z)
			v.x = out * (maxf(v.x * out, 0.0) + LANE_CLEAR_ACCEL * delta)
			v.z = maxf(v.z, 0.0) + LANE_CLEAR_ACCEL * delta
		_pos[i] = moved
		_vel[i] = v
		_write(i, moved, v)
		i += 1
	_multimesh.visible_instance_count = _count
	_multimesh.buffer = _buffer
	sim_usec = Time.get_ticks_usec() - started

## Moves the spark in slot `from` to slot `to` (filling the gap a spent one left).
func _move(from: int, to: int) -> void:
	_pos[to] = _pos[from]
	_vel[to] = _vel[from]
	_age[to] = _age[from]
	_life[to] = _life[from]
	_size[to] = _size[from]
	_bright[to] = _bright[from]
	_tint[to] = _tint[from]
	_pushed[to] = _pushed[from]

## Writes spark `i` into the buffer: its place, its path as its y axis (the streak's direction), its size as the axes'
## length, its colour, and its brightness, life share and speed as custom data (CutSpark.gdshader).
func _write(i: int, at: Vector3, v: Vector3) -> void:
	var size := _size[i]
	var speed := v.length()
	var along := v * (size / speed) if speed > 1e-4 else Vector3(0.0, size, 0.0)
	var tint := _tint[i]
	var o := i * STRIDE
	_buffer[o] = size
	_buffer[o + 1] = along.x
	_buffer[o + 2] = 0.0
	_buffer[o + 3] = at.x
	_buffer[o + 4] = 0.0
	_buffer[o + 5] = along.y
	_buffer[o + 6] = 0.0
	_buffer[o + 7] = at.y
	_buffer[o + 8] = 0.0
	_buffer[o + 9] = along.z
	_buffer[o + 10] = 0.0
	_buffer[o + 11] = at.z
	_buffer[o + 12] = tint.r
	_buffer[o + 13] = tint.g
	_buffer[o + 14] = tint.b
	_buffer[o + 15] = 1.0
	_buffer[o + 16] = _bright[i]
	_buffer[o + 17] = _age[i] / _life[i]
	_buffer[o + 18] = speed
	_buffer[o + 19] = 0.0
