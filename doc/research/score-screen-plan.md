# Score screen: failed and cleared at a glance (plan)

Owner, 2026-10-28: Beat Saber's results make failed and cleared unmistakable, and the colour carries the feeling.
Plan only; nothing here is built yet. Images are in `score-screen-plan/`. Source: a recording of Beat Saber's PC
version on the Pico 4 (`recordings/ScreenRecording_2026.10.28-11.46.33.mp4`; not in git). Run 1 failed at about
160 s, run 2 cleared at about 295 s. Timestamps below are video seconds.

## 1. How Beat Saber tells failed from cleared

| | Failed | Cleared |
|---|---|---|
| The moment | Energy hits 0 (at a wall, 158.5 s). Within about 0.3 s, **"LEVEL FAILED"** appears in the play space where the notes were: big neon italic capitals in red, a white-hot core and a red glow, mirrored in the floor (`bs_fail_2_text.jpg`, 160.3 s). The HUD stays faintly behind it. | The last note goes. No word in the play space. |
| Scene light | The stage sinks to near black around the red word (160.3-161.2 s), then fades to full black (`bs_fail_4_fade.jpg`, about 162 s). | Fades to black about 0.5 s after the end (`bs_clear_2_end.jpg`, 295.6 s). |
| Results room | The menu room is washed in **strong red**: sky, floor and haze (`bs_fail_6_results_later.jpg`, 163-167 s). The red then fades back to the normal blue house light over about 4 s. | The normal **cool blue** menu room. Then **fireworks**: cyan sparks bursting over the logo (`bs_clear_4_results_settled.jpg`, about 299 s). |
| Panel headline | A **red banner, "LEVEL FAILED"**, full width under the song's name. | An **orange banner, "LEVEL CLEARED"** (warm, not a note colour) (`bs_clear_3_results.jpg`). |
| Stats | Song and difficulty only. | Good cuts "92 / 94" with max combo, score "56 689" big in blue with "NEW HIGHSCORE" under it, rank "A". |
| Buttons | Restart (secondary) and Continue (primary, blue). | The same two. |
| Sound | The song is low-passed shut in about 0.2 s, about 0.45 s of bass only, then the menu music (`recordings/audio/fail.wav`). | About 0.5 s of silence, then the menu music. |
| Total | About 3.5 s from the fail to the results. | About 1 s. |

So Beat Saber says it four times on a fail: the word in the world, the red room, the red banner, and the absent
stats. On a clear it says it with the warm banner, the stats and the fireworks. The colour does most of the work
before the player reads anything.

## 2. Ours today

`ours_cleared.png` and `ours_failed.png` (`tools/capture/endscore_capture.tscn`, `--percent 0.87` and
`--percent -1`) show the same panel. A player tells them apart only by:
- the rank letter: S in its rank colour against an F in muted rose;
- the ring: counting up to 87% against an empty "0%";
- which button is primary: Main Menu after a clear, Retry after a fail (`game/ui/EndScore.gd:161`).

There is no headline word, and the stage behind is the menu's dim house light either way. During play a fail
shows the "Failed" label while the song low-passes shut (`game/BeepSaber_Game.gd`, `_fail_song`). A clear plays
`clear.wav`. "0%" after a fail reads like a bug, and the score and record still show as if counted.

## 3. Options

Each option builds on the one before. Mockups are composites (a Classic stage render, graded per mood, behind our
real panel with the banner drawn in the grade font), not game renders.

### A. A headline banner (smallest)

`A_cleared.jpg`, `A_failed.jpg`

