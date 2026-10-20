# Wall workout: research for the Workout labels and filter

Measured 2026-10-20 after the player asked whether walls that make you lean left and right or squat can
be found, as long as they come in sequences that work as exercise (see "Research before changing game
feel" in the root `AGENTS.md`).

## Definition

A wall moves the player only when it covers the head, in the middle of the grid between columns 1 and 2:

- **squat**: the wall's bottom is at layer 1.5 or higher and it spans both middle columns;
- **side step**: the wall reaches from the floor to head height and covers one middle column, so the
  player steps or leans to the other side.

Walls of one move that touch (closer than 0.25 s) are one move. A **set** is at least 8 moves of one kind
(squats, or side steps to either side), each within 4 s of the last: resistance training guidance gives
8-12 repetitions per set (ACSM), and a gap over 4 s breaks the rhythm. Implemented in
`MapStats._workout`; `wall_research.py` uses the same rules.

## Results

| Sample | Difficulties with a set | Song time in sets |
|---|---|---|
| Popular and ranked BeatSaver maps (464 difficulties) | 9 % | almost none |
| Maps tagged "fitness" on BeatSaver (72) | 58 % | median 18 %, top quarter 72 % or more |
| The headset's songs | JUMP Hard (2 sets, 14 %), Let It Go (1 set) | no squat sets |

Squat walls are rare outside fitness maps (93 % of the popular sample has none; ranking criteria
discourage them). Energy cost: VR rhythm play with squats and lunges measured 8.2 METs against 7.6 for
mostly punching (Craig et al. 2024, funded by the game's maker); Beat Saber averaged 6.24 METs (VR
Institute of Health and Exercise).

## Labels

| Label | Rule |
|---|---|
| (none) | no set |
| Some workout | at least one set |
| Workout | 30 % or more of the song in sets |

The song list's Workout button lists songs with a difficulty that has a set. The 30 % edge sits between
the fitness median and its top quarter; confirm with headset playtests.

## Sources

- BeatSaver API and map downloads: https://api.beatsaver.com
- Craig, Rhodes, Sui (2024). Energy expenditure of two modes of a VR fitness game, JMIR Serious Games 12:e53999: https://games.jmir.org/2024//e53999
- VR Institute of Health and Exercise on Beat Saber: https://roadtovr.com/playing-beat-saber-burn-number-calories-tennis/
