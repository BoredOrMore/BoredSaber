# Godot 4.4-4.7 API changes

What changed in Godot after the models' training data (~4.3), trimmed to what can matter for BoredSaber: GDScript,
3D, the Compatibility renderer, audio, input and OpenXR on Android. Read it before writing a Godot API call you are
not sure of, before trusting an older tutorial, and before any engine upgrade.

Adapted from `docs/engine-reference/godot/` in Claude-Code-Game-Studios by Donchitos (MIT, licence at the end), as of
2026-10-29; its tables were last checked against the official migration guides on 2026-10-17 (4.7) and 2026-02-12
(4.4-4.6). Dropped: C#, GDExtension, D3D12, 2D, TileMap, navigation, multiplayer, editor theme and gdUnit4 items.
Added: the "BoredSaber today" and "Upgrading to 4.7" sections.

## BoredSaber today

The project is pinned to Godot 4.6.2 (`.github/workflows/build-pico4.yml`, `GODOT_VERSION`) with
`godot_openxr_vendors` 4.3.1. So the 4.4, 4.5 and 4.6 sections below are in force now; the 4.7 section only matters
when upgrading. Repo search on 2026-10-29 (`game/`, `OQ_Toolkit/`, `tools/`, `tests/`):

| Change | Where it touches us |
|--------|---------------------|
| Glow runs before tonemapping (4.6) | `WorldEnvironment` glow in `game/BeepSaber_Game.tscn`; already tuned on 4.6, nothing to redo |
| Dual focus (4.6): `grab_focus()` sets keyboard/gamepad focus only | `keyboard._text_edit.grab_focus()` in `BeatSaverPanel.gd`, `ProfilesPanel.gd`, `BeepSaberMainMenu.gd`, `OQ_UI2DKeyboard.gd`; check with the laser pointer when editing them |
| `duplicate()` keeps shallow copies of nested resources (4.5 adds `duplicate_deep()`) | 40 `duplicate()` calls, mostly materials and meshes; use `duplicate_deep()` only where nested sub-resources must be per instance |
| Jolt default for new projects (4.6) | `project.godot` has `3d/physics_engine="Bullet"`, a Godot 3 value; which engine actually runs has not been checked |
| 4.7 GDScript and API breaks (table below) | No uses found of `device == 0`, `draw_line`/`draw_polyline`/`draw_arc`, `RichTextLabel.add_image`, `tap_back_pos`, `area_mask`, `is_class()`, `Quaternion()`, `LookAtModifier3D`, `SoftBody3D`, `WorldBoundaryShape3D`, `OpenXRExtensionWrapper` |

## Upgrading to 4.7

- Pico 4 first: Godot 4.6.3 crashed on Pico 4 at startup (eye-tracked foveation with Vulkan, see `.github/AGENTS.md`).
  Stay on 4.6.2, or move to 4.7+ only with that extension disabled and after a launch test on the headset.
- `godot_openxr_vendors` must have a release built for the new engine version; 4.7 changed
  `OpenXRExtensionWrapper._on_register_metadata()`, so older vendor plugins can fail to load.
- Keep the Pico rules in the root `AGENTS.md` (Compatibility renderer, OpenXR API 1.0.0, no `grip_surface/pose`).
- Fix the GDScript breaks first: typed-return overrides need an explicit `return`, and setters of packed-array
  properties no longer run on `arr[i] = v`.
- Run the headless tests, export through CI, then test on the headset (`.github/AGENTS.md`).

## Breaking changes

### 4.6 → 4.7 (Jun 2026)

