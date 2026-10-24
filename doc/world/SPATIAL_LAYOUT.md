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
- Platform: the player's lit border (`game/floor.tscn`).

## Environment layout (Classic)
- Track floor: about 7 m wide at normal width (`EventDriver.set_background`), from z -1.5 to -48.
- Tunnel frames: every 10 m from z -10 to -60, inner edges at x ±11.6, top y 11.6 (`ClassicRig.gd`).
- Near gate around the player: z 0.5, half-width 3.5, top 4.5, for parallax.
- Rings: square frames 12.4 m across, out to z -55, spinning on light events.
- Laser fixtures: diagonal at x ±4.5, z -30 to -50; waving at x ±12.43, z -21 to -30, each on a pedestal
  (top y 0.05) with a moving head whose tilt axis is 0.54 m above it (`ClassicRig.FIXTURE_Y`, `LaserFixtures.gd`).

## Exclusion zones
- The note corridor: lanes ±1.2 m (more when wide), y 0 to 2.5, from the player to the far spawn. No scenery,
  particles or bright light inside it.
- In front of the horizon: structure goes to the sides and below it (Light rule 5).
- Mixed reality: only the track, notes, sabers and beams are drawn; scenery would cover the player's room.

## Sightlines
- The note corridor straight ahead, at every row, at every height setting.
- Each environment's signature view toward the horizon.

## Validation
Blender render from (0, 1.6, 1) looking down -z before building; headset screenshots in play after.
