# Visual style

Template from the rhythm-world suite; the rules themselves live in the root `AGENTS.md` ("Light", "Colour rules")
and are only summarised here. Target picture: the Classic style frame (Claude Design artifact "BoredSaber
Classic Style Frame": target look, look spec, materials).

## Identity
- One line: a concert stage at night: dark, with small bright sources whose colour shows in their glow and the haze.
- Shape language: steel frames, pedestals, moving-head fixtures, square rings; clean boxes with lit edges.
- Stylised, not realistic. Seen from 2 to 60 m.

## Scale and symmetry (owner, 2026-10-25)
- Scale: beyond immersion, the player should feel tiny, a small part of something enormous. Each stage needs at least
  one form far larger than the player (a megastructure, a wall or tower rising out of view, depth that runs on past
  the haze), with the track and platform small against it.
- Symmetry: not everything mirrored left and right. Break it on purpose where it helps: different landmarks, heights
  or distances on each side, one-sided features. Keep symmetry only where it serves (the track, the note lanes, a
  centred focal point).
- A stage concept, spec or blockout says how it does both.

## Colour system
| Role | Colour | Meaning | Constraints |
|---|---|---|---|
| Environment base | dark navy, `SHADOW_TINT` in the shadows | the stage | Takes its light colour from the note colours |
| Note colour A/B | from the preset or the map | "cut this": notes, sabers, the lights | Nothing else uses them |
| Danger | `DANGER_COLOR` (ff3030) or the map's wall colour | "dodge": walls, bombs | Never decoration |
| House light | `EventDriver.HOUSE_COLOR` | menus, before the show | Near neutral |
| Haze | `env_haze`, mostly neutral | air | Tinted only a little by the lights |

## Materials and light
- Everything is unshaded and fakes its lighting in its own shader (no real lights, shadows, bloom or screen reads).
- Brightness order: notes and sabers > walls and bombs > fixtures > beams in haze > scenery > sky.
- Emitters: white-hot core, coloured falloff; brighten toward white, never past 1.
- Scenery: dark matte metal that takes on the lights' colour (`env_light`); rings keep a lit inner edge.
- Fixtures: dark metal with baked occlusion; lens and glow in the beam's colour.
- Haze reveals light; far things lose contrast toward it. Rings take half the haze to stay dark shapes.

## Light carriers (owner, 2026-10-25)
Each stage hangs the map's five light groups (diagonal lasers, square bars, left and right waving lasers, centre and
floor) on something; beams from moving heads are one way, not a rule. Options to pick from for a stage, all in the note
colours, mounted on its structure (AGENTS.md "Light", rule 5), in the order of their GPU cost on the Pico 4, cheapest
first. The order is reasoned from how each draws (opaque or see-through, extra draws, overdraw), not measured on the
headset: measure with `tools/bench.sh` before relying on it.
1. Emissive vertex mask in an existing model: faces a model marks in vertex colour glow in their group's colour in the
   scenery shader (EnvSolid layer 6). No extra mesh or draw call. Used: Metal Factory's glowing wall vents.
2. Opaque light strips (`LightStrip.gdshader`): thin boxes flush on a surface, white-hot where they face the eye. One
   draw call per MultiMesh, no overdraw. Used: the track's edge lights, Metal Factory's energy rails. Option: strips
   along a vault's ribs.
3. Caged lamp model on a column (option, not built): a small fixture model; its glow, if it gets an additive halo,
   adds overdraw, so keep halos small and few.
4. Transparent beams from moving heads (Classic, Neon Grid, Night City, Pulse Void): long see-through beams that stack
   over much of the screen; the main overdraw cost of a stage.
5. Real Godot lights, shadows, volumetric fog or post-processing bloom: not used (Light rule 10).

## Prohibited
Floating primitives, decoration without a purpose, glow that erases silhouettes, uncontrolled flashing, detail that
doesn't read at play distance, large saturated or pure-white areas.

## Review checklist
- [ ] Notes are the brightest thing in view, even at the peak of a light show.
- [ ] Big forms read before small detail; nothing floats.
- [ ] No shimmer on thin lines when the head moves.
- [ ] Blacks stay black (no big bright area greying the LCD).
- [ ] The player reads as small against at least one huge form.
- [ ] Left and right are not a plain mirror (unless the stage's idea needs it).
- [ ] GPU within budget.
