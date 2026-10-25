# Review report: track edge

- Ticket / branch / commit: track and platform plan / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/track_edge.py`, `game/models/track_edge.glb`, `game/env/TrackDeck.gd`, `doc/assets/track_edge/`
- Source / export / preview paths: `tools/models/track_edge.py` / `game/models/` / none: Blender and the Godot editor
  left open on the dev Mac for the owner
- Commands actually run and exit codes:
  - `blender -b -P tools/models/track_edge.py -- game/models` → 0; 40 triangles (30 with one end cap: the left edge,
    turned half round, showed its open end to the player, so both ends are capped)
  - `godot --headless --import --path .` → 0; a `stage_capture` of Classic → the edges in place, strips in their channels

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images |
| Silhouette / proportions | NOT CHECKED | owner |
| Geometry / normals / transforms | PASS | normals recalculated; both ends capped; stretched only along the extrusion |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | outside the lanes (from 1.2 m out at normal width); below the notes' rows |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | NOT CHECKED | owner |
| Performance budget | PASS | 80 triangles for both edges, one draw call; GPU not measured (no headset on the Mac) |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: the skirt is 1.5 m deep on every stage; where a stage's floor is at the track's
height (Metal Factory) it runs into the floor.
Human decision: pending (owner)
Reviewer / date:
