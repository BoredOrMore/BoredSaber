# Review report: drive gears

- Ticket / branch / commit: Metal Factory stage / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (local import and CI)
- Changed files: `game/models/drive_gear_large.glb`, `game/models/drive_gear_small.glb`, `game/env/MetalFactoryRig.gd`,
  `game/event_driver.gd`, `doc/assets/drive_gear/`, `doc/world/SPATIAL_LAYOUT.md`, `doc/world/AUDIO_VISUAL_MAPPING.md`
- Source / export / preview paths: `tools/models/gears.py` / `game/models/` / none: Blender and the Godot editor left
  open on the dev Mac for the owner
- Commands actually run and exit codes:
  - `blender -b -P tools/models/gears.py -- game/models` → 0; drive_gear_large 436, drive_gear_small 346 triangles
  - `godot --headless --import --path .` → 0; `res://tests/test_show_intensity.tscn` → 0 failures
  - `stage_capture --map Psycho --env metal_factory --start 14` with a temporary print (not committed): intensity 0
    until 16.5 s, then rising (0.42 at 18 s) while the large gear starts to turn

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images |
| Silhouette / proportions | PASS | owner, in Blender, the Godot editor and `stage_capture --map` (2026-10-25) |
| Geometry / normals / transforms | PASS | front and edges only; normals recalculated; origin at the centre |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | far end, beside and below the horizon, outside the note corridor |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | PASS (desktop) | owner, `stage_capture --map`; headset not yet |
| Performance budget | PASS | 1564 triangles for four, two MultiMeshes; four transforms a frame |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: the large and small gears overlap in depth rather than truly meshing (as in the
blockout); they turn at matched speeds as if meshed.
Human decision: APPROVED (owner, 2026-10-25); headset still to come
Reviewer / date: owner, 2026-10-25
