class_name Hud
extends Node3D

## The HUD in Beat Saber's arrangement (owner, 2026-10-27; checked against .claude/skills/vr-ui-design): on the left
## the combo, the score, then the accuracy and the live grade; on the right the multiplier in its filling ring and
## the time played / the song's length. Each side is one flat panel turned to face the eye, its lines laid on it
## (owner: lines each turned their own way didn't sit on one plane).
## Placed from the player's real eye (owner, 2026-10-27: everything the player looks at is worked out from their own
## eye): the headset's place when a song starts (place(eye)). Each panel's centre is HUD_DISTANCE from it, HUD_YAW to
## the side of straight down the track and HUD_PITCH below level, but always past the outer lane by HUD_LANE_MARGIN
## (the Wide modifiers turn it further out). 5.8 m (owner: further back, so a look down the track still takes it in;
## about 19 degrees out, it was 28.5): past vr-ui-design's 3.5 m for text on purpose, the eyes barely refocus between
## the notes and the HUD. The lines' sizes and places below are metres on a panel HUD_LAID_OUT_DISTANCE from the eye;
## the panels grow by HUD_DISTANCE / HUD_LAID_OUT_DISTANCE, so every line keeps that size in view.
## Sizes rank the lines by how much a glance needs them mid-song (owner: no hierarchy made a glance hard to read):
## the combo count and the multiplier biggest, then the grade in its colour, then the score; the accuracy, the time
## and the "Combo" caption small and muted. The grade grows with how good it is (owner, 2026-10-27: start at the
## normal size, bigger and livelier as it gets better): GRADE_SIZES of its normal 0.2 m (2.9 degrees at the eye; 4 at
## SS), shown at normal size until the song's first note. A song starts at the lowest grade
## and climbs (owner, 2026-10-27: starting at SS and dropping felt like being marked down; Beat Saber's live rank starts
## at SS): the grade shown is the lower of the accuracy's and one unlocked a step up from F every GRADE_RAMP_NOTES
## notes, so good play reaches SS after 30 notes; after that it follows the accuracy. The score screen's grade is
## unchanged. Untuned. A grade going up pops from GRADE_POPS times its size, and S
## and SS flash toward white (GRADE_FLASHES), settling over GRADE_POP_SECONDS with a little overshoot, like the end
## screen's grade; a grade going down shrinks back over GRADE_SHRINK_SECONDS without a pop. While it stays at A, S or
## SS it rumbles (owner: a rumble, not a gentle pulse), harder the better it is: GRADE_RUMBLES [shake in metres on the
## panel, tilt in degrees, steady brightening toward white], a new random offset GRADE_RUMBLE_HZ times a second; a
## grade going up rumbles GRADE_RUMBLE_BOOST times as hard, easing back over GRADE_RUMBLE_BOOST_SECONDS. The colour
## doesn't flicker with the shake (no flashing at 3-30 Hz).
## where the eye is taken to be before a song has started (a standing player, 1 m behind the track's origin)
const HUD_EYE := Vector3(0.0, 1.6, 1.0)
const HUD_DISTANCE := 5.83
const HUD_YAW := 19.0
const HUD_PITCH := -3.6
const HUD_LANE_MARGIN := 0.7
const HUD_LAID_OUT_DISTANCE := 4.0
## On 90/360 maps the HUD is one small cluster far down the track above the notes, like Beat Saber's 360 HUD (owner,
## 2026-10-29: the side panels covered incoming notes; "above the lane, far enough to read without losing the notes"):
## FAR_DISTANCE from the eye, centred over the lane, turning with the track. Its lowest line sits FAR_MARGIN_DEG over
## the highest note's top seen from there (notes_top; the notes beyond fly in under it, measured on our 90/360 maps at no
## more than +6 degrees past 5.8 m), worked out at the song's start from the real eye and the map. In it, in degrees
## from its centre (the score): the "Combo" caption and count on the left, the multiplier ring on the right, the energy
## bar under the score and the song's time under that; the accuracy and grade show in Pause and on the score screen. No
## shake or pop, no glow; it draws over walls (FAR_RENDER_PRIORITY) but notes in front of it still hide it. Sizes as
## Beat Saber's (FAR_*_DEG; the score about 1.1 degrees, the combo 1.4, small lines 1.2): below vr-ui-design's
## 1.85 degree minimum for text, an owner exception for this HUD only (Bored, 2026-10-29). Untuned.
const FAR_DISTANCE := 15.0
const FAR_MARGIN_DEG := 1.0
const FAR_SCORE_DEG := 1.1
const FAR_COMBO_DEG := 1.4
const FAR_SMALL_DEG := 1.2
const FAR_CAPTION := Vector2(-7.4, 0.2)
const FAR_COMBO := Vector2(-7.4, -1.3)
const FAR_RING := Vector2(7.4, -1.0)
const FAR_RING_DEG := 4.4
const FAR_MULTIPLIER_DEG := 1.4
const FAR_BAR := Vector2(0.0, -2.0)
const FAR_BAR_SIZE := Vector2(6.4, 0.25)
const FAR_TIME := Vector2(0.0, -3.3)
## how far below its centre the cluster's lowest line reaches (the time's bottom), degrees
const FAR_BELOW_DEG := 3.9
const FAR_RENDER_PRIORITY := 10
## half a note's height at block size 100, and the bombs' and chain links' too
const HUD_NOTE_HALF := 0.25
## The smallest lines are 0.11 m at 4 m (capitals about 1.1 degrees); the old HUD's text was 0.15 m.
const HUD_COMBO_CAPTION := Vector3(0.0, 0.38, 0.11)
const HUD_COMBO := Vector3(0.0, 0.24, 0.22)
const HUD_SCORE := Vector3(0.0, 0.05, 0.13)
const HUD_ACCURACY := Vector3(-0.17, -0.15, 0.11)
const HUD_GRADE := Vector3(0.22, -0.15, 0.2)
const GRADE_SIZES := {"SS": 1.4, "S": 1.2}
const GRADE_POPS := {"SS": 1.45, "S": 1.35, "A": 1.25, "B": 1.15}
const GRADE_FLASHES := {"SS": 0.7, "S": 0.4}
const GRADE_POP_SECONDS := 0.3
const GRADE_SHRINK_SECONDS := 0.3
## grades from lowest to highest, and notes per step of the opening climb
const GRADE_LADDER := ["F", "D", "C", "B", "A", "S", "SS"]
const GRADE_RAMP_NOTES := 5
const GRADE_RUMBLES := {"SS": [0.02, 4.0, 0.3], "S": [0.012, 2.5, 0.15], "A": [0.006, 1.2, 0.0]}
const GRADE_RUMBLE_HZ := 25.0
const GRADE_RUMBLE_BOOST := 2.0
const GRADE_RUMBLE_BOOST_SECONDS := 0.6
## A high grade glows in its own colour, in the letter's own shape (owner, 2026-10-27): the letter drawn again behind
## itself as outlines only, GRADE_GLOW_LAYERS [outline in font pixels, share of the glow] wider and fainter, so the
## light hugs each letter's outline and fades outward. GRADE_GLOWS is the glow's strength (the better, the stronger; brighter by the rumble's
## boost just after going up). The copies share the letter's text and shake and grow with it. Drawn by themselves, so
## they show with the Glow setting off too. Untuned.
## The grade letter's own font, heavy and slanted (owner's pick of the compared fonts, 2026-10-27; OFL)
const GRADE_FONT := preload("res://game/ui/fonts/Kanit-BlackItalic.ttf")
## its capitals are 0.92 of Roboto's at one font size: grown back to the grade's measured size
const GRADE_FONT_SCALE := 1.09
## Numbers (score, combo, multiplier, accuracy, time, cut points, the score screen and records) in Kanit SemiBold
## Italic, weight 600 (owner, 2026-10-28; OFL), grown like the grade (Kanit's digits stand as tall as its capitals)
const NUMBER_FONT := preload("res://game/ui/fonts/Kanit-SemiBoldItalic.ttf")
const NUMBER_FONT_SCALE := GRADE_FONT_SCALE
const GRADE_GLOWS := {"SS": 0.6, "S": 0.4, "A": 0.2}
const GRADE_GLOW_LAYERS := [[10, 0.6], [22, 0.3], [38, 0.15]]
## the multiplier ring and its shockwave draw with this; fade_out fades them through its `fade`
const MULTIPLIER_RING_SHADER := preload("res://game/hud/MultiplierRing.gdshader")
## the multiplier ring's scale (its quad is 0.5 m) and centre, the multiplier's height, and the time line
const HUD_RING_SIZE := 1.5
const HUD_RING := Vector2(0.0, 0.15)
const HUD_MULTIPLIER_HEIGHT := 0.2
const HUD_TIME := Vector3(0.0, -0.3, 0.11)
## the "Practice · 50%" line under the time while practising (muted, the time's size), and on the far cluster above
## the score, clear of the notes below it
const HUD_PRACTICE := Vector3(0.0, -0.45, 0.11)
const FAR_PRACTICE := Vector2(0.0, 1.6)

# the score and the combo keep their nodes in BeepSaber_Game.tscn (other scripts find them by path)
var _point_label: MeshInstance3D
var _combo: ComboHud
var _percent_indicator: PercentIndicator
var _left: Node3D
var _right: Node3D
## On 90/360 maps the HUD turns with the track about the player (turn, EventDriver.track_turned), keeping its angles and
## distance to the track's direction: where place() put the panels, the score and the combo with the track straight,
## and how far the track has turned
var _placed: Array[Transform3D] = []
var _turn := 0.0
## the far cluster on 90/360 maps (place); its "Combo" caption and energy bar, and the bar's fullness
var far := false
var _caption: MeshInstance3D
var _health_bar: MeshInstance3D
var _health := 1.0
var _accuracy_label: MeshInstance3D
var _grade_label: MeshInstance3D
## The grade shown, "" before a song's first note, to pop the label when it goes up.
var _grade := ""
var _grade_tween: Tween
var _grade_glow := Node3D.new()
var _grade_glow_labels: Array[Label3D] = []
var _grade_size := 1.0
## seconds to the rumble's next offset, and how much of the grade-up boost is left (1 just after, 0 settled)
var _rumble_wait := 0.0
var _rumble_boost := 0.0
var _time_label: MeshInstance3D
var _practice_label: MeshInstance3D

