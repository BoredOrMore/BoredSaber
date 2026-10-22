# Scoring and reach: why cuts score low

Measured 2026-10-21/22 after the player said scoring feels bad. Logs from `cut_parts` lines (LightSaber.gd) on
the headset, 785 cuts over 9 songs (Easy to Expert+).

## What the logs show

- Per note the player gets 64% of the best score on average; 17% of cuts reach 80%, almost none 100%.
- Approach (pre-swing): median 64°, only 10% reach the 100° full mark. Follow-through: median 49°, 30% reach 60°.
  A cut sweeps about 110° in all, where full marks need 160°.
- Measuring over the whole swing instead of fixed 0.2 s windows gives the same angles (median 67° against 65°),
  so the window is not the cause.
- Centre points stopped 10 cm from the centre of a 37.5 cm block: 54% of clean hits got none. Fixed in d949d9b
  (full within 2 cm, none at the edge): average 4.6 → 8.2 of 20, zero share 54% → 25%.

## Beat Saber, for comparison

| | Beat Saber | BoredSaber |
|---|---|---|
| Points per cut | 70 approach + 30 follow-through + 15 centre = 115 | 90 + 40 + 20 = 150 |
| Shares | 61% / 26% / 13% | 60% / 27% / 13% (same) |
| Full approach / follow-through | 100° / 60° | 100° / 60° (same) |
| Grades | SS 90, S 80, A 65, B 50, C 35, D 20 % | same |
| Lane spacing | 0.6 m, lanes at x = -0.9 … 0.9 | same |
| Row heights (1.8 m player) | 0.85, 1.40, 1.90 m (steps 0.55, 0.50) | 0.80, 1.40, 2.00 m (steps 0.6) |
| Taller or shorter player | grid moves by half the height difference, clamped to -0.2 … +0.6 m | the view moves by the full difference ("Measure my height") |
| Where notes are cut | a cut plane about 0.65 m in front of the head | the perfect beat is 1.0 m in front of the player's origin |

The score ratio and targets match Beat Saber, so they are not harder than Beat Saber's. What differs is where
the notes come: about 35 cm further away and a slightly taller grid. Notes further out are reached with the arm
held forward, which turns a swing into a shorter push from the shoulder; the logged angles (110° per cut) fit
that.

## Sources

- Points, targets, grades: BSMG Ranking & Scoring Guide, https://bsmg.wiki/ranking-guide.html; AccSaber wiki,
  https://wiki.accsaber.com/Beat_Saber/How_to_improve/basics/
- Grid geometry: ArcViewer (open-source Beat Saber map and replay viewer that recreates the game's layout),
  `Assets/__Scripts/Previewer/MapControl/Objects/ObjectManager.cs` in https://github.com/AllPoland/ArcViewer:
  `LaneWidth = 0.6`, `VanillaRowHeights = {0, 0.55, 1.05}` (game-accurate, used for replays),
  `DefaultPlayerHeight = 1.8`, `playerHeightOffset = clamp((height - 1.8) / 2, -0.2, 0.6)`,
  `PlayerCutPlaneDistance = 0.65`. The 0.85 m bottom row is the commonly cited value; ArcViewer gives the offsets
  between rows. Not from Beat Games directly: confirm on the headset.
