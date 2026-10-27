# Asset spec: Classic's props

- Ticket / owner: Classic test tunnel, model 4 (owner, 2026-10-27: model order OK, the wall catwalk OK) / Claude, owner
  reviews.
- Purpose: the lighting crew's kit, the familiar-size cues that make the tunnel huge; uneven left and right (main
  elements symmetric, props not).
- Parts (one script, two exports):
  - Props, built where they stand as one mesh: three flight cases on the left (two side by side, one stacked, each
    turned a little; a lid seam, corner caps, end handles), a cable reel further on the left (two flanges, the wound
    cable), a scissor lift on the right (chassis on four wheels, four stages of crossed arms each side, the platform at
    6 m with a rail round it), the ladder from the curved wall up to the right catwalk's open edge.
  - Tool box: one on each hanging scaffold's deck, a different spot on each, moved with the scaffold (lid, handle).
- Size and pivot: props at the player's floor origin (Blender -y is Godot +z), standing on the tunnel floor's top
  (y -0.3); the tool box at its foot.
- Distance: the cases and reel 4-13 m, the lift 18 m, the ladder 40 m, the tool boxes 20 m up.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: ClassicRig: the props one mesh at the origin; the tool boxes one MultiMesh of six. They replace the
  blockout's prop, scissor-arm, ladder and tool-box boxes. The ladder's ends repeat ClassicRig's numbers (the lining's
  face, the catwalk's open edge).
- Budget: props about 1,000 triangles, tool box under 100; +2 draw calls.
- Export: `game/models/classic_props.glb`, `game/models/tool_box.glb`; source `tools/models/classic_props.py`.
- Review: owner in Blender and Godot, then on the headset.
