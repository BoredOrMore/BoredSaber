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
## the multiplier ring's scale (its quad is 0.5 m) and centre, the multiplier's height, and the time line
const HUD_RING_SIZE := 1.5
const HUD_RING := Vector2(0.0, 0.15)
const HUD_MULTIPLIER_HEIGHT := 0.2
const HUD_TIME := Vector3(0.0, -0.3, 0.11)

# the score and the combo keep their nodes in BeepSaber_Game.tscn (other scripts find them by path)
var _point_label: MeshInstance3D
var _combo: ComboHud
var _percent_indicator: PercentIndicator
var _left: Node3D
var _right: Node3D
var _accuracy_label: MeshInstance3D
var _grade_label: MeshInstance3D
## The grade shown, "" before a song's first note, to pop the label when it goes up.
var _grade := ""
var _grade_tween: Tween
var _grade_size := 1.0
## seconds to the rumble's next offset, and how much of the grade-up boost is left (1 just after, 0 settled)
var _rumble_wait := 0.0
var _rumble_boost := 0.0
var _time_label: MeshInstance3D

func _init(point_label: MeshInstance3D, combo: ComboHud, percent_indicator: PercentIndicator) -> void:
	name = "Hud"
	_point_label = point_label
	_combo = combo
	_percent_indicator = percent_indicator

## The two panels and the lines the old HUD didn't have, made like the score's text. The panels show and hide
## with the score (Playing, Paused, MapComplete... set its visibility).
func _ready() -> void:
	_left = Node3D.new()
	_right = Node3D.new()
	add_child(_left)
	add_child(_right)
	_point_label.visibility_changed.connect(func() -> void:
		_left.visible = _point_label.visible
		_right.visible = _point_label.visible)
	var muted := (_point_label.material_override as BaseMaterial3D).duplicate() as BaseMaterial3D
	muted.albedo_color = Constants.UI_TEXT_MUTED
	(_label(_left, HUD_COMBO_CAPTION, muted).mesh as TextMesh).text = "Combo"
	_accuracy_label = _label(_left, HUD_ACCURACY, muted)
	# its own material, for the grade's colour
	_grade_label = _label(_left, HUD_GRADE, (_point_label.material_override as BaseMaterial3D).duplicate())
	_time_label = _label(_right, HUD_TIME, muted)
	_set_letters(_combo.mesh as TextMesh, HUD_COMBO.z)
	_set_letters(_point_label.mesh as TextMesh, HUD_SCORE.z)
	(_point_label.mesh as TextMesh).text = "0"
	_combo.ring.reparent(_right)
	_combo.set_multiplier_height(HUD_MULTIPLIER_HEIGHT / HUD_RING_SIZE)
	# the ring under the score now shows as the accuracy line and the grade beside it
	_percent_indicator.visible = false
	_right.visible = false
	_left.visible = false
	place()

## Puts the two panels in place from the player's eye (the headset's place now), each turned to face it, and the
## old nodes on them.
func place(eye := HUD_EYE) -> void:
	_grade = ""
	_grade_size = 1.0
	_rumble_boost = 0.0
	_grade_label.scale = Vector3.ONE
	_grade_label.position = Vector3(HUD_GRADE.x, HUD_GRADE.y, 0.0)
	_grade_label.rotation = Vector3.ZERO
	_left.global_transform = _panel(eye, -1.0)
	_right.global_transform = _panel(eye, 1.0)
	_point_label.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_SCORE.x, HUD_SCORE.y, 0.0))
	_combo.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_COMBO.x, HUD_COMBO.y, 0.0))
	_combo.rest_at(_combo.position)
	_combo.ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * HUD_RING_SIZE),
			Vector3(HUD_RING.x, HUD_RING.y, 0.0))

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
	if not _left.visible:
		return
	var home := Vector3(HUD_GRADE.x, HUD_GRADE.y, 0.0)
	if not GRADE_RUMBLES.has(_grade):
		_grade_label.position = home
		_grade_label.rotation = Vector3.ZERO
		return
	var rumble: Array = GRADE_RUMBLES[_grade]
	_rumble_boost = maxf(_rumble_boost - delta / GRADE_RUMBLE_BOOST_SECONDS, 0.0)
	var strength := 1.0 + (GRADE_RUMBLE_BOOST - 1.0) * _rumble_boost
	_rumble_wait -= delta
	if _rumble_wait <= 0.0:
		_rumble_wait = 1.0 / GRADE_RUMBLE_HZ
		_grade_label.position = home + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * rumble[0] * strength
		_grade_label.rotation.z = deg_to_rad(randf_range(-1.0, 1.0) * rumble[1] * strength)
	if not (_grade_tween and _grade_tween.is_running()):
		(_grade_label.material_override as BaseMaterial3D).albedo_color = \
				(Constants.RANK_COLORS[_grade] as Color).lerp(Color.WHITE, rumble[2])

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

## 236336 as "236 336", as Beat Saber shows its score
static func _grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
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
