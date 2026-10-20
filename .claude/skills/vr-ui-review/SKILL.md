---
name: vr-ui-review
description: Check a BoredSaber UI change before calling it done - walk every game state that shows the changed nodes, check placement, overlap and depth in 3D, wording, feedback and dead ends, then verify on the Pico 4. Use after any change to menus, panels, HUD, score screen, keyboard or the BeatSaver page, and when the user reports a UI problem.
---

# VR UI review for BoredSaber

Run this after `vr-ui-design` work, or to diagnose a reported UI problem. Report findings as
"problem → cause (file:line) → fix", worst first.

## 1. List what changed and where it shows

1. List every node the change touches (canvas, `MeshInstance3D`, button, keyboard).
2. For each, find every game state that shows it:
   `grep -n "<node_ref>\._show\|<node_ref>\._hide\|<node_ref>\.visible" game/scripts/GameState/*.gd game/*.gd`.
   States: MapSelection (song menu), Settings, Playing, Paused, MapComplete, NewHighscore.
3. Note shared nodes (one keyboard for search and names, one highscore table for menu and score
   screen). A shared node must be right in every state, not only the one you changed.

## 2. Walk the flow as the player

For each state the change appears in, write the steps: arrive → read → press → result → leave.
Check:

- [ ] The new or changed thing is where the player is already looking.
- [ ] One obvious main action, in `UI_ACCENT`; the default lets the player just continue.
- [ ] Every modal can be cancelled; empty or invalid input can't trap the player.
- [ ] Controls that would abandon a modal are disabled while it is open.
- [ ] After each press there is visible (and audible) feedback, and slow work shows progress.
- [ ] Typed text, selections and saved results are visible where the player looks.
- [ ] Wording follows the root `AGENTS.md` (no NJS/NPS/RT/JSON; one term per concept; short).
- [ ] No hidden modes, no duplicate filters, current state shown plainly.

## 3. Check placement in 3D (numbers, not guesses)

For each visible piece in each state, compute its world centre and size:

- World position = parent transform applied to the child offset, through every parent
  (`Transform3D(...)` in `.tscn` is row-major basis then origin; columns are the local axes).
- Canvas size in metres = control size px / 1024 × node scale.
- Angle from straight ahead for a player at the origin, eyes ~1.6 m, facing -z:
  yaw = atan2(x, -z), pitch = atan2(y - 1.6, -z).

Flag:

- [ ] Reading/pressing area outside ~±30° yaw, +20° / -12° pitch (lower is fine only for short,
      tilted tasks like the keyboard).
- [ ] Distance under 0.5 m or over 2.5 m for something the player must read.
- [ ] Two pieces overlapping in view whose depths differ by less than ~5 cm, or the one to read is
      behind (the hidden name text box: keyboard text at z -0.83 behind the score panel at z -0.78).
- [ ] A side panel not facing the player.
- [ ] Targets under ~3° (≈ 5.2 cm at 1 m), text smaller in angle than the main menu's 28 px at
      scale 2.4 and 1 m.
- [ ] Hit areas that don't match the drawn shape.
- [ ] Anything inside the note lane during play.

A short Python or GDScript snippet that prints these numbers from the `.tscn` transforms is fine;
keep it in the scratchpad, not the repo.

## 4. Check on the headset

Follow `.github/AGENTS.md` to install the build. Then:

1. Mirror the left eye from a Mac:
   `scrcpy -s <device> --crop=2160:2160:0:0 --max-size=1080 --no-audio`
   (close it again before measuring performance).
2. Go through the flow from step 2 in every affected state, including cancel and error paths.
3. `adb logcat -d | grep -E 'E godot +: (ERROR|SCRIPT)'` after the walk: no new errors (index out of
   bounds on lists, missing nodes).
4. If the UI is visible during a song, compare `PxrMetric` frame GPU time with the previous build.
5. Ask the user to try the flow and say what to look for; the change isn't done until they've
   played it ("Changes to feel need a playtest" in the root `AGENTS.md`).

## 5. Report

- Problems found, each with cause and fix, worst first.
- What you checked and how (numbers for placement, states walked, headset or not).
- Anything you couldn't verify, said plainly.
