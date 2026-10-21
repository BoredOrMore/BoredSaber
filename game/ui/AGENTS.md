# Menu UI

2D Godot `Control` panels rendered into VR, plus the few 3D menu pieces. Read the root `AGENTS.md` first.

All text here is player-facing: follow "Player-facing wording and UX" in the root `AGENTS.md` (no
developer terms like NJS/NPS/RT in labels, named choices with a default, ask or propose options when
the plain wording isn't obvious).

Design and review UI with the repo skills `.claude/skills/vr-ui-design/SKILL.md` and
`.claude/skills/vr-ui-review/SKILL.md` (placement in 3D, shared canvases across game states, feedback, dead ends).

## File map

- `menu_theme.tres`: the one shared `Theme` (Roboto-Medium 28 px, dark surfaces, accent borders, `toggle_on/off.svg`
  pills for `CheckButton`). Every panel `.tscn` sets `theme = ExtResource(...)` on its root. The one main
  button of a screen sets `theme_type_variation = &"PrimaryButton"` (accent border, blue fill); 3D
  `UIRaycastButton`s use `set_primary(true)`.
- `BeatSaverPanel/`: browse/search/download maps from beatsaver.com (class `BeatSaverPanel`).
  The menu's "Get more songs" opens it directly (`BeepSaber_Game._open_beatsaver`), in front of the player in place
  of the song menu. (BeatSage, YouTube search and a BeatSaver/BeatSage picker were removed: nothing could reach them.)
- `UI_AudioEngine/`: autoload; `attach_children(node)` wires hover/click sounds to every `Button` below `node`.
- In `game/`: `BeepSaberMainMenu.gd/.tscn` (class `MainMenu`: song list, Song/More tabs and a Settings gear above the right column; the Song tab holds
  difficulty and the modifier chips, rarer ones behind "More modifiers"),
  `settings_Panel.gd/.tscn` (class `SettingsPanel`, tabs Gameplay/Visuals/Audio/Advanced), `HighscorePanel`,
  `Pause_Panel` (signals `continue_button`/`restart_button`/`mainmenu_button`), `EndScore` (3D `MeshInstance3D`, not a
  canvas), `vr_slider.gd` (thumbstick/drag scrolling), `UI_Panel.gdshader` (rounded 3D panel used by `EndScore.tscn`
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

`vr_slider.gd` targets an `ItemList` or `ScrollContainer` via `scroll_node_path`. Pointer over list + trigger held =
drag scroll; otherwise thumbstick (stronger of both hands) with threshold, speed lerp and hold acceleration consts at
the top. `scroll_without_pointer = true` scrolls even when not hovered; only the main song list uses it
(`BeepSaberMainMenu.tscn:380-385`). BeatSaver loads the next page past 90% scroll (`BeatSaverPanel.gd:447-465`).

## BeatSaver HTTP flow

- `update_list(req)` (`BeatSaverPanel.gd:165`) cancels in-flight requests and calls `/api/maps/<list>/<page>`,
  `/api/search/text/<page>?...` (also used when NPS/length filters are on, `_filter_query()` :109) or
  `/api/maps/uploader/<id>/<page>`. `back_stack` keeps up to `MAX_BACK_STACK_DEPTH` previous requests.
- Response (`_on_HTTPRequest_request_completed` :214): requires `result == 0`, JSON `Dictionary`, `docs` `Array`, and
  skips non-`Dictionary` docs. Fields go through `Utils.get_str/get_float/get_array/get_dict` with defaults
  (`BeatSaverSongInfo._init` :14-23). `response_code` is not checked.
- Known gaps (report, don't silently patch in unrelated work): `versions[0]["hash"]` is indexed without checking
  `versions` is non-empty (:234-235, :301); covers then load sequentially (`update_next_cover` :408).
- Download (:312): rejects HTML bodies, writes zip to `APPDATA_PATH/temp`, unzips to `Songs/<hash>/`, then
  `main_menu_ref._on_LoadPlaylists_Button_pressed()` refreshes the list. New boundary code must validate like
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
