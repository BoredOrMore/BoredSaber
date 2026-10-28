class_name CutFlash
extends Node3D
## Sparks off a cut, as the player drew them: they leave the whole cut line through the note (not one point), most
## thrown back against the swing (up for a down cut) in a fountain that spreads and falls away to the sides under
## gravity, and a few carried on along the swing. Hot white cooling to the saber's colour (CPU particles with
## short trails, SparkStreak.gdshader). COUNT pairs of emitters reused in turn, so a burst of cuts never
## allocates. Nothing stays hanging where the cut was: a flat streak left there looked fake to the player. Sizes
## in metres, untuned.

const COUNT := 6
## a spark's trail: its width and length in metres at scale 1 (two crossed strips along its velocity)
## (the player found 4 mm by 12 cm too small and asked for the earlier size back)
const SPARK_WIDTH := 0.024
const SPARK_TRAIL := 0.3
const SPARK_SHADER := preload("res://game/SparkStreak.gdshader")
## half the length of the cut line the sparks leave from, along the swing through the note
const CUT_LINE_HALF := 0.18
## the fountain thrown back against the swing
const FOUNTAIN_SPARKS := 28
## speeds at a full swing, spread wide so some sparks shoot far and some drop short along the same narrow line
## (the player asked for random speeds within a plume that doesn't open out)
const FOUNTAIN_SPEED_MIN := 1.8
const FOUNTAIN_SPEED_MAX := 4.8
const FOUNTAIN_SPREAD_DEG := 40.0
const FOUNTAIN_SECONDS := 0.5
## the few carried on along the swing
const SPRAY_SPARKS := 8
const SPRAY_SPEED_MIN := 2.0
const SPRAY_SPEED_MAX := 5.0
const SPRAY_SPREAD_DEG := 8.0
const SPRAY_SECONDS := 0.4
## pulls the sparks into falling arcs (m/s²)
const SPARK_GRAVITY := 9.0
## The swing drives the sparks through one exponential curve, as the saber trail's opacity does: the tip's speed as
## a share x of SWING_FULL (m/s), eased as (e^(SWING_CURVE x) - 1) / (e^SWING_CURVE - 1), so a soft cut gives a
## small, dim, narrow puff and only a real swing a full fountain. It scales the sparks' speed (the fountain's
## height) from SPEED_SCALE_MIN to 1, their brightness from BRIGHTNESS_MIN to 1, the fountain's spread between the
## two angles below, and the pull down by the speed's square root.
const SWING_FULL := 6.0
const SWING_CURVE := 3.0
const SPEED_SCALE_MIN := 0.35
const BRIGHTNESS_MIN := 0.2
## a narrow plume close along the swing, not a fan (the player's sketch: within about 20 degrees)
const FOUNTAIN_SPREAD_MIN_DEG := 6.0
const FOUNTAIN_SPREAD_MAX_DEG := 9.0
## sparks vary in length (and width) only this much, so the burst looks even
const SPARK_SCALE_MIN := 0.85
const SPARK_SCALE_MAX := 1.15
## Dust beside the sparks (owner, 2026-10-28; doc/research/cut-dust-plan.md option 2): DUST_MOTES soft motes puff out
## of the cut slowly (DUST_SPEED_MIN/MAX at a full swing) with strong drag, swirl round the cut in a vortex the swing
## sets (CutDust.gdshader: spinning the way the saber went, DUST_SPIN at a full swing, slowing by DUST_SPIN_DRAG), then
## drift with the track past the player and out to the sides (DUST_DRIFT_BACK, DUST_DRIFT_SIDE, a gentle pull), so they
## clear the note lanes, fading over DUST_SECONDS. In the note colour leaned DUST_GREY of the way to DUST_WHITE, so it
## reads as dust in light, not as something to cut. Untuned until seen on the headset.
## The cut itself (owner, 2026-10-28): the sparks, born along the cut line the way the saber went, break up into the
## dust, whose motes start along that same line (the emitter turned like the sparks'), not from a blob. A separate
## streak hanging on the cut line was removed before (2026-10-22, dd6c828: it looked fake), so the line is only the
## sparks. The motes are small crisp points, DUST_SIZE across, growing only DUST_SIZE_GROW (the first, 6 cm and 2.5x with
## a soft edge, looked blurry on the headset).
const DUST_MOTES := 40
const DUST_SECONDS := 1.5
const DUST_SIZE := 0.022
const DUST_SIZE_GROW := 1.2
const DUST_SPEED_MIN := 0.2
const DUST_SPEED_MAX := 1.2
const DUST_DRAG := 2.5
const DUST_SPIN := 9.0
const DUST_SPIN_DRAG := 1.8
const DUST_DRIFT_BACK := 2.2
const DUST_DRIFT_SIDE := 1.2
const DUST_GREY := 0.8
const DUST_WHITE := Color(0.86, 0.87, 0.9)
const DUST_ALPHA := 0.9
const DUST_SHADER := preload("res://game/CutDust.gdshader")

var _next := 0
var _fountains: Array[CPUParticles3D] = []
var _sprays: Array[CPUParticles3D] = []
var _dusts: Array[CPUParticles3D] = []

