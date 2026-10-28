class_name CutFlash
extends Node3D
## Sparks off a cut, as Beat Saber's (owner, 2026-10-28; measured frame by frame in the PC recording, 128.6-129.6 s,
## doc/research/cut-dust-plan.md section 7): born on the note's faces where the cut crosses them (owner: "the face of
## the box mesh"), they fly out from those faces and along the swing, harder and wider the harder the swing; a strong
## smooth drag stops them within about SPARK_DRAG's 0.2 s, a little gravity lets them sag, and they fade out after
## SPARK_SECONDS. Each is a crisp streak as long as its speed carries it, white-hot with a thin rim of the note colour
## (CutSpark.gdshader).
## While they hang there the blades push them (owner, 2026-10-28): a blade passing within WAKE_RADIUS drags a spark
## along with it, more the nearer it passes, so a swing through the sparks sweeps them away. A pushed spark is never
## carried into the note lanes ahead of the player (LANE_*): there it can only move out to the side and back.
## One MultiMesh of COUNT blocks of SPARKS slots, a new burst taking the oldest block, so nothing allocates. The shader
## moves each spark along its drag-and-gravity path from where it was born or last pushed; the CPU works sparks out
## only when a blade passes near their burst (simulating every spark each frame in GDScript cost 0.46 ms on the Mac,
## 2026-10-28). A streak left hanging on the cut line looked fake (2026-10-22, dd6c828), so the line is only the
## sparks'. Sizes in metres, untuned until seen on the headset.
const COUNT := 5
## the trail used by other sparks (spark_mesh: the clash, Metal Factory): its width and length in metres at scale 1
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## a cut spark: a streak at most STREAK_LENGTH long and POINT_SIZE wide, SPARK_SIZE of the first ones' 0.12 m and
## 0.022 m (owner, 2026-10-28: 0.6 was too small, 0.8)
const CUT_SPARK_SHADER := preload("res://game/CutSpark.gdshader")
const SPARK_SIZE := 0.8
const STREAK_LENGTH := 0.12 * SPARK_SIZE
const POINT_SIZE := 0.022 * SPARK_SIZE
## half the length of the cut line the sparks leave from when no note's mesh is given (the slash block, the bench)
const CUT_LINE_HALF := 0.25
## sparks a burst (Beat Saber shows about 50-80)
const SPARKS := 56
## a spark's start direction: out of the note's face it leaves (weight 1; without a mesh, out to either side of the cut
## line, SIDE, random in size so the burst is one cloud, not two), along the swing (ALONG) and a random part (SCATTER),
## each a weight before normalising; its speed (m/s) at a full swing
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
## middle, their rows' height (m), and everything farther than the hit plane. A push there keeps only the parts of the
## blade's pull that go out to the side and back; drag and gravity never turn a spark round, so it stays out.
const LANE_HALF_LANES := 2.0
const LANE_BOTTOM := 0.5
const LANE_TOP := 2.3
## floats per spark in the MultiMesh buffer: a 3x4 transform, a colour and the custom data
const STRIDE := 20

## the blades that push the sparks (BeepSaber_Game sets the two sabers)
var sabers: Array[LightSaber] = []
## an extra blade (base, tip) for the benchmark and captures, which have nobody swinging; empty when unused
var test_blade := PackedVector3Array()
## the time spent on the sparks in the last frame (µs; 0 with none alive), for the benchmark
var sim_usec := 0
var _multimesh := MultiMesh.new()
var _material := ShaderMaterial.new()
var _buffer := PackedFloat32Array()
var _dirty := false
## the clock the shader moves the sparks by (s)
var _now := 0.0
## the burst each block of SPARKS slots last held: its cut, when it was made, how far its sparks can get from the cut
var _next := 0
var _burst_at := PackedVector3Array()
var _burst_time := PackedFloat32Array()
var _burst_reach := PackedFloat32Array()
## each spark since it was last born or pushed: where and how fast it went, when, its age then, and its whole life
var _from := PackedVector3Array()
var _speed := PackedVector3Array()
var _since := PackedFloat32Array()
var _age_then := PackedFloat32Array()
var _life := PackedFloat32Array()
## each blade's base and tip last frame, by blade (the sabers', then test_blade)
var _blade_past: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]

