extends Node

@onready var hover_stream := $HoverStream as AudioStreamPlayer
@onready var click_stream := $ClickStream as AudioStreamPlayer
@onready var back_stream := $BackStream as AudioStreamPlayer
@onready var toggle_on_stream := $ToggleOnStream as AudioStreamPlayer
@onready var toggle_off_stream := $ToggleOffStream as AudioStreamPlayer

## buttons that go back or close a panel play the falling back sound instead of the click
const BACK_BUTTON_NAMES: Array[StringName] = [&"Back_Button", &"back", &"CloseButton", &"Close_Button", &"MainMenu", &"mainmenu"]

func attach_children(node: Node, include_buttons: bool = true, include_texture_buttons: bool = true) -> void:
	for child in node.get_children():
		if include_buttons and child is Button:
			attach_button(child as Button)
		elif include_texture_buttons and child is TextureButton:
			attach_button(child as TextureButton)
		
		attach_children(child, include_buttons)

func attach_button(button: BaseButton) -> void:
	@warning_ignore("return_value_discarded")
	button.mouse_entered.connect(_on_button_hovered.bind(button))
	@warning_ignore("return_value_discarded")
	button.pressed.connect(_on_button_pressed.bind(button))

func play_click() -> void:
	click_stream.play()
	
func set_volume(value_db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(&"UI")
	AudioServer.set_bus_volume_db(bus_idx, value_db)

# prevent spuratic clicking when mouse enters/exits a control quickly
const HOVER_DEBOUNCE_TIME_MS = 200
## No two hover sounds closer than this, so sweeping the laser down a list ticks instead of buzzing.
const HOVER_MIN_GAP_MS = 70
var _hovered_ctrls: Array[BaseButton] = [null, null]
var _prev_hover_time := 0
var _prev_hover_sound_time := -HOVER_MIN_GAP_MS
func _on_button_hovered(control: BaseButton) -> void:
	if hover_sounds(control, Time.get_ticks_msec()):
		hover_stream.play()

## Whether entering control at time_now_ms makes the hover sound. Not when the pointer is very close to
## the edge of a control (enters/exits quickly) or shakes on the line between two (A, B, A, B...),
## and never twice within HOVER_MIN_GAP_MS.
func hover_sounds(control: BaseButton, time_now_ms: int) -> bool:
	var back_and_forth := control in _hovered_ctrls and (time_now_ms - _prev_hover_time) <= HOVER_DEBOUNCE_TIME_MS
	var sounds := not back_and_forth and time_now_ms - _prev_hover_sound_time >= HOVER_MIN_GAP_MS
	if sounds:
		_prev_hover_sound_time = time_now_ms
	if control != _hovered_ctrls[0]:
		_hovered_ctrls = [control, _hovered_ctrls[0]]
	_prev_hover_time = time_now_ms
	return sounds

## Plays the sound for a press: on/off for a switch (a toggle button in no group; a group is a choice
## of options, which clicks), back for back and close buttons, the click for the rest.
func _on_button_pressed(button: BaseButton) -> void:
	if button.toggle_mode and not button.button_group:
		(toggle_on_stream if button.button_pressed else toggle_off_stream).play()
	elif button.name in BACK_BUTTON_NAMES:
		back_stream.play()
	else:
		click_stream.play()
