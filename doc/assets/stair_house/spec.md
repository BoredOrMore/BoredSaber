# Asset spec: stair house (rooftop bulkhead)

- Ticket / owner: Night City canyon, models after the blockout (owner, 2026-10-26) / Claude, owner reviews.
- Gameplay purpose: none; the small structure where the stairs come up onto the player's roof, on the tower-wall
  side, replacing the blockout box. A door at human size right next to the player is the closest familiar-size cue:
  the towers beyond it read as enormous.
- Reference: a city rooftop stair bulkhead: a small concrete hut with a flat roof slab, a steel door, a vent pipe.
- Dimensions / origin / axes: metres. Body 4 m along the track, 3 m across, 2.8 m tall; roof slab 0.15 m thick,
  overhanging 0.15 m all round and 0.4 m over the door; door 0.9 x 2.0 m in a frame, off-centre toward the far end;
  a step in front of it; a vent pipe on the roof's back corner; a louvred vent on the near end wall. Origin at the
  floor under the body's middle; y up; the door faces the track (+x in the rig after its turn).
- Silhouette: a hut with a roof slab and a pipe; reads at 3-10 m beside the player.
- Materials: EnvSolid no-window canyon variant (the rooftop's own material); occlusion baked into vertex colour red,
  so the door's recess, under the overhang and the step's corner darken. Flat shading. No glow.
- Collision: none.
- Budget: under 300 triangles; one instance: +1 draw call (the blockout box it replaces is one box less in the
  rooftop's MultiMesh).
- Export: `game/models/stair_house.glb`; source `tools/models/stair_house.py`.
- Placement: NightCityRig, STAIR_HOUSE, where the blockout box stood.
- Review: owner in Blender and Godot, then on the headset.
