# Dev tools

Desktop/dev-machine tools: Godot capture scenes, Blender model scripts, Python asset generators, headset GPU
bench, doc checker. None of it runs in the game. Read the root `AGENTS.md` first.

`tools/asset_pipeline/` has its own rules: see `tools/asset_pipeline/AGENTS.md` (it holds the only `.gdignore`
here, so Godot skips it; everything else under `tools/` is imported by Godot but `capture/` isn't referenced by
the game).

Run everything from the repo root. Dev Mac: `godot` (4.6.2) and `blender` on PATH (`/opt/homebrew/bin`).

## File map: `capture/` (Godot scenes, desktop render to PNG)

All four parse `--key value` pairs after `--` (`OS.get_cmdline_user_args()`), so every flag takes a value
(`--stats 1`, not `--stats`). Renders need a window: no `--headless`, except `peak_objects`, which renders nothing.

- `ui_angles.gd` / `ui_angles.tscn`: loads the game scene headless and measures every menu panel, button and line of
  text as angles and distances from the eye (`--eye 1.6`, the menus raised as `_place_menus` does) against
  vr-ui-design's limits; writes a Markdown report (`--out`, default `user://ui_angles.md`): what's outside the limits,
  then every panel. Renders nothing, so it can run `--headless` and the Mac camera's FOV plays no part.
- `env_thumbnails.sh`: every environment's picker pictures, `game/env/thumbs/<id>.png` (card, 440x400) and
  `<id>_wide.png` (closed button, 896x240), rendered by `stage_capture` with a per-environment camera (`FRAMES`: yaw,
  pitch, fov) framed tight on the stage's main unique element. Run it whenever an environment is added or its look
  changes (root AGENTS.md); a new environment gets a `FRAMES` line.
- `stage_capture.gd` / `stage_capture.tscn`: a stage as seen from the player's eye with the game's environment
  (`game/event_driver.tscn`), WorldEnvironment, floor and shaders. Writes `--out` (default
  `user://stage_capture.png`), prints `stage_capture OK -> path`, exits 1 on save or `--map` failure. Full option
  list with meanings in its header (`stage_capture.gd:7-31`); code reads exactly:
  `--out --size WxH(1920x1080) --seconds(2.5) --env classic|neon_grid|night_city|pulse_void|metal_factory --built 0..1
  --lights on|off|menu --left/--right RRGGBB --danger RRGGBB --eye(1.6) --pitch --yaw --fov(90) --beat --animate
  --map <folder|song name> --difficulty --start --at --notes 1 --note left|right --note-yaw --note-pitch --dot 1
  --wall 1 --wall-z(3) --wall-x --saber left|right --saber-dist(0.35)
  --bomb 1|classic --bomb-dist(0.8) --stats 1 --audit 1 --build-up 0..1 --result fail|clear --failed-word 1`.
  With `--map` it runs to song end unless `--seconds` or `--at`. `--saber` holds `default_saber.tscn` (`:222`).
  Example: `godot --path . res://tools/capture/stage_capture.tscn -- --out /tmp/stage.png --env night_city`
- `endscore_capture.gd` / `endscore_capture.tscn`: renders `game/ui/EndScore.tscn` to check text fits its board.
  `--out(/tmp/end.png) --song --author --level --mapper --card <name card text> --card-change 1 ("Not you?") --percent(0.87)
  --record 1 --fc 1`;
  undocumented in header: `--before <percent>` (show and close a previous score first) and `--frames(1)` with it.
- `highscore_capture.gd` / `highscore_capture.tscn`: renders `game/ui/HighscorePanel.tscn` at menu size.
  `--out(/tmp/hs.png) --table highscores.json --key "[artist,song,,mapper]" --rank(1) --names long --rows(10)
  --mods 1` (all modifiers on in memory, longest title).
- `peak_objects.gd` / `peak_objects.tscn`: scans every map in `Constants.APPDATA_PATH + "Songs/"` and prints the
  busiest moment by triangles and by notes (game spawn rules, nothing cut), plus `MESH` triangle counts. Headless:
  `godot --headless --path . res://tools/capture/peak_objects.tscn`. `TRIS` (`peak_objects.gd:9`) is hand-kept.

## File map: `models/` (Blender, headless)

Run: `blender -b -P tools/models/<script>.py -- game/models` (`OUT_DIR` = first arg after `--`). Exception:
`note_round.py -- game/notes/BeepCube`. Each header names its spec `doc/assets/<name>/spec.md`; follow
`.claude/skills/game-model-creator/SKILL.md` and `tools/asset_pipeline/`.

- `model_export.py`: shared `bake_and_export(obj, out_dir, name)`: AO baked to vertex red, face attr `glow` 1/2 to
  green/blue (EnvSolid vents), flat shading, GLB Y-up, prints triangles.
