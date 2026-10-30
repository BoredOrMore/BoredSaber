# Song menu as a curved horseshoe: plan (nothing built yet)

Owner, 2026-10-27: song and ranks on the left, a dedicated modifier panel on the right, the panels curved.
Diagram: `horseshoe_plan.png` (top-down, and the panels in degrees from the eye against the comfort zone).

## Layout (eye at its real height, panels 2.0 m away on one curve around it)

| Panel | Holds | Yaw (centre) | Width | Height |
|---|---|---|---|---|
| Left: Song + ranks | cover, title, artist, favourite star, characteristic dropdown, difficulty buttons, stats pills, "Slash to play · Normal", then the ranking rows (grade, name, score) | -42° | 420 px = 28° | 640 px = 41° |
| Centre: Song list | Search, Filters, sort, Get songs, Player, Settings, the list | 0° | 745 px = 50° | 640 px = 41° |
| Right: Modifiers | every modifier chip with icon and word, Speed, Fail, Damage (only with Health), Environment, More modifiers' options, Reset, "Score x1.08" | +42° | 420 px = 28° | 640 px = 41° |

On a 2 m curve one panel px (2.4/1024 m) is 0.067°: the theme's 28 px text is 1.88° (over the 1.85° minimum) and a
48 px chip 3.2° (over 3°), the same at every point of a curved panel. Today's flat panel is 74° x 54° and its edge
text is 18% smaller (1.88° to 1.55°).

## Curved or flat-angled panels

| | Curved (a slice of a cylinder around the eye) | Flat, each turned to face the eye |
|---|---|---|
| Text size across a panel | the same everywhere | centre 50° panel: edges 9% smaller; side panels 3% |
| Pointer | ray against the cylinder: solve the ray's distance to the axis = R, then u = arc angle x R / width, v = height; collision stays a box, the exact spot is computed | unchanged (the canvas's flat quad) |
| GPU | the same pixels drawn; 32 columns of quads per panel instead of one (about 200 vertices), nothing measurable | today's cost |
| Work | a curved canvas (mesh + pointer maths + a test) used by all three | move and turn canvases |

Recommended: curved, one curve for all three, so it reads as one wall with gaps.

## Where the rest goes
- Declutter items: 1 (modifiers out) is the right panel; 2 (Damage only with Health), 3 (favourite star), 4 (short
  Slash to play line) and 5 (characteristic dropdown) all fold in.
- Settings, Profiles ("Who's playing?") and the Download page open in the centre panel's place as now; the Download
  page's details could move to the left panel later (same pattern).
- The slash note (61° right, 23.5° down) would sit just past the modifiers panel's edge (56°): sabers pointing at
  modifiers would swing through it. It needs a new spot (question 2).
- The warning icon moves to the centre panel's top right corner.

## Rules check
- vr-ui-design: centre within ±25°; side panels 28°-56°, past the ±30° reading zone but within the 55° turn for
  occasional tasks (modifiers, ranks) except their outer 1°; height 41° is past +20°/-12° (question 1).
- Text >= 1.85° and targets >= 3° everywhere on the curve (28 px text, 48 px chips; today's 22-24 px chips grow).
- AGENTS.md: nothing duplicated (modifiers move, the summary line isn't needed with the panel in view); Play stays the
  one primary action; no new colour (selected chips UI_ACCENT; check muted and level-coloured text on a selected chip
  for 3:1 contrast while building); the 3D text stays Roboto Medium.

## Order of work
1. Curved canvas: mesh, pointer maths, a test (the hit lands on the right control at the panel's edges).
2. Modifiers into their own panel (ModifierChips moves with them), on the right.
3. Song details and ranks into the left panel (the Highscores panel joins it).
4. Centre: the list and its top bar, narrowed to 745 px.
5. Slash note and warning icon moved; layout test and ui_angles re-run; headset check.

## Questions
1. Height: 41° keeps about 7 song rows; the comfort zone (+20°/-12°, 32°) fits about 5. Which?
2. Slash note: below the centre panel, or past the modifiers panel (about 65°)?
3. Ranks on the left at 28°-56° are outside the ±30° reading zone (the earlier audit wanted them inside). OK as a
   glance-only panel?
4. Curved for all three panels, or curved centre and flat sides?
