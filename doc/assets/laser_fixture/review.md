# Review report: laser fixture

- Ticket / branch / commit: Classic stage look / `pico4-offline` / this commit
- Blender and Godot versions: Blender 5.2.2 LTS (dev Mac); Godot 4.6.2 in CI only
- Changed files: `tools/models/laser_fixture.py`, `game/models/laser_fixture.glb`, `game/models/laser_fixture_yoke.glb`
- Source / export / preview paths: `tools/models/laser_fixture.py` / `game/models/` / `doc/assets/laser_fixture/previews/`
- Commands actually run and exit codes:
  - `blender -b -P tools/models/laser_fixture.py -- game/models` → 0; prints head 198, yoke 76 triangles, foot 0.540 m
  - review renders (import both `.glb`, `build_review_cameras.py`, cameras scaled to 1.2 m and pulled to a quarter of their distance, `render_review_views.py --out doc/assets/laser_fixture/previews`) → 0, four renders, then shrunk to 640 px

| Check | Result | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | no reference images; style frame only |
| Silhouette / proportions | PASS | owner on the headset: size halved, then accepted; previews |
| Geometry / normals / transforms | PASS | first review render showed the yoke's cross bar baked fully black (its ends were buried in the arms); bar now ends at the arms, re-rendered clean |
| Materials / lighting | WARN | in-game lens and glow seen only at a distance; no close-up headset capture |
| Gameplay readability | PASS | outside the note corridor (x ±4.5 and ±12.4 m) |
| Godot import / resource paths | PASS | CI import and export succeed; no script or shader errors in logcat after install |
| In-engine visual inspection | PASS | owner, Pico 4: size, yoke fixed, head tilting with the beam, staying when lights are off |
| Performance budget | WARN | GPU 7.4–9.7 ms of 11.1 ms in a song at 90 Hz with everything on; no before/after bench for the fixture alone |
| Scope / no unrelated changes | PASS | only the files above change for the bar fix |

Known limitations / assumptions: occlusion is baked per part, so the head doesn't darken the yoke or the other way round.
Human decision: APPROVED for the shape and motion (owner, 2026-10-24); the bar fix needs a look on the headset.
Reviewer / date: owner, 2026-10-24
