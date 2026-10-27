# Review report: wall machinery kit

- Ticket / branch / commit: Metal Factory stage / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/wall_kit.py`, `tools/models/model_export.py`, `game/models/wall_*.glb`,
  `game/env/MetalFactoryRig.gd`, `doc/assets/wall_kit/`, `doc/world/SPATIAL_LAYOUT.md`
- Source / export / preview paths: `tools/models/wall_kit.py` / `game/models/` / none: Blender and the Godot editor left
  open on the dev Mac for the owner
- Commands actually run and exit codes:
  - `blender -b -P tools/models/wall_kit.py -- game/models` → 0; column 48, panel 108, pipes 72, machine 100,
    machine_low 100 triangles. A first layout stacked the pipes; they would have run into the tall machine's tank and
    the catwalk, so they now lie side by side.
  - `godot --headless --import --path .` → 0; `res://tests/test_show_intensity.tscn` → 0 failures (a first run caught
    an untyped variable in the rig, fixed); a `stage_capture` look along the left wall → pieces in place

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images |
| Silhouette / proportions | NOT CHECKED | owner, in Blender and the Godot editor |
| Geometry / normals / transforms | PASS | normals recalculated; origins at the back; right wall turned half round |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | walls at x ±15-18, far outside the note corridor |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | NOT CHECKED | owner |
| Performance budget | PASS | 4,712 triangles in five MultiMeshes (five draw calls) |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: no breathing motion yet; the older model scripts still carry their own copy of the
bake and export code (model_export.py is new with this kit).
Human decision: pending (owner)
Reviewer / date:
