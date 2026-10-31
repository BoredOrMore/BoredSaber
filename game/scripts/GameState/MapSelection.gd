extends GameState
class_name GameStateMapSelection

func _ready(game: BeepSaber_Game) -> void:
	vr.set_play_performance(false)
	DebugView.end_cycle(game)
	game.main_menu._show()
	game.profiles_canvas._hide()
	game._update_slash_block.call_deferred()
	game.main_menu.disable_collision = false
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(true)
	game.endscore._hide()
	game.pause_menu._hide()
	game.practice_canvas._hide()
	game.highscore_canvas._hide()
	# sabers are out in the menu: they slash the block that plays the song
	game.left_saber._show()
	game.right_saber._show()
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
	game.set_colors_from_settings()
	game.menu.update_view()
	# back from a song (finished or failed): the song's preview fades in again
	game.menu.play_selected_preview()
