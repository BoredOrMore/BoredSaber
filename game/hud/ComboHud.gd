extends MeshInstance3D
class_name ComboHud
## The combo count and multiplier on the left of the HUD (the Multiplier_Label node), with feedback that makes a
## combo feel like something: the ring around the multiplier fills hit by hit as in Beat Saber and flashes when the
## multiplier goes up, and a broken combo shakes and turns MISS_COLOR for a moment. The count itself holds still on
## ordinary hits: the HUD sits near the edge of view, where steady motion distracts (Apple visionOS: avoid busy
## motion at the edges), so only multiplier raises and milestones flash, and no text grows.
## Kept moderate on purpose: too much feedback makes a game feel and play worse, not better (Kao 2020, "The effects
## of juiciness in an action RPG"), and big flashes are tiring in a headset.

## a combo of 50, then every 100: the game also brightens the air and buzzes the controllers
signal milestone_reached(combo: int)

## the ring's glow when the multiplier goes up fades with the chime's ringing tail (tools/make_combo_sounds.py), so
## sound and light end together. No text grows: only the HUD grade's letter pops (owner, 2026-10-27) (untuned)
const RAISE_FLASH_SECONDS := 0.8
## a thin copy of the ring grows out of it and fades as the chime lands: by this much of its size, over this long;
## bigger and slower for a milestone. It stays on the HUD panel, the view itself never moves (untuned)
const SHOCKWAVE_GROWTH := 0.6
const SHOCKWAVE_SECONDS := 0.6
const MILESTONE_SHOCKWAVE_GROWTH := 1.2
const MILESTONE_SHOCKWAVE_SECONDS := 1.0
## how far (in this node's units) and how long a broken combo shakes, and how long its tint takes to fade (untuned)
const BREAK_SHAKE := 0.04
const BREAK_SHAKE_SECONDS := 0.3
const BREAK_SHAKE_SPEED := 60.0
const BREAK_TINT_SECONDS := 0.5
## segments the ring fills in or drains per second
const RING_FILL_SPEED := 12.0
## the ring sits under the combo count as the accuracy ring sits under the score
const RING_OFFSET := Vector3(0, -0.4933, 0)
const RING_SIZE := 0.5
## the first milestone, then one every MILESTONE_STEP
const FIRST_MILESTONE := 50
const MILESTONE_STEP := 100
## the "100 COMBO" text rises from above the combo count and fades out (this node's units, untuned)
const MILESTONE_START := Vector3(0, 0.12, 0)
const MILESTONE_RISE := 0.15
const MILESTONE_SECONDS := 1.8
## the multiplier chime climbs a major chord, x2 x4 x8 (tools/make_combo_sounds.py makes the sounds)
const UP_PITCHES := {2: 1.0, 4: 1.26, 8: 1.5}
## a break only sounds when it ends a combo at least this long, so early misses stay quiet
const BREAK_SOUND_MIN_COMBO := 10

var _base_position: Vector3
var _text_material: BaseMaterial3D
var _text_color: Color
var _ring_material: ShaderMaterial
var _shockwave: MeshInstance3D
var _shockwave_material: ShaderMaterial
var _shockwave_tween: Tween
## the multiplier in its filling ring; the game moves it to the right of the view, apart from the combo count
var ring: MeshInstance3D
var _multiplier_mesh: TextMesh
var _multiplier_material: BaseMaterial3D
var _shown_multiplier := 1
var _segments := 2.0
var _filled := 0.0
var _filled_target := 0.0
var _shake_left := 0.0
var _raise_tween: Tween
var _tint_tween: Tween
var _milestone_label: MeshInstance3D
var _milestone_mesh: TextMesh
var _milestone_material: BaseMaterial3D
var _milestone_tween: Tween
var _up_sound: AudioStreamPlayer
var _milestone_sound: AudioStreamPlayer
var _break_sound: AudioStreamPlayer
## no shake, pops or shockwaves (the far HUD of 90/360 maps, Hud: in the middle of the view they'd pull the eye off the
## notes); the sounds and the broken combo's tint stay
var calm := false

