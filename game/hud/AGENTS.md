# game/hud/ — in-song HUD

What the player reads mid-song: score, combo and multiplier, accuracy and live grade, time, health, and the points
that pop up at each cut. Read the root `AGENTS.md` first. Design and review HUD changes with
`.claude/skills/vr-ui-design/SKILL.md` and `.claude/skills/vr-ui-review/SKILL.md`; the HUD follows Beat Saber's
arrangement (owner, 2026-10-27).

## Entry points and flow

- `game/BeepSaber_Game.gd` `_ready` makes `Hud.new(point_label, multiplier_label, percent_indicator)` and adds it; the
  three nodes stay in `BeepSaber_Game.tscn` (`Point_Label`, `Multiplier_Label` with `ComboHud.gd`,
  `Percent_Indicator`) because game states and other scripts find them by path.
- Each map start calls `hud.place()` (the lane width changes with the Wide modifiers), then `_display_points()`.
- `Scoreboard.score_changed` → `BeepSaber_Game._display_points()` → `hud.show_points(points, played, length,
  accuracy)`. `_physics_process` emits `score_changed` once a second so the clock ticks.
- Visibility: game states (`game/scripts/GameState/*.gd`) show and hide `Point_Label`; the two panels follow it.
- `Scoreboard.points_awarded` → `PointsLabelDriver.show_points` (cut numbers and misses at the note).
- Health: `BeepSaber_Game.tscn` node with `HealthRails.gd`; the game calls `start_map` and updates it on damage.

## File map

- `Hud.gd` (class `Hud`): the two flat panels left and right of the lanes, each turned to face `HUD_EYE`; layout
  constants (`HUD_*`: letters' height in metres in `.z`, position on the panel in `.x/.y`); makes the caption,
  accuracy, grade and time labels as copies of the score's `TextMesh`; `show_points` formats score as "236 336",
  time as played / length, accuracy "%.1f%%", grade via `EndScore.grade` in `Constants.RANK_COLORS`.
- `ComboHud.gd` (class `ComboHud`, on `Multiplier_Label`): combo count, the multiplier ring (`ring`, reparented onto
  the right panel by `Hud`), raise flash, broken-combo shake and tint, `milestone_reached` (50, then every 100).
  `rest_at(at)` sets where the shake returns; `set_multiplier_height(h)` sizes the multiplier in the ring.
- `MultiplierRing.gdshader`: the ring's segments (one per hit the next multiplier needs) and its flash.
- `PercentIndicator.gd/.tscn` (class `PercentIndicator`) + `PercentIndicator.gdshader`: the old accuracy ring.
  Hidden in play (`Hud` sets it invisible) but still fed; `EndScore.tscn` and `SpectatorWindow.tscn` use it visibly.
- `Points_label_driver.gd/.tscn` (class `PointsLabelDriver`): pools and places `points_label.tscn` instances.
- `points_label.gd/.tscn`: one popped number or miss mark; `MissMark.gdshader` draws the miss X from a distance field.
- `HealthRails.gd` (class `HealthRails`) + `HealthRail.gdshader`: health as two strips beside the track (bar mode
  shortens them, 4 Lives splits them into pips); `HealthRails.EDGE_PAD` must match `edge_pad` in the shader.

## Invariants and gotchas

- `TextMesh.font_size` is capped at 127: sizes go through `pixel_size` (`Hud._set_letters`, font 100 px).
- The panels sit 5.5 m from the eye, about 19° to the side (owner, 2026-10-27: a look down the track takes them in),
  past vr-ui-design's 3.5 m for text on purpose (little refocus from the notes); `Hud._facing_eye` grows them with their
  distance so the text keeps its size in view. New lines go on a panel, not as free nodes turned their own way.
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
