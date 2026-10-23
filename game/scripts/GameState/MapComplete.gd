extends GameState
class_name GameStateMapComplete

func _ready(game: BeepSaber_Game) -> void:
	# show this map's records next to the score, as after a new record
	game.highscore_panel.load_highscores(
		Map.current_info,Map.current_difficulty.difficulty_rank,game._new_record)
	game.endscore.set_buttons_disabled(false)
	game.main_menu._hide()
	game.profiles_canvas._hide()
	game.slash_block.set_shown(false)
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._show()
	game.menu.play_selected_preview(MainMenu.SCORE_SCREEN_PREVIEW_DB)
	game.event_driver.set_menu_focus(true)
	game.pause_menu._hide()
	game.highscore_canvas.transform = game.highscores_score_transform
	game.highscore_canvas._show()
	game.left_saber._hide()
	game.right_saber._hide()
	game.multiplier_label.visible = false
	game.point_label.visible = false
	game.percent_indicator.visible = false
	game.health_rails.visible = false
	game.track.visible = false
	game.left_ui_raycast.visible = true
	game.right_ui_raycast.visible = true
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
