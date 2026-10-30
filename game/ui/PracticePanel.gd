extends Panel
class_name PracticePanel
## The practice panel beside the player (owner, 2026-10-30): where the song is on a playback timeline that follows it
## and can be dragged to any point (stopped or while playing), the start point on a slider of its own that stays where
## it was set (Restart and the song's end go back to it; owner, 2026-10-30), an end point behind a Repeat toggle (off:
## the whole song; on: the part from the start to the end plays again and again; owner, 2026-10-30), the speed
## (changed only while stopped),
## Play/Pause, Restart and Exit. The game (BeepSaber_Game) runs the song and places the panel; this one only shows the
## state and passes the presses on.

signal play_pressed
signal pause_pressed
signal restart_pressed
signal exit_pressed
## The playback timeline was grabbed (pointer press or a drag starting).
signal scrub_started
## The playback timeline was let go at `seconds` of the song.
signal scrub_ended(seconds: float)
## The start point was set to `seconds` of the song (let go, or pressed on its track).
signal start_set(seconds: float)
## The end point was set to `seconds` of the song, or turned off (-1).
signal end_set(seconds: float)
signal speed_changed(percent: int)

const PLAY_ICON := preload("res://game/ui/icons/play.svg")
const PAUSE_ICON := preload("res://game/ui/icons/pause.svg")
## One line under the timeline saying what dragging does now (help in place).
const HINT_STOPPED := "The start stays put; Restart goes back to it."
const HINT_PLAYING := "Drag to jump. Pause to change the speed."
## Fine steps, so the thumbstick moves the timeline smoothly (BeepSaber_Game._practice_stick).
const TIMELINE_STEP_SECONDS := 0.01
## The start and end points move in whole seconds.
const START_STEP_SECONDS := 1.0
## The shortest part Repeat plays, and how long a part it starts with when turned on (untuned).
const MIN_PART_SECONDS := 2.0
const NEW_PART_SECONDS := 10.0
const HINT_REPEAT := "Plays from Start to End, again and again."

@onready var _time := $Rows/Time as Label
@onready var _timeline := $Rows/Timeline as HSlider
@onready var _start_time := $Rows/StartTime as Label
@onready var _start := $Rows/Start as HSlider
@onready var _end_time := $Rows/EndRow/EndTime as Label
@onready var _repeat := $Rows/EndRow/Repeat as CheckButton
@onready var _end := $Rows/End as HSlider
@onready var _hint := $Rows/Hint as Label
@onready var _slower := $Rows/SpeedRow/Slower_Button as Button
@onready var _speed := $Rows/SpeedRow/Speed as Label
@onready var _faster := $Rows/SpeedRow/Faster_Button as Button
@onready var _play := $Rows/Buttons/PlayPause_Button as Button
@onready var _restart := $Rows/Buttons/Restart_Button as Button
@onready var _exit := $Rows/Buttons/Exit_Button as Button

var _playing := false
var _dragging := false
var _setting_start := false
var _setting_end := false
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
	_start.step = START_STEP_SECONDS
	_start.drag_started.connect(func() -> void: _setting_start = true)
	_start.drag_ended.connect(func(_changed: bool) -> void:
		_setting_start = false
		_set_start(_start.value))
	_start.value_changed.connect(func(value: float) -> void:
		_show_start()
		if not _setting_start:
			_set_start(value))
	_end.step = START_STEP_SECONDS
	_end.drag_started.connect(func() -> void: _setting_end = true)
	_end.drag_ended.connect(func(_changed: bool) -> void:
		_setting_end = false
		_set_end(_end.value))
	_end.value_changed.connect(func(value: float) -> void:
		_show_end()
		if not _setting_end:
			_set_end(value))
	_repeat.toggled.connect(func(on: bool) -> void:
		_set_end(_start.value + NEW_PART_SECONDS if on else -1.0))
	_restart.pressed.connect(restart_pressed.emit)
	_slower.pressed.connect(_step_speed.bind(-1))
	_faster.pressed.connect(_step_speed.bind(1))
	_play.pressed.connect(func() -> void:
		if _playing:
			pause_pressed.emit()
		else:
			play_pressed.emit())
	_exit.pressed.connect(exit_pressed.emit)

## Shows the song at `seconds` of `length` with its start point at `start` and its end point at `end` (-1: off, the
## whole song), playing or stopped, at `speed` percent; the speed can change only while stopped.
func show_state(playing: bool, seconds: float, start: float, end: float, length: float, speed: int) -> void:
	_playing = playing
	_timeline.max_value = length
	if not _dragging:
		_timeline.set_value_no_signal(seconds)
	_start.max_value = length
	if not _setting_start:
		_start.set_value_no_signal(start)
	_show_start()
	_end.max_value = length
	_repeat.set_pressed_no_signal(end >= 0.0)
	_end.editable = end >= 0.0
	if not _setting_end and end >= 0.0:
		_end.set_value_no_signal(end)
	_show_end()
	_speed_percent = speed
	_speed.text = "%d%%" % speed
	_slower.disabled = playing or speed <= Constants.PRACTICE_SPEED_MIN
	_faster.disabled = playing or speed >= Constants.PRACTICE_SPEED_MAX
	_play.icon = PAUSE_ICON if playing else PLAY_ICON
	_play.text = "Pause" if playing else "Play"
	_hint.text = HINT_PLAYING if playing else HINT_REPEAT if end >= 0.0 else HINT_STOPPED
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

## Where the playback timeline is, in song seconds.
func seconds() -> float:
	return _timeline.value

## The start point, in song seconds.
func start_seconds() -> float:
	return _start.value

## "Start 1:24"
func _show_start() -> void:
	_start_time.text = "Start %s" % Hud._clock(int(_start.value))

## "End 1:50", or "End: whole song" while Repeat is off.
func _show_end() -> void:
	_end_time.text = "End %s" % Hud._clock(int(_end.value)) if _repeat.button_pressed else "End: whole song"

## A new start point; with Repeat on, the end moves along when the part would get shorter than MIN_PART_SECONDS.
func _set_start(seconds: float) -> void:
	if _repeat.button_pressed and _end.value < seconds + MIN_PART_SECONDS:
		_set_end(seconds + MIN_PART_SECONDS)
	start_set.emit(seconds)

## A new end point (-1 turns Repeat off), never closer than MIN_PART_SECONDS after the start nor past the song.
func _set_end(seconds: float) -> void:
	if seconds >= 0.0:
		seconds = minf(maxf(seconds, _start.value + MIN_PART_SECONDS), _end.max_value)
		_end.set_value_no_signal(seconds)
	_end.editable = seconds >= 0.0
	_show_end()
	end_set.emit(seconds)

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
