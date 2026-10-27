class_name LightRig
extends RefCounted
## Where each stage hangs the map's five light groups (EventDriver): the lasers' fixtures and the square bars placed on
## the stage's own structure, the sky's distance, the haze's key light and the beams' width per stage. Moved out of
## event_driver.gd as is; the light show itself (colours, flashes, the build-up) stays there.

var _d: EventDriver

func _init(driver: EventDriver) -> void:
	_d = driver

## Each environment hangs the same five light groups (so a map's light show still drives them) on its own rig, so
## the stages don't all look alike: Classic keeps Beat Saber's layout; Neon Grid hangs them on its arches' building site
## (NeonGridRig: floodlights at the footings, survey beacons, the crane's work lights, strips along the arches); Night City sweeps its waving lasers like searchlights from far beside the track and crosses its
## diagonal beams from rooftop height; Pulse Void stands its floodlights on the dish's feed legs and its beacons on masts
## at the rim (PulseVoid). Every beam starts at its fixture and turns around it (game/AGENTS.md). Positions in metres, untuned.
## Each side's fan: from its stage, leaning RIG_FAN_MIN_DEG..RIG_FAN_MAX_DEG away from the track (never toward the sun).
const RIG_FAN_MIN_DEG := 5.0
const RIG_FAN_MAX_DEG := 70.0

## the sky sphere drawn this many times as far in Neon Grid, behind the arches (950 m, inside the camera's 1024 m far plane)
const NEON_SKY_SCALE := 9.5
const RAIL_BASIS := Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 0.3))
## Night City's square bars trim the buildings' roof edges facing the track, as architectural accent light: this far
## below the roof and off the inner face
const ROOF_TRIM_DROP := 0.15
const ROOF_TRIM_OFFSET := 0.2
## Metal Factory: the energy strips' centres along each rail (each 9.6 m long with RAIL_BASIS), just above the rail's
## top so they don't flicker into it
const FACTORY_STRIP_Z: Array[float] = [-8.0, -22.0, -36.0]
const FACTORY_STRIP_LIFT := 0.01

## each laser's and the square bars' Classic transform, put back before another rig is hung
var classic_places := {}

## Night City's canyon (NightCityRig, blockout): the wall side's lights on the tower wall's face, the open side's on
## the low roofs. The diagonal lasers cross over the canyon from both; the waving lasers are searchlights on the wall's
## face at several heights and on the low roofs; the horizontal square bars alternate between trims on the low roofs'
## inner edges and billboards on the wall's face; the vertical ones are left out. Heights in metres, untuned.

const CANYON_SKY_SCALE := 9.5

const CANYON_BILLBOARD_Y := [22.0, 30.0, 46.0, 58.0]

func _hang_canyon(waving: Array[Node3D]) -> void:
	var w := NightCityRig.WALL_SIDE
	var o := -w
	var towers := NightCityRig.TOWERS
	var roofs := NightCityRig.LOW_ROOFS
	var pairs := _d.diagonal_lasers.size() >> 1
	for i in _d.diagonal_lasers.size():
		var j := i % pairs
		if i < pairs:
			# on the maintenance platforms out of the tower wall (NightCityRig.wall_diagonal_spot)
			aim(_d.diagonal_lasers[i], NightCityRig.wall_diagonal_spot(j, pairs), Vector3(o * 0.6, 1.0, -0.1))
		else:
			var r: Vector4 = roofs[j % roofs.size()]
			aim(_d.diagonal_lasers[i], Vector3(o * r.x, r.w, (r.y + r.z) * 0.5), Vector3(w * 0.4, 1.0, 0.05))
	@warning_ignore("integer_division")
	var half := waving.size() / 2
	for i in waving.size():
		var j := i % half
		if (i < half) == (w < 0.0):
			waving[i].global_position = NightCityRig.wall_searchlight_spot(j)
		else:
			var r: Vector4 = roofs[j % roofs.size()]
			waving[i].global_position = Vector3(o * (r.x + NightCityRig.LOW_ROOF_DEPTH * 0.6), r.w + 0.3, (r.y + r.z) * 0.5)
	var k := 0
	for bar in square_bars():
		if bar.get_parent() != _d.square_lasers_holder:
			bar.visible = false
			continue
		var j := k >> 1
		if k % 2 == 0:
			var r: Vector4 = roofs[j % roofs.size()]
			bar.global_transform = Transform3D(RAIL_BASIS, Vector3(o * (r.x - ROOF_TRIM_OFFSET), r.w - ROOF_TRIM_DROP, (r.y + r.z) * 0.5))
		else:
			var t: Vector4 = towers[j % towers.size()]
			bar.global_transform = Transform3D(RAIL_BASIS, Vector3(w * (t.x - ROOF_TRIM_OFFSET),
				CANYON_BILLBOARD_Y[j % CANYON_BILLBOARD_Y.size()], lerpf(t.y, t.z, 0.25 + 0.15 * j)))
		k += 1


