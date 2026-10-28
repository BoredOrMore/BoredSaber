class_name CutFlash
extends Node3D
## Sparks off a cut, as the player drew them: they leave the whole cut line through the note (not one point), most
## thrown back against the swing (up for a down cut) in a narrow plume, and a few carried on along the swing.
## Owner, 2026-10-28: the sparks themselves behave like dust, no second layer. Each is born a crisp short streak along
## its path, the way the saber went, then within STREAK_SECONDS shrinks to a small crisp point (CutSpark.gdshader); its
## physics are dust's: hard drag (SPARK_DRAG) so it stops within a few tens of centimetres, weightless, swirling round
## the cut in a vortex the swing sets (spinning the way the saber went, SPARK_SPIN at a full swing, slowing by
## SPARK_SPIN_DRAG), lingering SPARK_SECONDS and drifting with the track past the player and out to the cut's side
## (SPARK_DRIFT_BACK, SPARK_DRIFT_SIDE), so it clears the note lanes. Hot white cooling to the note colour leaned
## SPARK_GREY of the way to SPARK_WHITE, so it reads as dust in light. COUNT pairs of emitters reused in turn, so a
## burst of cuts never allocates. A streak left hanging on the cut line looked fake (2026-10-22, dd6c828), so the line
## is only the sparks'. Sizes in metres, untuned until seen on the headset.
const COUNT := 6
## the trail used by other sparks (spark_mesh: the clash, Metal Factory): its width and length in metres at scale 1
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## a cut spark: a streak STREAK_LENGTH long at birth, a crisp point POINT_SIZE across after STREAK_SECONDS
const CUT_SPARK_SHADER := preload("res://game/CutSpark.gdshader")
const STREAK_LENGTH := 0.12
const STREAK_SECONDS := 0.12
const POINT_SIZE := 0.022
## half the length of the cut line the sparks leave from, along the swing through the note
const CUT_LINE_HALF := 0.18
## the plume thrown back against the swing
const FOUNTAIN_SPARKS := 28
## speeds at a full swing, spread so some sparks fly further than others along the same narrow line
## (the player asked for random speeds within a plume that doesn't open out)
const FOUNTAIN_SPEED_MIN := 1.8
const FOUNTAIN_SPEED_MAX := 4.8
const FOUNTAIN_SPREAD_DEG := 40.0
## the few carried on along the swing
const SPRAY_SPARKS := 8
const SPRAY_SPEED_MIN := 2.0
const SPRAY_SPEED_MAX := 5.0
const SPRAY_SPREAD_DEG := 8.0
## dust's physics, light (owner, 2026-10-28: the first felt heavy, stopping dead): hard drag SPARK_DRAG only while it is
## a streak (the first SPARK_DRAG_SHARE of its life), then SPARK_GLIDE_DRAG so it glides; life; the vortex's spin at a
## full swing (rad/s) and how slowly it dies away; a slight upward lift (SPARK_LIFT, m/s²); the drift toward the player
## and out to the side (m/s²). The gentle sway on top is CutSpark.gdshader's.
const SPARK_DRAG := 4.0
const SPARK_GLIDE_DRAG := 0.8
const SPARK_DRAG_SHARE := 0.1
const SPARK_SECONDS := 1.5
const SPARK_SPIN := 9.0
const SPARK_SPIN_DRAG := 0.7
const SPARK_LIFT := 0.15
const SPARK_DRIFT_BACK := 2.2
const SPARK_DRIFT_SIDE := 1.2
## the colour it cools to: the note colour leaned this far to a grey-white
const SPARK_GREY := 0.8
const SPARK_WHITE := Color(0.86, 0.87, 0.9)
## The swing drives the sparks through one exponential curve, as the saber trail's opacity does: the tip's speed as
## a share x of SWING_FULL (m/s), eased as (e^(SWING_CURVE x) - 1) / (e^SWING_CURVE - 1), so a soft cut gives a
## small, dim, narrow puff and only a real swing a full plume. It scales the sparks' speed from SPEED_SCALE_MIN to 1,
## their brightness from BRIGHTNESS_MIN to 1, the plume's spread between the two angles below, and the vortex's spin.
const SWING_FULL := 6.0
const SWING_CURVE := 3.0
const SPEED_SCALE_MIN := 0.35
const BRIGHTNESS_MIN := 0.2
## a narrow plume close along the swing, not a fan (the player's sketch: within about 20 degrees)
const FOUNTAIN_SPREAD_MIN_DEG := 6.0
const FOUNTAIN_SPREAD_MAX_DEG := 9.0
## sparks vary in size only this much, so the burst looks even
const SPARK_SCALE_MIN := 0.85
const SPARK_SCALE_MAX := 1.15

var _next := 0
var _fountains: Array[CPUParticles3D] = []
var _sprays: Array[CPUParticles3D] = []

