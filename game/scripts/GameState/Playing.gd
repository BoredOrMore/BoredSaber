extends GameState
class_name GameStatePlaying

func _ready(game: BeepSaber_Game) -> void:
	game.main_menu._hide()
	game.profiles_canvas._hide()
	game.slash_block.set_shown(false)
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._hide()
	game.pause_menu._hide()
	game.highscore_canvas._hide()
	game.show_sabers_for_map()
	game.multiplier_label.visible = true
	game.point_label.visible = true
	# the far HUD of 90/360 maps carries the energy bar instead
	game.health_rails.visible = Settings.health_mode and not game.hud.far and not Map.practice
	game.track.visible = true
	game.left_ui_raycast.visible = false
	game.right_ui_raycast.visible = false
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()
	game.left_saber.set_swingcast_enabled(true)
	game.right_saber.set_swingcast_enabled(true)
	Scoreboard.paused = false
	_lead_in_shown = -1
	DebugView.cycle_from_flag()

func _physics_process(game: BeepSaber_Game) -> void:
	DebugView.cycle_tick()
	DebugView.apply(game)
	if game.failing:
		return
	for controller: BeepSaberController in [game.left_controller, game.right_controller]:
		if controller.by_just_pressed() or controller.menu_just_pressed():
			game._transition_game_state(game.gamestate_paused)
			return
	if game.lead_in > 0.0:
		_count_down_lead_in(game)
		_process_map(game)
	elif game._audio_synced_after_restart:
		_process_map(game)
	else:
		# 0.5 seconds is a pretty concervative number to use for the audio
		# resync check. Having this duration be this long might only be an
		# issue for maps that spawn notes extremely early into the song.
		if game.song_player.get_playback_position() < game.song_start + 0.5:
			game._audio_synced_after_restart = true

var _lead_in_shown := -1

## Shows the seconds left before the song and starts it when the lead-in runs out.
func _count_down_lead_in(game: BeepSaber_Game) -> void:
	game.lead_in -= game.get_physics_process_delta_time()
	var seconds := ceili(game.lead_in)
	if seconds != _lead_in_shown:
		_lead_in_shown = seconds
		game.pause_countdown.visible = seconds > 0
		if seconds > 0:
			game.pause_countdown.text = str(seconds)
			game.play_countdown(seconds)
	if game.lead_in <= 0.0:
		game.lead_in = 0.0
		game.song_player.play(game.song_start)
		game.play_countdown(0)

func _process_map(game: BeepSaber_Game) -> void:
	if (Map.current_info == null):
		return
	
	var current_beat := game.get_current_time() * Map.current_info.beats_per_minute * 0.016666666666666667
	spawn_due(current_beat)
	
	game.event_driver.show_beat = current_beat
	while not Map.event_stack.is_empty() and Map.event_stack[-1].beat <= current_beat:
		game.event_driver.process_event(Map.event_stack.pop_back() as EventInfo)

## Spawns the map's notes, bombs, walls, arcs and chains that are due by `current_beat` (within the jump's half,
## Map.half_jump_beats, ahead; all but walls Cuttable.FLY_SECONDS more, to fly in), from the GlobalReferences pools. Shared with the stage preview
## (tools/capture/stage_capture.gd --notes).
static func spawn_due(current_beat: float) -> void:
	# notes, bombs, arcs and chains come FLY_SECONDS early to fly in (Cuttable.fly_offset); walls at their jump
	var wall_ahead := current_beat + Map.half_jump_beats
	var look_ahead := wall_ahead + Cuttable.FLY_SECONDS * Map.beats_per_second()
	
	# chains connect to a regular colornote and modify it, so we have to keep
	# track of what notes were spawned this frame, in case any become the head
	# of a chain.
	# why did they do this?
	var note_info_refs: Array[ColorNoteInfo] = []
	var cube_refs: Array[BeepCube] = []
	
	# spawn notes
	while not Map.note_stack.is_empty() and Map.note_stack[-1].beat <= look_ahead:
		var note := GlobalReferences.cube_pool.acquire() as BeepCube
		var note_info := Map.note_stack.pop_back() as ColorNoteInfo
		note.spawn(note_info, current_beat)
		note_info_refs.append(note_info)
		cube_refs.append(note)
	
	# spawn bombs
	while not Map.bomb_stack.is_empty() and Map.bomb_stack[-1].beat <= look_ahead:
		var bomb := GlobalReferences.bomb_pool.acquire() as Bomb
		bomb.spawn(Map.bomb_stack.pop_back() as BombInfo, current_beat)
	
	# spawn obstacles (walls)
	while not Map.obstacle_stack.is_empty() and Map.obstacle_stack[-1].beat <= wall_ahead:
		var wall := GlobalReferences.wall_pool.acquire() as Wall
		wall.spawn(Map.obstacle_stack.pop_back() as ObstacleInfo, current_beat)
	
	while not Map.arc_stack.is_empty() and Map.arc_stack[-1].head_beat <= look_ahead:
		var arc_info := Map.arc_stack.pop_back() as ArcInfo
		
		# find starting cube to use as magnet trigger and mark start and end cubes as arc head/tail
		var head_cube : BeepCube
		var cube_id := cube_refs.size()-1
		var have_head := false
		var have_tail := false
		while cube_id >= 0:
			var current_cube : BeepCube = cube_refs[cube_id]
			if current_cube.which_saber == arc_info.color:
				if current_cube.beat == arc_info.head_beat:
					current_cube.set_arc_head()
					head_cube = current_cube
					if have_tail:
						break
					have_head = true
				if current_cube.beat == arc_info.tail_beat:
					current_cube.set_arc_tail()
					if have_head:
						break
					have_tail = true
			cube_id -= 1
		
		if have_head:
			var arc := GlobalReferences.arc_pool.acquire() as Arc
			arc.spawn(arc_info, current_beat, head_cube)
	
	while not Map.chain_stack.is_empty() and Map.chain_stack[-1].head_beat <= look_ahead:
		var chain_info := Map.chain_stack.pop_back() as ChainInfo
		if chain_info.slice_count > 1: # skip if the chain doesn't have any links
			ChainLink.construct_chain(chain_info, current_beat, note_info_refs, cube_refs)
