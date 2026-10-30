# Note spawn animation: ours vs Beat Saber (plan)

Owner, 2026-10-28: compare how a note appears and settles with Beat Saber. This changes how notes read and react,
so it is researched first (root `AGENTS.md`, "Research before changing game feel"). Plan only; nothing built.
Images are in `note-spawn-plan/`.

## 1. Ours today

The "Spawn" animation in `game/notes/BeepCube/BeepCube.tscn` comes from Open Saber / Beep Saber. It animates the
note's mesh (`BeepCubeMesh`); the collision stays on the note's own place. It is played by `BeepCube.spawn` at
`speed_scale = NJS / 9` (`BeepCube.gd:121-124`), so it runs 0.8 s at NJS 9 and 0.4 s at NJS 18.

| Anim time (s) | 0 | 0.3 | 0.6 | 0.8 |
|---|---|---|---|---|
| Position | 2 m behind its place | at its place | 0.5 m up | at its place |
| Rotation | 180° from its cut direction | 180° | turning | its cut direction |
| Scale | 0.1 | 0.1 | growing | 1 |

- The note appears at the half jump distance: `Map.half_jump_beats`, 4 beats, halved while that would be over 18 m.
  It moves at NJS.
- For TheFatRat Timelapse (Easy, 127 BPM, NJS 9) that is 17 m and 1.89 s ahead.
- `ours_spawn_strip.jpg` (stage_capture, 15.16-16.9 s, a note cut at 17.01 s) shows:
  - the notes are specks for the first 0.3 s;
  - they turn sideways and grow while they bob;
  - they reach full size facing their cut direction only about 0.8 s after appearing.

## 2. Beat Saber

**From the open replica.** ArcViewer is a web viewer that copies Beat Saber's note motion for replays. Its source
(github.com/AllPoland/ArcViewer, `JumpManager.cs`, `NoteManager.cs`, `ObjectManager.cs`, values from
`Previewer.unity`) shows:

- **Fly-in.** Before its jump the note rushes in from `moveZ` 300 m beyond the jump start in `moveTime` 0.975 s.
  That's about 300 m/s, so it is effectively there at once, and it happens before the reaction time starts.
- **Jump.** From the jump start (half jump distance = NJS × reaction time) to the player it moves at NJS.
- **Arc.** Its height follows a parabola, `y = target - (target - startY) × (d / HJD)²` (`SpawnParabola`).
  - It leaves from a low start row (`StartYSpacing` 0.6 m per note stacked under it on the same beat) and rises to
    its own row.
  - It arrives at its row exactly at the cut plane: a falling-ball arc, fast at first and level at the end.
- **Rotation.** It turns from 0° to its cut direction over the first `rotationAnimationTime` 0.3 of the jump, eased
  sine-out (`Easings.Sine.Out`).
- **Facing.** Over the jump it also leans to face the player's head (`LookAtPlayer`, 80% vertically, by jump
  progress).
- **Crossing notes.** These swing in from the other side in the jump's first half (the flip animation).
- **Scale.** None: the note is full size from the start.

**From the recording.** The PC version, 2026-10-28, `bs_spawn_strip.jpg`: 12 frames a second from 126.9 s, a note
cut at 128.7 s.
- The note first shows at about 127.65 s, about 1.05 s before its cut. It is already full size for its distance, with
  no visible fly-in or scale-up (the fly-in is under one 24 fps frame).
- Its arrow is already pointing its way by the time it is big enough to read.
- It rises slightly as it comes, from low to its row, ending level.
- The stream's compression hides the first frames' detail; the timings are ±1 frame (42 ms).

**From BSMG and community tools** (JDFixer; bsmap's `NoteJumpSpeed`; ChroMapper's difficulty settings):
- Reaction time = half jump distance / NJS.
- Players tune their jump distance and reaction time, and expect the whole reaction time to be readable.

## 3. Side by side

| | Ours | Beat Saber |
|---|---|---|
| First seen | At 17 m, 1.89 s ahead (this map), as a 10% speck | At the jump start, full size |
| Fly-in | 2 m in 0.3 s (anim time) inside the reaction time | 300 m in about 1 s **before** the reaction time |
| Height | +0.5 m bob and back, mid-way | One rising arc from a low start row to its own row, level at the cut plane |
| Rotation | Starts 180° off, turns 0.3-0.8 s (anim time) | 0° to its direction in the first 30% of the jump, sine-out |
| Scale | 0.1 → 1 over 0.3-0.8 s | None |
| Faces the player | No | Leans toward the head over the jump |
| Speed rule | Anim × NJS/9 | All by jump progress (a share of the reaction time) |

