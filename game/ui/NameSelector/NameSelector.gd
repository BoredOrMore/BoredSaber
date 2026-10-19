extends Control
class_name NameSelector

signal type_name_requested()

@onready var _saved_label := $NameRow/SavedLabel as Label

## Shows which name the new record was saved under.
func show_saved_name(name: String) -> void:
	_saved_label.text = "Saved as %s" % name

func _on_EditButton_pressed() -> void:
	type_name_requested.emit()
