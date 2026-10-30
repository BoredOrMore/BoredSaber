extends MeshInstance3D
class_name EndScore

signal mainmenu
signal repeat
## "Practice this part" after a fail (owner, 2026-10-30).
signal practice_part
## "Not you?" on the name card: the player wants this run's record under someone else (owner, 2026-10-28)
signal change_player

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
## lowest accuracy for each rank, best first; anything lower is F
const GRADES := [[0.9, "SS"], [0.8, "S"], [0.65, "A"], [0.5, "B"], [0.35, "C"], [0.2, "D"]]
# While the score counts up, the ring turns from grey toward the colour of the rank reached so far; each new
# rank pops its letter in with a blip. At the end the ring glows and pulses once, and the top rank gets a
# light running around it. All values untuned.
## where the target icon sits on this screen: inside the ring, under the %, smaller than the HUD's.
## Set in code because an override of the ring scene's child in EndScore.tscn didn't reach the exported game.
const ICON_POSITION := Vector3(0, -0.11, 0.1)
const ICON_PIXEL_SIZE := 0.00047
const RING_COLOR_SPEED := 6.0
const RANK_POP_SCALE := 1.35
const RANK_POP_SECONDS := 0.25
const RANK_UP_HZ := 1760.0
const HALO_PEAK := 1.2
const HALO_REST := 0.6
const PULSE_SCALE := 1.06
const PULSE_SECONDS := 0.35
const TOP_RANK_SPARKLE := 0.8
## How wide the song's lines may run on the board (metres, from the name label's left edge): the first to the board's
## right padding, the second (level and map author) to just before "New Record!" (NRMesh). Longer lines end in "…"
## instead of spilling off the board (owner on the headset, 2026-10-25: the score board's content overflowed).
const NAME_WIDTHS := [1.8, 1.3]
## the name card's text, one line, at most this wide; less CARD_BUTTON_ROOM when "Not you?" sits at its right end
const CARD_TEXT_WIDTH := 1.5
const CARD_BUTTON_ROOM := 0.42
## The name card under the score (where this run stands on the map's board, and the button to name it) lights its
## border once when the count lands, so the eye goes to it after the score (untuned).
const CARD_GLOW_SECONDS := 0.8

## The headline across the board under the song's name (owner, 2026-10-28, after Beat Saber's results): "FAILED" in
## white on a bar of the danger colour, or "SONG CLEARED" in the panel's dark on a bar of the rank's colour, in the
## grade's font. The board grew BANNER_ROOM upward for it (EndScore.tscn); the song's name moved up with it.
const BANNER_SIZE := Vector2(1.8, 0.08)
const BANNER_Y := 0.43
const BANNER_TEXT_HEIGHT := 0.062
const BANNER_CORNER := 0.02
const FAILED_TEXT := "FAILED"
const CLEARED_TEXT := "SONG CLEARED"
## Where the buttons sit across the bottom: Repeat and Main Menu, or after a fail Practice this part, Retry and Main
## Menu (x in metres).
const TWO_BUTTONS_X := [-0.3, 0.3]
const THREE_BUTTONS_X := [-0.6, 0.0, 0.6]
## After a fail the empty ring and its 0% give way to how far the song got ("Failed at 1:42\nof 3:10"), at the ring's
## place, PROGRESS_TEXT_HEIGHT letters.
const PROGRESS_TEXT_HEIGHT := 0.07
const PROGRESS_Y := 0.06
## TextMesh sizes go through pixel_size from a 100 px font (font_size is capped at 127)
const LABEL_FONT_SIZE := 100
var animated_percent: float = 0.0
var _banner_material := ShaderMaterial.new()
var _banner_text := TextMesh.new()
var _banner_text_material := StandardMaterial3D.new()
var _progress_text := TextMesh.new()
var _progress := MeshInstance3D.new()
var _tick_player := AudioStreamPlayer.new()
var _ding_player := AudioStreamPlayer.new()
var _ding_high_player := AudioStreamPlayer.new()
var _rank_up_player := AudioStreamPlayer.new()
@onready var raycast_area := $RaycastArea as Area3D
@onready var collision := $RaycastArea/CollisionShape3D as CollisionShape3D
@onready var _name_card := $NameCard as MeshInstance3D
@onready var _name_label := ($NameCard/Label as MeshInstance3D).mesh as TextMesh
## The song was played to the end, so Main Menu (pick the next song) is the main action; after a fail it is Retry.
var _finished := false
var _card_material: ShaderMaterial

