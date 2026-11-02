# native/pico_room

C++ GDExtension that reads the real room from PICO's own OpenXR extensions (`XR_BD_*`), for the room-aware Mixed
Reality mode (plan: https://claude.ai/artifact/GGNL7bgEiekk4VeT4G3aVy). Godot 4.6 can't do this from GDScript: the
standard spatial entity path (`XR_EXT_spatial_entity`) isn't offered by the Pico 4 runtime on OS 5.12, and GDScript
can't call raw OpenXR functions. The owner approved this native dependency (2026-11-02).

Stage: probe only (tag `PicoRoom:` in logcat). Once the app has focus it loads the room the player saved in PICO's own
room setup (`xrLoadAnchorEntityBD` with the spatial scene filter), and loads again every 5 s and on each local map state
event until it finds anchors. It opens PICO's scene capture (`xrStartSpatialSceneCaptureBD`) on the first focus, every time (Bored, 2026-11-02: PICO only recognises the room after it), then loads when focus returns. For each anchor it also tries `xrCreateAnchorSpaceBD` (guessed: session, info with the anchor id at +0x10, XrSpace out) and `xrLocateSpace` in the play space, logged raw (v10). When the loaded event (type
1200006350) reports anchors, it reads the results and logs each anchor's label, component flags, plane and box, raw. Not for
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
  pointer at +0x28; filter types 1200006348 UUID / 1200006349 component / 1200006362 spatial scene, flags at +0x10).
  The anchor store the app sees was empty ("GetAnchor Total = 0") even though the room was scanned in PICO's
  Settings: scene filter and component filter both found 0 (b984b09). A null filter runs as a UUID load with 0 UUIDs and finds nothing. The loaded event is type 1200006350: task id at
  +0x10, result i32 +0x18, total u32 +0x1C, location +0x20. The other functions'
  layouts are still guesses (PICO's Unity SDK C#), so the probe hands them oversized zeroed buffers and logs them raw.
  The instance gives -12 (the runtime checks for a session); a wrong layout crashes inside the runtime.
- After a scan in PICO's room capture (opened from the game by `xrStartSpatialSceneCaptureBD`; it runs as its own app,
  `com.pvr.roomcapture`), the scene-filter load found 11 anchors (ad4c718). Results struct: capacity u32 at +0x10, count
  u32 written at +0x14, entries pointer at +0x18; each entry is 40 bytes (type, next, anchor id at +0x10, UUID). Anchor
  handles are small ids (260...), not `XrSpace`s: never pass them to `xrLocateSpace`. Calling the capture with
  (session, &task) crashed at address 0; the probe now passes (session, zeroed info, &task).
- Anchors only load while the headset has recognised (localised in) the saved room: the runtime's local map state
  (event type 1200006303, logged as on_local_map_state_changed) was 1 when 11 anchors loaded and 0 when the same room
  gave 0 (457bd49). Standing and looking around for a minute didn't bring it to 1 (0fb0406); opening PICO's scene
  capture did (total 11 on every load after it). `xrStartSpatialSceneCaptureBD(session, info, &task)` returns 0 without crashing.
- Each risky stage writes a marker file (`user://pico_room_vN_<stage>`) and removes it when it returns, so after a
  crash the next launch skips that stage instead of crashing on every launch. Bump vN with each probe build.
- `com.picovr.permission.SPATIAL_DATA` is unknown to OS 5.12 (logcat `NameNotFoundException`).
