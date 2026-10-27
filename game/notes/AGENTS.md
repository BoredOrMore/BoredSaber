# game/notes/ — what flies at the player

Notes (`BeepCube`), chain links, arcs, bombs and walls, and the `Cuttable` base they share. Read the root
`AGENTS.md` first (notes are the brightest thing in view: "Light", "Colour rules") and `game/AGENTS.md` for the
spawn, cut and miss flow, pooling rules and "Add a note type".

## Entry points and flow

- Spawned from `GameStatePlaying` (`game/scripts/GameState/Playing.gd`) out of `ScenePool`s in `BeepSaber_Game.tscn`
  (`GlobalReferences.*_pool`); every instance lives under `track` and is reused (`spawn()` resets it).
- `Cuttable.gd` (class `Cuttable`, a `PooledNode3D`): base of `BeepCube`, `ChainLink`, `Bomb`: lane movement,
  rotation, miss past `Constants.MISS_Z`, cut-piece release. Walls (`Wall.gd`) and arcs (`Arc.gd`) move themselves.
- Cuts: the saber's swing cast calls `Cuttable.cut(saber, speed, plane, controller)`; scoring goes to `Scoreboard`
  (`game/Scoreboard.gd`), swing angles come from `game/LightSaber.gd`.

## File map

- `Cuttable.gd` (class `Cuttable`): base for `BeepCube`, `ChainLink`, `Bomb`: lane movement, rotation, miss,
  piece release.
- `BeepCube/` — `BeepCube.gd` (note; `cutted` signal, scoring, rumble), `BeepCube_CutPiece.gd`
  (`CutPiece` RigidBody halves, `MAX_LIFETIME` 0.3 s), `BeepCube_SliceParticles.gd/.tscn` (GPU particles freed
  on Android/Web), `BeepCube.gdshader` (`color`, `is_dot`, `arrows_enabled`, `is_chain_head`, cut uniforms),
  `note_gloss.gdshaderinc` (the default glossy note look, shared with `ChainLink.gdshader`).
  `BeepCubeTest.tscn` is a standalone test scene.
- `Chain/` — `ChainLink.gd` (bezier link placement, lenient hitbox, link scoring), shader, mesh.
- `Arc/` — `Arc.gd` (mesh from `ArcInfo.mesh_arrays`, magnet material on head cut), `Arc.gdshader`
  (reads `left_saber`/`right_saber`). Static `left_material`/`right_material(_magnet)` are shared.
- `Bomb/` — `Bomb.gd`, `BombGlow.gdshader` + `bomb_glow.tres` (`danger_color`); `BombMerged.gdshader` draws body and
  glow hull in one call (`Bomb.merged_mesh`, the default); `BombMesh.tscn` + `BombBody.gdshader` are the two-mesh
  bomb `Bomb.classic` brings back to compare.
- `Wall/` — `Wall.gd` (resizes box mesh/shape per wall), `FramedWall.gdshader` (default wall: box plus edge bars, one
  draw call), `DangerWall.gdshader` + `danger_wall.tres` (classic wall, `Settings.classic_walls`).

## Invariants and gotchas

- Pooled instances are reused: `spawn()` resets every per-instance state; `release()` exactly once (`game/AGENTS.md`).
- Notes, chains and arcs keep their own colour: `fog_disabled`, no stage light or env reflection on them.
- The `.material` files here are binary (`RSCC`) and embed their shader's path: moving a shader means re-saving the
  material (load it, set `shader` to the new path, `ResourceSaver.save`), a text edit can't fix it.
  `BeepCube/BeepCube.material` points at a texture that no longer exists and nothing uses it.
- Danger colour (`danger_wall.tres`, `bomb_glow.tres`) and the arc materials are shared; set from `BeepSaber_Game.gd`.

## Where to change X

- Note look: `BeepCube.gdshader` + `note_gloss.gdshaderinc` (shared with `ChainLink.gdshader`); mesh `note_round.glb`
  from `tools/models/note_round.py -- game/notes/BeepCube`.
- Cut accuracy and points: `BeepCube.cut`, `ChainLink.cut`; the score rules: `game/Scoreboard.gd`, `game/Constants.gd`.
- Wall or bomb look: `FramedWall.gdshader` / `BombMerged.gdshader` (defaults), the classic ones beside them.
- A new note type: "Add a note type" in `game/AGENTS.md`.

## Checking a change

- `godot --headless --path . --import`, then `tests/` (`test_swing_rating` covers scoring).
- Look on the Mac: `tools/capture/stage_capture.tscn` with `--note left`, `--bomb 1`, `--wall 1`, or `--map <song> --notes 1`.
- Then on the headset; anything touching cutting, spawning or rumble needs a play there.
