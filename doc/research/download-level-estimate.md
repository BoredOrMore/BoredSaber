# Download page: level before download against the measured level

The Download page shows each BeatSaver difficulty's level (Easy..Expert+) before the map is downloaded
(`BeatSaverSongInfo.level_of`); after download the song menu measures it from the map file (`MapStats.level_of`).
The owner found the two often disagree (2026-10-27).

Sample: the headset's 53 songs and the Mac's 18 downloaded songs, 195 Standard difficulties, each matched to its
BeatSaver entry by hash (`api.beatsaver.com/maps/hash/<hash>`), at Speed 100%. The measured level was counted from
the map files (`MapStats._count`, the same as the song menu).

| Estimate | Same level | Shown harder | Shown easier | Within one level |
|---|---|---|---|---|
| Before: reaction, notes per second x 0.84, +1 when BeatSaver's parity count is Tangled | 131 (67%) | 22 | 42 | 188 (96%) |
| No parity step, x 0.84 | 140 (72%) | 11 | 44 | 186 (95%) |
| No parity step, x 0.82 (now) | 142 (73%) | 14 | 39 | 186 (95%) |

By sample: the headset's 146 went 68% to 73% (0.82); the Mac's 49 went 65% to 73%.

- The swing pace factor (median same-hand swing gap over 2 / notes per second) measured 0.82 on the Mac's sample
  (quartiles 0.72-0.91); 0.78-0.84 all land within 4 points of each other, 0.82 the most.
- BeatSaver's parity count (errors + warnings + resets) disagreed with the measured swing flow: it called maps
  Tangled that measured smooth (yoru ni kakeru Easy/Normal/Hard, Beauty And A Beat Normal), and missed others.
- Most misses read easier than they play: their swings come in dense bursts that the song's average notes per
  second hides (Bling-Bang-Bang-Born Hard: 3.2 notes a second, but a 0.38 s median swing gap). BeatSaver gives no
  per-section density, so the page marks a level not yet downloaded as an estimate ("≈"); a map in the library shows
  its measured levels.
