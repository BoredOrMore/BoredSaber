# Asset spec: gear ring

- Ticket / owner: Metal Factory stage, third detail asset (order set 2026-10-25) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the rings round the track in place of Classic's square rings,
  turning on the map's ring-spin events. Metal Factory only.
- Reference files and views: none; the approved blockout.
- Confidence and assumptions: an original, generic toothed ring; sizes from the blockout.
- Dimensions / units / origin / axes: metres. Rim from 6.2 m to 6.8 m out, 12 teeth 0.6 m high (13.6 m across at the
  tips), 0.6 m deep. Origin at the centre; faces the player (+z); axle along z. In the rig: centre 2 m up, at z -15 to
  -55 every 8 m, running down through the floor; the inner edge stays 6.2 m from the track's axis (the note corridor
  reaches 1.3 m from it).
- Silhouette landmarks / required features: chunky tapered teeth that read as a gear at 15-55 m.
- Materials / palette / emission: the hall's EnvSolid material (light_spill 0.3); occlusion baked into vertex colour red.
- Motion: turns on ring-spin events at half Classic's ring speed (`MetalFactoryRig.RING_SPIN`), neighbours in
  opposite directions like meshed gears, so the view round the track never all flows one way (vection, plan doc).
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: 180 triangles (plan ~200; 15 a tooth, front and edges only, never seen from
  behind); six in one MultiMesh = 1080; no textures.
- Export format / destination: `game/models/gear_ring.glb`; source `tools/models/gears.py` (which also builds the drive
  gears, the next asset).
- Existing Godot resources affected: `game/env/MetalFactoryRig.gd` (replaces the ring boxes), `game/event_driver.gd`
  (passes the ring speed).
- Required previews and automated checks: owner looks in Blender and the Godot editor (owner's preference, no review
  images); CI import.
- Human acceptance criteria: reads as a gear, spins smoothly and not uncomfortably on ring events, clear of the notes.
