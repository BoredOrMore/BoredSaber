# Asset spec: Monolith mountains
- Ticket / owner: Bored, 2026-10-31 (thread "Model 3D assets for the game"): the zigzag silhouette rings had no
  detail and the clouds hid them; make them 3D models with varied shapes and no repeats; vertex colour, no textures.
- Gameplay purpose / song / genre: scenery of the Monolith stage; mountains on both sides of the valley that show
  their size against the clouds at their feet.
- Reference files and views: no picture; the shape brief comes from the owner's words and the critic round.
- Confidence and assumptions: low-poly faceted style chosen to match the game's flat, unshaded look (assumption,
  to confirm on the headset).
- Dimensions / units / origin / axes: metres; footprints 450-900 m long, peaks 120-310 m; origin at the middle of
  the base, length along x, up +y, front (the side the player sees) +z. The rig rescales them to each ring's height.
- Silhouette landmarks / required features: peaks with their own flank shapes (dome to spire) and leans, spurs and
  gullies, shoulders and notches in the outline; only the front half is built; the height reaches 0 at every edge.
- Materials / palette / emission: `MonolithRidge.gdshader`, unshaded dark neutral facets lit toward the glow behind
  the slab, paler with height and distance, sinking into the clouds; vertex red = baked AO, green = height share.
- Collision or hitbox requirements: none (scenery).
- Geometry / texture / material budgets: 440-504 triangles each, about 11k for all of them (4 slices round the
  player); no texture; one material.
- Export format / destination: `.glb`, `game/models/monolith_mountain_0..5.glb`, from `tools/models/monolith_mountain.py`.
- Existing Godot resources affected: `game/env/MonolithRig.gd`, `game/env/MonolithRidge.gdshader` (rewritten).
- Required previews and automated checks: four views per variant, UV checker, in-game captures; nothing within
  320 m, none touching the slab.
- Human acceptance criteria: on the headset the mountains read as huge, varied peaks rising out of the clouds, with
  the valley toward the slab still open.
