extends Node

@export var scroll_node_path: NodePath
## Scroll with the thumbstick even when no pointer is over the list (for the screen's main list).
@export var scroll_without_pointer := false
var scroll_node: Control
var v_scroll: VScrollBar
var is_mouse_in := false
var relpos := 0.0
var scrollpos := 0.0

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
	var newpos := -vr.rightController.rotation_degrees.x - (vr.rightController.transform.origin.y * 20.0)
	if is_mouse_in:
		if vr.rightController.trigger_pressed():
			# Scroll via "click & drag"
			_scroll_by((relpos - newpos) * 20.0)
		else:
			_joystick_scroll(delta)
	elif scroll_without_pointer and scroll_node.is_visible_in_tree() and _canvas_shown():
		_joystick_scroll(delta)
	else:
		_hold_time = 0.0
	relpos = newpos

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
	is_mouse_in = false
