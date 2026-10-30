extends Node

@export var scroll_node_path: NodePath
## Scroll with the thumbstick even when no pointer is over the list (for the screen's main list).
@export var scroll_without_pointer := false
## Scroll with the thumbstick at all; off when the screen uses the stick for something else (the song list
## moves its selection with it).
@export var joystick_scroll := true
var scroll_node: Control
var v_scroll: VScrollBar
var is_mouse_in := false

# JOYSTICK_SCROLL_THRESHOLD
# Range: 0.0 to 1.0
# Description: Scrolling via the joystick is engadged when the absolute value
# of the joystick's position exceeds this threshold. This prevents accidental
# scroll events occuring from small amounts of noise/movements in the joystick.
const JOYSTICK_SCROLL_THRESHOLD := 0.1

# JOYSTICK_SLOW_SCROLL_SPEED
# Range: 0 to max
# Description: The minimum scroll speed to use when scrolling via the joystick.
# This value is interpolated against the joystick's position and represents the
# scrolling speed nearest to the joystick's resting position.
const JOYSTICK_SLOW_SCROLL_SPEED := 10.0

# JOYSTICK_FAST_SCROLL_SPEED
# Range: 0 to max
# Description: The maximum scroll speed to use when scrolling via the joystick.
# This value is interpolated against the joystick's position and represents the
# scrolling speed at full throw of the joystick.
const JOYSTICK_FAST_SCROLL_SPEED := 2000.0

# JOYSTICK_ACCELERATION
# Description: How much faster scrolling gets per second the stick is held,
# so short pushes move a few rows and long holds race through the list.
const JOYSTICK_ACCELERATION := 1.5

# JOYSTICK_MAX_BOOST
# Description: The highest multiplier the hold acceleration can reach.
const JOYSTICK_MAX_BOOST := 4.0

var _hold_time := 0.0
## Scroll movement smaller than one pixel, kept for the next frame so slow scrolling still moves.
var _carry := 0.0

## How far one press of the scroll bar's up or down arrow moves the list, in pixels (about two rows).
const ARROW_STEP := 120.0

func _ready() -> void:
	scroll_node = get_node(scroll_node_path) as Control
	
	if scroll_node is ItemList:
		v_scroll = (scroll_node as ItemList).get_v_scroll_bar()
	elif scroll_node is ScrollContainer:
		v_scroll = (scroll_node as ScrollContainer).get_v_scroll_bar()
	# the arrows move nothing until given a step
	v_scroll.custom_step = ARROW_STEP
	
	@warning_ignore("return_value_discarded")
	scroll_node.connect(&"mouse_entered", Callable(self, &"_mouse_entered"))
	@warning_ignore("return_value_discarded")
	scroll_node.connect(&"mouse_exited", Callable(self, &"_mouse_exited"))

func _process(delta: float) -> void:
	if is_mouse_in and joystick_scroll and _press_pos == NOT_PRESSED:
		_joystick_scroll(delta)
	elif scroll_without_pointer and scroll_node.is_visible_in_tree() and _canvas_shown():
		_joystick_scroll(delta)
	else:
		_hold_time = 0.0

## Pointer drag: the list follows the pointer 1:1 (either hand, it's the canvas's pointer) once it moved past
## DRAG_THRESHOLD px from the press, so a shorter move stays a click; a drag never clicks what it started on,
## and a flick keeps the list moving for MOMENTUM_SECONDS, easing to a stop. The scroll bar's range keeps the
## first and last rows from being dragged past.
const DRAG_THRESHOLD := 12.0
const MOMENTUM_SECONDS := 0.3
## Shortest time a drag step counts for (one frame at the Pico 4's 72 Hz), so steps that arrive together don't
## make a flick look impossibly fast.
const MIN_STEP_SECONDS := 1.0 / 72.0
## How much of each new speed sample the flick speed takes (smooths a jittery pointer).
const VELOCITY_SMOOTHING := 0.5
## Where the cancelling release goes: far outside every control, so nothing under the press acts on it.
const FAR_AWAY := Vector2(-100000.0, -100000.0)
const NOT_PRESSED := Vector2.INF
var _press_pos := NOT_PRESSED
var _press_value := 0.0
var _dragging := false
## Flick speed in scroll px per second, and when the last drag step was.
var _velocity := 0.0
var _last_step_usec := 0
var _momentum: Tween

func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.position != FAR_AWAY:
		if button.pressed:
			if _over_list(button.position):
				_press_pos = button.position
				_press_value = v_scroll.value
				_dragging = false
				_velocity = 0.0
				_last_step_usec = Time.get_ticks_usec()
				if _momentum:
					_momentum.kill()
		elif _press_pos != NOT_PRESSED:
			if _dragging:
				# the press was already cancelled; this release belongs to the drag
				get_viewport().set_input_as_handled()
				_fling()
			_press_pos = NOT_PRESSED
			_dragging = false
		return
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	# hover follows the pointer itself: a press on a child (a filter chip) sends the exit while the pointer is still
	# inside, so no exit came when it left after, and the stick kept scrolling this instead of the song list
	is_mouse_in = motion.position != FAR_AWAY and scroll_node.is_visible_in_tree() \
			and scroll_node.get_global_rect().has_point(motion.position)
	if _press_pos == NOT_PRESSED:
		return
	# the button went up where this didn't see it (an option list's popup takes the release): the press is over,
	# or the list would follow the pointer from then on
	if motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		_press_pos = NOT_PRESSED
		_dragging = false
		return
	var dy := motion.position.y - _press_pos.y
	if not _dragging and absf(dy) > DRAG_THRESHOLD:
		_dragging = true
		_cancel_press.call_deferred()
	if _dragging:
		var before := v_scroll.value
		v_scroll.value = _press_value - dy
		var now := Time.get_ticks_usec()
		var seconds := maxf((now - _last_step_usec) / 1000000.0, MIN_STEP_SECONDS)
		_velocity = lerpf(_velocity, (v_scroll.value - before) / seconds, VELOCITY_SMOOTHING)
		_last_step_usec = now
		_redraw()

## True for a point on the list, not on its scroll bar (which drags itself).
func _over_list(point: Vector2) -> bool:
	if not scroll_node.is_visible_in_tree() or not _canvas_shown():
		return false
	var rect := scroll_node.get_global_rect()
	if v_scroll.visible:
		rect.size.x -= v_scroll.size.x
	return rect.has_point(point)

## Lets go of whatever the press went down on (a row, a button) away from it, so it doesn't act.
func _cancel_press() -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = FAR_AWAY
	release.global_position = FAR_AWAY
	get_viewport().push_input(release)

## Keeps a flicked list moving: the distance a linearly slowing scroll covers in MOMENTUM_SECONDS.
func _fling() -> void:
	# a pause before letting go is no flick
	if (Time.get_ticks_usec() - _last_step_usec) / 1000000.0 > MOMENTUM_SECONDS:
		return
	var target := v_scroll.value + _velocity * MOMENTUM_SECONDS / 2.0
	_momentum = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_momentum.tween_method(func(value: float) -> void:
		v_scroll.value = value
		_redraw(), v_scroll.value, target, MOMENTUM_SECONDS)

func _redraw() -> void:
	var canvas := scroll_node.get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas != null:
		canvas._input_update()

## False while the 3D canvas showing this list is hidden (a Control inside a canvas's SubViewport stays
## "visible" when the canvas is hidden).
func _canvas_shown() -> bool:
	var canvas := scroll_node.get_viewport().get_parent() as Node3D
	return canvas == null or canvas.is_visible_in_tree()

## Scrolls by the stronger thumbstick of the two hands, faster the longer it is held.
func _joystick_scroll(delta: float) -> void:
	var y_left := vr.leftController.get_vector2("primary").y
	var y_right := vr.rightController.get_vector2("primary").y
	var y_joy := y_left if absf(y_left) > absf(y_right) else y_right
	if absf(y_joy) <= JOYSTICK_SCROLL_THRESHOLD:
		_hold_time = 0.0
		return
	_hold_time += delta
	var boost := minf(1.0 + _hold_time * JOYSTICK_ACCELERATION, JOYSTICK_MAX_BOOST)
	# negate sign so positive scroll_amounts will scroll down
	var scroll_amount := lerpf(
		JOYSTICK_SLOW_SCROLL_SPEED,
		JOYSTICK_FAST_SCROLL_SPEED,
		absf(y_joy)) * boost * -signf(y_joy) * delta
	_scroll_by(scroll_amount)

## Moves the list by whole pixels and redraws its canvas. A canvas that redraws only on pointer input
## would otherwise freeze between pointer moves while the thumbstick scrolls, which looks jerky.
func _scroll_by(amount: float) -> void:
	_carry += amount
	var step := roundf(_carry)
	if step == 0.0:
		return
	_carry -= step
	var before := v_scroll.value
	v_scroll.value += step
	if v_scroll.value == before:
		_carry = 0.0
		return
	var canvas := scroll_node.get_viewport().get_parent() as OQ_UI2DCanvas
	if canvas != null:
		canvas._input_update()

func _mouse_entered() -> void:
	is_mouse_in = true

func _mouse_exited() -> void:
	# a list of child buttons (BeatSaverList's rows) reports an exit when the pointer moves onto one of them
	is_mouse_in = scroll_node.get_global_rect().has_point(scroll_node.get_global_mouse_position())
