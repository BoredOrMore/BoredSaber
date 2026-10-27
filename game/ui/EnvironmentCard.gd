class_name EnvironmentCard
extends Button
## A button that is a picture (owner, 2026-10-28: the environment's picture fills the whole button, still telling
## the stages apart): the picture covers the button, cropped to its shape and rounded by its CardButton style (it
## clips its children), the name in white over a dark band at the bottom; a ring in UI_ACCENT while pointed at,
## thicker when picked. The Environment picker's closed button and its cards (ModifierChips).

const SCENE := preload("res://game/ui/EnvironmentCard.tscn")

## A new card showing picture and title.
static func make(picture: Texture2D, title: String) -> EnvironmentCard:
	var card := SCENE.instantiate() as EnvironmentCard
	card.show_card(picture, title)
	return card

func _ready() -> void:
	mouse_entered.connect(_ring)
	mouse_exited.connect(_ring)
	toggled.connect(func(_on: bool) -> void: _ring())
	_ring()

func show_card(picture: Texture2D, title: String) -> void:
	($Picture as TextureRect).texture = picture
	($Name as Label).text = title

## Shows the card as the pick (pressed, its thick ring) without pressing it.
func set_picked(on: bool) -> void:
	set_pressed_no_signal(on)
	_ring()

func _ring() -> void:
	var ring := $Ring as Panel
	var hovered := is_hovered()
	ring.visible = button_pressed or hovered
	(ring.get_theme_stylebox(&"panel") as StyleBoxFlat).set_border_width_all(6 if button_pressed else 3)
