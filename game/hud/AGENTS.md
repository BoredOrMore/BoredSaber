# game/hud/ — in-song HUD

What the player reads mid-song: score, combo and multiplier, accuracy and live grade, time, health, and the points
that pop up at each cut. Read the root `AGENTS.md` first. Design and review HUD changes with
`.claude/skills/vr-ui-design/SKILL.md` and `.claude/skills/vr-ui-review/SKILL.md`; the HUD follows Beat Saber's
arrangement (owner, 2026-10-27).

## Entry points and flow

- `game/BeepSaber_Game.gd` `_ready` makes `Hud.new(point_label, multiplier_label, percent_indicator)` and adds it; the
  three nodes stay in `BeepSaber_Game.tscn` (`Point_Label`, `Multiplier_Label` with `ComboHud.gd`,
  `Percent_Indicator`) because game states and other scripts find them by path.
- Each map start calls `hud.place(_eye())` (the lane width changes with the Wide modifiers), then `_display_points()`.
- `Scoreboard.score_changed` → `BeepSaber_Game._display_points()` → `hud.show_points(points, played, length,
  accuracy)`. `_physics_process` emits `score_changed` once a second so the clock ticks.
- Visibility: game states (`game/scripts/GameState/*.gd`) show and hide `Point_Label`; the two panels follow it.
  A fail calls `hud.fade_out(FAIL_WORD_DELAY)` and `health_rails.fade_out(FAIL_WORD_DELAY)`
  (`BeepSaber_Game._fail_song`): both panels and the energy strips fade and hide before FAILED shows (owner, 2026-10-29).
- `Scoreboard.points_awarded` → `PointsLabelDriver.show_points` (cut numbers and misses at the note).
- Health: `BeepSaber_Game.tscn` node with `HealthRails.gd`; the game calls `start_map` and updates it on damage.
- 90/360 maps: the HUD is one far cluster like Beat Saber's 360 HUD (owner, 2026-10-29; `Hud.far`, `far_cluster`):
  `FAR_DISTANCE` 15 m out over the lane, its lowest line `FAR_MARGIN_DEG` over the map's highest note top
  (`notes_top`) seen from there, worked out at song start from the real eye. Combo left, score centre, multiplier
  ring right, energy bar (`show_health`; the `HealthRails` strips are hidden there) and time under the score; accuracy
  and grade move to Pause (`GameStatePaused`) and the score screen. `ComboHud.calm`: no shake, pops or shockwaves.
  Drawn over walls (`FAR_RENDER_PRIORITY`, alpha) while notes in front still hide it. `EventDriver.track_turned`
  turns it (`Hud.turn`) about the player's standing point with the track (`TrackDeck.turned`).
- Owner exception (Bored, 2026-10-29), the far 90/360 HUD only: text at Beat Saber's sizes (`FAR_SCORE_DEG` 1.1,
  `FAR_COMBO_DEG` 1.4, `FAR_SMALL_DEG` 1.2 degrees), below the 1.85 degree minimum everywhere else.

## File map

- `Hud.gd` (class `Hud`): the two flat panels left and right of the lanes, each turned to face `HUD_EYE`; layout
  constants (`HUD_*`: letters' height in metres in `.z`, position on the panel in `.x/.y`); makes the caption,
  accuracy, grade and time labels as copies of the score's `TextMesh`; numbers in `NUMBER_FONT` (Kanit SemiBold
  Italic, owner 2026-10-28); `_grouped` puts commas in every score and count ("236,336"); `show_points` formats score,
  time as played / length, the percent "%.1f%%" from `Scoreboard.song_progress()` (points over the whole song's best,
  climbing from 0%; owner 2026-10-30), grade from the accuracy via `EndScore.grade` in `Constants.RANK_COLORS`.
  Practice (`Map.practice`, `_set_practice`): the accuracy alone, as "%.1f%%" at the score's place and size (owner's
  choice 3A, 2026-10-30; a part, so the accuracy and not the climbing percent); score, combo, ring, grade, caption,
  time and the far energy bar hidden.
