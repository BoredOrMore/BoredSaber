extends Label3D
class_name MenuClock
## The time of day ("14:05", 24-hour, owner 2026-10-29) above the song menu centre panel's top left corner, opposite
## the warning icon, so the player knows the time without taking the headset off. Shown with the song menu only, like
## the warning icon; the Pause panel shows the same time (PausePanel). Muted: it's information, not an action.

## Above the centre panel's top left corner, level with the warning icon (22 degrees up) and mirroring it (21 degrees
## left), on the menus' 2 m curve, facing the player.
const CLOCK_POSITION := Vector3(-0.7297, 2.4125, -0.8622)
## The song menu's 28 px text at its scale (2.4 / 1024 m a pixel): 0.066 m, 1.9 degrees at 2 m, above the 1.85 floor.
const TEXT_SIZE := 66
const TEXT_PIXEL := 0.001
const CHECK_SECONDS := 1.0

var game: BeepSaber_Game
var _since_check := CHECK_SECONDS

func _ready() -> void:
	# facing the player: turned away from the menus' curve axis, through the eye
	look_at_from_position(CLOCK_POSITION, 2.0 * CLOCK_POSITION - Vector3(0.0, CLOCK_POSITION.y, Hud.HUD_EYE.z),
		Vector3.UP)
	font = Hud.NUMBER_FONT
	font_size = TEXT_SIZE
	pixel_size = TEXT_PIXEL
	outline_size = 0
	modulate = Constants.UI_TEXT_MUTED
	visible = false

func _process(delta: float) -> void:
	if game == null:
		return
	_since_check += delta
	if _since_check < CHECK_SECONDS:
		return
	_since_check = 0.0
	visible = game.main_menu.visible and game.gamestate == game.gamestate_mapselection
	if visible:
		text = now_text()

## The device's local time of day as "HH:MM", 24-hour.
static func now_text() -> String:
	var now := Time.get_time_dict_from_system()
	return "%02d:%02d" % [now.hour, now.minute]