**What this means for reading.**
- Ours spends up to 0.8 s of anim time with the note small, sideways or moving up and down. At NJS 9 that is the
  first 40% of a 1.89 s reaction time.
- At high NJS the anim speeds up only by NJS/9, while the reaction time can drop to 0.5-0.7 s. At NJS 18 with a
  0.6 s reaction time, the arrow settles at 0.44 s: only 0.16 s before the hit.
- Beat Saber's is tied to the reaction time, so the arrow is final by 30% of it, however fast the map.
- The note's real position and collision are the same in both; only the look differs. GPU cost: none (one
  transform per note either way).

## 4. Options

### A. Keep ours

No work. Notes keep their Beep Saber character (small, spinning in, bobbing), with the reading cost above. It is
worst on fast maps.

### B. Tune ours toward Beat Saber (S, recommended first step)

- Drive the animation by **jump progress**, a share of the note's own reaction time, not NJS/9. A fast map can then
  never squeeze the arrow's settling into the last moment.
- Full size from the start (drop the 0.1 scale).
- No bob.
- Rotation from 0° (its default "down") to its direction over the first 30% of the jump, sine-out.
- Keep a short fly-in of the last 2 m from behind, as the "arrival", but do it **before** the reaction time starts,
  as Beat Saber does: spawn a little earlier and rush in.
- Work: `BeepCube.spawn` (a tween or `_process` by jump progress in place of the AnimationPlayer), same for chain
  heads. Test in `test_spawn` that a note at the hit plane is at its row, size and direction.

### C. Beat Saber-like jump (M)

Everything in B, plus:
- the rising arc from a low start row (notes stacked on one beat start 0.6 m apart), level at the cut plane;
- the lean toward the player's head over the jump;
- the crossing notes' flip from the other side.

Work: the start-row rule (ArcViewer's `GetStartY`), the parabola on the mesh's y, `LookAtPlayer` from the real eye,
and the flip. Same for bombs (they also jump in Beat Saber), and arcs and chains attached to heads must follow the
mesh. Check on the headset with dense maps that the arc doesn't confuse which row a note is in.

## 5. Recommendation

**B now, C after a headset look.** B fixes the reading problem: full-size notes whose arrows settle early, at any
NJS. It's small and keeps the collision path untouched. C adds Beat Saber's feel (the rise and the lean), which is
easier to judge once B is in.

## 6. Questions for the owner

1. B (tuned toward Beat Saber) first, or straight to C (the full Beat Saber jump)?
2. Keep any of our Beep Saber character: the 180° spin-in, the bob, the grow-in? Or go fully Beat Saber?
3. Should notes lean to face your head as they come (Beat Saber does)?
4. The rising arc from a low row (C): want it? It's Beat Saber's look but moves notes vertically while you read them.
5. Bombs too, or notes only?

Sources: ArcViewer source, https://github.com/AllPoland/ArcViewer (`Assets/__Scripts/Previewer/MapControl/`);
bsmap `NoteJumpSpeed` (half jump duration / jump distance), https://jsr.io/@kvl/bsmap/doc/~/NoteJumpSpeed;
ChroMapper difficulty settings, https://chromapper.atlassian.net/wiki/spaces/UG/pages/1048655/Difficulty+settings;
the Beat Saber PC recording (2026-10-28, `recordings/`, not in git).

## 7. Decision (owner, 2026-10-28)

- Built: option C, fully Beat Saber (b75b343). No 180° spin-in, no bob, no grow-in. Full size from the start, the turn
  to the cut direction in the first 30% of the jump (sine-out), driven by jump progress. A lean to face the head on
  90/360 maps only: in the recording's second song (Standard), near notes show their sides as plain perspective
  does, so Standard gets none.
- Then **no rise** (owner's pick "ข"). With the start-row arc (ArcViewer's numbers: 0.6 m under the bottom row, 0.6 m
  up per stacked note) the owner saw notes rise from the floor, while Beat Saber's notes look as if they fall from
  above.
  - Measured frame by frame (`fall_check_bs_vs_ours.jpg`, top: Beat Saber 127.55-128.3 s; bottom: ours with the
    rise), a Beat Saber note's offset below the horizon grows in step with its size over its last 1.1 s. That means
    its height stays nearly level.
  - The "fall" is perspective: anything below eye level slides down the screen as it comes closer.
  - Our rise worked against that, so ours read as coming up from the floor.
  - Notes, bombs, chains and arcs now stay at their row's height for the whole jump. The start rows
    (`Map.set_start_rows`) and the arc's matching lift are gone.
