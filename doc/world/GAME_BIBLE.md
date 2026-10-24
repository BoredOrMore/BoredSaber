# Game bible

Lasting facts about BoredSaber's world. Template from the rhythm-world suite; fill the open questions with the
owner rather than inventing answers.

## Core experience
- Genre: VR rhythm game, cutting notes to music with two sabers (Beat Saber maps from BeatSaver).
- Platform: Pico 4 (standalone, Godot Compatibility renderer, 72 or 90 Hz); a Quest build too.
- Viewpoint: first person, standing, facing -z.
- Comfort: no artificial movement; short, moderate flashes; nothing large and saturated.

## World premise
- Setting: four stages: Classic (steel tunnel and rings), Neon Grid, Night City, Pulse Void.
- What the space is: a concert stage built for the song being played.

## Gameplay constraints
See `SPATIAL_LAYOUT.md` (origin, bounds, corridor, exclusion zones) and the root `AGENTS.md` colour rules.

## Decisions (owner, 2026-10-24)
- A map with no light events plays in the dark.
- Stages change during a song: structure can assemble during a build-up. Design still to be agreed (below).
- Each stage has a story (below).

## Stage stories (agreed with the owner, 2026-10-24, as a first version)
- Classic: a steel tunnel where a lighting crew rehearses its show. The rings are calibration gates; the moving
  heads are the crew's rig, waiting for the song to start.
- Neon Grid: a live broadcast stage on an endless grid at sunset. The poles along the way are the studio's light poles.
- Night City: a rooftop concert among tall towers. The lasers are mounted on the roofs, and the whole city moves to
  the beat.
- Pulse Void: a signal from deep space. The rings are the signal itself; the player is its receiver.

## Open questions
- What does each stage's story change in how it looks or moves (and in its build-up)?
- Build-up structure: what marks a build-up (a map has no build-up data; candidates: light-event density, note
  density, song progress), which pieces assemble, from where, and how fast, without crossing the note corridor?
- Should any stage age, wear or take damage across a song?
