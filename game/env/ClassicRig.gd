@tool
extends Node3D
class_name ClassicRig
## The Classic environment (doc/assets/classic_tunnel/spec.md; owner, 2026-10-27: the giant test tunnel, blockout): a
## lighting crew rehearses inside a test tunnel built for something far bigger than people, a round bore 120 m
## across (BORE_RADIUS), its ribs running on past RIB_FAR ahead; the track is the maintenance walkway along its
## bottom. The crew hoists six truss bridges up as the song builds (the old frames' build-up, far ones first); on the
## drop the tunnel's own test lights run along its ribs from far to near (rib strips, EventDriver).
## Lights on things that belong there (AGENTS.md "Light", rule 5): the square bars under the trusses and the rib
## strips, the moving heads on the trusses' top chords, the waving lasers' follow spots on the wall catwalks.
## Main elements (bore, trusses, catwalks) symmetric; the props near the track are not.
## Dark boxes in one MultiMesh with the scenery's shader; the rib strips in their own (ArchStrip.gdshader). A tool
## script, so the tunnel shows in the editor too (built, not saved: no owner). Sizes in metres, blockout, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const ARCH_STRIP := preload("res://game/env/ArchStrip.gdshader")
## the bore: radius, its centre's height, the ribs' spacing, nearest and farthest z, boxes round each rib and the rib's
## section (across the ring, along the bore). The track runs along the circle's bottom (owner, 2026-10-27: keep the
## 59 m centre, its size). A lining closes the bore between the ribs (LINING thick, behind them), so the curve rises
## from beside the track instead of opening onto the sky; the ribs and lining under FLOOR_Y are left out and a floor
## plate there, just under the track deck, reaches the lowest lining panels.
const BORE_RADIUS := 60.0
const BORE_CENTRE_Y := 59.0
const FLOOR_Y := -0.3
const LINING := 0.3
const RIB_STEP := 25.0
const RIB_NEAR := 25.0
const RIB_FAR := -600.0
const RIB_SEGMENTS := 24
const RIB := Vector2(2.4, 3.0)
## The truss bridges at the old frames' places, TRUSS_Y up when hoisted: two chords and a web panel between, wall to wall.
const FRAME_Z: Array[float] = [-10.0, -20.0, -30.0, -40.0, -50.0, -60.0]
const TRUSS_Y := 20.0
const TRUSS := Vector2(2.0, 0.6)
## the catwalks along the walls: height, width, from z, to z
const CATWALK := Vector4(8.0, 3.0, -8.0, -64.0)
const CATWALK_RAIL := 1.1
## Props near the track, uneven: [centre, size].
const PROPS := [
	# flight cases stacked on the left
	[Vector3(-6.5, 0.4, -3.0), Vector3(1.2, 0.8, 0.8)], [Vector3(-6.4, 1.2, -3.1), Vector3(1.0, 0.8, 0.7)],
	[Vector3(-7.8, 0.4, -4.2), Vector3(1.2, 0.8, 0.8)],
	# a cable reel further on the left
	[Vector3(-8.0, 0.6, -12.0), Vector3(1.2, 1.2, 0.6)],
	# a scissor lift on the right: base, platform raised to 6 m, its rails
	[Vector3(9.0, 0.4, -16.0), Vector3(2.4, 0.8, 1.2)], [Vector3(9.0, 6.0, -16.0), Vector3(2.6, 0.2, 1.3)],
	[Vector3(9.0, 6.6, -16.6), Vector3(2.6, 1.0, 0.06)],
]
## the scissor lift's crossed arms, between its base and platform (centre, length, tilt)
const SCISSOR := [Vector3(9.0, 3.2, -16.0), 6.6, 0.95]
## a ladder against the right catwalk: its foot and top x, z
const LADDER := Vector3(26.0, 28.6, -30.0)
## the moving heads' tilt axis this far above the truss's top chord (laser_fixture.py: yoke foot 0.54 under it)
const FIXTURE_ABOVE := 0.84
## the rib strips: a segment on each rib box in the upper part of the ring (RIB_STRIP_FROM..1-RIB_STRIP_FROM of the
## circle from the floor), this wide and thick on the rib's inner face
const RIB_STRIP_FROM := 0.15
const RIB_STRIP := Vector2(0.5, 0.4)
## Building the trusses during a song: each truss is flown in on its own share of the show's build-up (EventDriver),
## the far ones first, from FIRST_FRAME_AT to LAST_FRAME_AT; when its share is reached it comes down FLY metres from
## near the ceiling over RISE_SECONDS, and stays (owner, 2026-10-27: from above, so it never crosses the player's view;
## from the floor it stood across the track at eye height). Flown out at a song's start and put back in place for the
## menus. The timing is the old frames' (right on the headset, 2026-10-24).
const FLY := 75.0
const RISE_SECONDS := 1.5
const FIRST_FRAME_AT := 0.1
const LAST_FRAME_AT := 0.8
const BOXES_PER_TRUSS := 3

