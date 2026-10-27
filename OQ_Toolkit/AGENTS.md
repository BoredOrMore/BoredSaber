# OQ_Toolkit (partial port)

Leftover pieces of the Oculus Quest Toolkit, ported to Godot 4 and kept only where the game still depends on them.
Read the root `AGENTS.md` first. Don't refactor or "modernise" this folder wholesale: many scenes and `.tscn` uids
in `game/` point into it, and the canvas behaviour below is tuned for Pico 4 performance.

## File map

- `vr_autoload.gd`: autoload `vr` (`project.godot` `[autoload]`). XR init, logging, controller refs.
- `OQ_UI2D/OQ_UI2DCanvas.tscn` + `scripts/OQ_UI2DCanvas.gd`: renders a child `Control` into a `SubViewport` on a quad.
  Scene has `SubViewport`, `UIArea` (`helper_UIArea.gd`, collision layer 2) and `update_once` (`update_viewport_once.gd`).
- `OQ_UI2D/OQ_UI2DKeyboard.tscn` + `scripts/OQ_UI2DKeyboard.gd`: two canvases, a `TextEdit` and the
  `controls/VirtualKeyboard` (buttons built in code, emits `InputEventKey` through `Input.parse_input_event`).
- `OQ_UI2D/OQ_UI2DLabel.tscn` + `scripts/OQ_UI2DLabel.gd`: text on a quad, auto-sized, redraws once per change.
- `OQ_UI2D/OQ_UI2DLogWindow.tscn`: shows the `vr` log ring buffer; mounted under `Settings_canvas`.
- `OQ_UI2D/theme/`: Roboto fonts (used by `game/ui/menu_theme.tres`, `BlackWhiteThem.tres`, `EndScore.tscn`, and
  served by `song_uploader.gd:93`), `oq_ui2d_standard.theme` (keyboard `TextEdit` only), `godot_splash_512.png`.
- `OQ_ARVROrigin/Feature_VRSimulator.tscn`: desktop keyboard/mouse stand-in, added when `!vr.inVR`
  (`game/BeepSaber_Game.gd:307-308`).

## What the game still uses

- `vr.initialize(origin, camera, left, right)` from `BeepSaber_Game.gd:289`: stores `vrOrigin/vrCamera/
  leftController/rightController`, picks the highest refresh rate, disables v-sync, sets `use_xr`, sets `inVR`, and
  applies `MixedReality` (`vr_autoload.gd:180-221`).
- Signal `pose_recentered` (re-emitted from OpenXR, `:177-178`), connected at `BeepSaber_Game.gd:296`.
- `vr.xr_interface` for `session_visible`/`session_stopping` pause hooks (`BeepSaber_Game.gd:298-300`).
- `vr.inVR`, `vr.leftController`/`vr.rightController` (typed `BeepSaberController`, read by `game/ui/vr_slider.gd`).
- Logging: `vr.log_info/log_warning/log_error/log_file_error` (dozens of call sites). Each writes to a 1024-entry
  ring buffer that collapses repeats, then prints.
- `vr.UI_PIXELS_TO_METER` (1/1024): canvas and label sizing.
- `OQ_UI2DCanvas` `_show()/_hide()/_input_update()`, `OQ_UI2DKeyboard` `_show()/_hide()`, signals
  `text_input_enter(text)`/`text_input_cancel()` and its `_text_edit`, `OQ_UI2DLabel` (`Pause_countdown`).

## Legacy / unused (no reference found outside this folder)

`vr_autoload.gd`: `get_current_player_height`, `load_json_file`, `set_dominant_controller_left`,
`is_dominant_controller_left`, `dominantController/nonDominantController`, `_need_settings_refresh`,
`_active_scene_path`, `toolkit_version`, `oq_base_dir`, `active_arvr_interface_name`. Scenes:
`OQ_UI2DNotificationWindow`, `OQ_Helpers/OQ_SplashScreen.tscn` (its script is used by `game/GodotSplash.tscn`, which
nothing instances either). Leave them unless a task removes them on purpose; report rather than delete in passing.
The Web branch (`vr_autoload.gd:189-193`) loads `res://game/scripts/webxr/webxr_initializer.tscn`.

## Invariants and gotchas

- Hidden canvases must not render: `_hide()` sets `render_target_update_mode = UPDATE_DISABLED` then hides
  (`OQ_UI2DCanvas.gd:51-53`); `_show()` restores it (`:55-61`). Plain `hide()/show()` skips this; use the underscore
  versions. Collision follows visibility every frame (`:107-111`) so the ray can't hit hidden UI.
- `update_only_on_input` (default `true` in the scene) redraws only for 3 frames after input via
  `UpdateViewport.update_once` (`update_viewport_once.gd`). Anything animating without input must call
  `_input_update()` or set `UPDATE_ONCE` itself, or the texture freezes.
- The canvas reparents its first `Control` child into the `SubViewport` at `_ready` (`OQ_UI2DCanvas.gd:80-83`):
  `$Canvas/Panel` paths break, use `find_child` (as `OQ_UI2DKeyboard.gd:16-19` does) or exported refs.
- `helper_UIArea.gd` assumes the unscaled area is the unit square `[-0.5, 0.5]` (`:12-17`); size the canvas through
  the control size or node scale, never by editing the area or mesh.
- Keyboard `TextEdit` keeps `virtual_keyboard_enabled = false` (`OQ_UI2DKeyboard.tscn:23`); otherwise focusing it
  opens the Pico system IME over the game. Any new `LineEdit`/`TextEdit` in the game needs the same.
- `VirtualKeyboard.gd:79-85` ignores a repeated `button_down` without `button_up` (double-press workaround). Keep it.
- Canvas `transparency` export defaults to `TRANSPARENCY_DISABLED`; enabling it is slower (`OQ_UI2DCanvas.gd:66-67`).
- `vr_autoload.gd` calls game code (`MixedReality`, `BeepSaberController`, `Settings`), so it is not standalone.

## Where to change X

- XR start-up, refresh rate, recenter: `vr_autoload.gd` `initialize`. OpenXR settings themselves live in
  `project.godot`; see the Pico constraints in the root `AGENTS.md`.
- Pointer-to-2D mapping (click/motion events): `OQ_UI2D/scripts/helper_UIArea.gd`.
- Redraw policy of a menu: the canvas instance's `update_only_on_input` in `game/BeepSaber_Game.tscn`.
- Keyboard layout or keys: `controls/VirtualKeyboard.gd` (`BUTTON_LAYOUT_*`, `B_SIZE`).
- Panel look: not here; `game/ui/menu_theme.tres` (see `game/ui/AGENTS.md`).

## Testing

Run the root test command; it does not exercise this folder. Desktop: run the main scene without a headset to get
`Feature_VRSimulator`. Any change to canvases, keyboard, raycast mapping or `initialize` needs a headset check:
menus render and redraw, hidden menus can't be clicked, keyboard types without the system IME, recenter works, and
`adb logcat` shows `OpenXR initialised successfully` and the available fps line.
