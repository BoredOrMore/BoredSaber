# game/ — gameplay core

Main scene, global state autoloads, beatmap playback, the cuttable entities (notes, bombs, chains,
arcs, walls), sabers, scoring/health and the in-world HUD. Root `AGENTS.md` rules and Pico 4
constraints apply here unchanged.

## Entry points and runtime flow

- Main scene: `res://game/BeepSaber_Game.tscn` (`run/main_scene` in `project.godot`), script
  `BeepSaber_Game.gd` (`class_name BeepSaber_Game`).
- Autoloads living in `game/`: `Constants` (`Constants.gd`), `Scoreboard` (`Scoreboard.gd`),
  `Settings` (`Settings.gd`). Others are under `game/scripts/` and `game/ui/` (`Utils`,
  `MixedReality`, `Highscores`, `PlayCount`, `UI_AudioEngine`, `GlobalReferences`).
- `Map` (`Map.gd`) is **not** an autoload: a `RefCounted` with only `static` state (stacks,
  `current_info`, `beat_distance`, `half_jump_beats`, colours).
- Game states are `GameState` objects in `game/scripts/GameState/`. `_transition_game_state()`
  sets `gamestate` and calls its `_ready(game)`; `BeepSaber_Game._physics_process` calls
  `gamestate._physics_process(self)` each tick. Each state's `_ready` shows/hides every HUD node.
- Startup (`_ready`): fills `GlobalReferences.*_pool` from `$BeepCubePool` etc. and presizes them
  (cubes 100, links 100, bombs 30, walls 15, arcs 15), inits `vr`, then enters `gamestate_mapselection`.
- Start: menu signal `start_map` -> `start_map(info, difficulty)` -> `Map.load_beatmap()` (threaded
  parsers fill `note_stack`, `bomb_stack`, `obstacle_stack`, `arc_stack`, `chain_stack`,
  `event_stack`, reversed so `pop_back()` is the next item) -> colours, song stream, `lead_in`,
  `Scoreboard.restart()`, `_clear_track()` -> `gamestate_playing`.
- Spawning: `GameStatePlaying._process_map()` (`scripts/GameState/Playing.gd:60`) pops every item
  with `beat <= current_beat + Map.half_jump_beats`, `acquire()`s from the pool and calls
  `spawn(info, current_beat)`. Arcs mark head/tail cubes spawned this tick (`set_arc_head/tail`);
  chains go through `ChainLink.construct_chain()`, which flags the head cube with `make_chain_head()`.
  Events go to `event_driver.process_event()` at `current_beat` (no look-ahead).
- Movement: `Cuttable._physics_process` (cubes, links, bombs) and `Wall._physics_process` move
  along the lane at `Map.beat_distance * Map.beats_per_second()`; `Arc._process` moves per render
  frame. All stop while `Scoreboard.paused`.
- Cutting: `SwingableRayCast.area_collided` -> `LightSaber._handle_area_collided()` (wired in
  `LightSaber.tscn`) -> `Cuttable.cut(saber, speed, plane, controller)`. `BeepCube.cut` scores via
  `Scoreboard.note_cut` or `bad_cut("wrong saber")` and emits `cutted(correct_saber)` (arcs listen);
  `ChainLink.cut` -> `Scoreboard.chain_link_cut`; `Bomb.cut` -> `bad_cut("bomb")`.
- Miss: `Cuttable._physics_process` calls `on_miss()` past `Constants.MISS_Z`; cubes/links report
  `bad_cut("miss")`, bombs just release.
- Walls: `PlayerHead` `area_entered/exited` (group `wall`) -> `_in_wall`, `Scoreboard.enter_wall()`
  / `exit_wall()`; `_check_and_update_saber()` keeps calling `enter_wall()` while walled.
- End: `SongPlayer.finished` -> `_on_song_ended()` -> highscore/playcount -> `EndScore.show_score()`
  -> `gamestate_newhighscore` or `gamestate_mapcomplete`.

## File map (root)

- `BeepSaber_Game.gd/.tscn` — main scene: states, pools, health/fail, colours, rumble, recenter; makes the `Hud` (`hud/`).
- `Health.gd` (class `Health`) — the health rules per fail mode (`start_value`, `next_value`); `BeepSaber_Game` keeps
  the value, the rails and the fail. Tested by `tests/test_health.gd`.
- `Map.gd` — beatmap v2/v3/v4 parsing into stacks, note jump (`set_note_jump`), `beats_per_second()`
  (includes `Settings.music_speed`), map/custom colours with handedness overrides.
- `Constants.gd` — layout, scoring, health, fail modes, modifier bitmasks, UI/danger colours.
- `Settings.gd` — persisted `config.ini` options; every setter calls `set_and_emit()` -> `changed(name)`.
- `Scoreboard.gd` — points, combo/multiplier, accuracy, wall/miss/bomb penalties; signals
  `score_changed`, `points_awarded`.
- `LightSaber.gd/.tscn/.gdshader` — saber collision, show/hide anims, swing history for swing
  scoring, floor burn raycast, `left_saber`/`right_saber` shader globals.
- `SlashBlock.gd` — a note (the game's cube model, in the selected song's colours per the Map colors chip, with a
  small note of the other colour on a top corner) 75 degrees to the dominant hand's side, where no saber reaches
  while using the song menu: cutting it down with that hand's saber (tip >= 2 m/s, untuned) or pointer + trigger
  breaks it in two (`CutPiece`) and plays the selected song (`MainMenu.play_selected`); a wrong cut buzzes. The
  game shows it only while a song is picked and nothing covers the menu (`BeepSaber_Game._update_slash_block`).
- `BodyTest.gd` — body test prototype (More tab > Body Test): guard and low-stance holds, punch, squat and side-step drills that speed up
  until the player misses 3 of 8, then charged moves (power punch from guard, squat + uppercut, squat + stand up)
  held 1-8 s before GO, to measure move timings and stance holds for the planned Workout mode. Logs every rep as
  `BODYTEST,` lines and a CSV in `<APPDATA_PATH>bodytest/` (the `reach` row puts reach and eye height in the
  last two columns, `guard` the left and right fist-to-eye distance in `time_ms`/`peak_speed`, `low_stance` the eye
  drop in the eye-drop column; charged rows put the hold in `interval_ms` and ok / no_stance / broke_at_<ms> / missed
  in the last `outcome` column). Thresholds are untuned starting values.
- `CutFlash.gd` (class `CutFlash`) + `SparkStreak.gdshader` — sparks along the cut line, trails drawn by the shader.
- `FloorReflection.gd` (class `FloorReflection`) + `FloorReflection.gdshader` — the notes and blades faintly mirrored in
  the deck: two MultiMeshes refilled each frame, drawn at the deck's depth in a depth-only pass then colour, so a lower
  note's reflection hides an upper one's (no second render, no screen read); fades by depth and distance; off with
  the deck (old track, mixed reality). Made in `BeepSaber_Game._ready`; `stage_capture --notes 1` shows it too.
- `LowResGlow.gd` (class `LowResGlow`) — glow without Godot's glow pass (that pass costs ~5 ms on the Pico 4).
- `Benchmark.gd` (class `Benchmark`) — hands-off GPU benchmark (Settings > Advanced, or `tools/bench.sh`).
- `DebugView.gd` (class `DebugView`) — Settings > Advanced switches that leave parts of the scene out to measure
  their GPU cost; bits of the `debug_view` shader global, never saved.
- `event_driver.gd/.tscn` — lighting events and background; `floor.gd/.tscn` — floor and burn marks.
- `SpectatorWindow.gd/.tscn` — desktop spectator camera/HUD.
- Menus and panels (song menu, settings, end score, highscores, pause, `vr_slider`) live in `ui/`.
- `vr_goggles.gdshader` + `.glb` (the headset model in `BeepSaber_Game.tscn`), `GodotSplash.tscn`, `BlackWhiteThem.tres`, `background*.tres` — visuals.

## Entity folders

- `notes/` — notes, chain links, arcs, bombs, walls and their `Cuttable` base; see `notes/AGENTS.md`.
- `sabers/` — saber visuals listed in `Settings.SABER_VISUALS`: `default/` (`DefaultSaber`,
  `SaberTail`), `particles/` (`particles_saber.gd` extends `DefaultSaber`, clash sounds).
- `data/` — static assets: `background/` panoramas and backdrop meshes, `maps/` bundled `Songs/` and
  `Playlists.json`, UI theme, logo, button texture, cut/click/saber sounds, miss/health/clear/menu
  sounds (`tools/make_feedback_sounds.py`), the fail sound (`tools/make_fail_sound.py`), shared shaders/meshes.

## Invariants and gotchas

- Moving the playspace (where notes reach the player, `Constants.HIT_PLANE_Z`, the `Track` node, `XROrigin3D`,
  lane or row positions, player height handling) moves everything the player cuts or dodges together. After such
  a change check each kind on the headset, not only notes: notes and chains arrive on the beat at the hit plane;
  bombs and walls pass where the notes do and still hit the head (`PlayerHead`) and sabers; each arc's head and
  tail sit on its two notes and the arc stays attached while it flies in; anything that measures distance in
  world space instead of track space (`global_transform`, `MISS_Z`, despawn checks, beat accuracy) is updated.

- Light comes from a source. Every beam, laser and glow in the scenery starts at a place a real fixture
  could sit (floor, rig, ring, sky edge), and moves the way a real light does: a beam turns around the
  fixture it comes out of, never around its middle. In `event_driver.tscn` a laser's pivot node is the
  fixture; its ribbon mesh is offset by half its length so it starts at the pivot (`ribbon` is 32 m long,
  centred; a `Bar7` scaled 3 on z sits at z -48). Animate the pivot, not the mesh.

- Pooling: every spawned entity must `release()` exactly once (`PooledNode3D.release` warns on
  repeats). Cube/link with `cube_cuts_falloff` release only after both `CutPiece`s die
  (`Cuttable._on_cut_piece_died`). `clear_from_track()` must hide and release if not yet released;
  `_clear_track()` calls it on every `track` child. Hidden entities set `PROCESS_MODE_DISABLED`;
  cubes/links re-enable in `spawn()` before starting their jump (`Cuttable.start_jump`).
- New pooled scenes go through `_on_ScenePool_new_scene_instanced()` (`BeepSaber_Game.gd:624`):
  added to `track` forever, shown one frame at presize to warm shaders, then hidden via
  `hide_cube()` or `hide_pooled()`. A new entity type needs one of those.
- Pooled instances are reused, so `spawn()` must reset every per-instance state (see the chain-head
  reset in `BeepCube.gd:74-79`). The cube `ShaderMaterial` is `resource_local_to_scene`
  (`BeepCube.tscn:76`); its collision `BoxShape3D`s are not, yet `BeepCube.gd:55-58` and
  `ChainLink.gd:95-99` resize them per spawn (shared across instances). Report, don't silently "fix".
- Danger colour (`danger_wall.tres`, `bomb_glow.tres`) and `Arc` materials are shared; set via
  `_update_danger_color()` and `update_left/right_color()` in `BeepSaber_Game.gd`.
- Colours: always read `Map.color_left/right` (handedness-aware getters), not `Settings.color_*`, at spawn.
- Health: all damage goes through `update_health(delta, mistake)` (`BeepSaber_Game.gd:156`);
  `FAIL_MODE_LIVES`/`INSTANT` only react to `mistake`. Fail is `_fail_song()` (sets `failing`, pauses
  Scoreboard, fades rumble, closes a low-pass on the song and fades it, empties the track (`_empty_track`: shrinks
  everything away, then `_clear_track`), shows FAILED after `FAIL_WORD_DELAY`, fades to black, then `_on_song_ended()`;
  `start_map` takes the filter off); guard new logic with `not failing`.
- Rumble: `_check_and_update_saber()` only sets rumble when `not controller.is_simple_rumbling()`,
  so cut rumble in `BeepCube.cut` wins for its duration.
- Timing: song time comes from `get_current_time()` (negative during `lead_in`). After restart,
  Playing waits for `_audio_synced_after_restart` before processing the map.
- Arcs move in `_process`, everything else in `_physics_process`; keep new movement in physics so it
  lines up with saber collisions.
- Physics rate: `project.godot` sets `common/physics_fps=72`, the Godot 3 key name; Godot 4 reads
  `physics/common/physics_ticks_per_second` (default 60). Unverified which one applies; if physics runs at
  60 Hz on the 72 Hz Pico display, physics-driven notes judder. Check before tuning motion.
- `LightSaber._physics_process` writes `left_saber`/`right_saber` globals (declared in
  `project.godot` `[shader_globals]`); renaming them breaks `Arc.gdshader`.
- Compatibility renderer only (root `AGENTS.md`): no Vulkan-only shader features; GPU particles are
  already disabled on Android.
- Known oddities, report don't fix unasked: `BeepSaber_Game.tscn:344` connects to a missing
  `_on_right_controller_button_pressed`; `Map.gd:150` `continue` skips `i += 1`;
  `Constants.gd:79-80` `DIFFICULTY_HANDEDNESS_IGNORE` equals `FORCE_RIGHT`.

## Where to change X

- Add a setting: property with setter calling `set_and_emit()` and a `default_values` entry in
  `Settings.gd`, control + handler in `ui/settings_Panel.gd/.tscn`, react in an
  `on_settings_changed(key)` (`BeepSaber_Game.gd:365` or `LightSaber.gd:79`).
- Add a note type: info class in `game/BeatmapInfo/`, parser + stack in `Map.gd` (`load_beatmap`),
  scene extending `Cuttable` with `spawn/cut/on_miss/clear_from_track/hide_*`, a `ScenePool` node in
  `BeepSaber_Game.tscn` wired to `_on_ScenePool_new_scene_instanced`, presize in `_ready`, a
  `GlobalReferences` slot, and a spawn loop in `Playing._process_map`.
- Tune scoring/health: constants in `Constants.gd` (`OPENSABER_*`, `SWING_*`, `HEALTH_*`); logic in
  `Scoreboard.gd`, cut accuracy in `BeepCube.cut`, swing angles in `LightSaber.gd`.
- Note colours/presets: `Settings.COLOR_PRESETS`/`color_left/right`; map overrides in
  `Map.set_colors_from_custom_data()`; propagation in `update_left/right_color()`.
- HUD element: see `hud/AGENTS.md`; mirror in `SpectatorWindow` if it should show there.
- Test: `godot --headless --path . res://tests/test_map_info.tscn` for parsing changes; anything
  touching spawning, cutting, rendering, rumble or XR needs a headset run with `adb logcat`.

## Subfolders with their own docs

- `notes/` — the things that fly at the player; see `notes/AGENTS.md`.
- `hud/` — in-song HUD (score, combo, accuracy, time, health, cut numbers); see `hud/AGENTS.md`.
- `scripts/` — game states, scene pools, controller, UI raycast, highscores, utils; see `scripts/AGENTS.md`.
- `ui/` — map download/BeatSaver/name-selector panels, UI audio, menu theme; see `ui/AGENTS.md`.
- `BeatmapInfo/` — parsed map/difficulty/note info classes; see `BeatmapInfo/AGENTS.md`.
