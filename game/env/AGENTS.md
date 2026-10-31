# game/env/ — stage environments

The scenery around the track: one rig script per stage (structure the lights hang on), the scenery/sky shaders,
the laser fixtures and bar batching, the track deck, and the air (haze globals, smoke, dust). Everything here is
driven by `EventDriver` (`game/event_driver.gd/.tscn`), which owns the five light groups.
Read the root `AGENTS.md` first ("Light", "Colour rules", "Pico 4 constraints").

## Entry points and flow

- Scene: `game/event_driver.tscn` (`Level/`): the sky `Sphere`, the five light-group holders (`DiagonalLasers`,
  `SquareLasers`, `Left/RightWavingLasers`, `TrackTurn/TrackLights`), the old `rings`, `ClassicRig`, `NeonGridRig`,
  `NightCityRig`, `MetalFactoryRig`, `PulseVoid`, `HengeRig`, `MonolithRig`, `NeonGrid` floor, `TrackDeck`, `StageSmoke`. Every rig is built at load
  (tool scripts, `_ready`) and stays in memory; only visibility changes.
- The track turns with the notes on 90/360 maps (`EventDriver._turn_track`): `Level/TrackTurn` (the edge light strips,
  the old see-through track `floor` and its `Endpath`) and `TrackDeck.turn` (deck and curbs) turn about the player's
  standing point (`Constants.PLAYER_Z`) to `Map.track_rotation(show_beat)`, easing over `TRACK_TURN_TIME` (0.8 s,
  untuned; a cubic ease in and out that keeps its speed when a new turn comes mid-way). The platform, camera and XR origin never turn. `set_background` lays the turning
  parts out unturned (it writes global transforms), then turns them back.
  The turn cue (`TrackDeck.set_cue`, a chevron on the floor) eases the same way to `Map.cue_rotation(show_beat)`, the
  map's rotation events, so it leads the lanes (inner class `Turn` eases both).
- Stage choice: `Settings.ENVIRONMENTS` (`Settings.gd:35`, ids `classic`, `neon_grid`, `pulse_void`, `night_city`,
  `metal_factory`, `henge`, `monolith`, plus `auto`). `EventDriver.pick_environment(map)`: a 90/360 difficulty
  (`Map.TURNING_CHARACTERISTICS`) always gets `henge`, the only stage ready for them (owner, 2026-10-29); else the
  player's pick, else `map_environment`:
  `Constants.MAP_ENVIRONMENTS` (map's Beat Saber env name), then `TAG_ENVIRONMENTS` (genre), then a folder-name hash
  into `AUTO_ENVIRONMENTS` (Metal Factory is never auto-picked). Called from `BeepSaber_Game.gd:173` (song start)
  and `:758` (menu).
- "Canyon" is not its own stage: it is Night City's layout (`NightCityRig.build`; the old row-of-buildings layout
  was removed 2026-10-31).
- `set_environment(id)`: lazily builds the stage's sky `ShaderMaterial` (`SKY_SHADERS`,
  `SKY_TEXTURES`; Classic keeps the scene's sky), copies the `bg_<type>_tint/intensity` params over, sets the
  Stinger bus reverb, `_rig.apply(id)` (`LightRig.gd`), `track_deck.set_stage(id)`, visibility, `set_background()`.
- `LightRig.apply(id)` (`LightRig.gd`, made by EventDriver as `_rig`): resets every laser/bar to its Classic transform (`classic_places`),
  then re-places them on the stage's carriers via the rig's static helpers (`ClassicRig.moving_head_spot/follow_spot/
  scaffold_bar`, `NeonGridRig.floodlight_bases/crane_lights/SURVEY_MASTS`,
  `LightRig._hang_canyon`, `PulseVoid.leg_floodlight/rim_beacon`, `MetalFactoryRig.RAIL_X/RAIL_TOP`). Also sets sky scale
  (`NEON_SKY_SCALE`/`CANYON_SKY_SCALE`), `fog_key` (`FOG_KEYS`), Pulse Void's narrower beams, fixture kind per laser.
