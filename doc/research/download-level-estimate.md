# Download page: level before download against the measured level

The Download page shows each BeatSaver difficulty's level (Easy..Expert+) before the map is downloaded
(`BeatSaverSongInfo.level_of`); after download the song menu measures it from the map file (`MapStats.level_of`).
The owner found the two often disagree (2026-10-27).

Sample: the Mac's 18 downloaded songs, 49 Standard difficulties, each matched to its BeatSaver entry by hash
(`api.beatsaver.com/maps/hash/<hash>`), at Speed 100%.

| Estimate | Same level | Shown harder | Shown easier | Within one level |
|---|---|---|---|---|
| Before (reaction, notes per second x 0.84, +1 when BeatSaver's parity count is Tangled) | 32 (65%) | 5 | 12 | 46 |
| After (no parity step) | 36 (73%) | 1 | 12 | 45 |

- The swing pace factor (median same-hand swing gap over 2 / notes per second) measured 0.82 here (quartiles
  0.72-0.91); refitting it doesn't help: every value from 0.60 to 1.00 matched 28-36, 0.84 the most.
- BeatSaver's parity count (errors + warnings + resets) disagreed with the measured swing flow: it called 4 of
  the 17 misses Tangled that measured smooth (yoru ni kakeru Easy/Normal/Hard, Beauty And A Beat Normal), and
  missed others. Dropping it gained four.
- The 12 left read easier than they play: their swings come in dense bursts that the song's average notes per
  second hides (Bling-Bang-Bang-Born Hard: 3.2 notes a second, but a 0.38 s median swing gap). BeatSaver gives no
  per-section density, so the page marks a level not yet downloaded as an estimate ("≈").
- The headset's 53 songs weren't reachable for this run; the sample is small.
