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
- [ ] Test every state, not only the happy path: nothing selected, empty list, every filter on, no
      network (request fails), slow network, cancel at each step, error on load, first launch with
      default settings, mixed reality on, left-handed. Each one shows a message and a way on.
- [ ] Destructive actions name what is lost and confirm (or can be undone); filters show what is on,
      how many results remain and how to clear them.
- [ ] Mixed reality on: nothing opaque covers the room beyond what play needs.

## 3. Check placement in 3D (numbers, not guesses)

For each visible piece in each state, compute its world centre and size:

- World position = parent transform applied to the child offset, through every parent
  (`Transform3D(...)` in `.tscn` is row-major basis then origin; columns are the local axes).
- Canvas size in metres = control size px / 1024 × node scale.
- Angle from straight ahead for the player at `XROrigin3D` (0, 0, 1), eyes (0, 1.6, 1), facing -z:
  with dx = x, dy = y - 1.6, dz = z - 1: yaw = atan2(dx, -dz), pitch = atan2(dy, hypot(dx, dz)).

Flag:

- [ ] Reading/pressing area outside ~±30° yaw, +20° / -12° pitch (lower is fine only for short,
      tilted tasks like the keyboard).
- [ ] Distance under 0.5 m or over 2.5 m for something the player must read; pointer targets
      closer than 0.8 m or further than 3 m [Meta hands UI].
- [ ] Two pieces overlapping in view whose depths differ by less than ~5 cm, or the one to read is
      behind (the hidden name text box: keyboard text at z -0.83 behind the score panel at z -0.78).
- [ ] A side panel not facing the player.
- [ ] Targets under ~3° (≈ 5.2 cm at 1 m), text smaller in angle than the main menu's 28 px at
      scale 2.4 and 2 m (≈ 1.9°).
- [ ] Hit areas that don't match the drawn shape; interactive elements overlapping or touching.
- [ ] Text floating above its background; many depth levels to refocus between.
- [ ] Sustained pulsing (worst near 0.2 Hz) or busy motion at the edges of view.
- [ ] A pointer target without hover, press and sound feedback.
- [ ] Anything inside the note lane during play.

A short Python or GDScript snippet that prints these numbers from the `.tscn` transforms is fine;
keep it in the scratchpad, not the repo.

## 4. Check the 2D panel before the headset

The cloud sessions have no headset and can't reach beatsaver.com, so render the panel itself:

1. Write a scratch scene that instances the panel `.tscn`, fills it with fake data (copy the shape of
   a real response or map folder) and saves `get_viewport().get_texture().get_image()` to a PNG.
   Run it with the Linux Godot under Xvfb:
   `DISPLAY=:99 timeout 100 <godot> --path . --rendering-driver opengl3 --resolution 1280x720 res://<scene>.tscn`.
   Keep the scene out of the commit unless the user asks for it.
   Use the worst real content, not the bundled sample song: pull the busiest maps from the headset
   (`adb pull /sdcard/Android/data/<package>/files/Songs/<folder>` into the desktop `user://` Songs folder), the
   ones with the most characteristics and difficulties and the longest names.
2. Render every state the panel has, not only the happy one: empty, loading, error, long content
   (the longest title, mapper and tag list you can find), a selected item, progress at 0 % and 100 %,
   already-downloaded or saved.
3. Look at each PNG and flag: text clipped or wrapped by the engine, labels touching edges or each
   other, two lines of a list item fighting for one row, a dropdown arrow on top of its text, the
   active choice not in `UI_ACCENT`, any developer word, a clickable thing with no hover highlight,
   italics or Light/Thin weights, text under the main menu's size in angle.
4. Code checks that a render won't show:
   - `tests/test_menu_layout.tscn` passes (overlaps, gaps under 4 px, controls spilling out of their box); a
     new panel or state gets added to it with its worst-case content;
   - visuals that change without pointer input (progress, cover loaded, list refreshed) call
     `canvas._input_update()`, or the headset shows a stale frame (`game/ui/AGENTS.md`);
   - nodes inside a canvas are found with `find_child` or exported `NodePath`s, since the canvas
     reparents its `Control`;
   - GDScript types are explicit where a ternary or `and`/`or` returns a Variant, or the panel fails
     to parse on load and shows nothing.
5. Share the PNGs with the user when a layout changed, so they can say what's wrong before the APK
   reaches the headset.

## 5. Check on the headset

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

## 6. Fix the class, not the case

- [ ] For each problem found, search the whole game for the same pattern (other screens, other
      keyboards, other lists, other filters) and fix every instance in the same change.
- [ ] Add a line to this checklist or to the root `AGENTS.md` ("Player-facing wording and UX") so the
      same kind of problem is caught next time.

## 7. Report

- Problems found, each with cause and fix, worst first.
- What you checked and how (numbers for placement, states walked, headset or not).
- Anything you couldn't verify, said plainly.
