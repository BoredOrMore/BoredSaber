# Asset spec: Pulse Void's feed leg

- Ticket / owner: Pulse Void's giant receiving dish, model 3 (owner, 2026-10-27: the feed cabin OK) / Claude, owner
  reviews.
- Purpose: the four legs holding the feed cabin over the dish, and the carriers of the diagonal lasers (AGENTS.md
  "Light", rule 5): floodlights standing on platforms along them.
- Parts: a triangular lattice truss 200 m long (two top chords 2.5 m apart, a bottom chord 2.5 m under them, zigzag
  bracing on its sides every 20 m); three level platforms on its top at a quarter, half and three quarters of its
  length, each with a rail on three sides (open toward the cabin).
- Size and pivot: origin at the leg's top end, on its axis (the cabin's underside corner); the leg runs along Godot
  -z down to the dish 200 m out, near the rim (owner, 2026-10-27: at 150 m, 26 degrees down, the cabin's
  roof hid them; now 11 degrees down); the platforms' tops 1.5 m over the axis, level.
- Lights: ten floodlights, two a leg at a quarter and three quarters; the two left over on the front legs' middle
  platforms, left and right alike (PulseVoid.leg_floodlight). Before this, the last two stood past the legs' feet.
- Sightlines: the legs leave the cabin's underside at 45 degrees either side of ahead and behind and only go down:
  always below the horizon, clear of the note corridor.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: PulseVoid: one MultiMesh of four, replacing the leg boxes.
- Budget: about 560 triangles a leg (2.3k for four); +1 draw call.
- Export: `game/models/feed_leg.glb`; source `tools/models/feed_leg.py`.
- Review: owner in Blender and Godot, then on the headset.
