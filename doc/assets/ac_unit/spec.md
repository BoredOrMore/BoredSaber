# Asset spec: rooftop air-conditioning unit

- Ticket / owner: Night City canyon, models after the blockout (owner, 2026-10-26: AC units, then antenna, low-roof
  edges, stair house) / Claude, owner reviews.
- Gameplay purpose: none; rooftop clutter on the low roofs on the open side, a second familiar-size cue (a condenser
  is about waist to chest high) next to the water tanks, so the roofs read at human scale and the towers as huge.
- Reference: the common rooftop condensing unit: a sheet-metal box on short rails, a round fan opening on top with a
  guard, louvred sides.
- Dimensions / origin / axes: metres. Body 1.2 m wide (x), 0.9 m deep (z), 1.0 m tall, on two rails 0.12 m tall.
  Fan opening 0.7 m across on top, recessed, with a guard of two crossing bars and the motor hub. Origin at the
  rails' feet, on the roof; y up. Front: the louvred long side (+z in Godot).
- Silhouette: a squat box with a disc on top; reads at 10-60 m.
- Materials: EnvSolid (the city's no-window variant, as the other rooftop props); occlusion baked into vertex colour
  red, so the fan well and the louvres darken. Flat shading. No glow.
- Collision: none.
- Budget: under 200 triangles a copy (about ten copies, one MultiMesh: one draw call).
- Export: `game/models/ac_unit.glb`; source `tools/models/ac_unit.py`.
- Placement: NightCityRig, on the low roofs in uneven clusters (one, two or three together, turned differently, none
  mirrored across the track), between and around the water tanks.
- Review: owner in Blender and Godot, then on the headset. Acceptance: reads as an AC unit from the player's roof; the
  roofs gain a human scale.
