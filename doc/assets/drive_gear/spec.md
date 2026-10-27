# Asset spec: drive gears (large and small)

- Ticket / owner: Metal Factory stage, fourth detail asset (order set 2026-10-25) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the far end's machinery that comes alive with the song: still
  while it is quiet, turning slowly as it builds and at full speed at the drop. Metal Factory only.
- Reference files and views: none; the approved blockout.
- Confidence and assumptions: original, generic spur gears; sizes from the blockout.
- Dimensions / units / origin / axes: metres. Large: rim 8.8-10 m, 24 teeth 1.2 m high (22.4 m across at the tips),
  1 m deep. Small: rim 6.3-7.5 m, 18 teeth 1.2 m high (17.4 m across). Same tooth size, so they could mesh. Four
  spokes, eight-sided hub. Origin at the centre; faces the player (+z); axle along z. In the rig: large at x ±17, y 2,
  z -58 (half in the walls' end piers); small at x ±9, y -6, z -62 in the pit (top about 2.7 m up); axles into the
  piers and foundation.
- Silhouette landmarks / required features: teeth and spokes that read as turning gears at 58-62 m.
- Materials / palette / emission: the hall's EnvSolid material (light_spill 0.3); occlusion baked into vertex colour red.
- Motion: with the show's intensity, from still at 0.1 to full at 0.9; large 0.35 rad/s (about 20°/s) at full, each
  small one the other way, faster by 24:18; the right pair mirrors the left (`MetalFactoryRig.turn_gears`). Far and to
  the sides only; floor and track never move (vection, owner's decision 4).
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: large 436, small 346 triangles (plan ~400); four in two MultiMeshes = 1564;
  no textures. Front and edges only (never seen from behind).
- Export format / destination: `game/models/drive_gear_large.glb`, `drive_gear_small.glb`; source
  `tools/models/gears.py`.
- Existing Godot resources affected: `game/env/MetalFactoryRig.gd` (replaces the drive gear boxes),
  `game/event_driver.gd` (passes the intensity each frame).
- Required previews and automated checks: owner looks in Blender, the Godot editor and `stage_capture --map`; CI import.
- Human acceptance criteria: reads as heavy machinery waking up with the song, never uncomfortable to watch.
