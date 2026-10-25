# Review report: track end stop

- Ticket / branch / commit: track and platform plan T4 / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS; Godot 4.6.2 (local import and CI)
- Changed files: `tools/models/track_end.py`, `game/models/track_end.glb`, `game/env/TrackDeck.gd`,
  `game/event_driver.gd`, `doc/assets/track_end/`, `doc/world/SPATIAL_LAYOUT.md`
- Commands actually run and exit codes: `blender -b -P tools/models/track_end.py -- game/models` → 0, 14 triangles;
  `godot --headless --import --path .` → 0; a `stage_capture` of Classic down the track → the stop in place, the strips
  ending at it; the old Endpath then still rose over the horizon, so it shows only with the old track.

| Check | Result | Evidence / notes |
|---|---|---|
| Silhouette / proportions | NOT CHECKED | owner |
| Geometry / normals / transforms | PASS | normals recalculated; ends capped; back open (never seen) |
| Gameplay readability | PASS | behind where notes and walls appear; top 0.5 m, below the horizon |
| Godot import / resource paths | PASS | local import; CI after push |
| In-engine visual inspection | NOT CHECKED | owner |
| Performance budget | PASS | 14 triangles, one draw call; GPU not measured (no headset on the Mac) |

Human decision: pending (owner)
Reviewer / date:
