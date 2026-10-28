extends Node3D
class_name ResultMoment
## The moment a song ends, like Beat Saber (owner, 2026-10-28; doc/research/score-screen-plan.md, option C): on a fail
## a big "FAILED" where the notes were, in the grade's font, white-hot with a glow of the danger colour and a faint
## mirror image in the deck; then, on a fail or a clear, the view fades to black for FADE_SECONDS and back up on the
## score screen. The fade is a black quad just in front of the eye (no post-processing), a darkening, never a flash.
## Placed from the player's real eye (root AGENTS.md): WORD_DISTANCE ahead at eye height, WORD_HEIGHT letters (about
## 8 degrees, inside the no-head-turn zone; the word is about 30 degrees wide). Untuned.

const WORD := "FAILED"
const WORD_DISTANCE := 7.0
const WORD_HEIGHT := 1.0
## the word's letters at a 100 px font through pixel_size; Kanit's capitals are about 0.73 of the font size
const FONT_SIZE := 100
const CAP_SHARE := 0.73
## the core leans this far from the danger colour to white (white-hot), the glow layers [outline px, alpha] behind it
const CORE_WHITE := 0.6
const GLOW_LAYERS := [[12, 0.55], [28, 0.25], [48, 0.12]]
## the word grows from WORD_POP_FROM of its size and fades up over WORD_POP_SECONDS
const WORD_POP_FROM := 0.85
const WORD_POP_SECONDS := 0.2
## the mirror image in the deck (y 0): this strong
const MIRROR_ALPHA := 0.2
const FADE_SECONDS := 0.5
## the fade quad: this far in front of the eye, big enough to cover the view
const FADE_DISTANCE := 0.15
const FADE_SIZE := 1.0

var _word := Node3D.new()
var _mirror := Node3D.new()
var _fade := MeshInstance3D.new()
var _fade_material := StandardMaterial3D.new()

## Builds the word (hidden) and the fade quad, which rides on `camera`.
func _init(camera: Node3D) -> void:
	_build_word(_word, 1.0)
	_build_word(_mirror, MIRROR_ALPHA)
	_mirror.scale = Vector3(1.0, -1.0, 1.0)
	add_child(_word)
	add_child(_mirror)
	_word.visible = false
	_mirror.visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * FADE_SIZE
	_fade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_material.no_depth_test = true
	_fade_material.render_priority = BaseMaterial3D.RENDER_PRIORITY_MAX
	_fade_material.albedo_color = Color(0, 0, 0, 0)
	quad.material = _fade_material
	_fade.mesh = quad
	_fade.position = Vector3(0.0, 0.0, -FADE_DISTANCE)
	_fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fade.visible = false
	camera.add_child(_fade)

## The word's glow layers and core under `holder`, at `alpha`; the mirror's ignores depth so the deck doesn't hide it.
func _build_word(holder: Node3D, alpha: float) -> void:
	var pixel := WORD_HEIGHT / (FONT_SIZE * CAP_SHARE)
	for i in GLOW_LAYERS.size() + 1:
		var label := Label3D.new()
		label.text = WORD
		label.font = Hud.GRADE_FONT
		label.font_size = FONT_SIZE
		label.pixel_size = pixel
		label.shaded = false
		label.double_sided = true
		label.no_depth_test = alpha < 1.0
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i < GLOW_LAYERS.size():
			# outlines only, widest at the back
			label.modulate = Color(1, 1, 1, 0)
			label.outline_size = GLOW_LAYERS[i][0]
			label.outline_modulate = Color(Constants.DANGER_COLOR, GLOW_LAYERS[i][1] * alpha)
			label.render_priority = -1 - i
			label.outline_render_priority = -1 - i
			label.position.z = -0.01 * (i + 1)
		else:
			label.modulate = Color(Constants.DANGER_COLOR.lerp(Color.WHITE, CORE_WHITE), alpha)
			label.outline_size = 0
		holder.add_child(label)

## Pops "FAILED" up WORD_DISTANCE ahead of `eye`, with its mirror image in the deck.
func show_failed(eye: Vector3) -> void:
	_word.position = Vector3(eye.x, eye.y, eye.z - WORD_DISTANCE)
	_mirror.position = Vector3(eye.x, -eye.y, eye.z - WORD_DISTANCE)
	for holder: Node3D in [_word, _mirror]:
		holder.visible = true
		holder.scale = Vector3(1.0, signf(holder.scale.y), 1.0) * WORD_POP_FROM
		var target := Vector3(1.0, signf(holder.scale.y), 1.0)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(holder, ^"scale", target, WORD_POP_SECONDS)
	_set_word_fade(0.0)
	create_tween().tween_method(_set_word_fade, 0.0, 1.0, WORD_POP_SECONDS)

## How far the word has faded up (0 to 1), on its core and glow alike.
func _set_word_fade(share: float) -> void:
	for holder: Node3D in [_word, _mirror]:
		for label: Label3D in holder.get_children():
			label.transparency = 1.0 - share

## Takes the word away.
func hide_failed() -> void:
	_word.visible = false
	_mirror.visible = false

## Fades the view to black over `seconds` (FADE_SECONDS unless given; also the stage switch's fade); await it.
func fade_out(seconds := FADE_SECONDS) -> void:
	_fade.visible = true
	await create_tween().tween_property(_fade_material, ^"albedo_color:a", 1.0, seconds).finished

## Fades the view back up from black over `seconds` (FADE_SECONDS unless given).
func fade_in(seconds := FADE_SECONDS) -> void:
	await create_tween().tween_property(_fade_material, ^"albedo_color:a", 0.0, seconds).finished
	_fade.visible = false
