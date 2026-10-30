# Headless tests

Engine-level checks that run without a headset or XR runtime. CI runs every one (`.github/workflows/build-pico4.yml`,
5 minutes each); a new test goes there too.

## File map

- `test_map_info.tscn` - a single `Node` with the test script; the scene is what Godot runs.
- `test_map_info.gd` - the checks:
  - v2: loads the bundled song `res://game/data/maps/Songs/TheFatRat_Timelapse/` through
    `Map.load_map_info` and checks BPM 127 from `_beatsPerMinute`.
  - v4: writes a minimal v4 `Info.dat` (`V4_INFO`) to `user://test_maps/v4/`, loads it, and checks version
    prefix `4.`, BPM 128 from `audio.bpm`, `previewStartTime`, and one difficulty.

- `test_menu_layout.tscn` / `.gd` - lays out the song menu (Song tab, More modifiers, More tab) and "Who's playing?"
  headless with worst-case content (every modifier changed, a long player name and title, eight characteristic
  tabs, five numbered levels, two stats lines, six players with a delete question; the practice panel stopped and
  playing, with its time, start, end, speed and greyed speed buttons, the start staying put, and
  pointer presses on its one bar (the playhead on the bar, the nearer marker under it, Repeat's end); on the Download page every filter
  and a long search as chips, a map with long names and five levels, its Details, a download and the open filters) and fails when a visible control
  spills out of its parent or the panel, or two controls placed with offsets are closer than `MIN_GAP` (4 px). A
  control wholly under an open overlay (`OVERLAYS`: More, More modifiers) counts as hidden. Content inside a
  `ScrollContainer` is allowed to run past it; on the song page only the song list and the filters' page
  (`FilterChips.SCROLL_NAME`, owner 2026-10-30) may scroll, and the filters are checked scrolled to their end on both pages. Run it after any change to these panels or the theme. It also drags the song
  list with pointer events pushed into a `SubViewport` (as the game's canvases receive them): 1:1, no pick after a
  drag, a short press still picks.
- `test_song_search.tscn` / `.gd` - `SongSearch` (the song menu's search): kana read as romaji, case, spaces,
  punctuation, long vowels and doubled letters alike, every typed word, tags; `BeatSaverPanel.close_query`; the AI
  mark in saved tags; Get songs listing a 360°-only map by its 360° difficulties.
- `test_swing_rating.tscn` / `.gd` - checks `LightSaber.swept` (swing angles as Beat Saber measures them): a steady
  approach counts in full, a step whose plane turned past 90° ends the count, a follow-through stops at the turn back.
- `test_sabers.tscn` / `.gd` - every saber in `Settings.SABER_VISUALS` loads, takes a colour and runs a frame without a
  script error stopping it part-way; the particle sword finds its particles.
- `test_beatmap.tscn` / `.gd` + `data/beatmap/` (small v2, v3, v4 maps) - `Map.load_beatmap`: counts, stack order (popped
  from the back), lanes, layers, colours and cut directions of notes, bombs, walls, arcs, chains and light events in
  each format, plain and mirrored (`Settings.flip`); `half_jump_beats_for`/`set_note_jump`; gradual rotation; v2 rotation events adding up in degrees; where the track turns (`get_turns`, `track_rotation`) and the turn cue (`cue_rotation`); 90/360
  maps play on Henge (`EventDriver.pick_environment`); a v4 map
  takes its lights from its lightshow file (`data/beatmap/v4_lightshow.dat`, skipping an event past its data) and,
  without one, leaves no lights from the last map; a stray non-object v2 note is skipped (it once looped forever);
  practice: `Map.skip_before`, `Map.snapshot`/`restore` (jumping back) and the practice speed in `beats_per_second`.
- `test_scoreboard.tscn` / `.gd` - `Scoreboard`: multiplier steps (2, 6, 14 hits) and halving, combo, max points and
  accuracy, modifier shares and No Fail, bad cuts, walls, chain links, `restart`. A `FakeGame` stands in for
  `GlobalReferences.main_game_scene`. Not covered: `note_cut` (needs a real saber).
- `test_highscores.tscn` / `.gd` - `HighscoreTable` on a file of its own: order, the 10-record limit, ties, a table per
  map, difficulty and modifier set, player names, saving.
- `test_spawn.tscn` / `.gd` - notes, bombs, walls and arcs from their real pools: place on spawn (lane, row, beat),
  movement per second, and a reused one placed as a fresh one would be (arcs once kept their old place); the note jump
  (at the hit plane a note's visual is at its row, full size, turned; where it appears it is at its row, unturned). Turned lanes
  (90°, 180°, -90°): notes, bombs, walls and arcs turned about the player's standing point, a turned note flown to its
  hit point on its beat, rotation 0 unchanged. Not covered: chains, the arc's magnet hookup.
- `test_health.tscn` / `.gd` - `Health` (the rules `BeepSaber_Game.update_health` applies): starting health per fail
  mode, hits, misses and walls in the bar, Half Damage, 4 Lives, Instant, No Fail's hidden bar, the cap.
- `test_cut.tscn` / `.gd` - cut judgement (`BeepCube.right_saber`, `angle_accuracy`, `centre_accuracy`,
  `beat_accuracy_at`) and the chain's curve (`ChainLink.curve_points`, `link_place`).
- `test_hud.tscn` / `.gd` - the far 90/360 HUD (`Hud.far_cluster`: 15 m over the lane, clear of the highest note at
  eye 1.5-1.75 m, Beat Saber's text sizes, parts laid out on it; Standard keeps the side panels); the HUD's panels
  placed from the player's eye (`Hud._panel`): the same angle and distance
  for any eye, facing it, grown by distance, turned out to clear the lanes on Wide 200%; `Hud.turn` takes the panels and
  the score round the player with the track and back.
- `test_show_intensity.tscn` / `.gd` - checks `EventDriver.intensity_curve` (the build-up of the stage): a calm part
  low and a dense part high, values in 0..1, no curve without light events, finite values for a flat light show; the
  track's turn on 90/360 maps (`EventDriver.Turn`): eased in and out over `TRACK_TURN_TIME`, keeping its speed when a
  new turn comes mid-way, the short way round; Henge's drop (`EventDriver.henge_drop`): starts past `STRIP_DROP`,
  holds through a dip, ends under `HENGE_DROP_RELEASE`; nothing builds without light events.

## Running

```sh
godot --headless --path . res://tests/test_map_info.tscn
```

- Exit code 0 = pass, 1 = any failure (`test_map_info.gd:63`). Output prints `PASS:`/`FAIL:` lines and a
  failure count.
- Run `--import` once first on a fresh clone so `class_name` scripts and resources are registered (CI does
  this, `.github/workflows/build-pico4.yml:72-73`).
- CI runs the same command with Godot 4.6.2 on every push and PR before exporting the APK
  (`build-pico4.yml:75-76`); a failure stops the build and the `pico4-latest` release.
- Project autoloads (`Settings`, `vr`, ...) load as usual, so record `_init` code that reads `Settings` works.
- The `Pico 4` export preset has `exclude_filter="tests/*"` (`export_presets.cfg`), so tests never ship.

## Structure of a test

- `extends Node`; checks run in `_ready()` and end with `get_tree().quit(1 if failures > 0 else 0)`.
- `check(ok, what)` counts failures and prints; put the observed value in the message
  (`"... (got %s)" % value`).
- Fixtures: prefer an inline dict written to `user://test_maps/...` (as `V4_INFO`) over new files under
  `res://`; reuse bundled songs in `game/data/maps/Songs/` for real-map coverage.
- Guard dependent checks with `if result:` so a null load reports one failure instead of crashing.

## Adding a test

1. Map parsing: add `check(...)` lines to `test_map_info.gd`. Keep one script per area.
2. New area: copy the pattern into `tests/test_<area>.gd` + a `tests/test_<area>.tscn` with a root `Node`
   using that script, then add a `Run tests` line for it in `.github/workflows/build-pico4.yml` and the
   command to root `AGENTS.md` (workflow edits are a CI change: keep it to that one line).
3. Run it headless locally and confirm a deliberately wrong expectation exits 1.
4. Never weaken or delete a check to make it pass (root `AGENTS.md`).
