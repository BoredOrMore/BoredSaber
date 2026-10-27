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
## the dish: its radius, its vertex's height (the focus, a quarter of the diameter above it, is at the track; so is the
## rim), panel rings from DISH_INNER to the rim, segments round, the panels' thickness; the rim truss's section
const DISH_RADIUS := 250.0
const VERTEX_Y := -125.0
const DISH_INNER := 20.0
const DISH_RINGS := 14
const DISH_SEGMENTS := 48
const PANEL := 0.6
const RIM := 3.0
## the feed cabin under the player (size, its top just under the track deck; the model's, where the legs meet it):
## small, so the legs show past its roof's edge (owner, 2026-10-27: 6 x 6 m; at 12 m the roof hid them)
const CABIN := Vector3(6.0, 7.0, 6.0)
const CABIN_TOP := -0.4
## the feed legs: from the cabin's corners down to the dish LEG_REACH out, near the rim as on a real dish (owner,
## 2026-10-27: at 150 m they dropped too steeply to show past the cabin's roof), at 45 degrees either side of ahead and behind;
## their section (the cable trays run beside it)
const LEG_REACH := 200.0
const LEG := 2.5
## the masts on the rim for the beacons: their height, section, and the angles they stand at either side of ahead
const MAST := Vector2(40.0, 2.0)
const MAST_FROM_DEG := 20.0
const MAST_TO_DEG := 70.0
## the floodlights on the legs' platforms (feed_leg.py FLOOD_AT, FLOOD_DECK): at these shares of a leg's length, in the
## order they are filled (two a leg, then the front legs' middle ones), the platforms' top this far over the leg's axis,
## the tilt axis FLOOD_ABOVE over it
const FLOOD_AT: Array[float] = [0.25, 0.75, 0.5]
const FLOOD_DECK := 1.5
const FLOOD_ABOVE := 0.84
## the seam strips: on the dish's face at each panel ring's outer edge, this wide (along the dish) and thick; the drop's
## beam from the far rim straight up, its width and height
const SEAM := Vector2(1.2, 0.3)
const DROP_BEAM := Vector2(4.0, 800.0)
## props on the dish's surface, uneven: a control room (left of ahead), a cherry picker (right): [x, z, size]
const CONTROL_ROOM := [Vector3(-45.0, 0.0, -70.0), Vector3(14.0, 6.0, 10.0)]
const CHERRY_PICKER := Vector3(70.0, 0.0, -95.0)
const CABLE_TRAY := 0.8

var seam_material: ShaderMaterial
var drop_beam: MeshInstance3D

func _ready() -> void:
	var boxes: Array[Transform3D] = []
	boxes.append_array(_dish())
	for side in [-1.0, 1.0]:
		for i in 3:
			var a: float = deg_to_rad(lerpf(MAST_FROM_DEG, MAST_TO_DEG, i / 2.0)) * side
			var foot := _rim(a)
			boxes.append(_box(foot + Vector3(0.0, MAST.x * 0.5, 0.0), Vector3(MAST.y, MAST.x, MAST.y)))
	boxes.append_array(_props())
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
	var panels := MultiMesh.new()
	panels.transform_format = MultiMesh.TRANSFORM_3D
	panels.mesh = LaserFixtures._model_mesh(DISH_PANEL)
	var places := _panels()
	panels.instance_count = places.size()
	for i in places.size():
		panels.set_instance_transform(i, places[i])
	var dish := MultiMeshInstance3D.new()
	dish.multimesh = panels
	dish.material_override = material
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dish)
	var cabin := MeshInstance3D.new()
	cabin.mesh = LaserFixtures._model_mesh(FEED_CABIN)
	cabin.position = Vector3(0.0, CABIN_TOP, 0.0)
	cabin.material_override = material
	cabin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cabin)
	var legs: Array[Transform3D] = []
	for k in 4:
		legs.append(Transform3D(Basis.looking_at(_leg_foot(k) - _leg_top(k), Vector3.UP), _leg_top(k)))
	var leg_mesh := MultiMesh.new()
	leg_mesh.transform_format = MultiMesh.TRANSFORM_3D
	leg_mesh.mesh = LaserFixtures._model_mesh(FEED_LEG)
	leg_mesh.instance_count = legs.size()
	for k in legs.size():
		leg_mesh.set_instance_transform(k, legs[k])
	var leg_instance := MultiMeshInstance3D.new()
	leg_instance.multimesh = leg_mesh
	leg_instance.material_override = material
	leg_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(leg_instance)
	_add_seams()

