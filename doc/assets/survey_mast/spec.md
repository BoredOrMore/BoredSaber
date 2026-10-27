# Asset spec: survey mast with beacon

- Ticket / owner: Neon Grid arches, models after the blockout (owner, 2026-10-26: after the crane) / Claude, owner
  reviews.
- Purpose: the site's survey and marker masts along the grid's left side, 8-14 m tall, unevenly spaced. Each carries a
  signal beacon at its top: the left waving lasers' fixtures (AGENTS.md "Light", rule 5: the carrier belongs to the
  world). Near the player (6-50 m), so they are also a familiar-size cue against the arches.
- Reference: a guyed survey or met mast: a slim pole in sections on a base plate, three guy wires to ground anchors, a
  beacon housing on top, a junction box and a small solar panel on the pole.
- Dimensions / origin / axes: metres, modelled 10 m tall (the rig scales each copy to its height, 8-14 m). Pole 0.22 m,
  narrowing at two section joints; base plate 1.0 m square; three guys from 7 m up to anchors 4 m out, not evenly round
  (asymmetric); beacon housing 0.45 m on a short collar at the top (where the beam leaves); a junction box at 1.4 m and
  a solar panel at 5 m, on different sides. Origin at the base; y up.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow on the model.
- Collision: none.
- Budget: under 250 triangles a copy; four copies in one MultiMesh: one draw call (replacing four blockout boxes).
- Export: `game/models/survey_mast.glb`; source `tools/models/survey_mast.py`.
- Review: owner in Blender and Godot, then on the headset.
