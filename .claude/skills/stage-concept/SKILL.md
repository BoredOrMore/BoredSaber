---
name: stage-concept
description: How to come up with a new abstract BoredSaber stage concept, where shape and light express a feeling and light plays against shadow; checks every concept with the budget agent. Use when the owner asks for a new stage, a stage for a mode (90°/360° maps), or new ideas for an existing one.
---

# Stage concept: shape and light express a feeling

A stage here is abstract: no city, factory or landscape to explain it. Big shapes and how light falls on them,
cuts through them and leaves them in shadow carry one feeling the song can push. The owner asked for this way
(2026-10-29). This skill only makes concepts; building them follows `rhythm-world-design`, `game-model-creator`
and `shader-design`. The creative director (`.claude/skills/creative-director/`) picks which concepts reach the owner.

## 1. Start from a feeling, not a place
Write the feeling in a few words and the moment it peaks: "held breath, then release", "alone in something
endless", "pressure closing in, then breaking open". Then answer, each in one line:
- Shape: which few primitive families say it (slabs, rings, blades, arches, steps, a single monolith), how they
  are arranged (repeated, converging, stacked, orbiting), and how big next to the player. The player should feel
  tiny inside something enormous: main forms far above eye height, a scale cue near the track.
- Light: where it lives on the shapes (edges, seams, slits, a face that catches it) and where it goes (along,
  across, through gaps). Shapes are the light's carrier: every light lies on or comes out of a shape (root
  `AGENTS.md` Light rule 5); nothing floats to hold a light.
- Shadow: what stays dark, and how the dark is shaped: a silhouette against a lit plane, light raking through a
  gap so a shadow band falls across a surface, a void the light never reaches. Shadows are black, never tinted.
- Motion: what moves on the music (shapes turn, open, slide, light sweeps), what never moves (the floor and the
  track stay still: a rest frame against motion sickness).
- Build-up and drop: what the stage does from the dark intro to the peak (Game bible: stages evolve in a song).

## 2. Rules that shape every concept
- Light rules in the root `AGENTS.md` win: value before hue, hot core and coloured falloff, saturation only in
  small areas, the two note colours plus neutrals, flashes short and rare, haze reveals, no post-processing.
- Colour rules: light colours come from the note colours; never the danger colour or a new hue.
- Blocking: the main forms that frame the track are symmetric; asymmetry lives in the smaller pieces, unless the
  concept is about flow (a sweep, a path) and says so (owner, 2026-10-27).
- Gameplay first: nothing in the note corridor (`doc/world/SPATIAL_LAYOUT.md`), the horizon view stays clear,
  scenery darker than notes, walls, bombs and fixtures.
- Mode: say which modes it serves. A 360° stage has no "front": its main form must read the same all around
  (rings, a dome, a field of repeated forms), and the track turns inside it while it stays still.
- Mixed reality: say what is left when only track, notes, sabers and beams are drawn.

## 3. How light and shadow are made here (cheap, no real lights)
Everything is unshaded. Use these, cheapest first (`doc/world/VISUAL_STYLE.md` "Light carriers"):
1. Glowing faces or edges marked in the model's vertex colour (no extra draw call).
2. Opaque strips flush on surfaces (`LightStrip.gdshader`).
3. A light pattern drawn in the receiving surface's shader: a raking band, a gobo, a slit of light, and the
   shadow band beside it (fake, computed from the light's direction).
4. Darkness by absence: unlit faces stay near black; baked AO in vertex colour deepens corners.
5. Few narrow beams in haze, fading along their length, only where the feeling needs them.

## 4. Check the budget before showing anyone
Send each concept to the budget agent (`.claude/agents/budget.md`) with its element list (shapes with rough size
and count, light carriers per map light group, beams, haze, sky, moving parts, the mode). Put its table in the
concept. If an element is over, use its cheaper option or drop the element, then ask again. No concept goes to the
owner without a budget verdict.

## 5. What one concept contains
- Name and feeling (one line each), and a one-paragraph picture of what the player sees from the platform.
- Shape list, light list (the map's five light groups: diagonal lasers, square bars, left and right waving lasers,
  centre and floor, and the shape that carries each), shadow list, motion list, build-up and drop.
- Modes it serves, mixed reality view, how it differs from the existing stages (and their menu thumbnails).
- The budget agent's table and total.
- Open questions for the owner. Never decide the owner's taste; offer 2-3 concepts that differ in feeling, not
  just in shape.

Sources to lean on: Gurney "Color and Light" (value structure, light on form); Pilbrow "Stage Lighting Design"
(direction, shape and movement of light); chiaroscuro and theatre light design (a shape is read by the light that
falls on it and the shadow it throws); Keltner & Haidt 2003 (awe: vastness and the need to re-fit what you see).
