# Asset spec: Classic's tunnel rib and lining panel

- Ticket / owner: Classic test tunnel, model 2 (owner, 2026-10-27: model order OK, the hanging scaffold OK) / Claude,
  owner reviews.
- Purpose: the bore's structure, repeated all along it: steel ribs every 25 m and the lining between them. They must
  read as built steel at 10-600 m, not as boxes.
- Parts (one script, two exports):
  - Rib segment: one of the 24 pieces round a rib ring, a T-section (a flange 3 m wide facing the tunnel, a web behind
    it down to the lining) with a splice plate at its end where it meets the next segment. The rib strips
    (ArchStrip.gdshader) keep their place on the flange's face.
  - Lining panel: the plate between two ribs, one per ring segment, its face standing proud of a bevelled edge so the
    seams between panels show.
- Size and pivot: both at their box's centre, in metres: x along the ring (16.65 m), Blender z toward the tunnel's
  axis (Godot y; the rib 2.4 m deep, the panel 0.3 m), Blender y along the bore (Godot z; the rib 3 m, the panel 25 m).
  The rig places them with its old boxes' transforms, unscaled.
- Distance: 10-600 m. No bolts: about 1,100 copies (572 rib segments, 550 panels) leave no room for them.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: ClassicRig: one MultiMesh each, replacing the rib and lining boxes.
- Budget: rib segment under 30 triangles, panel under 12; the two together about 21k (the boxes were 13.5k); +2 draw
  calls.
- Export: `game/models/tunnel_rib.glb`, `game/models/tunnel_lining.glb`; source `tools/models/tunnel_parts.py`.
- Review: owner in Blender and Godot, then on the headset.
