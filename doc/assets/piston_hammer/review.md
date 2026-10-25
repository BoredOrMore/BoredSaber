# Review report: piston (housing and hammer)

- Ticket / branch / commit: Metal Factory stage / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 (CI imports)
- Changed files: `tools/models/piston_hammer.py`, `game/models/piston_housing.glb`, `game/models/piston_hammer.glb`,
  `doc/assets/piston_hammer/`
- Source / export / preview paths: `tools/models/piston_hammer.py` / `game/models/` / `doc/assets/piston_hammer/previews/`
- Commands actually run and exit codes:
  - `blender -b -P tools/models/piston_hammer.py -- game/models` → 0; prints housing 156, hammer 94 triangles
    (284 for the housing at first, with every edge bevelled; now only the plate is)
  - review renders: both `.glb` imported, housing moved up 2.6 m and hammer down 2.6 m (assembled, hammer raised),
    Workbench with studio light and a plain grey colour (the factory scene has no lights, so the first renders were
    black; vertex colour shows the occlusion only in red), `build_review_cameras.py` with ortho scale 11 and the 3/4
    camera 1.7 times as far, `render_review_views.py --out doc/assets/piston_hammer/previews` → 0, four renders,
    shrunk to 640 px

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images; blockout captures only |
| Silhouette / proportions | PASS | previews: plate, banded barrel, gland, rod, neck, chamfered head read at review scale |
| Geometry / normals / transforms | PASS | flat shading, normals recalculated on the hammer; origins as specified |
| Materials / lighting | NOT CHECKED | occlusion baked but not yet read by a game shader |
| Gameplay readability | PASS | stays where the blockout's piston stood (x ±8), outside the note corridor |
| Godot import / resource paths | NOT CHECKED | CI import after push |
| In-engine visual inspection | NOT CHECKED | not in the rig yet |
| Performance budget | PASS | 250 triangles per piston, 2.5k for ten (plan estimate 180 per piston) |
| Scope / no unrelated changes | PASS | only the files above |

Known limitations / assumptions: occlusion is baked per part, so the housing doesn't darken the rod.
Human decision: pending (owner)
Reviewer / date:
