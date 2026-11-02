# native/pico_room

C++ GDExtension that reads the real room from PICO's own OpenXR extensions (`XR_BD_*`), for the room-aware Mixed
Reality mode (plan: https://claude.ai/artifact/GGNL7bgEiekk4VeT4G3aVy). Godot 4.6 can't do this from GDScript: the
standard spatial entity path (`XR_EXT_spatial_entity`) isn't offered by the Pico 4 runtime on OS 5.12, and GDScript
can't call raw OpenXR functions. The owner approved this native dependency (2026-11-02).

Stage: probe only (tag `PicoRoom:` in logcat). Once the app has focus it loads the room the player saved in PICO's own
room setup (`xrLoadAnchorEntityBD`, no filter), logs every runtime event raw, and when the event carrying the load's
task id arrives, reads the results and logs each anchor's label, component flags, plane, box and pose, raw. Not for
merging until it reads rooms.

## File map

- `SConstruct` - builds `game/native/bin/libpicoroom.<platform>.<target>.<arch>.so` against godot-cpp (`GODOT_CPP`) and
  the Khronos OpenXR-SDK headers (`OPENXR_INCLUDE`).
- `src/register_types.cpp` - entry `pico_room_library_init`; registers the probe at the core level (before OpenXR
  makes its instance, or its extensions are never requested).
- `src/pico_room_probe.h`, `src/pico_room_probe.cpp` - `PicoRoomProbe` (`OpenXRExtensionWrapperExtension`).
- `game/native/pico_room.gdextension` - tells Godot where the built libraries are; the export puts the arm64 one in
  the APK. `game/native/bin/` is built by CI and git-ignored.

## Build

CI (`.github/workflows/build-pico4.yml`, "Build PICO room plugin") clones godot-cpp `GODOT_CPP_TAG` (godot-4.5-stable;
4.5 extensions load in 4.6) and OpenXR-SDK `OPENXR_SDK_TAG`, builds Android arm64 with the runner's newest NDK and
Linux x86_64 (only so the headless import and tests load it cleanly). Locally:
`GODOT_CPP=<godot-cpp> OPENXR_INCLUDE=<OpenXR-SDK>/include scons platform=linux target=template_debug`.

## Gotchas

- The runtime's library names PICO-specific extensions (`XR_BD_room_scene`, `XR_BD_semi_auto_room_capture`,
  `XR_BD_spatial_localization_and_tracking`) and lacks the Khronos `XR_BD_spatial_sensing` base and `XR_EXT_future`
  by name (strings in `libpxrruntime*.so`, 2026-11-02). Trust the probe's list over the Khronos headers.
- The Pico 4 runtime (OS 5.12) offers only PICO's older private room API: `XR_BD_anchor_entity`,
  `XR_BD_room_scene`, `XR_BD_semi_auto_room_capture` (function names from the runtime's strings). PICO publishes no C
  header for it. Known from the runtime's code: `xrLoadAnchorEntityBD(XrSession, info*, uint64_t* task)`, the info is
  OpenXR-style (type, next, then u32 maxResult at +0x10, u64 timeout at +0x18, u32 location at +0x20, include filter
  pointer at +0x28; null loads everything; filter types 1200006348/1200006349/1200006362). The other functions'
  layouts are still guesses (PICO's Unity SDK C#), so the probe hands them oversized zeroed buffers and logs them raw.
  The instance gives -12 (the runtime checks for a session); a wrong layout crashes inside the runtime.
- Each risky stage writes a marker file (`user://pico_room_vN_<stage>`) and removes it when it returns, so after a
  crash the next launch skips that stage instead of crashing on every launch. Bump vN with each probe build.
- `com.picovr.permission.SPATIAL_DATA` is unknown to OS 5.12 (logcat `NameNotFoundException`).
