extends Panel
class_name PracticePanel
## The practice panel beside the player (owner, 2026-10-30): where the song is on a timeline that can be dragged to any
## point (stopped or while playing), the speed (changed only while stopped), Play/Pause and Exit. The game
## (BeepSaber_Game) runs the song and places the panel; this one only shows the state and passes the presses on.

signal play_pressed
signal pause_pressed
signal exit_pressed
## The timeline was grabbed (pointer press or a drag starting).
signal scrub_started
## The timeline was let go at `seconds` of the song.
signal scrub_ended(seconds: float)
signal speed_changed(percent: int)

const PLAY_ICON := preload("res://game/ui/icons/play.svg")
const PAUSE_ICON := preload("res://game/ui/icons/pause.svg")
## One line under the timeline saying what dragging does now (help in place).
const HINT_STOPPED := "Drag to where you want to play from."
const HINT_PLAYING := "Drag to jump. Pause to change the speed."
## Fine steps, so the thumbstick moves the timeline smoothly (BeepSaber_Game._practice_stick).
const TIMELINE_STEP_SECONDS := 0.01

@onready var _time := $Rows/Time as Label
@onready var _timeline := $Rows/Timeline as HSlider
@onready var _hint := $Rows/Hint as Label
@onready var _slower := $Rows/SpeedRow/Slower_Button as Button
@onready var _speed := $Rows/SpeedRow/Speed as Label
@onready var _faster := $Rows/SpeedRow/Faster_Button as Button
@onready var _play := $Rows/Buttons/PlayPause_Button as Button
@onready var _exit := $Rows/Buttons/Exit_Button as Button

var _playing := false
var _dragging := false
var _speed_percent := 100

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	_timeline.step = TIMELINE_STEP_SECONDS
	_timeline.drag_started.connect(func() -> void:
		_dragging = true
		scrub_started.emit())
	_timeline.drag_ended.connect(func(_changed: bool) -> void:
		_dragging = false
		scrub_ended.emit(_timeline.value))
	_timeline.value_changed.connect(_on_timeline_changed)
	_slower.pressed.connect(_step_speed.bind(-1))
	_faster.pressed.connect(_step_speed.bind(1))
	_play.pressed.connect(func() -> void:
		if _playing:
			pause_pressed.emit()
		else:
			play_pressed.emit())
	_exit.pressed.connect(exit_pressed.emit)

## Shows the song at `seconds` of `length`, playing or stopped, at `speed` percent; the speed can change only while
## stopped.
func show_state(playing: bool, seconds: float, length: float, speed: int) -> void:
	_playing = playing
	_timeline.max_value = length
	if not _dragging:
		_timeline.set_value_no_signal(seconds)
	_speed_percent = speed
	_speed.text = "%d%%" % speed
	_slower.disabled = playing or speed <= Constants.PRACTICE_SPEED_MIN
	_faster.disabled = playing or speed >= Constants.PRACTICE_SPEED_MAX
	_play.icon = PAUSE_ICON if playing else PLAY_ICON
	_play.text = "Pause" if playing else "Play"
	_hint.text = HINT_PLAYING if playing else HINT_STOPPED
	_show_time()

## Moves the timeline with the playing song (never under a drag).
func show_time(seconds: float) -> void:
	if _dragging:
		return
	_timeline.set_value_no_signal(seconds)
	_show_time()

## Moves the timeline `by` song seconds (the thumbstick), within the song.
func nudge(by: float) -> void:
	_timeline.set_value_no_signal(_timeline.value + by)
	_show_time()

## Where the timeline is, in song seconds.
func seconds() -> float:
	return _timeline.value

## "1:24 of 2:55"
func _show_time() -> void:
	_time.text = "%s of %s" % [Hud._clock(int(_timeline.value)), Hud._clock(int(_timeline.max_value))]

## A drag moves the time shown; a press on the track without a drag jumps there at once.
func _on_timeline_changed(value: float) -> void:
	_show_time()
	if not _dragging:
		scrub_started.emit()
		scrub_ended.emit(value)

## One speed step slower (-1) or faster (1), within Constants.PRACTICE_SPEED_*.
func _step_speed(sign: int) -> void:
	speed_changed.emit(clampi(_speed_percent + sign * Constants.PRACTICE_SPEED_STEP, Constants.PRACTICE_SPEED_MIN,
			Constants.PRACTICE_SPEED_MAX))
