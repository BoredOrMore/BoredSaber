# Wall workout: research for the Workout label

Measured 2026-10-20, after the player asked whether the game can tell maps whose walls make you
move like a workout (lean side to side, squat). See "Research before changing game feel" in the
root `AGENTS.md`.

## Definitions

Player stands between the two middle columns (x = 1 and 2) of the 4-wide grid; rows 0-4 (v2 full
walls = rows 0-4, v2 crouch walls = rows 2-4).

- **Lean:** a wall from the floor (y = 0, h >= 3) over exactly one middle column: the body must move
  to the other side.
- **Squat:** a wall over the head row (y <= 2 < y + h) with room below (y >= 1), across both middle
  columns.
- Walls of the same move starting within 0.1 s are one move.
- **Set:** at least 8 moves of the same kind (lean or squat), each no more than 4 s after the last.
  8 repetitions is the low end of the ACSM resistance-training guideline (8-12 per set); 4 s keeps
  it a steady rhythm rather than the odd wall.
- **Set share:** time from the first to the last move of each set, summed, over the song's note span.

## Results

| Sample | Difficulties | With at least one set | Median set share | p75 set share |
|---|---|---|---|---|
| BeatSaver popular + ranked | 464 | 9 % | 0 % | 0 % |
| BeatSaver tag `fitness` (top 20 by rating) | 72 | 58 % | 18 % | 72 % |
| Test headset songs | 77 | 6 % | 0 % | 0 % |

Moves per minute: popular maps median 0 leans (65 % have none) and 0 squats (93 % have none);
fitness maps median 11.8 leans and 4.7 squats per minute. Most "wall" difficulty in popular maps is
isolated dodges, not exercise. Headset best: JUMP Hard 2 sets, 16 leans (14 % of the song).

## Bands

| Label | Rule |
|---|---|
| (none) | no set |
| Some workout | at least one set |
| Workout | set share >= 30 % (between the fitness median and p75) |

Starting point from data; confirm with headset playtests.

## Sources

- BeatSaver API search with `tags=fitness`: https://api.beatsaver.com
- Obstacle fields (v2 `_type`, `_lineIndex`, `_width`; v3/v4 `x`, `y`, `w`, `h`, `d`):
  https://bsmg.wiki/mapping/map-format.html
- ACSM position stand on resistance training (8-12 repetitions per set):
  https://pubmed.ncbi.nlm.nih.gov/19204579/
- Script: `doc/research/wall_research.py` (`python3 -I wall_research.py <zip_or_song_dir> ...`).