- Using it: `ac_unit`, `antenna`, `dish_panel`, `dish_props`, `feed_cabin`, `feed_leg`, `hanging_scaffold`, `platform_frame`, `site_props`,
  `stair_house`, `survey_mast`, `tower_crane`, `track_edge`, `track_end`, `wall_catwalk`, `water_tank` (one `.glb`
  each, same name); `arch_parts` (arch_section/footing/scaffold), `classic_props` (classic_props, tool_box),
  `follow_spot` (+`follow_spot_stand`), `rim_parts` (rim_segment, rim_mast), `tunnel_parts` (tunnel_rib, tunnel_lining), `wall_kit` (wall_column/panel/
  pipes/machine/machine_low).
- Own exporter (older, inline copy): `anvil_base`, `gears` (gear_ring, drive_gear_large/small), `laser_fixture`
  (+`laser_fixture_yoke`), `piston_hammer` (+`piston_housing`), `note_round` (`game/notes/BeepCube/note_round.glb`).

## File map: Python generators (write tracked game assets)

- `make_hit_sounds.py` -> `game/data/cut_1..4.wav`, `bad_cut.wav`, `bomb_hit.wav`. Stdlib.
- `make_combo_sounds.py` -> `game/data/combo_up/combo_milestone/combo_break.wav` (ComboHud). Stdlib.
- `make_countdown_sounds.py` -> `game/data/countdown_tick.wav`, `countdown_go.wav`. Stdlib.
- `make_feedback_sounds.py` -> `game/data/miss, low_health, clear, ui_hover, ui_back, toggle_on, toggle_off.wav`.
- `make_fail_sound.py` -> `game/data/fail.wav` (reversed `lightsaber.ogg` + thump). Needs ffmpeg.
- `make_sa3_sounds.py NAME [--pick 2b]`: Stable Audio 3 candidates in `$SA3_OUT` (`~/ai-audio-tools/samples`),
  `--pick` copies to `game/data/NAME.wav`. Needs `$SA3_DIR` install + ffmpeg. Only recipe `saber_powerdown`,
  which the game does not use (superseded by `make_fail_sound.py`).
- `make_stage_sky.py` -> `game/data/background/stage_sky.png` (Classic "Stage" sky, `Settings.gd:12`). Stdlib.
- `bake_neon_grid_sky.py` -> `game/env/neon_grid_sky_sharp.png`, `_soft.png` (`NeonGridSky.gdshader`). numpy+Pillow.
- `bake_night_city_sky.py` -> `game/env/night_city_sky_sharp.png`, `_soft.png` (`NightCitySky.gdshader`). numpy+Pillow.
- `make_matcap.py` -> `game/env/metal_matcap.png` (EnvSolid metal layer). Relative `OUT`: run from repo root.

## File map: other

- `bench.sh [--only resolution|msaa|glowb|total|hz90|fog|reflection|cuts|stages] [log]`: over adb, writes the mode to
  `/sdcard/Android/data/org.godotengine.open_saber_plus/files/benchmark`, waits for `BENCH done|cancelled`, saves
  logcat to `bench.log` (or `[log]`), runs `bench_report.py`. Game must be open in the song menu; headset worn or
  proximity sensor covered. Modes match `game/Benchmark.gd:27-47`.
- `bench_report.py <log>` (or stdin): per-phase GPU ms/median/p95/max, missed frames, seconds over budget, CPU,
  temp, from `BENCH start/end` + PxrMetric lines.
- `check_agent_docs.py`: exits 1 listing every tracked `.gd/.tscn/.gdshader/.gdshaderinc` under `game/`, `tests/`,
  `tools/` (asset_pipeline skipped) whose stem+extension is not in its nearest non-root `AGENTS.md`. Currently
  untracked and not called from `.github/workflows/`.

## Invariants and gotchas

- Generators overwrite tracked assets in `game/`; rerun only the one you changed, commit its output with it.
  Edit the constants in the script, not the output file.
- Capture output paths: default `user://` for stage, `/tmp/...` for the others; pass `--out` explicitly.
- Capture scenes reuse game scenes/autoloads (`Settings`, `Highscores`); `--mods` changes settings
  in memory only, never saved.
- Desktop colours differ from the Pico LCD; capture is a pre-check, the headset is final.
- Model scripts need Cycles for the AO bake (slow at `AO_SAMPLES` 64); exported `.glb` gets a `.import` on next
  editor open (untracked, don't commit `.uid`/`.import` noise per root rules).

## Where to change X

- New capture option: `_args()` users in `stage_capture.gd`; document it in the header block `:7-31`.
- New model: copy a `model_export.py` user, add spec under `doc/assets/`, export to `game/models`.
- New synth sound: add a `save(...)` in the matching `make_*_sounds.py`; design it by the Sound design rules in
  `doc/research/player-guidance.md`.
- Bench phases: `game/Benchmark.gd` (the game side), then `bench.sh` usage comment.

## How to check a change

- `python3 tools/check_agent_docs.py` (must print the all-named line).
- Capture scripts: run the scene, open the PNG; `peak_objects` headless.
- Generators: rerun, listen/look, `git diff --stat game/` to see what changed.
