# game/scripts

Shared runtime pieces used by `game/BeepSaber_Game.gd` and the menus: autoload tables, controller input,
UI pointer, saber hit detection, object pools, the Wi-Fi song uploader and small helpers.
Game state machine: see `GameState/AGENTS.md`.

## File map

Autoloads (`project.godot` `[autoload]`): `Utils`, `MixedReality`, `Highscores`, `PlayCount`, `GlobalReferences`.

- `Utils.gd` (autoload `Utils`, all `static`) - typed dict getters `get_str/bool/float/array/dict`, zip/file reads
  (`unzip`, `file_exists`, `read_binary_file`, `binary_to_json`), `custom_thread_call` / `custom_thread_wait_to_finish`,
  note-angle and flip helpers (`precise_angle_rad`, `adjust_*`), `update_bus_speed`.
- `BeepSaberController.gd` (`BeepSaberController`, extends `XRController3D`) - per-frame button edges
  (`ax/by/menu/trigger_*pressed/just_pressed/just_released`), `simple_rumble`, `movement_aabb`.
- `SongTags.gd` (class `SongTags`) - BeatSaver tags (genre, style) of library songs kept in a file, so "Auto" can
  pick an environment by genre offline (`EventDriver.map_environment`).
- `MixedReality.gd` (autoload) - `set_mixed_reality(mr)`: passthrough on/off plus floor/HUD material tweaks.
- `PlayCountTable.gd` (autoload `PlayCount`) - play counts, favourite flag, last difficulty per map.
- `HighscoreTable/HighscoreTable.gd` (autoload `Highscores`) - top-10 records per map + modifier set.
  `HighscoreTableTest.gd/.tscn` - manual console test scene.
- `global_references.gd` (autoload `GlobalReferences`) - the five `ScenePool`s and `main_game_scene`.
- `CollisionLayerConstants.gd` - `*_bit` / `*_mask` physics layer constants.
- `ScenePool/` - `ScenePool` (`presize`, `acquire`, signal `new_scene_instanced`) and `PooledNode3D` (`release`).
- `UIRaycast/` - `UIRaycast` laser pointer, `UIRaycastTarget.gd` (Area3D base), `UIRaycastButton` (3D button, `pressed`/`released`).
- `SwingableRayCast/` - `SwingableRayCast`: saber ray plus swept sub-rays, signal `area_collided`.
- `SongUploader/` - `SongUploader` HTTP server (`prompt.html`, `style.css` are served as-is).
- `webxr/webxr_initializer.*` - "Enter VR" button for the Web export.
- `BackgroundImgLoader.gd` - threaded cover loader (`load_texture`), max 10 threads by default.
- `HTTPRequestPool.gd/.tscn` - throttled `HTTPRequest`s, signal `request_complete(..., token, user_data)`.
- `ImageUtils.gd` - `get_img_from_buffer` by magic bytes (jpg/png/bmp/webp).
- `MapStats.gd` - cached note count / length / NPS per difficulty, menu filters, `count_all_async`.
- `LinkedList.gd` - small deque used by `BackgroundImgLoader` and `SwingableRayCast` debug trail.

## How it connects

- `BeepSaber_Game.gd:277-286` fills `GlobalReferences.*_pool` from scene nodes and presizes them (100/100/30/15/15);
  `GameState/Playing.gd` acquires from them. `BeepSaber_Game.gd:624-642` (`_on_ScenePool_new_scene_instanced`)
  parents every new pooled node to `Track` for good.
- `BeepSaber_Game.gd:503-545` (`_on_song_ended`) calls `PlayCount.increment_play_count` and `Highscores.*`;
  `HighscorePanel.gd`, `BeepSaberMainMenu.gd` read them.
- `Map.gd` loads difficulty files on threads via `Utils.custom_thread_call` (e.g. `Map.gd:539-551`).
- `SongUploader` node lives in `BeepSaber_Game.tscn:336`; the menu shows `get_server_url()` (`BeepSaberMainMenu.gd:472-474`).
- `webxr_initializer.tscn` is instanced only on Web by `OQ_Toolkit/vr_autoload.gd:189-192`.
- `MixedReality.set_mixed_reality` is called from `OQ_Toolkit/vr_autoload.gd:217` and `game/settings_Panel.gd:205`.

## Invariants and gotchas

- Threads: `custom_thread_call` runs the function inline on Web (no threads) and stores the result
  (`Utils.gd:126-128`); otherwise it starts the thread and records it in `thread_finished` under
  `thread_finished_mutex` (`Utils.gd:104-107,130-135`). Join with `custom_thread_wait_to_finish` (`Utils.gd:110-122`),
  which returns `null` for a thread that never started. `BackgroundImgLoader.gd:40` never joins, so its
  threads stay in `thread_finished`.
- `BackgroundImgLoader` calls the callback on the worker thread (`BackgroundImgLoader.gd:63`); receivers must
  `call_deferred` scene changes (`BeepSaberMainMenu.gd:272-277`). `MapStats` defers `_save_cache` and `on_done`
  to the main thread and guards `_cache` with `_cache_mutex` (`MapStats.gd:44-53,95-119`).
