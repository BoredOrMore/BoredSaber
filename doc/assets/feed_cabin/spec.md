# Asset spec: Pulse Void's feed cabin and maintenance beam

- Ticket / owner: Pulse Void's giant receiving dish, model 2 (owner, 2026-10-27: the dish panel OK) / Claude, owner
  reviews.
- Purpose: the receiver at the dish's focus, the player standing on its roof: the cabin with the feed horn aimed down
  at the dish, and the beam the track runs out on. Seen looking down past the track and to the sides.
- Parts: the cabin (12 x 12 x 7 m) with pilasters every 3 m round it, a band of four framed windows on its front,
  louvred vents on its sides, a parapet round the roof (open at the front), the feed horn under it (4.4 m mouth);
  the beam from the cabin's front to 61 m ahead, 5 m wide and 2.5 m deep: four chords, Warren bracing on both sides,
  cross members under it, a walkway plate under the track deck, handrails either side (posts every 10 m, a top and a
  middle rail) at x ±2.5, clear of the note corridor (lanes ±1.2 m).
- Size and pivot: origin at the cabin's top centre (PulseVoid CABIN_TOP, 0.4 m under the track); Blender +y is
  ahead (Godot -z).
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: PulseVoid: one mesh, replacing the cabin and beam boxes; the feed legs keep meeting the cabin's
  underside corners.
- Budget: about 1,000 triangles; +1 draw call.
- Export: `game/models/feed_cabin.glb`; source `tools/models/feed_cabin.py`.
- Review: owner in Blender and Godot, then on the headset.
