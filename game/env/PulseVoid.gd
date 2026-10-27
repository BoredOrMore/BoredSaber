@tool
class_name PulseVoid
extends Node3D
## Pulse Void (doc/assets/pulse_void_dish/spec.md; owner, 2026-10-27: the giant receiving dish, blockout): a signal from
## deep space, the player its receiver. They stand on the feed cabin at the focus of a radio dish DISH_RADIUS * 2
## across, its rim round the horizon at the track's height; the track is the cabin's maintenance beam. Four feed legs
## hold the cabin from the dish. Lights on things that belong there (AGENTS.md "Light", rule 5): the square bars' light
## in rows along the panel seams (seam strips, ArchStrip.gdshader), lit from the rim inward as the show builds and all
## of them on the drop with a beam up from the far rim (EventDriver); floodlights on the legs (diagonal lasers),
## beacons on masts at the rim (waving lasers). Main elements symmetric; the props on the dish are not.
## Dark boxes in one MultiMesh with the scenery's shader, the seam strips in their own. A tool script, so the dish shows
## in the editor too (built, not saved: no owner). Sizes in metres, blockout, untuned.

const ENV_SOLID := preload("res://game/env/EnvSolid.gdshader")
const ARCH_STRIP := preload("res://game/env/ArchStrip.gdshader")
## a dish panel (doc/assets/dish_panel/spec.md): a unit piece, its face's top at +0.5, scaled to each ring's panel
const DISH_PANEL := preload("res://game/models/dish_panel.glb")
## the feed cabin with its horn and the maintenance beam to 61 m ahead (doc/assets/feed_cabin/spec.md): origin at the
## cabin's top centre
const FEED_CABIN := preload("res://game/models/feed_cabin.glb")
## a feed leg (doc/assets/feed_leg/spec.md): a lattice truss from its top end (the origin) along -z to its foot, with
## the floodlights' platforms on it; the four legs are the same piece turned
const FEED_LEG := preload("res://game/models/feed_leg.glb")
## the rim girder's segment (a unit piece scaled to each, its top at +0.5, its inner face toward the dish's centre) and
## a rim mast with its beacon's platform (origin at its foot, the platform's top MAST up) (doc/assets/rim_parts/spec.md)
const RIM_SEGMENT := preload("res://game/models/rim_segment.glb")
const RIM_MAST := preload("res://game/models/rim_mast.glb")
## the crew's kit where it stands, uneven left and right (doc/assets/dish_props/spec.md: a control room ahead left, a
## cherry picker ahead right, a cable tray down the front-right leg), one mesh at the origin
const DISH_PROPS := preload("res://game/models/dish_props.glb")
## the dish: its radius, its vertex's height (the focus, a quarter of the diameter above it, is at the track; so is the
## rim), panel rings from DISH_INNER to the rim, segments round, the panels' thickness; the rim truss's section
const DISH_RADIUS := 250.0
const VERTEX_Y := -125.0
const DISH_INNER := 20.0
const DISH_RINGS := 14
const DISH_SEGMENTS := 48
const PANEL := 0.6
## the panels a little wider than their ring's share, so the fan-shaped gaps between them close; every other segment
## stands proud by PANEL_STAGGER, so the overlaps don't fight
const PANEL_OVERLAP := 1.04
const PANEL_STAGGER := 0.03
## the rim: a vertical ring girder round the dish's edge (owner, 2026-10-27: it leaned with the dish), its thickness
## outward and height, its top RIM_TOP above the dish's edge
const RIM := Vector2(2.0, 4.0)
const RIM_TOP := 0.5
## the feed cabin under the player (size, its top just under the track deck; the model's, where the legs meet it):
## small, so the legs show past its roof's edge (owner, 2026-10-27: 6 x 6 m; at 12 m the roof hid them)
const CABIN := Vector3(6.0, 7.0, 6.0)
const CABIN_TOP := -0.4
## the feed legs: from the cabin's corners down to the dish LEG_REACH out, near the rim as on a real dish (owner,
## 2026-10-27: at 150 m they dropped too steeply to show past the cabin's roof), at 45 degrees either side of ahead and behind;
## their section
const LEG_REACH := 200.0
const LEG := 2.5
## the masts round the rim (as FAST's towers, owner, 2026-10-27): on footings on the ground MAST_R out, past the rim,
## their height to the beacon's platform (rim_parts.py MAST_HEIGHT), the angles they stand at either side of ahead, the
## footings' size
const MAST_R := 258.0
const MAST := 40.0
const MAST_FROM_DEG := 20.0
const MAST_TO_DEG := 70.0
const MAST_FOOTING := Vector3(5.0, 8.0, 5.0)
## the feed legs' footings on the dish (size, level)
const LEG_FOOTING := Vector3(5.0, 3.0, 5.0)
## the floodlights on the legs' platforms (feed_leg.py FLOOD_AT, FLOOD_DECK): at these shares of a leg's length, in the
## order they are filled (two a leg, then the front legs' middle ones), the platforms' top this far over the leg's axis,
## the tilt axis FLOOD_ABOVE over it
const FLOOD_AT: Array[float] = [0.25, 0.75, 0.5]
const FLOOD_DECK := 1.5
const FLOOD_ABOVE := 0.84
## the seam strips: on the dish's face at each panel ring's outer edge, this wide (along the dish) and thick; the drop's
## beam straight up from the calibration laser station's turret at the bridge's end (dish_props.py STATION_AT, HUT,
## TURRET), its width and height
const SEAM := Vector2(1.2, 0.3)
const STATION := Vector3(7.0, 5.2, -254.0)
const DROP_BEAM := Vector2(4.0, 800.0)

