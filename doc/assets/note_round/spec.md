# Asset spec: rounder note body

- Ticket / owner: note look plan (owner, 2026-10-25: notes should look close to Beat Saber's, not like tin cans; a
  rounder mesh together with the glossy shader) / Claude, owner reviews.
- Gameplay purpose / song / genre: the note the player cuts, every song. Its rounded edges carry the glossy look's
  highlight (BeepCube.gdshader, note_gloss.gdshaderinc).
- Reference files and views: the owner's Beat Saber screenshot (2026-10-25).
- Confidence and assumptions: the radius and the arrow's size are a first guess, untuned until a headset playtest.
- Dimensions / units / origin / axes: a cube 0.5 wide in its own units (0.4 m in game: BeepCube.tscn scales it by 0.8),
  edges and corners rounded with radius 0.0875 (0.07 m; the classic mesh's is 0.04 m). Origin at its centre; the
  arrow face toward the player (Blender -y, Godot +z).
- Silhouette landmarks / required features: wide rounded edges; flat faces stay flat (exact normals).
- Materials / palette / emission: BeepCube.gdshader; the arrow and dot from BeepCubeEmission.png, with the classic
  mesh's UV layout (front from the texture's top-left quarter, back from the top-right, scaled 1.2 so the arrow stays
  on the smaller flat face).
- Collision or hitbox requirements: none of its own; the note's hitboxes (BeepCube.tscn) are unchanged.
- Geometry / texture / material budgets: 300 triangles (4 segments per bevel); no new texture.
- Export format / destination: `game/BeepCube/note_round.glb`; source `tools/models/note_round.py`.
- Existing Godot resources affected: `game/BeepCube/BeepCube.gd` (uses it unless Classic notes is on; the cut halves
  too), `game/BeepCube/BeepCube.gdshader` (ROUND_BEVEL_START/FULL).
- Required previews and automated checks: the owner looks in Blender and Godot (BeepCubeTest.tscn, and
  `stage_capture --note`); CI import and tests.
- Human acceptance criteria: reads as glossy plastic, not a tin can; arrow and dot sit on the front face; cuts look
  right.
