# Asset spec: anvil

- Ticket / owner: Metal Factory stage, second detail asset (owner's pick, 2026-10-25) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the block each piston's hammer slams onto on the beat, and the
  stand of the diagonal laser beside it (AGENTS.md "Light", rule 5). Metal Factory only.
- Reference files and views: none; the approved blockout and the piston (`doc/assets/piston_hammer/`).
- Confidence and assumptions: an original, generic forging anvil block; footprint from the blockout.
- Dimensions / units / origin / axes: metres, y up. Plinth 3.6 m square, 0.35 m high; body 3.4 m square up to 1.2 m
  (the shelf); strike die 2.4 m square up to 1.5 m with 0.06 m chamfers. Origin at the centre of its foot, on the floor.
  The die's top is where the hammer's 2.2 m face lands (`MetalFactoryRig.ANVIL_TOP`), 0.1 m of die showing round it.
- Silhouette landmarks / required features: stepped block (plinth, body, die) that reads as a heavy base under the hammer;
  a shelf corner free for the laser fixture (inset 0.3 m from both edges, clear of the die and the hammer).
- Materials / palette / emission: dark metal, the hall's EnvSolid material (light_spill 0.3); occlusion baked into
  vertex colour red for the shader that will read it. Strike light comes with the slam effect later.
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: 68 triangles (plan ~80); 10 copies in one MultiMesh = 680; no textures.
- Export format / destination: `game/models/anvil_base.glb`; source `tools/models/anvil_base.py`.
- Existing Godot resources affected: `game/env/MetalFactoryRig.gd` (replaces the anvil boxes; the diagonal lasers move
  from the blockout top at 1.5 m to the shelf at 1.2 m).
- Required previews and automated checks: owner looks in Blender and the Godot editor (owner's preference, 2026-10-25:
  no review render images); CI import.
- Human acceptance criteria: reads as the heavy base the hammer strikes, hammer face sits flush on the die when down,
  fixture stands on the shelf without touching the die or the hammer.