## Each stage's key light for the fog's in-scattering (fog_light.gdshaderinc): the way to it from the player (x, y, z)
## and how strongly the haze brightens toward it (w). Classic: the stage ahead and above; Neon Grid: the sun on the
## horizon; Night City: the glow at the canyon's far end, a little toward the open side; Pulse Void: the tunnel's
## bright end; Metal Factory: the gear pit ahead, gently. Halved with the fog (owner, 2026-10-26). Untuned.
const FOG_KEYS := {
	"classic": Vector4(0.0, 0.3, -1.0, 0.06),
	"neon_grid": Vector4(0.0, 0.12, -1.0, 0.1),
	"night_city": Vector4(0.2, 0.1, -1.0, 0.075),
	"pulse_void": Vector4(0.0, 0.0, -1.0, 0.1),
	"metal_factory": Vector4(0.0, 0.05, -1.0, 0.04),
}

## Pulse Void's beams: their width and brightness, parts of the beams' own (untuned)
const VOID_BEAM_WIDTH := 0.5
const VOID_BEAM_BRIGHTNESS := 0.55
## each beam material's own width and brightness, put back on the other stages
var _beam_rest := {}


## The waving lasers' fixtures, left side first.
func waving_lasers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for holder: Node3D in [_d.left_waving_lasers_holder, _d.right_waving_lasers_holder]:
		for child in holder.get_children():
			if child is Node3D and not child is AnimationPlayer:
				out.append(child as Node3D)
	return out

## The square bars: the horizontal ones (children of the holder) first, then the vertical ones of each side.
func square_bars() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node in _d.square_lasers_holder.find_children("*", "MeshInstance3D", true, false):
		out.append(node as Node3D)
	return out

## Aims a laser fixture from a point along a direction, keeping its beam length (local z scale).
static func aim(laser: Node3D, from: Vector3, direction: Vector3) -> void:
	var length := laser.global_transform.basis.z.length()
	var aim := Basis.looking_at(direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.FORWARD)
	laser.global_transform = Transform3D(Basis(aim.x, aim.y, aim.z * length), from)


