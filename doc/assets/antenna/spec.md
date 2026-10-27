# Asset spec: rooftop antenna

- Ticket / owner: Night City canyon, models after the blockout (owner, 2026-10-26: AC units, then antenna, low-roof
  edges, stair house) / Claude, owner reviews.
- Gameplay purpose: none; a thin vertical against the sky. On the low roofs, a TV aerial a little taller than a person
  (a familiar size); the same mast, scaled up, on two of the towers' tops as radio masts, so the towers read as huge:
  the same shape far above, tiny.
- Reference: a rooftop TV aerial: a pole on a small base, a few horizontal elements (a Yagi), angled stays.
- Dimensions / origin / axes: metres. Pole 3.5 m tall, 5 cm thick, on a base plate 0.4 m square; three crossbars
  (1.2, 0.9, 0.6 m, longest lowest) near the top; two stays from the pole's middle to the base's corners. Origin at
  the base on the roof; y up. Front: none to speak of (the crossbars run along x).
- Silhouette: a thin pole with a few crossbars; reads against the sky at 10-150 m.
- Materials: EnvSolid (the city's no-window variant, as the other rooftop props); occlusion baked into vertex colour
  red. Flat shading. No glow (no aircraft light: a light would be a new glow source).
- Collision: none.
- Budget: under 100 triangles a copy (about eight copies, one MultiMesh: one draw call).
- Export: `game/models/antenna.glb`; source `tools/models/antenna.py`.
- Placement: NightCityRig: a few on the low roofs, leaning slightly, turned differently; scaled up on two tower
  tops (not the third), off-centre.
- Review: owner in Blender and Godot, then on the headset.
