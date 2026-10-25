# Asset spec: piston (housing and hammer)

- Ticket / owner: Metal Factory stage, first detail asset after the blockout (approved 2026-10-25) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the stage's signature motion: hammers slam onto their anvils on the
  map's beat (from its BPM, every beat or every 2 beats) while the show's intensity is high (doc/world/GAME_BIBLE.md).
  Metal Factory only.
- Reference files and views: none; the blockout captures in `doc/world/captures/metal_factory_blockout_*.png`.
- Confidence and assumptions: an original, generic industrial drop hammer. Sizes taken from the approved blockout.
- Dimensions / units / origin / axes: metres, y up. Housing: mounting plate 1.6 m square, barrel 1.4 m across, 3.0 m
  from the header beam's underside to the bottom of the gland; origin at the plate's top. Hammer: head 2.2 m square,
  1.2 m high; rod 0.5 m across; 4.95 m from the striking face to the rod's top; origin at the centre of the striking
  face. In the rig the housing hangs at y 9 (the header) and the striking face moves between y 3.8 (raised) and 1.5 (on
  the anvil); the rod stays inside the housing over the whole stroke.
- Silhouette landmarks / required features: square mounting plate, eight-sided barrel with two bands, gland collar,
  rod, tapered neck, square head with chamfered edges. Seen from 7-45 m, beside the track (x ±8).
- Materials / palette / emission: dark metal; occlusion baked into vertex colour red. The shader that reads it, and the
  strike's light, come with the motion (shader-design skill); until then the rig keeps its EnvSolid boxes.
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: under 200 triangles per part (housing 156, hammer 94); 10 pistons = 2.5k
  triangles; no textures; one material; one MultiMesh per part.
- Export format / destination: `game/models/piston_housing.glb`, `game/models/piston_hammer.glb`; source
  `tools/models/piston_hammer.py`.
- Existing Godot resources affected: none yet; `game/env/MetalFactoryRig.gd` swaps its piston boxes for these after
  the owner approves the model.
- Required previews and automated checks: four review renders; CI import.
- Human acceptance criteria: reads as a heavy machine from the player's place, in proportion with the anvil and header,
  and the hammer's travel looks plausible.
