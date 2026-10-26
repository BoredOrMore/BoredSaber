---
name: rhythm-world-design
description: Standard for designing or changing BoredSaber's environments (Classic, Neon Grid, Night City, Pulse Void, Metal Factory, and any new one) and anything placed in them - structure, fixtures, lights, music-reactive effects, scene evolution during a song (build-up, drop), generated layouts. Use before any environment or scene-layout change, and when proposing one to the user.
---

# Rhythm-world design for BoredSaber

From the owner's "Godot Rhythm-World Agent Suite" (2026-10-24), adapted to this game. The focused rules are in
`rules/` next to this file; the project's filled-in design records are in `doc/world/`. Where this skill or its
`rules/` disagree with the repo's own rules (root `AGENTS.md` "Light", "Colour rules", "Pico 4 constraints";
`game/AGENTS.md` playspace rule), the repo's rules win. If the suite's way would be clearly better, or at least no
slower on the headset, suggest the change to the owner with the reason and the GPU numbers; don't apply it on your
own (the owner's decision, 2026-10-24).

Goal: an original, polished, music-driven performance space in the spirit of Beat Saber, never a copy of its assets
or levels. Readable during fast play first, beautiful second, and cheap enough for the Pico 4.

## 1. Non-negotiable
1. Gameplay readability beats decoration: notes, sabers, walls and bombs are always the brightest, clearest things.
2. Every visible thing earns its place: gameplay, composition, atmosphere, rhythm or progression.
3. Minimal on purpose, not unfinished.
4. Placed by a spatial rule (rig scripts like `ClassicRig.gd`), not by hand-nudged meshes.
5. One visual language: shapes, colours, light and motion (`doc/world/VISUAL_STYLE.md`).
6. Light follows the music the map authors wrote (its light events), not randomness.
7. Reuse modules (MultiMesh, shared materials) without the scene looking repetitive.
8. Check it in play on the headset, not only in code or in Blender.
9. Never report a check that wasn't run (no local Godot: CI imports and builds, the headset runs).
10. Look before overwriting or deleting existing work.

## 2. Before changing anything
- Read `doc/world/` (bible, style, spatial layout, audio-visual mapping) and the root `AGENTS.md` "Light" rules.
- Find the real numbers in code: `game/Constants.gd` (lanes, rows, hit plane), `game/event_driver.gd` and
  `.tscn` (lights, rigs, haze), the environment's rig script in `game/env/`.
- Say which kind of task it is: layout, new structure, fixture or model, light/music response, effect, or
  optimisation. Reuse what exists before building new.

## 3. Plan a substantial change
Write down, and show the user before building: the player experience it adds, where it sits in the spatial layout
(and that it stays out of the exclusion zones), its silhouette and focal role, its colours and materials, how it
reacts to the music, and its GPU cost. Record lasting decisions in the matching `doc/world/` file.

## 4. Order of work
Inspect → spatial and visual design → block out the big forms (boxes in the rig script) → check scale and
sightlines from the player's eye (Blender render or headset) → real models (game-model-creator) → secondary
pieces → materials, light and music response (shader-design) → checks → optimise and report what's left.
Don't detail what may still move.

## 5. Placement contract
For every significant piece or group, be able to say: why it exists, why here, why facing that way, what holds it
up (nothing floats: Light rule 5), for a light what it is in the world (a carrier that belongs there and fits the
story, never a stand just to hold the light: Light rule 5), how big next to the player and its neighbours, what it adds to composition or
rhythm, and whether it can block a note, a wall or the player's view. If it can't be justified, move or remove it.

## 6. Three layers
- Gameplay: notes, chains, arcs, walls, bombs, sabers, the platform. Highest priority, tightly controlled.
- Environment: frames, rings, pedestals, buildings, fixtures. To the sides and below the horizon.
- Atmosphere: beams, haze, dust, smoke, glows. Never brighter than the gameplay layer, never inside the note lane.

## 7. Generated layouts
Rig scripts build structure from named constants (deterministic: same constants, same scene). Keep landmarks and
the note corridor authored; vary only chosen properties within stated ranges; rebuilding must not duplicate nodes.

## 8. Checks (this project)
1. CI import and build pass; after install, logcat has no `SHADER ERROR`, `SCRIPT ERROR` or `Parse Error`.
2. From the player's eye: a Blender render of the layout before building, then headset screenshots in play,
   compared with the style frame (Classic target look).
3. Busy light sections and quiet ones; menus too (pre-show lighting).
4. GPU: `tools/bench.sh` before and after; budget 13.9 ms at 72 Hz, the refresh rate for every scene (owner, 2026-10-26).
5. Anything that moves the playspace follows the playspace rule in `game/AGENTS.md`.

## 9. Done means
It exists and fits the style; the gameplay layer is readable and unobstructed; the pieces are composed, not
scattered; checks above were run; known problems are fixed or reported.

## 10. Report
What changed; files touched; key decisions and why; checks run and results; checks not run; what's left.
