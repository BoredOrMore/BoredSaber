# Asset spec: Classic's follow spot

- Ticket / owner: Classic test tunnel, model 5, the last (owner, 2026-10-27: model order OK, the props OK) / Claude,
  owner reviews.
- Purpose: the light the waving lasers leave from on the wall catwalks (AGENTS.md "Light", rule 5: on something that
  belongs there): a theatre follow spot, a long can on a yoke on a tripod, the crew's kit.
- Parts (one script, two exports, as laser_fixture.py): the head (a barrel with the lens recessed at its front, the
  lamp housing at the back, a handle on top) and the stand (the yoke's arms up to the tilt axis, a post to a collar,
  three tripod legs to the catwalk's deck).
- Size and pivot: both at the tilt axis, 1.5 m over the deck (ClassicRig FOLLOW_SPOT_PIVOT); the lens faces Godot's
  -z, the beam's way; barrel 0.36 m across and 1 m long.
- Behaviour: LaserFixtures moves it as it does the moving heads (the stand turns about the vertical, the head tilts in
  it, rests nose down when its light is off); its lens is marked green and takes the beam's colour, black when off;
  the glow sits in front of its lens. Classic's waving lasers use it (EventDriver, LaserFixtures.set_kind), every
  other laser keeps the moving head.
- Distance: 28-70 m from the player, on the catwalks.
- Materials: LaserFixture.gdshader (with the moving heads); occlusion baked into vertex colour red.
- Budget: head under 100 triangles, stand under 150; +2 draw calls (each fixture kind is its own MultiMeshes).
- Export: `game/models/follow_spot.glb`, `game/models/follow_spot_stand.glb`; source `tools/models/follow_spot.py`.
- Review: owner in Blender and Godot, then on the headset.