- A full-width banner under the song's name: "SONG CLEARED" in `UI_TEXT`, or "FAILED" in `MISS_COLOR`, on a
  `UI_SURFACE` bar, in the grade font (Kanit Black Italic, the HUD grade's).
- After a fail: hide the empty ring and its "0%", and show "Failed at 1:42 of 3:10" in their place.
- Rules: all kept. `MISS_COLOR` is for mistakes, and the word carries the meaning without hue.
- Work: S. `EndScore.tscn` gets a banner TextMesh plus the fail branch in `show_score`. Check it with
  `endscore_capture`.
- Feeling: clear to read, but the room feels the same both ways.

### B. The room's light tells it too (recommended, Beat Saber-like)

`B_bs_failed.jpg`, `B_bs_cleared.jpg` (Beat Saber-like, needs the exception below). `B_rules_failed.jpg`,
`B_rules_cleared.jpg` (within today's rules).

A, plus the stage light changes for the results moment.

**Fail, Beat Saber-like.** On the results, the stage takes a dim red wash: the haze and the house light lean to
the danger colour.
- It fades in over 1.0 s, never cuts or flashes, and peaks at moderate brightness.
- It holds about 3 s, then eases back to the house light over 3 s, as Beat Saber does.
- The banner is a red bar with white "FAILED". Red always comes with the word.

**Clear, Beat Saber-like.**
- The banner takes the achieved rank's colour, e.g. gold for S, with dark text.
- The house light warms a little.
- A short spark burst over the stage: `CPUParticles3D` in the note colours and white. One burst, under 1 s, no
  strobing.

**Within today's rules (if the exception isn't wanted).**
- Fail: the stage lights die to near black and grey, a cold neutral house light, red only on the word.
- Clear: the stage lights come up in the note colours with the sparks; the banner keeps neutral or uses
  `UI_ACCENT`.

**Rules touched by the Beat Saber-like version:**
- Colour rules: "Danger colour ... never use it for decoration or menus" (red wash and red banner); "the
  environment stays dark ... takes its light colours from the note colours" (red house light); "RANK_COLORS only
  colour the rank letter" (gold banner); "no large areas of saturated ... colour" (the wash).
- Light rules 4 (limited palette) and 8 (no large saturated red flashes): kept by fading, never flashing.

**Comfort:**
- WCAG 2.3.1 is kept: no flash at all; the wash is one fade-in (1 s) and one fade-out (3 s).
- No sudden full-field red: the wash adds at most about 35% red over a stage that is already dark (mockup values),
  so the brightest red stays far below a full-field red flash.
- The words keep 4.5:1 contrast on their bars.

**Work: M.**
- The banner and fail branch as in A.
- `EventDriver` gets a `result_mood(failed: bool)`: a tween of the house colour and haze weight toward
  `DANGER_COLOR` or a warm tint, using the existing house-light and haze code, and back.
- A sparks node for the clear.
- `GameState` MapComplete/NewHighscore calls it.
- Headset check of the brightness.

### C. The fail moment in the play space too (biggest)

`C_fail_moment_bs.jpg` (with the exception), `C_fail_moment_rules.jpg` (within the rules).

B, plus the moment of failing done like Beat Saber.
- Our small "Failed" label becomes a big "FAILED" in the grade font where the notes were: white-hot core, glow in
  the danger colour, mirrored in the deck by the floor reflection.
- At the same time the stage lights die and, with the exception, the red starts to fade in.
- Then a 0.5 s fade to black, and the results come up in the red room (B).
- The low-pass (already built) carries the sound.
- On a clear: a 0.5 s fade to black and the results, so both endings have a clear beat between play and score.
- Work: M-L. The label becomes a 3D TextMesh with a glow layer (the HUD's grade glow is the pattern), plus a fade
  overlay that is a quad in front of the eye (no post-processing), and the GameState timing.
- Comfort: as in B; the fade to black is a darkening, not a flash.

## 4. Recommendation

**B, Beat Saber-like, then C's fail moment once B has been seen on the headset.** B gives the feeling the owner
asked for (the red room, the warm clear) at size M, using the light and haze code that's already there. C adds the
in-world word, which is Beat Saber's strongest single signal, but needs the fade overlay and new timing; better
judged after seeing B. A alone fixes reading but not the feeling.

Exception text to add to the root `AGENTS.md` "Colour rules" (and pointed to from "Light"), if B is picked:

> - The result moment is the one exception (owner, 2026-10-28): from a song's fail or clear until the score screen
>   closes, the stage may take the result's mood like Beat Saber. On a fail, a dim wash of the danger colour over
>   the house light and haze, with the red banner "FAILED". On a clear, a warm house light, the banner in the
>   achieved rank's colour and one short spark burst. The red never flashes: it fades in over at least 1 s, peaks
>   at moderate brightness and fades back to the house light. It always pairs with the word, so it never relies on
>   hue (WCAG 2.3.1; never a sudden full-field red). Everywhere else the rules above stand.

## 5. Questions for the owner

1. B (Beat Saber-like) as recommended, or B within today's rules, or A only for now?
2. Clear banner colour: the achieved rank's colour (gold for S, blue for A, ...), or one fixed warm colour like
   Beat Saber's orange?
3. After a fail, show how far the player got ("Failed at 1:42 of 3:10") in place of the empty ring?
4. How long should the red room last: Beat Saber's about 4 s then back to normal, or for as long as the score
   screen is open?
5. Want C's in-world "FAILED" word in the same change, or after seeing B on the headset?
