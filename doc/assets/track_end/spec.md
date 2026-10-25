# Asset spec: track end stop

- Ticket / owner: track and platform plan T4 (owner, 2026-10-25: the edge lights "just disappear" where the track
  ends) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the deck's far end on every stage, which the edge light strips
  run into.
- Reference files and views: none.
- Confidence and assumptions: a low block, not a gate: notes and walls appear well before the track's end, so it is
  behind them, and it stays below the horizon (Light rule 5: nothing in front of the horizon). A taller per-stage gate
  (Metal Factory's blast door) would stand in front of the horizon, so it is left for the owner to decide.
- Dimensions / units / origin / axes: metres. 1 m wide as built (stretched across the deck and both edges), top 0.5 m
  above the deck with a 0.12 m chamfer on its near edge, 1.2 m deep, near face down to -1.5 m (the edges' skirt).
  Origin at the middle of its near face, on the deck's top; placed at z -48.
- Silhouette landmarks / required features: a solid stop the strips end against.
- Materials / palette / emission: EnvSolid; occlusion baked into vertex colour red.
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: 14 triangles; no textures.
- Export format / destination: `game/models/track_end.glb`; source `tools/models/track_end.py`.
- Existing Godot resources affected: `game/env/TrackDeck.gd`, `game/event_driver.gd` (the old Endpath shows only with
  the old track).
- Required previews and automated checks: owner looks in the Godot editor; CI import.
- Human acceptance criteria: the edge strips end on something; nothing new stands over the horizon.
