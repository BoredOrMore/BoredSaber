# Menu UI

2D Godot `Control` panels rendered into VR, plus the few 3D menu pieces. Read the root `AGENTS.md` first.

All text here is player-facing: follow "Player-facing wording and UX" in the root `AGENTS.md` (no
developer terms like NJS/NPS/RT in labels, named choices with a default, ask or propose options when
the plain wording isn't obvious).

Design and review UI with the repo skills `.claude/skills/vr-ui-design/SKILL.md` and
`.claude/skills/vr-ui-review/SKILL.md` (placement in 3D, shared canvases across game states, feedback, dead ends).

## File map

- `fonts/`: Roboto's variable font (`Roboto-Variable.ttf`, OFL, `OFL.txt`) as `roboto_semibold.tres` (600) and
  `roboto_bold.tres` (700) for 2D text only: TextMesh (3D text: HUD, `UIRaycastButton`, end-screen lines) can't draw a
  variable font's overlapping outlines (letters like "e" come out broken) and keeps `Roboto-Medium.ttf`.
  `Kanit-SemiBoldItalic.ttf` (weight 600, same OFL, from google/fonts): every number (`Hud.NUMBER_FONT`).
  `Kanit-BlackItalic.ttf` (OFL, `Kanit-OFL.txt`): the HUD's grade letter only (`game/hud/Hud.gd`), heavy and slanted;
  compared with Roboto Black and three other italics in `doc/research/grade_font_candidates.png`.
- `menu_theme.tres`: the one shared `Theme` (Roboto-Medium 28 px for text; buttons, chips, option buttons and tabs
  SemiBold, `PrimaryButton` and `TitleLabel` (panel titles) Bold (owner, 2026-10-27); dark surfaces, accent borders, `toggle_on/off.svg`
  pills for `CheckButton`). Every panel `.tscn` sets `theme = ExtResource(...)` on its root. The one main
  button of a screen sets `theme_type_variation = &"PrimaryButton"` (accent border, blue fill); 3D
  `UIRaycastButton`s use `set_primary(true)`.
- `SongList.gd` (class `SongList`): the song menu's list, a `ScrollContainer` of row buttons in the `ItemList` look with
  the ItemList calls the menu uses; every row 76 px with a 72 px cover, 82 px apart (the selected one only changes its background); empty space at both ends lets
  `center_on` glide any row to the middle (the thumbstick uses it); a pressed row stays under the pointer.
- `ProfilesPanel.gd/.tscn` (class `ProfilesPanel`): "Who's playing?", opened by the player button beside the menu's gear
  (`BeepSaber_Game._open_profiles`) on its own canvas 10 cm in front of the menu, which takes no pointer input meanwhile.
  Picks, adds (max `Settings.MAX_PLAYERS`), renames (records too, `Highscores.rename_player`) and deletes players;
  names are typed on the menu's keyboard (`Keyboard_highscore`), which the menu ignores while its `_keyboard_for` is empty.
- `BeatSaverPanel/`: browse/search/download maps from beatsaver.com (class `BeatSaverPanel`). Its song list is
  `BeatSaverList.gd` (class `BeatSaverList`): the song list's rows (72 px cover, "Artist - Title") with the level strip
  and length at the end, a fixed set of recycled rows, each with one cover texture written over in place, the 72 px
  covers kept as images; only the picked map's big cover is fetched (`DetailCoverDownload`)
  (doc/research/get-songs-list-plan.md). `FrameProbe.gd`: a probe node for its slow-frame log (where the frame's
  `_process` calls end).
- Templates (owner, 2026-10-28: build UI as templates, pages only swap content): `menu_panel.tres`, the menus'
  rounded panel frame (24 px corners, about 1.6 degrees at 2 m), the root style of the song menu's three panels
  (`MenuPanel.tscn`, a frame that takes no input), Settings, the Download page and "Who's playing?";
  `MenuSection.tscn` / `MenuSection.gd` (class `MenuSection`), a titled group of rows: rows `ROW_GAP` apart,
  sections `SECTION_GAP` apart (`section_list`), used by the modifier and More modifiers sections.
  Button kinds are `menu_theme.tres` type variations, so each look and its states (normal, hover, pressed,
  selected, disabled) and rounded corners live in one place; the hover sound is `UI_AudioEngine`'s for every
  button: `Button` (secondary), `PrimaryButton` (the page's main action: Done, Download), `ChipButton` (modifier
  and settings chips, Favorite, Reset, More modifiers; narrow padding, 48 px), `TabButton` (Modifiers/More; a
  chip), `DifficultyButton` (level and characteristic buttons; narrow padding, 22 px text),
  `BackButton` (Back and Close), `DestructiveButton` (every `ConfirmButton`; its words turn red on hover). Panel kinds:
  `StatPill` (a stat, fully rounded), `LevelBar` (a level's name in its colour).
  `ModifierChips.make_row_button` takes the kind.
- `EnvironmentCard.tscn` / `EnvironmentCard.gd` (class `EnvironmentCard`, kind `CardButton`): a button that is a
  picture, filling it (cover, rounded by the button, which clips it) with the name over a dark band; a ring while
  pointed at or picked. The Look section's Environment button (the pick's wide picture) opens `EnvironmentPanel`
  over the modifiers: Back and a card per environment, two to a row in four rows (`ENVIRONMENT_CARD_HEIGHT` 148 px
  since Henge made seven cards), nothing scrolling (`ModifierChips`).
- `StatPills.gd` (class `StatPills`): a difficulty's short stats as rounded icon pills (get ready, notes per second,
  swing flow, length, workout sets; the `StatPill` kind) in a centred flow; the song menu's stats under the
  difficulty and, as a table's header (one pill per column, with its unit), the Download page's details, whose
  levels sit in rounded `LevelBar`s with their numbers in columns under it.
  `LevelStrip.gd` draws a row's level strip (Easy..Expert+ slots, the player's level framed, "≈" while estimated)
  into one image, shared by every row with the same strip.
  The menu's "Get songs" opens it directly (`BeepSaber_Game._open_beatsaver`) in place of the song menu, laid out
  like it (owner, 2026-10-29, layout A): 1249x745 px at scale 2.4 on the menus' 2 m cylinder, turned 16.9° left so its
  details panel and list sit where the song menu's left and centre panels are; the right stays empty. Above the list:
  Search, Filters (opens `FiltersPanel` over the list: Style, Difficulty, Length, Genre), the sort and "My songs" in
  Get songs' place; under them a chip per filter on (its x takes it off), the search or the "More by" mapper. (BeatSage, YouTube search and a BeatSaver/BeatSage picker were removed: nothing could reach them.)
