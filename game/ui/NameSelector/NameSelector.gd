extends Control
class_name NameSelector

signal name_selected(name: String)
signal type_name_requested()

@onready var _base_button := Button.new()
@onready var _name_row := $NameRow as HBoxContainer

func _ready() -> void:
	clear_names()

func add_name(name: String) -> void:
	var new_button := _base_button.duplicate() as Button
	new_button.text = name
	new_button.pressed.connect(_on_NameButton_pressed.bind(name))
	_name_row.add_child(new_button)

## Adds the last button, which opens the keyboard to type a new name.
func add_keyboard_button() -> void:
	var new_button := _base_button.duplicate() as Button
	new_button.text = "Type name..."
	new_button.pressed.connect(type_name_requested.emit)
	_name_row.add_child(new_button)

func clear_names() -> void:
	for child in _name_row.get_children():
		child.queue_free()

func _on_NameButton_pressed(name: String) -> void:
	name_selected.emit(name)