## Hangs the lights on the environment's rig (see RIG_FAN_MIN_DEG).
func apply(id: String) -> void:
	for node: Node3D in classic_places:
		if node == _d.square_lasers_holder:
			node.transform = classic_places[node]
		else:
			node.global_transform = classic_places[node]
			if node is MeshInstance3D:
				# a square bar a rig left out
				node.visible = true
	var waving := waving_lasers()
	@warning_ignore("integer_division")
	var half := waving.size() / 2
	# Metal Factory has no beams: the diagonal and waving lasers' light glows in its wall vents. The beam meshes are hidden
	# rather than their holders, which the light events show and hide.
	for laser: Node3D in _d.diagonal_lasers + waving:
		for beam in laser.get_children():
			if beam is MeshInstance3D:
				(beam as MeshInstance3D).visible = id != "metal_factory"
	# the sky sphere (100 m) would hide the canyon's far city and landmark tower (to 800 m out) and Neon Grid's arches:
	# there it is drawn CANYON_SKY_SCALE or NEON_SKY_SCALE times as far; elsewhere at its size, where it hides the beams'
	# far ends
	var sky_scale := 1.0
	if id == "night_city" and not Settings.classic_night_city:
		sky_scale = CANYON_SKY_SCALE
	elif id == "neon_grid" or id == "classic" or id == "pulse_void":
		# Classic's tunnel runs 600 m ahead (ClassicRig): the sky behind its far end
		sky_scale = NEON_SKY_SCALE
	(_d.get_node(^"Level/Sphere") as Node3D).scale = Vector3.ONE * sky_scale
	# the haze lit from the stage's key light (fog_light.gdshaderinc)
	var key: Vector4 = FOG_KEYS.get(id, Vector4(0.0, 0.0, -1.0, 0.0))
	var key_dir := Vector3(key.x, key.y, key.z).normalized()
	RenderingServer.global_shader_parameter_set(&"fog_key", Vector4(key_dir.x, key_dir.y, key_dir.z, key.w))
	# Pulse Void's beams narrower and dimmer, so the dish's lights lead and the notes stay brightest (Light rule 1; owner,
	# 2026-10-25: too bright); the rest keep the beams' own width and brightness
	for material: ShaderMaterial in [_d.diagonal_lasers_material, _d.left_waving_lasers_material, _d.right_waving_lasers_material]:
		if not _beam_rest.has(material):
			# a value the material doesn't set is the shader's own default
			var rest_of := func(param: StringName) -> float:
				var value: Variant = material.get_shader_parameter(param)
				if value == null:
					value = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), param)
				# the dummy renderer (headless runs) knows no defaults: NeonRibbon.gdshader's, kept in step by hand
				return value if value != null else {&"width": 0.4, &"brightness": 3.5}[param]
			_beam_rest[material] = [rest_of.call(&"width"), rest_of.call(&"brightness")]
		var rest: Array = _beam_rest[material]
		var void_stage := id == "pulse_void"
		material.set_shader_parameter(&"width", rest[0] * VOID_BEAM_WIDTH if void_stage else rest[0])
		material.set_shader_parameter(&"brightness", rest[1] * VOID_BEAM_BRIGHTNESS if void_stage else rest[1])
	# Classic's waving lasers leave from follow spots, every other laser from a moving head (LaserFixtures)
	for i in waving.size():
		_d._fixtures.set_kind(_d.diagonal_lasers.size() + i, LaserFixtures.FOLLOW_SPOT if id == "classic" else LaserFixtures.MOVING_HEAD)
	match id:
		"classic":
			# the giant test tunnel (ClassicRig): moving heads standing on the hanging scaffolds' decks, follow spots on the wall
			# catwalks, the square bars under the scaffolds' decks (the vertical ones left out); all keep their Classic aim
			for i in _d.diagonal_lasers.size():
				_d.diagonal_lasers[i].global_position = ClassicRig.moving_head_spot(i, _d.diagonal_lasers.size())
			for i in waving.size():
				waving[i].global_position = ClassicRig.follow_spot(i, waving.size())
			var bars: Array[Node3D] = []
			for bar in square_bars():
				if bar.get_parent() != _d.square_lasers_holder:
					bar.visible = false
				else:
					bars.append(bar)
			for i in bars.size():
				bars[i].global_transform = ClassicRig.scaffold_bar(i, bars.size())
		"neon_grid":
			# the diagonal lasers: floodlights at B's footing (left) and C's (right), fanning up and away from the sun
			var per_side := _d.diagonal_lasers.size() >> 1
			var bases := NeonGridRig.floodlight_bases()
			for i in _d.diagonal_lasers.size():
				var side := -1.0 if i < per_side else 1.0
				var a := deg_to_rad(lerpf(RIG_FAN_MIN_DEG, RIG_FAN_MAX_DEG, float(i % per_side) / maxi(per_side - 1, 1)))
				aim(_d.diagonal_lasers[i], bases[0 if side < 0.0 else 1] + Vector3(0.0, 1.0, 0.0), Vector3(side * sin(a), cos(a), -0.15))
			# the waving lasers: survey beacons on the masts (left), the crane's work lights (right)
			var crane := NeonGridRig.crane_lights(waving.size() - half)
			for i in waving.size():
				if i < half:
					var m := NeonGridRig.SURVEY_MASTS[i % NeonGridRig.SURVEY_MASTS.size()]
					waving[i].global_position = Vector3(m.x, m.z, m.y)
				else:
					waving[i].global_position = crane[i - half]
			# the square bars' light goes to the arches' strips (NeonGridRig, ArchStrip.gdshader); the bars themselves are
			# left out
			for bar in square_bars():
				bar.visible = false
		"night_city" when not Settings.classic_night_city:
			_hang_canyon(waving)
		"night_city":
			# diagonal lasers cross from the roofs' inner edges, one every 6 m along each row of buildings
			for i in _d.diagonal_lasers.size():
				var pairs := _d.diagonal_lasers.size() >> 1
				var side := -1.0 if i < pairs else 1.0
				var z := -18.0 - 8.0 * (i % pairs)
				var roof := maxf(NightCityRig.roof_at(side, z), 1.0)
				aim(_d.diagonal_lasers[i], Vector3(side * NightCityRig.INNER_FACE_X, roof, z), Vector3(-side * 0.35, 1.0, 0.1))
			# searchlights stand in the middle of each roof
			for i in waving.size():
				var side := -1.0 if i < half else 1.0
				var b: Vector3 = NightCityRig.buildings(side)[i % half]
				waving[i].global_position = Vector3(side * (NightCityRig.INNER_FACE_X + NightCityRig.DEPTH_X * 0.5), b.z + 0.3, b.x)
			# roof trim: the horizontal bars run along the top of the buildings' inner faces; the vertical ones are left out
			var sign_i := 0
			for bar in square_bars():
				if bar.get_parent() != _d.square_lasers_holder:
					bar.visible = false
					continue
				var side := -1.0 if sign_i % 2 == 0 else 1.0
				var b: Vector3 = NightCityRig.buildings(side)[(sign_i >> 1) % NightCityRig.LEFT.size()]
				bar.global_transform = Transform3D(RAIL_BASIS,
					Vector3(side * (NightCityRig.INNER_FACE_X - ROOF_TRIM_OFFSET), b.z - ROOF_TRIM_DROP, b.x))
				sign_i += 1
		"pulse_void":
			# the giant receiving dish (PulseVoid): floodlights on the feed legs, beacons on the rim masts; the dish's seam rows
			# carry the square bars' light (_update_strips), so the bars are left out
			for i in _d.diagonal_lasers.size():
				_d.diagonal_lasers[i].global_position = PulseVoid.leg_floodlight(i, _d.diagonal_lasers.size())
			for i in waving.size():
				waving[i].global_position = PulseVoid.rim_beacon(i, waving.size())
			for bar in square_bars():
				bar.visible = false
		"metal_factory":
			# no lasers here: their light glows in the wall vents (MetalFactoryRig.set_vent_colors, _process; the beams are
			# hidden above, the heads in show_scenery_for_mixed_reality and set_background). The horizontal square bars become energy strips flush on the rails' tops; the vertical ones are left out
			var strip := 0
			var per_side := FACTORY_STRIP_Z.size()
			for bar in square_bars():
				if bar.get_parent() != _d.square_lasers_holder:
					bar.visible = false
					continue
				var side := -1.0 if strip < per_side else 1.0
				bar.global_transform = Transform3D(RAIL_BASIS, Vector3(side * MetalFactoryRig.RAIL_X,
						MetalFactoryRig.RAIL_TOP + FACTORY_STRIP_LIFT, FACTORY_STRIP_Z[strip % per_side]))
				strip += 1