func _ready() -> void:
	var most := COUNT * SPARKS
	_burst_at.resize(COUNT)
	_burst_time.resize(COUNT)
	_burst_time.fill(-SPARK_SECONDS)
	_burst_reach.resize(COUNT)
	_from.resize(most)
	_speed.resize(most)
	_since.resize(most)
	_age_then.resize(most)
	_life.resize(most)
	_buffer.resize(most * STRIDE)
	var quad := QuadMesh.new()
	_material.shader = CUT_SPARK_SHADER
	_material.set_shader_parameter(&"streak_length", STREAK_LENGTH)
	_material.set_shader_parameter(&"point_size", POINT_SIZE)
	_material.set_shader_parameter(&"drag", SPARK_DRAG)
	_material.set_shader_parameter(&"gravity", SPARK_GRAVITY)
	quad.material = _material
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.use_custom_data = true
	_multimesh.mesh = quad
	_multimesh.instance_count = most
	# the shader moves the sparks and sizes the quads, so the instances' own box means nothing; never cull them
	_multimesh.custom_aabb = AABB(Vector3(-100.0, -100.0, -100.0), Vector3(200.0, 200.0, 200.0))
	# one dark spark on the first frame builds the shader at load, not at the first cut (it froze the Mac 370 ms)
	_write(0, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 1.0, 1.0, 0.0, Color.BLACK)
	_multimesh.buffer = _buffer
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = _multimesh
	instance.top_level = true
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## A spark with a trail for CPU particles with particle_flag_align_y: two crossed strips along +y (the velocity),
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

## Sends sparks off a cut through `at` along the swing: with the note's mesh (`box`, its global transform, and `extent`,
## its box) and the cut plane's `normal`, from where the plane crosses the mesh's faces, out from each face; without,
## from a cut line along the swing, out to both sides. Harder the harder the swing. They take the oldest burst's block.
func flash(at: Vector3, swing: Vector3, color: Color, normal := Vector3.ZERO, box := Transform3D.IDENTITY,
		extent := AABB()) -> void:
	var camera := get_viewport().get_camera_3d()
	var sight := (at - camera.global_position).normalized() if camera else Vector3.FORWARD
	var along := _across_view(sight, swing)
	var side := along.cross(sight).normalized()
	var x := clampf(swing.length() / SWING_FULL, 0.0, 1.0)
	var power := (exp(SWING_CURVE * x) - 1.0) / (exp(SWING_CURVE) - 1.0)
	var speed_scale := lerpf(SPEED_SCALE_MIN, 1.0, power)
	var bright := lerpf(BRIGHTNESS_MIN, 1.0, power)
	var burst := _next
	_next = (_next + 1) % COUNT
	_burst_at[burst] = at
	_burst_time[burst] = _now
	# the farthest a spark gets: its run against the drag, its sag, and the cut line it starts on
	_burst_reach[burst] = SPEED_MAX * speed_scale / SPARK_DRAG + SPARK_GRAVITY * SPARK_SECONDS / SPARK_DRAG \
			+ CUT_LINE_HALF
	var flying := roundi(SPARKS * lerpf(SPARKS_MIN_SHARE, 1.0, power))
	for n in SPARKS:
		var i := burst * SPARKS + n
		if n >= flying:
			_life[i] = 0.0
			_write(i, Vector3.ZERO, Vector3.ZERO, _now, 0.0, 0.0, 1.0, 0.0, Color.BLACK)
			continue
		var scatter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var out := side * SIDE * randf_range(-1.0, 1.0)
		_from[i] = at + along * randf_range(-CUT_LINE_HALF, CUT_LINE_HALF)
		if extent.has_volume() and normal != Vector3.ZERO:
			var face := _on_face(at, normal, box, extent)
			_from[i] = face[0]
			out = face[1]
		out += along * ALONG + scatter * SCATTER
		_speed[i] = out.normalized() * randf_range(SPEED_MIN, SPEED_MAX) * speed_scale
		_since[i] = _now
		_age_then[i] = 0.0
		_life[i] = randf_range(SPARK_SECONDS_MIN, SPARK_SECONDS)
		_write(i, _from[i], _speed[i], _now, 0.0, _life[i], randf_range(SPARK_SCALE_MIN, SPARK_SCALE_MAX), bright, color)
	_dirty = true

## A random point where the cut plane (through `at`, facing `normal`) crosses the faces of the box `extent` placed by
## `box`, and that face's outward normal, both in world space: a random direction along the plane from `at`, to where
## it leaves the box.
func _on_face(at: Vector3, normal: Vector3, box: Transform3D, extent: AABB) -> Array[Vector3]:
	var to_box := box.affine_inverse()
	var centre := extent.get_center()
	var half := extent.size * 0.5
	var start := (to_box * at).clamp(extent.position, extent.end)
	var plane_normal := (to_box.basis * normal).normalized()
	var across := plane_normal.cross(Vector3.UP if absf(plane_normal.y) < 0.9 else Vector3.RIGHT).normalized()
	var way := across.rotated(plane_normal, randf() * TAU)
	var reach := INF
	var axis := 0
	for k in 3:
		if absf(way[k]) > 1e-5:
			var t := (centre[k] + signf(way[k]) * half[k] - start[k]) / way[k]
			if t < reach:
				reach = t
				axis = k
	var face := Vector3.ZERO
	face[axis] = signf(way[axis])
	return [box * (start + way * maxf(reach, 0.0)), (box.basis * face).normalized()]

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

