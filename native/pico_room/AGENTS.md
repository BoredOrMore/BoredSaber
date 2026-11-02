# native/pico_room

C++ GDExtension that reads the real room from PICO's own OpenXR extensions (`XR_BD_*`), for the room-aware Mixed
Reality mode (plan: https://claude.ai/artifact/GGNL7bgEiekk4VeT4G3aVy). Godot 4.6 can't do this from GDScript: the
standard spatial entity path (`XR_EXT_spatial_entity`) isn't offered by the Pico 4 runtime on OS 5.12, and GDScript
can't call raw OpenXR functions. The owner approved this native dependency (2026-11-02).

Stage: probe only (tag `PicoRoom:` in logcat). It logs which room extensions Godot enabled and which of PICO's room
functions resolve, then, once the app has focus, tries to load the room the player saved in PICO's own room setup
(`xrLoadAnchorEntityBD`, no filter) and logs each anchor's scene label, plane, box and pose, plus every runtime event
raw. Not for merging until it reads rooms.

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
  header for it: struct layouts come from PICO's Unity SDK C# (`PXR_Plugin.cs`) and signatures from the community
  dump https://github.com/thoricelli/PICO-documentation (xrAPI/README.md); whether the first argument is the instance
  or the session isn't known yet, so the probe tries both. Anchor handles are `XrSpace`s (the runtime destroys them
  with `xrDestroySpace`).
- `com.picovr.permission.SPATIAL_DATA` is unknown to OS 5.12 (logcat `NameNotFoundException`).
