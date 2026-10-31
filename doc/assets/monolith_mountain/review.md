# Review report: Monolith mountains
- Ticket / branch / commit: Bored, 2026-10-31 / `claude/project-thread-xntzut` (from `pico4-offline` 296084f)
- Blender and Godot versions: as `doc/assets/monolith_cloud/review.md`.
- Changed files: `tools/models/monolith_mountain.py`, `game/models/monolith_mountain_0..5.glb`,
  `game/env/MonolithRig.gd`, `game/env/MonolithRidge.gdshader`.
- Source / export / preview paths: script above; `.glb` in `game/models/`; `previews/review_views.png`,
  `previews/uv_checker.png`; in game: `doc/assets/monolith_cloud/previews/ingame.png`.
- Commands actually run and exit codes: as the clouds' report, with `tools/models/monolith_mountain.py` (0).

Rounds: first pass -> critic round 1 (open sheet edges, the same symmetric cone everywhere, triangles wasted on the
back, sliver triangles) -> edges fade to 0, per-peak flank and lean, slow shoulder noise, front half only, cells
split along the shorter diagonal.

| Check | Result: PASS / WARN / FAIL / NOT CHECKED | Evidence / notes |
|---|---|---|
| Reference fidelity | NOT CHECKED | No picture reference; shapes follow the brief. |
| Silhouette / proportions | PASS | Six different outlines (dome to spire, single to triple peaks); rings read as layers in the captures. |
| Geometry / normals / transforms | PASS | No flipped or zero-area faces; flat normals per facet. |
| UVs | PASS | No flipped UV faces; 90% within 21% of the median density. Not used in game. |
| Materials / lighting | WARN | Facets lit toward the slab's glow read; values untuned. |
| Gameplay readability | PASS | No mountain vertex within 320 m (fronts pushed out), none touching the slab, the valley's line open (none under 80 m tall). |
| Godot import / resource paths | PASS | As the clouds. |
| In-engine visual inspection | WARN | Desktop captures only. |
| Performance budget | NOT CHECKED | 10.9k triangles, 4 slices round the player. GPU not measured on the Pico. |
| Scope / no unrelated changes | PASS | |

Known limitations / assumptions: low-poly faceted style is my reading of "3D like the clouds"; no far-edge blur on
the peaks yet (AGENTS.md "Soft far edges").
Human decision: pending (Bored)
Reviewer / date: critic agent + in-game captures, 2026-10-31
