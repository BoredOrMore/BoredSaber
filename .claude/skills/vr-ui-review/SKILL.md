---
name: vr-ui-review
description: Check a BoredSaber UI change or a reported UI problem - walk every game state that shows the changed nodes, check placement, overlap, clipping and depth in 3D, wording, feedback, navigation and dead ends, then verify on the Pico 4. Use after any change to menus, panels, HUD, score screen, keyboard or the BeatSaver page; when the user reports a UI bug (overlapping or clipped text, panels in the wrong place, a screen you can't get back from); and when asked whether UI wording or layout is OK. Load it before searching the code.
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
- [ ] Each icon means one thing everywhere: no icon stands for two concepts, and a new icon takes a meaning no
  other icon has (search `game/ui/icons/` and every `preload(` of an `.svg`). (The bolt meant both notes per second
  and Energy, 2026-10-28: Energy keeps the bolt, notes per second got a music note.)
- [ ] Test every state, not only the happy path: nothing selected, empty list, every filter on, no
      network (request fails), slow network, cancel at each step, error on load, first launch with
      default settings, mixed reality on, left-handed. Each one shows a message and a way on.
- [ ] Destructive actions name what is lost and confirm (or can be undone); filters show what is on,
      how many results remain and how to clear them.
- [ ] Filters never cover the list they filter, so each press shows its result at once, and each choice is one press
      (chips, `FilterChips`), not a dropdown (owner, 2026-10-30: the Filters panels hid the list until Back).
- [ ] Mixed reality on: nothing opaque covers the room beyond what play needs.
- [ ] Recognition over recall: what is set (modifiers, filters, difficulty, the stage) shows where the player
      decides, not only on another tab.
- [ ] Engage-ability, not only usability: the change keeps the player moving toward playing (Hodent); feedback is
      felt (sound, light, rumble) but moderate (`ComboHud.gd`'s header).
- [ ] A HUD addition takes its tier by urgency (now: big, steady, high contrast; secondary: smaller, muted; rare:
      off the HUD), `doc/research/game-ui.md`.

## 2b. Checks by type of UI

Find the type of every node from step 1, then run its list on top of sections 2-5. A node can be more than one type
(a button on a curved panel runs both lists).

### HUD during play (`game/hud/`)
- [ ] Placed from the eye at song start (`Hud.gd`), inside the no-turn zone (±30° side, +20° / -12°), checked at 3 eye
  heights and with Wide lanes (as `tests/test_hud` does).
- [ ] Never inside the note lane or the wall/bomb space, at any lane width.
- [ ] Tier by urgency (`doc/research/game-ui.md`): now = big and steady, secondary = smaller and muted.
- [ ] Brightness below notes and sabers (Light rule 1); no colour with another job (no note colour, no `DANGER_COLOR`
  except low Energy).
- [ ] Motion only on events (combo pop, red shake), short; nothing that pulses all song long.
- [ ] GPU time in play compared with the last build (`PxrMetric`).

### Curved menu panels (song menu, Get songs, Settings, Who's playing)
- [ ] Built from `MenuPanel` / `MenuSection` templates and the shared theme; no hand-built frame.
- [ ] Turn zone: ±45° side, top edge +20°, bottom -27°; glance-only up to ±70°.
- [ ] Horizontal curve only, centred on the eye; rises with eye height on each state change (`_place_menus`).
- [ ] Only the song list scrolls on the song page; everything else fits its panel.
- [ ] Pointer hit point matches the drawn point on the curve (0 px error in the panel test).
- [ ] Rounded corners.

### Flat screens and popups (score screen, Pause, confirm popups, Licenses)
- [ ] Stay flat (owner, 2026-10-27); face the eye; in the no-turn zone when shown after a song.
- [ ] Every one has Cancel / Back / Close; nothing behind it can be pressed while it is open.
- [ ] Shown in front of whatever is behind it with ≥ 5 cm depth gap, never behind another panel.

### Buttons and controls (buttons, chips, tabs, toggles, sliders)
- [ ] Uses one of the theme's button templates (`theme_type_variation`); one `PrimaryButton` (`UI_ACCENT`) per screen;
  destructive = `ConfirmButton`, apart from the main action.
- [ ] Target ≥ 2.5-3° on its smaller side at its real distance; ≥ 4 px from its neighbours.
- [ ] Hover, press and sound; selected state visible without colour alone (white label + border).
- [ ] Looks like what it does (a tab switches in place; a button that opens a screen is not a tab).

### Text and numbers
- [ ] Height ≥ 1.85° (`ui_angles` floor); Roboto Medium body, SemiBold/Bold headings in 2D; 3D `TextMesh` Medium.
  One owner exception (Bored, 2026-10-29): the far HUD of 90/360 maps uses Beat Saber's 1.1-1.4° (`Hud.FAR_*_DEG`).
- [ ] Numbers: Kanit Italic 600, thousands "," in scores and counts (not time or percent), a unit on every value.
- [ ] Contrast ≥ 4.5:1 (3:1 at 24 px and up) on every background it sits on (normal, hover, selected).
- [ ] Player words only (root `AGENTS.md`); one word per concept across every screen.
- [ ] Longest real content fits without clipping (`tests/test_menu_layout`).

### Feedback in the lane (MISS, cut numbers, FAILED, combo banner, sparks)
- [ ] Never hides the next notes: shows behind or beside the cut point and fades before the next note arrives there.
- [ ] Colour by job: MISS white (owner, 2026-10-28), note colours only for cut feedback, `DANGER_COLOR` only for danger.
- [ ] Flashes < 3 per second, moderate peaks (Light rule 8); short, no lingering motion.
- [ ] Same in mixed reality (draws only what play needs).

### Input (pointer, keyboard, thumbstick)
- [ ] Both hands work; left-handed setting respected.
- [ ] Keyboard has ✕, typed text visible where the player looks, empty input can't block Enter.
- [ ] Thumbstick scroll gives light haptic per row; no input the player can't give in that state.

### Sound and haptics as UI
- [ ] Every press has a sound; the same action uses the same sound everywhere.
- [ ] Haptics short and light in menus; in play they follow cuts, clashes and walls only.
- [ ] Nothing relies on sound or haptics alone (pair with a visual).

## 2c. Does the change collide with anything?

Run all three before calling a UI change done, and list the result in the report (section 7).

1. **Space.** For each changed node, in every state from step 1, compute its angular box (yaw, pitch, size) from the
   real eye (`tools/capture/ui_angles`, at eye 1.5, 1.6 and 1.75 m) and compare it with every other node visible in
   that state: HUD, menus, popups, the slash note, the keyboard, the note lane and wall space, the saber's reach.
   Flag any two boxes that overlap in view, unless one is meant to sit on the other (≥ 5 cm in front, the one to read
   in front).
2. **Rules.** Check the change line by line against root `AGENTS.md` (UX, Colour, Light), `vr-ui-design` and the
   lists in 2b. If a rule has to bend, stop and ask the owner; don't ship the exception.
3. **Other work.** Check open branches and threads for edits to the same files or nodes
   (`git log origin/<branch> -- <file>` for each open branch); if another thread owns that UI (e.g. the menu layout),
   hand the change over instead of editing it.

## 3. Check placement in 3D (numbers, not guesses)

For each visible piece in each state, compute its world centre and size:

- World position = parent transform applied to the child offset, through every parent
  (`Transform3D(...)` in `.tscn` is row-major basis then origin; columns are the local axes).
- Canvas size in metres = control size px / 1024 × node scale.
- Angle from the player's real eye (root `AGENTS.md`), not a fixed one: for an eye at (ex, ey, ez) facing -z, with
  dx = x - ex, dy = y - ey, dz = z - ez: yaw = atan2(dx, -dz), pitch = atan2(dy, hypot(dx, dz)). Pieces placed from
  the eye move with it, so check at eye heights 1.5, 1.6 and 1.75 m (`tools/capture/ui_angles` with `--eye`), the
  player at `XROrigin3D` (0, 0, 1).

Flag:

- [ ] UI looked at while still (HUD, countdown, score) outside ~±30° yaw, +20° / -12° pitch; a menu
      the player turns to use outside ±45° yaw, +35° / -27° pitch (past ±45° only for a glance, never
      past ±70°); lower is fine only for short, tilted tasks like the keyboard.
- [ ] Anything on the song page other than the song list scrolls.
- [ ] Distance under 0.5 m or over 2.5 m for something the player must read; pointer targets
      closer than 0.8 m or further than 3 m [Meta hands UI].
- [ ] Two pieces overlapping in view whose depths differ by less than ~5 cm, or the one to read is
      behind (the hidden name text box: keyboard text at z -0.83 behind the score panel at z -0.78).
- [ ] Something in front of a curved panel crossing it at its edges: the panel bends toward the eye (its edges
      sit closer than its centre), so check the gap at the front piece's ends, not its middle, with the
      distance from the panel's axis (the keyboard's text box sank 9 cm into the curved "Who's playing?"
      panel and touched the song menu; the keyboards now sit 10% closer along the eye ray, same angles).
- [ ] A side panel not facing the player.
- [ ] Targets under ~3° (≈ 5.2 cm at 1 m), text under 1.85° high (the `ui_angles` floor, from the
      main menu's 28 px at scale 2.4 and 2 m).
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
4. Contrast and colour (Game Accessibility Guidelines, WCAG): every text colour against every background it sits on
   (normal, hover, selected) at least 4.5:1, or 3:1 for text 24 px and up; compute it from the colours, as in the
   table in `doc/research/game-ui.md`, and recompute that table when a UI colour changes. Nothing told by colour
   alone: a name, an icon or a mark goes with it.
5. Code checks that a render won't show:
   - `tests/test_menu_layout.tscn` passes (overlaps, gaps under 4 px, controls spilling out of their box); a
     new panel or state gets added to it with its worst-case content;
   - visuals that change without pointer input (progress, cover loaded, list refreshed) call
     `canvas._input_update()`, or the headset shows a stale frame (`game/ui/AGENTS.md`);
   - nodes inside a canvas are found with `find_child` or exported `NodePath`s, since the canvas
     reparents its `Control`;
   - GDScript types are explicit where a ternary or `and`/`or` returns a Variant, or the panel fails
     to parse on load and shows nothing.
6. Share the PNGs with the user when a layout changed, so they can say what's wrong before the APK
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
- The three collision checks from 2c (space, rules, other work) and what each found.
- Anything you couldn't verify, said plainly.