func _ready() -> void:
	_base_position = position
	# own copies, so tinting this text leaves the score's alone
	_text_material = material_override.duplicate() as BaseMaterial3D
	material_override = _text_material
	_text_color = _text_material.albedo_color

	ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(RING_SIZE, RING_SIZE)
	ring.mesh = quad
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = preload("res://game/hud/MultiplierRing.gdshader")
	_ring_material.set_shader_parameter(&"fill_color", Constants.COMBO_RING_COLOR)
	_ring_material.set_shader_parameter(&"empty_color", Constants.COMBO_RING_EMPTY_COLOR)
	# tweens need every parameter they animate to be set first
	_ring_material.set_shader_parameter(&"segments", _segments)
	_ring_material.set_shader_parameter(&"filled", 0.0)
	_ring_material.set_shader_parameter(&"flash", 0.0)
	_ring_material.set_shader_parameter(&"fade", 1.0)
	ring.material_override = _ring_material
	ring.position = RING_OFFSET
	ring.layers = layers
	add_child(ring)

	var multiplier_label := MeshInstance3D.new()
	_multiplier_mesh = TextMesh.new()
	_multiplier_mesh.font = Hud.NUMBER_FONT
	_multiplier_mesh.font_size = 100
	_multiplier_mesh.pixel_size = 0.001 * Hud.NUMBER_FONT_SCALE
	_multiplier_mesh.depth = 0.0
	multiplier_label.mesh = _multiplier_mesh
	_multiplier_material = _text_material.duplicate() as BaseMaterial3D
	multiplier_label.material_override = _multiplier_material
	multiplier_label.position = Vector3(0, 0, 0.02)
	multiplier_label.layers = layers
	ring.add_child(multiplier_label)

	# the shockwave: the ring's shape, whole and in the accent colour, behind the multiplier
	_shockwave = MeshInstance3D.new()
	_shockwave.mesh = quad
	_shockwave_material = _ring_material.duplicate() as ShaderMaterial
	_shockwave_material.set_shader_parameter(&"segments", 1.0)
	_shockwave_material.set_shader_parameter(&"filled", 1.0)
	_shockwave_material.set_shader_parameter(&"fill_color", Constants.UI_ACCENT)
	_shockwave_material.set_shader_parameter(&"fade", 0.0)
	_shockwave.material_override = _shockwave_material
	_shockwave.position = Vector3(0, 0, -0.01)
	_shockwave.layers = layers
	_shockwave.visible = false
	ring.add_child(_shockwave)

	_milestone_label = MeshInstance3D.new()
	_milestone_mesh = _multiplier_mesh.duplicate() as TextMesh
	_milestone_mesh.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_milestone_label.mesh = _milestone_mesh
	_milestone_material = _text_material.duplicate() as BaseMaterial3D
	_milestone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_milestone_material.albedo_color = Constants.UI_ACCENT
	_milestone_label.material_override = _milestone_material
	_milestone_label.layers = layers
	_milestone_label.visible = false
	add_child(_milestone_label)

	_up_sound = _add_sound(preload("res://game/data/combo_up.wav"))
	_milestone_sound = _add_sound(preload("res://game/data/combo_milestone.wav"))
	_break_sound = _add_sound(preload("res://game/data/combo_break.wav"))
	# 3.5 LU under combo_up though it matters more (loudness notes, 2026-10-23)
	_break_sound.volume_db = 3.0

	Scoreboard.score_changed.connect(refresh)
	Scoreboard.combo_hit.connect(_on_combo_hit)
	Scoreboard.multiplier_raised.connect(_on_multiplier_raised)
	Scoreboard.combo_broken.connect(_on_combo_broken)
	refresh()