## Paints the panel and the percent ring in the menu colours and starts with the buttons off.
func _ready() -> void:
	# the grade in the HUD's grade font (owner, 2026-10-27)
	($GradeViewport/GradeLabel as RichTextLabel).add_theme_font_override(&"normal_font", Hud.GRADE_FONT)
	var panel := (mesh as QuadMesh).material as ShaderMaterial
	panel.set_shader_parameter(&"fill_color", Constants.UI_PANEL)
	panel.set_shader_parameter(&"border_color", Constants.UI_BORDER)
	(($PercentIndicator as PercentIndicator).material_override as ShaderMaterial).set_shader_parameter(&"color", Constants.UI_ACCENT)
	var icon := $PercentIndicator/Icon as Sprite3D
	icon.position = ICON_POSITION
	icon.pixel_size = ICON_PIXEL_SIZE
	_card_material = (_name_card.mesh as QuadMesh).material as ShaderMaterial
	_card_material.set_shader_parameter(&"fill_color", Constants.UI_SURFACE)
	_card_material.set_shader_parameter(&"border_color", Constants.UI_BORDER)
	_card_material.set_shader_parameter(&"hover_color", Constants.UI_SURFACE)
	_card_material.set_shader_parameter(&"hover_border_color", Constants.UI_ACCENT)
	(($NameCard/Label as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Constants.UI_TEXT
	# "Not you?" reads as a button on the card (owner, 2026-10-28): the board's darker fill and a border
	var change := ($ChangePlayer as UIRaycastButton).back_shader
	change.set_shader_parameter(&"fill_color", Constants.UI_PANEL)
	change.set_shader_parameter(&"border_color", Constants.UI_BORDER)
	_add_banner()
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
	_rank_up_player.stream = _make_ding(RANK_UP_HZ)
	_rank_up_player.bus = &"UI"
	add_child(_rank_up_player)

## Builds the headline bar and its word, and the line that says how far a failed song got.
func _add_banner() -> void:
	var bar := QuadMesh.new()
	bar.size = BANNER_SIZE
	_banner_material.shader = (mesh as QuadMesh).material.shader
	_banner_material.set_shader_parameter(&"size", BANNER_SIZE)
	_banner_material.set_shader_parameter(&"corner_radius", BANNER_CORNER)
	_banner_material.set_shader_parameter(&"border_width", 0.0)
	bar.material = _banner_material
	var banner := MeshInstance3D.new()
	banner.mesh = bar
	banner.position = Vector3(0.0, BANNER_Y, 0.008)
	add_child(banner)
	_banner_text.font = Hud.GRADE_FONT
	_banner_text.font_size = LABEL_FONT_SIZE
	_banner_text.pixel_size = BANNER_TEXT_HEIGHT * Hud.GRADE_FONT_SCALE / LABEL_FONT_SIZE
	_banner_text.depth = 0.0
	_banner_text_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_banner_text.material = _banner_text_material
	var word := MeshInstance3D.new()
	word.mesh = _banner_text
	word.position = Vector3(0.0, BANNER_Y, 0.012)
	add_child(word)
	# the score and record in the numbers' font (Hud.NUMBER_FONT); the progress line ("Failed at 1:42") with them
	var details := ($Details as MeshInstance3D).mesh as TextMesh
	# Kanit's lines run taller than Roboto's: kept at the old size and line height ("Record" ran under the name card)
	details.line_spacing = int(details.font.get_height(details.font_size) - Hud.NUMBER_FONT.get_height(details.font_size))
	details.font = Hud.NUMBER_FONT
	_progress_text.font = details.font
	_progress_text.font_size = LABEL_FONT_SIZE
	_progress_text.pixel_size = PROGRESS_TEXT_HEIGHT / LABEL_FONT_SIZE
	_progress_text.depth = 0.0
	var progress_material := StandardMaterial3D.new()
	progress_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	progress_material.albedo_color = Constants.UI_TEXT
	_progress_text.material = progress_material
	_progress.mesh = _progress_text
	_progress.position = Vector3(0.0, PROGRESS_Y, 0.012)
	add_child(_progress)

## Sets the headline for a fail or a clear at `percent` accuracy, and after a fail how far the song got.
func _show_result(percent: float, failed_at: float, song_length: float) -> void:
	var failed := percent < 0
	var bar_color: Color = Constants.DANGER_COLOR if failed else Constants.RANK_COLORS.get(grade(percent), Constants.UI_TEXT)
	_banner_material.set_shader_parameter(&"fill_color", bar_color)
	_banner_material.set_shader_parameter(&"border_color", bar_color)
	_banner_text.text = FAILED_TEXT if failed else CLEARED_TEXT
	_banner_text_material.albedo_color = Color.WHITE if failed else Constants.UI_PANEL
	($PercentIndicator as Node3D).visible = not failed
	($RankHalo as Node3D).visible = not failed
	_progress.visible = failed
	_progress_text.text = "Failed at %s\nof %s" % [Hud._clock(int(failed_at)), Hud._clock(int(song_length))]

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
	($Practice as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	($MainMenu as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	($ChangePlayer as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	show()

func _hide() -> void:
	raycast_area.collision_layer = 0
	collision.disabled = true
	($Repeat as UIRaycastButton).collision_layer = 0
	($Practice as UIRaycastButton).collision_layer = 0
	($MainMenu as UIRaycastButton).collision_layer = 0
	($ChangePlayer as UIRaycastButton).collision_layer = 0
	_tick_player.stop()
	_ding_player.stop()
	_ding_high_player.stop()
	_rank_up_player.stop()
	hide()

func show_score(score: int, record: int, percent: float, song_string: String, is_full_combo: bool, is_new_record: bool,
		failed_at := 0.0, song_length := 0.0) -> void:
	_show_result(percent, failed_at, song_length)
	var details_mesh := ($Details as MeshInstance3D).mesh as TextMesh
	var details_material := ($Details as MeshInstance3D).material_override as StandardMaterial3D
	var percent_indicator := $PercentIndicator as PercentIndicator
	var grade_label := $GradeViewport/GradeLabel as RichTextLabel
	var fc_label := $FCViewport/FCLabel as RichTextLabel
	var nr_label := $NRViewport/NRLabel as RichTextLabel
	var name_label := ($NameLabel as MeshInstance3D).mesh as TextMesh
	
	details_material.albedo_color = Color.TRANSPARENT
	# the count-up starts from nothing: animated_percent still held the last song's accuracy until the tween's first
	# step, so the first frames showed its rank (SS) and a score counted past this one's (owner, 2026-10-25)
	animated_percent = 0.0
	# the rank, Full Combo and New Record letters live in small viewports whose pictures still hold the last song's
	# until they render again: hidden until they have, so no frame shows the old rank (owner, 2026-10-25)
	grade_label.text = ""
	_reveal_marks()
	grade_label.modulate = Color.TRANSPARENT
	fc_label.modulate = Color.TRANSPARENT
	nr_label.modulate = Color.TRANSPARENT
	percent_indicator.endscore()
	var ring_material := percent_indicator.material_override as ShaderMaterial
	var halo_material := ($RankHalo as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
	var ring_color := Constants.UI_TEXT_MUTED
	ring_material.set_shader_parameter(&"color", ring_color)
	ring_material.set_shader_parameter(&"sparkle", 0.0)
	halo_material.set_shader_parameter(&"strength", 0.0)
	percent_indicator.scale = Vector3.ONE
	var shown_rank := ""
	fc_label.visible = is_full_combo
	nr_label.visible = is_new_record
	var lines := song_string.split("\n")
	for i in lines.size():
		lines[i] = _fit(($NameLabel as MeshInstance3D).mesh as TextMesh, lines[i], NAME_WIDTHS[mini(i, NAME_WIDTHS.size() - 1)])
	name_label.text = "\n".join(lines)
	details_mesh.text = "Score\n%s\n\nRecord\n%s" % [Hud._grouped(score), Hud._grouped(record)]
	# after a fail, trying again is the likely next step
	var repeat_button := $Repeat as UIRaycastButton
	repeat_button.text = "Retry" if percent < 0 else "Repeat"
	repeat_button.set_primary(percent < 0)
	# after a fail, practising the part that failed sits beside Retry
	var practice_button := $Practice as UIRaycastButton
	practice_button.visible = percent < 0
	var xs: Array = TWO_BUTTONS_X if percent >= 0 else THREE_BUTTONS_X.slice(1)
	practice_button.position.x = THREE_BUTTONS_X[0]
	repeat_button.position.x = xs[0]
	($MainMenu as UIRaycastButton).position.x = xs[1]
	_finished = percent >= 0
	($MainMenu as UIRaycastButton).set_primary(_finished)
	
	
	var tw: Tween
	if percent >= 0:
		# the game shows this panel right after calling show_score, so wait for that before counting
		await get_tree().process_frame
		# the score counts up with the ring, ticking like a counter, and dings when it lands
		create_tween().tween_property(details_material,^"albedo_color",Constants.UI_TEXT,0.5).from(Color.TRANSPARENT)
		tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self,^"animated_percent",percent,3.0).from(0.0)
		tw.play()
		var shown_score := -1
		var last_tick := -TICK_MIN_INTERVAL
		while tw.is_running() and is_visible_in_tree():
			var progress := animated_percent / percent if percent > 0.0 else 1.0
			percent_indicator.update_percent(animated_percent)
			var rank := grade(animated_percent)
			if rank != "F" and rank != shown_rank:
				shown_rank = rank
				_show_rank(grade_label, rank)
				_rank_up_player.play()
			var target := Constants.RANK_COLORS[shown_rank] as Color if shown_rank != "" else Constants.UI_TEXT_MUTED
			ring_color = ring_color.lerp(target, minf(1.0, get_process_delta_time() * RING_COLOR_SPEED))
			ring_material.set_shader_parameter(&"color", ring_color)
			var counted := int(score * progress)
			var now := Time.get_ticks_msec() / 1000.0
			if counted != shown_score and now - last_tick >= TICK_MIN_INTERVAL:
				shown_score = counted
				last_tick = now
				details_mesh.text = "Score\n%s\n\nRecord\n%s" % [Hud._grouped(counted), Hud._grouped(record)]
				_tick_player.pitch_scale = lerpf(TICK_PITCH_FROM, TICK_PITCH_TO, progress)
				_tick_player.play()
			await get_tree().process_frame
		#_on_Tween_tween_completed()
		
		percent_indicator.update_percent(animated_percent)
		details_mesh.text = "Score\n%s\n\nRecord\n%s" % [Hud._grouped(score), Hud._grouped(record)]
		var final_rank := grade(percent)
		if final_rank != shown_rank:
			_show_rank(grade_label, final_rank)
		var final_color := Constants.RANK_COLORS[final_rank] as Color
		ring_material.set_shader_parameter(&"color", final_color)
		halo_material.set_shader_parameter(&"color", final_color)
		halo_material.set_shader_parameter(&"how_full", percent)
		var glow := create_tween()
		glow.tween_property(halo_material, ^"shader_parameter/strength", HALO_PEAK, PULSE_SECONDS).from(0.0)
		glow.tween_property(halo_material, ^"shader_parameter/strength", HALO_REST, PULSE_SECONDS)
		var pulse := create_tween().set_trans(Tween.TRANS_SINE)
		pulse.tween_property(percent_indicator, ^"scale", Vector3.ONE * PULSE_SCALE, PULSE_SECONDS)
		pulse.tween_property(percent_indicator, ^"scale", Vector3.ONE, PULSE_SECONDS)
		if final_rank == GRADES[0][1]:
			ring_material.set_shader_parameter(&"sparkle", TOP_RANK_SPARKLE)
		if is_visible_in_tree():
			_ding_player.play()
			glow_name_card()
			if is_new_record or is_full_combo:
				await get_tree().create_timer(DING_HIGH_DELAY).timeout
				_ding_high_player.play()
	else:
		create_tween().tween_property(details_material,^"albedo_color",Constants.UI_TEXT,2).from(Color.TRANSPARENT)
		_set_rank_text(grade_label, "F")
		glow_name_card()

	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_parallel()
	if grade_label.modulate.a < 0.5:
		tw.tween_property(grade_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(fc_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(nr_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.play()

## Hides the rank, Full Combo and New Record pictures until their viewports have drawn this song's text.
func _reveal_marks() -> void:
	var marks: Array[MeshInstance3D] = [$GradeMesh, $FCMesh, $NRMesh]
	for mark in marks:
		mark.visible = false
	# drawn once this frame (they may have been off while the screen was hidden), then shown
	for viewport: SubViewport in [$GradeViewport, $FCViewport, $NRViewport]:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for mark in marks:
		mark.visible = true
	for viewport: SubViewport in [$GradeViewport, $FCViewport, $NRViewport]:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE

## The rank for an accuracy, with Beat Saber's thresholds (SS 90%, S 80%, A 65%, B 50%, C 35%, D 20%); below that,
## or after a fail, F.
## The grade for an accuracy (0..1), as on the score screen; the HUD shows it live too.
static func grade(percent: float) -> String:
	for rank: Array in GRADES:
		if percent >= rank[0]:
			return rank[1]
	return "F"

func _set_rank_text(label: RichTextLabel, rank: String) -> void:
	label.text = "[center]%s" % rank
	label.add_theme_color_override(&"default_color", Constants.RANK_COLORS[rank])

## Puts a new rank letter up with a quick pop.
func _show_rank(label: RichTextLabel, rank: String) -> void:
	_set_rank_text(label, rank)
	label.modulate = Color.WHITE
	var grade_mesh := $GradeMesh as Node3D
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(grade_mesh, ^"scale", Vector3.ONE, RANK_POP_SECONDS).from(Vector3.ONE * RANK_POP_SCALE)

func set_buttons_disabled(disabled: bool) -> void:
	($Repeat/Collision as CollisionShape3D).disabled = disabled
	($Practice/Collision as CollisionShape3D).disabled = disabled
	($MainMenu/Collision as CollisionShape3D).disabled = disabled
	($ChangePlayer/Collision as CollisionShape3D).disabled = disabled

## Shows a line on the name card, with "Not you?" at its end when `can_change` (a record this run just saved).
func show_name_card(text: String, can_change := false) -> void:
	_name_card.visible = true
	($ChangePlayer as UIRaycastButton).visible = can_change
	# one line: the card is one line tall
	_name_label.text = _fit(_name_label, text.replace("\n", "  ·  "),
			CARD_TEXT_WIDTH - (CARD_BUTTON_ROOM if can_change else 0.0))
	($MainMenu as UIRaycastButton).set_primary(_finished)

func hide_name_card() -> void:
	_name_card.visible = false
	($ChangePlayer as UIRaycastButton).visible = false

## Lights the name card's border once.
func glow_name_card() -> void:
	if _name_card.visible:
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN) \
			.tween_property(_card_material, ^"shader_parameter/highlight", 0.0, CARD_GLOW_SECONDS).from(1.0)

func _on_ChangePlayer_button_up() -> void:
	change_player.emit()

func _on_Repeat_button_up() -> void:
	repeat.emit()

func _on_Practice_button_up() -> void:
	practice_part.emit()

func _on_MainMenu_button_up() -> void:
	set_buttons_disabled(true)
	mainmenu.emit()

## `text` cut to fit `width` metres in `mesh`'s font, ending in "…" when cut.
static func _fit(mesh: TextMesh, text: String, width: float) -> String:
	var font := mesh.font
	var size := mesh.font_size
	var fits := func(t: String) -> bool:
		return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * mesh.pixel_size <= width
	if fits.call(text):
		return text
	var cut := text.length()
	while cut > 1 and not fits.call(text.substr(0, cut).strip_edges() + "…"):
		cut -= 1
	return text.substr(0, cut).strip_edges() + "…"
