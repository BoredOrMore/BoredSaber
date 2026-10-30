extends GameState
class_name GameStatePaused

func _ready(game: BeepSaber_Game) -> void:
	game.main_menu._hide()
	game.profiles_canvas._hide()
	game.slash_block.set_shown(false)
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._hide()
	game.pause_menu._show()
	game.pause_countdown.visible = false
	game.highscore_canvas._hide()
	game.multiplier_label.visible = true
	game.point_label.visible = true
	# the far HUD of 90/360 maps carries the energy bar instead
	game.health_rails.visible = Settings.health_mode and not game.hud.far and not Map.practice
	game.track.visible = false
	game.left_ui_raycast.visible = true
	game.right_ui_raycast.visible = true
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber._hide()
	game.right_saber._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
	Scoreboard.paused = true
	
	game.pause_position = game.song_player.get_playback_position()
	game.song_player.stop()
	game.play_pause_sound()
	(game.pause_menu.ui_control as PausePanel).set_pause_text(
		"%s By %s\nMap author: %s" % [
		Map.current_info.song_name,
		Map.current_info.song_author_name,
		Map.current_info.level_author_name
		], MapStats.level_name(Map.current_info, Map.current_difficulty) + _accuracy_line(game)
	)

## The accuracy and live grade so far, on a line of their own, when the far HUD of 90/360 maps leaves them out.
func _accuracy_line(game: BeepSaber_Game) -> String:
	if not game.hud.far:
		return ""
	var accuracy := Scoreboard.accuracy()
	return "\nAccuracy %.1f%%  %s" % [accuracy * 100.0, Hud.shown_grade(accuracy, Scoreboard._notes_scored)]