func _add_sound(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	add_child(player)
	return player

## Shows the current combo and multiplier; the ring moves to them over the next frames.
func refresh() -> void:
	# the "Combo" caption is the game's HUD label above this count
	var text := Hud._grouped(Scoreboard.combo)
	if (mesh as TextMesh).text != text:
		(mesh as TextMesh).text = text
	_multiplier_mesh.text = "x%d" % Scoreboard.multiplier
	if Scoreboard.multiplier != _shown_multiplier:
		_segments = 1.0 if Scoreboard.multiplier >= 8 else 2.0 * Scoreboard.multiplier
		_ring_material.set_shader_parameter(&"segments", _segments)
		# going up starts the new ring empty; going down drains it from full
		_filled = 0.0 if Scoreboard.multiplier > _shown_multiplier else _segments
		_shown_multiplier = Scoreboard.multiplier
	_filled_target = Scoreboard.multiplier_progress() * _segments

func _process(delta: float) -> void:
	if _filled != _filled_target:
		_filled = move_toward(_filled, _filled_target, RING_FILL_SPEED * delta)
		_ring_material.set_shader_parameter(&"filled", _filled)
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		var amount := BREAK_SHAKE * _shake_left / BREAK_SHAKE_SECONDS
		position = _base_position + Vector3(sin(_shake_left * BREAK_SHAKE_SPEED) * amount, 0, 0)

## The multiplier's letter height in the ring's own units (metres before the ring is scaled).
func set_multiplier_height(height: float) -> void:
	# TextMesh caps font_size at 127, so the size goes through pixel_size
	_multiplier_mesh.font_size = 100
	_multiplier_mesh.pixel_size = height / 100.0

## Where the count rests, for the game's HUD layout (the broken-combo shake swings around it).
func rest_at(at: Vector3) -> void:
	_base_position = at

## True for the combos that get a milestone: 50, 100, 200, 300...
static func is_milestone(combo: int) -> bool:
	return combo == FIRST_MILESTONE or (combo >= MILESTONE_STEP and combo % MILESTONE_STEP == 0)

func _on_combo_hit() -> void:
	if is_milestone(Scoreboard.combo):
		if not calm:
			_show_milestone(Scoreboard.combo)
			_send_shockwave(MILESTONE_SHOCKWAVE_GROWTH, MILESTONE_SHOCKWAVE_SECONDS)
		_milestone_sound.play()
		milestone_reached.emit(Scoreboard.combo)

func _show_milestone(combo: int) -> void:
	_milestone_mesh.text = "%s COMBO" % Hud._grouped(combo)
	_milestone_label.visible = true
	if _milestone_tween:
		_milestone_tween.kill()
	_milestone_tween = create_tween().set_parallel()
	_milestone_tween.tween_property(_milestone_label, ^"position", MILESTONE_START + Vector3(0, MILESTONE_RISE, 0), MILESTONE_SECONDS).from(MILESTONE_START).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var faded := Constants.UI_ACCENT
	faded.a = 0.0
	_milestone_tween.tween_property(_milestone_material, ^"albedo_color", faded, MILESTONE_SECONDS * 0.5).from(Constants.UI_ACCENT).set_delay(MILESTONE_SECONDS * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_milestone_tween.chain().tween_callback(_milestone_label.hide)

func _on_multiplier_raised(multiplier: int) -> void:
	_up_sound.pitch_scale = UP_PITCHES.get(multiplier, 1.0)
	_up_sound.play()
	if calm:
		return
	if _raise_tween:
		_raise_tween.kill()
	_raise_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_raise_tween.tween_property(_ring_material, ^"shader_parameter/flash", 0.0, RAISE_FLASH_SECONDS).from(1.0)
	_send_shockwave(SHOCKWAVE_GROWTH, SHOCKWAVE_SECONDS)

## Grows the shockwave out of the ring by growth of its size over seconds, fading it out; a new one restarts it.
func _send_shockwave(growth: float, seconds: float) -> void:
	if _shockwave_tween:
		_shockwave_tween.kill()
	_shockwave.visible = true
	_shockwave_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shockwave_tween.tween_property(_shockwave, ^"scale", Vector3.ONE * (1.0 + growth), seconds).from(Vector3.ONE)
	_shockwave_tween.tween_property(_shockwave_material, ^"shader_parameter/fade", 0.0, seconds).from(1.0)
	_shockwave_tween.chain().tween_callback(_shockwave.hide)

func _on_combo_broken(lost_combo: int) -> void:
	if lost_combo >= BREAK_SOUND_MIN_COMBO:
		_break_sound.play()
	if not calm:
		_shake_left = BREAK_SHAKE_SECONDS
	if _tint_tween:
		_tint_tween.kill()
	_tint_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tint_tween.tween_property(_text_material, ^"albedo_color", _text_color, BREAK_TINT_SECONDS).from(Constants.MISS_COLOR)
	_tint_tween.tween_property(_multiplier_material, ^"albedo_color", _text_color, BREAK_TINT_SECONDS).from(Constants.MISS_COLOR)
	_tint_tween.tween_property(_ring_material, ^"shader_parameter/fill_color", Constants.COMBO_RING_COLOR, BREAK_TINT_SECONDS).from(Constants.MISS_COLOR)
	_tint_tween.tween_property(_ring_material, ^"shader_parameter/empty_color", Constants.COMBO_RING_EMPTY_COLOR, BREAK_TINT_SECONDS).from(Constants.MISS_COLOR.darkened(0.5))
