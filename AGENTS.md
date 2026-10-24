# Agent guidelines

BoredSaber is a Godot 4.6 (GDScript) Beat Saber-style game for standalone Pico 4, based on Open Saber Plus.

## Repository map

Each folder below has its own `AGENTS.md` with a file map, gotchas and "where to change X" recipes.
Read the one for the folder you are changing before editing.

- `game/`: main scene, autoloads, note/bomb/chain/arc/wall/saber entities, assets in `game/data/`.
- `game/scripts/`: shared scripts (utils, controllers, highscores, pools, raycasts, song uploader).
- `game/scripts/GameState/`: the game state machine (menu, playing, paused, fail, score screen).
- `game/BeatmapInfo/`: beatmap data model and how `game/Map.gd` parses Beat Saber map formats.
- `game/ui/`: menus, shared theme and UI palette, BeatSaver download panels.
- `OQ_Toolkit/`: partially ported VR toolkit (`vr` autoload, 2D-in-VR canvases, keyboard).
- `tests/`: headless tests.
- `.github/`: CI build, APK release and how to test a build on the headset with adb.
- `addons/`: not tracked; CI installs godot_openxr_vendors there.

## Rules

- Keep diffs minimal: touch only the files the change needs. No unrelated
  refactors, renames or reformatting, they hide the real change from review.
  This includes files the Godot editor rewrites on its own (`.uid`, `.import`,
  resaved `.tscn`/`.tres`): revert or delete them unless the change needs them.
  If you spot an unrelated problem, report it instead of fixing it.
- Match the neighbouring files: naming (`snake_case` functions and variables,
  `PascalCase` `class_name`), static typing, comment density, and how logic is
  split between scenes (`.tscn`) and scripts (`.gd`).
- Write the simplest code that solves the current task. Keep a function next
  to its only caller; extract a shared abstraction on the third use, not
  before. Never create new generic helper/utils scripts, and don't grow the
  existing `game/scripts/Utils.gd` with code that has one caller.
- Fail fast on internal invariants: use `assert()` or `push_error()` and
  return, with no fallbacks or defaults for states that should not happen. Do
  validate at boundaries: map files (`Info.dat` and difficulty files), BeatSaver
  and other network responses, the saved `config.ini`, and OpenXR runtime
  capabilities.
- Every function gets a `##` doc comment saying what it does or returns, not how.
- Every number that sets behaviour gets an `UPPER_CASE` `const` at the top of
  its script. Values the player can change go in `game/Settings.gd`
  (`default_values`, plus a control in `game/settings_Panel.tscn`); engine and
  XR values go in `project.godot` or the scene that owns them.
- Ask before adding a new dependency (Godot addons, plugin or engine version
  bumps, GitHub Actions).
- Never bypass git hooks (`--no-verify`) and never weaken or delete a test
  to make it pass; fix the cause.
- One logical change per commit. Push only when the user asks.

## Player-facing wording and UX

Everything a player sees (menus, buttons, labels, tooltips, score screen, errors) is for players,
not developers. Follow "Don't make me think": a player should understand every choice at a glance.
Each rule below names its source and a bug it would have caught here.

Words and choices
- Speak the player's language, not the code's: no `NJS`, `HJD`, `RT`, `NPS`, `BPM`, `JSON`, `null`,
  `index`, `request failed (code 0)`, "(can stutter)". Say what it means for the player, e.g. "Notes
  appear 0.7 s ahead", "Couldn't download the song. Check your Wi-Fi and try again." [Nielsen #2]