func _init(point_label: MeshInstance3D, combo: ComboHud, percent_indicator: PercentIndicator) -> void:
	name = "Hud"
	_point_label = point_label
	_combo = combo
	_percent_indicator = percent_indicator

## The two panels and the lines the old HUD didn't have, made like the score's text. The panels show and hide
## with the score (Playing, Paused, MapComplete... set its visibility).
func _ready() -> void:
	# its own copy: the score's material is shared with the debug text, and a fail fades it (fade_out)
	_point_label.material_override = _point_label.material_override.duplicate()
	_left = Node3D.new()
	_right = Node3D.new()
	add_child(_left)
	add_child(_right)
	_point_label.visibility_changed.connect(func() -> void:
		_left.visible = _point_label.visible
		_right.visible = _point_label.visible)
	var muted := (_point_label.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
	muted.albedo_color = Constants.UI_TEXT_MUTED
	_caption = _label(_left, HUD_COMBO_CAPTION, muted)
	(_caption.mesh as TextMesh).text = "Combo"
	_health_bar = MeshInstance3D.new()
	_health_bar.mesh = QuadMesh.new()
	_health_bar.material_override = muted
	_health_bar.layers = _point_label.layers
	_left.add_child(_health_bar)
	_accuracy_label = _label(_left, HUD_ACCURACY, muted)
	# its own material, for the grade's colour
	_grade_label = _label(_left, HUD_GRADE, (_point_label.material_override as BaseMaterial3D).duplicate())
	(_grade_label.mesh as TextMesh).font = GRADE_FONT
	(_grade_label.mesh as TextMesh).pixel_size *= GRADE_FONT_SCALE
	_add_grade_glow()
	_time_label = _label(_right, HUD_TIME, muted)
	_practice_label = _label(_right, HUD_PRACTICE, muted)
	_set_letters(_combo.mesh as TextMesh, HUD_COMBO.z)
	_set_letters(_point_label.mesh as TextMesh, HUD_SCORE.z)
	(_point_label.mesh as TextMesh).text = "0"
	for label: MeshInstance3D in [_point_label, _combo, _accuracy_label, _time_label]:
		(label.mesh as TextMesh).font = NUMBER_FONT
		(label.mesh as TextMesh).pixel_size *= NUMBER_FONT_SCALE
	_combo.ring.reparent(_right)
	_combo.set_multiplier_height(HUD_MULTIPLIER_HEIGHT / HUD_RING_SIZE)
	# the ring under the score now shows as the accuracy line and the grade beside it
	_percent_indicator.visible = false
	_right.visible = false
	_left.visible = false
	place()

## Puts the two panels in place from the player's eye (the headset's place now), each turned to face it, and the
## old nodes on them; shows the practice line while practising.
func place(eye := HUD_EYE) -> void:
	_grade = ""
	_grade_size = 1.0
	_rumble_boost = 0.0
	_grade_label.scale = Vector3.ONE
	_grade_label.position = Vector3(HUD_GRADE.x, HUD_GRADE.y, 0.0)
	_grade_label.rotation = Vector3.ZERO
	_set_far(Map.current_difficulty != null and Map.current_difficulty.characteristic in Map.TURNING_CHARACTERISTICS)
	if far:
		var cluster := far_cluster(eye, notes_top())
		_left.global_transform = cluster
		_right.global_transform = cluster
		_point_label.global_transform = cluster
		_combo.global_transform = cluster * Transform3D(Basis(), _far_spot(FAR_COMBO))
		_combo.ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * _far_size(FAR_RING_DEG) / ComboHud.RING_SIZE),
				_far_spot(FAR_RING))
		_caption.position = _far_spot(FAR_CAPTION)
		_time_label.position = _far_spot(FAR_TIME)
		_practice_label.position = _far_spot(FAR_PRACTICE)
		show_health(_health)
	else:
		_left.global_transform = _panel(eye, -1.0)
		_right.global_transform = _panel(eye, 1.0)
		_point_label.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_SCORE.x, HUD_SCORE.y, 0.0))
		_combo.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_COMBO.x, HUD_COMBO.y, 0.0))
		_combo.ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * HUD_RING_SIZE),
				Vector3(HUD_RING.x, HUD_RING.y, 0.0))
		_caption.position = Vector3(HUD_COMBO_CAPTION.x, HUD_COMBO_CAPTION.y, 0.0)
		_time_label.position = Vector3(HUD_TIME.x, HUD_TIME.y, 0.0)
		_practice_label.position = Vector3(HUD_PRACTICE.x, HUD_PRACTICE.y, 0.0)
	# practice says so the whole run, so a score that isn't saved never reads as a real one
	_practice_label.visible = Map.practice
	_set_text(_practice_label, "Practice · %d%%" % Map.practice_speed)
	_combo.rest_at(_combo.position)
	_placed = [_left.global_transform, _right.global_transform, _point_label.global_transform, _combo.global_transform]
	turn(_turn)

