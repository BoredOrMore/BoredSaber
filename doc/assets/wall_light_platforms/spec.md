# Asset spec: Night City wall light platforms

- Ticket / owner: Night City light carriers (owner, 2026-10-27, option ก): the lights on the tower wall floated on its
  face (AGENTS.md "Light", rule 5: the carrier belongs to the world).
- Purpose: small steel maintenance platforms sticking out of the tower wall, one under each wall light: the stage
  crew's mounts for the concert's lights. Props: sizes differ a little, placement uneven.
- Dimensions: metres. Slab 1.3-1.7 out from the wall, 2.2-3.4 along it, 0.2 thick, 0.3 under the fixture; a front rail
  1.0 high with two posts; a 45-degree strut from the slab's front edge back down to the wall. Heights unchanged: the
  diagonal lasers at 18/34/52/72/96 m, the waving searchlights at 12/40/80/120 m (NightCityRig.WALL_DIAGONAL_Y,
  WALL_SEARCHLIGHT_Y); each fixture now stands half its platform out from the wall.
- Method: boxes in the props' MultiMesh (NightCityRig._wall_platforms), as the low-roof edges: no draw call of their
  own. Boxes carry no baked occlusion; the scenery shader's form shading sets the slab's top apart from its edge.
- Materials: EnvSolid no-window canyon variant (the rooftop props' material).
- Budget: 10 platforms x 5 boxes x 12 triangles = 600 triangles; +0 draw calls.

## Night City: light group -> carrier
| Group | Carrier |
|---|---|
| Diagonal lasers, wall side | fixtures on the maintenance platforms out of the tower wall (this asset) |
| Diagonal lasers, open side | fixtures on the low roofs' inner edges |
| Waving lasers, wall side | searchlights on the maintenance platforms (this asset) |
| Waving lasers, open side | searchlights standing on the low roofs |
| Square bars | trims on the low roofs' edges; the billboards, on their arms off the tower wall |
| Ring and centre lights | the city in the sky: the skyline's rims, its far glow and windows |
| Floor lights | the track's edge lights |
| (song-driven) | the towers' windows |
