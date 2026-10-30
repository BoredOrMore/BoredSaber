# Cut effect: dust that swirls and lingers (plan)

Owner, 2026-10-28: "make the cutting effect swirl and linger, almost like dust instead of spark physics". This
changes how cutting feels, so it is researched and planned first (root `AGENTS.md`, "Research before changing game
feel"). Nothing here is built. Images are in `cut-dust-plan/`.

## 1. What we have today

`game/CutFlash.gd` (class `CutFlash`):
- Sparks with short trails (`SparkStreak.gdshader`, two crossed additive strips along the velocity).
- They leave the whole cut line through the note (`CUT_LINE_HALF` 0.18 m).
- **Fountain:** 28 sparks thrown back against the swing in a narrow plume, 6-9 degrees (d61f1ab). Speeds run 1.8-4.8
  m/s at a full swing, so some fly far and some drop short. They live 0.5 s.
- **Spray:** 8 sparks carried on along the swing, 2-5 m/s, 0.4 s.
- Gravity 9 m/s². No drag.
- They start hot white and cool to the saber's colour.
- **Swing strength:** the tip's speed as a share x of 6 m/s, eased by (e^(3x) - 1) / (e^3 - 1) (f61c637). It scales
  speed (0.35-1x), brightness (0.2-1) and spread.
- Sparks vary only 0.85-1.15 in size, so a burst looks even.
- `COUNT` 6 pairs of `CPUParticles3D` reused in turn, so a run of cuts never allocates.
- Nothing stays where the cut was: a flat streak left behind looked fake to the player.

Over time (`options_over_time.jpg`, top row; 0.15 s, 0.6 s, 1.4 s): a bright plume, gone by 0.6 s.

## 2. Beat Saber (PC version, recording 2026-10-28)

`bs_hit_default_14.jpg`, `bs_hit_default_20.jpg` (Default stage, 128.7-129.0 s), `bs_hit_bts_12.jpg`:
- A dense shower of about 50-80 short streaks, pink and white, rising from the cut and falling under gravity.
- It lasts about 0.6 s: physics sparks, much like ours.
- They don't linger or swirl.
- The cut halves tumble away with their cut face glowing.

So the owner is asking for something Beat Saber doesn't do. The look to aim for is closer to embers or glittering dust
in stage light, which still keeps the hit's punch at the moment of the cut.

## 3. Options

Every option keeps the hit's first frames bright (that's the feedback the cut needs) and changes what follows.
Prototype frames for each are in `options_over_time.jpg` (rows 2-4), rendered in Godot with `CPUParticles3D`.

### 1. Retune today's sparks into lingering motes (cheapest)

- Same emitters. Slower: 1.2-3 m/s.
- Strong drag (damping about 3.5), so they stop within about 0.4 s instead of falling.
- Gravity only about 1.2 m/s², so they float.
- Live 1.5-2 s. They grow about 3x as they fade.
- A soft round sprite instead of the streak, additive, cooling to a lighter, less saturated note colour.
- Swirl: none. They drift apart and hang, then fade.
- **GPU cost** (Pico 4, 72 Hz, Compatibility). Lifetime triples, so about 3x the live particles: at three cuts a second,
  about 110-170 live.
  - Each sprite is 5-15 cm at 1-2 m from the eye, about 40-80 px per eye.
  - Additive overdraw of about 0.3-0.6 Mpx per eye against the 2160² view: about +0.2-0.4 ms (estimate).
  - CPU: updating CPUParticles3D, under 0.1 ms.
- **Work:** S. Constants and one sprite shader in `CutFlash.gd`.

### 2. Sparks hand off to swirling dust (recommended)

- The cut keeps a short, smaller spark plume: 20 sparks, 0.4 s, today's physics. That keeps the punch.
- Alongside it, a dust puff of 30-40 soft motes:
  - slow (0.4-1.4 m/s) with drag;
  - nearly weightless;
  - lingering 1.5-2 s;
  - each mote **curling** on its own path.
