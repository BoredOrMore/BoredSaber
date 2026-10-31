extends GameState
class_name GameStatePracticeHold
## Practice stopped (owner, 2026-10-30): the song waits at a point with the practice panel beside the player, where the
## timeline, the speed, Play and Exit are pressed; the sabers point, the HUD keeps the accuracy.

func _ready(game: BeepSaber_Game) -> void:
	game.main_menu._hide()
	game.profiles_canvas._hide()
	game.slash_block.set_shown(false)
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._hide()
	game.pause_menu._hide()
	game.practice_canvas._show()
	game.pause_countdown.visible = false
	game.highscore_canvas._hide()
	game.show_sabers_for_map()
	game.multiplier_label.visible = false
	game.point_label.visible = true
	game.health_rails.visible = false
	game.track.visible = true
	game.left_ui_raycast.visible = true
	game.right_ui_raycast.visible = true
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
	Scoreboard.paused = true

func _physics_process(game: BeepSaber_Game) -> void:
	game._practice_stick(game.get_physics_process_delta_time())
