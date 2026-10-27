# Asset spec: Pulse Void's rim parts (rim girder segment, rim mast)

- Ticket / owner: Pulse Void's giant receiving dish, model 4 (owner, 2026-10-27: the feed legs OK) / Claude, owner
  reviews.
- Purpose: the dish's edge round the horizon, and the masts on it ahead carrying the beacons (the waving lasers;
  AGENTS.md "Light", rule 5).
- Parts (one script, two exports):
  - Rim segment: one of 48 round the rim (33 m along it, 3 m out, 3 m deep): a girder whose inner face (toward the
    dish's centre, the side the player sees) is set back under a top lip, with three stiffener plates on it.
  - Rim mast: a triangular lattice mast 40 m tall (legs 3 m apart at the foot, 1.2 m at the top), four rings of
    braces, a plinth on the rim, the beacon's platform on top (3 x 3 m).
- Size and pivot: segment a unit piece (-0.5..0.5) scaled by the rig (its top at +0.5, its inner face toward the
  centre); mast at its foot on the rim, the platform's top 40 m up (PulseVoid MAST), turned with the rim so the
  three either side mirror each other.
- Placement: masts at 20, 45 and 70 degrees either side of ahead on the rim, 250 m out: well outside the note
  corridor; seen against the sky above the horizon from the player.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Budget: segment 60 triangles (2.9k for 48), mast about 200 (1.2k for six); +2 draw calls.
- Export: `game/models/rim_segment.glb`, `game/models/rim_mast.glb`; source `tools/models/rim_parts.py`.
- Review: owner in Blender and Godot, then on the headset.
- Placement (owner, 2026-10-27): the rim segments now stand as a vertical ring girder (2 m thick, 4 m tall, its top
  0.5 m over the dish's edge, inner face toward the centre); the masts stand on footings on the ground past the rim
  (258 m out), each with a cable to the feed cabin's roof corner (FAST's towers); the two front ones carry the
  bridge's stays.