var rib_strip_material: ShaderMaterial
var _multimesh: MultiMesh
var _boxes: Array[Transform3D] = []
## per truss (FRAME_Z order): how far up it is (0 down, 1 hoisted) and where it is heading
var _lift := PackedFloat32Array()
var _target := PackedFloat32Array()

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	# the trusses' boxes come first, BOXES_PER_TRUSS each in FRAME_Z order (_process moves them)
	var half := truss_half_span()
	for z in FRAME_Z:
		for dy in [TRUSS.x * 0.5, -TRUSS.x * 0.5]:
			boxes.append(_box(Vector3(0.0, TRUSS_Y + dy, z), Vector3(half * 2.0, TRUSS.y, TRUSS.y)))
		boxes.append(_box(Vector3(0.0, TRUSS_Y, z), Vector3(half * 2.0, TRUSS.x, 0.12)))
	boxes.append_array(_ribs())
	boxes.append_array(_floor_and_lining())
	boxes.append_array(_catwalks())
	for p: Array in PROPS:
		boxes.append(_box(p[0], p[1]))
	for side in [-1.0, 1.0]:
		var c: Vector3 = SCISSOR[0]
		boxes.append(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), side * float(SCISSOR[2])) * Basis.from_scale(Vector3(0.12, SCISSOR[1], 0.12)), c))
	boxes.append_array(_ladder())
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		multimesh.set_instance_transform(i, boxes[i])
	_multimesh = multimesh
	_boxes = boxes
	_lift.resize(FRAME_Z.size())
	_lift.fill(1.0)
	_target = _lift.duplicate()
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_add_rib_strips()

## Half the bore's width at the trusses' height: they span wall to wall.
static func truss_half_span() -> float:
	return sqrt(BORE_RADIUS * BORE_RADIUS - pow(BORE_CENTRE_Y - TRUSS_Y, 2.0)) - RIB.x

## Half the bore's width at a height.
static func bore_half_width(y: float) -> float:
	return sqrt(BORE_RADIUS * BORE_RADIUS - pow(BORE_CENTRE_Y - y, 2.0))

## Where a point at `angle` round a rib (0 straight down, increasing up the right wall) sits, and the rib box there.
static func _rib_box(z: float, angle: float, length: float, size: Vector2) -> Transform3D:
	var dir := Vector3(sin(angle), -cos(angle), 0.0)
	var tangent := Vector3(cos(angle), sin(angle), 0.0)
	var basis := Basis(tangent * length, -dir * size.x, Vector3(0.0, 0.0, size.y))
	return Transform3D(basis, Vector3(0.0, BORE_CENTRE_Y, z) + dir * BORE_RADIUS)

## The ribs: a ring of boxes every RIB_STEP from RIB_NEAR to RIB_FAR.
static func _ribs() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var length := TAU * BORE_RADIUS / RIB_SEGMENTS * 1.06
	var z := RIB_NEAR
	while z >= RIB_FAR:
		for i in RIB_SEGMENTS:
			if _above_floor(TAU * (i + 0.5) / RIB_SEGMENTS):
				boxes.append(_rib_box(z, TAU * (i + 0.5) / RIB_SEGMENTS, length, RIB))
		z -= RIB_STEP
	return boxes

