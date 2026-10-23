# Reaction time and swing gap: research for difficulty labels

Measured 2026-10-19 from BeatSaver map data, to set player-facing difficulty bands from evidence
instead of guesses (see "Research before changing game feel" in the root `AGENTS.md`).

## Definitions

- **Reaction time (RT):** how long a note is visible before it reaches the player. Same formula as
  `Map.set_note_jump` (Beat Saber's): half jump starts at 4 beats, halves while
  `njs * (60 / bpm) * hjd > 17.999`, then `hjd = max(hjd + offset, 0.25)`; `RT = hjd * 60 / bpm`.
  Needs only Info.dat values (BPM, NJS, offset). Divide by the Speed modifier when it isn't 100%.
- **Swing gap:** time between two consecutive notes of the same hand. Notes closer than 50 ms are
  treated as one swing (stacks, windows). Per difficulty we keep the median gap.

## Method

- Sample: BeatSaver search API, 15 pages each of `sortOrder=Rating&ranked=true` and `sortOrder=Rating`,
  Standard characteristic only: 1,824 difficulties (945 with a BeatLeader star rating, `blStars`).
- Swing gaps: map zips for the first 80 maps of each sample, v2 `_notes`, v3 `colorNotes`, v4
  `colorNotes`+`colorNotesData`: 469 difficulties.
- Script: `doc/research/rt_research.py` (run with `python3 -I rt_research.py <data_dir> 15 80`).

## Results

Reaction time by difficulty (ms):

| Difficulty | n | p10 | p25 | median | p75 | p90 | median NJS |
|---|---|---|---|---|---|---|---|
| Easy | 206 | 811 | 938 | 1125 | 1400 | 1633 | 11 |
| Normal | 257 | 732 | 814 | 960 | 1200 | 1429 | 12 |
| Hard | 414 | 643 | 714 | 846 | 984 | 1200 | 14 |
| Expert | 499 | 570 | 618 | 706 | 835 | 942 | 16 |
| Expert+ | 448 | 500 | 535 | 583 | 654 | 756 | 18 |

Median swing gap by difficulty (ms):

| Difficulty | n | median | p25 | p75 |
|---|---|---|---|---|
| Easy | 52 | 1008 | 706 | 1446 |
| Normal | 67 | 723 | 571 | 938 |
| Hard | 105 | 568 | 429 | 714 |
| Expert | 128 | 424 | 351 | 496 |
| Expert+ | 117 | 341 | 248 | 390 |

Against BeatLeader stars (community difficulty rating), median RT: 0–3★ 960 ms, 3–5★ 735 ms,
5–7★ 600 ms, 7–9★ 529 ms, 9–11★ 486 ms.

How well each measure predicts BeatLeader stars (n = 268, linear fit, R²): notes per second 0.75,
1/RT 0.64, 1/swing gap 0.68, RT + swing gap together 0.75, all three 0.78. RT and swing gap
together predict difficulty as well as notes per second, and they are easier for a player to
understand ("how long to read" + "how fast to swing").

## Bands derived from the data

Reaction time ("how much time you have to read a note"):

| Label | RT | Typical |
|---|---|---|
| Relaxed | ≥ 1000 ms | Easy, under 3★ |
| Comfortable | 800–1000 ms | Normal/Hard |
| Quick | 650–800 ms | Hard/Expert, 3–5★ |
| Fast | 550–650 ms | Expert+, 5–7★ |
| Extreme | < 550 ms | 7★ and up |

Swing pace (median same-hand gap, "how often each hand swings"):

| Label | Gap | Typical |
|---|---|---|
| Calm | ≥ 800 ms | Easy |
| Steady | 550–800 ms | Normal/Hard |
| Brisk | 420–550 ms | Hard/Expert |
| Rapid | 330–420 ms | Expert/Expert+ |
| Frantic | < 330 ms | hard Expert+ |

Band edges sit near the midpoints between neighbouring medians. They are a data-based starting
point; confirm them with headset playtests and adjust if a band feels wrong.

## Song list difficulty (2026-10-19)

Headset play found the mappers' labels and the reaction-time bands both misleading (a map labelled
Normal can need Expert+ reading speed). The song list now shows one difficulty per map difficulty,
named like Beat Saber's but computed from play: the harder of the reaction time and swing gap levels,
one level up when the swings are Tangled (doc/research/swing-flow.md). Edges are the midpoints between
the medians above:

| Level | Reaction time | Swing gap |
|---|---|---|
| Easy | ≥ 1040 ms | ≥ 866 ms |
| Normal | ≥ 903 ms | ≥ 646 ms |
| Hard | ≥ 776 ms | ≥ 496 ms |
| Expert | ≥ 645 ms | ≥ 383 ms |
| Expert+ | below | below |

The mapper's label is still shown on the info line. The BeatSaver download list has no swing data, so
there the difficulty filter uses reaction time only.

## Sources

- BeatSaver API (map metadata, per-difficulty NJS/offset/NPS, BeatLeader stars, map downloads):
  https://api.beatsaver.com
- Beat Saber jump formula as implemented by the bsmap library (NoteJumpSpeed: HJD, JD, RT helpers;
  fallback NJS Easy/Normal/Hard 10, Expert 12, Expert+ 16): https://jsr.io/@kvl/bsmap/doc/~/NoteJumpSpeed
- JDFixer (community mod that sets jump distance / reaction time per player preference; documents RT
  as a function of NJS and jump distance, no recommended values): https://github.com/zeph-yr/JDFixer
