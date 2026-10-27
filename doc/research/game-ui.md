# Game UI: research for moving beyond app-style panels

Collected 2026-10-20 after the player asked whether the UI is "app-based" (it is: every menu is a 2D Godot
screen on a flat floating panel, pressed with a saber used as a pointer) and asked for more research on game UI.
`.claude/skills/vr-ui-design` covers app-style rules (Apple visionOS, Meta Horizon); this note covers how games
place UI in their world.

## Vocabulary: four kinds of game UI

Fagerholt and Lorentzon ("Beyond the HUD", Chalmers master's thesis, 2009) sort each UI element by two questions:
is it part of the game's world (space), and is it part of its fiction (story)?

| | In the world's space | Not in the world's space |
|---|---|---|
| **In the fiction** | Diegetic: a watch on the wrist, a poster you shoot | Meta: red blur at the screen's edge when hurt |
| **Not in the fiction** | Spatial: a floating arrow over a target, a label next to an object | Non-diegetic: a HUD or menu panel |

BoredSaber today: menus, settings, BeatSaver page, highscores and keyboard are non-diegetic panels; the score
under the track, points that pop up at cuts and the combo display are spatial; the music dipping while the
head is in a wall is meta.

## What the evidence says

- A study of VR first-person games reports Diegetic and Spatial interfaces as the most immersive, Meta and
  Non-diegetic as the least (paper hosted by Universidade da Beira Interior).
- Controlled studies are small and mixed:
  - Saling et al. (ICAT-EGVE 2021): players preferred a diegetic GUI, but not significantly.
  - Dickinson et al. (2021, N = 58, VR training): no higher presence with the diegetic interface, possibly
    because it took more effort to use.
  - Köhle et al. (INTERACT 2021, N = 37): an overlay health bar, a wristwatch and a body-movement display were
    rated equal for presence; each had its own strengths.
  - Questionnaires inside the VR scene (VRST 2020): higher presence and user experience with N = 11 experts,
    no effect on presence in a follow-up with N = 24.
  - A DCU usability study (N = 15): players moved from preferring non-diegetic to diegetic UI as they got
    more familiar with the game.
- Summary: diegetic UI is often liked and sometimes feels more immersive, but it does not reliably raise
  presence or usability, and it can cost effort. Use it where the action is simple and repeated; keep
  panels where the player reads, compares or types.

## What VR rhythm games do

- **Beat Saber:** flat menu panels in its environment, pointed at with the sabers. A fan-made minimalist menu
  replaced them with a frozen map in front of the player: cut a block to start. Its author found that new
  players can't see the controller buttons, often get lost after changing a setting by accident, and some
  never manage to read menu text. Cutting needs no buttons and teaches the core move (cut firmly, in the
  arrow's direction).
- **Pistol Whip:** scene selection began as a text list and the developers found it didn't work; it became
  a wall of movie posters, and the player shoots a poster to start that scene. Its later update reworked
  the in-game numbers onto plaques for readability.
- **Synth Riders:** reviewers praise a clean, easy song and stage selection with plenty of previews.
- **Supernatural:** browsing by curated rows (carousels such as "Trending") and filters; its team builds both
  2D and 3D interfaces placed inside the environments.

## Game UI principles (beyond VR)

The VR rules (placement, angles, sizes, weights) are in `.claude/skills/vr-ui-design/`; these are the general game
UX frameworks, for designing and reviewing (`.claude/skills/vr-ui-review/` turns the checkable ones into items).

- **Usability and engage-ability** (Celia Hodent, *The Gamer's Brain*, 2017; UX at Epic, Ubisoft, LucasArts): game
  UX is two questions, can the player use and understand it (usability), and do they want to keep playing
  (engage-ability: motivation, emotion, flow). The book turns both into a checklist (chapters 11 and 12; not
  summarised here from the book itself).
- **Playability heuristics** (Desurvire et al., HEP, CHI 2004: 43 items in game play, story, mechanics and
  usability; refined into PLAY, 2009, rated by 54 players against high- and low-scoring Metacritic games): for an
  expert review of a build. Later work notes the lists are long and need a reviewer who knows them.
- **General interface rules** that hold in games (Shneiderman's eight golden rules, Nielsen's heuristics):
  feedback for every action, one word and one behaviour per thing everywhere, prevent mistakes and let them be
  undone, recognition over recall (show what is set; don't make the player remember it).
- **HUD by urgency** (game UI guides): what the player needs this second is always shown, high in contrast and
  never moving; secondary information smaller and quieter; the rest off the HUD. The in-song HUD follows it
  (owner, 2026-10-27): combo and multiplier, then grade and score, then accuracy, time and captions.
- **Accessibility** (Game Accessibility Guidelines, basic tier; WCAG for the numbers): readable text by default;
  text against its background at least 4.5:1 (3:1 for large text, 24 px and up, which is all of our menu text at
  28 px), or an outline or shadow over a busy background; never colour alone (the notes have arrows; menus and
  the score screen must name or mark what colour shows); no more than three flashes a second (done:
  `EventDriver.MAX_FLASHES_PER_SECOND`).

### Contrast of our UI colours (2026-10-27)

WCAG ratios of the theme's colours (`game/Constants.gd` `UI_*`, `DIFFICULTY_COLORS`; `menu_theme.tres`), computed
from the sRGB values. Panel 0.086/0.094/0.114, surface (buttons) 0.133/0.149/0.18, selected (pressed chip, selected
row, main button) 0.2/0.36/0.45.

| Text | on panel | on surface | on selected |
|---|---|---|---|
| `UI_TEXT` | 14.2 | 12.2 | 5.8 |
| `UI_TEXT_MUTED` | 6.8 | 5.8 | **2.8** |
| `UI_ACCENT` | 9.2 | 7.9 | 3.7 |
| `UI_DANGER` | 6.7 | 5.7 | **2.7** |
| Easy | 6.6 | 5.7 | **2.7** |
| Normal | 7.6 | 6.5 | 3.1 |
| Hard | 8.7 | 7.4 | 3.5 |
| Expert | 4.7 | 4.0 | **1.9** |
| Expert+ | 3.8 | 3.3 | **1.5** |
| Expert+ now (0.74, 0.5, 0.86) | 6.1 | 5.2 | - |

Below 3:1 (bold) fails even the large-text rule: the picked difficulty's name on its selected button, and muted or
danger text on a selected chip or row. Expert+ is low everywhere. Fixed (owner, 2026-10-27): the picked
level's name is `UI_TEXT` and its border carries the difficulty colour (`BeepSaberMainMenu._set_picked_border`);
Expert+ is lighter. Muted and danger text on a selected chip or row remain to check where they occur.

## Takeaways for BoredSaber

1. Keep panels for browsing, settings, search and typing: lots of text and choices, and the studies show no
   usability gain from making these diegetic.
2. Make the game's own actions diegetic: the moments the player does again and again (start a song, retry,
   continue) can use the game's verb, a block to cut, instead of a button to point at.
3. Make the song choice visual: covers large enough to read as posters, as Pistol Whip learned from its list.
4. Make panels belong to the place: mounted on the environment's structure and lit like it (AGENTS.md "Light",
   rule 5), rather than floating windows.
5. Measure: a change to UI kind is a change to feel; playtest it on the headset ("Changes to feel need a
   playtest", root AGENTS.md).

## Sources

- Fagerholt, E. and Lorentzon, M., Beyond the HUD (Chalmers, 2009), summarised in https://www.gamedeveloper.com/design/user-interface-design-in-video-games
- VR first-person game interfaces: https://ubibliorum.ubi.pt/bitstreams/f16e2c04-714e-4de3-b17f-fa3e15495bfc/download
- Saling et al., Diegetic vs. Non-Diegetic GUIs: What do Virtual Reality Players Prefer? (ICAT-EGVE 2021): https://diglib.eg.org/handle/10.2312/egve20211333
- Dickinson et al., Diegetic Tool Management in a Virtual Reality Training Simulation (2021): https://pure.hud.ac.uk/en/publications/diegetic-tool-management-in-a-virtual-reality-training-simulation/
- Köhle et al. (INTERACT 2021): https://www.medien.ifi.lmu.de/pubdb/publications/pub/koehle2021interact/koehle2021interact.pdf
- In-VR questionnaires (VRST 2020): https://hci.uni-bremen.de/wp-content/uploads/2020/11/vrst20-33.pdf
- Minimalist Beat Saber menu: https://www.codementor.io/@vynloverdrive/why-i-built-a-minimalist-beat-saber-menu-2pgyahfw60
- Pistol Whip scene posters: https://blog.playstation.com/2020/07/30/become-an-unstoppable-action-hero-in-pistol-whip-out-now-on-ps-vr/
- Pistol Whip interface update: https://mixed-news.com/en/pistol-whip-holiday-update-brings-many-improvements/
- Synth Riders review: https://www.newskillgaming.com/en/blog/reviews-video-games/synth-riders-review-a-worthy-rival-for-beat-saber-in-vr
- Supernatural 3.0 browsing: https://www.vrfitnessinsider.com/supernatural-vr-fitness-app-update-focuses-on-individuality-and-efficiency/
- Supernatural UI engineering (job listing): https://metacareers.com/jobs/1306149284146253
- Hodent, C., The Gamer's Brain (CRC Press, 2017): https://www.routledge.com/9781498775502
- Desurvire, Caplan and Toth, Using Heuristics to Evaluate the Playability of Games (CHI 2004): https://hci.rwth-aachen.de/materials/conferences/CHI2004/2p1509.pdf
- Desurvire and Wiberg, Game Usability Heuristics (PLAY) (2009): https://link.springer.com/doi/10.1007/978-3-642-02774-1_60
- Shneiderman, The Eight Golden Rules of Interface Design: https://www.cs.umd.edu/~ben/goldenrules.html
- Game Accessibility Guidelines, basic: https://gameaccessibilityguidelines.com/basic/
- HUD information by urgency: https://pixune.com/blog/game-ui-design/