## Whether the rib box at `angle` round the ring stands above the tunnel's floor (the ones under it are left out).
static func _above_floor(angle: float) -> bool:
	return BORE_CENTRE_Y - BORE_RADIUS * cos(angle) > FLOOR_Y

## The floor and the lining, one slab and one lining panel per segment for each bay between two ribs (cut per bay so
## the haze, worked out per vertex, changes along them).
static func _floor_and_lining() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var lowest := 0
	while not _above_floor(TAU * (lowest + 0.5) / RIB_SEGMENTS):
		lowest += 1
	var half := (BORE_RADIUS + RIB.x) * sin(TAU * lowest / RIB_SEGMENTS)
	var length := TAU * BORE_RADIUS / RIB_SEGMENTS * 1.06
	var z := RIB_NEAR
	while z > RIB_FAR:
		var mid := z - RIB_STEP * 0.5
		boxes.append(_box(Vector3(0.0, FLOOR_Y - 0.5, mid), Vector3(half * 2.0, 1.0, RIB_STEP)))
		for i in RIB_SEGMENTS:
			var angle := TAU * (i + 0.5) / RIB_SEGMENTS
			if _above_floor(angle):
				var t := _rib_box(mid, angle, length, Vector2(LINING, RIB_STEP))
				t.origin -= t.basis.y.normalized() * (RIB.x + LINING) * 0.5
				boxes.append(t)
		z -= RIB_STEP
	return boxes

## The catwalks along both walls, with a rail on their open edge.
static func _catwalks() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var wall := bore_half_width(CATWALK.x)
	var length := CATWALK.z - CATWALK.w
	var z := (CATWALK.z + CATWALK.w) * 0.5
	for side in [-1.0, 1.0]:
		var x: float = side * (wall - CATWALK.y * 0.5)
		boxes.append(_box(Vector3(x, CATWALK.x - 0.1, z), Vector3(CATWALK.y, 0.2, length)))
		boxes.append(_box(Vector3(x - side * CATWALK.y * 0.5, CATWALK.x + CATWALK_RAIL, z), Vector3(0.08, 0.08, length)))
	return boxes

## The ladder up to the right catwalk: two rails and a rung every 0.6 m.
static func _ladder() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	# its foot on the lining's inner face
	var foot := Vector3(LADDER.x, BORE_CENTRE_Y - sqrt(pow(BORE_RADIUS + RIB.x * 0.5, 2.0) - LADDER.x * LADDER.x), LADDER.z)
	var top := Vector3(LADDER.y, CATWALK.x, LADDER.z)
	var d := top - foot
	var basis := Basis(Vector3(0.0, 0.0, 1.0), -atan2(d.x, d.y))
	for dz in [-0.25, 0.25]:
		boxes.append(Transform3D(basis * Basis.from_scale(Vector3(0.06, d.length(), 0.06)), (foot + top) * 0.5 + Vector3(0.0, 0.0, dz)))
	var rungs := int(d.length() / 0.6)
	for i in range(1, rungs):
		boxes.append(Transform3D(basis * Basis.from_scale(Vector3(0.05, 0.05, 0.5)), foot + d * float(i) / rungs))
	return boxes