- One word per concept and one concept per word, everywhere, and one place to change each setting.
  No two controls that do the same thing. (Difficulty had four vocabularies; "Workout" meant two
  things; handedness lived in Settings and Modifiers; two buttons renamed the player.) [Nielsen #4]
- Prefer a few named choices over raw numbers or free input (Easy / Normal / Hard, not a 0.5-1.5
  slider), with a sensible default already selected. (Twelve saber-offset number boxes.)
- When a new term, choice or flow has no obvious plain wording, ask the user or propose two or three
  player-friendly options instead of shipping developer wording.

Flow
- Shortest path to play: count the presses from launch to playing a song and never add one without a
  reason; every screen has a way on to playing. (Forced name entry; Play hidden by the Modifiers tab.)
- Always a way out: every modal has Cancel, every page has Back or Close, and no state needs input the
  player can't give. Walk the error, empty and cancel paths, not only the happy one. (Keyboard without
  ✕; empty name blocking Enter; a failed restart leaving no menu.) [Nielsen #3]
- Prevent mistakes, then confirm what's lost: destructive actions (delete, reset, exit, abandon a run)
  name what goes ("Delete Blinding Lights and its 3 records?") or offer undo; don't ask about things
  that are easy to undo. (Reset all silently wiped the name, filters and modifiers.) [Nielsen #5]

Feedback and state
- Every action answers at once: a visible change and a sound on press, progress for slow work
  ("Loading songs…", "Downloading 45%"), and on failure what happened plus what to do. Never "nothing
  happens". (Empty BeatSaver list after a failed request; Play with no song picked.) [Nielsen #1, #9]
- Mind the three response limits: the press itself shows within 0.1 s (highlight, sound); anything over
  1 s shows that it is working ("Loading songs…"); anything over 10 s shows how far it got and can be
  cancelled. (Refresh Songs gave no sign it ran.) [Nielsen, "Response Times: The 3 Important Limits"]
- Show the current state, don't make the player remember it: what is selected, which filters are on,
  what was typed, which tab is open, what a button will do. (Search text hidden under a button; the
  typed name invisible behind a panel.) [Nielsen #6]
- Filters never surprise: show which filters are on, how many results remain ("Showing 5 of 30 ·
  Clear filters"), counts on the choices, and a message with a way back when nothing matches; one
  screen's filters don't change another's. (Easy + Workout silently left 0 songs.) [Nielsen #1, #6]

Layout and look
- One primary action per screen in `UI_ACCENT`; everything else secondary, destructive actions
  secondary and apart. (Settings, Pause and the score screen had no main button.) [Hick's law]
- Things that can be pressed look pressable, and things that look pressable are: a control looks like
  what it does (a tab switches content in place; a button that opens another screen isn't styled as a
  tab). (Settings looked like a tab but opened a whole screen.) [Norman: signifiers]
- Show less, reveal on demand: the first view holds what most players use; detailed or developer
  options go in Advanced or behind a toggle. (Debug switches, saber X/Y/Z among everyday settings.)
  [Nielsen #8, progressive disclosure]
- Remove before adding: before a new button, option or screen, check whether an existing one can do
  the job, and delete what nobody can reach. (BeatSage/YouTube screens still loaded but unreachable.)
- Help in place: a short hint where the choice is made (a one-line explanation, a label that appears
  on hover), not a manual. [Nielsen #10]
- Mixed reality: virtual scenery never covers the player's room; with mixed reality on, draw only what
  play needs (track, notes, sabers, light beams). (Neon Grid's floor hid the room.)

Process
- For any menu, panel, HUD or score-screen work, follow `.claude/skills/vr-ui-design/SKILL.md` before
  building (flow, 3D placement, sizes, feedback) and `.claude/skills/vr-ui-review/SKILL.md` before calling
  it done (every game state that shows the node, overlap and depth checks, headset walk-through).
- Fix the class, not the case: when a UX problem is found, search the whole game for the same pattern,
  fix every instance in one change, and add the check to `vr-ui-review` so it doesn't come back.

Sources: Nielsen, "10 Usability Heuristics for User Interface Design" (NN/g,
https://www.nngroup.com/articles/ten-usability-heuristics/); Norman, "The Design of Everyday Things"
(signifiers, feedback); Krug, "Don't Make Me Think"; Hick-Hyman law (more choices, slower decisions).

## Research before changing game feel

Anything that changes how the game feels to play must be researched before it is implemented or tuned:
note speed and reaction time, spawn distance, swing and cut scoring, health and fail rules, difficulty
bands and thresholds, haptics, hit and miss feedback, sound timing, comfort (brightness, flashing,
motion), and HUD placement.

- Base values on evidence, not guesses: Beat Saber and community standards (map data from BeatSaver,
  BeatLeader/ScoreSaber conventions, tools like JDFixer), VR comfort guidelines, or measured data
  from real maps. Record the sources and the numbers in the commit message or the folder `AGENTS.md`.
- If no research exists yet for a value, do it first (or ask the user), and mark any placeholder
  clearly as untuned in code and in the reply.
- Changes to feel need a playtest on the headset before they are called done.

## Colour rules

Every colour in the game has one job, so players can read the scene at a glance. Colours live in
one place: `game/Constants.gd` (UI palette `UI_*`, `MISS_COLOR`, `SHADOW_TINT`, `DANGER_COLOR`,
`DIFFICULTY_COLORS`, `RANK_COLORS`) and `COLOR_PRESETS` in `game/Settings.gd`; `game/ui/menu_theme.tres` must stay in
step with the `UI_*` values. Don't hard-code a new `Color(...)` in a scene or script; add a named
constant with its role, or reuse one.

- Note colours (left/right, from the preset or the map) mean "cut this": notes, chains, arcs,
  sabers, and the lights that follow them. Nothing else uses them.
- Danger colour (`DANGER_COLOR`, Beat Saber's wall red, or the map's wall colour) means "dodge or
  you'll lose": walls, bombs, wall-hit feedback, low health. Never use it for decoration or menus.
- `MISS_COLOR` is only for misses and mistakes.
- `UI_DANGER` (soft red) is for a menu asking before it deletes or resets something, and for the song menu's
  warning icon (play area, battery, heat, breaks); always with words or a "!".
- `UI_ACCENT` (cyan) means "selected, active or the main action": the active tab or option, the
  selected song, the Play button. Don't use it for plain decoration or for warnings.
- Neutrals (`UI_PANEL`, `UI_SURFACE*`, `UI_BORDER`, `UI_TEXT`, `UI_TEXT_MUTED`) for everything else.
- `DIFFICULTY_COLORS` only label difficulties and reaction-time levels.
- `RANK_COLORS` only colour the rank letter and the result ring on the score screen.
- The environment stays dark navy (`SHADOW_TINT` in the shadows) and takes its light colours from the
  note colours, so the scene never competes with notes or danger.
- Never rely on hue alone (colour-blind players): pair a colour with a shape, pattern or word
  (the see-through box with a glowing frame for walls, the ✕ for a miss, text on difficulty buttons).
- Comfort: no large areas of saturated or pure-white colour, keep flashes short and moderate, and
  keep body text at a 4.5:1 contrast or better against its panel.
- A new colour role needs the user's agreement first; propose it with where it is used.

## Light

The scene is lit like a concert stage, not a toy: dark, with small bright sources whose colour shows in
their glow and the haze. Read this before changing lights, environments, walls, bombs, haze or the sky,
and measure every change on the headset (`.github/AGENTS.md`). The game renders without HDR (0-1 per
channel), so brightness comes from contrast and the size of bright areas, not from values above 1.

1. Value before hue: most of the frame is dark; light lives in small, bright sources. Keep a clear
   brightness order: notes and sabers > walls and bombs > light fixtures > beams in haze > scenery > sky.
2. Hot core, coloured falloff: a bright emitter burns toward white at its centre and shows its colour in
   the glow around it (overexposure desaturates). Brighten by mixing toward white or widening the
   bright part, never by multiplying a saturated colour past 1 (it clips to a flat, fully saturated
   colour). Walls already do this (`game/Wall/DangerWall.gdshader`: white-hot frame, red halo).
3. Saturation lives in small areas: full note colour only on fixtures, beams and their halos; large
   surfaces (floor, sky, haze, walls' glass) stay dark and low in saturation.
4. Limited palette: the two note colours, the danger colour, and neutrals (cool or warm grey, white).
   No extra hues; the menus use a near-neutral house light (`EventDriver.HOUSE_COLOR`).
5. Light has a source and a path: build the structure first (frames, walls, plates, buildings), then mount
   every light on it in one of three ways: (a) a fixture on a surface shooting a beam out (with a bright
   spot where the beam leaves it), (b) a strip or panel flush on a surface, outlining it, or (c) a bar or
   beam spanning from one object to another. Nothing floats unsupported. Fixtures repeat in rows along their
   surface for rhythm and depth. A beam turns around its fixture (`game/AGENTS.md`), shows only through
   haze, and fades with distance and along its length; far things lose contrast toward the haze colour
   (aerial perspective). Keep each environment's signature view clear: structure goes to the sides and below the
   horizon, never in front of it (a backdrop behind Neon Grid's horizon read as clutter).
6. Haze reveals, it doesn't paint: the air stays mostly neutral and is tinted only a little by nearby
   lights (`EventDriver.HAZE_LIGHT_WEIGHT`).
7. Fixtures move like machines: pan and tilt around the fixture with ease in and out at plausible
   speeds; colour changes fade, except deliberate flashes.
8. Flashes are short and rare: fewer than 3 a second, never large saturated red flashes, moderate
   peaks (`EventDriver.FLASH_BOOST`) (WCAG 2.3.1 Three Flashes; Harding flash test).
9. Dynamics tell the story: dim and slow before the show (menus), the map's light show during it,
   a blackout between; contrast between moments beats constant brightness.
10. Fake it cheaply: no post-processing or screen reads on the Pico (a screen read copies the frame per
    eye); glow, distortion and shadows are drawn in the object's own shader.

For any shader work, follow `.claude/skills/shader-design/SKILL.md` (layers first, named knobs, then
optimise with before/after GPU numbers). For any new or replaced model, follow
`.claude/skills/game-model-creator/SKILL.md` (spec and budget first, Blender by script, shared unshaded material).
For any environment or layout change, follow `.claude/skills/rhythm-world-design/SKILL.md` and keep the design
records in `doc/world/` (game bible, visual style, spatial layout, audio-visual mapping) up to date. Where it
disagrees with the Light, Colour or playspace rules here, these rules win; suggest a change to the owner when the
skill's way is clearly better or at least no slower on the headset.

Sources: James Gurney, "Color and Light" (luminance and saturation, limited palettes); Richard
Pilbrow, "Stage Lighting Design" (direction, source and movement of stage light); W3C WCAG 2.2
success criterion 2.3.1 (https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold);
inverse-square falloff and atmospheric extinction as used in physically based rendering.

## Pico 4 constraints

Found from headset logs on Pico OS 5.12 (OpenXR runtime 2.1.12); don't undo them without testing on the headset.

- Renderer stays Compatibility (`gl_compatibility`): the Vulkan path segfaults inside the Pico runtime at startup.
- `xr/openxr/target_api_version` stays `1.0.0`, and the Pico profiles in `openxr_action_map.tres` must not bind
  `grip_surface/pose`: the runtime rejects the path and drops the whole profile, so the controllers stop tracking.
- Builds are signed with `.github/debug.keystore` so new APKs install over old ones; don't regenerate it.

## Checking a change

- Map parsing tests: `godot --headless --path . res://tests/test_map_info.tscn` (exits non-zero on failure).
- Menu layout test: `godot --headless --path . res://tests/test_menu_layout.tscn` (overlaps and overflow in the song
  menu and "Who's playing?" with worst-case content; exits non-zero on failure).
- `.github/workflows/build-pico4.yml` imports the project, runs the tests and exports the APK on every push.
  Pushes to `pico4-offline` or the default branch also replace the `pico4-latest` release, which the headset
  browser downloads from.
- Anything touching XR, input or rendering needs a test on the headset, with `adb logcat` when it misbehaves.
