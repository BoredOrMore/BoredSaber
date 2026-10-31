extends Control
class_name PracticeTimeline
## The practice panel's one bar (owner, 2026-10-30): the song with its playhead (a round knob on the bar, dragged to jump),
## the start point (a triangle pointing on, hung under the bar) and, with Repeat on, the end point (a square); the part
## between them is lit. A press on the bar takes the playhead, a press under it the nearer marker. Shape and each
## marker's own label ("Start 1:24", "End 1:50"; owner, 2026-10-30) tell the three apart, never colour alone; the note
## colours stay off the UI.

## The playhead was grabbed (a press on the bar).
signal scrub_started
## The playhead was let go at `seconds`.
signal scrub_ended(seconds: float)
## The start or end marker was let go at `seconds`.
signal start_set(seconds: float)
signal end_set(seconds: float)

## The bar's band (pressing there takes the playhead) and the markers' band under it, in px: 52 px is 3.5 degrees at
## the panel's 1.3 m and scale 1.6, past vr-ui-design's 2.5-3 degree targets.
const BAR_BAND := 52.0
## The markers' band holds the shape and its label under it.
const MARKER_BAND := 88.0
const TRACK_HEIGHT := 12.0
const PLAYHEAD_RADIUS := 14.0
const MARKER_SIZE := 30.0
## Room at both ends so the knob and the markers stay whole at 0:00 and at the end.
const SIDE_ROOM := 18.0
## The markers' labels: the theme's 28 px (1.9 degrees at the panel's distance and scale), under the shapes; the start's
## ends at its marker, the end's begins at its marker, so they never cover each other.
const LABEL_SIZE := 28
const LABEL_GAP := 8.0

enum Grab { NONE, PLAYHEAD, START, END }

var length := 1.0
var playhead := 0.0
var start := 0.0
## -1 while Repeat is off
var end := -1.0
var _grab := Grab.NONE

## The bar's size before any layout.
func _get_minimum_size() -> Vector2:
	return Vector2(0.0, BAR_BAND + MARKER_BAND)

## True while the playhead or a marker is held.
func grabbed() -> bool:
	return _grab != Grab.NONE

## Whether the playhead is held (code then leaves it alone).
func playhead_held() -> bool:
	return _grab == Grab.PLAYHEAD

## The x of `seconds` on the bar.
func _x(seconds: float) -> float:
	return SIDE_ROOM + (size.x - 2.0 * SIDE_ROOM) * clampf(seconds / maxf(length, 0.001), 0.0, 1.0)

## The song seconds at `x` on the bar.
func _seconds(x: float) -> float:
	return clampf((x - SIDE_ROOM) / maxf(size.x - 2.0 * SIDE_ROOM, 1.0), 0.0, 1.0) * length

func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press(button.position)
		elif _grab != Grab.NONE:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _grab != Grab.NONE:
		_move((event as InputEventMouseMotion).position.x)
		accept_event()

## A press on the bar takes the playhead; under it, the marker on that side of the middle between the two.
func _press(at: Vector2) -> void:
	if at.y < BAR_BAND:
		_grab = Grab.PLAYHEAD
		scrub_started.emit()
	elif end < 0.0 or at.x < (_x(start) + _x(end)) * 0.5:
		_grab = Grab.START
	else:
		_grab = Grab.END
	_move(at.x)

## Moves what is held to `x`.
func _move(x: float) -> void:
	match _grab:
		Grab.PLAYHEAD:
			playhead = _seconds(x)
		Grab.START:
			start = roundf(_seconds(x))
		Grab.END:
			end = roundf(_seconds(x))
	queue_redraw()

## Lets go of what is held.
func _release() -> void:
	var held := _grab
	_grab = Grab.NONE
	queue_redraw()
	match held:
		Grab.PLAYHEAD:
			scrub_ended.emit(playhead)
		Grab.START:
			start_set.emit(start)
		Grab.END:
			end_set.emit(end)

func _draw() -> void:
	var mid := BAR_BAND * 0.5
	var left := SIDE_ROOM
	var right := size.x - SIDE_ROOM
	var track := Rect2(left, mid - TRACK_HEIGHT * 0.5, right - left, TRACK_HEIGHT)
	draw_rect(track, Constants.UI_BORDER)
	if end >= 0.0:
		draw_rect(Rect2(_x(start), track.position.y, _x(end) - _x(start), TRACK_HEIGHT), Constants.UI_TEXT_MUTED)
	draw_rect(Rect2(left, mid - TRACK_HEIGHT * 0.25, _x(playhead) - left, TRACK_HEIGHT * 0.5), Constants.UI_ACCENT)
	var top := BAR_BAND + 6.0
	_draw_marker(_x(start), top, true, _grab == Grab.START)
	if end >= 0.0:
		_draw_marker(_x(end), top, false, _grab == Grab.END)
	_draw_labels(top + MARKER_SIZE + LABEL_GAP)
	draw_circle(Vector2(_x(playhead), mid), PLAYHEAD_RADIUS, Constants.UI_ACCENT if _grab == Grab.PLAYHEAD else Constants.UI_TEXT)

## "Start 1:24", or "End 1:50" (`is_start` false).
func label_text(is_start: bool) -> String:
	return "%s %s" % ["Start" if is_start else "End", Hud._clock(int(start if is_start else end))]

## Where the start's and end's labels go (the end's left out while Repeat is off): the start's ending at its marker and
## the end's beginning at its, each kept inside the bar, pushed apart when they'd meet.
func label_rects() -> Array[Rect2]:
	var font := get_theme_font(&"font", &"Label")
	var start_width := font.get_string_size(label_text(true), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
	var start_x := clampf(_x(start) - start_width, 0.0, size.x - start_width)
	var rects: Array[Rect2] = [Rect2(start_x, 0.0, start_width, LABEL_SIZE)]
	if end >= 0.0:
		var end_width := font.get_string_size(label_text(false), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var end_x := minf(maxf(_x(end), start_x + start_width + LABEL_GAP), size.x - end_width)
		# at the bar's right end the end's label can't go further right: the start's moves left of it instead
		rects[0].position.x = minf(start_x, end_x - LABEL_GAP - start_width)
		rects.append(Rect2(end_x, 0.0, end_width, LABEL_SIZE))
	return rects

## The markers' labels on the line whose top is at `line_top`, lit while their marker is held.
func _draw_labels(line_top: float) -> void:
	var font := get_theme_font(&"font", &"Label")
	var rects := label_rects()
	for i in rects.size():
		var held := _grab == (Grab.START if i == 0 else Grab.END)
		draw_string(font, Vector2(rects[i].position.x, line_top + font.get_ascent(LABEL_SIZE)), label_text(i == 0),
				HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Constants.UI_ACCENT if held else Constants.UI_TEXT)

## A marker hanging under the bar at `x`: a line up to the bar and a triangle pointing on (start) or a square (end),
## drawn, not font glyphs (vr-ui-design: Roboto lacks them); lit while held.
func _draw_marker(x: float, top: float, is_start: bool, held: bool) -> void:
	var color := Constants.UI_ACCENT if held else Constants.UI_TEXT
	draw_line(Vector2(x, BAR_BAND * 0.5), Vector2(x, top), color, 3.0)
	var half := MARKER_SIZE * 0.5
	if is_start:
		draw_colored_polygon(PackedVector2Array([Vector2(x - half * 0.6, top), Vector2(x + half, top + half),
				Vector2(x - half * 0.6, top + MARKER_SIZE)]), color)
	else:
		draw_rect(Rect2(x - half * 0.8, top, MARKER_SIZE * 0.8, MARKER_SIZE * 0.8), color)