## The rib strips' MultiMesh: a segment on each rib box's inner face in the upper part of the ring, custom data x its
## order far to near (0 the farthest rib), so the tunnel's test lights run from far to near as `level` rises.
func _add_rib_strips() -> void:
	var spots: Array[Transform3D] = []
	var data: Array[Color] = []
	var length := TAU * BORE_RADIUS / RIB_SEGMENTS
	var count := int((RIB_NEAR - RIB_FAR) / RIB_STEP) + 1
	var z := RIB_NEAR
	var n := 0
	while z >= RIB_FAR:
		for i in RIB_SEGMENTS:
			var angle := TAU * (i + 0.5) / RIB_SEGMENTS
			var from_floor := minf(angle, TAU - angle) / PI
			if from_floor < RIB_STRIP_FROM or not _above_floor(angle):
				continue
			var t := _rib_box(z, angle, length, Vector2(1.0, 1.0))
			var inward := t.basis.y.normalized()
			var basis := Basis(t.basis.x.normalized() * length * 0.9, inward * RIB_STRIP.y, Vector3(0.0, 0.0, RIB_STRIP.x))
			spots.append(Transform3D(basis, t.origin + inward * (RIB.x * 0.5 + RIB_STRIP.y * 0.5)))
			data.append(Color(1.0 - float(n) / maxf(count - 1, 1), 0.0, 0.0, 0.0))
		z -= RIB_STEP
		n += 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, spots[i])
		multimesh.set_instance_custom_data(i, data[i])
	rib_strip_material = ShaderMaterial.new()
	rib_strip_material.shader = ARCH_STRIP
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = rib_strip_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## Where moving head i of `count` stands: on the top chord of a truss, pairs either side of the track.
static func moving_head_spot(i: int, count: int) -> Vector3:
	@warning_ignore("integer_division")
	var per_side := count / 2
	var side := -1.0 if i < per_side else 1.0
	var j := i % per_side
	var truss := FRAME_Z.size() - 1 - (j % (FRAME_Z.size() - 1))
	return Vector3(side * (5.0 + 3.0 * (j % 2)), TRUSS_Y + TRUSS.x * 0.5 + TRUSS.y * 0.5 + FIXTURE_ABOVE, FRAME_Z[truss])

## Where follow spot i of `count` stands: on a wall catwalk, the first half on the left.
static func follow_spot(i: int, count: int) -> Vector3:
	@warning_ignore("integer_division")
	var per_side := count / 2
	var side := -1.0 if i < per_side else 1.0
	var j := i % per_side
	var x := side * (bore_half_width(CATWALK.x) - CATWALK.y * 0.5)
	return Vector3(x, CATWALK.x + 0.6, lerpf(CATWALK.z - 6.0, CATWALK.w + 10.0, float(j) / maxf(per_side - 1, 1)))

## Where square bar i of `count` hangs: under a truss's bottom chord, along it, beside the track.
static func truss_bar(i: int, count: int) -> Transform3D:
	var truss := i % FRAME_Z.size()
	@warning_ignore("integer_division")
	var side := -1.0 if (i / FRAME_Z.size()) % 2 == 0 else 1.0
	# a bar is 32 m along its z; laid along the truss (x), 0.4 of it
	var basis := Basis(Vector3(0.0, 1.0, 0.0), PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.4))
	var x := side * 14.0 if count > FRAME_Z.size() else 0.0
	return Transform3D(basis, Vector3(x, TRUSS_Y - TRUSS.x * 0.5 - TRUSS.y, FRAME_Z[truss]))

## How much of the show has been built, 0 to 1: trusses whose share is reached go up, the rest down.
func set_built(built: float) -> void:
	var count := FRAME_Z.size()
	for i in count:
		# FRAME_Z runs near to far; the far trusses go up first
		var share := lerpf(FIRST_FRAME_AT, LAST_FRAME_AT, float(count - 1 - i) / maxf(count - 1, 1))
		_target[i] = 1.0 if built >= share else 0.0

func _process(delta: float) -> void:
	for i in _lift.size():
		if _lift[i] == _target[i]:
			continue
		_lift[i] = move_toward(_lift[i], _target[i], delta / RISE_SECONDS)
		var up := FLY * (1.0 - smoothstep(0.0, 1.0, _lift[i]))
		for b in BOXES_PER_TRUSS:
			var box := _boxes[i * BOXES_PER_TRUSS + b]
			_multimesh.set_instance_transform(i * BOXES_PER_TRUSS + b, Transform3D(box.basis, box.origin + Vector3.UP * up))

## How far above its place the truss at this z is now (0 when in place or when no truss is there): EventDriver hides
## the lights on a truss until it is in place.
func drop_at(z: float) -> float:
	for i in FRAME_Z.size():
		if absf(FRAME_Z[i] - z) < 1.0:
			return FLY * (1.0 - smoothstep(0.0, 1.0, _lift[i]))
	return 0.0

## True while every truss is hoisted.
func standing() -> bool:
	return _lift.count(1.0) == _lift.size()

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)
