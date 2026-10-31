# Review report: Monolith clouds
- Ticket / branch / commit: Bored, 2026-10-31 / `claude/project-thread-xntzut` (from `pico4-offline` 296084f)
- Blender and Godot versions: Blender 5.2.2 LTS (Python module `bpy`, headless, in the cloud container); Godot
  4.6.2-stable (Linux, headless import and tests; captures through Xvfb with the Compatibility renderer, Mesa).
- Changed files: `tools/models/monolith_cloud.py`, `tools/models/model_export.py` (smooth, green, unwrap),
  `game/models/monolith_cloud_0..5.glb`, `game/env/MonolithRig.gd`, `game/env/MonolithCloud.gdshader`,
  `game/env/MonolithCloudEdge.gdshader` (removed).
- Source / export / preview paths: script above; `.glb` in `game/models/`; `previews/review_views.png` (front, side,
  top, three-quarter per variant), `previews/uv_checker.png`, `previews/ingame.png` (ahead, down, left, right,
  behind, and the old flat rings for comparison).
- Commands actually run and exit codes: `python -c "import bpy; ..." tools/models/monolith_cloud.py -- game/models`
  (0); Godot `--headless --import` (0); `tests/test_map_info`, `test_menu_layout`, `test_song_search` (0 each);
  `tools/check_agent_docs.py` (0); `tools/capture/stage_capture.tscn -- --env monolith --lights on` (0).

Rounds: first pass (voxel remesh + decimate) -> critic round 1 (torn faces, puffs melted into one blob, weak top
relief, same recipe for all six, ragged base) -> rebuilt as separate overlapping puffs with hidden faces removed,
bumps on bumps, a different tallest part per variant -> in game: banks first read as rocks (too sparse), then as
squeezed crystals, then as one cloud sea (two rows per band, foot sunk below the band, 1.3x wider than tall).

| Check | Result: PASS / WARN / FAIL / NOT CHECKED | Evidence / notes |
|---|---|---|
| Reference fidelity | WARN | Layered round puffs with creases like the reference; the bright rims of the reference are weak in game (rim tone close to the lit tops). |
| Silhouette / proportions | WARN | Six different banks, no shape repeats in the captures; up close (80 m band) the 8-segment puffs show polygon outlines. |
| Geometry / normals / transforms | PASS | No flipped or zero-area faces (UV check script), normals kept square under the rig's uneven scale (inverse transpose). |
| UVs | PASS | Smart project; no flipped UV faces; 90% of faces within 31% of the median texel density. Not used in game (vertex colour). |
| Materials / lighting | WARN | Vertex red (AO 0-1) and green (height 0-1) read in Godot; untuned: large purple area when the lights are on (AGENTS.md comfort rule: large areas low in saturation). |
| Gameplay readability | PASS | Nothing within 320 m above y -6 (check script: 0 vertices); the note path stays clear; no bank crosses the slab. |
| Godot import / resource paths | PASS | Headless import clean for the new files; tests pass. |
| In-engine visual inspection | WARN | Desktop captures only (Mesa, 90 degree view); not seen on the headset. |
| Performance budget | NOT CHECKED | 49.9k cloud triangles (60.8k with the mountains), 4 slices per band so about half is drawn; 24 cloud + 4 mountain draw calls, about half in view (was 18). GPU not measured on the Pico. |
| Scope / no unrelated changes | PASS | Only the Monolith clouds and mountains, their scripts and docs. |

Known limitations / assumptions: the soft see-through fringe the owner asked for on the flat clouds is gone; the
rim brightening at grazing angles stands in for it (to check on the headset). Drift is 1.5 m/s round the player,
0.7-1.3x per band, untuned.
Human decision: pending (Bored)
Reviewer / date: critic agent + in-game captures, 2026-10-31
