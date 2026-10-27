# Asset spec: Neon Grid arch parts (section, footing, scaffold)

- Ticket / owner: Neon Grid arches, models after the blockout (owner, 2026-10-26: last, the arch detail) / Claude,
  owner reviews.
- Purpose: make the three arches read as built megastructures from 150-800 m: sections joined by flanges, panel seams,
  ribs and bracing on the outer face, concrete footings where the legs meet the grid, and on C's unfinished end,
  scaffolding round the exposed structure where the crane works.
- Parts (all in one script, three exports):
  - Section: a unit piece of an arch (x across, y toward the arch's middle, z along the curve, -0.5..0.5), scaled by
    the rig to the arch's section and the segment's length: the body, a flange ring at one end (the joint to the next),
    a panel seam halfway, two ribs and a diagonal brace on the outer face. The inner face stays plain for the light
    strips (ArchStrip.gdshader), which keep their place.
  - Footing: a stepped concrete plinth with a steel bearing plate, unit-sized, scaled to each leg's section.
  - Scaffold: a scaffold tower round C's unfinished end: four posts, ledgers at four levels, diagonal braces, working
    platforms; 40 m tall, 30 x 22 m, open on the side the crane reaches over.
- Distance: 150-800 m, so details are chunky (no member thinner than about 1/40 of the section), and nothing thin
  enough to shimmer.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: NeonGridRig: sections replace the arch boxes (one MultiMesh), footings at each built leg (one MultiMesh),
  the scaffold on C's end (one mesh). None in front of the sun or the horizon's centre (front view checked).
- Budget: section under 100 triangles (about 75 copies), footing under 60, scaffold under 400; +3 draw calls over the
  blockout (the arches leave the rig's box MultiMesh).
- Export: `game/models/arch_section.glb`, `arch_footing.glb`, `arch_scaffold.glb`; source `tools/models/arch_parts.py`.
- Review: owner in Blender and Godot, then on the headset.