- The curl is done in the mote's vertex shader: a cheap analytic curl-like drift, a few sines of time and its place,
  or a small 3D noise texture. No compute shader, which the Compatibility renderer doesn't have.
- **Colour.** The sparks keep white cooling to the saber's colour. The dust leans to a soft grey-white tinted by the
  note colour (about 60% toward neutral) and alpha-blended, not additive. It reads as dust in light, not as more
  sparks.
- **GPU cost.** About 200-300 live motes at three cuts a second. They're alpha-blended, so overdraw costs a little
  more than additive: about +0.3-0.6 ms (estimate). The vertex drift is a few ALU per vertex, next to nothing.
  CPU particles: about 0.1-0.2 ms.
- **Work:** M. A second `CPUParticles3D` per emitter pair with a mote `ShaderMaterial`. Swing strength scales the
  puff's size and count, as it does the sparks.

### 3. Dust only

- No sparks: the cut gives a puff of 40-50 motes that swirl and linger 2 s.
- Cost: about +0.3-0.5 ms.
- **Risk:** the cut loses its sharp "hit" moment. Today's sparks were tuned at length with the owner for exactly that
  read (f61c637, d61f1ab). Dust alone reads soft.
- **Work:** S-M.

### GPUParticles3D?

The Compatibility renderer does run `GPUParticles3D`, through transform feedback. But the game already frees GPU
particles on Android (`BeepCube_SliceParticles.gd`), and with this few particles CPU particles cost little. Stay with
`CPUParticles3D`.

## 4. What it touches

- **Comfort, and seeing the next notes.**
  - Cuts happen at the hit plane, right where the next notes arrive. Dust that hangs there for 2 s would veil them.
  - So the dust should **drift with the track toward the player and out to the sides**: an initial velocity of +z and
    outward, plus a slow sideways curl. That way it clears the note corridor within about 0.5 s and lingers beside or
    behind the player.
  - It fades out within about 0.4 m of the eye, so nothing hangs in the player's face.
  - Keep its peak brightness under the notes' (Light rule 1).
- **Colour rules.** Note colours mean "cut this". A lingering mote in full note colour could read like something to
  hit. So: dust at low saturation (note colour leaned toward neutral), or plain warm white. The sparks keep the
  saber's colour, as today, and are short-lived.
- **Floor reflection.** It mirrors notes and blades only, so dust isn't reflected. Adding it would mean another
  MultiMesh. Not needed.
- **Haze and fog.** Notes and sparks are `fog_disabled`. Dust could take a hint of the lit air, as the stage's ambient
  specks do (`game/env/Dust.gdshader` lights them from `env_haze` and the blades). That would tie the cut dust to the
  stage at almost no cost.
- **Flash limits.** A cut is a short bright moment, and dust fades slowly, so it adds no flashing.
- **Measurement.** Before calling it done, run a bench phase in a dense song (`tools/bench.sh`, a "cut dust" mode next
  to the reflection one) against the 13.9 ms frame.

## 5. Recommendation

**Option 2: keep a short spark plume for the hit, and add curling dust that drifts back past the player and lingers
about 1.5 s.** It gives the swirl and the linger asked for without losing the cut's punch, keeps the note lanes clear,
and stays at an estimated +0.3-0.6 ms. Build it behind constants (count, life, drag, curl strength, colour lean) and
tune on the headset.

## 6. Questions for the owner

1. Replace the sparks with dust (option 3), or keep a short spark burst and add dust (option 2)?
2. Dust colour: the note colour softened toward grey-white, plain warm white, or the full note colour?
3. How long should it linger: about 1 s, 1.5 s or 2 s?
4. How much swirl: a gentle drift, clear curls, or a strong vortex that turns round the cut?
5. Should the dust drift back past you (keeping the lanes clear, recommended), or hang where the cut was?

## 7. What was built (owner, 2026-10-28)

- First the dust (sparks that became lingering points, swirling in a vortex, b9e723b), then a lighter version
  (3547b5f). The owner found both wrong: "too light, and the vortex swirl looks very silly". They asked for Beat Saber's
  sparks instead, which also answer to the saber while they hang there, not only at birth.
