# Asset spec: Pulse Void's props

- Ticket / owner: Pulse Void's giant receiving dish, model 5, the last (owner, 2026-10-27: the rim and masts OK) /
  Claude, owner reviews.
- Purpose: the dish crew's kit, the familiar-size cues on a surface 500 m across; uneven left and right (main
  elements symmetric, props not).
- Parts, built where they stand as one mesh: a control room ahead left on the dish's surface (14 x 6 x 10 m on a base
  down into the slope, a window band on its track side and front, a roof slab and a roof unit, a stair down the base);
  a cherry picker ahead right (chassis on four wheels, outriggers to pads, turret, a two-section boom up toward the
  panels, a bucket with a rail); a cable tray down the front-right feed leg (a channel with the cable bundle in it,
  brackets to the leg every 40 m).
- Size and pivot: origin at the player's floor (Blender -y is Godot +z); the dish and leg numbers repeat PulseVoid's.
- Sightlines: on the dish's surface 215-222 m out, near the rim, 7-9 degrees under the eye (nearer in, the cabin's
  roof and its side parapet hid them: everything over ~18 degrees down to the sides); below the horizon and far
  outside the note corridor.
- Materials: EnvSolid base (the rig's); occlusion baked into vertex colour red. Flat shading. No glow.
- Placement: PulseVoid: one mesh at the origin, replacing the blockout's prop boxes.
- Budget: about 700 triangles; +1 draw call.
- Export: `game/models/dish_props.glb`; source `tools/models/dish_props.py`.
- Review: owner in Blender and Godot, then on the headset.
- Placement (owner, 2026-10-27): the control room stands on the ground outside the rim (286 m, left), as real ones
  stand off the dish; the cherry picker is replaced by a repair gondola hung by a cable from the front-right mast over
  the panels (no vehicle stands on a 40-degree dish); the calibration laser station at the bridge's end on the front
  rim, on the track's centre line past the bridge's end (it stood right of the track and the beam was off centre),
  is the drop's beam's source. About 450 triangles.
