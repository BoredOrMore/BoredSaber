# CI and headset builds

`.github/workflows/build-pico4.yml` imports the project, runs the headless tests and exports a debug APK
for Pico 4 on every push, pull request and manual dispatch. `.github/debug.keystore` signs it.

## File map

- `workflows/build-pico4.yml` - the only workflow.
- `debug.keystore` - committed Android debug key (alias `androiddebugkey`, password `android`). Don't
  regenerate it: a new key makes the next APK fail to install over the old one.

## Pipeline, step by step (`build-pico4.yml`)

1. Env (`:8-11`): `GODOT_VERSION: 4.6.2`, `VENDORS_VERSION: 4.3.1`. 4.6.3 crashes on Pico 4 at startup
   (eye-tracked foveation with Vulkan, `:9`); stay on 4.6.2 until that is verified on the headset.
   Runner `ubuntu-24.04`, `contents: write` for the release step.
2. Checkout, Java 17 (temurin) for the Gradle build (`:19-24`).
3. Cache + download Godot editor and only the `templates/android_*` export templates (`:26-44`); the cache
   key is the Godot version.
4. Install OpenXR vendors plugin (`:46-54`): downloads `godotopenxrvendorsaddon.zip` for
   `VENDORS_VERSION`, then `mkdir -p addons` (addons/ has no tracked files, so without it `cp -r` would make
   `addons/` the plugin folder itself) and `test -f addons/godotopenxrvendors/plugin.gdextension`.
5. Configure Android export (`:56-70`): copies the keystore to `~/debug.keystore` and writes
   `~/.config/godot/editor_settings-4.6.tres` with SDK, Java and debug keystore paths.
6. `--headless --path . --import` (`:72-73`).
7. Run tests: `res://tests/test_map_info.tscn`; non-zero exit fails the job (`:75-76`).
8. Export (`:78-85`): `--install-android-build-template --export-debug "Pico 4" build/BoredSaber-Pico4.apk`,
   then checks the APK exists and contains `lib/arm64-v8a/libgodotopenxrvendors.so`. Without that library
   the game still starts but loses Pico OpenXR support, so the grep is the guard.
9. Upload artifact `BoredSaber-Pico4` (`:87-90`).
10. Publish `pico4-latest` (`:92-101`): only for non-PR runs on `pico4-offline` or the default branch.
    Deletes the old release and tag, creates a prerelease at `$GITHUB_SHA`. The fixed URL lets the headset
    browser download without a GitHub login.

## Gotchas

- Godot, vendors and Action version bumps are dependency changes: ask first (root `AGENTS.md`).
- The `Pico 4` preset in `export_presets.cfg` is arm64-only, Gradle build, excludes `tests/*`.
- Releases are replaced, not versioned: the previous `pico4-latest` APK is gone after each qualifying push.
- Editor settings file name uses `${GODOT_VERSION%.*}` (`4.6`); keep that if the version changes.

## Installing and testing on the headset

```sh
adb devices                                  # headset in developer mode, USB debugging allowed
adb install -r build/BoredSaber-Pico4.apk    # -r keeps data; works because of the shared debug key
adb logcat -c
adb logcat -s godot APxrRuntime PxrMetric    # game output, Pico OpenXR runtime, per-second metrics
```

- `godot`: GDScript `print`/`push_error`, script errors and crashes.
- `APxrRuntime`: OpenXR runtime messages (rejected action paths, session state, profile drops).
- `PxrMetric`: frame stats; watch `FPS` and `FrmGpu`. The Pico 4 display runs at 72 Hz (the game
  logs `avaliable fps: [72.0]`), so the budget is 1000 / 72 = 13.9 ms per frame; `FrmGpu` above that drops frames.
- Songs live in `/sdcard/Android/data/<package>/...` (`game/Constants.gd:21`); push test maps there with
  `adb push`.
- Changes to XR, input or rendering need this check on the device; the CI build only proves it exports.
