# Spatial layout

The real numbers, from code (2026-10-24). Change the code first, then this file. Template from the rhythm-world
suite (`.claude/skills/rhythm-world-design/`).

## Coordinate convention
- Units: metres. Up: +y. Forward (where notes come from): -z. Right: +x.
- Player: `XROrigin3D` at z 1, standing on the floor (y 0). Nominal eye height 1.7 m (`Constants.EYE_HEIGHT`).
- The player's height setting shifts the view by half of it, clamped to -0.6..+0.2 m (`Constants.view_shift`).

## Gameplay volume
- Lanes: 4, centres at x = -0.9 + 0.6 i (`DEFAULT_LANE_ZERO_X`, `DEFAULT_LANE_DISTANCE_X`), wider with the
  Wide 125-200% modifiers.
- Rows: y 0.85 / 1.40 / 1.90 (`Constants.ROW_Y`), extrapolated outside the grid.
- Hit plane: the `Track` node sits at z 0.35 (`HIT_PLANE_Z`), so a note is on the beat 0.65 m in front of the player.
- Travel: notes move toward +z, 4 m per beat (`BEAT_DISTANCE`); a note past z 2.5 is a miss (`MISS_Z`).
- Crouch walls start at y 1.3 (`CROUCH_WALL_BOTTOM`).
- Platform: the player's lit border (`game/floor.tscn`), a 2 m pad at z 1. With the deck (`TrackDeck.gd`) it is part of the
  track: the deck runs from its front (z -0.1), a ring (`platform_frame.glb`) round the pad holds the border lights in its
  channel, plain plates fill out to the deck's width, the edges run on along its sides and an end stop closes it at z 2.1.

## Environment layout (Classic)
- Track: a deck (`TrackDeck.gd`, 2026-10-25) whose top is y 0, four lanes wide (2.4 m at normal width, wider with the
  Wide modifiers), 0.4 m deep, from the platform's front (z -0.1) on into the haze (below); along each side the track edge (`track_edge.glb`): a curb 0.08 m
  above the deck whose channel, 0.15 m out, houses the edge light strip (the floor-light group), and a skirt down to
  1.5 m below the deck, 0.42 m out. The deck's surface follows the stage (`TrackDeck.SKINS`): tread plate with rivets in
  Metal Factory, dark glass in Neon Grid, plain plates elsewhere. It has no end to be seen (owner, 2026-10-25): the deck, its edges and their strips run on to z -150 (Metal Factory:
  -66, its foundation, before the gear pit) and fade fully into the haze from 45 m out to 2 m short of their end. The
  old track's far end piece (Endpath, z -85) shows only with the old track. The old see-through sheet stays for mixed reality and the Old track
  setting (Settings > Advanced).
- Tunnel frames: every 10 m from z -10 to -60, inner edges at x ±11.6, top y 11.6 (`ClassicRig.gd`).
- Near gate around the player: z 0.5, half-width 3.5, top 4.5, for parallax.
- Rings: square frames 12.4 m across, out to z -55, spinning on light events.
- Laser fixtures: diagonal at x ±4.5, z -30 to -50; waving at x ±12.43, z -21 to -30, each on a pedestal
  (top y 0.05) with a moving head whose tilt axis is 0.54 m above it (`ClassicRig.FIXTURE_Y`, `LaserFixtures.gd`).

## Environment layout (Metal Factory, blockout 2026-10-25)
Plain boxes in `MetalFactoryRig.gd`, every size a named constant there; detail models still to come.
- Factory floor: either side of the track from x ±3.6 to ±18, z 4 to -56 (top y 0), and under the track and the
  player's platform (top y -0.02), so no sky shows between or past them; a pit beyond it to the foundation
  (z -66 to -70, top y 0).
- Pistons: two rows at x ±8, z -12 to -44 every 8 m. Anvil (`anvil_base.glb`) 3.6 m square at its foot, a shelf
  at 1.2 m and a 2.4 m strike die on top at 1.5 m; hammer 2.2 m, raised (bottom y 3.8); housing under a header beam
  at y 9, carried by posts at z -8 to -48 every 8 m.
- Gear rings (`gear_ring.glb`): around the track at z -15 to -55 every 8 m, centre y 2, rim 6.2 to 6.8 m out, 12 teeth
  to 13.6 m across, running down through the floor; inner edge 6.2 m from the centre.
- Energy rails: x ±4, z 2 to -48, top y 0.3, 0.4 m wide; the square bars run as strips flush on top.
- Machinery walls: solid at x ±18 to ±20, up to y 17 (the vault's springline), z 6 to -68; catwalk ledge along the inner face at x ±16, top
  y 8. On the wall's face the wall kit (`wall_*.glb`): I-beam columns every 8 m from z 0 to -56 (floor to ceiling);
  in each bay between (z -4 to -52) a louvered panel above the catwalk (y 8.5 to 16.1), a run of three pipes under
  it (centred y 6.7, out to x ±15.9) and a machine on the floor (3 m deep, 4 m long; tall to y 6, low to y 4.2, in
  turn).
- Vault (owner's sketch, 2026-10-25: the top half of an octagon tube): the walls rise to the springline at y 17,
  then each side turns in at 45 degrees for 9 m to a flat crown at y 26, x ±9; a solid 1 m shell from z 6 to -68, so
  no sky shows overhead (underground). Ribs (0.6 m) follow the outline every 8 m from z 0 to -64 and beams run the hall's
  length at the four corner lines (MetalFactoryRig._vault); nothing spans the hall below the vault.
- The hall's faces take 0.3 of the lights' spill (`MetalFactoryRig.LIGHT_SPILL`, EnvSolid `light_spill`), so the
  big walls and ceiling stay near black (eye capture, lights on: wall luma 39 → 29 of 255; lights off 24).
- Drive gears at the far end, facing the player (`drive_gear_large/small.glb`): root radius 10 (22.4 m across the
  teeth) at x ±17, y 2, z -58 (half in the walls' end piers); root radius 7.5 (17.4 m across) at x ±9, y -6, z -62 in
  the pit (top about y 2.7). Axles into the piers and foundation. The view straight
  ahead above the foundation stays open; beyond it is the stage's own dark sky (`MetalFactorySky.gdshader`, near-black
  navy, no light colours), the darkest thing in view (eye capture, lights on: far opening luma 104 → 16 of 255).
- No laser beams or moving heads (owner, 2026-10-25): the diagonal and waving lasers' light glows in the wall panels'
  vent louvers (upper row both walls: diagonal; lower row: the left or right waving group by wall); the square bars
  are the energy rails' strips; the centre and floor lights are unchanged.

## Exclusion zones
- The note corridor: lanes ±1.2 m (more when wide), y 0 to 2.5, from the player to the far spawn. No scenery,
  particles or bright light inside it.
- In front of the horizon: structure goes to the sides and below it (Light rule 5).
- Mixed reality: only the track, notes, sabers and beams are drawn; scenery would cover the player's room.

## Sightlines
- The note corridor straight ahead, at every row, at every height setting.
- Each environment's signature view toward the horizon.

## Validation
Metal Factory blockout captures (Godot `tools/capture/stage_capture.tscn`): `captures/metal_factory_blockout_*.png`.

Blender render from (0, 1.6, 1) looking down -z before building; headset screenshots in play after.
