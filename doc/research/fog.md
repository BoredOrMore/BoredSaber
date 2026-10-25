# Fog: what we have, what costs, what to do (research, 2026-10-25)

Owner asked for research on fog that is cheap on the Pico 4 and looks good. Nothing here is measured on the headset
yet; costs are reasoned from how each technique draws (per vertex, per pixel, extra transparent layers).

## What the game does now
| Part | Where | How | Cost |
|---|---|---|---|
| Distance haze | `EnvSolid.gdshader` layer 5, sky shaders, `TrackDeck.gdshader` | exponential fog, worked out per vertex, colour `env_haze` (the lights that are on, mostly neutral) | almost free: a few operations per vertex |
| Height fog | `height_fog.gdshaderinc` (4 shaders) | analytic exponential height fog along the view ray (Quilez, "Better fog"), per vertex | almost free |
| Fog sheets, floor smoke | `StageSmoke.gd`, `FogSheet.gdshader`, `FloorSmoke.gdshader` | transparent planes with drifting noise | the expensive kind: each sheet is a full-screen-ish transparent layer (overdraw). Shown in menus only; freed when a song starts |
| Beam smoke | `NeonRibbon.gdshader` | two slow waves along each beam stand in for smoke the beam lights | free (inside the beam's own pixels) |
| Dust | `Dust.gdshader` | tiny specks near the player, lit only where light falls | small: few, tiny additive quads |

## What others found (mobile VR)
- Built-in and post-process fog are the costly paths on Quest (full-screen passes, mobile HDR); developers drop them
  or go to per-vertex height fog or a transparent plane in front of the camera ([Meta forum][1],
  [realtimevfx][2], [Tomb Defense devlog][3]).
- Transparent fog cards are cheap to build but costly to stack: each draws over everything behind it, back to front
  ([realtimevfx][2]). One large sphere around the camera can replace several cards in places ([realtimevfx][2]).
- Fog can say where the light is: tint it warmer/brighter where the view looks toward the light (in-scattering), only a
  change in the fog's colour term ([Quilez, "Better fog"][4]).
- Beat Saber's own fog ("BloomFog"): not verified from any source; we don't copy its details.

## Gaps in ours
1. **Huge faces get wrong fog.** The fog is worked out per vertex. Night City's towers are boxes 200 m tall and 65 m
   long with vertices only at their corners, so the fog between them is a straight blend of the corners' values: a
   tower's middle can be as fogged as its far corner. Big, flat, wrong-looking fog on the largest things in view.
2. **One fog for every stage.** Density, colour and height are constants shared by all stages; the canyon (a street
   45 m below the player) and the open Neon Grid want different air.
3. **The fog doesn't say where the light is.** It takes the lights' colour everywhere alike, so it reads as a flat
   tint, not as air lit from somewhere.

## Options, cheapest first
| # | What | Look | Cost (reasoned) |
|---|---|---|---|
| A | **Per-pixel fog on big faces**: EnvSolid works out the fog per pixel where a uniform says so (Night City's towers), or the big boxes get a few subdivisions | the towers fade correctly with distance and height; the canyon's floor sinks into fog | per pixel: about 10 operations on the towers' pixels; or subdivisions: a few hundred more vertices. No draw call |
| B | **Per-stage fog values** (density, height, colour weight) set by each rig, like light_spill | each stage gets its own air: a deep canyon full of fog below, a clear Neon Grid | free |
| C | **Light-direction in-scatter**: the fog's colour leans toward the lights' colour and brighter where the view looks toward the light fixtures or the bright horizon (Quilez) | air that glows toward the lights, depth and direction | a dot product per vertex. Free |
| D | **Canyon fog pool**: Night City's height fog measured from the street (y -45), so fog fills the canyon below the roofs and the low roofs rise out of it | strong depth, "huge" scale (things vanish down into the fog) | free (a uniform) |
| E | **One far fog sheet in songs**, beyond the notes (30-60 m), small and dim | a visible layer of mist far ahead | one transparent layer over part of the view: measure first |
| F | Full-screen, depth-based or volumetric fog | best looking | not on the Pico 4's Compatibility renderer; breaks the no-screen-reads rule (Light rule 10). Not recommended |

Recommendation: A + B + D for Night City now (all free or nearly), C next for every stage, E only if a headset
measurement shows room. Every value untuned until the headset.

[1]: https://communityforums.atmeta.com/discussions/dev-quest/discussion-about-the-fog-effect-of-unreal-4-if-it-reaches-72hz-on-the-quest-plat/876625
[2]: https://realtimevfx.com/t/cheap-mobile-fog-unity/15447
[3]: https://rankrebellion.itch.io/tomb-defense/devlog/749457/improving-performance
[4]: https://iquilezles.org/articles/fog/
