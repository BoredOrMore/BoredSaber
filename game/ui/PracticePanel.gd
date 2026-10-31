extends Panel
class_name PracticePanel
## The practice panel beside the player (owner, 2026-10-30): one bar (PracticeTimeline) with the playhead, dragged to
## jump (stopped or while playing), the start point that stays where it was set (Restart and the song's end go back to
## it) and, with the Repeat toggle on, the end point (the part from the start to the end plays again and again); the
## speed (changed only while stopped), Play/Pause, Restart and Exit. The game (BeepSaber_Game) runs the song and places
## the panel; this one only shows the state and passes the presses on.

signal play_pressed
signal pause_pressed
signal restart_pressed
signal exit_pressed
## The playhead was grabbed (a press on the bar).
signal scrub_started
## The playhead was let go at `seconds` of the song.
signal scrub_ended(seconds: float)
## The start point was set to `seconds` of the song.
signal start_set(seconds: float)
## The end point was set to `seconds` of the song, or turned off (-1).
signal end_set(seconds: float)
signal speed_changed(percent: int)

const PLAY_ICON := preload("res://game/ui/icons/play.svg")
const PAUSE_ICON := preload("res://game/ui/icons/pause.svg")
## One line under the bar saying what to do now (help in place).
const HINT_STOPPED := "Drag under the bar to move the start."
const HINT_REPEAT := "Plays from Start to End, again and again."
const HINT_PLAYING := "Drag the bar to jump. Pause to change the speed."
## The shortest part Repeat plays, and how long a part it starts with when turned on (untuned).
const MIN_PART_SECONDS := 2.0
const NEW_PART_SECONDS := 10.0

@onready var _time := $Rows/TopRow/Time as Label
@onready var _repeat := $Rows/TopRow/Repeat as CheckButton
@onready var _bar := $Rows/Timeline as PracticeTimeline
@onready var _hint := $Rows/Hint as Label
@onready var _slower := $Rows/SpeedRow/Slower_Button as Button
@onready var _speed := $Rows/SpeedRow/Speed as Label
@onready var _faster := $Rows/SpeedRow/Faster_Button as Button
@onready var _play := $Rows/Buttons/PlayPause_Button as Button
@onready var _restart := $Rows/Buttons/Restart_Button as Button
@onready var _exit := $Rows/Buttons/Exit_Button as Button

var _playing := false
var _speed_percent := 100

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	_bar.scrub_started.connect(scrub_started.emit)
	_bar.scrub_ended.connect(func(seconds: float) -> void:
		_show_time()
		scrub_ended.emit(seconds))
	_bar.start_set.connect(_set_start)
	_bar.end_set.connect(_set_end)
	_repeat.toggled.connect(func(on: bool) -> void:
		_set_end(_bar.start + NEW_PART_SECONDS if on else -1.0))
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
	_bar.length = length
	if not _bar.grabbed():
		_bar.playhead = seconds
		_bar.start = start
		_bar.end = end
	_repeat.set_pressed_no_signal(end >= 0.0)
	_speed_percent = speed
	_speed.text = "%d%%" % speed
	_slower.disabled = playing or speed <= Constants.PRACTICE_SPEED_MIN
	_faster.disabled = playing or speed >= Constants.PRACTICE_SPEED_MAX
	_play.icon = PAUSE_ICON if playing else PLAY_ICON
	_play.text = "Pause" if playing else "Play"
	_hint.text = HINT_PLAYING if playing else HINT_REPEAT if end >= 0.0 else HINT_STOPPED
	_show_time()

## Moves the playhead with the playing song (never under a drag).
func show_time(seconds: float) -> void:
	if _bar.playhead_held():
		return
	_bar.playhead = seconds
	_show_time()

## Moves the playhead `by` song seconds (the thumbstick), within the song.
func nudge(by: float) -> void:
	_bar.playhead = clampf(_bar.playhead + by, 0.0, _bar.length)
	_show_time()

## Where the playhead is, in song seconds.
func seconds() -> float:
	return _bar.playhead

## The start point, in song seconds.
func start_seconds() -> float:
	return _bar.start

## "1:41 of 2:55" over the bar; the bar draws its markers' labels.
func _show_time() -> void:
	_time.text = "%s of %s" % [Hud._clock(int(_bar.playhead)), Hud._clock(int(_bar.length))]
	_bar.queue_redraw()

## A new start point; with Repeat on, the end moves along when the part would get shorter than MIN_PART_SECONDS.
func _set_start(seconds: float) -> void:
	_bar.start = seconds
	if _bar.end >= 0.0 and _bar.end < seconds + MIN_PART_SECONDS:
		_set_end(seconds + MIN_PART_SECONDS)
	_show_time()
	start_set.emit(seconds)

## A new end point (-1 turns Repeat off), never closer than MIN_PART_SECONDS after the start nor past the song.
func _set_end(seconds: float) -> void:
	if seconds >= 0.0:
		seconds = minf(maxf(seconds, _bar.start + MIN_PART_SECONDS), _bar.length)
	_bar.end = seconds
	_repeat.set_pressed_no_signal(seconds >= 0.0)
	_show_time()
	end_set.emit(seconds)

## One speed step slower (-1) or faster (1), within Constants.PRACTICE_SPEED_*.
func _step_speed(sign: int) -> void:
	speed_changed.emit(clampi(_speed_percent + sign * Constants.PRACTICE_SPEED_STEP, Constants.PRACTICE_SPEED_MIN,
			Constants.PRACTICE_SPEED_MAX))
