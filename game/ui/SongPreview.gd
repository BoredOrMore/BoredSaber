class_name SongPreview
extends AudioStreamPlayer
## The song menu's preview player (the main menu's song_prev node): fades between previews, plays on from the
## preview's start to the song's end and loops after a short gap, so the menus never fall silent (as in Beat Saber),
## and stops whenever the song itself plays.

## Seconds of quiet between the end of a preview and its next loop, and how fast Play fades it out.
const LOOP_GAP := 0.5
const PLAY_FADE_SECONDS := 0.3
## how long a preview takes to fade in or out
var transition_time := 1.0
## the game's song player (BeepSaberMainMenu.main_song_player_ref): the preview yields to it
var song_player: AudioStreamPlayer

## Bumped by every preview request, so only the newest one plays after the fade-out awaits.
var _generation := 0
## the playing preview's start, length and volume, to loop it
var _loop_start := 0.0
var _loop_duration := 0.0
var _loop_volume_db := 0.0
@onready var _end_timer := $stop_prev as Timer

func _ready() -> void:
	_end_timer.timeout.connect(_on_ended)

func _physics_process(_delta: float) -> void:
	if song_player and song_player.playing:
		stop()

## Fades the playing preview to volume_db.
func fade_to(volume_db: float) -> void:
	create_tween().tween_property(self, ^"volume_db", volume_db, transition_time)

## Plays a song's audio from start_time to its end, fading out the one playing first; type_hint is 'ogg' or 'mp3'.
func start(buffer: PackedByteArray, start_time: float = 0.0, type_hint: String = 'ogg', volume_db: float = 0.0) -> void:
	_generation += 1
	var generation := _generation
	var audio: AudioStream
	# take song preview data from buffer as-is. trust passed type hint
	if type_hint == 'ogg':
		audio = AudioStreamOggVorbis.load_from_buffer(buffer)
	elif type_hint == 'mp3':
		audio = AudioStreamMP3.new()
		(audio as AudioStreamMP3).data = buffer

	if not audio: return

	# play on from the preview's start to the end of the song instead of looping the map's short preview
	# window, which felt repetitive in the menus (the player's choice); _on_ended starts it again
	var duration := maxf(audio.get_length() - start_time, 1.0)

	# fade out preview if ones already running
	if playing:
		await fade_out()
	if generation != _generation:
		return

	# start the requested preview, if still on song select
	if not song_player.playing:
		stream = audio
		Loudness.apply(bus, audio, Loudness.key(buffer.size(), audio))
		var fade_in := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		@warning_ignore("return_value_discarded")
		# TODO: is this a good idea with higher speeds?
		fade_in.tween_property(self, ^"volume_db", volume_db, transition_time)
		fade_in.play()
		play(start_time)
		pitch_scale = Settings.music_speed / 100.
		_end_timer.start(duration)
		_loop_start = start_time
		_loop_duration = duration
		_loop_volume_db = volume_db

## Fades out the playing preview over seconds (transition_time when below 0) and drops any preview still waiting to
## start.
func cancel(seconds := -1.0) -> void:
	_generation += 1
	await fade_out(seconds)

## The preview reached its end: fade it out, then play it again from its start after a short gap, as long as nothing
## else took over (another preview, a song), so the song select never falls silent.
func _on_ended() -> void:
	var generation := _generation
	await fade_out()
	await get_tree().create_timer(LOOP_GAP).timeout
	if generation != _generation or song_player.playing or playing or stream == null:
		return
	volume_db = -50
	play(_loop_start)
	create_tween().tween_property(self, ^"volume_db", _loop_volume_db, transition_time)
	_end_timer.start(_loop_duration)

## Fades out the preview over seconds (transition_time when below 0) and stops it, unless a newer one started.
func fade_out(seconds := -1.0) -> void:
	if seconds < 0.0:
		seconds = transition_time
	var generation := _generation
	var fade := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	@warning_ignore("return_value_discarded")
	fade.tween_property(self, "volume_db", -50, seconds)
	fade.play()
	await get_tree().create_timer(seconds).timeout
	# a newer preview has started meanwhile; leave it playing
	if generation == _generation:
		stop()
