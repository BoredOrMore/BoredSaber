extends UIRaycastTarget
class_name WarningIcon
## A red "!" right of the song menu, about level with its Damage row, shown only while something may hurt the player
## or the headset; pointing the laser at it opens a card listing those warnings in plain words. Warnings: the play
## area (the guardian) too small for the saber's reach or the Slash to play note (where the runtime gives it: Pico
## doesn't, and an unknown play area isn't warned about); a low battery; a hot
## headset; 30 minutes of songs this session; Full resolution lowered to Sharp after stuttering. It only warns: it
## never changes anything. Checked every CHECK_SECONDS while the song menu shows.

## In the song menu centre panel's top right corner, at the end of its top bar (22 degrees right, 18 up, 2 cm in front of
## the curved panel), facing the player.
const ICON_POSITION := Vector3(0.746, 2.239, -0.834)
## 0.14 m at about 2.07 m: about 4 degrees, above the 3 degree minimum target (vr-ui-design).
const ICON_SIZE := 0.14
## Round corners, as the menus' (owner, 2026-10-28): the card's like a panel's 24 px, the icon's like a chip's 14 px,
## at the menus' scale (2.4/1024 m per px); RoundedQuad cuts them without blending.
const CARD_CORNER := 0.056
const ICON_CORNER := 0.033
const ROUNDED_QUAD := preload("res://game/ui/RoundedQuad.gdshader")
const CARD_WIDTH := 0.95
const CARD_PADDING := 0.04
## Text 60 px at 0.001 m a pixel: the song menu's 28 px body text at its scale (2.4 / 1024 m a pixel).
const TEXT_SIZE := 60
const TEXT_PIXEL := 0.001
const CHECK_SECONDS := 2.0

## Saber reach around the player's head, in metres (arm and saber), and how close to the guardian it may come.
const REACH := 0.9
const LOW_BATTERY_PERCENT := 15
## Android's PowerManager thermal status: 2 moderate, 3 severe (the system starts slowing the device down).
const HOT_THERMAL_STATUS := 2
const BREAK_SECONDS := 30 * 60

const PLAY_AREA_SMALL_TEXT := "Play area: your saber's reach (%.1f m around you) or the Slash to play note goes past your guardian. Make room before you swing."
const BATTERY_TEXT := "Battery %d%%: charge soon, the headset may switch off mid-song."
const HOT_TEXT := "The headset is hot: it may slow down and stutter. Take a break, or try Graphics: Low."
const BREAK_TEXT := "You've played 30 min, take a short break."
const LOWERED_TEXT := "Lowered to Sharp to stay smooth: Full resolution stuttered in a song."

var game: BeepSaber_Game
var _icon := MeshInstance3D.new()
var _icon_material := ShaderMaterial.new()
var _card := Node3D.new()
var _card_back := MeshInstance3D.new()
var _card_text := Label3D.new()
## A double tick from the icon's place when it appears, so it's noticed without looking for it.
var _sound := AudioStreamPlayer3D.new()
var _messages := PackedStringArray()
var _since_check := CHECK_SECONDS
## Logged once each: what the device didn't let the game read.
var _unreadable := {}
## The guardian, read once and again after a recenter (asking every check logs an engine warning when there is none).
var _play_area := PackedVector3Array()
var _play_area_read := false

func _ready() -> void:
	# facing the player at the middle of the play space
	look_at_from_position(ICON_POSITION, 2.0 * ICON_POSITION - Vector3(0.0, ICON_POSITION.y, 0.0), Vector3.UP)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ICON_SIZE
	_icon.mesh = quad
	_icon_material.shader = ROUNDED_QUAD
	_icon_material.set_shader_parameter(&"color", Constants.UI_DANGER)
	_icon_material.set_shader_parameter(&"size", quad.size)
	_icon_material.set_shader_parameter(&"radius", ICON_CORNER)
	_icon.material_override = _icon_material
	add_child(_icon)
	var mark := _label("!", TEXT_SIZE * 2)
	mark.modulate = Constants.UI_PANEL
	mark.position.z = 0.002
	add_child(mark)
	# the laser hits exactly the red square
	var shape := BoxShape3D.new()
	shape.size = Vector3(ICON_SIZE, ICON_SIZE, 0.01)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	collision_layer = CollisionLayerConstants.Ui_mask
	collision_mask = 0

	# the card: under the icon, reaching left, over the song list
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.width = (CARD_WIDTH - 2.0 * CARD_PADDING) / TEXT_PIXEL
	_card_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card_text.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_card_text.font_size = TEXT_SIZE
	_card_text.pixel_size = TEXT_PIXEL
	_card_text.modulate = Constants.UI_TEXT
	_card_text.outline_size = 0
	# a wrapped, left-aligned Label3D starts its lines at its position
	_card_text.position = Vector3(CARD_PADDING, CARD_PADDING, 0.002)
	_card.add_child(_card_text)
	var back_material := ShaderMaterial.new()
	back_material.shader = ROUNDED_QUAD
	back_material.set_shader_parameter(&"color", Constants.UI_PANEL)
	back_material.set_shader_parameter(&"radius", CARD_CORNER)
	_card_back.mesh = QuadMesh.new()
	_card_back.material_override = back_material
	_card.add_child(_card_back)
	_card.position = Vector3(ICON_SIZE / 2.0 - CARD_WIDTH, 0.0, 0.01)
	_card.visible = false
	add_child(_card)
	_sound.stream = preload("res://game/data/warning.wav")
	_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_sound.bus = &"UI"
	add_child(_sound)
	visible = false
	vr.pose_recentered.connect(func() -> void: _play_area_read = false)

## A centred label of the given size.
func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = TEXT_PIXEL
	label.outline_size = 0
	return label

func _process(delta: float) -> void:
	if game == null:
		return
	_since_check += delta
	if _since_check < CHECK_SECONDS:
		return
	_since_check = 0.0
	_messages = messages()
	var was_visible := visible
	visible = not _messages.is_empty() and game.main_menu.visible and game.gamestate == game.gamestate_mapselection
	if visible and not was_visible:
		_sound.play()
	collision_layer = CollisionLayerConstants.Ui_mask if visible else 0
	if not visible:
		_card.visible = false
	_show_card_text()

## Every warning that applies now, in plain words.
func messages() -> PackedStringArray:
	var out := PackedStringArray()
	var play_area := _play_area_warning()
	if not play_area.is_empty():
		out.append(play_area)
	var battery := _battery_percent()
	if battery >= 0 and battery < LOW_BATTERY_PERCENT:
		out.append(BATTERY_TEXT % battery)
	if _thermal_status() >= HOT_THERMAL_STATUS:
		out.append(HOT_TEXT)
	if game.played_seconds >= BREAK_SECONDS:
		out.append(BREAK_TEXT)
	if not Settings.resolution_cap.is_empty():
		out.append(LOWERED_TEXT)
	return out

## The play area warning, or "": the guardian (OpenXR play area, on the floor around the origin) must hold the
## saber's reach around the head and the Slash to play note.
func _play_area_warning() -> String:
	var xr := XRServer.primary_interface
	if xr == null or not xr.is_initialized():
		return ""
	if not _play_area_read:
		_play_area_read = true
		_play_area = xr.get_play_area()
	var area := _play_area
	if area.size() < 3:
		_log_unreadable("play area", "the runtime gave none (%d points, mode %d): not warning" % [area.size(), xr.get_play_area_mode()])
		return ""
	var polygon := PackedVector2Array()
	for point in area:
		polygon.append(Vector2(point.x, point.z))
	var head := game.xr_origin.to_local(vr.vrCamera.global_position) if vr.vrCamera else Vector3.ZERO
	var at := Vector2(head.x, head.z)
	var note := game.xr_origin.to_local(game.slash_block.global_position)
	if not Geometry2D.is_point_in_polygon(at, polygon) or _distance_to_edge(at, polygon) < REACH \
			or (game.slash_block._shown and not Geometry2D.is_point_in_polygon(Vector2(note.x, note.z), polygon)):
		return PLAY_AREA_SMALL_TEXT % REACH
	return ""

static func _distance_to_edge(at: Vector2, polygon: PackedVector2Array) -> float:
	var nearest := INF
	for i in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(at, polygon[i], polygon[(i + 1) % polygon.size()])
		nearest = minf(nearest, at.distance_to(closest))
	return nearest

## Battery charge in percent from Android's BatteryManager, or -1 where it can't be read.
func _battery_percent() -> int:
	var activity: Variant = _android_activity()
	if activity == null:
		return -1
	var manager: Variant = activity.getSystemService("batterymanager")
	# BatteryManager.BATTERY_PROPERTY_CAPACITY
	var percent: Variant = manager.getIntProperty(4) if manager != null else null
	if not percent is int or percent < 0:
		_log_unreadable("battery", "BatteryManager gave %s" % [percent])
		return -1
	return percent

## Android's PowerManager.getCurrentThermalStatus() (0 none .. 6 shutdown), or -1 where it can't be read.
func _thermal_status() -> int:
	var activity: Variant = _android_activity()
	if activity == null:
		return -1
	var power: Variant = activity.getSystemService("power")
	var status: Variant = power.getCurrentThermalStatus() if power != null else null
	if not status is int:
		_log_unreadable("thermal", "PowerManager gave %s" % [status])
		return -1
	return status

## The Android activity (Godot's AndroidRuntime), or null off Android.
func _android_activity() -> Variant:
	if not Engine.has_singleton("AndroidRuntime"):
		return null
	return Engine.get_singleton("AndroidRuntime").getActivity()

func _log_unreadable(what: String, why: String) -> void:
	if not _unreadable.has(what):
		_unreadable[what] = true
		print("Warnings: can't read %s: %s" % [what, why])

## The card shows while the laser is on the icon.
func ui_raycast_hit_event(_pos: Vector3, _click: bool, _release: bool) -> void:
	if not _card.visible:
		_card.visible = true
		_icon_material.set_shader_parameter(&"color", Constants.UI_DANGER.lightened(0.2))
		_show_card_text()

func ui_raycast_exit() -> void:
	_card.visible = false
	_icon_material.set_shader_parameter(&"color", Constants.UI_DANGER)

## Fills the card with the warnings, a bullet each, and sizes its panel to the text.
func _show_card_text() -> void:
	_card_text.text = "\n".join(Array(_messages).map(func(message: String) -> String: return "• " + message))
	var font := _card_text.font if _card_text.font else ThemeDB.fallback_font
	var lines := font.get_multiline_string_size(_card_text.text, HORIZONTAL_ALIGNMENT_LEFT, _card_text.width, TEXT_SIZE,
			-1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND)
	var height := lines.y * TEXT_PIXEL + 2.0 * CARD_PADDING
	(_card_back.mesh as QuadMesh).size = Vector2(CARD_WIDTH, height)
	(_card_back.material_override as ShaderMaterial).set_shader_parameter(&"size", Vector2(CARD_WIDTH, height))
	_card_back.position = Vector3(CARD_WIDTH / 2.0, height / 2.0, 0.0)
	_card.position.y = -ICON_SIZE / 2.0 - 0.02 - height
