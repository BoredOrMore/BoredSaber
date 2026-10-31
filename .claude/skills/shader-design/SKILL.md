---
name: shader-design
description: How to build or change a shader in BoredSaber (notes, sabers, walls, bombs, arcs, sparks, trails, scenery, sky, haze, UI shaders). Use before writing or editing any .gdshader, and when proposing a look change to the user.
---

# Shader design for BoredSaber

Build an effect the way an artist sees it, in layers, and only then make it cheap. Picture the result first,
not coordinates, spaces or equations. Read the root `AGENTS.md` "Light" and "Pico 4 constraints" before
starting; the style frame (Classic target look, look spec, materials) is the picture to aim at.

## 1. See it in layers

Before any code, write the effect down as a short stack of layers, back to front, each one a thing you could
point at on screen. Example, a wall:

1. faint glass in between (dark, low saturation)
2. thin frame on every edge (white-hot)
3. soft halo around the frame (danger colour)
4. haze: fades with distance toward `env_haze`

Each layer answers: what it looks like, where it is on the object, which colour and how bright in the
brightness order (notes and sabers > walls and bombs > fixtures > beams in haze > scenery > sky). If a layer
can't be named this way, it isn't needed. Show the user the layer list (or a sketch on the style frame)
before building something new.

## 2. Build one layer at a time

- Each layer is its own small function returning its colour or mask (`float frame_mask(...)`,
  `vec3 halo(...)`), combined at the end in `fragment()` in the same order as the list. No layer reaches
  into another's variables.
- Build and check one layer before adding the next: on the headset, or with a `debug_view` mode
  (`global uniform int debug_view`, see `DebugView` in the game) that shows that layer alone.
- Combine the way light does: emitted light adds (additive layers, `blend_add`, or `+`), surfaces and
  haze mix (`mix`). Brighten toward white, never multiply a saturated colour past 1 (Light rule 2).

## 3. Name the knobs

- Every number that changes the look gets a name and a one-line comment saying what it does in words the
  player would see ("how wide the halo is, in metres"), plus its unit. Group them by layer at the top of
  the file, in layer order.
- `const` for values tuned once; `uniform` only for what the game sets per object; `global uniform` only
  for what the whole scene shares (`env_haze`, `left_saber_color`, `cut_waves`, `note_max_value`...). Reuse
  those before adding a new one, and reuse the `.gdshaderinc` helpers in `game/env/`
  (`height_fog`, `fog_light`, `player_light`). No colour toning of the darks (gradient mapping, shadow
  tints): the owner had a navy shadow tint removed (2026-10-26); blacks stay black.
- Untuned values say "untuned"; tuned ones say what they were tuned against (headset test, player
  request). Cite where a technique comes from (paper, Beat Saber modding wiki, a Godot doc).
- Typed constants only (`const float X = 1.0;`): an untyped `const` is a SHADER ERROR on the Pico.

## 4. Then make it cheap, keeping the look

Only once the layers look right. Measure before and after on the headset (step 5); the goal is the same
picture for less GPU time, never a different picture.

- Fake, don't simulate: no real lights, shadows, reflections, post-processing or screen reads
  (Light rule 10). Lighting, bloom, reflections and rim light are drawn in the object's own shader
  (`render_mode unshaded`), as every shader here already does.
- Overdraw is the main cost on the Pico's tile GPU: keep see-through and additive surfaces small and few,
  `depth_draw_never` on them, `cull_back` where the back is never seen. Big full-screen transparent
  sheets are the most expensive thing you can add.
- Move work up: per object (uniform, computed on the CPU) beats per vertex beats per pixel. Anything that
  doesn't change across a surface goes in `vertex()` and is passed as a `varying`.
- Fewer texture reads; bake fixed patterns into a texture or the mesh (`tools/bake_*`) instead of noise
  computed per pixel. No loops over lights or samples per pixel.
- Cheap math: `exp`, `pow`, `smoothstep` are fine in moderation; prefer `mix`, `clamp`, `step` and
  dot products. Avoid `discard` (breaks early depth tests on mobile GPUs) unless the shape needs it.
- Thin lines: anti-alias with `fwidth` and keep at least `min_pixels` wide, dimming instead of thinning,
  so they don't shimmer when the head moves (`NeonRibbon.gdshader`).
- No HDR: values are 0-1 per channel, so brightness comes from contrast and the size of the bright part.

## 5. Check it

1. Push; the APK builds and is installed on the headset. Launch the game and read logcat for
   `SHADER ERROR|E godot +: (ERROR|SCRIPT)|Parse Error`.
2. Look at it on the headset in the menu and mid-song, next to the style frame: brightness order holds,
   no shimmer on thin lines, no big bright area greying the blacks.
3. Measure GPU with `tools/bench.sh` (the mode closest to the change, e.g. `--only total`) before and
   after; report both numbers (ms at 72 Hz, budget 13.9 ms) to the user.
4. Explain the change to the user layer by layer, in plain words, with the math in one line each where it
   helps (as `CutFlash.gd` and `SaberTrail.gdshader` explain their exponential curves).
