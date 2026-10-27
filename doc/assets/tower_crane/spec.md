# Asset spec: tower crane on arch C

- Ticket / owner: Neon Grid arches, models after the blockout (owner, 2026-10-26: crane first) / Claude, owner reviews.
- Purpose: the crane building arch C's unfinished end. The tiniest familiar shape on the largest structure: a tower
  crane, itself tens of metres tall, reads as a toy on a 260 m arch, so the arch reads as enormous. It carries the right
  waving lasers as its work lights, hung under the jib (AGENTS.md "Light", rule 5: the carrier belongs to the world).
- Reference: a hammerhead tower crane: a square lattice mast, a slewing unit with the cab on one side, a long jib
  toward the work and a short counter-jib with concrete counterweights, an A-frame apex with tie bars, a trolley and a
  hook block hanging on its cable.
- Dimensions / origin / axes: metres. Mast 30 m tall, 2.4 m square; jib 70 m toward -x (the track), counter-jib 22 m
  toward +x; apex 8 m above the jib's root. Origin at the mast's foot; y up. The rig places it on arch C's unfinished
  end (NeonGridRig.crane_top: the jib's root).
- Silhouette: seen from 450-800 m, so the lattice is suggested, not modelled bar by bar: a solid core in each mast and
  jib section with corner chords and a few diagonals thick enough not to shimmer. Asymmetric: the cab on one side of
  the slewing unit, the trolley out at two thirds of the jib, the hook hanging off it.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow on the model (the
  work lights are the waving lasers' fixtures).
- Collision: none.
- Budget: under 500 triangles; one instance: +1 draw call (replacing three blockout boxes in the rig's MultiMesh).
- Export: `game/models/tower_crane.glb`; source `tools/models/tower_crane.py`.
- Review: owner in Blender and Godot, then on the headset.