var seam_material: ShaderMaterial
var drop_beam: MeshInstance3D

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	boxes.append(_box(Vector3(0.0, dish_y(0.0) - PANEL * 0.5, 0.0), Vector3(DISH_INNER * 2.0, PANEL, DISH_INNER * 2.0)))
	for k in 4:
		boxes.append(_box(_leg_foot(k), LEG_FOOTING))
	var masts: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		for i in 3:
			var a: float = deg_to_rad(lerpf(MAST_FROM_DEG, MAST_TO_DEG, i / 2.0)) * side
			var foot := _mast_foot(a)
			# turned with the rim, so the masts either side are mirror images
			masts.append(Transform3D(Basis(Vector3.UP, -a), foot))
			boxes.append(_box(foot - Vector3(0.0, MAST_FOOTING.y * 0.5, 0.0), MAST_FOOTING))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = boxes.size()
	for i in boxes.size():
		multimesh.set_instance_transform(i, boxes[i])
	var material := ShaderMaterial.new()
	material.shader = ENV_SOLID
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_add_model(DISH_PANEL, _panels(), material)
	var cabin := MeshInstance3D.new()
	cabin.mesh = LaserFixtures._model_mesh(FEED_CABIN)
	cabin.position = Vector3(0.0, CABIN_TOP, 0.0)
	cabin.material_override = material
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cabin)
	var legs: Array[Transform3D] = []
	for k in 4:
		legs.append(Transform3D(Basis.looking_at(_leg_foot(k) - _leg_top(k), Vector3.UP), _leg_top(k)))
	_add_model(FEED_LEG, legs, material)
	_add_model(RIM_SEGMENT, _rim_segments(), material)
	_add_model(RIM_MAST, masts, material)
	_add_model(DISH_PROPS, [Transform3D.IDENTITY], material)
	_add_seams()

