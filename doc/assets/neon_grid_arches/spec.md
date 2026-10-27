# Asset spec: Neon Grid, megastructure arches (blockout)

- Ticket / owner: Neon Grid ("Sunset") redesign, concept 2 picked by the owner (2026-10-26); replaces the old layout
  (no Classic switch).
- Story: the endless grid at sunset is the building site of arches far bigger than anything human. The broadcast stage
  is a speck among them.
- Layout (metres, player at the origin, the track toward -z):
  - Arch A: 300 m tall, spans the grid behind the player (centre x 110, z 160), leaning slightly toward them: they
    have passed under it.
  - Arch B: 350 m tall, far ahead on the left (centre x -450, z -420), its span along the track, leaning 15° out.
  - Arch C: 260 m tall, ahead on the right (centre x 450, z -450), only 62% built; its unfinished end carries a tower
    crane (mast 30 m, jib 70 m reaching toward the track).
  - None of them, and no beam, is in front of the sun or the horizon's centre (front view checked).
  - Near the player, at human size: a site cabin (container) behind on the left, a row of concrete barrier blocks and
    stacked girders on the right, survey masts (8-14 m) along the left at uneven spacing.
  - Nothing is mirrored across the track.
- Light carriers (AGENTS.md "Light", rule 5: the carrier belongs to the world):
  - Diagonal lasers: site floodlights at B's near footing (left) and C's far footing (right), fanning up and away
    from the sun.
  - Left waving lasers: survey beacons on top of the survey masts.
  - Right waving lasers: the crane's work lights along its jib.
  - Square bars (horizontal): light strips along the arches' inner edges, shared between A, B and C. The vertical
    bars are left out.
  - Ring lights and centre lights: in the sky (the horizon line, the mountains' rims, the sun), as before.
  - The old 3 m lamp poles, their rails and the two horizon stages are gone: they existed only to hold lights.
- To come after the blockout is approved: the strips climb the arches with the build-up and B lights fully on the
  drop; real models (arch sections with ribs, the crane, the cabin, the masts) in Blender.
- Technical: arches are 28 boxes along each half circle (C fewer) in the rig's one MultiMesh, EnvSolid base variant.
  The grid floor grew to 1900 m (63 subdivisions; its far part is plain haze, as before) and the sky sphere is drawn
  at 950 m (inside the camera's 1024 m far plane), as in Night City.
- Budget: 19.1k triangles and 15 draw calls in view (was 12.3k and 16); the floor is most of the triangle increase.
  Not yet measured on the headset.
