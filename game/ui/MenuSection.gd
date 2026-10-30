@tool
class_name MenuSection
extends VBoxContainer
## A titled group of controls on a menu panel (owner, 2026-10-28: build UI as templates, pages only swap content):
## its title, then its rows ROW_GAP apart. Sections sit SECTION_GAP apart in their parent (section_list), three
## times the gap between rows, so each reads as one group (vr-ui-design: grouping and spacing).

## between rows of a section, and between sections: 6 and 16 px, about 0.4 and 1 degree at the menus' 2 m
const ROW_GAP := 6
const SECTION_GAP := 16
const SCENE := preload("res://game/ui/MenuSection.tscn")

@export var title := "":
	set(value):
		title = value
		if is_node_ready():
			$Title.text = value

func _ready() -> void:
	$Title.text = title

## A new section titled title, its rows added after it.
static func make(section_title: String) -> MenuSection:
	var section := SCENE.instantiate() as MenuSection
	section.title = section_title
	return section

## Spaces list's sections SECTION_GAP apart.
static func section_list(list: BoxContainer) -> void:
	list.add_theme_constant_override(&"separation", SECTION_GAP)
