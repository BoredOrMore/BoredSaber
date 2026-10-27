# Asset spec: track edge

- Ticket / owner: track and platform plan, tier 3 piece brought forward (owner, 2026-10-25: the track looked flat and
  floating, the lights beside it had no source) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the track's sides on every stage: a curb whose channel houses the
  edge light strip (the floor-light group), and a skirt carrying the track down to the stage floor.
- Reference files and views: none.
- Confidence and assumptions: an original, generic machined edge; sized to the existing strip (0.1 m section).
- Dimensions / units / origin / axes: metres. Profile out from the deck's edge: lip bevelled up to the curb's top at
  0.08 m, a 0.1 m channel 0.04 m deep centred 0.15 m out (the strip sits in it, its top 4 mm proud of the curb), outer
  bevel at 0.27-0.30 m, outer face down to -0.35 m, skirt flaring to 0.42 m out and down to -1.5 m. Extruded 1 m along
  the track, centred; the game stretches it to the track's 46.5 m. Origin at the deck's edge, on the deck's top. Built
  for the right side; the left is it turned half round. Both ends capped; the inner face under the deck left open.
- Silhouette landmarks / required features: a curb with a lit channel, a skirt that grounds the track.
- Materials / palette / emission: EnvSolid (the scenery's material); the strip is EventDriver's track light
  (LightStrip, the floor-light group's colour); occlusion baked into vertex colour red.
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: 40 triangles; two in one MultiMesh; no textures.
- Export format / destination: `game/models/track_edge.glb`; source `tools/models/track_edge.py`.
- Existing Godot resources affected: `game/env/TrackDeck.gd` (replaces the box curbs), `game/event_driver.gd` (the
  strips' place).
- Required previews and automated checks: owner looks in Blender and the Godot editor; CI import.
- Human acceptance criteria: the track reads as a solid deck with real sides; the edge light reads as set into it.