func _ready() -> void:
	for i in COUNT:
		# each emitter's local y is the swing reversed (set per cut), so +y throws back, -y carries on
		var fountain := _make_sparks(FOUNTAIN_SPARKS, FOUNTAIN_SPEED_MIN, FOUNTAIN_SPEED_MAX)
		fountain.spread = FOUNTAIN_SPREAD_DEG
		fountain.direction = Vector3.UP
		_fountains.append(fountain)
		var spray := _make_sparks(SPRAY_SPARKS, SPRAY_SPEED_MIN, SPRAY_SPEED_MAX)
		spray.spread = SPRAY_SPREAD_DEG
		spray.direction = Vector3.DOWN
		_sprays.append(spray)

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

## One emitter of cut sparks: streaks that become dust (CutSpark.gdshader), with dust's drag and no gravity.
func _make_sparks(amount: int, speed_min: float, speed_max: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	var quad := QuadMesh.new()
	var material := ShaderMaterial.new()
	material.shader = CUT_SPARK_SHADER
	material.set_shader_parameter(&"lifetime", SPARK_SECONDS)
	material.set_shader_parameter(&"vortex_drag", SPARK_SPIN_DRAG)
	material.set_shader_parameter(&"streak_length", STREAK_LENGTH)
	material.set_shader_parameter(&"streak_seconds", STREAK_SECONDS)
	material.set_shader_parameter(&"point_size", POINT_SIZE)
	quad.material = material
	sparks.mesh = quad
	sparks.particle_flag_align_y = true
	sparks.amount = amount
	sparks.lifetime = SPARK_SECONDS
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.local_coords = false
	sparks.initial_velocity_min = speed_min
	sparks.initial_velocity_max = speed_max
	sparks.damping_min = SPARK_DRAG
	sparks.damping_max = SPARK_DRAG * 1.3
	# hard drag only while it is a streak, then a glide
	var drag := Curve.new()
	drag.add_point(Vector2(0.0, 1.0))
	drag.add_point(Vector2(SPARK_DRAG_SHARE, 1.0))
	drag.add_point(Vector2(SPARK_DRAG_SHARE * 2.0, SPARK_GLIDE_DRAG / SPARK_DRAG))
	drag.add_point(Vector2(1.0, SPARK_GLIDE_DRAG / SPARK_DRAG))
	sparks.damping_curve = drag
	sparks.scale_amount_min = SPARK_SCALE_MIN
	sparks.scale_amount_max = SPARK_SCALE_MAX
	# from anywhere along the cut line (the emitter's local y)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.005, CUT_LINE_HALF, 0.005)
	sparks.color_ramp = Gradient.new()
	add_child(sparks)
	return sparks

## The swing as the player sees it: its part across the line of sight to the cut, so the spray flies the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(sight: Vector3, swing: Vector3) -> Vector3:
	var across := swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends sparks off the cut line through `at` along the swing: a plume back against it and a spray along it, which
## slow, swirl round the cut the way the saber went and drift away past the player.
func flash(at: Vector3, swing: Vector3, color: Color) -> void:
	var i := _next
	_next = (_next + 1) % COUNT
	var camera := get_viewport().get_camera_3d()
	var sight := (at - camera.global_position).normalized() if camera else Vector3.FORWARD
	# local y: against the swing as the player sees it; z: toward the player
	var back := -_across_view(sight, swing)
	var toward := -sight
	var basis := Basis(back.cross(toward), back, toward).orthonormalized()
	var x := clampf(swing.length() / SWING_FULL, 0.0, 1.0)
	var power := (exp(SWING_CURVE * x) - 1.0) / (exp(SWING_CURVE) - 1.0)
	var speed_scale := lerpf(SPEED_SCALE_MIN, 1.0, power)
	var axis := swing.cross(toward)
	axis = axis.normalized() if axis.length() > 1e-4 else Vector3.RIGHT
	var tint := color.lerp(SPARK_WHITE, SPARK_GREY)
	var fountain := _fountains[i]
	var spray := _sprays[i]
	fountain.initial_velocity_min = FOUNTAIN_SPEED_MIN * speed_scale
	fountain.initial_velocity_max = FOUNTAIN_SPEED_MAX * speed_scale
	fountain.spread = lerpf(FOUNTAIN_SPREAD_MIN_DEG, FOUNTAIN_SPREAD_MAX_DEG, power)
	spray.initial_velocity_min = SPRAY_SPEED_MIN * speed_scale
	spray.initial_velocity_max = SPRAY_SPEED_MAX * speed_scale
	for sparks: CPUParticles3D in [fountain, spray]:
		var material := (sparks.mesh as QuadMesh).material as ShaderMaterial
		material.set_shader_parameter(&"vortex_centre", at)
		material.set_shader_parameter(&"vortex_axis", axis)
		material.set_shader_parameter(&"vortex_spin", SPARK_SPIN * power)
		sparks.gravity = Vector3(signf(at.x) * SPARK_DRIFT_SIDE, SPARK_LIFT, SPARK_DRIFT_BACK)
		sparks.global_transform = Transform3D(basis, at)
		sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0, lerpf(BRIGHTNESS_MIN, 1.0, power)))
		sparks.color_ramp.set_color(1, Color(tint, 0.0))
		sparks.restart()
