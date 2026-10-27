# Asset spec: Pulse Void's dish panel

- Ticket / owner: Pulse Void's giant receiving dish, model 1 (owner, 2026-10-27: blockout OK, model order OK) / Claude,
  owner reviews.
- Purpose: the dish's surface, 14 rings of 48 panels; it fills the lower half of the view, so the panels' seams carry
  its scale (each panel 3-33 m across, 16 m down the slope).
- Parts: the face only (the dish is seen from above; panels meet edge to edge): a raised frame round the edge, the face
  recessed inside it, a rib down the middle of the slope. The seam light rows (ArchStrip) keep their place on the
  panels' outer edges.
- Size and pivot: a unit piece (-0.5..0.5), scaled by the rig to each ring's panel: x along the ring, Blender z the
  dish's normal (the frame's top at +0.5, the face 0.3 under it), Blender y down the slope.
- Distance: 15-280 m, seen from above at a low angle toward the rim.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: PulseVoid: one MultiMesh of 672, replacing the panel boxes.
- Budget: under 20 triangles a panel (about 12k for all); +1 draw call. Measured blockout: 8.2 ms at 72 Hz (GPU
  normalised), the dish's fill no problem.
- Export: `game/models/dish_panel.glb`; source `tools/models/dish_panel.py`.
- Review: owner in Blender and Godot, then on the headset.
- Placement (owner, 2026-10-27): panels 4% wider than their share of the ring, so the fan-shaped gaps between
  them close; every other segment 3 cm proud so the overlaps don't flicker.
