extends Panel
class_name PausePanel

signal continue_button()
signal restart_button()
signal mainmenu_button()

## How often the clock in the top left corner (the time of day, as above the song menu: MenuClock) is read.
const CLOCK_SECONDS := 1.0
## 32 px at the panel's scale (1.87 / 1024 m a pixel, about 1.76 m from the eye): 1.9 degrees, above the 1.85 floor.
const CLOCK_FONT_SIZE := 32

@onready var _clock := $Clock as Label
var _since_clock := CLOCK_SECONDS

func _ready():
	UI_AudioEngine.attach_children(self)
	_clock.add_theme_font_override(&"font", Hud.NUMBER_FONT)
	_clock.add_theme_color_override(&"font_color", Constants.UI_TEXT_MUTED)
	_clock.add_theme_font_size_override(&"font_size", CLOCK_FONT_SIZE)

## Keeps the clock current while the panel shows.
func _process(delta: float) -> void:
	_since_clock += delta
	if _since_clock < CLOCK_SECONDS or not is_visible_in_tree():
		return
	_since_clock = 0.0
	_clock.text = MenuClock.now_text()

func set_pause_text(song_name,dificulty=""):
	$Label.text = "Current song:\n%s\n%s" % [song_name,dificulty]

func _on_continue_button_up():
	emit_signal("continue_button")

func _on_restart_button_up():
	emit_signal("restart_button")

func _on_mainmenu_button_up():
	emit_signal("mainmenu_button")
