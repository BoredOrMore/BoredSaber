# Asset spec: wall machinery kit

- Ticket / owner: Metal Factory stage, fifth detail asset (order set 2026-10-25) / Claude, owner reviews.
- Gameplay purpose / song / genre: none for gameplay; the hall's side walls, so it reads as an underground plant and
  presses in (plan doc: scale, mass, darkness). The "breathing" (panels shifting, vents brightening with the show's
  intensity) comes after the owner approves the shapes. Metal Factory only.
- Reference files and views: none; the approved blockout.
- Confidence and assumptions: an original, generic industrial kit; sizes from the blockout.
- Dimensions / units / origin / axes: metres. Every piece's back is on the wall's face, its front toward the track;
  origin at the back, centred along the hall, at its foot (pipes: the run's middle).
  - column: I-beam 0.8 m wide, 0.6 m deep, 19 m high, 1 m base plate; since the vault (springline 17 m) its top runs
    up into the vault's shell and the rib above it continues its line.
  - panel: 7.2 m along the hall, 7.6 m high, framed, four louvers 6 m long; set above the catwalk (foot 8.5 m up).
  - pipes: three 0.6 m pipes side by side, 0.4-1.8 m out, 8 m long, two brackets; under the catwalk (6.7 m up), clear
    of the tall machine's tank (top 6 m) and the catwalk (underside 7.4 m).
  - machine (tall, low): 3 m deep, 4 m long; plinth, body to 4.4 m (low 2.6 m), three ribs, a tank on top piped back
    into the wall.
  - In the rig: walls at x ±18; columns every 8 m from z 0 to -56; panels, pipes and machines in each bay between,
    z -4 to -52; machines tall and low in turn; the right wall's pieces turned half round.
- Silhouette landmarks / required features: vertical rhythm of columns, horizontal louvers and pipes, machine masses
  at the floor.
- Materials / palette / emission: the hall's EnvSolid material (light_spill 0.3); occlusion baked into vertex colour red.
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: column 48, panel 108, pipes 72, machine 100 each (plan ~150 a piece); in the
  hall 16 columns, 14 panels, 14 pipe runs, 14 machines = 4,712 triangles in five MultiMeshes; no textures.
- Export format / destination: `game/models/wall_column.glb`, `wall_panel.glb`, `wall_pipes.glb`, `wall_machine.glb`,
  `wall_machine_low.glb`; source `tools/models/wall_kit.py` (bake and export shared in `tools/models/model_export.py`).
- Existing Godot resources affected: `game/env/MetalFactoryRig.gd` (replaces the machine boxes; the wall slab, catwalk
  and end piers stay boxes).
- Required previews and automated checks: owner looks in Blender and the Godot editor; CI import.
- Human acceptance criteria: the walls read as heavy machinery, dark, not busy, nothing near the note corridor.