## One MultiMesh of a model at these places, with the scenery's material.
func _add_model(model: PackedScene, places: Array[Transform3D], material: Material) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = LaserFixtures._model_mesh(model)
	multimesh.instance_count = places.size()
	for i in places.size():
		multimesh.set_instance_transform(i, places[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

## The dish's height at a distance from its axis.
static func dish_y(r: float) -> float:
	return VERTEX_Y + r * r / (4.0 * -VERTEX_Y)

## The point on the dish at distance r and angle a (0 straight ahead, toward +x positive).
static func dish_point(r: float, a: float) -> Vector3:
	return Vector3(sin(a) * r, dish_y(r), -cos(a) * r)

## Where the mast at angle a stands: on the ground past the rim.
static func _mast_foot(a: float) -> Vector3:
	return Vector3(sin(a) * MAST_R, 0.0, -cos(a) * MAST_R)


## A panel (or seam strip) of the dish between radii r0 and r1 round angle a, `span` radians wide, `thick` deep, its
## top face on the dish.
static func _panel(r0: float, r1: float, a: float, span: float, thick: float) -> Transform3D:
	var p0 := dish_point(r0, a)
	var p1 := dish_point(r1, a)
	var down := p1 - p0
	var across := Vector3(cos(a), 0.0, sin(a)) * span * (r0 + r1) * 0.5
	var normal := across.cross(down).normalized()
	if normal.y < 0.0:
		normal = -normal
	# right-handed (z up the slope), so the panel model isn't mirrored and its faces aren't culled
	return Transform3D(Basis(across, normal * thick, -down), (p0 + p1) * 0.5 - normal * thick * 0.5)

## The dish's panels' places (the model's, scaled), edge to edge.
static func _panels() -> Array[Transform3D]:
	var places: Array[Transform3D] = []
	var span := TAU / DISH_SEGMENTS
	for ring in DISH_RINGS:
		var r0 := lerpf(DISH_INNER, DISH_RADIUS, float(ring) / DISH_RINGS)
		var r1 := lerpf(DISH_INNER, DISH_RADIUS, float(ring + 1) / DISH_RINGS)
		for s in DISH_SEGMENTS:
			var t := _panel(r0, r1, span * (s + 0.5), span * PANEL_OVERLAP, PANEL)
			t.origin += t.basis.y.normalized() * PANEL_STAGGER * (s % 2)
			places.append(t)
	return places

## The rim girder's segments' places (the model's, scaled), edge to edge round the dish.
static func _rim_segments() -> Array[Transform3D]:
	var places: Array[Transform3D] = []
	var span := TAU / DISH_SEGMENTS
	for s in DISH_SEGMENTS:
		var a := span * (s + 0.5)
		var across := Vector3(cos(a), 0.0, sin(a)) * span * (DISH_RADIUS + RIM.x * 0.5)
		var inward := Vector3(-sin(a), 0.0, cos(a))
		var centre := Vector3(sin(a), 0.0, -cos(a)) * (DISH_RADIUS + RIM.x * 0.5) + Vector3(0.0, RIM_TOP - RIM.y * 0.5, 0.0)
		places.append(Transform3D(Basis(across, Vector3.UP * RIM.y, inward * RIM.x), centre))
	return places

## Feed leg k's ends: the cabin's corner and its foot on the dish (k 0 ahead right, then round).
static func _leg_top(k: int) -> Vector3:
	var a := deg_to_rad(45.0 + 90.0 * k)
	return Vector3(sin(a) * CABIN.x * 0.5, CABIN_TOP - CABIN.y, -cos(a) * CABIN.z * 0.5)

static func _leg_foot(k: int) -> Vector3:
	return dish_point(LEG_REACH, deg_to_rad(45.0 + 90.0 * k))

## The seam strips' MultiMesh: a strip on each panel's outer edge, custom data x its order from the rim (0 the rim: lit
## first as the show builds) and y 1 (all lit on the drop); and the drop's beam, in the same light, shown only then
## (EventDriver: unlit it would be a dark line across the pulsar).
func _add_seams() -> void:
	var spots: Array[Transform3D] = []
	var data: Array[Color] = []
	var span := TAU / DISH_SEGMENTS
	for ring in DISH_RINGS:
		var r := lerpf(DISH_INNER, DISH_RADIUS, float(ring + 1) / DISH_RINGS)
		for s in DISH_SEGMENTS:
			var t := _panel(r - SEAM.x, r, span * (s + 0.5), span * 0.96, SEAM.y)
			t.origin += t.basis.y.normalized() * SEAM.y
			spots.append(t)
			data.append(Color(1.0 - float(ring + 1) / DISH_RINGS, 1.0, 0.0, 0.0))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = spots.size()
	for i in spots.size():
		multimesh.set_instance_transform(i, spots[i])
		multimesh.set_instance_custom_data(i, data[i])
	seam_material = ShaderMaterial.new()
	seam_material.shader = ARCH_STRIP
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = seam_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	drop_beam = MeshInstance3D.new()
	drop_beam.mesh = BoxMesh.new()
	drop_beam.transform = _box(STATION + Vector3(0.0, DROP_BEAM.y * 0.5, 0.0), Vector3(DROP_BEAM.x, DROP_BEAM.y, DROP_BEAM.x))
	drop_beam.material_override = seam_material
	drop_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop_beam.visible = false
	add_child(drop_beam)

## Where floodlight i of `count` stands: on a feed leg's platform, the legs taken in turn; what doesn't share out evenly
## goes to the front legs' middle platforms, left and right alike (up to FLOOD_AT.size() a leg).
static func leg_floodlight(i: int, count: int) -> Vector3:
	@warning_ignore("integer_division")
	var even := count / 4 * 4
	var k := i % 4
	@warning_ignore("integer_division")
	var slot := i / 4
	if i >= even:
		# leg 0 is ahead right, 3 ahead left
		k = 0 if (i - even) % 2 == 0 else 3
	var t: float = FLOOD_AT[slot]
	return _leg_top(k).lerp(_leg_foot(k), t) + Vector3(0.0, FLOOD_DECK + FLOOD_ABOVE, 0.0)

## Where beacon i of `count` stands: on top of a rim mast, the first half on the left.
static func rim_beacon(i: int, count: int) -> Vector3:
	@warning_ignore("integer_division")
	var half := maxi(count / 2, 1)
	var side := -1.0 if i < half else 1.0
	var a := deg_to_rad(lerpf(MAST_FROM_DEG, MAST_TO_DEG, float((i % half) % 3) / 2.0)) * side
	return _mast_foot(a) + Vector3(0.0, MAST + 0.6, 0.0)

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)
