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
- Each stage gets a story; drafts below, not yet agreed.

## Stage stories (drafts to discuss)
- Classic: a steel test tunnel where a lighting crew rehearses a show. The rings are calibration gates; the
  moving heads on their pedestals are the crew's rig, waiting for the music.
- Neon Grid: a broadcast stage on an endless grid at sunset; the stages to the sides are the studio's light towers.
- Night City: a rooftop gig between towers; the lasers are mounted on the roofs and the city answers the beat.
- Pulse Void: a signal arriving from deep space; its rings are the pulse itself, and the player is the receiver.

## Open questions
- Which story drafts fit, and what does each stage's story change in how it looks or moves?
- Build-up structure: what marks a build-up (a map has no build-up data; candidates: light-event density, note
  density, song progress), which pieces assemble, from where, and how fast, without crossing the note corridor?
- Should any stage age, wear or take damage across a song?