## Advances the sparks' clock (the shader moves them: drag and gravity, CutSpark.gdshader) and lets the blades push
## the sparks of any burst they pass near; only then are those sparks worked out here.
func _process(delta: float) -> void:
	_now += delta
	_material.set_shader_parameter(&"now", _now)
	var blades := _blades(delta)
	var started := Time.get_ticks_usec()
	var alive := false
	for burst in COUNT:
		if _now - _burst_time[burst] >= SPARK_SECONDS:
			continue
		alive = true
		for blade in blades:
			var reach := AABB(blade[0], Vector3.ZERO).expand(blade[1]).grow(WAKE_RADIUS + _burst_reach[burst])
			if reach.has_point(_burst_at[burst]):
				_push(burst, blade)
	if _dirty:
		_multimesh.buffer = _buffer
		_dirty = false
	sim_usec = Time.get_ticks_usec() - started if alive else 0

## Pulls the sparks of `burst` within WAKE_RADIUS of `blade` toward its speed, more the nearer it passes; in the note
## lanes ahead only the parts going out to the side and back.
func _push(burst: int, blade: PackedVector3Array) -> void:
	var lane_half := LANE_HALF_LANES * Settings.LANE_DISTANCE_X
	var length := blade[0].distance_to(blade[1])
	var fall := Vector3.DOWN * SPARK_GRAVITY / SPARK_DRAG
	for i in range(burst * SPARKS, (burst + 1) * SPARKS):
		var t := _now - _since[i]
		if _age_then[i] + t >= _life[i]:
			continue
		# where it is now and how fast it goes (the shader's path)
		var keep := exp(-SPARK_DRAG * t)
		var p := _from[i] + fall * t + (_speed[i] - fall) * (1.0 - keep) / SPARK_DRAG
		var on := Geometry3D.get_closest_point_to_segment(p, blade[0], blade[1])
		var gap := p.distance_to(on)
		if gap >= WAKE_RADIUS:
			continue
		var v := fall + (_speed[i] - fall) * keep
		var share := on.distance_to(blade[0]) / length if length > 1e-4 else 1.0
		var pull := (blade[2].lerp(blade[3], share) - v) * WAKE_PULL * (1.0 - gap / WAKE_RADIUS)
		if absf(p.x) < lane_half and p.y > LANE_BOTTOM and p.y < LANE_TOP and p.z < Constants.HIT_PLANE_Z:
			var out := 1.0 if p.x >= 0.0 else -1.0
			if (v.x + pull.x) * out < 0.0:
				pull.x = -v.x
			if v.z + pull.z < 0.0:
				pull.z = -v.z
		var o := i * STRIDE
		_from[i] = p
		_speed[i] = v + pull
		_age_then[i] += t
		_since[i] = _now
		_write(i, p, _speed[i], _now, _age_then[i], _life[i], _buffer[o], _buffer[o + 16],
				Color(_buffer[o + 12], _buffer[o + 13], _buffer[o + 14]))
		_dirty = true

## Writes spark `i` into the buffer for the shader: where it starts (the transform's origin), its velocity then (the y
## axis), its size (the x axis' x), when it started, its life and its age then (the z axis; the transform stays full
## floats where colour and custom data don't), its note colour, and its brightness as custom data.
func _write(i: int, from: Vector3, speed: Vector3, since: float, age: float, life: float, size: float, bright: float,
		tint: Color) -> void:
	var o := i * STRIDE
	_buffer[o] = size
	_buffer[o + 1] = speed.x
	_buffer[o + 2] = since
	_buffer[o + 3] = from.x
	_buffer[o + 4] = 0.0
	_buffer[o + 5] = speed.y
	_buffer[o + 6] = life
	_buffer[o + 7] = from.y
	_buffer[o + 8] = 0.0
	_buffer[o + 9] = speed.z
	_buffer[o + 10] = age
	_buffer[o + 11] = from.z
	_buffer[o + 12] = tint.r
	_buffer[o + 13] = tint.g
	_buffer[o + 14] = tint.b
	_buffer[o + 15] = 1.0
	_buffer[o + 16] = bright
	_buffer[o + 17] = 0.0
	_buffer[o + 18] = 0.0
	_buffer[o + 19] = 0.0
