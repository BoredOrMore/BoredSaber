extends GameState
class_name GameStateNewHighScore

func _ready(game: BeepSaber_Game) -> void:
	# populate highscore panel with records
	game.highscore_panel.load_highscores(
		Map.current_info,Map.current_difficulty.difficulty_rank)
	
	# the record is already saved under the default name; picking a name only renames it
	game.endscore.set_buttons_disabled(false)
	
	# no list of past names to pick from: show the saved name and let the keyboard edit it
	var saved_name := game._default_player_name()
	game._name_selector().show_saved_name(saved_name)
	
	game.main_menu._hide()
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._show()
	game.pause_menu._hide()
	game.highscore_canvas._show()
	game.name_selector_canvas._show()
	game.left_saber._hide()
	game.right_saber._hide()
	game.multiplier_label.visible = false
	game.point_label.visible = false
	game.percent_indicator.visible = false
	game.track.visible = false
	game.left_ui_raycast.visible = true
	game.right_ui_raycast.visible = true
	game.highscore_keyboard._text_edit.placeholder_text = "Type your name"
	game.highscore_keyboard._text_edit.text = saved_name
	game.highscore_keyboard._text_edit.set_caret_column(saved_name.length())
	game.highscore_keyboard._on_TextEdit_text_changed()
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
	game.set_colors_from_settings()
