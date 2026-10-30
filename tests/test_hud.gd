extends Node
# Headless checks that the HUD's panels are placed from the player's eye (Hud._panel): the same angle and distance
# for any eye, clear of the lanes on the Wide modifiers, grown so the lines keep their size in view; and that a fail's
# fade (Hud.fade_out, HealthRails.fade_out) fades the panels and the energy strips, hides them and leaves them whole
# for the next song; and that on 90/360 maps the HUD is one far cluster over the lane above every note (Hud.far_cluster)
# that turns with the track about the player (Hud.turn).
# Run: godot --headless --path . res://tests/test_hud.tscn

var failures := 0

func check(ok: bool, what: String) -> void:
	if ok:
		print("PASS: ", what)
	else:
		failures += 1
		printerr("FAIL: ", what)

## The panel's yaw and pitch from the eye, in degrees, and its distance.
func seen(eye: Vector3, panel: Transform3D) -> Vector3:
	var to := panel.origin - eye
	return Vector3(rad_to_deg(atan2(to.x, -to.z)), rad_to_deg(asin(to.y / to.length())), to.length())

func _ready() -> void:
	var width: int = Settings.width
	Settings.width = 100
	var near := func(a: float, b: float) -> bool: return absf(a - b) < 0.01

	for eye: Vector3 in [Hud.HUD_EYE, Vector3(0.0, 1.85, 1.0), Vector3(0.1, 1.4, 1.2)]:
		var right := seen(eye, Hud._panel(eye, 1.0))
		var left := seen(eye, Hud._panel(eye, -1.0))
		check(near.call(right.x, Hud.HUD_YAW) and near.call(left.x, -Hud.HUD_YAW),
				"eye at %s: the panels sit %.0f degrees either side (got %.2f, %.2f)" % [eye, Hud.HUD_YAW, left.x, right.x])
		check(near.call(right.y, Hud.HUD_PITCH) and near.call(right.z, Hud.HUD_DISTANCE),
				"eye at %s: %.1f degrees below level, %.2f m away (got %.2f, %.2f)" % [eye, -Hud.HUD_PITCH, Hud.HUD_DISTANCE, right.y, right.z])
		var basis := Hud._panel(eye, 1.0).basis
		check(near.call(basis.get_scale().x, Hud.HUD_DISTANCE / Hud.HUD_LAID_OUT_DISTANCE),
				"eye at %s: the panel grows by its distance over the laid-out one" % eye)
		check(basis.z.normalized().dot((eye - Hud._panel(eye, 1.0).origin).normalized()) > 0.999, "eye at %s: the panel faces the eye" % eye)

	# Wide 200%: the lanes reach out further; the panels turn out to stay clear of them
	Settings.width = 200
	var clear := 1.5 * Settings.LANE_DISTANCE_X + Hud.HUD_LANE_MARGIN
	var wide := Hud._panel(Hud.HUD_EYE, 1.0)
	check(wide.origin.x >= clear - 0.001 and seen(Hud.HUD_EYE, wide).x > Hud.HUD_YAW,
			"Wide 200%%: the panel turns out past the outer lane (x %.2f, needs %.2f)" % [wide.origin.x, clear])
	check(near.call(seen(Hud.HUD_EYE, wide).z, Hud.HUD_DISTANCE), "Wide 200%: still HUD_DISTANCE from the eye")
	Settings.width = width

	check(Hud.grade_rises("A", "S") and Hud.grade_rises("B", "SS") and not Hud.grade_rises("S", "A")
			and not Hud.grade_rises("", "SS") and not Hud.grade_rises("A", "A"),
			"the live grade pops when it goes up, not when it stays or drops")
	check(Hud.shown_grade(1.0, 0) == "F" and Hud.shown_grade(1.0, 4) == "F" and Hud.shown_grade(1.0, 5) == "D"
			and Hud.shown_grade(1.0, 30) == "SS" and Hud.shown_grade(0.7, 100) == "A" and Hud.shown_grade(0.7, 10) == "C",
			"the live grade starts at F and climbs a step every 5 notes, never above the accuracy's grade")
	await check_fade_out()
	check_turn()
	check_raised()
	print("%d failure(s)" % failures)
	get_tree().quit(1 if failures > 0 else 0)

## Builds a HUD from stand-ins for the game's score, combo and accuracy nodes and fades it out.
func check_fade_out() -> void:
	var point_label := MeshInstance3D.new()
	point_label.mesh = TextMesh.new()
	var text := StandardMaterial3D.new()
	point_label.material_override = text
	var combo := ComboHud.new()
	combo.mesh = TextMesh.new()
	combo.material_override = text
	var percent := preload("res://game/hud/PercentIndicator.tscn").instantiate() as PercentIndicator
	for node: Node in [point_label, combo, percent]:
		add_child(node)
	var hud := Hud.new(point_label, combo, percent)
	add_child(hud)
	var score := point_label.material_override as BaseMaterial3D
	var ring := combo.ring.material_override as ShaderMaterial
	# as the Playing state shows it
	point_label.visible = false
	point_label.visible = true
	check(score != text, "the score has its own material, so a fade leaves the shared text material alone")
	hud.fade_out(0.4)
	await get_tree().create_timer(0.2).timeout
	check(score.albedo_color.a > 0.05 and score.albedo_color.a < 0.95 and float(ring.get_shader_parameter(&"fade")) < 0.95
			and score.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"halfway through the fade the score and the ring are see-through (score %.2f)" % score.albedo_color.a)
	await get_tree().create_timer(0.4).timeout
	check(not point_label.visible and not combo.visible and not hud._left.visible and not hud._right.visible,
			"after the fade both panels are hidden")
	check(score.albedo_color.a == 1.0 and float(ring.get_shader_parameter(&"fade")) == 1.0
			and score.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and text.albedo_color.a == 1.0,
			"after the fade the materials are whole again for the next song")
	hud.queue_free()
	for node: Node in [point_label, combo, percent]:
		node.queue_free()

	var rails := HealthRails.new()
	add_child(rails)
	var bar := rails._bar_material
	rails.fade_out(0.4)
	await get_tree().create_timer(0.2).timeout
	check(float(bar.get_shader_parameter(&"fade")) > 0.05 and float(bar.get_shader_parameter(&"fade")) < 0.95
			and rails._icon.modulate.a < 0.95, "halfway through the fade the energy strips and bolt are see-through")
	await get_tree().create_timer(0.4).timeout
	check(not rails.visible and float(bar.get_shader_parameter(&"fade")) == 1.0 and rails._icon.modulate.a == 1.0,
			"after the fade the energy strips are hidden and whole again for the next song")
	rails.queue_free()

## Builds a HUD from stand-ins and turns it with the track: each part turned about the player's standing point, the
## panels still facing the eye turned with them, and back where it was when the track points ahead again.
func check_turn() -> void:
	var point_label := MeshInstance3D.new()
	point_label.mesh = TextMesh.new()
	point_label.material_override = StandardMaterial3D.new()
	var combo := ComboHud.new()
	combo.mesh = TextMesh.new()
	combo.material_override = StandardMaterial3D.new()
	var percent := preload("res://game/hud/PercentIndicator.tscn").instantiate() as PercentIndicator
	for node: Node in [point_label, combo, percent]:
		add_child(node)
	var hud := Hud.new(point_label, combo, percent)
	add_child(hud)
	var near := func(a: Vector3, b: Vector3) -> bool: return a.distance_to(b) < 0.001
	var pivot := Vector3(0.0, Hud.HUD_EYE.y, Constants.PLAYER_Z)
	var left := hud._left.global_transform
	var score := point_label.global_position
	hud.turn(PI * 0.5)
	var turned := pivot + Basis(Vector3.UP, -PI * 0.5) * (left.origin - pivot)
	check(near.call(hud._left.global_position, turned), "a 90 degree turn takes the left panel round the player: %s, " %
		hud._left.global_position + "expected %s" % turned)
	check(near.call(point_label.global_position, pivot + Basis(Vector3.UP, -PI * 0.5) * (score - pivot)),
		"and the score with it: %s" % point_label.global_position)
	var to_eye := (pivot + Basis(Vector3.UP, -PI * 0.5) * (Hud.HUD_EYE - pivot)) - hud._left.global_position
	check(hud._left.global_basis.z.normalized().dot(to_eye.normalized()) > 0.999,
		"the turned panel still faces the eye turned with it")
	hud.turn(0.0)
	check(near.call(hud._left.global_position, left.origin) and near.call(point_label.global_position, score),
		"turned back, the HUD is where it was")
	hud.queue_free()
	for node: Node in [point_label, combo, percent]:
		node.queue_free()

## On 90/360 maps the HUD is one cluster FAR_DISTANCE out over the lane, its lowest line clear of the highest note's top
## seen from there by the margin, for any eye height; its lines at Beat Saber's sizes (the owner's exception to the 1.85
## degree minimum, this HUD only); a Hud on a 360 map lays its parts out on it; Standard keeps the side panels.
func check_raised() -> void:
	for eye_y: float in [1.5, 1.6, 1.75]:
		var eye := Vector3(0.0, eye_y, Constants.PLAYER_Z)
		var cluster := Hud.far_cluster(eye, 2.15)
		var to := cluster.origin - eye
		var bottom := rad_to_deg(asin(to.y / to.length())) - Hud.FAR_BELOW_DEG
		var note_top := rad_to_deg(atan((2.15 - eye_y) / Hud.FAR_DISTANCE))
		var top := rad_to_deg(asin(to.y / to.length())) + 1.2 + Hud.FAR_RING.y + Hud.FAR_RING_DEG * 0.5 - 1.2
		print("  far HUD at eye %.2f m: lowest line %.1f deg, centre %.1f, top %.1f (notes' top %.1f)" % [eye_y, bottom,
			bottom + Hud.FAR_BELOW_DEG, top, note_top])
		check(absf(bottom - note_top - Hud.FAR_MARGIN_DEG) < 0.05,
			"eye %.2f m: the far HUD's lowest line (%.1f deg) clears the highest note (%.1f deg) by the margin" % [eye_y, bottom,
			note_top])
		check(absf(to.length() - Hud.FAR_DISTANCE) < 0.01 and absf(cluster.origin.x) < 0.001,
			"eye %.2f m: it is FAR_DISTANCE out, centred over the lane" % eye_y)
		check(cluster.basis.z.normalized().dot(-to.normalized()) > 0.999, "eye %.2f m: it faces the eye" % eye_y)
		check(bottom + Hud.FAR_BELOW_DEG + 2.0 < 20.0, "eye %.2f m: within 20 degrees up" % eye_y)
	# Beat Saber's sizes, as angles at the eye
	var at := func(deg: float) -> float: return rad_to_deg(atan(Hud._far_size(deg) / Hud.FAR_DISTANCE))
	check(absf(at.call(Hud.FAR_SCORE_DEG) - 1.1) < 0.01 and absf(at.call(Hud.FAR_COMBO_DEG) - 1.4) < 0.01
		and absf(at.call(Hud.FAR_SMALL_DEG) - 1.2) < 0.01, "the far HUD's lines are Beat Saber's sizes (1.1, 1.4, 1.2 deg)")
	# a Hud on a 360 map lays its parts out on the cluster; on a Standard map it keeps the side panels
	var point_label := MeshInstance3D.new()
	point_label.mesh = TextMesh.new()
	point_label.material_override = StandardMaterial3D.new()
	var combo := ComboHud.new()
	combo.mesh = TextMesh.new()
	combo.material_override = StandardMaterial3D.new()
	var percent := preload("res://game/hud/PercentIndicator.tscn").instantiate() as PercentIndicator
	for node: Node in [point_label, combo, percent]:
		add_child(node)
	var hud := Hud.new(point_label, combo, percent)
	add_child(hud)
	var saved := Map.current_difficulty
	Map.current_difficulty = DifficultyInfo.new("Expert", 7, "Expert.dat", 16.0, 0.0, {}, "Expert", "360Degree")
	hud.place(Hud.HUD_EYE)
	var cluster := Hud.far_cluster(Hud.HUD_EYE, Hud.notes_top())
	check(hud.far and point_label.global_position.is_equal_approx(cluster.origin) and combo.calm
		and not hud._grade_label.visible and not hud._accuracy_label.visible,
		"on a 360 map the score sits at the far cluster's centre, the combo calm, accuracy and grade off it")
	var combo_yaw := rad_to_deg(atan2(combo.global_position.x - Hud.HUD_EYE.x, Hud.HUD_EYE.z - combo.global_position.z))
	check(absf(combo_yaw - Hud.FAR_COMBO.x) < 0.3, "the combo sits %.1f deg left of centre (got %.1f)" % [-Hud.FAR_COMBO.x,
		combo_yaw])
	Map.current_difficulty = DifficultyInfo.new("Expert", 7, "Expert.dat", 16.0, 0.0, {}, "Expert", "Standard")
	hud.place(Hud.HUD_EYE)
	check(not hud.far and hud._left.global_transform.is_equal_approx(Hud._panel(Hud.HUD_EYE, -1.0)) and not combo.calm
		and hud._grade_label.visible, "a Standard map keeps the side panels as they were")
	Map.current_difficulty = saved
	hud.queue_free()
	for node: Node in [point_label, combo, percent]:
		node.queue_free()
