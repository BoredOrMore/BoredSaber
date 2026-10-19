# Swing flow: research for the Smooth / Twisty / Tangled labels

Measured 2026-10-19 from BeatSaver map data, after headset play found maps labelled easy that were
confusing to swing (see "Research before changing game feel" in the root `AGENTS.md`).

## Definition

Sabers flow like a pendulum: after a down swing the natural next swing of that hand is up, and so on
(the "parity" or "flow" rule of the BSMG mapping guides). Per hand, notes closer than 50 ms are one
swing (its first arrow sets the direction; a dot is cut along the natural follow-through). For each
swing within 1 s of the same hand's previous swing, compare its direction with the reverse of the
previous one:

- turned about 90 degrees (e.g. down then left): **awkward turn**, weight 1;
- turned further (e.g. down then down again): **reset**, the hand must swing back empty, weight 2.

A swing that reaches the far column on the other hand's side (left hand in column 3, right hand in
column 0) is a **crossover**, weight 1. The **flow percent** is the weighted count over all swings.
Implemented in `MapStats._awkward_percent`.

## Results

464 Standard difficulties from popular and ranked BeatSaver maps:

- median 1.6 %, 75 % of difficulties at 5 % or less, the worst 10 % above 13 %;
- easy difficulties are the least careful: 12 % of Easy and 24 % of Normal difficulties are at 10 % or
  more, against 9 % of Expert;
- difficulties above 4 % have a higher BeatLeader Tech rating (median 3.5 against 2.5). BeatLeader's
  ratings mostly follow note density, so the flow percent is the more direct measure of confusing swings.

On the headset's 30 songs, Love Yourself Expert (29 %) and Beauty And A Beat Hard (17 %) stood out;
the player confirmed both feel confusing to swing.

## Bands

| Label | Flow percent | Share of sample |
|---|---|---|
| Smooth | under 4 % | about 70 % |
| Twisty | 4–10 % | |
| Tangled | 10 % and up | about 13 % |

Tangled difficulties count one overall level harder; only those at 25 % or more (the worst 5 % of the
sample, hardly playable) are left out of the song list. The easiest overall level (Gentle) also needs a
Smooth difficulty. The 1 s window and the band edges are a data-based starting point; confirm with
headset playtests.

## Sources

- BeatSaver API and map downloads: https://api.beatsaver.com
- BSMG wiki, mapping basics (parity, flow, resets): https://bsmg.wiki/mapping/basic-mapping.html
- BeatLeader star rating with separate Pass, Acc and Tech ratings: https://beatleader.xyz
