# Review report: gear ring

- Ticket / branch / commit: Metal Factory stage / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/gears.py`, `game/models/gear_ring.glb`, `game/env/MetalFactoryRig.gd`,
  `game/event_driver.gd`, `doc/assets/gear_ring/`, `doc/world/SPATIAL_LAYOUT.md`, `doc/world/AUDIO_VISUAL_MAPPING.md`
- Source / export / preview paths: `tools/models/gears.py` / `game/models/` / none: Blender and the Godot editor left
  open on the dev Mac for the owner
- Commands actually run and exit codes:
  - `blender -b -P tools/models/gears.py -- game/models` → 0; gear_ring 180 triangles (a first version with separate
    faces per tooth edge had 288)
  - `godot --headless --import --path .` → 0; `res://tests/test_show_intensity.tscn` → 0 failures; a `stage_capture`
    smoke run of Metal Factory → OK, rings drawn, clear of the corridor

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images |
| Silhouette / proportions | NOT CHECKED | owner, in Blender and the Godot editor |
| Geometry / normals / transforms | PASS | front and edges only (never seen from behind); normals recalculated; origin at the centre |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | inner edge 6.2 m from the track's axis, outside the note corridor |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | NOT CHECKED | owner; the spin needs a map with ring events (or the headset) |
| Performance budget | PASS | 180 triangles, 1080 for six, one MultiMesh; six transforms a frame while spinning |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: rings pass through the floor as they turn (as in the blockout); no back faces.
Human decision: pending (owner)
Reviewer / date:
