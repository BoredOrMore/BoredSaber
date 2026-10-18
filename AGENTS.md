# Agent guidelines

BoredSaber is a Godot 4.6 (GDScript) Beat Saber-style game for standalone Pico 4, based on Open Saber Plus.

## Repository map

Each folder below has its own `AGENTS.md` with a file map, gotchas and "where to change X" recipes.
Read the one for the folder you are changing before editing.

- `game/`: main scene, autoloads, note/bomb/chain/arc/wall/saber entities, assets in `game/data/`.
- `game/scripts/`: shared scripts (utils, controllers, highscores, pools, raycasts, song uploader).
- `game/scripts/GameState/`: the game state machine (menu, playing, paused, fail, score screen).
- `game/BeatmapInfo/`: beatmap data model and how `game/Map.gd` parses Beat Saber map formats.
- `game/ui/`: menus, shared theme and UI palette, BeatSaver download panels.
- `OQ_Toolkit/`: partially ported VR toolkit (`vr` autoload, 2D-in-VR canvases, keyboard).
- `tests/`: headless tests.
- `.github/`: CI build, APK release and how to test a build on the headset with adb.
- `addons/`: not tracked; CI installs godot_openxr_vendors there.

## Rules

- Keep diffs minimal: touch only the files the change needs. No unrelated
  refactors, renames or reformatting, they hide the real change from review.
  This includes files the Godot editor rewrites on its own (`.uid`, `.import`,
  resaved `.tscn`/`.tres`): revert or delete them unless the change needs them.
  If you spot an unrelated problem, report it instead of fixing it.
- Match the neighbouring files: naming (`snake_case` functions and variables,
  `PascalCase` `class_name`), static typing, comment density, and how logic is
  split between scenes (`.tscn`) and scripts (`.gd`).
- Write the simplest code that solves the current task. Keep a function next
  to its only caller; extract a shared abstraction on the third use, not
  before. Never create new generic helper/utils scripts, and don't grow the
  existing `game/scripts/Utils.gd` with code that has one caller.
- Fail fast on internal invariants: use `assert()` or `push_error()` and
  return, with no fallbacks or defaults for states that should not happen. Do
  validate at boundaries: map files (`Info.dat` and difficulty files), BeatSaver
  and other network responses, the saved `config.ini`, and OpenXR runtime
  capabilities.
- Every function gets a `##` doc comment saying what it does or returns, not how.
- Every number that sets behaviour gets an `UPPER_CASE` `const` at the top of
  its script. Values the player can change go in `game/Settings.gd`
  (`default_values`, plus a control in `game/settings_Panel.tscn`); engine and
  XR values go in `project.godot` or the scene that owns them.
- Ask before adding a new dependency (Godot addons, plugin or engine version
  bumps, GitHub Actions).
- Never bypass git hooks (`--no-verify`) and never weaken or delete a test
  to make it pass; fix the cause.
- One logical change per commit. Push only when the user asks.

## Pico 4 constraints

Found from headset logs on Pico OS 5.12 (OpenXR runtime 2.1.12); don't undo them without testing on the headset.

- Renderer stays Compatibility (`gl_compatibility`): the Vulkan path segfaults inside the Pico runtime at startup.
- `xr/openxr/target_api_version` stays `1.0.0`, and the Pico profiles in `openxr_action_map.tres` must not bind
  `grip_surface/pose`: the runtime rejects the path and drops the whole profile, so the controllers stop tracking.
- Builds are signed with `.github/debug.keystore` so new APKs install over old ones; don't regenerate it.

## Checking a change

- Map parsing tests: `godot --headless --path . res://tests/test_map_info.tscn` (exits non-zero on failure).
- `.github/workflows/build-pico4.yml` imports the project, runs the tests and exports the APK on every push.
  Pushes to `pico4-offline` or the default branch also replace the `pico4-latest` release, which the headset
  browser downloads from.
- Anything touching XR, input or rendering needs a test on the headset, with `adb logcat` when it misbehaves.
