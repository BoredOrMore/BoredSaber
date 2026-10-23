class_name ConfirmButton
extends IconButton
## A button for something that can't be undone. The first press asks in the button itself, naming what will be
## lost (question); a second press within CONFIRM_SECONDS does it (confirmed); otherwise the button goes back.
## Asking in place keeps the player's eyes where they pressed, and naming the loss is what makes a confirmation
## read rather than clicked through (NN/g, "Confirmation Dialogs Can Prevent User Errors (If Not Overused)").

signal confirmed

const CONFIRM_SECONDS := 4.0

## What the first press asks, e.g. "Exit the game? Press again"; set it before the press when it names
## something that changes.
@export var question := ""

var _label := ""
var _asking := false
## Bumped on every press, so a timer from an earlier question doesn't undo a later one.
var _press := 0

## Listens for presses on top of IconButton's centring.
func _ready() -> void:
	super()
	pressed.connect(_on_pressed)

## Asks on the first press, confirms on the second.
func _on_pressed() -> void:
	_press += 1
	if _asking:
		cancel()
		confirmed.emit()
		return
	_asking = true
	_label = text
	text = question
	add_theme_color_override(&"font_color", Constants.UI_DANGER)
	add_theme_color_override(&"font_hover_color", Constants.UI_DANGER)
	var press := _press
	await get_tree().create_timer(CONFIRM_SECONDS).timeout
	if _asking and press == _press:
		cancel()

## Puts the button back as it was before the question.
func cancel() -> void:
	if not _asking:
		return
	_asking = false
	text = _label
	remove_theme_color_override(&"font_color")
	remove_theme_color_override(&"font_hover_color")
