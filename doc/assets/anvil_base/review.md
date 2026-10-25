# Review report: anvil

- Ticket / branch / commit: Metal Factory stage / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/anvil_base.py`, `game/models/anvil_base.glb`, `game/env/MetalFactoryRig.gd`,
  `doc/assets/anvil_base/`, `doc/world/SPATIAL_LAYOUT.md`
- Source / export / preview paths: `tools/models/anvil_base.py` / `game/models/` / none: the owner checks in Blender and
  the Godot editor, left open on the dev Mac (owner's preference, 2026-10-25)
- Commands actually run and exit codes:
  - `blender -b -P tools/models/anvil_base.py -- game/models` → 0; prints 68 triangles, die top 1.50 m, 0.20 m wider
    than the hammer's face, shelf 1.20 m
  - `godot --headless --import --path .` → 0; `res://tests/test_show_intensity.tscn` → 0 failures

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images |
| Silhouette / proportions | PASS | owner, in Blender and the Godot editor ("good", 2026-10-25) |
| Geometry / normals / transforms | PASS | flat shading, origin on the floor; die top at the hammer's landing height (1.5 m) |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | same place as the blockout's anvils (x ±8), outside the note corridor |
| Godot import / resource paths | PASS | local import with Godot 4.6.2; CI import and export succeed (commit 8a6f99e) |
| In-engine visual inspection | PASS (desktop) | owner, Godot editor viewport (event_driver.tscn); headset not yet |
| Performance budget | PASS | 68 triangles, 680 for ten, one MultiMesh (one more draw call) |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: occlusion is baked on the anvil alone; the hammer doesn't darken it.
Human decision: APPROVED (owner, 2026-10-25); headset still to come
Reviewer / date: owner, 2026-10-25
