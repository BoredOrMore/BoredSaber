# game/scripts/GameState

The game's screen/state machine. Each state is a stateless-ish `Object` whose `_ready(game)` sets what is
visible and enabled, and whose `_physics_process(game)` runs every physics frame while it is current.
All flow logic (start, fail, end, pause, resume) lives in `game/BeepSaber_Game.gd`.

## File map

- `GameState.gd` - `class_name GameState`, base with no-op `_ready(game)` and `_physics_process(game)`.
  A bare instance is the boot state (`BeepSaber_Game.gd:9,16`).
- `MapSelection.gd` - `GameStateMapSelection`: main menu + map source dialogs, sabers sheathed, UI pointers on.
- `Settings.gd` - `GameStateSettings`: settings canvas + map source dialogs, sabers sheathed.
- `Playing.gd` - `GameStatePlaying`: HUD + track, sabers via `show_sabers_for_map()`, swingcasts on, pointers off;
  `_physics_process` handles pause input, the lead-in countdown and spawning (`_process_map`).
- `Paused.gd` - `GameStatePaused`: pause menu, HUD kept, track hidden, sabers sheathed; stops the song.
- `MapComplete.gd` - `GameStateMapComplete`: end score + this map's highscores.
- `NewHighscore.gd` - `GameStateNewHighScore`: like MapComplete, for a run that made the board ("Saved as <player>").
- `BodyTest.gd` - `GameStateBodyTest`: hides menus, sabers and pointers, runs a `game/BodyTest.gd` node and
  returns to MapSelection when it emits `finished`.

## Transition mechanics

- `_transition_game_state(next)` only sets `gamestate` and calls `next._ready(self)` (`BeepSaber_Game.gd:197-199`).
  There is no exit hook, so every `_ready` must set every canvas, HUD, saber and pointer itself; that is why each
  file repeats the same list.
- One instance per state, created once as `gamestate_*` vars (`BeepSaber_Game.gd:9-15`). Member vars survive
  re-entry; reset them in `_ready` (`Playing.gd:24`).
- `BeepSaber_Game._physics_process` calls `gamestate._physics_process(self)` each frame (`BeepSaber_Game.gd:264`).
  Only `Playing` overrides it.
- Code elsewhere checks `game.gamestate == game.gamestate_*` (`BeepSaber_Game.gd:170,215,224,232,357`).

Transitions (callers wired in `BeepSaber_Game.tscn:340-362`):

| From | To | Trigger |
|---|---|---|
| boot | MapSelection | `BeepSaber_Game._ready` (`:313`) |
| MapSelection | Settings | menu `settings_requested` -> `_settings_button` (`:616-618`) |
| MapSelection | BodyTest | menu `body_test_requested` (More tab) -> `_body_test_button` |
| BodyTest | MapSelection | test `finished` (done + trigger, or B/Y/menu) -> `GameStateBodyTest._on_finished` |
| Settings | MapSelection | settings panel `apply` -> `_on_settings_Panel_apply` (`:620-622`) |
| MapSelection / Paused / end screens | Playing | `start_map` (`:93-152`); restart -> `_restart_button` (`:552-555`) |
| Playing | Paused | B/Y or menu just pressed (`Playing.gd:29-32`); app focus/visibility lost (`:351-358`, `:298-300`) |
| Paused | Playing | `continue_button` -> `_unpause_button` (`:584-601`) |
| Paused / end screens | MapSelection | `mainmenu*` -> `_main_menu_button` (`:557-559`), clears the track |
| Playing | NewHighscore / MapComplete | `SongPlayer.finished` or fail -> `_on_song_ended` (`:503-545`) |

## Flows

- Practice: the lead-in counts down the same way and the song plays from `song_start` (not 0); the restart sync
  waits for a position under `song_start + 0.5` (`Playing.gd`).
- Lead-in: `start_map` stops the song and sets `lead_in = max(LEAD_IN_MIN_SECONDS, half_jump_beats / beats_per_second)`
  (`BeepSaber_Game.gd:136-138`). `Playing._count_down_lead_in` subtracts physics delta, shows whole seconds on
  `pause_countdown`, then `song_player.play(0.0)` (`Playing.gd:48-58`). Notes spawn during it because
  `get_current_time()` is negative while `lead_in > 0` (`BeepSaber_Game.gd:495-499`).
- Restart sync: after the lead-in, `_process_map` waits until playback position < 0.5 s
  (`_audio_synced_after_restart`, `BeepSaber_Game.gd:60-70`, `Playing.gd:36-43`), so old notes are not replayed.
- Pause: `Paused._ready` saves `pause_position`, stops the song, sets `Scoreboard.paused` (`Paused.gd:25-28`).
  Resume runs a 3-2-1 countdown (3 x 0.5 s timers) while still in Paused, plays from `pause_position` unless a
  lead-in is still running, then enters Playing (`BeepSaber_Game.gd:584-601`).
- Fail: `update_health` calls `_fail_song` when health hits 0 in Playing (`BeepSaber_Game.gd:170-171`). It sets
  `failing`, freezes scoring, disables swingcasts, shows "Failed", tweens pitch/volume down over `FAIL_SECONDS`,
  fades rumble, then calls `_on_song_ended` (`:174-193`). While `failing`, Playing ignores pause input and stops
  spawning (`Playing.gd:27-28`) and `_pause_if_playing` does nothing (`:357`).
- Song end: increments play count, and a new highscore is saved at once under `_default_player_name()` before
  NewHighscore opens (`BeepSaber_Game.gd:535-543`). The player is picked in the song menu, not on the score screen.

## Input per state

- Playing: B/Y or menu (left only on Pico 4) on either controller pauses (`Playing.gd:29-32`); sabers cut via swingcast.
- Paused, MapSelection, Settings, MapComplete, NewHighscore: trigger through the visible `UIRaycast`.
- Outside Playing and Paused, A/X or B/Y toggles the saber on that hand (`BeepSaber_Game.gd:224-228`).

## Gotchas

- `Settings.gd` does not touch swingcasts; `MapSelection`, `Settings`, `MapComplete`, `NewHighscore` never hide
  `pause_countdown`. They rely on Paused (`Paused.gd:10`) and `_fail_song` (`BeepSaber_Game.gd:191`) hiding it.
- Only `Paused`, `Playing` and `_fail_song` write `Scoreboard.paused`; `BeepSaberController` skips
  `movement_aabb` updates while it is true (`BeepSaberController.gd:97-98`).
- `_unpause_button` awaits timers; the state is still Paused until the countdown ends.

## Adding a state

1. New `game/scripts/GameState/<Name>.gd`: `extends GameState`, `class_name GameState<Name>`, `##` doc comments.
2. In `_ready`, set every item the other states set (copy the full list from the closest state).
3. Add `var gamestate_<name> := GameState<Name>.new()` next to the others in `BeepSaber_Game.gd:9-15`.
4. Enter it only via `_transition_game_state`; guard callbacks with `gamestate == gamestate_<name>`.
5. Check `_check_and_update_saber` (`BeepSaber_Game.gd:224,232`) and `_pause_if_playing` (`:357`) for states they
   should cover.

Test: `godot --headless --path . res://tests/test_map_info.tscn` does not cover states. On the headset, walk menu ->
play -> pause/resume -> fail and finish -> new record -> menu, and watch `adb logcat` for errors.
