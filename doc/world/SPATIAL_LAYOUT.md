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
  Metal Factory, dark glass in Neon Grid, plain plates elsewhere. Nothing runs across the deck (any such line read as a
  beat line, owner 2026-10-25): only the lane grooves along it. It has no end to be seen (owner, 2026-10-25): the deck, its edges and their strips run on to z -150 (Metal Factory:
  -66, its foundation, before the gear pit) and fade fully into the haze from 45 m out to 2 m short of their end. The
  old track's far end piece (Endpath, z -85) shows only with the old track. The old see-through sheet stays for mixed reality and the Old track
  setting (Settings > Advanced).
- The giant test tunnel (`ClassicRig.gd`, 2026-10-27; spec `doc/assets/classic_tunnel/spec.md`): a round bore 120 m
  across (`BORE_RADIUS` 60, centre y 59), the track along its bottom. Ribs (`tunnel_rib.glb`, 2.4 x 3 m section) every
  25 m from z 25 to -600 (`RIB_STEP`, `RIB_NEAR`, `RIB_FAR`), 24 segments round; a lining (`tunnel_lining.glb`, 0.3 m)
  closes the bore between them; the parts under the floor are left out and a floor plate at y -0.3 reaches the lowest
  lining panels. Main elements symmetric, props not.
- Hanging scaffolds (`hanging_scaffold.glb`): six, at z -10 to -60 every 10 m (`FRAME_Z`), decks 40 x 3 m with their tops
  at y 20 (`SCAFFOLD_Y`) when in place, each on four cables (x ±16) up through the ceiling, a tool box on each deck
  in a different spot. They fly in from 75 m higher (`FLY`) as the show builds (far ones first, between 0.1 and 0.8 of
  the build-up) and stay; flown out at a song's start, in place for the menus.
- Wall catwalks (`wall_catwalk.glb`, 8 m spans): at y 8, 3 m wide, z -8 to -64 along both walls, their wall edge on the
  lining; the crew's props (`classic_props.glb`) near the track and a ladder up to the right one.
- Light carriers: moving heads (`laser_fixture.glb`, the diagonal lasers) stand in pairs on the scaffold decks, tilt
  axis 0.84 m above the deck (`FIXTURE_ABOVE`); the waving lasers' follow spots stand on the catwalks (tilt axis
  1.5 m above the deck, `FOLLOW_SPOT_PIVOT`); the square bars hang under the decks beside the track; rib strips
  (`ArchStrip.gdshader`) on the ribs' inner faces in the upper part of the ring run from far to near on the drop.
- The old Classic's square rings are retired (2026-10-27): `EventDriver.rings_enabled` is false, their node stays hidden.

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
  ahead above the foundation stays open; beyond it is the stage's own dark sky (`MetalFactorySky.gdshader`, near-black,
  no light colours), the darkest thing in view (eye capture, lights on: far opening luma 104 → 16 of 255).
- No laser beams or moving heads (owner, 2026-10-25): the diagonal and waving lasers' light glows in the wall panels'
  vent louvers (upper row both walls: diagonal; lower row: the left or right waving group by wall); the square bars
  are the energy rails' strips; the centre and floor lights are unchanged.

## Environment layout (Henge, blockout 2026-10-29)
Plain boxes in `HengeRig.gd`, every size a named constant there; for 90 and 360 degree maps (GAME_BIBLE.md).
- The player stands at the centre (z 1), on the round platform; there is no track floor ahead on these maps, only the
  turn cue chevron 2.6 m out (`TrackDeck`).
- 24 monoliths in a ring, 15 degrees apart, the first straight ahead: inner faces 150 m from the player, 12 m across,
  3 m deep, 120 m tall, standing on the floor; gaps about 27 m (10.4 degrees) between them. Black, unlit.
- A strip up each slab's two inner vertical edges (0.4 x 0.3 m), the left or right lasers' colour by the slab's side
  of the track's current direction.
- Floor: a disc 200 m out at y -0.4 (under the platform's base), dark, with the gaps' bands of light in vertex colour
  (brightest at the slab ring, nothing at the player or the floor's edge); a ring strip on it 140 m out (0.6 m wide)
  in the floor lights' colour.
- Beams: the diagonal lasers straight up from slab tops round the circle, the waving lasers on the slabs between.
- Sky: dark, a neutral glow along the horizon behind the slabs; the sky sphere at 950 m.
- Note corridor: nothing stands within 140 m in any direction. Notes fly in from up to about 300 m
  (`Cuttable.FLY_DISTANCE`), so their fly-in crosses the slab ring; not yet checked on the headset.

## Monolith (BLOCKOUT 2026-10-31, `game/env/MonolithRig.gd`)
- Slab: 360 m wide, 810 m tall, 90 m deep; front face 520 m from the player, 30 degrees left of ahead, facing them; its
  top front corners about 980 m away (camera far 1024 m).
- Pillar: the platform stands on a column 10 m round down to the valley floor at y -80.
- Valley: runs the slab's way (30 degrees left of ahead); its floor 460 m wide at y -80, bending 25 m either way; then
  terraces up both sides, 15 m higher every 30 m out (4 m steep faces), to ridges about +295 m at 980 m. The first
  terrace above y -5 starts beyond 325 m. The slab stands on the valley floor (top about 950 m away); its shadow falls
  down the valley toward the player.
- Clouds (owner's reference, 2026-10-31: stylized flats): 4 upright rings at 220, 360, 520 and 760 m, each a band up
  from the valley floor topped by a row of round puffs; the 220 m ring's puffs top out near y -11; beyond 320 m they
  rise to about +60 m at 760 m, hiding the slab's foot. Edges soft (a fringe 0.012 rad wide, owner 2026-10-31);
  terrain, pillar and slab below the clouds' level take the cloud's tone, so nothing pokes through a cloud.
- Lights: drawn on the slab's face (edges 3 m, seams 1.5 m every 90 m, slit 2 m, foot strip 2 m); beam fixtures along
  its foot, 2 m in front of the face.
- Sky: black, a neutral glow low on the horizon behind the slab and a fainter one all round behind the ridges.
- Note corridor: within 320 m in any direction nothing rises above y -5 but the platform itself; the notes' 300 m
  fly-in is clear.

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
Henge blockout captures: `captures/henge_blockout_*.png` (front, side, behind, top, a 360 map in play).

Blender render from (0, 1.6, 1) looking down -z before building; headset screenshots in play after.
