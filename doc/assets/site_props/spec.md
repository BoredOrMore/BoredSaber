# Asset spec: Neon Grid site props (container, barriers, beams)

- Ticket / owner: Neon Grid arches, models after the blockout (owner, 2026-10-26: after the survey masts) / Claude,
  owner reviews.
- Purpose: the building site's clutter next to the player, the closest human-scale cue against the arches: a shipping
  container behind on the left, a short row of concrete barriers and a pile of steel I-beams on the right. Not lined
  up, not mirrored.
- Reference: a 20 ft ISO container (corrugated sides, corner castings, door locking bars), Jersey barriers (sloped
  profile, lifting slots on top), wide-flange I-beams stacked unevenly with one sticking out.
- Dimensions: metres. Container 6.06 x 2.44 x 2.59 (its length along the track); barriers 2.0 long, 0.81 tall, 0.61
  wide at the foot, 0.15 at the top; beams 0.3 x 0.3 I-profiles, 9-12 m long.
- Method: one Blender script builds all three where they stand around the player (origin at the player's floor, the
  rig places it at the origin): one mesh, one draw call, replacing the blockout's boxes. No light carrier (nothing on
  the site needs one here: the masts and the crane carry the lights).
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red (the corrugation's grooves, the slots,
  between the beams). Flat shading.
- Collision: none.
- Budget: 1200 triangles (the container's body is cut into a grid so its baked occlusion reads; without it the big faces took their dark corners all over); +1 draw call (blockout boxes removed).
- Export: `game/models/site_props.glb`; source `tools/models/site_props.py`.
- Review: owner in Blender and Godot, then on the headset.
