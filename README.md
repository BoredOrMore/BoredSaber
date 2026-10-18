# Open Saber Plus VR
This is a fork of [Beep Saber by NeoSpark314](https://github.com/NeoSpark314/BeepSaber) ported to Godot 4.3 and OpenXR (WIP)
(The OQ Toolkit is only partially ported/patched for it to work on Godot 4 with OpenXR, most features that are not used in this project will not work)

This fork tries to improve the experience and make it more of it's own game instead of just a demo.



This is a basic implementation of the beat saber game mechanic for VR using the [Godot Game Engine](https://godotengine.org/) and the [Godot Oculus Quest Toolkit](https://github.com/NeoSpark314/godot_oculus_quest_toolkit). The main objective of this project is to show how a VR game can be implemented using
the Godot game engine.

The main target platform is the Oculus Quest but it should also work with SteamVR if you add the OpenVR plugin to the addons folder in the godot project.

Originally this game was (and still is) a demo game as part of the Godot Oculus Quest Toolkit. To keep the demo implementation small
this stand alone version was forked so that it can be changed and developed independent of the original demo.

![screenshot01](doc/images/OS0.4.0_1.gif)
![screenshot02](doc/images/OS0.4.0_2.gif)
![screenshot03](doc/images/OS0.4.0_3.gif)
# About the implementation
This game uses godot 4.3. The implementation supports to load and play maps from [BeatSaver](https://beatsaver.com/).
To export for android headsets the godot openxr vendors plugin may be needed

There is one demo song included that is part of the deployed package.

You can play custom songs by downloading them in the in-game menu. 

# Pico 4
The `Pico 4` export preset builds an APK with the Pico OpenXR loader. GitHub Actions builds it on every push
(`.github/workflows/build-pico4.yml`) with Godot 4.6.2 and godot_openxr_vendors 4.3.1, and uploads it as the
`BoredSaber-Pico4` artifact. Pushes to `pico4-offline` or the default branch also replace the `pico4-latest` release, so the
headset browser can download https://github.com/BoredOrMore/BoredSaber/releases/download/pico4-latest/BoredSaber-Pico4.apk
without a GitHub login. Godot 4.6.3 is avoided because it crashes on Pico 4 at startup.

Downloaded songs are stored on the headset, so they stay playable without an internet connection.

Map parsing tests run headless: `godot --headless --path . res://tests/test_map_info.tscn`

# Credits
The included Music Track is Time Lapse by TheFatRat (https://www.youtube.com/watch?v=3fxq7kqyWO8)

# Licensing
The source code of the godot beep saber / open saber game in this repository is licensed under an MIT License.
