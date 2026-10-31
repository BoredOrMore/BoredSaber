# Asset spec: Monolith clouds
- Ticket / owner: Bored, 2026-10-31 (thread "Model 3D assets for the game"): the flat cloud rings looked like stickers,
  one repeated image with no life; make them 3D models, shapes varied with no repeats, drifting slowly; vertex colour,
  no textures.
- Gameplay purpose / song / genre: scenery of the Monolith stage (Auto pool); a cloud sea filling the valley below
  the player's pillar.
- Reference files and views: the owner's stylized cloud reference (layered cumulus banks, bright rims on the puff
  tops, bodies fading dark into haze), sent in the "Design a new environment" thread on 2026-10-31.
- Confidence and assumptions: the shapes follow the reference; sizes come from the old rings (`CLOUD_RINGS`).
- Dimensions / units / origin / axes: metres; six banks from 40 x 22 x 16 m to 160 x 50 x 24 m; origin at the middle
  of the flat bottom, length along x, up +y (Godot). The rig rescales them per band.
- Silhouette landmarks / required features: separate overlapping round puffs with creases between them; bumps
  growing on bumps (cauliflower tops); variants: small, medium, large, towering, flat strip; the tallest part in a
  different place in each.
- Materials / palette / emission: `MonolithCloud.gdshader`, unshaded, neutral grey plus the haze (never the lights'
  colours); vertex red = baked AO, vertex green = height in the bank.
- Collision or hitbox requirements: none (scenery).
- Geometry / texture / material budgets: 368-768 triangles per bank (12x5 cut to 8x5 segments per puff); about 50k
  for the whole cloud sea, cut into 4 slices round the player so about half is drawn; no texture; one material.
- Export format / destination: `.glb`, `game/models/monolith_cloud_0..5.glb`, from `tools/models/monolith_cloud.py`.
- Existing Godot resources affected: `game/env/MonolithRig.gd`, `game/env/MonolithCloud.gdshader` (rewritten);
  `MonolithCloudEdge.gdshader` removed.
- Required previews and automated checks: four views per variant, UV checker, in-game captures from the eye; note
  path check (nothing above y -5 within 320 m), triangle count.
- Human acceptance criteria: on the headset the clouds read as a 3D cloud sea, not stickers, with no shape seen
  twice and a slow drift; GPU stays inside the 72 Hz budget (13.9 ms).