- `ComboHud.gd` (class `ComboHud`, on `Multiplier_Label`): combo count, the multiplier ring (`ring`, reparented onto
  the right panel by `Hud`), raise flash, broken-combo shake and tint, `milestone_reached` (50, then every 100).
  `rest_at(at)` sets where the shake returns; `set_multiplier_height(h)` sizes the multiplier in the ring.
- `MultiplierRing.gdshader`: the ring's segments (one per hit the next multiplier needs) and its flash.
- `PercentIndicator.gd/.tscn` (class `PercentIndicator`) + `PercentIndicator.gdshader`: the old accuracy ring.
  Hidden in play (`Hud` sets it invisible) but still fed; `EndScore.tscn` and `SpectatorWindow.tscn` use it visibly.
- `Points_label_driver.gd/.tscn` (class `PointsLabelDriver`): pools and places `points_label.tscn` instances.
- `points_label.gd/.tscn` (class `PointsLabel`): one popped cut number (`Hud.NUMBER_FONT`) or MISS (the live grade's
  font, `Hud.GRADE_FONT`, Kanit Black Italic; every digit and letter checked to tessellate cleanly at 100 px).
- `ResultMoment.gd` (class `ResultMoment`, made in `BeepSaber_Game._ready`): the end of a song. On a fail a big "FAILED"
  `WORD_DISTANCE` ahead of the real eye in the grade font, drawn over the nearer HUD (`WORD_PRIORITY`, no depth test), white-hot with a danger-colour glow (Label3D outline layers,
  as the HUD grade's) and a faint mirror image in the deck; on a fail or a clear a `FADE_SECONDS` fade to black (a quad
  on the XR camera, no post-processing) and back up on the score screen. `stage_capture --failed-word 1`.
- `HealthRails.gd` (class `HealthRails`) + `HealthRail.gdshader`: health as two strips beside the track (bar mode
  shortens them, 4 Lives splits them into pips); `HealthRails.EDGE_PAD` must match `edge_pad` in the shader. `start_map(lives, how_full, eye)` places them from the
  player's eye: they start `RAIL_NEAR_DEGREES` (22°) below it and widen with that distance.

## Invariants and gotchas

- Fades go through each material's own opacity (`albedo_color.a`, the ring's `fade`, `Label3D.modulate`):
  `GeometryInstance3D.transparency` is ignored by the Compatibility renderer. `Hud.fade_out` handles text materials,
  the multiplier ring's shader and 3D labels; anything else new on a panel needs a case there (it reports it).

- `TextMesh.font_size` is capped at 127: sizes go through `pixel_size` (`Hud._set_letters`, font 100 px).
- The panels are placed from the player's real eye (the headset's place at a song's start, `BeepSaber_Game._eye`):
  `HUD_DISTANCE` (5.8 m) from it at `HUD_YAW` (19°) and `HUD_PITCH`, turned further out to clear the outer lane on
  the Wide modifiers, facing it and grown by `HUD_DISTANCE / HUD_LAID_OUT_DISTANCE` so the lines keep their size in
  view (owner, 2026-10-27: everything the player looks at is worked out from their own eye). Past vr-ui-design's
  3.5 m for text on purpose (little refocus from the notes). New lines go on a panel.
- Size order is the hierarchy: combo and multiplier > grade > score > accuracy, time, caption (muted).
- HUD materials are unshaded and fog-free; nothing on the HUD may outshine notes (root `AGENTS.md`, Light).
- Feedback stays moderate (`ComboHud.gd` header): no busy motion at the edge of view.
- Don't rename `Point_Label`, `Multiplier_Label` or `Percent_Indicator` without updating every `$` path to them.

## Where to change X

- Position, size or order of a HUD line: the `HUD_*` constants in `Hud.gd`.
- What a line shows or its format: `Hud.show_points`.
- Combo feel (flash, shake, milestones): `ComboHud.gd` constants; the ring's look: `MultiplierRing.gdshader`.
- Cut numbers: `points_label.gd`; which cuts show them: `Scoreboard.points_awarded` callers.
- Health display: `HealthRails.gd` constants.

## Checking a change

- `godot --headless --path . --import`, then the tests in `tests/` (`test_menu_layout` has 2 pointer-drag checks
  that fail only on macOS).
- Look at it on the headset in play (Wide 200% too, for placement); CI builds the APK.
