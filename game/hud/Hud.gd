class_name Hud
extends Node3D

## The HUD in Beat Saber's arrangement (owner, 2026-10-27; checked against .claude/skills/vr-ui-design): on the left
## the combo, the score, then the accuracy and the live grade; on the right the multiplier in its filling ring and
## the time played / the song's length. Each side is one flat panel turned to face HUD_EYE, its lines laid on it
## (owner: lines each turned their own way didn't sit on one plane). HUD_AHEAD ahead, beside the lanes (HUD_SIDE, or
## out past the outer lane by HUD_LANE_MARGIN on wide modifiers), centred at HUD_Y. 5.5 m from the eye (owner,
## 2026-10-27: further back, so a look straight down the track still takes it in): about 19 degrees to the side (it
## was 28.5 at 3.5 m) and from about 3 degrees above the eye to 9 below. Past vr-ui-design's 3.5 m for text on
## purpose: there the eyes barely refocus between the notes and the HUD; the panels are scaled up with the distance
## (_facing_eye) so the text keeps the size in view it had at 3.5 m.
## Sizes rank the lines by how much a glance needs them mid-song (owner: no hierarchy made a glance hard to read):
## the combo count and the multiplier biggest, then the grade in its colour, then the score; the accuracy, the time
## and the "Combo" caption small and muted. Sizes are the letters' height in metres; positions are on the panel.
const HUD_EYE := Vector3(0.0, 1.6, 1.0)
const HUD_AHEAD := -4.5
## the sizes and places below were laid out for panels HUD_LAID_OUT_AHEAD ahead (3.5 m out); farther out a panel grows
## with its distance from the eye (_facing_eye), so each line keeps the size in view it had there
const HUD_LAID_OUT_AHEAD := -2.5
const HUD_SIDE := 1.9
const HUD_LANE_MARGIN := 0.7
const HUD_Y := 1.25
## The smallest lines are 0.11 m at 3.5 m (capitals about 1.3 degrees); the old HUD's text was 0.15 m.
const HUD_COMBO_CAPTION := Vector3(0.0, 0.38, 0.11)
const HUD_COMBO := Vector3(0.0, 0.24, 0.22)
const HUD_SCORE := Vector3(0.0, 0.05, 0.13)
const HUD_ACCURACY := Vector3(-0.17, -0.11, 0.11)
const HUD_GRADE := Vector3(0.19, -0.11, 0.2)
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

## Puts the two panels in place for the lane width, each turned to face the eye, and the old nodes on them.
func place() -> void:
	var side := maxf(HUD_SIDE, 1.5 * Settings.LANE_DISTANCE_X + HUD_LANE_MARGIN)
	_left.global_transform = _facing_eye(Vector3(-side, HUD_Y, HUD_AHEAD))
	_right.global_transform = _facing_eye(Vector3(side, HUD_Y, HUD_AHEAD))
	_point_label.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_SCORE.x, HUD_SCORE.y, 0.0))
	_combo.global_transform = _left.global_transform * Transform3D(Basis(), Vector3(HUD_COMBO.x, HUD_COMBO.y, 0.0))
	_combo.rest_at(_combo.position)
	_combo.ring.transform = Transform3D(Basis.from_scale(Vector3.ONE * HUD_RING_SIZE),
			Vector3(HUD_RING.x, HUD_RING.y, 0.0))

## The score, the time played of the song's length (whole seconds), the accuracy and its grade.
func show_points(points: int, played: int, length: int, accuracy: float) -> void:
	_set_text(_point_label, _grouped(points))
	_set_text(_time_label, "%s / %s" % [_clock(clampi(played, 0, length)), _clock(length)])
	_set_text(_accuracy_label, "%.1f%%" % (accuracy * 100.0))
	var grade := EndScore.grade(accuracy)
	_set_text(_grade_label, grade)
	(_grade_label.material_override as BaseMaterial3D).albedo_color = Constants.RANK_COLORS[grade]
	_percent_indicator.update_percent(accuracy)

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

## A panel at `at`, its face (+z) turned to the eye.
static func _facing_eye(at: Vector3) -> Transform3D:
	var grow := (at - HUD_EYE).length() / (Vector3(at.x, at.y, HUD_LAID_OUT_AHEAD) - HUD_EYE).length()
	return Transform3D(Basis.looking_at(HUD_EYE - at, Vector3.UP, true).scaled(Vector3.ONE * grow), at)
