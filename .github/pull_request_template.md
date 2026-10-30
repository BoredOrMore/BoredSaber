## What and why

<!-- What the player notices (or "no player-facing change"), and why it was needed. -->

## Changes

<!-- One line per logical change; name the main files. -->

-

## Checks

<!-- Tick what applies; delete the lines that don't and say why a needed one was skipped. -->

- [ ] Headless tests pass (`godot --headless --path . res://tests/<test>.tscn`), and new logic has a test
- [ ] `python3 tools/check_agent_docs.py` passes; the folder `AGENTS.md` is updated for added, moved or removed files
- [ ] No unrelated changes (Godot-rewritten `.uid`, `.import`, `.tscn`/`.tres` left out)
- [ ] Played on the Pico 4 (needed for XR, input, rendering and game-feel changes)
- [ ] GPU before/after on the headset at 72 Hz (budget 13.9 ms), for stage, shader or effect changes
- [ ] Menu, HUD or score-screen change: `vr-ui-review` done, sizes and placement from the real eye
- [ ] Colours from `Constants.gd` / `Settings.gd` only, and the Colour and Light rules in `AGENTS.md` are followed
- [ ] Player-facing wording is plain (no `NJS`, `BPM`, error codes)

## Game-feel sources

<!-- For note speed, scoring, health, haptics, comfort, HUD placement: the sources and numbers used,
     or "untuned placeholder". Otherwise delete this section. -->

## Screenshots or captures

<!-- Stage captures (`tools/capture/`) or headset screenshots for anything visual. Otherwise delete. -->

## Not done / known gaps
