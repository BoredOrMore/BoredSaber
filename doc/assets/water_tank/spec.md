# Asset spec: rooftop water tank

- Ticket / owner: Night City canyon, models after the blockout (owner, 2026-10-25) / Claude, owner reviews.
- Gameplay purpose: none; rooftop clutter on the low roofs on the open side, a familiar-size cue (a tank is about
  3 m tall) that makes the towers read as huge, and something on the roofs so they aren't bare slabs.
- Reference: the classic New York rooftop water tower (a wooden tank on a steel stand with a conical lid).
- Dimensions / origin / axes: metres. Tank 2.6 m across, 2.8 m tall, on a steel stand 2 m tall (four legs and a ring
  beam), conical lid 0.7 m. Origin at the stand's feet, on the roof; y up. Symmetric, no front.
- Silhouette: barrel, cone lid, four legs: reads at 10-60 m against the haze and the sky.
- Materials: EnvSolid (the city's material); occlusion baked into vertex colour red. Flat shading on the stand,
  smooth on the barrel and lid. No glow.
- Collision: none.
- Budget: under 300 triangles (a few copies on the low roofs, one MultiMesh).
- Export: `game/models/water_tank.glb`; source `tools/models/water_tank.py`.
- Placement: NightCityRig, on the low roofs, a few copies of different heights' roofs.
- Review: owner in Blender and Godot, then on the headset. Acceptance: reads as a water tank from the player's roof;
  its size makes the towers behind feel larger.