- `ModifierChips.gd` (class `ModifierChips`, made by the menu's `_ready`): the Song tab's fail and damage rows,
  on/off and Speed chips, More modifiers, environment picker and reset, in step with `Settings`; `changed()` names
  the modified ones. Its static `make_row_button` (a button of a given kind) is shared with the difficulty picker.
- `SongPreview.gd` (class `SongPreview`, on the menu's `song_prev` node): the song menu's preview player: fades between
  previews, plays from the preview's start to the song's end and loops, yields to the song itself. It reads and
  decodes the audio on a `WorkerThreadPool` task (`start_file` for a song on disk, `start` for BeatSaver's buffer)
  once the request stayed the newest for `START_DELAY_SECONDS` (0.25 s), on both song pages. The menu's
  `play_selected_preview`, `play_preview` and `stop_preview` (used by game states and BeatSaver) go through it.
- `IconButton.gd` (class `IconButton`): icon just left of a centred label. `ConfirmButton.gd` (extends it): for
  what can't be undone; first press asks in the button, a second within `CONFIRM_SECONDS` does it.
- `StepperSpinBox.gd` (class `StepperSpinBox`): number between big − and + buttons for the pointer; hold repeats.
- `RoundedQuad.gdshader`: a flat colour quad with round corners for UI in 3D (WarningIcon), cut by alpha scissor
  and alpha to coverage like the canvases, never blended.
- `WarningIcon.gd` (class `WarningIcon`, a `UIRaycastTarget`): red "!" just above the song menu centre panel's top
  right corner while something may hurt the player or headset; pointing at it opens the list of warnings on a card
  in the empty space above the song menu, growing upward, so it covers no other UI (owner, 2026-10-29).
- `MenuClock.gd` (class `MenuClock`, a `Label3D`): the time of day, 24-hour ("14:05", owner 2026-10-29), just above the
  centre panel's top left corner opposite the warning icon, shown with the song menu; `MenuClock.now_text()` also
  feeds the clock in the Pause panel's top left corner. Not in the HUD: there "time" is the song's.
- `UI_AudioEngine/` (`UI_AudioEngine.gd/.tscn`): autoload; `attach_children(node)` wires hover and press sounds to every `Button` below `node`:
  on/off for a toggle in no `ButtonGroup`, back for names in `BACK_BUTTON_NAMES`, click for the rest.
- `BeepSaberMainMenu.gd/.tscn` (class `MainMenu`: song list, Song/More tabs and a Settings gear above the right column; the Song tab holds
  difficulty and the modifier chips, rarer ones behind "More modifiers"),
  `settings_Panel.gd/.tscn` (class `SettingsPanel`, tabs Gameplay/Visuals/Audio/Advanced), `HighscorePanel.gd/.tscn`,
  `Pause_Panel.gd/.tscn` (signals `continue_button`/`restart_button`/`mainmenu_button`), `EndScore.gd/.tscn` (3D `MeshInstance3D`, not a
  canvas; `RankHalo.gdshader` glows round its result ring; a FAILED / SONG CLEARED banner under the song's name, and after a
  fail "Failed at M:SS of M:SS" in place of the ring; "Not you?" on the name card after a saved record opens "Who's playing?"
  in place of the score screen (hidden meanwhile) and moves the record to whoever is picked, who becomes the current
  player (`BeepSaber_Game._change_record_player`); `doc/research/score-screen-plan.md`), `vr_slider.gd` (thumbstick/drag scrolling), `UI_Panel.gdshader` (rounded 3D panel used by `EndScore.tscn`
  and `game/scripts/UIRaycast/UIRaycastButton.tscn`).

## Colour palette

`game/Constants.gd:97-105` holds `UI_PANEL`, `UI_SURFACE`, `UI_SURFACE_HOVER`, `UI_SURFACE_PRESSED`, `UI_BORDER`,
`UI_ACCENT`, `UI_TEXT`, `UI_TEXT_MUTED`. 3D pieces read them in code (`EndScore.gd:14-16`,
`UIRaycastButton.gd:38-50`); the theme repeats the same values as literals. Change a colour in both places
(comment at `Constants.gd:97`). Difficulty colours use `Constants.DIFFICULTY_COLORS` with `UI_TEXT` as fallback.

## How 2D UI reaches VR

- Each panel is a child of an `OQ_UI2DCanvas` instance in `game/BeepSaber_Game.tscn` (MainMenu, PauseMenu, Settings,
  MapSourceDialogs/*, Highscores). At runtime the canvas moves the `Control` into its `SubViewport` and
  textures a quad with it; size is `control.size * vr.UI_PIXELS_TO_METER`, so scale with the node `transform`.
- Canvases default to `update_only_on_input = true`: the viewport only redraws after pointer/key input. Code that
  changes visuals without input must ask for a redraw: `canvas._input_update()` (`BeatSaverPanel.gd:243-244`, 368-370,
  428-429).
- Game states show/hide canvases with `_show()`/`_hide()` (`game/scripts/GameState/*.gd`); those toggle SubViewport
  updates. The panel-level `_show/_hide` in `BeatSaverPanel.gd` calls the canvas's plain `show()/hide()` instead, so the viewport keeps
  its update mode. Don't copy that pattern into new panels; call the canvas `_show/_hide`.
- Main-scene `.gd` code reaches panels through typed `@onready` canvas refs (`BeepSaber_Game.gd:29-48`). Inside a
  canvas, `$Path` from outside fails after reparenting; use `find_child` or exported `NodePath`s set in the scene.

## Pointer input

- `game/scripts/UIRaycast/UIRaycast.gd`: one per saber; `RayCast3D` against areas on mask `524290` (includes
  `CollisionLayerConstants.Ui_mask`, the canvas `UIArea` layer 2). Calls `ui_raycast_hit_event(pos, trigger_just_pressed,
  trigger_just_released)` on any `UIRaycastTarget`, and `ui_raycast_exit()` when leaving.
- Only one hand's ray is active: `left_handed` setting picks it (`BeepSaber_Game.gd:369-375`). States toggle
  `left/right_ui_raycast.visible`.
- The canvas `UIArea` (`OQ_Toolkit/OQ_UI2D/scripts/helper_UIArea.gd`) converts the hit into `InputEventMouseButton` /
  `InputEventMouseMotion` pushed into the SubViewport, so normal `Button.pressed`, hover styles and
  `mouse_entered` work. Collision is off while the canvas is hidden (`OQ_UI2DCanvas.gd:107-111`).
- Text entry uses the in-world `OQ_UI2DKeyboard` (`Keyboard_online_search`, `Keyboard_highscore`), connected via
  `text_input_enter`/`text_input_cancel` (`BeatSaverPanel.gd:83-85`, `BeepSaberMainMenu.gd:461-467`).

## Scrolling

`vr_slider.gd` targets an `ItemList` or `ScrollContainer` via `scroll_node_path`. Pointer drag (either hand): the list
follows the pointer 1:1 once it moves `DRAG_THRESHOLD` (12 px) from the press, a shorter move stays a click, a drag
never clicks what it started on (a release far away cancels the press), and a flick coasts `MOMENTUM_SECONDS`. An
`ItemList` still selects on press, so the BeatSaver list picks the row a drag starts on. Otherwise thumbstick
(stronger of both hands) with threshold, speed lerp and hold acceleration consts at
the top. `scroll_without_pointer = true` scrolls even when not hovered. The song list sets `joystick_scroll = false`:
there the thumbstick moves the selection instead (`MainMenu._step_with_stick`, centred by `SongList.center_on`;
each step ticks that hand's controller, `STICK_TICK_*`).
Above the list one row holds Search (icon), Filters (opens `FiltersPanel` over the list), the sort and Get songs. BeatSaver loads the next page past 90% scroll (`BeatSaverPanel.gd:447-465`).

## BeatSaver HTTP flow

- `update_list(req)` (`BeatSaverPanel.gd:165`) cancels in-flight requests and calls `/api/maps/<list>/<page>`,
  `/api/search/text/<page>?...` (also used when NPS/length filters are on, `_filter_query()` :109) or
  `/api/maps/uploader/<id>/<page>`. `back_stack` keeps up to `MAX_BACK_STACK_DEPTH` previous requests.
- Response (`_on_HTTPRequest_request_completed` :214): requires `result == 0`, JSON `Dictionary`, `docs` `Array`, and
  skips non-`Dictionary` docs. Fields go through `Utils.get_str/get_float/get_array/get_dict` with defaults
  (`BeatSaverSongInfo._init` :14-23). `response_code` is not checked.
- While the page is open the stage goes quiet (`BeepSaber_Game.BEATSAVER_QUIET`: no beams, dust, scenery detail or
  floor reflection, via `DebugView` bits) and its canvas redraws at most 36 times a second
  (`max_updates_per_second`): dragging it had run the GPU past the frame (10-14 ms of 13.9).
- Covers: downloaded one after another (`update_next_cover`), the next starting as each arrives; each is decoded and
  sized to 72 px on a `WorkerThreadPool` task (`_make_cover`); finished covers go onto the list together every
  `COVER_FLUSH_SECONDS` with one page redraw (`_flush_covers`), and only the 72 px result is uploaded on the main
  thread; `_cover_list` drops covers finished for an older list. The picked map's cover is fetched again at
  `DETAIL_COVER` px (`_on_detail_cover_completed`) into the details' one texture.
- Known gaps (report, don't silently patch in unrelated work): `versions[0]["hash"]` is indexed without checking
  `versions` is non-empty (:234-235, :301).
- Download (:312): rejects HTML bodies; a `WorkerThreadPool` task (`_save_song`, awaited a frame at a time) writes
  the zip to `APPDATA_PATH/temp` and unpacks it to `Songs/<hash>/`; once the queue is empty
  `main_menu_ref.add_downloaded_songs` reads just those folders' info on another task and adds them to the list (no
  rescan of the library). Only the list's sort and rows are built on the main thread. New boundary code must validate like
  the root rules say.

## Layout conventions

- Build with containers (`MarginContainer` > `VBoxContainer`/`HBoxContainer`/`GridContainer`), not absolute offsets.
  Theme separation: `BoxContainer` 12, `HBoxContainer` 16, `ItemList` h 16 / v 10; panels use 16 px margins
  (`BeepSaberMainMenu.tscn:208-211`); settings rows override `separation = 12`.
- Every state of one control (normal/hover/pressed/disabled) must use the same `content_margin_*`. A
  `CheckButton` once had 0 px idle vs 16 px hover margins and its label jumped under the pointer (commit `37ceb03`);
  `toggle_idle` and `list_hover` now both use 16/8. Same rule for `surface*` (20/12) and `tab_*` (28/12).
- Set colours in the theme, not per-node overrides, so panels stay consistent.

## Recipes

- **New setting row**: add the var + `default_values` entry in `game/Settings.gd`; add the control under the right
  `Tabs/<Tab>/VBox` in `settings_Panel.tscn` with a `toggled`/`value_changed` connection; add an `@onready` ref,
  load it in `set_controls_from_settings()` and a handler that assigns `Settings.<key>` (pattern:
  `settings_Panel.gd:210-211`). React elsewhere through `Settings.changed`.
- **New panel**: root `Panel` with `theme = menu_theme.tres`; call `UI_AudioEngine.attach_children(self)` in `_ready`;
  instance it under a new `OQ_UI2DCanvas` in `BeepSaber_Game.tscn`, add a typed `@onready` canvas ref, and show/hide
  it from every `GameState` script that should (each one hides the others explicitly).
- **New control in a panel**: put it in an existing container, rely on theme styles; a list that can overflow gets
  a `vr_slider.tscn` instance pointing at it.
- **Colour/style change**: edit `menu_theme.tres` and the matching `Constants.UI_*`.

## Testing

Run the root test command (`godot --headless --path . res://tests/test_map_info.tscn`); it does not cover UI. Check
layout in the editor or the desktop VR simulator (`Feature_VRSimulator` is added when `!vr.inVR`). Pointer, hover
margins, scrolling and keyboard focus need a headset run (root `AGENTS.md`), with `adb logcat` on errors.
