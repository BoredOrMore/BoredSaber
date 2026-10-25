# Asset spec: laser fixture (moving head and yoke)

Written after the fact from the work of 2026-10-24, when the pipeline arrived.

- Ticket / owner: Classic stage look / Claude, owner reviews on the headset.
- Gameplay purpose / song / genre: none for gameplay; the light source every laser beam leaves from (AGENTS.md "Light", rule 5). All songs, all stages.
- Reference files and views: none; Beat Saber references described in the style frame (Claude Design "BoredSaber Classic Style Frame").
- Confidence and assumptions: shape is an original generic moving head; sizes tuned on the headset by the owner.
- Dimensions / units / origin / axes: metres. Head 0.45 m across, 0.58 m long; yoke 0.58 m wide, foot 0.54 m below the tilt axis. Origin at the tilt axis (the laser's pivot). Lens faces Godot -z; yoke arms along x.
- Silhouette landmarks / required features: barrel, recessed lens with bezel, back cap, U yoke with two arms, stem, base plate.
- Materials / palette / emission: one shared unshaded material (`LaserFixture.gdshader`): dark metal, occlusion baked to vertex colour red, lens marked in green and lit in the beam's colour; a camera-facing glow (`LaserFlare.gdshader`).
- Collision or hitbox requirements: none.
- Geometry / texture / material budgets: under 200 triangles per part (head 198, yoke 76); no textures; one material.
- Export format / destination: `.glb` in `game/models/laser_fixture.glb` and `laser_fixture_yoke.glb`; source `tools/models/laser_fixture.py`.
- Existing Godot resources affected: `game/env/LaserFixtures.gd`, `game/env/ClassicRig.gd` (`FIXTURE_Y`), `game/event_driver.gd`.
- Required previews and automated checks: four review renders; CI import; logcat after install.
- Human acceptance criteria: reads as a real fixture from the player's place, size right, head follows the beam without glitches, stays when its light is off.
