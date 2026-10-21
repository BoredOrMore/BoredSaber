extends GameState
class_name GameStateBodyTest

## The running test; freed when it ends.
var _test: BodyTest

func _ready(game: BeepSaber_Game) -> void:
	game.main_menu._hide()
	game.profiles_canvas._hide()
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._hide()
	game.pause_menu._hide()
	game.highscore_canvas._hide()
	game.left_saber._hide()
	game.right_saber._hide()
	game.multiplier_label.visible = false
	game.point_label.visible = false
	game.percent_indicator.visible = false
	game.health_rails.visible = false
	game.track.visible = false
	game.left_ui_raycast.visible = false
	game.right_ui_raycast.visible = false
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(false)
	game.right_saber.set_swingcast_enabled(false)
	_test = BodyTest.new()
	game.add_child(_test)
	_test.setup(game)
	_test.finished.connect(_on_finished.bind(game))

## Frees the test and goes back to the song menu.
func _on_finished(game: BeepSaber_Game) -> void:
	_test.queue_free()
	_test = null
	game._transition_game_state(game.gamestate_mapselection)
