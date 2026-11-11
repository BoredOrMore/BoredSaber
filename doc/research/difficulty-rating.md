# Difficulty rating: levels from BeatLeader's star scale

Measured 2026-11-10, after the owner found levels "slightly off somewhere" and asked whether a hand slicing on the
other hand's side should count even when a map isn't twisty (see "Research before changing game feel" in the root
`AGENTS.md`). The owner picked a continuous score fitted to BeatLeader's stars (option C) and agreed to its level
cut-offs; Get songs reads BeatLeader's own stars.

## What the levels were

`MapStats.level_of` took the harder of the reaction time level and the median swing gap level, one level up when the
swing flow was Tangled (10 % or more; `doc/research/reaction-time-and-swing-gap.md`, `doc/research/swing-flow.md`).
Crossing the body counted only at the far column, and only inside the flow percent, so a map with 5-9 % crossovers
and smooth swings got no harder. Get songs estimated the swing gap from BeatSaver's average notes per second
(`doc/research/download-level-estimate.md`).

## Method

- Sample: the first 20 pages of BeatSaver's most liked maps (`sortOrder=Rating`), 404 maps, every Standard difficulty
  with at least 20 notes and a BeatLeader rating: 1,094 difficulties (Easy 110, Normal 148, Hard 263, Expert 306,
  Expert+ 267). BeatLeader rates every map, ranked or not, with its model (Pass, Tech and Acc ratings combined into
  stars), and at the Slower (0.85x), Faster (1.2x) and Super Fast (1.5x) song speeds too.
- Parts per difficulty, as `MapStats._swing_parts` counts them (per hand, notes within 50 ms are one swing):
  - **burst**: swings a second, both hands, in 4 s windows stepped 1 s; the 90th percentile of the windows (the song's
    hardest stretches; the old median swing gap hides dense sections);
  - **cross**: percent of swings on the other hand's side: the far column counts 1, the near middle column 0.5;
  - **crossed**: percent of swings made with the arms crossed: within 0.25 s of the other hand's last swing, the left
    hand's column right of the right hand's;
  - **turn**: the flow percent's turns and resets without the far-column crossovers.
- Fit: least squares of BeatLeader's stars on the parts, checked by 5-fold cross-validation grouped by map (a map's
  difficulties never sit in both the fitting and the checking part).
- Scripts: `doc/research/difficulty_fetch.py` (maps and ratings; hosts api.beatsaver.com, r2cdn.beatsaver.com,
  api.beatleader.xyz) and `doc/research/difficulty_fit.py` (parts, fit, cut-offs, comparison).

## Results

Spearman rank correlation of each part with BeatLeader's stars:

| Part | rho |
|---|---|
| burst | +0.90 |
| notes per second | +0.90 |
| median swing gap | -0.85 |
| crossed | +0.80 |
| cross | +0.74 |
| reaction time | -0.68 |
| flow percent | +0.19 |
| turn | +0.04 |

| Model | R² (cross-validated) |
|---|---|
| Old inputs: 1/reaction time, 1/median gap, flow | 0.66 |
| + burst | 0.83 |
| burst, cross, crossed, turn (the game's) | 0.89 |

Reaction time adds nothing once the burst is known (its weight fell to about 0, slightly negative), so it no longer
sets the level; it still shows as "get ready" time.

The game's formula (`MapStats.stars`), stars per one standard deviation of each part in brackets:

stars = 2.225 + 0.593 x burst x speed (0.97) + 0.062 x cross (0.34) + 0.077 x crossed (0.19) + 0.022 x turn (0.21)

So after how fast the hardest stretches swing, crossing the body is the next biggest part, as the owner felt. The Speed
modifier scales the burst only; at 1.2x this adds about what BeatLeader's own Faster rating adds (Gurenge Hard: 5.51
to 5.98 here, 5.90 on BeatLeader).

## Levels

Cut-offs are the midpoints between the median stars of neighbouring mapper labels (Easy 3.69, Normal 4.19, Hard 4.99,
Expert 5.99, Expert+ 7.28): **Easy under 3.94, Normal under 4.59, Hard under 5.49, Expert under 6.64, Expert+ from
6.64** (`Constants.STAR_LEVEL_TOPS`; owner agreed 2026-11-10).

Against the level of BeatLeader's own stars on these cut-offs:

| Levels from | Same level | Shown harder | Shown easier |
|---|---|---|---|
| Old formula | 53 % | 39 % | 8 % |
| Mapper's label | 63 % | 21 % | 17 % |
| New formula (cross-validated) | 73 % | 16 % | 11 % |

The old formula mostly showed maps harder than they play: a short reaction time or a Tangled bump sent many to
Expert+.

## Get songs

Before download the notes aren't there, so Get songs asks BeatLeader for the map's stars
(`api.beatleader.xyz/leaderboards/hash/<hash>`, about 10 KB, one map at a time, the rows in view first) and puts them
on the same cut-offs, reading between BeatLeader's 0.85x, 1x, 1.2x and 1.5x ratings for the Speed modifier. While
they are on their way the strip says "Loading…"; only when BeatLeader can't give them (no answer in 10 s, an error, or
no stars for the map) it shows the old estimate with "≈" (owner, 2026-11-11). The owner's example: LiSA's Gurenge (BeatSaver
5270) Hard showed ≈Hard and plays at Expert (5.51 stars); its Expert showed ≈Expert and plays at Expert+ (7.31).

## Limits

- BeatLeader's stars include accuracy, so they rate how hard a map is to play well, not only to pass; its Pass rating
  ranks the same way (the game's parts fit it at R² 0.88).
- The sample is popular maps, so Easy and Normal are fewer (258 of 1,094).
- The level of a map in the song menu (fitted) and on Get songs (BeatLeader's own stars) can differ by a level for
  about a quarter of maps; the cut-offs are the same.
- Not yet confirmed by headset playtests.

## Sources

- BeatLeader API and ratings: https://api.beatleader.xyz, https://beatleader.xyz (Pass/Acc/Tech star rating)
- BeatSaver API and map downloads: https://api.beatsaver.com
- Fitts, P. M. (1954). The information capacity of the human motor system in controlling the amplitude of movement.
  Journal of Experimental Psychology 47(6), 381-391: reaching farther takes longer, why reaching across the body
  makes a swing harder.
