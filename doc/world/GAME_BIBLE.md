# Game bible

Lasting facts about BoredSaber's world. Template from the rhythm-world suite; fill the open questions with the
owner rather than inventing answers.

## Core experience
- Genre: VR rhythm game, cutting notes to music with two sabers (Beat Saber maps from BeatSaver).
- Platform: Pico 4 (standalone, Godot Compatibility renderer, 72 Hz for every scene: a 13.9 ms frame (owner, 2026-10-26)); a Quest build too.
- Viewpoint: first person, standing, facing -z.
- Comfort: no artificial movement; short, moderate flashes; nothing large and saturated.

## World premise
- Setting: five stages: Classic (steel tunnel and rings), Neon Grid, Night City, Pulse Void, Metal Factory.
- What the space is: a concert stage built for the song being played.

## Gameplay constraints
See `SPATIAL_LAYOUT.md` (origin, bounds, corridor, exclusion zones) and the root `AGENTS.md` colour rules.

## Decisions (owner, 2026-10-24)
- A map with no light events plays in the dark.
- Stages change during a song: structure can assemble during a build-up. Design still to be agreed (below).
- Each stage has a story (below).

## Metal Factory (owner, 2026-10-25)
- Its energy strips take the note colours like every other light: no orange, no new colour role.
- Pistons slam on the map's beat (from its BPM, every beat or every 2 beats), only while the show's intensity is high.
- At the drop only the side and far pieces turn, on different axes and in different directions; the floor and the
  track never move (a rest frame against vection).
- On "Auto" a song tagged metal, dubstep or drum-and-bass on BeatSaver plays in it (on since 2026-10-25; BeatSaver has
  no "industrial" tag). A map that names a Beat Saber environment in `Constants.MAP_ENVIRONMENTS` keeps that one first,
  and of several tags the first the table knows wins.

## 90° and 360° maps (owner, 2026-10-29)
- The track (deck and its edge strips) turns to where the notes come from; the stage never turns (a rest frame).
- One new stage, built for 360°, is the default for 90° and 360° maps. A map that names a stage not ready for
  360° gets the new stage instead. The BeatSaver page keeps hiding maps without a Standard difficulty.
- The new stage is Henge (concept, not built; GPU 7.5-9 ms estimated by the budget agent, not measured):
  - Feeling: held breath, then release. Abstract: shape and light, no place to explain it.
  - Shape: 24 black monoliths in a circle round the player, about 150 m out and 120 m tall, on a dark floor; a faint
    neutral glow on the horizon behind them. Nothing moves; only light does.
  - Light on the shapes: strips on the slabs' inner edges, short narrow beams from their tops, a ring strip on the
    floor. The map's left and right light groups go to the slabs left and right of where the track points at that
    moment.
  - Shadow: the slabs stand as silhouettes against the horizon glow; bands of light from the gaps between them,
    with the slabs' shadows between, rake across the floor toward the player.
  - Build-up: slab edges light one by one round the circle; drop: every gap floods at once.
  - Budget notes: draw the floor bands in vertex colour on a wedge mesh, not per pixel; split slabs and strips in
    four quadrants for culling; keep the drop's floor flood below the notes' brightness.

## Monolith (owner, 2026-10-31)
- Picked after two rounds of concepts (doc https://claude.ai/artifact/Moa8du6uKSKjhjsekRMvj4). Rejected: Shaft, a
  vertical cylinder 70 m round, because notes fly in from 300 m and came out of its wall. Rule from it: the notes'
  fly-in stays clear, nothing within about 320 m between y -5 and +30. Henge breaks it too; the owner keeps Henge as is.
- "Feels tiny" means (owner, 2026-10-31): in open space with something massive, not inside it or at its centre.
- Abstract, no story. In the Auto pool.
- Feeling: standing before something that was here before you. One black slab (1:4:9), 360 m wide, 810 m tall, 90 m
  deep, 520 m away, 30 degrees left of ahead, its face turned to the player, on an open dark plain.
- Light on the slab only: its two vertical edges (left and right lasers), 8 horizontal seams (square bars), a slit up
  its middle and a strip along its foot (floor lights), beams up its face from fixtures at its foot (diagonal and
  waving). A faint neutral glow on the horizon behind it; its shadow falls across the plain toward the player.
- Build-up: seams light from the foot up; drop: the slit opens to the top, then closes back low.
- The main form is one symmetric object placed off-centre on purpose (the point of the stage); props still to come.
- Setting (owner, 2026-10-31): the player stands on a tall pillar in the middle of a valley, looking down on terraces
  stepping away below, the slab ahead down the valley, stylized low clouds drifting among the terraces (owner's pick
  "clouds among terraces" over "above a sea of cloud" and "clouds only far away").

## Stage stories (agreed with the owner, 2026-10-24, as a first version)
- Classic: a steel tunnel where a lighting crew rehearses its show. The rings are calibration gates; the moving
  heads are the crew's rig, waiting for the song to start.
- Neon Grid: a live broadcast stage on an endless grid at sunset. The poles along the way are the studio's light poles.
- Night City: a rooftop concert among tall towers. The lasers are mounted on the roofs, and the whole city moves to
  the beat.
- Pulse Void: a signal from deep space. The rings are the signal itself; the player is its receiver.
- Metal Factory (owner, 2026-10-25): an underground power plant that the player's signal wakes up.

## Open questions
- What does each stage's story change in how it looks or moves (and in its build-up)?
- Build-up structure: what marks a build-up (a map has no build-up data; candidates: light-event density, note
  density, song progress), which pieces assemble, from where, and how fast, without crossing the note corridor?
- Should any stage age, wear or take damage across a song?
