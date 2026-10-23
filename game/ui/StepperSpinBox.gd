class_name StepperSpinBox
extends SpinBox
## A number shown between big − and + buttons, for the pointer: SpinBox's own arrows are a few pixels
## tall and typing needs the keyboard. One press moves by button_step; holding repeats, faster over time.
## The SpinBox keeps its own finer step, so saved values aren't rounded to button_step.

## How far one press of − or + moves the value.
@export var button_step := 0.01

## Wait before a held button starts repeating, then the first and the fastest repeat interval (seconds).
const HOLD_DELAY := 0.4
const REPEAT_SLOW := 0.15
const REPEAT_FAST := 0.04
## Side of the − and + buttons, about 3 degrees at menu distance like other targets.
const BUTTON_SIZE := Vector2(52, 52)
const MINUS_ICON := preload("res://game/ui/icons/minus.svg")
const PLUS_ICON := preload("res://game/ui/icons/plus.svg")

var _held := 0
var _hold_time := 0.0
var _next_repeat := 0.0

## Shows the number only (no arrows, no typing) and puts the buttons on either side of it.
func _ready() -> void:
	var none := ImageTexture.new()
	for icon in [&"updown", &"up", &"up_hover", &"up_pressed", &"up_disabled", &"down", &"down_hover", &"down_pressed", &"down_disabled"]:
		add_theme_icon_override(icon, none)
	for constant in [&"buttons_width", &"field_and_buttons_separation", &"set_min_buttons_width_from_icons"]:
		add_theme_constant_override(constant, 0)
	var empty := StyleBoxEmpty.new()
	for style in [&"up_background", &"up_background_hovered", &"up_background_pressed", &"up_background_disabled",
			&"down_background", &"down_background_hovered", &"down_background_pressed", &"down_background_disabled",
			&"field_and_buttons_separator", &"up_down_buttons_separator"]:
		add_theme_stylebox_override(style, empty)
	get_line_edit().editable = false
	# read-only text would turn grey; it is the value, not a disabled field
	get_line_edit().add_theme_color_override(&"font_uneditable_color", Constants.UI_TEXT)
	get_line_edit().alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_process(false)
	_add_buttons.call_deferred()

## Adds − before and + after this box in its parent (deferred: the parent is still adding children in _ready).
func _add_buttons() -> void:
	var index := get_index()
	for sign: int in [-1, 1]:
		var button := Button.new()
		button.icon = MINUS_ICON if sign < 0 else PLUS_ICON
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = BUTTON_SIZE
		button.tooltip_text = "Less" if sign < 0 else "More"
		button.button_down.connect(_on_button_down.bind(sign))
		button.button_up.connect(_on_button_up)
		get_parent().add_child(button)
		get_parent().move_child(button, index if sign < 0 else index + 2)
		UI_AudioEngine.attach_button(button)

## Steps once at once, then repeats while held.
func _on_button_down(sign: int) -> void:
	_held = sign
	_hold_time = 0.0
	_next_repeat = HOLD_DELAY
	_step()
	set_process(true)

## Stops repeating.
func _on_button_up() -> void:
	_held = 0
	set_process(false)

## Repeats the held step, the interval shrinking from REPEAT_SLOW to REPEAT_FAST over a second.
func _process(delta: float) -> void:
	_hold_time += delta
	if _hold_time < _next_repeat:
		return
	_step()
	var speed_up := clampf((_hold_time - HOLD_DELAY) / 1.0, 0.0, 1.0)
	_next_repeat = _hold_time + lerpf(REPEAT_SLOW, REPEAT_FAST, speed_up)

## Moves the value one button_step in the held direction, landing on whole steps.
func _step() -> void:
	value = snappedf(value + _held * button_step, button_step)