- Storage root: `Constants.CONFIG_ROOT_PATH` is `user://` except on Android with a `/data/data/` user dir,
  where it is `APPDATA_PATH` = `/sdcard/Android/data/<pkg>/...` (`Constants.gd:20-23`). Files:
  `highscores.json` (`HighscoreTable.gd:5`), `play_count.json` (`PlayCountTable.gd:5`), `map_stats.json` (`MapStats.gd:8`).
  Every change rewrites the whole file; `clear_table()` does not save.
- Highscore format: `{map_key: {str(rank_key): [{score, player_name, epoch_time}, ...]}}`, at most
  `MAX_RECORDS_PER_KEY` = 10, sorted highest then oldest (`HighscoreTable.gd:9-24,210-220`). `map_key` is
  `MapInfo.get_key()` (`BeatmapInfo/MapInfo.gd:63`). `get_rank_key` folds health, arrows, bombs, claws, walls, block size, width,
  speed, flip and handedness into the rank (`HighscoreTable.gd:48-75`), so each modifier set has its own table.
  `get_records` does not fold (`HighscoreTable.gd:130-132`); pass a folded rank (`HighscorePanel.gd:26`).
  A score of 0 is never a highscore (`HighscoreTable.gd:43`).
- `HighscoreTableTest.gd:5-16,52` passes plain Dictionaries where `HighscoreTable` takes `MapInfo`; it is not in CI.
- `PlayCount.get_last_difficulty` returns the `favorite` value, not `last_difficulty` (`PlayCountTable.gd:72-79`;
  caller `BeepSaberMainMenu.gd:347`). Known bug: report, don't fix in an unrelated change.
- Controller buttons are read in `_physics_process` only while `get_is_active()`; the first active frame is read
  twice to swallow stale `just_pressed` (`BeepSaberController.gd:96-107`). `trigger` = `trigger` or `select_button`
  (`BeepSaberController.gd:60`). Pico 4 profile (`openxr_action_map.tres:1414`): `ax_button` = A/X, `by_button` = B/Y,
  `menu_button` = left menu only, `select_button` = system click, `trigger` = trigger value.
- Collision layers: `*_bit` are 0-based, but `set_collision_layer_value` / `set_collision_mask_value` take 1-based
  layer numbers. `BeepCube.gd:88-93` and `LightSaber.gd:115-118` (via `SwingableRayCast._set_collision_mask_value`)
  pass `*_bit` directly, so notes use layers 9/10 and bombs layer 5 (`Bomb.tscn:63` = 16), one below the
  `project.godot` `[layer_names]` (LeftNote 10, RightNote 11, Bombs 6). Self-consistent: change both sides or neither.
- UI pointer: `UIRaycast` casts only when `active and visible` (`UIRaycast.gd:63`). Game states set `visible`;
  the `left_handed` setting picks which hand is `active` (`BeepSaber_Game.gd:369-375`). Its `RayCast3D` hits areas
  only, mask `524290` = layers 2 (UI) and 20 (`UIRaycast.tscn:26-28`). Targets must extend `UIRaycastTarget`
  or they are ignored (`UIRaycast.gd:29`); buttons sit on layer 2 (`UIRaycastButton.tscn:32`, `EndScore.gd:20-23`).
- `SwingableRayCast` builds its sub-rays one physics frame after `_ready`, copying the mask then
  (`SwingableRayCast.gd:29-43`); later mask changes must go through `_set_collision_mask_value` (`:55-61`).
  It only runs while `enabled`, toggled by `LightSaber.set_swingcast_enabled` (`LightSaber.gd:220`).
- Pools: `presize` works once (`ScenePool.gd:24-26`); `acquire` grows the pool when empty (`:32-37`). Return nodes
  with `PooledNode3D.release()` (double release only warns, `PooledNode3D.gd:14-20`). Never `queue_free` a pooled
  node; pooled scenes must have a `PooledNode3D` root.
- `SongUploader` listens on port 45800 (`song_uploader.gd:7,24`) and serves each connection synchronously in
  `_process` with busy-wait loops (`:53-60,78-80`): an upload stalls frames, and the header loop has no disconnect
  check. Uploads are saved by magic bytes to `APPDATA_PATH` `Songs/*.zip` or `Backgrounds/*.jpg|png` (`:170-180`).
- `MixedReality` reaches nodes by absolute `/root/BeepSaber/...` paths (`MixedReality.gd:19-39`); renaming those
  nodes in `BeepSaber_Game.tscn` breaks it at runtime.
- `HTTPRequestPool` re-issues a queued request through `request()`, which assigns a new token (`HTTPRequestPool.gd:55-58`).

## Where to change X

- New persistent per-map data: extend `PlayCountTable.gd` and keep its JSON shape backward compatible.
- New highscore modifier: add a bit in `game/Constants.gd` and fold it in `HighscoreTable.get_rank_key`; old
  records then stop matching the new key.
- New controller button: add the action to `openxr_action_map.tres` (keep the Pico rules in the root
  `AGENTS.md`), then read it in `BeepSaberController._update_buttons_and_sticks`.
- New pooled object: add a `ScenePool` node to `BeepSaber_Game.tscn`, wire `new_scene_instanced`, add a
  `GlobalReferences` var and presize it in `BeepSaber_Game._ready`.
- New 3D UI control: extend `UIRaycastTarget`, put it on layer 2.

Test: `godot --headless --path . res://tests/test_map_info.tscn` (covers map parsing only). Input, raycasts,
haptics, pools, MR and uploads need a headset run with `adb logcat`.
