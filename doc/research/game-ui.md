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
