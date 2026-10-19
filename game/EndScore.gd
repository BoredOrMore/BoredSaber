extends MeshInstance3D
class_name EndScore

signal mainmenu
signal repeat

## Fewest seconds between two ticks while the score counts up (about 18 a second at most).
const TICK_MIN_INTERVAL := 0.055
## Tick pitch at 0% and at 100%, so the count sounds like it climbs.
const TICK_PITCH_FROM := 0.9
const TICK_PITCH_TO := 1.6
## The ding when the count lands: a sine with its octave, fading out. A new record or full
## combo adds a second, higher note.
const DING_HZ := 880.0
const DING_HIGH_HZ := 1318.5
const DING_HIGH_DELAY := 0.15
const DING_SECONDS := 0.4
const DING_MIX_RATE := 22050

var animated_percent: float = 0.0
var _tick_player := AudioStreamPlayer.new()
var _ding_player := AudioStreamPlayer.new()
var _ding_high_player := AudioStreamPlayer.new()
@onready var raycast_area := $RaycastArea as Area3D
@onready var collision := $RaycastArea/CollisionShape3D as CollisionShape3D

## Paints the panel and the percent ring in the menu colours and starts with the buttons off.
func _ready() -> void:
	var panel := (mesh as QuadMesh).material as ShaderMaterial
	panel.set_shader_parameter(&"fill_color", Constants.UI_PANEL)
	panel.set_shader_parameter(&"border_color", Constants.UI_BORDER)
	(($PercentIndicator as PercentIndicator).material_override as ShaderMaterial).set_shader_parameter(&"color", Constants.UI_ACCENT)
	set_buttons_disabled(true)
	_tick_player.stream = preload("res://game/data/click_002.ogg")
	_tick_player.bus = &"UI"
	_tick_player.max_polyphony = 4
	add_child(_tick_player)
	_ding_player.stream = _make_ding(DING_HZ)
	_ding_player.bus = &"UI"
	add_child(_ding_player)
	_ding_high_player.stream = _make_ding(DING_HIGH_HZ)
	_ding_high_player.bus = &"UI"
	add_child(_ding_high_player)

## A short synthesized ding, so the count's end needs no sound file.
static func _make_ding(hz: float) -> AudioStreamWAV:
	var count := int(DING_MIX_RATE * DING_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / DING_MIX_RATE
		var v := (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 2.0 * t)) / 1.5 * exp(-t * 8.0)
		data.encode_s16(i * 2, int(v * 0.6 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = DING_MIX_RATE
	wav.data = data
	return wav

func _show() -> void:
	raycast_area.collision_layer = CollisionLayerConstants.Ui_mask
	collision.disabled = false
	($Repeat as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	($MainMenu as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	show()

func _hide() -> void:
	raycast_area.collision_layer = 0
	collision.disabled = true
	($Repeat as UIRaycastButton).collision_layer = 0
	($MainMenu as UIRaycastButton).collision_layer = 0
	_tick_player.stop()
	_ding_player.stop()
	_ding_high_player.stop()
	hide()

func show_score(score: int, record: int, percent: float, song_string: String, is_full_combo: bool, is_new_record: bool) -> void:
	var details_mesh := ($Details as MeshInstance3D).mesh as TextMesh
	var details_material := ($Details as MeshInstance3D).material_override as StandardMaterial3D
	var percent_indicator := $PercentIndicator as PercentIndicator
	var grade_label := $GradeViewport/GradeLabel as RichTextLabel
	var fc_label := $FCViewport/FCLabel as RichTextLabel
	var nr_label := $NRViewport/NRLabel as RichTextLabel
	var name_label := ($NameLabel as MeshInstance3D).mesh as TextMesh
	
	details_material.albedo_color = Color.TRANSPARENT
	grade_label.modulate = Color.TRANSPARENT
	fc_label.modulate = Color.TRANSPARENT
	nr_label.modulate = Color.TRANSPARENT
	percent_indicator.endscore()
	fc_label.visible = is_full_combo
	nr_label.visible = is_new_record
	name_label.text = song_string
	details_mesh.text = "Score\n%d\n\nRecord\n%d" % [score,record]
	# after a fail, trying again is the likely next step
	var repeat_button := $Repeat as UIRaycastButton
	repeat_button.text = "Retry" if percent < 0 else "Repeat"
	repeat_button.set_primary(percent < 0)
	
	if percent >= 0.98:
		grade_label.text = "[center][rainbow freq=0.5 sat=0.7 val=2]A+"
	elif percent >= 0.90:
		grade_label.text = "[center]A"
	elif percent >= 0.80:
		grade_label.text = "[center]B"
	elif percent >= 0.70:
		grade_label.text = "[center]C"
	elif percent >= 0.60:
		grade_label.text = "[center]D"
	elif percent >= 0.50:
		grade_label.text = "[center]E"
	elif percent >= 0.00:
		grade_label.text = "[center]F"
	else:
		grade_label.text = "[center]F-"
	
	var tw: Tween
	if percent >= 0:
		# the score counts up with the ring, ticking like a counter, and dings when it lands
		create_tween().tween_property(details_material,^"albedo_color",Constants.UI_TEXT,0.5).from(Color.TRANSPARENT)
		tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self,^"animated_percent",percent,3.0).from(0.0)
		tw.play()
		var shown_score := -1
		var last_tick := -TICK_MIN_INTERVAL
		while tw.is_running() and visible:
			var progress := animated_percent / percent if percent > 0.0 else 1.0
			percent_indicator.update_percent(animated_percent)
			var counted := int(score * progress)
			var now := Time.get_ticks_msec() / 1000.0
			if counted != shown_score and now - last_tick >= TICK_MIN_INTERVAL:
				shown_score = counted
				last_tick = now
				details_mesh.text = "Score\n%d\n\nRecord\n%d" % [counted, record]
				_tick_player.pitch_scale = lerpf(TICK_PITCH_FROM, TICK_PITCH_TO, progress)
				_tick_player.play()
			await get_tree().process_frame
		#_on_Tween_tween_completed()
		
		percent_indicator.update_percent(animated_percent)
		details_mesh.text = "Score\n%d\n\nRecord\n%d" % [score, record]
		if visible:
			_ding_player.play()
			if is_new_record or is_full_combo:
				await get_tree().create_timer(DING_HIGH_DELAY).timeout
				_ding_high_player.play()
	else:
		create_tween().tween_property(details_material,^"albedo_color",Constants.UI_TEXT,2).from(Color.TRANSPARENT)

	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_parallel()
	tw.tween_property(grade_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(fc_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(nr_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.play()

func set_buttons_disabled(disabled: bool) -> void:
	($Repeat/Collision as CollisionShape3D).disabled = disabled
	($MainMenu/Collision as CollisionShape3D).disabled = disabled

func _on_Repeat_button_up() -> void:
	repeat.emit()

func _on_MainMenu_button_up() -> void:
	set_buttons_disabled(true)
	mainmenu.emit()
