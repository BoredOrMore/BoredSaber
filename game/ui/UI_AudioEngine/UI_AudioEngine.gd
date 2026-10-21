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
var _prev_hovered_ctrl: BaseButton
var _prev_hover_time := 0
func _on_button_hovered(control: BaseButton) -> void:
	# prevent rapid hover sound effects that can occur when the mouse is
	# very close to the edge of the control node (ie. enters/exists quickly)
	var time_now_ms := Time.get_ticks_msec()
	if _prev_hovered_ctrl != control or (time_now_ms - _prev_hover_time) > HOVER_DEBOUNCE_TIME_MS:
		hover_stream.play()
	
	_prev_hovered_ctrl = control
	_prev_hover_time = time_now_ms

## Plays the sound for a press: on/off for a switch (a toggle button in no group; a group is a choice
## of options, which clicks), back for back and close buttons, the click for the rest.
func _on_button_pressed(button: BaseButton) -> void:
	if button.toggle_mode and not button.button_group:
		(toggle_on_stream if button.button_pressed else toggle_off_stream).play()
	elif button.name in BACK_BUTTON_NAMES:
		back_stream.play()
	else:
		click_stream.play()