From https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html. **GDScript breaks** marks
rows that stop existing GDScript from working; the guide lists no deprecations.

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Overrides inherit a typed return | An override of a method with a typed return inherits that type, so it needs an explicit `return` (`return null` fixes the error). **GDScript breaks** |
| GDScript | Packed array element writes | Setting one element of a packed array no longer calls the setter of the whole packed-array property |
| GUI | `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` | Renamed `UPDATE_WIDTH_UNIT`. **GDScript breaks** |
| GUI | `RichTextLabel.add_image()` / `update_image()` | `width` / `height` are `float`; `width_in_percent` / `height_in_percent` (`bool`) became `width_unit` / `height_unit` (`RichTextLabel.ImageUnit`) |
| Core | `Object.is_class()` | Parameter is `StringName` (was `String`) |
| Input | Mouse and keyboard device IDs | Were `0`; now `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`, because some joypads use `0`. Check the event type instead |
| Physics | Jolt `WorldBoundaryShape3D` | Sign of `plane.d` flipped compared to 4.6; negate it to keep 4.6 behaviour |
| Physics | Jolt `SoftBody3D` | Mass is 1 kg for the whole body (was per point), `linear_stiffness` applied differently; `Area3D` now reports `SoftBody3D` overlaps |
| Audio | `AudioStreamPlayer2D/3D.area_mask` default | `0` (was layer `1`): `Area3D.audio_bus_override` stops working until the mask is set back to layer `1` |
| Audio | `AudioEffectSpectrumAnalyzer.tap_back_pos` | Removed. **GDScript breaks** where used |
| Rendering | `CanvasItem` line drawing | No antialiasing feather, so lines look thinner |
| Rendering | `LinearToSRGB` visual shader node | No longer clamps to `[0, 1]` under Forward+ and Mobile |
| Rendering | `get_format()` | Moved from `ImageTexture` / `PortableCompressedTexture2D` to `Texture2D` |
| Rendering | `RenderingServer.particles_request_process_time()` | `time` renamed `process_time`; optional `process_time_residual` added (also on the particle nodes' `request_particles_process()`) |
| Rendering | Sky reflection roughness layers | `rendering/reflections/sky_reflections/roughness_layers` default `7` → `8` |
| Animation | `LookAtModifier3D.relative` | Default `false` (was `true`) |
| Animation | `AnimationNodeBlendSpace1D/2D.add_blend_point()` | Optional `name` added |
| Project | Stretch defaults for new projects | `canvas_items` / `expand`; existing projects keep theirs |
| Text | `ResourceImporterDynamicFont.hinting` | Default `3` (was `1`); fonts imported fresh may render differently |
| Editor | Asset Library | Replaced by the Asset Store workspace |
| XR | `OpenXRExtensionWrapper._on_register_metadata()` | New `interaction_profile_metadata` parameter; OpenXR extensions break |

### 4.5 → 4.6 (Jan 2026)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt is the default 3D engine for new projects | Existing projects keep their setting. Some `HingeJoint3D` properties (`damp`) only work with GodotPhysics3D |
| Rendering | Glow before tonemapping | Was after; uses screen blending. Scenes with glow look different |
| Rendering | AgX tonemapper | White point and contrast controls added |
| Core | `Quaternion()` initialises to identity | Was zero |
| UI | Dual focus | Mouse/touch focus is separate from keyboard/gamepad focus; `grab_focus()` only sets the latter |
| Animation | IK restored | CCDIK, FABRIK, Jacobian, Spline and TwoBone IK as `SkeletonModifier3D` nodes |
| Editor | Select Mode | New "Select Mode" (`v`) prevents accidental transforms; old mode is "Transform Mode" (`q`) |

### 4.4 → 4.5 (Sep 2025)

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Variadic arguments | `func f(...args: Array)`; see "New in GDScript" |
| GDScript | `@abstract` | Abstract classes and methods |
| GDScript | Script backtracing | Call stacks available in release builds |
| Rendering | Stencil buffer, SMAA 1x, Shader Baker, bent normals, specular occlusion | New features; not checked on the Compatibility renderer |
| Physics | 3D physics interpolation | Moved from RenderingServer to SceneTree; API unchanged |
| Resources | `duplicate_deep()` | Explicit deep copy of nested resources |
| UI | `FoldableContainer`; recursive Control disable | New collapsible container; one property disables mouse/focus for a whole subtree |
| Platform | Android 16 KB pages, SDL3 gamepad driver | Android 15+ page-size support; gamepads go through SDL |

### 4.3 → 4.4 (Mar 2025)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void` (`store_8` … `store_var`, `store_line`, `store_string`, `store_buffer`, …) |
| Core | `RegEx.compile()` / `create_from_string()` | Optional `show_error` added |
| Rendering | `Shader.set_default_texture_parameter()` / `get_default_texture_parameter()` | Type is `Texture` (was `Texture2D`); shader `sampler2D` / `texture()` unchanged |
| Particles | `restart()` | Optional `keep_seed` added |
| GUI | `RichTextLabel.push_meta()` | Optional `tooltip` added |

## Deprecated APIs

Models trained on Godot 3 tutorials still emit these. Replace the left column with the right.

| Deprecated | Use instead | Since |
|------------|-------------|-------|
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `VisibilityNotifier3D` | `VisibleOnScreenNotifier3D` | 4.0 |
| `AnimationPlayer.method_call_mode` / `playback_active` | `AnimationMixer.callback_mode_method` / `active` | 4.3 |
| `Skeleton3D.bone_pose_updated` | `skeleton_updated` | 4.3 |
| `duplicate()` for per-instance nested resources | `duplicate_deep()` | 4.5 |
| `event.device == 0` for mouse or keyboard | `event is InputEventMouse` / `InputEventKey` | 4.7 |
| `RichTextLabel` `UPDATE_WIDTH_IN_PERCENT`, `*_in_percent` | `UPDATE_WIDTH_UNIT`, `width_unit` / `height_unit` | 4.7 |
| `AudioEffectSpectrumAnalyzer.tap_back_pos` | (removed) | 4.7 |

## New in GDScript (4.5+)

- Variadic arguments: the rest parameter is written `...name`, comes last, and is `Array` or untyped
  (`values: Variant...` and `...values: Array[int]` do not parse).
  ```gdscript
  func log_values(prefix: String, ...values: Array) -> void:
  	for v in values:
  		print(prefix, ": ", v)
  ```
- Lambdas capture locals by value (all of Godot 4): a lambda cannot reassign an outer local, so `var hit := false`
  then `func(): hit = true` leaves `hit` false. Share state through a Dictionary, Array or object. A rest parameter
  works in a lambda, so `func(...args)` connects to a signal of any arity (observed on 4.6.1 upstream).
  ```gdscript
  var state := {"emitted": false}
  some_signal.connect(func(...args): state.emitted = true)
  ```
- `@abstract` classes and methods; an abstract method has no body:
  `@abstract func get_pattern() -> Array[int]`.

## Tooling

- ripgrep has no `gdscript` type (`*.gd` is registered as `gap`): use `--glob "*.gd"` or the Grep tool's `glob`.
- A fresh clone has no `.godot/` class cache: run `godot --headless --path . --import` before scripts that use
  `class_name` types.
- `--check-only -s <file>` fails on valid code that names an autoload, and `--import` / `--quit-after` exit 0 on a
  parse error, so neither is a parse check; running the scene or test is (upstream observation on 4.6.1).

## Sources

- Migration guides: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html,
  `upgrading_to_godot_4.6.html`, `upgrading_to_godot_4.5.html` in the same folder
- Release notes: https://godotengine.org/releases/4.7/, https://godotengine.org/releases/4.6/
- Releases and dates (4.4 Mar 3 2025, 4.5 Sep 15 2025, 4.6 Jan 26 2026, 4.7 Jun 18 2026, 4.7.2 Aug 18 2026):
  https://github.com/godotengine/godot/releases
- Upstream: https://github.com/Donchitos/Claude-Code-Game-Studios/tree/main/docs/engine-reference/godot

## Licence of the adapted material

```
MIT License

Copyright (c) 2026 Donchitos

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
