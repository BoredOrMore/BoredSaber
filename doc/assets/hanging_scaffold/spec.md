# Asset spec: Classic's hanging scaffold

- Ticket / owner: Classic test tunnel, model 1 of the models after the blockout (owner, 2026-10-27: blockout OK, model
  order OK) / Claude, owner reviews.
- Purpose: the six work platforms the crew flies in from the tunnel's ceiling as the song builds; they carry the moving
  heads (standing on the deck) and the square bars (hung under it). They must read as real hung scaffolds, not boards
  floating in the air.
- Parts: a deck plate 40 x 3 m on bearers every 2.5 m and two edge ledgers; toe boards round it; scaffold standards every
  5 m along both long edges with a top and a middle rail, and rails across both ends; a coupler where each standard
  meets the top rail; a cable lug at each corner where the rig's cables come down (x ±16, the deck's edges).
- Size and pivot: origin at the deck's top centre; x across the tunnel, Blender -y (Godot +z) the deck's depth, z up.
- Distance: 20 m up, 12-110 m from the player, seen mostly from below: the bearers and ledgers carry the look; tubes
  0.12 m or thicker so nothing shimmers.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: ClassicRig: one MultiMesh of six, moved with the fly-in; the cables and tool boxes stay boxes in the rig
  (cables reach the ceiling, tool boxes differ per scaffold).
- Budget: under 1,200 triangles each; +1 draw call over the blockout.
- Export: `game/models/hanging_scaffold.glb`; source `tools/models/hanging_scaffold.py`.
- Review: owner in Blender and Godot, then on the headset.
