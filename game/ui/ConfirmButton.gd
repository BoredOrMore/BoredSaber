class_name ConfirmButton
extends IconButton
## A button for something that can't be undone. The first press asks in the button itself, naming what will be
## lost (question); a second press within CONFIRM_SECONDS does it (confirmed); otherwise the button goes back.
## Asking in place keeps the player's eyes where they pressed, and naming the loss is what makes a confirmation
## read rather than clicked through (NN/g, "Confirmation Dialogs Can Prevent User Errors (If Not Overused)").

signal confirmed

const CONFIRM_SECONDS := 4.0
## The smallest size the question shrinks to so it fits the button: Meta's floor for text read on a panel
## (.claude/skills/vr-ui-design/SKILL.md).
const MIN_QUESTION_FONT_SIZE := 18

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
	if theme_type_variation == &"":
		theme_type_variation = &"DestructiveButton"
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
	_fit_question()
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
	remove_theme_font_size_override(&"font_size")
	remove_theme_color_override(&"font_color")
	remove_theme_color_override(&"font_hover_color")

## Shrinks the question's font, down to MIN_QUESTION_FONT_SIZE, until the button needs no more room than it has.
func _fit_question() -> void:
	var room := size
	var font_size := get_theme_font_size(&"font_size")
	while font_size > MIN_QUESTION_FONT_SIZE:
		add_theme_font_size_override(&"font_size", font_size)
		var needed := get_minimum_size()
		# the left padding centres the label (IconButton); the right one stands for both sides
		var box := get_theme_stylebox(&"normal")
		needed.x += box.content_margin_right - box.content_margin_left
		if needed.x <= room.x and needed.y <= room.y:
			return
		font_size -= 1
	add_theme_font_size_override(&"font_size", font_size)
