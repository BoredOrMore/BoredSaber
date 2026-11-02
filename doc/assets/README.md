# Asset records

One folder per asset, made with the asset pipeline (`tools/asset_pipeline/`):
- `spec.md`: the brief (`tools/asset_pipeline/templates/asset_spec.md`).
- `review.md`: the review report (`tools/asset_pipeline/templates/review_report.md`).
- `previews/`: the fixed review renders (front, side, top, three-quarter).
- `references/`: reference images, when there are any.

- `spec.json`: what the runner checks (below); `spec.md` stays the brief in words.
- `run/`: the runner's last round (gitignored).

## Runner (owner, 2026-11-02)

`tools/models/run_asset.py <asset>` does a whole round in one command: build, checks, Godot import, a 640 px contact
sheet (front, side, top, three-quarter) and `run/report.md`, one PASS / FAIL / NOT CHECKED line per check. Read the
report and the contact sheet, not the logs, unless a line says FAIL without enough to act on. Each round adds a line
to `runs.csv` (when, asset, commit, triangles, result, seconds), so rounds per asset can be counted.

`spec.json` fields (sizes in metres, Godot axes x, y up, z toward the player):

| Field | Needed | Meaning |
|---|---|---|
| `asset` | yes | the folder name |
| `script` | yes | the build script, e.g. `tools/models/ac_unit.py`; it takes the output folder after `--` |
| `outputs` | yes | the `.glb` names it writes |
| `budget_tris` | yes | the triangle limit per output |
| `note_path` | yes | `none` (not placed in a stage), `standard` (the corridor ahead) or `all` (nothing within 320 m, for 90/360 stages) |
| `placements` | with `note_path` | per output, a list of `[x, y, z, yaw_deg]` or `[x, y, z, yaw_deg, scale]` where the stage puts copies |
| `size_m` | no | per output, the expected `[x, y, z]` size; checked within 5% |
| `vertex_colour` | no | default true: every mesh needs vertex colour |
| `textures_allowed` | no | default false; true only with the owner's OK (Monolith's cloud height map was one) |
| `out_dir` | no | default `game/models` |
| `status` | no | `blockout`, `refine`, `in_game` or `done` |
| `owner_pick` | no | the blockout variant the owner chose |
| `refs` | no | reference ids (`R01`...) to what each one shows; say "matches R02" instead of re-describing |

| Asset | Status |
|---|---|
| `laser_fixture/` (moving head and yoke) | in the game; owner checked size and motion on the headset |
