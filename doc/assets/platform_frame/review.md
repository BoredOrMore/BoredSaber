# Review report: platform frame

- Ticket / branch / commit: track and platform plan P1, P4 / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS; Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/platform_frame.py`, `game/models/platform_frame.glb`, `game/env/TrackDeck.gd`,
  `doc/assets/platform_frame/`, `doc/world/SPATIAL_LAYOUT.md`
- Commands actually run and exit codes: `blender -b -P tools/models/platform_frame.py -- game/models` → 0, 32
  triangles; `godot --headless --import --path .` → 0; a `stage_capture` of Classic looking down at the platform → the
  deck running into it, the ring round the pad with the border lights in its channel, the edges along its sides.

| Check | Result | Evidence / notes |
|---|---|---|
| Silhouette / proportions | NOT CHECKED | owner |
| Geometry / normals / transforms | PASS | mitred corners, normals recalculated, top at y 0 |
| Gameplay readability | PASS | the pad and its lights unchanged in place and colour |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | NOT CHECKED | owner; headset |
| Performance budget | PASS | 32 triangles and four boxes; GPU not measured (no headset on the Mac) |

Known limitations / assumptions: the edge light strips still start 1.4 m ahead of the platform (their meshes are
unchanged), so the channel along the platform's sides is unlit; the pad stays the burn marks' black plane.
Human decision: pending (owner)
Reviewer / date:
