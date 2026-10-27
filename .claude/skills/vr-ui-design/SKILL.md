---
name: vr-ui-design
description: Rules for building or changing anything the player sees or touches in BoredSaber (menus, panels, HUD, score screen, keyboard, BeatSaver page, labels, filters). Use before writing UI code or scene changes, and when proposing a UI plan to the user.
---

# VR UI design for BoredSaber

The player wears a Pico 4, holds two sabers that double as laser pointers, and cannot see the code.
Every past UI bug in this repo came from one of the rules below being missed. Read the root
`AGENTS.md` ("Player-facing wording and UX", "Colour rules") and `game/ui/AGENTS.md` (how 2D UI
reaches VR) first; this skill adds the VR-specific checks.

## 1. Start from the player's flow, not the widget

Before touching a scene, write the flow as numbered steps from the player's view: what they see,
what they press, what happens next, how they leave. For each step answer:

- Where is the player looking right now? New UI goes where the eyes already are, not in a spot they
  have to discover. (The name bar under the score at waist height went unnoticed.)
- What does the player do next by default? There is always one obvious main action (`UI_ACCENT`).
- How do they back out? Every modal (keyboard, dialog) has Cancel, and an empty or invalid input can
  never trap them (the name keyboard once had no cancel and ignored Enter on an empty name).
- What else is clickable while this step is open? Disable controls that would abandon the step
  (Repeat/Main Menu stayed live while typing a name).

## 2. Placement in 3D

Everything the player looks at or interacts with is worked out from their real eye (owner, 2026-10-27): its
place, size and reach as angles and distances from the headset's position, not metres from a fixed eye. The HUD
is placed from the eye at a song's start (`game/hud/Hud.gd`), the slash note from the eye when it shows
(`SlashBlock.set_shown`), and the menus rise with the eye's height on every game state change
(`BeepSaber_Game._place_menus`); a new piece does the same.

Positions are metres in the main scene. The player stands at `XROrigin3D` (0, 0, 1), not at the
scene origin: eyes around (0, 1.6, 1), facing -z. Panels are `OQ_UI2DCanvas` quads: 1024 px = 1 m at scale 1 (`vr.UI_PIXELS_TO_METER`),
then multiplied by the node `transform` scale.

- Two zones, by whether the player turns to use the UI (owner, 2026-10-28):
  - **No head turn**, for UI looked at while still (HUD, countdown, score): within about ±30°
    left/right, 20° up and 12° down of straight ahead (comfortable head rotation from Alex Chu's
    Samsung VR design talk and Mike Alger's "Visual Design Methods for Virtual Reality", 2015;
    maximum 55° to the side, 60° up, 40° down).
  - **Head turn plus eyes**, for menus the player turns to use: the head's comfortable turn plus the
    eyes' comfortable 15° (beyond it the head follows): ±45° left/right, 35° up, 27° down. Past ±45°
    only for a glance (an occasional control or a look), never past ±70° (the neck's 55° plus the eyes).
  - Bias content below eye level: the normal line of sight is about 15° down (MIL-STD-1472) and
    holding the head up strains the neck sooner than looking down (ISO 11226). Short tasks like
    typing may sit lower if tilted to face the eye.
  - A panel wider than about 30° curves around the eye, left to right only (a slice of an upright
    cylinder, `OQ_UI2DCanvas.curve_radius`; owner, 2026-10-28: no curve up and down), so its text
    keeps the same angle to its left and right edges; its top and bottom rows sit further away.
- Main panel distance 0.8-2.5 m. Eye strain starts at ~0.5 m and closer (Oculus recommends 0.75 m
  minimum); further shrinks text. Pointer (ray) targets belong 0.8-3 m away, never closer than
  0.8 m [Meta hands UI]; content read for a while at least 1 m away [Apple eyes].
- Centre important content; content at the sides means turning the head again and again [Apple
  spatial layout, Meta comfort]. Anchor UI in the world, never to the head, and keep the main
  controls on one panel rather than many floating windows [Apple spatial layout, Meta comfort].
- A side panel must face the player (yaw toward (0, 1.6, 1)) and stay inside the head-turn zone. A
  table 2.3 m left turned 60° was out of sight.
- **Depth:** two panels at similar depth must not overlap in the view. Compute world positions:
  a child offset is rotated and scaled by every parent transform. (The keyboard's text box sat 5 cm
  behind the score panel and was invisible.) Leave at least 5 cm between layers that overlap, and
  put the one the player reads in front.
- **One node, many states:** a canvas shown in several game states (e.g. `Highscores_Canvas` in the
  song menu and on the score screen) must be placed per state, or checked against every state's
  layout. Moving it for one screen once covered the song list in another.
- Never put UI inside the play lane (x ±1 m, in front of the player) while notes can fly.

## 3. Size and legibility

- Pointer targets: at least 2.5-3° of visual angle [Meta hands UI, Meta eyes]:
  `size = 2 · distance · tan(1.5°)` ≈ 5.2 cm at 1 m, 10.5 cm at 2 m. The hit area may be larger than
  the drawn button (Apple: a 60 pt hit area around a smaller visible button).
- Spacing: button centres at least one target size apart with a visible gap (Apple: centres 60 pt
  apart, 16 pt between); interactive elements never overlap [Apple spatial layout, buttons].
- Pieces that act as one control (cover + title on a song card) share one highlight and hit shape
  [Apple eyes].
- Never lift text off its background in depth, and keep few depth levels: each refocus tires the
  eyes [Apple spatial layout, Meta comfort]. Bolder weights than on a phone [Apple typography]:
  Medium for text, SemiBold for buttons and chips, Bold for titles and the main button (the theme's Roboto, `game/ui/fonts/`), no Light/Thin, no italics, few sizes [Meta
  typography]. Meta's text floor is 14 px, 18 px for reading, on panels where 1 dp = 2 mm, about our
  px at canvas scale 2.
- Rounded buttons and chips with the label centred and padded; flat, no heavy outlines [Apple
  WWDC23 "Design for spatial input"].
- Text: the theme's 28 px on the main menu canvas (scale 2.4 at 2 m from the eyes ≈ 6.6 cm ≈ 1.9°) is the
  playtested baseline; don't make body text smaller in angle than that. Muted text needs more size.
  In a reading study on Oculus Go and Quest (Kojić et al., "User Experience of Reading in Virtual
  Reality", QoMEX 2020) players set short labels larger than paragraphs (about 30 against 17
  milliradians), so short labels and buttons get the bigger sizes, and they picked a contrast of 7:1
  or more, above the 4.5:1 minimum in the root `AGENTS.md`.
- Clickable shapes: the hit area matches what the player sees (a favourite star whose hitbox missed
  the icon felt broken). Leave room for dropdown arrows and padding; never let text touch edges.
- No dense blocks of text. Split details into short labelled lines or chips; clip long descriptions.
- Design for the longest real content, not the sample: long song titles and mapper names, 0 results,
  6 difficulties. A button label that doesn't fit gets shortened or split onto two lines on purpose,
  never wrapped by the engine mid-word; one line per idea in lists, with "…" for overflow.
- Inside a panel nothing may overlap or touch (4 px gap or more). Controls placed with offsets don't move out of
  each other's way, but buttons and containers grow to fit their content: a button is as tall as its text or icon
  plus the theme's padding (a 36 px icon makes a 60 px button, 40 px text a 72 px one), and a container centred
  in its box grows both ways. Size every box for its worst-case content, top-align boxes whose content varies
  (or put the neighbours in one container), and give an overlay panel the full height of what it covers. The
  song menu once had the difficulty picker over the favourite button, chips over Play, and the modifiers
  column peeking out under the More tab.

## 4. Controls that explain themselves

- No hidden modes: never a button that silently cycles through lists ("Plays" did). Show all
  choices as tabs or chips with the active one in `UI_ACCENT`.
- One vocabulary per concept, everywhere (difficulty became one Easy..Expert+ scale after four
  overlapping ones confused the player). Before adding a label, search the UI for an existing term.
- Don't add a filter that duplicates another. Prefer a few named choices with a default over raw
  numbers (root `AGENTS.md`).
- Show state: what's selected, what's already downloaded or saved, what a button will do.

### Icons

Use an icon when it is quicker to read than the word (the user asked for this), but pair it with a
short label by default: few icons are understood without one (NN/g "Icon usability": home, print
and search are about the only near-universal ones; labelled icons were predicted correctly far more
often than unlabelled ones in UserTesting's study).

- Icon-only is fine only for near-universal actions (search 🔍, close ✕, play ▶, back ←) and for
  repeated compact info whose meaning a header or the first use already taught (⏱ 3:24 in a list).
  An icon-only button still shows its name on hover (Apple: visionOS shows a tooltip on hover).
- One icon = one meaning everywhere, one meaning = one icon. Keep a single family: Lucide
  (ISC, `game/ui/icons/` with its `LICENSE`; copy only the icons used, stroke `#e6e8ee`, 36 px).
  Current meanings: search, star favourite, download get songs, play play/continue, refresh-cw
  rescan songs, trash-2 delete, log-out exit, house main menu, rotate-ccw restart song, undo-2 reset
  settings, locate-fixed recenter, check done, x close/clear, arrow-left back, user player (who's playing). Older
  `game/ui/*.svg` (`heart.svg` health, `target.svg` precision, `edit.svg`) match its style.
- A button with icon and label uses `IconButton` (`game/ui/IconButton.gd`) so the icon sits next
  to the centred word, not at the far edge.
- Size icons like targets (≥ 2.5-3°), and give them the same colour role as their meaning (danger
  only for danger, `UI_ACCENT` only for selected/main action).
- Draw icons as SVG in `game/ui/`; don't rely on font symbols (★ ✓ ←): glyphs Roboto lacks
  fall back to whatever font the headset has and look inconsistent.
- New icon source (an icon library) counts as a new dependency: ask first (root `AGENTS.md`).

## 5. Feedback for every action

- Every pointer target shows hover, a visible change on press and a short distinct sound on selection
  [Meta hands UI, Apple buttons] (`UI_AudioEngine.attach_children`); haptics add to that, never replace it.
- Anything slow (download, search, loading) shows progress or a spinner and a clear end state
  ("Downloading 45%" → "✓ In library · Play now").
- Saving or renaming confirms on screen where the player is looking ("Saved as …").
- Errors in player words with a next step ("Can't reach BeatSaver. Check your Wi-Fi.").
- Typed text is always visible where the player looks while typing.

## 6. Colours, comfort, performance

- Follow the root `AGENTS.md` colour rules (`UI_ACCENT` = selected/main action, danger colour never
  for UI). Pair colour with a word or shape.
- No large bright or saturated areas, short moderate flashes only.
- Text stays still while hovered and part of a screen (title, tabs) stays fixed when its content
  changes; never swap the whole view [Apple WWDC25 "Design hover interactions"]. No scrolling or
  marquee text: a long title ends in "…" and the details panel shows it whole.
- Motion only with a purpose. No sustained oscillation near 0.2 Hz (people are very sensitive to it)
  and no busy motion at the edges of view [Apple motion, immersive experiences]: keep pulses,
  and glows small and short.
- No repeating pattern or texture filling the view: the eyes can lock onto it at the wrong depth
  [Apple eyes].
- UI must not cost frame time during play: no per-frame viewport redraws of hidden canvases, no new
  post-processing. Canvases redraw only on input (see `game/ui/AGENTS.md`). Measure on the headset
  (`.github/AGENTS.md`) for anything visible during a song.

## 7. Propose before building

For a new screen or flow, send the user a short plan in player words: the flow steps, where each
piece sits, the labels, and what you'll drop. Before sending it, check the plan itself against every
rule in this skill and in the root `AGENTS.md` ("Player-facing wording and UX"), with numbers for
placement (section 2), and fix what fails: rules apply to proposals, not only to built code. (A
"cut a block to play" plan reached the user with a second Play control kept "as a fallback", a font
glyph in its label, no song name on the action and a target 30° below the eyes, because research and
genre examples were checked but these rules were not.) Offer two or three wording options when the plain
term isn't obvious. Then build in small steps, one build per step, and verify each with
`vr-ui-review`.

## Platform guidelines used

- Icons: Nielsen Norman Group, "Icon Usability" (Harley, 2014), https://www.nngroup.com/articles/icon-usability/

Numbers per source, with WWDC session links and the dp conversion: `sources.md` next to this file.

- Apple Human Interface Guidelines, visionOS: Spatial layout, Eyes, Buttons, Typography, Motion,
  Immersive experiences (https://developer.apple.com/design/human-interface-guidelines/spatial-layout
  and sibling pages). Apple points are angular, so take its rules and convert sizes with Meta's degrees.
- Meta Horizon design: Comfort (https://developers.meta.com/horizon/design/comfort/), Hands UI best
  practices (https://developers.meta.com/horizon/design/hands-ui-best-practices/: 2.5-3° colliders,
  ray UI 0.8-3 m, hover/press/sound feedback), Eyes best practices (3° gaze targets).
