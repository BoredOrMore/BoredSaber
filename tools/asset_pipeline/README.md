# Asset pipeline (Claude + Blender)

The owner's "Claude + Blender Rhythm Game Pipeline" kit (2026-10-24), placed here for making assets: models, props,
fixtures, effects. `agents/`, `docs/`, `templates/`, `blender/` and `tools/` are the kit as given; this README,
`AGENTS.md` and `config/pipeline.json` are adapted to BoredSaber. The repo's own rules win where they differ
(root `AGENTS.md`, `game/AGENTS.md`, and the game-model-creator, shader-design and rhythm-world-design skills).
`.gdignore` keeps Godot out of this folder.

## Where things go
- Model source: a build script per model in `tools/models/` (reproducible; it rebuilds the `.blend`), output
  `.glb` in `game/models/`.
- Records per asset: `doc/assets/<asset>/` with `spec.md` (from `templates/asset_spec.md`), `review.md` (from
  `templates/review_report.md`), `previews/` (the review renders) and `references/` when there are any.
- Scenes and layouts: a scene spec (`templates/scene_spec.md`) in `doc/world/` next to the world records.

## Stages (`docs/production_stages.md`)
Discovery → brief (spec) → blockout → fixed review renders → detail and materials → export → CI import → headset
review by the owner → integration (push to `pico4-offline`, PR into `godot-4-port`).

## Commands
Review renders of an exported model (the cameras sit 8 m out with a 4 m view; scale them to the asset):
```sh
blender -b --python-expr "import bpy; bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath='game/models/<asset>.glb')" \
  -P tools/asset_pipeline/blender/build_review_cameras.py \
  --python-expr "import bpy; from mathutils import Vector; [setattr(o.data, 'ortho_scale', 1.2) for o in bpy.data.objects if o.type == 'CAMERA']" \
  -P tools/asset_pipeline/blender/render_review_views.py -- --out doc/assets/<asset>/previews
```
`doc/assets/laser_fixture/review.md` records the exact command used for the fixture.

## In-game captures (no headset needed)
`tools/capture/stage_capture.tscn` renders a stage on the Mac with the game's own scenery, lights and shaders from
the player's eye; build-up, light colours, eye height, view direction and size are options (see the script's
header). Use it for the in-engine views of a review before the headset check; the Pico's LCD shows colour and
brightness somewhat differently, so the headset stays the final word.
```sh
godot --path . res://tools/capture/stage_capture.tscn -- --out /tmp/classic.png --env classic --built 0.5 --left 3d7bff --right ff3d5a
```

## What isn't available here
- Godot 4.6.2 (same as CI) is at `/Applications/Godot_4.6.2.app`, command `godot`: import and tests run locally
  (`test_menu_layout`'s two pointer-drag checks fail on macOS headless but pass in CI). CI stays the gate for the
  APK; logcat on the headset after install.
- `tools/compare_silhouettes.py` needs Pillow, which isn't installed (installing it is a download; ask first).
- One agent does the work here, so the roles in `agents/` are hats worn in turn, not parallel sessions; the
  worktree advice in `docs/git_worktrees.md` applies only if the owner asks for parallel work.
