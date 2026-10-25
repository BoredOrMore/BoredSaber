# Asset spec: platform frame (and the platform joined to the track)

- Ticket / owner: track and platform plan P1, P4 (owner, 2026-10-25: the platform as solid as the track, joined as one
  piece) / Claude, owner reviews.
- Gameplay purpose / song / genre: the player's place on every stage; the pad's border lights (game/floor.tscn) show the
  player where they stand and give a still rest frame. The burn marks stay as they are (the SubViewport, owner's choice).
- Dimensions / units / origin / axes: metres. A ring round the 2 m pad, from 1.02 m (the border lights' outer edge) to
  1.1 m out, its top level with the deck (y 0), 0.03 m tall with a 0.015 m chamfer on its outer top edge, mitred at the
  corners. Origin at the pad's centre on the deck's top; placed at the player's place (z 1).
- How it joins the track (TrackDeck.gd): the deck runs from the platform's front (z -0.1) to the far end; under the
  pad the base sits 0.03 m lower, so the burn marks and border lights lie flush in the ring's channel; plain plates fill
  from the ring out to the deck's width (wider with the Wide modifiers; the pad stays 2 m); the edges run on along the
  platform's sides to its back (z 2.1), where a second end stop closes it.
- Materials / palette / emission: EnvSolid; occlusion baked into vertex colour red. The border lights are unchanged
  (LightStrip, the right note colour).
- Collision or hitbox requirements: none new (the platform's collision box stays in game/floor.tscn).
- Geometry / texture / material budgets: 32 triangles; the base and fillers are boxes; no textures.
- Export format / destination: `game/models/platform_frame.glb`; source `tools/models/platform_frame.py`.
- Existing Godot resources affected: `game/env/TrackDeck.gd`.
- Required previews and automated checks: owner looks in Blender and the Godot editor; CI import.
- Human acceptance criteria: the platform reads as part of a solid track, its border lights set into it.
