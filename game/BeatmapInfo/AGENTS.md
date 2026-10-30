# Beatmap data model and parsing

Plain `RefCounted` records for one map (`Info.dat`) and the objects in one difficulty file, plus the
static loader in `game/Map.gd` that fills them. Format reference: https://bsmg.wiki/mapping/map-format.html

## File map

- `MapInfo.gd` - song metadata + `difficulty_beatmaps`. `new_v2` (`_version`, `_difficultyBeatmapSets`),
  `new_v4` (`version`, `difficultyBeatmaps`, `song`/`audio` dicts). Lightshow characteristic is skipped.
- `DifficultyInfo.gd` - `missing_mod()`: the first required mod (`_requirements` / v4 `requirements`) outside
  `PLAYABLE_MODS` (Mapping Extensions, Chroma, Cinema). Mapping Extensions' precise values go through
  `Utils.precise_measurement` (lanes, walls), `precise_layer` (note rows) and `precise_angle_rad` (1000/2000 +
  degrees, clockwise), as the mod's PrecisePlacementPatches and 360DegreeNoteRotationPatches do.
- `DifficultyInfo.gd` - difficulty, characteristic, `beatmap_filename`, NJS + offset, `custom_data`,
  `custom_name` (from `_difficultyLabel`/`difficultyLabel`), v4 `lightshow_filename`. v4 has no rank yet (`DifficultyInfo.gd:75`).
- `ColorNoteInfo.gd`, `BombInfo.gd`, `ObstacleInfo.gd`, `ArcInfo.gd`, `ChainInfo.gd`, `EventInfo.gd` - one
  record per object, each with `new_v2`/`new_v3` factories (`ChainInfo` is v3 only). v4 is converted to
  v3-shaped dicts in `Map.gd` before calling `new_v3`.
- `../Map.gd` - static loader and current-map state (`current_info`, `*_stack`, colours, `one_saber`).

## How it connects

1. Menu scans `Constants.APPDATA_PATH + "Songs/"` (`BeepSaberMainMenu.gd:169`); each folder or `.zip` goes
   through `Map.load_map_info` (`Map.gd:122`), which tries `Info.dat`/`info.dat`/`INFO.DAT` and picks v2 on
   `_version`, v4 on `version`, else returns null. Bundled songs in `res://game/data/maps/Songs/` are copied
   there once (`Settings.preloaded_songs`, `BeepSaberMainMenu.gd:146-167`).
2. `APPDATA_PATH` (`game/Constants.gd:21`): `user://OpenSaber/` off-device; on Android
   `/sdcard/Android/data/<package>/...` so songs can be pushed over USB.
3. `BeepSaber_Game.start_map` (`BeepSaber_Game.gd:93`) reads the difficulty file and calls
   `Map.load_beatmap` (`Map.gd:527`): `_version` -> v2 keys (`_notes`, `_obstacles`, `_events`, `_sliders`);
   `version` 3.x -> `colorNotes`, `bombNotes`, `obstacles`, `sliders`, `burstSliders`, `basicBeatmapEvents`,
   `rotationEvents`; 4.x -> same arrays plus `*Data` index tables (`colorNotesData`, `arcsData`, `chainsData`).
   If the difficulty file has no version, the `Info.dat` version is copied in (`Map.gd:531`).
4. Stacks are stored reversed (last index = earliest beat) so gameplay pops from the end.

## Threading

- Each object type runs on its own `*_thread_0`; inside, `load_range` splits the array in half and runs the
  first half on `*_thread_1` (`Map.gd:60-71`, e.g. `Map.gd:263-267`).
- Always start with `Utils.custom_thread_call` and join with `Utils.custom_thread_wait_to_finish`
  (`game/scripts/Utils.gd:110-135`). They track started threads in `thread_finished` under
  `thread_finished_mutex`, and run inline on Web (no threads). Never call `Thread.start` directly here.
- Halves write to pre-`resize`d arrays by index; don't `append` from two threads (v2 notes are the exception:
  each half returns its own arrays, `Map.gd:160-168`).
- Records read `Settings` in `_init` (flip, gradual rotation, handedness): set those before loading.

## Speed, characteristic, colours

- `set_note_jump` (`Map.gd:449`): `beat_distance = NJS * 60 / BPM` metres per beat; half jump starts at
  4 beats, halved while the jump distance exceeds 18 m, plus `note_jump_start_beat_offset`, min 0.25.
  NJS <= 0 keeps `Constants.BEAT_DISTANCE` (4.0) and 4 beats. Consumers: `BeepCube.gd:50,63`, `Wall.gd`,
  `Bomb.gd`, `Arc.gd`, `ChainLink.gd`, lead-in `BeepSaber_Game.gd:138`, spawn look-ahead `Playing.gd:65`.
- Reaction time (`half_jump_beats * 60 / BPM`) and same-hand swing gap are the measures for player-facing
  difficulty labels. Band edges and their evidence (BeatSaver data, BeatLeader stars) are in
  `doc/research/reaction-time-and-swing-gap.md`; take thresholds from there, don't invent new ones.
- `one_saber = characteristic == "OneSaber"` (`Map.gd:546,604`); either saber cuts any note
  (`BeepCube.gd:147`, `ChainLink.gd:128`).
- `set_colors_from_custom_data` (`Map.gd:74`): unless `Settings.disable_map_color`, checks info then difficulty
  `custom_data` for `_envColor%sBoost`, `envColor%sBoost`, `_envColor%s`, `envColor%s`, `_color%s`, `color%s`;
  later matches win. Missing keys fall back to `Settings.color_left/right`.

## Gotchas

- Boundary validation (root `AGENTS.md`): map files are untrusted. Read fields only through
  `Utils.get_float/get_str/get_array/get_dict` with a default, and type-check array entries (`is Dictionary`).
- v4 lights come from the difficulty's lightshow file (`lightshowDataFilename`, `DifficultyInfo.lightshow_filename`),
  read next to the beatmap file (`BeepSaber_Game._read_song`/`_read_lightshow`) and passed to `Map.load_beatmap`;
  only `basicEvents` are played (`load_event_stack_v4`). Colour boosts and the v3/v4 event box groups (newer
  environments' lights) are not loaded, as in v3. A v4 map without a lightshow file plays dark.
- `load_note_stack_v2` `continue`s without `i += 1` on a non-Dictionary entry (`Map.gd:150`): that hangs the
  loader thread. Known bug, not fixed here.
- `BombInfo._init` adds gradual rotation twice (`BombInfo.gd:16-17`). Known bug, not fixed here.
- `start_map` logs but does not return on an unreadable difficulty file (`BeepSaber_Game.gd:96-97`).
- `Map.beats_per_second` divides by 6000 because `Settings.music_speed` is a percentage (`Map.gd:465`).

## Recipes

- New `Info.dat` field: add the var and `_init` param to `MapInfo`/`DifficultyInfo`, read it in both `new_v2`
  and `new_v4` with a `Utils.get_*` default, then add a check to `tests/test_map_info.gd`.
- New difficulty-file field: add it to the record and every `new_v*`; for v4, copy it into the v3-shaped
  dict in the matching `load_*_v4` / `load_*_v3_v4` (`Map.gd:248-410`).
- New format version: add a branch in `load_map_info` (`Map.gd:134`) and/or `load_beatmap` (`Map.gd:537`);
  unknown versions must keep returning null/false with a `vr.log_warning`.
- Test: `godot --headless --path . res://tests/test_map_info.tscn` (see `tests/AGENTS.md`). Gameplay changes
  (speed, colours, OneSaber) also need a run on the headset.