## The dish's height at a distance from its axis.
static func dish_y(r: float) -> float:
	return VERTEX_Y + r * r / (4.0 * -VERTEX_Y)

## The point on the dish at distance r and angle a (0 straight ahead, toward +x positive).
static func dish_point(r: float, a: float) -> Vector3:
	return Vector3(sin(a) * r, dish_y(r), -cos(a) * r)

static func _rim(a: float) -> Vector3:
	return dish_point(DISH_RADIUS, a)

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
			places.append(_panel(r0, r1, span * (s + 0.5), span, PANEL))
	return places

## The dish's hub plate in the middle and the rim truss.
static func _dish() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var span := TAU / DISH_SEGMENTS
	boxes.append(_box(Vector3(0.0, dish_y(0.0) - PANEL * 0.5, 0.0), Vector3(DISH_INNER * 2.0, PANEL, DISH_INNER * 2.0)))
	for s in DISH_SEGMENTS:
		var a := span * (s + 0.5)
		var t := _panel(DISH_RADIUS, DISH_RADIUS + RIM, a, span * 1.02, RIM)
		boxes.append(t)
	return boxes

## Feed leg k's ends: the cabin's corner and its foot on the dish (k 0 ahead right, then round).
static func _leg_top(k: int) -> Vector3:
	var a := deg_to_rad(45.0 + 90.0 * k)
	return Vector3(sin(a) * CABIN.x * 0.5, CABIN_TOP - CABIN.y, -cos(a) * CABIN.z * 0.5)

static func _leg_foot(k: int) -> Vector3:
	return dish_point(LEG_REACH, deg_to_rad(45.0 + 90.0 * k))

## A square bar from a to b.
static func _bar(a: Vector3, b: Vector3, thick: float) -> Transform3D:
	var d := b - a
	var x := d.cross(Vector3.UP).normalized()
	var y := x.cross(d).normalized()
	return Transform3D(Basis(x * thick, y * thick, d), (a + b) * 0.5)

## The props on the dish's surface: the control room, the cherry picker (base, boom, bucket), the cable trays down the
## front-right leg.
static func _props() -> Array[Transform3D]:
	var boxes: Array[Transform3D] = []
	var at: Vector3 = CONTROL_ROOM[0]
	var size: Vector3 = CONTROL_ROOM[1]
	boxes.append(_box(Vector3(at.x, dish_y(Vector2(at.x, at.z).length()) + size.y * 0.5, at.z), size))
	var base := Vector3(CHERRY_PICKER.x, dish_y(Vector2(CHERRY_PICKER.x, CHERRY_PICKER.z).length()), CHERRY_PICKER.z)
	boxes.append(_box(base + Vector3(0.0, 1.0, 0.0), Vector3(3.0, 2.0, 6.0)))
	var tip := base + Vector3(-6.0, 18.0, 4.0)
	boxes.append(_bar(base + Vector3(0.0, 2.0, 0.0), tip, 0.6))
	boxes.append(_box(tip + Vector3(0.0, 0.6, 0.0), Vector3(2.0, 1.2, 1.5)))
	var side := Vector3(1.0, 0.0, 1.0).normalized() * (LEG * 0.5 + CABLE_TRAY)
	boxes.append(_bar(_leg_top(0) + side, _leg_foot(0) + side, CABLE_TRAY))
	return boxes

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
	drop_beam.transform = _box(_rim(0.0) + Vector3(0.0, DROP_BEAM.y * 0.5, 0.0), Vector3(DROP_BEAM.x, DROP_BEAM.y, DROP_BEAM.x))
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
	return _rim(a) + Vector3(0.0, MAST.x + 0.6, 0.0)

## A unit box scaled to size and placed at centre.
static func _box(centre: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), centre)