func _ready() -> void:
	for i in COUNT:
		# each emitter's local y is the swing reversed (set per cut), so +y throws back, -y carries on
		var fountain := _make_sparks(FOUNTAIN_SPARKS, FOUNTAIN_SECONDS, FOUNTAIN_SPEED_MIN, FOUNTAIN_SPEED_MAX)
		fountain.spread = FOUNTAIN_SPREAD_DEG
		fountain.direction = Vector3.UP
		_fountains.append(fountain)
		var spray := _make_sparks(SPRAY_SPARKS, SPRAY_SECONDS, SPRAY_SPEED_MIN, SPRAY_SPEED_MAX)
		spray.spread = SPRAY_SPREAD_DEG
		spray.direction = Vector3.DOWN
		_sprays.append(spray)
		_dusts.append(_make_dust())

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

func _make_sparks(amount: int, seconds: float, speed_min: float, speed_max: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.mesh = spark_mesh()
	sparks.particle_flag_align_y = true
	sparks.amount = amount
	sparks.lifetime = seconds
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.local_coords = false
	sparks.initial_velocity_min = speed_min
	sparks.initial_velocity_max = speed_max
	sparks.scale_amount_min = SPARK_SCALE_MIN
	sparks.scale_amount_max = SPARK_SCALE_MAX
	sparks.gravity = Vector3(0.0, -SPARK_GRAVITY, 0.0)
	# from anywhere along the cut line (the emitter's local y)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.005, CUT_LINE_HALF, 0.005)
	sparks.color_ramp = Gradient.new()
	add_child(sparks)
	return sparks

## One emitter of a cut's dust: soft round motes from the cut line, swirled and faded by CutDust.gdshader.
func _make_dust() -> CPUParticles3D:
	var dust := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * DUST_SIZE
	var material := ShaderMaterial.new()
	material.shader = DUST_SHADER
	material.set_shader_parameter(&"lifetime", DUST_SECONDS)
	material.set_shader_parameter(&"vortex_drag", DUST_SPIN_DRAG)
	quad.material = material
	dust.mesh = quad
	dust.amount = DUST_MOTES
	dust.lifetime = DUST_SECONDS
	dust.one_shot = true
	dust.explosiveness = 1.0
	dust.emitting = false
	dust.local_coords = false
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.damping_min = DUST_DRAG
	dust.damping_max = DUST_DRAG * 1.3
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(0.004, CUT_LINE_HALF, 0.004)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 1.0))
	grow.add_point(Vector2(1.0, DUST_SIZE_GROW))
	dust.scale_amount_curve = grow
	dust.color_ramp = Gradient.new()
	add_child(dust)
	return dust

## The swing as the player sees it: its part across the line of sight to the cut, so the spray flies the way the
## saber went (down for a down cut) instead of off toward or away from the player with the wrist's turn.
func _across_view(sight: Vector3, swing: Vector3) -> Vector3:
	var across := swing - sight * swing.dot(sight)
	return across.normalized() if across.length() > 1e-4 else Vector3.DOWN

## Sends sparks off the cut line through `at` along the swing: a fountain back against it and a spray along it.
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
	var fountain := _fountains[i]
	var spray := _sprays[i]
	fountain.initial_velocity_min = FOUNTAIN_SPEED_MIN * speed_scale
	fountain.initial_velocity_max = FOUNTAIN_SPEED_MAX * speed_scale
	fountain.spread = lerpf(FOUNTAIN_SPREAD_MIN_DEG, FOUNTAIN_SPREAD_MAX_DEG, power)
	spray.initial_velocity_min = SPRAY_SPEED_MIN * speed_scale
	spray.initial_velocity_max = SPRAY_SPEED_MAX * speed_scale
	for sparks: CPUParticles3D in [fountain, spray]:
		sparks.gravity = Vector3(0.0, -SPARK_GRAVITY * sqrt(speed_scale), 0.0)
		sparks.global_transform = Transform3D(basis, at)
		sparks.color_ramp.set_color(0, Color(1.0, 1.0, 1.0, lerpf(BRIGHTNESS_MIN, 1.0, power)))
		sparks.color_ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
		sparks.restart()
	if DebugView.flags & DebugView.NO_CUT_DUST == 0:
		_puff(_dusts[i], at, basis, swing, toward, power, color)

## Puffs a cut's dust at `at`: its vortex turns round the axis across the swing and the line to the player, the way
## the saber went, as fast as the swing was strong; it drifts toward the player and out to the cut's side.
func _puff(dust: CPUParticles3D, at: Vector3, basis: Basis, swing: Vector3, toward: Vector3, power: float,
		color: Color) -> void:
	var axis := swing.cross(toward)
	axis = axis.normalized() if axis.length() > 1e-4 else Vector3.RIGHT
	var material := (dust.mesh as QuadMesh).material as ShaderMaterial
	material.set_shader_parameter(&"vortex_centre", at)
	material.set_shader_parameter(&"vortex_axis", axis)
	material.set_shader_parameter(&"vortex_spin", DUST_SPIN * power)
	# the motes start along the cut line (the emitter's local y, as the sparks')
	dust.global_transform = Transform3D(basis, at)
	dust.initial_velocity_min = DUST_SPEED_MIN * lerpf(SPEED_SCALE_MIN, 1.0, power)
	dust.initial_velocity_max = DUST_SPEED_MAX * lerpf(SPEED_SCALE_MIN, 1.0, power)
	dust.gravity = Vector3(signf(at.x) * DUST_DRIFT_SIDE, 0.0, DUST_DRIFT_BACK)
	var tint := color.lerp(DUST_WHITE, DUST_GREY)
	dust.color_ramp.set_color(0, Color(tint, DUST_ALPHA * lerpf(BRIGHTNESS_MIN, 1.0, power)))
	dust.color_ramp.set_color(1, Color(tint, 0.0))
	dust.restart()
