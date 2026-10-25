---
name: game-model-creator
description: How to make a 3D model for BoredSaber (scenery pieces, light fixtures, saber handles, bombs, props) with Blender driven by Python scripts or with code in Godot, within the Pico 4's budget. Use before adding or replacing any mesh, and when proposing a new model to the user.
---

# Game models for BoredSaber

Adapted from the "Game Model Creator — Godot" skill the owner provided (2026-10-24), with this game's
rules added: Pico 4 budget, unshaded fake-lit shaders, shared materials. Read `.claude/skills/shader-design/SKILL.md`
too: a model is only half the look, its shader is the other half.

Run every asset through the asset pipeline in `tools/asset_pipeline/` (the owner's Claude + Blender kit): its stages
and gates, a spec and a review report per asset in `doc/assets/<asset>/`, and its review renders. This skill's
rules win where they differ.

## 1. Spec first

Before building, write down and show the user (or put on the style frame):
- purpose and where it stands (scene, node, how far from the player, seen from which side)
- size in metres (1 unit = 1 m), pivot (a fixture's pivot is where the light leaves it, `game/AGENTS.md`),
  which way is forward
- silhouette: what shape reads at the distance the player sees it from
- budget: triangles (small props under 500, a repeated scenery piece under 200 per copy, everything in a
  scene's view well under 50k), one material, no texture unless the look needs it (then 256 px or less)
- collision: none for scenery; simple shapes (box, capsule) for anything cut or hit
- acceptance: how it should look on the headset next to the style frame

## 2. Pick the method

- **Code in Godot** (`ArrayMesh`, `SurfaceTool`, `BoxMesh` in a `MultiMesh`): boxes and simple repeated
  pieces, anything whose size comes from game data. See `game/env/ClassicRig.gd`, `CutFlash.spark_mesh()`.
- **Blender by script**: bevels, rounded or detailed shapes, UVs, baked shading. Never edit by hand in the
  GUI: every model has a script that rebuilds it from nothing, so it can be changed and checked in review.
  Sculpting needs a person; ask the user.
- **Hand-written `.obj`**: tiny flat meshes (`game/data/ring.obj`).
- Models from outside (downloads, the user's files): record source and licence in the script's header or
  next to the file; no branded or copyrighted characters without rights.

## 3. Blender by script

- Blender 5.2 is at `/opt/homebrew/bin/blender` on the dev Mac. Run headless:
  `blender -b -P tools/models/<name>.py -- <output dir>`.
- Scripts live in `tools/models/`, one per model, starting from `read_factory_settings(use_empty=True)`,
  with every size as a named constant in metres at the top (same rule as shader knobs).
- Export glTF binary (`.glb`) into `game/models/<name>.glb`, Y up, applied modifiers and transforms,
  no cameras or lights, no materials the game won't use.
- Bake shading the game can use cheaply: ambient occlusion and bevel highlights baked into **vertex
  colours** (bake target vertex colours), read in the shader as `COLOR`. A texture costs a read per pixel
  and memory; vertex colours cost nothing extra. Bake to a texture only when the detail is finer than
  the mesh.
- Vertex colour channels (EnvSolid reads them): red is the baked ambient occlusion, which darkens every model in the
  scenery shader (layer 7); green and blue are glow masks a model may mark (Metal Factory's vents: green the upper
  row, blue the lower, layer 6); alpha is unused. `tools/models/model_export.py` writes them. A mesh without vertex
  colours reads white, so it is neither darkened nor lit.
- Keep normals clean (shade flat for hard metal, smooth by angle for rounded), no loose or duplicate
  vertices, faces pointing out. Print the triangle count at the end of the script.

## 4. Into the game

- Import settings: no generated lightmaps or LODs unless measured useful; the mesh only, materials
  replaced by the game's.
- Material: one shared `ShaderMaterial` per kind of object, using the game's unshaded shaders
  (`EnvSolid.gdshader` for scenery, or a new one built per the shader-design skill). Never
  `StandardMaterial3D` with real lights: the scene has none, and lighting costs the Pico.
- Many copies: one `MultiMeshInstance3D`, not many nodes. Shadows off (`cast_shadow` off).
- Pooled gameplay objects (notes, bombs, chains) follow the pooling rules in `game/AGENTS.md`.

## 5. Check it

1. Run the Blender script; it must finish without errors and print the triangle count within budget.
2. Push; CI imports the project and builds the APK (no local Godot). Read logcat after install for
   import, shader or script errors.
3. On the headset: scale, pivot, which way it faces, silhouette at play distance, shading next to the
   style frame. Anything that moves the playspace follows the playspace rule in `game/AGENTS.md`.
4. GPU before and after with `tools/bench.sh`; report triangles and ms.
5. Report: what was made, where the files are, what was checked on the headset and what wasn't.
   Never say a model is done, or that Godot ran, without having seen it.