## Turns the panels, the score and the combo `angle` radians about the player's standing point with the track
## (TrackDeck.turned), from where place() put them.
func turn(angle: float) -> void:
	_turn = angle
	var turned := TrackDeck.turned(angle)
	_left.global_transform = turned * _placed[0]
	_right.global_transform = turned * _placed[1]
	_point_label.global_transform = turned * _placed[2]
	_combo.global_transform = turned * _placed[3]
	_combo.rest_at(_combo.position)

## Switches between the far cluster (`on`, 90/360 maps) and the side panels: the lines' sizes, what shows, the calm
## combo, and drawing over walls.
func _set_far(on: bool) -> void:
	far = on
	_set_letters(_point_label.mesh as TextMesh, _far_size(FAR_SCORE_DEG) if on else HUD_SCORE.z)
	_set_letters(_combo.mesh as TextMesh, _far_size(FAR_COMBO_DEG) if on else HUD_COMBO.z)
	_set_letters(_caption.mesh as TextMesh, _far_size(FAR_SMALL_DEG) if on else HUD_COMBO_CAPTION.z)
	_set_letters(_time_label.mesh as TextMesh, _far_size(FAR_SMALL_DEG) if on else HUD_TIME.z)
	_set_letters(_practice_label.mesh as TextMesh, _far_size(FAR_SMALL_DEG) if on else HUD_PRACTICE.z)
	for label: MeshInstance3D in [_point_label, _combo, _caption, _time_label]:
		(label.mesh as TextMesh).pixel_size *= NUMBER_FONT_SCALE if label != _caption else 1.0
	_combo.set_multiplier_height((_far_size(FAR_MULTIPLIER_DEG) / (_far_size(FAR_RING_DEG) / ComboHud.RING_SIZE)) if on
			else HUD_MULTIPLIER_HEIGHT / HUD_RING_SIZE)
	_combo.calm = on
	_accuracy_label.visible = not on
	_grade_label.visible = not on
	_grade_glow.visible = not on and GRADE_GLOWS.has(_grade)
	_health_bar.visible = on and Settings.health_mode and not Map.practice
	# drawn after the see-through walls, so a wall passing through never covers it; notes in front still do
	for material: BaseMaterial3D in [_point_label.material_override, _caption.material_override,
			_combo.material_override]:
		material.render_priority = FAR_RENDER_PRIORITY if on else 0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if on else BaseMaterial3D.TRANSPARENCY_DISABLED
	(_combo.ring.material_override as ShaderMaterial).render_priority = FAR_RENDER_PRIORITY if on else 0

## Where the far cluster's centre (the score) sits: FAR_DISTANCE from the eye over the lane, facing it, its lowest line
## FAR_MARGIN_DEG over the top of notes reaching `top` metres up (never below level: farther notes come closer to it).
static func far_cluster(eye: Vector3, top: float) -> Transform3D:
	var bottom := maxf(rad_to_deg(atan((top - eye.y) / FAR_DISTANCE)), 0.0) + FAR_MARGIN_DEG
	var pitch := deg_to_rad(bottom + FAR_BELOW_DEG)
	var at := Vector3(0.0, eye.y + FAR_DISTANCE * sin(pitch), eye.z - FAR_DISTANCE * cos(pitch))
	return Transform3D(Basis.looking_at(eye - at, Vector3.UP, true), at)

## A spot on the far cluster `degrees` (across, up) from its centre, in metres on it.
static func _far_spot(degrees: Vector2) -> Vector3:
	return Vector3(_far_size(degrees.x), _far_size(degrees.y), 0.0)

## How many metres `degrees` span on the far cluster.
static func _far_size(degrees: float) -> float:
	return FAR_DISTANCE * tan(deg_to_rad(degrees))

## Fills the far cluster's energy bar to `how_full` (0..1) from its left end.
func show_health(how_full: float) -> void:
	_health = how_full
	var width := _far_size(FAR_BAR_SIZE.x)
	var start := _far_spot(FAR_BAR) - Vector3(width * 0.5, 0.0, 0.0)
	_health_bar.transform = Transform3D(Basis.from_scale(Vector3(maxf(width * how_full, 0.001), _far_size(FAR_BAR_SIZE.y),
			1.0)), start + Vector3(width * how_full * 0.5, 0.0, 0.0))

## A panel on side (-1 left, 1 right): HUD_DISTANCE from the eye at HUD_YAW and HUD_PITCH, turned further out when
## that would put it within HUD_LANE_MARGIN of the outer lane; facing the eye and grown for its distance.
static func _panel(eye: Vector3, side: float) -> Transform3D:
	var pitch := deg_to_rad(HUD_PITCH)
	var level := HUD_DISTANCE * cos(pitch)
	var clear := 1.5 * Settings.LANE_DISTANCE_X + HUD_LANE_MARGIN
	var yaw := maxf(deg_to_rad(HUD_YAW), asin(clampf((clear - side * eye.x) / level, -1.0, 1.0)))
	var at := eye + Vector3(side * sin(yaw) * level, HUD_DISTANCE * sin(pitch), -cos(yaw) * level)
	var grow := HUD_DISTANCE / HUD_LAID_OUT_DISTANCE
	return Transform3D(Basis.looking_at(eye - at, Vector3.UP, true).scaled(Vector3.ONE * grow), at)

## The highest any note, bomb, chain link or arc end of the loaded map reaches (its top, metres above the floor).
static func notes_top() -> float:
	var layer := 0.0
	for note in Map.note_stack:
		layer = maxf(layer, note.line_layer)
	for bomb in Map.bomb_stack:
		layer = maxf(layer, bomb.line_layer)
	for chain in Map.chain_stack:
		layer = maxf(layer, maxf(chain.head_line_layer, chain.tail_line_layer))
	for arc in Map.arc_stack:
		layer = maxf(layer, maxf(arc.head_line_layer, arc.tail_line_layer))
	return Constants.layer_y(layer) + HUD_NOTE_HALF * Settings.block_size / 100.0

## Fades both panels out over `seconds`, then hides them (owner, 2026-10-29: on a fail only FAILED stays in view);
## the next song shows them whole again. Every text, ring and glow on them is faded through its own opacity: the
## Compatibility renderer ignores GeometryInstance3D.transparency. The fade's tween runs after the HUD's own effects
## (the broken-combo tint, the grade's rumble), so its opacity wins over theirs while it lasts.
func fade_out(seconds: float) -> void:
	var materials := {}
	var rings := {}
	var labels := {}
	for root: Node3D in [_left, _right, _point_label, _combo]:
		_collect_shown(root, materials, rings, labels)
	var set_share := func(share: float) -> void:
		for material: BaseMaterial3D in materials:
			material.albedo_color.a = materials[material][0] * share
		for ring: ShaderMaterial in rings:
			ring.set_shader_parameter(&"fade", rings[ring] * share)
		for label: Label3D in labels:
			label.modulate.a = labels[label].x * share
			label.outline_modulate.a = labels[label].y * share
	for material: BaseMaterial3D in materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tween := create_tween()
	tween.tween_method(set_share, 1.0, 0.0, seconds)
	tween.tween_callback(func() -> void:
		_point_label.visible = false
		_combo.visible = false
		set_share.call(1.0)
		for material: BaseMaterial3D in materials:
			material.transparency = materials[material][1])

## The materials (with [opacity, transparency mode]), the rings' shader materials (with their fade) and the 3D labels
## (with their fill and outline opacity) of `node` and everything under it that is shown now.
func _collect_shown(node: Node, materials: Dictionary, rings: Dictionary, labels: Dictionary) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is Label3D:
		labels[node] = Vector2((node as Label3D).modulate.a, (node as Label3D).outline_modulate.a)
	elif node is MeshInstance3D:
		var material := (node as MeshInstance3D).material_override
		if material is BaseMaterial3D:
			materials[material] = [(material as BaseMaterial3D).albedo_color.a, (material as BaseMaterial3D).transparency]
		elif material is ShaderMaterial and (material as ShaderMaterial).shader == MULTIPLIER_RING_SHADER:
			rings[material] = (material as ShaderMaterial).get_shader_parameter(&"fade")
		else:
			push_error("Hud: %s has no material the fade knows" % node.name)
	for child in node.get_children():
		_collect_shown(child, materials, rings, labels)

## The score, the time played of the song's length (whole seconds), the accuracy and its grade.
func show_points(points: int, played: int, length: int, accuracy: float) -> void:
	_set_text(_point_label, _grouped(points))
	_set_text(_time_label, "%s / %s" % [_clock(clampi(played, 0, length)), _clock(length)])
	_set_text(_accuracy_label, "%.1f%%" % (accuracy * 100.0))
	var grade := shown_grade(accuracy, Scoreboard._notes_scored)
	_set_text(_grade_label, grade)
	var material := _grade_label.material_override as BaseMaterial3D
	# before the first note the accuracy reads 100%: the normal size, no pop
	if Scoreboard.max_points <= 0:
		material.albedo_color = Constants.RANK_COLORS[grade]
		return
	if grade == _grade:
		return
	_grade_size = float(GRADE_SIZES.get(grade, 1.0))
	if grade_rises(_grade, grade):
		_rumble_boost = 1.0
	var size := Vector3.ONE * _grade_size
	if _grade_tween:
		_grade_tween.kill()
	_grade_tween = create_tween().set_parallel()
	if grade_rises(_grade, grade) or _grade == "":
		_grade_tween.tween_property(_grade_label, ^"scale", size, GRADE_POP_SECONDS).from(size * float(GRADE_POPS.get(grade, 1.0))) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var flash := Constants.RANK_COLORS[grade].lerp(Color.WHITE, float(GRADE_FLASHES.get(grade, 0.0))) as Color
		_grade_tween.tween_property(material, ^"albedo_color", Constants.RANK_COLORS[grade], GRADE_POP_SECONDS).from(flash)
	else:
		_grade_tween.tween_property(_grade_label, ^"scale", size, GRADE_SHRINK_SECONDS).set_trans(Tween.TRANS_QUAD)
		material.albedo_color = Constants.RANK_COLORS[grade]
	_grade = grade
	_percent_indicator.update_percent(accuracy)

## The rumble at A, S and SS: the letter shakes and tilts around its spot (alongside a pop's growing), brighter.
func _process(delta: float) -> void:
	if not _left.visible or far:
		return
	var home := Vector3(HUD_GRADE.x, HUD_GRADE.y, 0.0)
	_grade_glow.visible = GRADE_GLOWS.has(_grade)
	if not GRADE_RUMBLES.has(_grade):
		_grade_label.position = home
		_grade_label.rotation = Vector3.ZERO
		return
	var rumble: Array = GRADE_RUMBLES[_grade]
	_rumble_boost = maxf(_rumble_boost - delta / GRADE_RUMBLE_BOOST_SECONDS, 0.0)
	var strength := 1.0 + (GRADE_RUMBLE_BOOST - 1.0) * _rumble_boost
	for i in GRADE_GLOW_LAYERS.size():
		_grade_glow_labels[i].text = (_grade_label.mesh as TextMesh).text
		_grade_glow_labels[i].outline_modulate = Color(Constants.RANK_COLORS[_grade],
				minf(float(GRADE_GLOWS.get(_grade, 0.0)) * strength * GRADE_GLOW_LAYERS[i][1], 1.0))
	_rumble_wait -= delta
	if _rumble_wait <= 0.0:
		_rumble_wait = 1.0 / GRADE_RUMBLE_HZ
		_grade_label.position = home + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * rumble[0] * strength
		_grade_label.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * rumble[1] * strength)
	if not (_grade_tween and _grade_tween.is_running()):
		(_grade_label.material_override as BaseMaterial3D).albedo_color = \
				(Constants.RANK_COLORS[_grade] as Color).lerp(Color.WHITE, rumble[2])

## The glow behind the grade letter: the same letters as outlines only (no fill), widest at the back, moving with it.
func _add_grade_glow() -> void:
	var mesh := _grade_label.mesh as TextMesh
	for i in GRADE_GLOW_LAYERS.size():
		var glow := Label3D.new()
		glow.font = mesh.font
		glow.font_size = mesh.font_size
		glow.pixel_size = mesh.pixel_size
		glow.outline_size = GRADE_GLOW_LAYERS[i][0]
		glow.modulate = Color(1, 1, 1, 0)
		glow.horizontal_alignment = mesh.horizontal_alignment
		glow.vertical_alignment = mesh.vertical_alignment
		glow.shaded = false
		glow.double_sided = false
		glow.layers = _point_label.layers
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.render_priority = -1 - i
		glow.outline_render_priority = -1 - i
		glow.position.z = -0.005 * (i + 1)
		_grade_glow_labels.append(glow)
		_grade_glow.add_child(glow)
	_grade_glow.visible = false
	_grade_label.add_child(_grade_glow)

## The grade the HUD shows after notes notes at this accuracy: the accuracy's grade, but no higher than a step up from
## F every GRADE_RAMP_NOTES notes.
static func shown_grade(accuracy: float, notes: int) -> String:
	var earned := GRADE_LADDER.find(EndScore.grade(accuracy))
	@warning_ignore("integer_division")
	return GRADE_LADDER[mini(earned, mini(notes / GRADE_RAMP_NOTES, GRADE_LADDER.size() - 1))]

## Whether the grade went up from before to after (not the first one of a song).
static func grade_rises(before: String, after: String) -> bool:
	var order: Array = Constants.RANK_COLORS.keys()
	return before != "" and order.find(after) < order.find(before)

static func _set_text(label: MeshInstance3D, text: String) -> void:
	var mesh := label.mesh as TextMesh
	if mesh.text != text:
		mesh.text = text

## 236336 as "236,336" (owner, 2026-10-28: commas in every score and count)
static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

static func _clock(seconds: int) -> String:
	@warning_ignore("integer_division")
	return "%d:%02d" % [seconds / 60, seconds % 60]

## A one-line label of letters height metres, centred on its spot.
func _label(panel: Node3D, spot: Vector3, material: BaseMaterial3D) -> MeshInstance3D:
	var label := MeshInstance3D.new()
	var mesh := (_point_label.mesh as TextMesh).duplicate() as TextMesh
	mesh.text = ""
	_set_letters(mesh, spot.z)
	label.mesh = mesh
	label.material_override = material
	label.layers = _point_label.layers
	label.position = Vector3(spot.x, spot.y, 0.0)
	panel.add_child(label)
	return label

## Text height in metres (the font's size; capitals come out about 0.73 of it), rendered from a 100 px font, centred on
## the label's origin. TextMesh caps font_size at 127, so the size goes through pixel_size.
static func _set_letters(mesh: TextMesh, height: float) -> void:
	mesh.font_size = 100
	mesh.pixel_size = height / 100.0
	mesh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mesh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