- **Beat Saber, measured** frame by frame (PC recording, Default stage, a full down cut at about 128.64 s, 24 fps,
  `beat_saber_sparks_vs_ours.jpg` top row at 0.04, 0.125, 0.25, 0.42, 0.58, 0.75 and 0.9 s after the cut):
  - Born white-hot along the whole cut line, about two notes long, as a column of short streaks.
  - They fly out to both sides of the line and along the swing. Most of the spread happens in the first 0.2 s (about
    0.3-0.5 m), then they nearly stop: a strong, smooth drag.
  - The lower ones sag a little: slight gravity, no fountain arc.
  - They stay short streaks to the end, never round dots.
  - Full brightness to about 0.45 s, fading after, the last gone by about 0.85-0.9 s.
  - Roughly 50-80 sparks for a full swing.
- **Ours now** (`game/CutFlash.gd`, `game/CutSpark.gdshader`; middle row): up to 56 sparks along a 0.5 m cut line,
  flying out to the sides (weight 0.8, random in size so it reads as one cloud), along the swing (1.0) and scattered
  (0.6), 1.5-5 m/s at a full swing; drag e^(-7t), gravity 1.5 m/s², each living 0.7-1.0 s; white cooling to the note
  colour in the first quarter of its life, fading from 55%. A streak's length follows its speed (0.04 s of travel, at
  least 2.5 point widths).
- **The blades push them** (bottom row: a blade swept left to right through the sparks at 0.28-0.4 s): a blade within
  0.12 m gives a spark up to half the gap to the blade's own speed each frame, less the farther it passes, so a swing
  sweeps them along and they stretch into streaks again. A pushed spark can't be carried into the note lanes ahead of
  the player; there it only moves out to the side and back. No vortex.
- To do that the sparks are simulated in GDScript and drawn as one MultiMesh (CPUParticles3D gives no access to a
  particle). CPU cost estimated 0.1-0.2 ms a frame with a few bursts alive; measured on the Pico with
  `tools/bench.sh --only cuts`, which now also swings a blade through them and logs "BENCH sparks cpu".
- **Then (owner, 2026-10-28, after trying 4f3f006 on the headset):** "40% smaller, white-hot, spreading out from the
  face of the box mesh". Streaks now 0.013 m wide and at most 0.072 m long; white-hot with a thin rim of the note
  colour for their whole life (the Light rule's hot core, coloured falloff), fading by brightness only. They're born
  on the note mesh's outer faces where the cut plane crosses them (a random point on that outline), flying out along
  the face's normal plus the swing and a random part. `sparks_from_faces.jpg`: Beat Saber, ours, ours with a blade
  sweep, at the same moments as above.
- **Cost.** On the Pico (cuts bench, 4 full cuts a second with a blade swinging through, 4f3f006), the per-frame
  GDScript simulation took 0.50 ms of CPU a frame and the sparks about 0.2-0.3 ms of GPU. So the motion moved into the
  shader in closed form (v = g/k + (v0 - g/k) e^(-kt)); the CPU only works out a burst's sparks when a blade passes
  near it. The first cut of a session also froze the Mac for 370 ms building the shader; one dark spark on the first
  frame now builds it at load.
- **Then 80%:** on the headset 40% smaller was too small; the owner asked for 80% of the first size: 0.0176 m wide,
  streaks to 0.096 m (`CutFlash.SPARK_SIZE`).
- **One look for every saber spark (owner, 2026-10-28).** The blades touching (CPU particles with trailed streaks,
  cooling to orange) and a blade sinking into the floor or platform (no sparks before) now use `CutFlash.spray`: the
  cut sparks' look and physics, 6 sparks at a time, 0.6-2 m/s, living 0.3-0.55 s, at most every 0.04 s per source.
  Not saber sparks, so left as they were: the song-clear burst, Metal Factory's sparks, the particle saber style.
  `one_spark_look.jpg`: the cut before (60% size), now (80%), and the floor and clash sprays.