- Light events: `Playing.gd:73-75` sets `show_beat` and calls `process_event(EventInfo)` (no look-ahead). Types 0-4
  -> `turn_light_on/off`, `flash_*`, `fade_*` set each group's `light_color` on its beam material and the sky's
  `bg_<type>_tint/intensity`; flashes capped at `MAX_FLASHES_PER_SECOND` per group. Types 8/9 rings, 12/13 waving
  laser speed. Light colour reaches scenery only through globals and per-rig materials, never per-object.
- Show intensity: `start_show(events, bpm)` (`BeepSaber_Game.gd:188`) builds `intensity_curve` (event rate over a
  4 s window, normalised to the song's own 20th-90th percentile); `_update_show` smooths it into `_intensity` and the
  never-falling `_built`. `_built` drives Classic's scaffolds (`set_built`), Neon Grid/Pulse Void strip `level`,
  canyon windows; `_intensity > STRIP_DROP` is "the drop" (all strips, Pulse Void's `drop_beam`, Classic rib sweep).
  `build_up(curve, beat, bpm)` looks `BUILD_UP_SECONDS` ahead for the next drop; `_update_sweep` turns the moving
  heads (`diagonal_lasers`) toward `SWEEP_TARGET` over the player and pans them, on `SWEEP_STAGES` (Classic so far).
- Result moment: `result_mood(failed)` (from `BeepSaber_Game` at a fail and at a clear): a fail kills the lights and
  fades the danger colour into `result_air`, a clear a warm air and two spark bursts (`CLEAR_SPARK_PLACES`); fades in
  over 1 s, holds `RESULT_HOLD_SECONDS`, eases out (root `AGENTS.md`, Colour rules' exception). `stage_capture --result`.
- Menus: `set_menu_focus(true)`: house-tinted breathing lights, `classic_rig.set_built(1.0)`,
  pistons rest, no smoke and no extra haze (owner: the menus as clear as can be). `false`: smoke dissipates, all groups off until the map turns them on.
- Per frame (`EventDriver._process`): decays combo/mistake pulses, writes `cut_waves`,
  `_update_haze()` (sums the four beam materials' `light_color` + floor -> `env_light`, a mostly-grey tint of it ->
  `env_haze`, plus `combo_glow`), track-deck light colour, Metal Factory vents, `_update_show`, canyon windows and
  billboards, `_update_strips` / `_update_rib_strips`, `_follow_frames`, ring spin. Then `LaserFixtures._process`
  copies laser poses into fixture MultiMeshes and `LaserBatch._process` (priority 1000, last) copies bar poses.

## File map

Classic (the giant test tunnel)
- `ClassicRig.gd` (tool, `ClassicRig`): 120 m bore to `RIB_FAR` -600, ribs/lining/catwalks/props as MultiMeshes of
  glb models, six hanging scaffolds at `FRAME_Z`. `set_built` flies scaffolds in far-first; `_process` moves them;
  `drop_at`/`standing` let EventDriver hide lights on scaffolds not yet down. Rib strips use `ArchStrip.gdshader`.

Neon Grid
- `NeonGridRig.gd` (tool): three megastructure arches (`ARCH_A/B/C`), crane on C, survey masts, site props; arch
  strips (`strip_material`, `ArchStrip.gdshader`) carry the square bars' light. The arches don't mirror; the middle
  ground's site gates (`GATE_*`, unfinished half arches either side of the track) do; sun kept clear.
- `NeonGridFloor.gdshader`: static glowing grid (no scroll: vection), `MIN_LINE_PIXELS` prefiltered lines; terrain
  raised per vertex past a flat valley along the track (`flat_spots` from `NeonGridRig.ground_spots`, set by EventDriver);
  on the scene's `NeonGrid` node.
- `NeonGridSky.gdshader`: sunset sky from baked masks `neon_grid_sky_sharp/soft.png` (`tools/bake_neon_grid_sky.py`;
  per-pixel version cost ~4.5 ms GPU).

Night City (canyon)
- `NightCityRig.gd` (tool): canyon (tower wall on `WALL_SIDE`, low roofs opposite, far city, landmark);
  `wall_*_spot` place lights; `set_windows` feeds layer 9.
- `EnvSolidCanyon.gdshader`: EnvSolid with `CANYON` + `WINDOWS`. `EnvSolidCanyonPlain.gdshader`: `CANYON` only, for
  near pieces that never show windows (saves the per-pixel window cost).
- `CityBillboard.gdshader`: procedural shape billboards on the tower wall, square bars' light (`billboard_material`).
- `CloudSea.gdshader`: opaque heaving cloud plane below the roofs (no blending); EnvSolid's canyon fog meets it.
- `NightCitySky.gdshader`: tower skyline from `night_city_sky_sharp/soft.png` (`tools/bake_night_city_sky.py`).

Pulse Void (the giant receiving dish)
- `PulseVoid.gd` (tool, `PulseVoid`): dish panels, feed cabin, four legs, rim girder and masts, props (glb models); seam strips (`seam_material`,
  `ArchStrip.gdshader`) lit rim-inward; `drop_beam` shown on the drop; `leg_floodlight`/`rim_beacon` place lasers.
- `PulseVoidSky.gdshader`: dark space with a glow down the track, computed from view direction (no texture).

Henge (24 monoliths round the player, for 90/360 maps; BLOCKOUT 2026-10-29)
- `HengeRig.gd` (tool, `HengeRig`): `SLAB_COUNT` black slabs (unlit, silhouettes) `RING_RADIUS` out, `QUADRANTS`
  MultiMeshes of slabs and of inner-edge strips; a floor disc whose vertex colour draws the gaps' light bands
  (`_floor_mesh`, `_band`); a floor ring strip (`ring_material`, the floor lights' colour, set by EventDriver).
  `slab_top(i)` places the lasers (`LightRig` "henge": diagonal beams straight up, waving lasers between; no square bars).
- `HengeStrip.gdshader`: the edge strips, left or right lasers' colour by which side of the track's turned line the
  slab stands (`track_turn.gdshaderinc`; `strip_material` params set each frame by EventDriver); `lit` lights the
  slabs one by one round the ring from straight ahead (`EventDriver._update_henge`: `_built` x `HENGE_BUILT_SHARE`,
  all the way over a drop's run-up, `build_up`). Drops come from the show intensity with a hold (`henge_drop`:
  past `STRIP_DROP`, held `HENGE_DROP_HOLD_SECONDS`, released under `HENGE_DROP_RELEASE`); no light events, dark.
- `HengeFloor.gdshader`: dark ground plus vertex-colour bands of the haze's colour; `flood` (the drop, eased) brightens
  the bands and adds `FLOOD_LEVEL` grey, capped at `FLOOR_MAX` below the notes. `HengeSky.gdshader`: dark with a
  neutral horizon glow (no `bg_<type>`). Picked only in the menu or for 90/360 maps; never by Follow map.

Monolith (one colossal slab down a terraced valley, seen from a tall pillar, abstract; in the Auto pool; BLOCKOUT
2026-10-31)
- `MonolithRig.gd` (tool, `MonolithRig`): one black box `SLAB` (1:4:9) `SLAB_DISTANCE` out, `SLAB_YAW` left of ahead,
  its face to the player (`face_material`), standing on the floor of a valley `VALLEY_Y` below the platform that runs
  the same way; the player's pillar down to it; the valley's sides step up in terraces (`_valley_mesh`: a column of
  vertices on each step edge so steps stay sharp, ending `VALLEY_RADIUS` out, inside the far plane; valley and pillar
  share `floor_material`); upright cloud rings (`CLOUD_RINGS`, `_cloud_ring`: a band up from the valley floor whose top
  is a row of round puffs, built in the mesh) among the terraces. Every terrace above y -5 starts
  beyond r 320 m, bends included; keep it so when changing the valley's numbers. `ledge_spot(share)` and
  `up_face(lean)` place the lasers (`LightRig` "monolith": diagonal beams up the face from its ledge `LEDGE_HEIGHT`
  up, above the clouds (owner, 2026-10-31), waving lasers
  between; no square bars). Nothing within the notes' 300 m fly-in in any direction (owner's rule, 2026-10-31).
- `MonolithFace.gdshader`: the slab's lights drawn on its front face (strip meshes would z-fight 500-1000 m out), each
  line at least `MIN_PIXELS` wide: edges in the left/right lasers' colours, `SEAMS` seams in the square bars' lit from
  the foot by `lit`, a slit up the middle open to `slit` and a ledge strip in the floor lights' colour
  (`EventDriver._update_monolith`: `_built` x `MONOLITH_BUILT_SHARE`, a drop by Henge's `henge_drop` rule opens the
  slit, it closes to `MONOLITH_SLIT_REST`). Soft far edges not on yet: planned for the slab's outline, never its lines.
- `MonolithFloor.gdshader`: the valley and pillar: dark ground with a neutral `BASE`, the horizon's glow on the far
  ground toward the slab, steep faces darker than treads (slope from screen derivatives, no normals), the slab's shadow
  falling toward the player as a widening wedge. `MonolithCloud.gdshader`: the cloud rings, opaque (outline in the
  mesh: no discard, no blending), light under the top darkening downward, a thin rim on the puffs, farther rings paler.
  `MonolithCloudEdge.gdshader`: the clouds' soft edge (owner, 2026-10-31), a see-through fringe `CLOUD_BLUR` (an
  angle) out from the outline, the stage's only blending. `monolith_cloud.gdshaderinc`: the clouds' tones and
  `under_cloud`, used by the clouds, the valley, the pillar and the slab: below the clouds' level (`CLOUD_RINGS`' puffs'
  middle, set by `_sink_into_clouds`, exactly 4 rings) a surface takes the cloud's tone, so nothing pokes hard through
  a cloud or shows beneath one (owner, 2026-10-31). `MonolithSky.gdshader`:
  black with a neutral horizon glow behind the slab (`SLAB_DIR` must match `MonolithRig.SLAB_YAW`; no `bg_<type>`) and
  a fainter neutral one all round so the ridges stand as silhouettes.

Metal Factory (underground power plant)
- `MetalFactoryRig.gd` (tool): pistons over anvils, gear rings, energy rails, wall kit with vents, vault, drive gears.
  No beams or moving heads: diagonal/waving light goes to vents (`set_vent_colors`); `slam`/`breathe`/`turn_gears`
  follow beat and intensity; `CPUParticles3D` sparks in note colours (`set_spark_colors`). `METAL_SHEEN`, `MATCAP`.
- `EnvSolidMetal.gdshader`: EnvSolid with `METAL` + `VENTS`; also the track edges (`TrackDeck.gd`).
- `MetalFactorySky.gdshader`: near-black opening, deliberately ignores `bg_<type>` light params.

Shared scenery
- `EnvSolid.gdshaderinc`: the scenery shader body, layers 1-9 documented in its header (base, form, light spill
  `env_light`, ring edge, haze, vents, vertex-colour AO in red, matcap sheen, canyon shading/fog, windows), switched
  by `#define RING/VENTS/METAL/CANYON/WINDOWS`. `debug_view` bits flatten parts for GPU measurement.
- `EnvSolid.gdshader`: plain variant (Classic, Neon Grid, Pulse Void, scene meshes). `EnvSolidRing.gdshader`: `RING`
  lit edge, only on the old `rings` (retired: `rings_enabled = false`).
- `height_fog.gdshaderinc`: analytic exponential height fog per vertex, coloured by `env_haze`.
- `fog_light.gdshaderinc`: haze in-scattering toward the stage key light (`fog_key`) plus 8-bit dither
  (`fog_dither_on`), and `fog_result` (the result moment's air, `result_air`, by distance from the eye); included by every
  scenery, sky and track shader, which pass their colour through `fog_dither(fog_result(colour, VERTEX), FRAGCOORD.xy)`.
- `TrackDeck.gd` (`TrackDeck`): opaque deck (top y 0), curbs housing the thin edge light strips (`STRIP_*`), platform frame, end stops;
  runs to `FAR_Z` -150 (`FAR_Z_BY_STAGE`), fades into haze. `layout(lane_width)` for Wide modifiers; `set_stage` skin.
  Hidden in mixed reality (old see-through sheet instead).
  Its deck and curbs sit under a child that `turn(place)` turns with the notes; the platform pieces don't. On 90/360
  maps during a song (`layout(lane_width, true)` from `EventDriver.set_background`) the platform is a black disc
  (`round_radius()`, as far as the square reaches) with a rim, the deck starting where its corners meet the disc
  (`deck_near()`), so it meets it at any angle; Standard keeps the square pad. There, like Glass Desert (the long deck
  turning made players dizzy, owner 2026-10-29; then no lane floor either) there is no deck, curbs or edge strips
  ahead, no floor reflection; the map's track lights light the platform's ring (`Floor.set_round(radius, lights)`), and
  the turn cue chevron (`CUE_*`, `Constants.TURN_CUE_COLOR`) shows.
- `TrackDeck.gdshader`: deck skin per stage (`SKINS`: plates, tread plate, dark glass), lane grooves, `fade_z`.
- `track_turn.gdshaderinc`: `track_angle` and `track_xz(world)`, a point's place on the unturned track, so the deck's
  grooves and skin and the far fade (`TrackDeck.gdshader`, `EnvSolid.gdshaderinc`'s `fade_z`, `LightStrip.gdshader`) turn
  with the track on 90/360 maps; set on the deck, curb and edge-strip materials by `TrackDeck.turn` and
  `EventDriver._apply_track_turn`.

Light carriers
- `NeonRibbon.gdshader`: the beam/bar ribbon (1 x 32 PlaneMesh) that turns to face the eye, `min_pixels` floor;
  material of every laser group in `event_driver.tscn`.
- `LightRig.gd` (class `LightRig`, `EventDriver._rig`): where each stage hangs the five light groups (`apply(id)`: fixture
  places, square bars, sky scale, `FOG_KEYS`, Pulse Void's beam width), the lasers' Classic places (`classic_places`), and
  `waving_lasers()`/`square_bars()`/`aim()` the driver uses too. Moved out of `event_driver.gd` (2026-10-27).
- `LaserBatch.gd` (`LaserBatch`): `make(holder, parent)` strips each bar's mesh and redraws the group as one
  MultiMesh, copying bar transforms each frame (hidden bar = no instance). Bars stay the nodes you animate.
- `LaserFixtures.gd` (`LaserFixtures`): a fixture at every laser pivot, MultiMesh per part and kind (`MOVING_HEAD`,
  `FOLLOW_SPOT` via `set_kind`); flare quad in front of the lens; heads rest nose-down after 2 s dark.
- `LaserFixture.gdshader`: fixture body/yoke, lens lit by per-instance custom colour. `LaserFlare.gdshader`: additive
  eye-facing glow at the lens, white-hot core.
- `LightStrip.gdshader`: flush strip, white-hot facing the eye (`top_white`: its top too), colour on turned faces,
  `min_pixels` floor for thin far strips; materials `floor_lights.tres`
  (track edges) and `platform_lights.tres` (platform border, always right colour).
- `ArchStrip.gdshader`: segmented strips lit by `level` against `INSTANCE_CUSTOM.x` (height/ring), `drop` for all;
  shared by Neon Grid arches, Pulse Void seams, Classic ribs.
- `PlayerLight.gdshader` + `player_light.gdshaderinc`: saber light pools on the floor (`game/floor.gd`,
  `LightSaber.gd`) and the cut-wave ring (`cut_waves`) that other light shaders add.
- `Footprints.gdshader`: two solid footprints on the standing platform (`game/floor.gd`), toes toward the track,
  30 cm apart, `Constants.FOOTPRINT_COLOR`, always shown and never changing (owner, 2026-10-29).

Air
- `StageSmoke.gd` (`StageSmoke`): floor layer (`FloorSmoke.gdshader`) + three fog sheets (`FogSheet.gdshader`,
  MultiMesh quads); `dissipate()` frees it in songs, `refill()` in menus; Eerie keeps a thinner floor layer.
- `Dust.gd/.gdshader` (`Dust`): 260 additive specks in one draw call around the player, seeded RNG (seed 7).

## Invariants and gotchas

- Unshaded, faked lighting only: no `Light3D`, shadows, volumetric fog, glow/bloom or screen reads (copy per eye on
  Pico). Compatibility renderer: no Vulkan-only shader features. Non-HDR, so brighten toward white, never past 1.
- Brightness order: notes/sabers > walls/bombs > fixtures > beams in haze > scenery > sky. Scenery stays dark and
  desaturated (`LIGHT_SPILL` 0.3 on Night City/Metal Factory for this), shadows black, no colour toning.
- Colours: note colours, danger, neutrals only; scenery takes light colour from `env_light`/group colours, never a
  new hard-coded `Color`. Haze mostly neutral (`HAZE_NEUTRAL`, `HAZE_LIGHT_WEIGHT`).
- Every light has a carrier that belongs to the stage's world (no light-only poles); nothing floats; beams turn
  around their fixture (animate the pivot node, the ribbon is offset half its length). Structure to the sides and
  below the horizon; signature view clear.
- Note corridor (lanes +-1.2 m, wider with Wide; y 0 to 2.5; player to far spawn): no scenery, particles or bright
  light. Mixed reality: only track, notes, sabers, beams (`show_scenery_for_mixed_reality`).
- Rigs are deterministic: every size/position is a named `const` (blockout values, mostly "untuned"); the only RNG is
  `Dust.gd`'s fixed seed. Static helpers on rigs are shared with `LightRig.apply`; change positions there, not in
  EventDriver.
- One MultiMesh per mesh/material (boxes, each glb model, strips, fixtures, bars); a new repeated piece joins one
  instead of adding nodes. Tool scripts build children without owner: never saved into `event_driver.tscn`.
- Shader globals `env_haze`, `env_light`, `combo_glow`, `cut_waves`, `fog_key`, `fog_dither_on`, `result_air`, `debug_view`,
  `atmosphere_eerie`, `left/right_saber(_color)` must be declared in `project.godot [shader_globals]`; a new
  `global uniform` needs an entry there or the shader fails to compile.
- `LaserFixtures`: yoke basis fixed per place (recomputed when its laser moves, or when its beam leaves the yoke's
  plane by `YOKE_PAN_SLACK`, as in the build-up sweep), head tilts on one axis only.
  Turning the yoke per frame flipped it when a waving laser swept through vertical. Unused kinds draw at zero scale.
- Classic: scaffolds start hoisted (`_lift` 1), `start_show` flies them out (`set_built(0)`) and the show brings them
  down; their square bars and moving heads are hidden while `drop_at(z) != 0` (`_follow_frames`), as lowered bars
  once shone up through the track. `_follow_frames` skips work once all stand.
- EnvSolid layer 6 vents use vertex colour, not MultiMesh custom data (enabling custom data lost vertex colours in
  Compatibility). AO lives in vertex colour red; meshes without colours read white.
- Canyon fog is per vertex: `NightCityRig` cuts boxes at `FOG_CUTS` heights so faces have vertices where fog changes.
- `LightRig.apply` hides beam meshes (not holders) on Metal Factory: holders' visibility belongs to the light events.
- Sky sphere scale: 9.5x on Classic/Neon Grid/Pulse Void/canyon so far structure isn't clipped (camera far 1024 m).
- GPU budget 13.9 ms at 72 Hz (`.github/AGENTS.md`); compare `FrmGpu` before/after any scenery or shader change.

## Where to change X

- New stage: id in `Settings.ENVIRONMENTS` (and `Constants.MAP_/TAG_/AUTO_ENVIRONMENTS` if auto-picked), a rig node
  under `Level` in `event_driver.tscn`, sky in `SKY_SHADERS` (+`SKY_TEXTURES`), `STINGER_ROOMS`, `LightRig.FOG_KEYS`, a
  `match` arm in `LightRig.apply`, visibility in `show_scenery_for_mixed_reality`, optional `TrackDeck.SKINS`/
  `FAR_Z_BY_STAGE`, its pictures `thumbs/<id>.png` and `thumbs/<id>_wide.png` (`tools/capture/env_thumbnails.sh`, a `FRAMES` line
  framed on the stage's main unique element; render them again when the stage's look changes, the picker shows them), `stage_capture.gd --env`. Write `doc/world/` entries first.
- New light carrier: place lights from a static helper on the rig, hang them in `LightRig.apply`; prefer the cheapest
  option in `doc/world/VISUAL_STYLE.md` "Light carriers" (vertex-mask vent < `LightStrip` < fixture < beam).
- Haze amount/tint: `HAZE_BASE`, `HAZE_LIGHT_WEIGHT`, `HAZE_NEUTRAL`;
  height fog in `height_fog.gdshaderinc`; key-light scattering `LightRig.FOG_KEYS`; smoke in `StageSmoke.gd` consts.
- A rig's layout: the `const` block at the top of its rig script (e.g. `ClassicRig.FRAME_Z`, `NeonGridRig.ARCH_B`,
  `NightCityRig.LEFT/RIGHT`, `PulseVoid` dish consts); then update `doc/world/SPATIAL_LAYOUT.md`.
- Show build-up timing: `INTENSITY_*`, `STRIP_*`, `RIB_*`, the sweep's `BUILD_UP_SECONDS`/`SWEEP_*` in `event_driver.gd`; `FIRST/LAST_FRAME_AT` in `ClassicRig.gd`.
- A scenery shader layer: the layer list and `#ifdef` blocks in `EnvSolid.gdshaderinc`; a stage-only layer gets a
  new `#define` in a thin variant `.gdshader` rather than a runtime branch.

## How to check a change

- CI (`.github/workflows/build-pico4.yml`) imports, runs tests and exports; it only proves shaders compile/import.
- Desktop look: `godot --path . res://tools/capture/stage_capture.tscn -- --out /tmp/stage.png --env <id>`
  (`--built 0..1`, `--lights on|off|menu`, `--left/--right RRGGBB`, `--eye/--pitch/--yaw/--fov`, `--map <song>`
  `--at <s>` to drive by a real light show, `--classic-city 1`, `--stats 1 --audit 1` for draw calls; full list in
  `tools/capture/stage_capture.gd` header). Not headless: a window opens.
- Headset: `adb logcat -s godot APxrRuntime PxrMetric` (`.github/AGENTS.md`), watch `FrmGpu` vs 13.9 ms.
  `tools/bench.sh [--only fog|total|...]` for per-phase GPU numbers; `game/DebugView.gd` toggles `debug_view` bits.
- `python3 tools/check_agent_docs.py`: every file here must stay named in this doc.
- Skills: `.claude/skills/rhythm-world-design/SKILL.md` (layout/stage design), `.claude/skills/shader-design/SKILL.md`
  (layers, named knobs, before/after GPU), `.claude/skills/game-model-creator/SKILL.md` (glb models, specs in
  `doc/assets/`). Design records: `doc/world/` (GAME_BIBLE, VISUAL_STYLE, SPATIAL_LAYOUT, AUDIO_VISUAL_MAPPING).
