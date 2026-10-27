# Asset spec: Pulse Void, the giant receiving dish (blockout)

- Ticket / owner: Pulse Void's new concept (owner, 2026-10-27: concept A, the giant radio dish; the old audio rings are
  removed, no switch back; blockout first, no references yet).
- Story: a signal from deep space; the player is its receiver. They stand on the feed cabin at the focus of a radio
  dish 500 m across; the track is the cabin's maintenance beam reaching forward. The dish's rim runs round the
  horizon; far ahead past it, the pulsar the signal comes from.
- Layout (metres, player at the origin, the track toward -z):
  - The dish: a paraboloid 500 m across, its vertex 125 m under the player, its focus at the player and its rim at
    the track's height all round (a deep dish, focal length a quarter of the diameter). Panels in 14 rings of 48
    from 20 m out to the rim; a hub plate in the middle; a rim truss round the edge.
  - The feed cabin under the player (6 x 7 x 6) and the maintenance beam under the track to 61 m ahead.
  - Four feed legs from the cabin's corners down to the dish 200 m out (near the rim), at 45 degrees either side of ahead and
    behind: below the horizon all the way, clear of the note lanes.
  - Masts on the rim ahead, either side, carrying the beacons.
  - Main elements symmetric (dish, legs, cabin, masts); props uneven: a control room on the dish's surface left of
    ahead, a cherry picker on it to the right, cable trays down the front-right leg.
- Light carriers (AGENTS.md "Light", rule 5):
  | Group | Carrier |
  |---|---|
  | Square bars (Beat Saber's ring lights, which the old rings carried) | light rows along the dish's panel seams, a concentric ring at each ring of panels (ArchStrip.gdshader); lit from the rim toward the player as the show builds, the whole dish on the drop |
  | Left lasers' light on the old rings | gone with the rings; the left waving lasers keep it |
  | Diagonal lasers | floodlights standing on the four feed legs |
  | Waving lasers | beacons on the masts at the rim |
  | Back lasers, centre lights | the sky: the halo and the pulsar's core at the track's end (PulseVoidSky.gdshader) |
  | Floor lights | the maintenance beam's edge lights (the track deck) |
  | The drop | a beam of light from the far rim straight up toward the pulsar's sky (lit with the whole dish) |
- Song evolution: the seam rows light ring by ring from the rim inward with the build-up (the dish locking on); on
  the drop every row and the beam light.
- Look: black darks, thin haze in the map's light colours (the scenery's EnvSolid haze); sky drawn 950 m out (inside
  the camera's 1,024 m far plane), past the rim.
- Budget: 13.9 ms at 72 Hz. The dish fills the lower half of the view in one opaque layer: watch fill. Blockout about
  12k triangles of scenery, +3 draw calls over the old rings.
- Review: owner in the stage window and Godot, then on the headset; Blender models after the blockout is OK.
