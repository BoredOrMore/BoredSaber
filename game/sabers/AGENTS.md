# Saber visuals

The look of a saber in the hand: blade, hilt, glow, trail, hit sound. Read the root `AGENTS.md` first ("Light"
rules govern blade, halo and hilt brightness).

Collision, swing tracking, show/hide timing and cutting live in `game/LightSaber.gd/.tscn` (documented in
`game/AGENTS.md`); this folder is only the visual child it holds.

## How a saber is chosen and instanced

- `game/Settings.gd:7-10` `SABER_VISUALS`: list of `[label, scene path]` pairs ("Default saber", "Particle sword").
  `Settings.saber_visual` is the index; `Settings.get_saber_visuals()` (`Settings.gd:663`) forces index 0 while
  `claws` is on.
- Settings > Visuals fills its OptionButton from that list (`game/settings_Panel.gd:141-143`, writes at `:258`).
- `game/LightSaber.tscn` instances `default_saber.tscn` under `saber_holder`; `LightSaber.gd:15` grabs it as
  `saber_visual: DefaultSaber`. `LightSaber._ready` (`:121`) and the `saber_visual`/`claws` settings keys (`:108-111`)
  call `set_saber(path)` (`LightSaber.gd:286`): loads the scene, accepts it only if it `is DefaultSaber`, frees the
  old holder children, adds it, applies colour/thickness/trail.
- The API `LightSaber` calls (every visual must provide it, so extend `DefaultSaber`): `set_color`, `set_thickness`,
  `set_trail`, `_show`, `_hide`, `quickhide`, `is_extended`, `hit(time_offset)`, `tip` (Marker3D read each physics
  frame for `left_saber`/`right_saber` globals, `LightSaber.gd:266`).
- Other users: `tools/capture/stage_capture.gd:60,222` (`--saber left|right` holds a lit default saber in front of
  the camera); `game/DebugView.gd:83` hides `saber_visual`.

## File map

- `default/default_saber.gd` (class `DefaultSaber`): base saber. Drives `AnimationPlayer` (`Show`/`Hide`, `ShowShort`/
  `HideShort` with claws, `QuickHide`), sets shader `color` on blade, halo and hilt ring `accent`, scales blade x/z
  for thickness, `hit()` flashes the trail and plays `hitsound` offset by `time_offset` (`:80-90`). Builds the halo
  `QuadMesh` in code (`:15-31`) and shows it only when `Settings.glare` and `glow_quality != "Classic"` and not
  `mixed_reality` (`:34`); `_process` feeds the blade's animated `CapsuleMesh.height` to the halo (`:37-39`).
- `default/default_saber.tscn`: nodes `LightSaber_Mesh` (blade, `game/LightSaber.material`), `Hilt/{Grip,Collar,
  Pommel,Ring}` (`SaberHilt.gdshader`), `AnimationPlayer`, `base`/`tip` markers (tip y=1.2554), `hitsound`
  (`game/data/cut_sounds.tres`), `AudioStreamPlayer3D` (no stream of its own: the Show/Hide animations' audio
  tracks play `game/data/lightsaber.ogg`), `tail` instance.
- `default/SaberHalo.gdshader`: blade glow as a camera-facing ribbon drawn per eye (not the glow pass, which is
  off by ~7 deg per eye up close). Uniforms `color`, `blade_length`, `width`, `min_pixels`, `strength`.
- `default/SaberHilt.gdshader`: unshaded gunmetal hilt, grip ridges, rim light; `ridges`=1 on grip, `glow`=1 on the
  ring, which takes `accent` (saber colour). Header says "Untuned".
- `default/tail.gd` (class `SaberTail`) / `default/tail.tscn`: swept trail sheet. One preallocated dynamic
  `ArrayMesh`, `MAX_SEGMENTS` 64, `MAX_AGE` 0.22 s; opacity from tip speed (`TRAIL_SPEED_FULL` 6 m/s, `TRAIL_CURVE`);
  resets on jumps over `TELEPORT_DISTANCE` 0.5 m (recenter, height change); `flash()` on a cut (x1.8, 0.15 s).
- `default/SaberTrail.gdshader`: additive unshaded sheet for `tail.tscn`; UV.x age, UV.y opacity; `color`, `energy`.
- `particles/particles_saber.gd` / `particles/particles_saber.tscn`: "Particle sword", extends `DefaultSaber`;
  `sword.obj` blade mesh with `game/LightSaber.gdshader`, `GPUParticles3D` sparks, random hit pitch, ignores
  thickness. Reuses `default/tail.tscn` via `RemoteTransform3D`. Assets: `sword.obj/.mtl`, `sword_clash.8a.ogg`
  (hitsound), `sword_clash.10.ogg`.

## Invariants and gotchas

- `set_saber` silently ignores a scene whose root script is not a `DefaultSaber`; new visuals must extend it.
- `DefaultSaber` `@onready`s fixed paths: `AnimationPlayer`, `LightSaber_Mesh` (ShaderMaterial override, and a
  `CapsuleMesh` for the halo), `tip`, `tail`, `hitsound`; `Hilt/Ring` (accent colour) is optional. A subclass scene
  must have the rest, and an override of `_ready`/`_process` must call `super`.
- Particle sword: its node named `CPUParticles3D` is a `GPUParticles3D` (the animations use that name); hidden and
  disabled on Android and the web, so on the headset it is the blade without particles.
- `tail.gd` reparents its `Mesh` to the scene root (vertices in world space, huge `custom_aabb`); `_notification`
  frees it on `PREDELETE` so swapping sabers leaves no frozen trail. Keep both.
- Trail and halo use additive, unshaded, `depth_draw_never` materials; brightness rules are in root "Light".
- Layers: blade/trail meshes use `layers = 3`; the halo copies the blade's layers.
- `.uid` files next to scripts/shaders are untracked editor output; don't commit them (root `AGENTS.md`).

## Where to change X

- Add a saber: new folder + scene whose script extends `DefaultSaber`, add `[label, path]` to
  `Settings.SABER_VISUALS`; claws always use index 0.
- Blade colour/thickness/show-hide anims: `default_saber.gd` + `AnimationPlayer` in `default_saber.tscn`; blade
  material is `game/LightSaber.material` (outside this folder).
- Glow around the blade: `SaberHalo.gdshader` (look), `default_saber.gd:34` (when shown).
- Trail length/fade/speed response: constants at `tail.gd:8,47-91`; look in `SaberTrail.gdshader`.
- Hilt look: `SaberHilt.gdshader` and `Hilt/*` meshes in `default_saber.tscn`.
- Hit sound: `hitsound` stream in each scene (`game/data/cut_sounds.tres` for default).
- Hit timing, collision, swing scoring: `game/LightSaber.gd`, not here.

## How to check a change

- No unit tests cover sabers. Look on desktop:
  `godot --path . res://tools/capture/stage_capture.tscn -- --out /tmp/saber.png --saber left --seconds 3`
  (default saber only; add `--saber-dist 0.5`, `--left RRGGBB`). Not headless: it needs a window to render.
- `python3 tools/check_agent_docs.py` after adding/renaming a file here.
- Halo, trail and colours on the Pico LCD differ from desktop: final check on the headset, both eyes, with Glow
  Soft/Sharp/Classic and the trail toggle.
