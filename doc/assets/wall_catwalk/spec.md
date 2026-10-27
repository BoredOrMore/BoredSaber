# Asset spec: Classic's wall catwalk

- Ticket / owner: Classic test tunnel, model 3 (owner, 2026-10-27: model order OK, the tunnel rib and lining OK) /
  Claude, owner reviews.
- Purpose: the maintenance catwalks along both walls, 8 m up, z -8 to -64, carrying the waving lasers' follow spots.
  They must read as built against the curved wall, not as planks floating beside it.
- Parts: one 8 m span, repeated 7 times a side: a deck plate 3 m wide on two edge stringers and cross bars every 2 m;
  a toe board, posts every 2 m and a top and a middle rail on the open side; a bracket at the span's middle: an arm
  under the deck to the wall, a leg down from the deck's open edge to where the wall curves in under it, and a brace
  between them.
- Size and pivot: origin at the deck's top centre; x across the catwalk (+x toward the wall), Blender -y (Godot +z)
  along it, z up. The deck's wall edge meets the lining's face at 8 m up; the right side as modelled, the left turned
  half round.
- Distance: 28-70 m from the player, seen from below and the side: the brackets and the rail carry the look; tubes
  0.12 m or thicker.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: ClassicRig: one MultiMesh of 14 spans, replacing the catwalk boxes; the follow spots and the ladder move
  with the deck's new place (flush with the lining).
- Budget: under 300 triangles a span (about 4k for all 14); +1 draw call.
- Export: `game/models/wall_catwalk.glb`; source `tools/models/wall_catwalk.py`.
- Review: owner in Blender and Godot, then on the headset.
