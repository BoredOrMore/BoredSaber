# Asset spec: low-roof edges (parapets and copings)

- Ticket / owner: Night City canyon, models after the blockout (owner, 2026-10-26) / Claude, owner reviews.
- Gameplay purpose: none; the low roofs on the open side get real edges, so they read as roofs of buildings and not
  slabs, and a parapet about waist high is another human-size cue against the towers.
- Reference: a city roof's parapet: a low wall along the roof's edge with a coping (a cap stone a little wider than
  the wall) on top.
- Dimensions / origin / axes: metres. Wall 0.25 m thick, 0.6-1.2 m tall (different per roof); coping 0.4 m wide,
  0.08 m tall, hanging over both faces. Along the edges of the four low roofs (LOW_ROOFS), uneven: some edges bare,
  one with a gap, heights differing between roofs, nothing mirrored.
- Method: boxes made in code (NightCityRig._low_roof_edges, LOW_ROOF_EDGES), not a Blender model: a wall and a coping
  are two boxes, and as boxes they join the props' existing box MultiMesh, so they add no draw call (GPU is tight).
  No baked occlusion (boxes have no vertex colours); the scenery shader's form shading sets the coping's top apart
  from the wall's face.
- Materials: EnvSolid no-window variant, the rooftop props' material.
- Collision: none.
- Budget: 12 triangles a box, 20 boxes: 240 triangles; +0 draw calls.
- Review: owner in Godot, then on the headset.
