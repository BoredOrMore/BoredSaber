# Player guidance: using every sense, body range and field of view

Researched 2026-10-29 at the owner's request ("use all senses available in VR to guide the player, calculated
with range of motion and FOV, including while the player moves"). Read this before designing or reviewing any
UI, UX or gameplay-loop element that must catch the player's eye or make the player move: menus and HUD
placement, warnings, notes and walls that come from outside the view, 90/360 maps, haptics, cue sounds.
Human-readable version with diagrams: https://claude.ai/artifact/9dTaYLqrVN1gpUVZUhQaCc

Everything under "Ideas" is untested; changes to game feel still need a headset playtest (root `AGENTS.md`).

## Rules for agents

1. Put what the player must read or hit within ±25° of straight ahead (eyes only); never require more than
   ±50° without a non-visual cue first. Past 50° the torso turns too, and it lags the head by 0.3-0.55 s.
2. Pico 4 shows about 102° × 102°; human vision is about 200° wide. Anything more than ~51° off the head's
   direction is invisible, so announce it with sound (direction) and/or haptics (left/right) before showing it.
3. Coarse to fine: sound says "over there" (±15-25° with a generic HRTF), the picture then says exactly where.
   Two senses together answer faster than either alone.
4. Cues the player must read while dodging or crouching sit far away (≥ 2 m, the HUD at 5.8 m): near things jump
   by many degrees when the head moves (table below).
5. Guide the eye with motion or a light that moves, inside the world (diegetic). A light that stays still does
   not draw the eye. Never rotate or move the camera for the player (forced rotation causes sickness and breaks
   presence).
6. Feedback to an action within 0.1 s; sound and picture of one event within +45 ms (sound early) to -125 ms
   (sound late) of each other. Rhythm timing is carried by sound; moving notes support it, flashes don't.
7. Don't buzz or beep all the time: people stop noticing constant vibration or repeated sounds.
8. Perceptual tricks (hand or world offsets) stay under the detection thresholds below, never change a score
   silently, and are an option the player switches on, shown on the score screen.
9. Plain Pico 4 has no eye tracking: use head direction as the gaze estimate (the eyes may be up to ±25° off it).
   Techniques that need eye tracking (subtle gaze direction, redirection during saccades or blinks) can't be used.

## Hardware and body numbers

| Item | Value | Source |
|---|---|---|
| Pico 4 field of view | ~102° wide × 102° high measured (105° on the spec sheet); the runtime's per-eye `XrFovf` not read yet | New VR Tech lab test, via KultureGeek |
| Human field of view | ~200-220° wide, ~130° high (both eyes) | Strasburger et al. 2011 |
| Eyes alone (comfortable) | ±15-25°; for shifts ≤ 25° the eyes do > 90% of the work | Sidenmark & Gellersen 2019 |
| Gaze zones | 0-25° eyes · 25-50° eyes + head · > 50° eyes + head + torso (standing; seated players rarely turn the torso) | Sidenmark & Gellersen 2019 |
| Neck turn | comfortable ±30°, UI max ±55°; anatomical 68-76° | Chu 2014, Alger 2015; Wolan-Nieroda 2020 |
| Neck up / down | comfortable +20° / −12°; UI max +60° / −40° | Chu 2014, Alger 2015 |
| Arms | above shoulder height they tire fast | Hincapié-Ramos 2014 (consumed endurance) |
| Eye height | ≈ 0.936 × body height (1.68 m for 1.80 m) | Drillis & Contini 1966 |

Seen without turning the torso: ±51° with the head straight, ±60° with a comfortable 30° head turn, up to ±127°
at the neck's limit (76° + 51°). Behind that the whole body turns: only for 90/360 maps, with a cue ≥ 1 s ahead.

## While the player moves

A head shift of Δx metres moves an object at distance d by atan(Δx / d) (motion parallax):

| Head moves | object at 0.65 m (cut point) | 1 m | 2 m | 5.8 m (HUD) |
|---|---|---|---|---|
| Lean 0.3 m (dodge one lane) | 24.8° | 16.7° | 8.5° | 3.0° |
| Lean 0.5 m | 37.6° | 26.6° | 14.0° | 4.9° |
| Crouch 0.5 m (eye 1.68 → 1.18 m, vertical) | 37.6° | 26.6° | 14.0° | 4.9° |

Where notes are when cut (0.65 m in front, rows 0.85 / 1.40 / 1.90 m, lanes x = ±0.3, ±0.9 m):

| Pose | bottom row | middle row | top row | outer lane |
|---|---|---|---|---|
| Standing (eye 1.68 m) | −51.9° (edge of view) | −23.3° | +18.7° | 54.2° to the side (outside the view) |
| Crouching (eye 1.18 m) | −26.9° | +18.7° | +47.9° (edge of view) | 54.2° |

The outer lane is 24° to the side at 2 m and 10° at 5 m. Players see a note clearly only while it is ≥ 2 m
away and cut it from memory and body sense (proprioception), as batters do with a ball (Land & McLeod 2000;
Mann et al. 2013). So any cue about a note, wall or bomb has to land before it is ~2 m away.

| Move | What changes | Cue that works | Lead time (estimate, untested) |
|---|---|---|---|
| Lean / dodge | near things jump sideways | wall readable from far (bright frame), directional sound | ≥ 0.6-1 s |
| Crouch | view drops; things overhead leave the top edge (+51°) | wall's lower edge visible from far; HUD below eye level | ≥ 1 s |
| Swing | eyes don't follow the hand | haptic on hit, cut sound, trail brightness by speed | feedback < 0.1 s |
| Turn (90/360) | torso lags the head 0.3-0.55 s | directional sound first, then an arrow or mini-map at the edge of view | ≥ 1-1.5 s |

Lead times = choice reaction time 0.35-0.5 s (Hick-Hyman) + movement time + torso lag; measure on the headset.

## What each sense can do on Pico 4

| Sense | On Pico 4 | Good for | Weak at | Sources |
|---|---|---|---|---|
| Vision | 102°, 72 Hz | exact position; motion and brightness contrast catch the eye best | only what is in view | Wolfe 2021; Sitzmann 2018 (gaze stays near the horizon) |
| Sound | stereo speakers in the strap; Godot does panning + distance falloff, no built-in HRTF | all around, including behind; timing | ±15-25° error and front/back mix-ups with a generic HRTF, mostly fixed once the head turns | Mills 1958; Wightman & Kistler 1999; Repp & Su 2013 |
| Touch (haptics) | one motor per controller, none on head or body | fast, private, clear left vs right | only left/right; constant buzz fades from notice | Verrillo 1966 (most sensitive ~250 Hz); de Jesus Oliveira 2017 |
| Body sense (proprioception) | the player's own | cutting notes outside the view | vision overrides it, so it can be fooled | Ernst & Banks 2002 |
| Balance (vestibular) | no output | — | any camera motion the player didn't make causes sickness | LaViola 2000; Rebenitsch & Owen 2016 |
| Smell, heat, wind | none | — | needs extra hardware | out of scope |

## Guidance techniques: current versus outdated

| Technique | Status | Evidence | On Pico 4 |
|---|---|---|---|
| EyeSee360 (360° squeezed into a small in-view map) | current, best for finding things outside the view | 34-44% faster than audio + vibration (Marquardt 2020); beats Halo/Wedge (Gruenefeld 2017) | yes |
| Halo / Wedge / edge arrows | older (from 2D screens) | fine for one target | yes |
| Directional sound + vibration | current, as a partner to vision | slower but slightly more accurate (0.96 vs 0.93 hits), keeps awareness of surroundings (7/8 vs 2/8 noticed a second target) (Marquardt 2020) | partly (vibration = left/right) |
| In-world (diegetic) cues: moving light, object that makes a sound | current | moving lights and sounding objects draw the eye; still lights don't (Rothe & Hußmann 2018); a guiding firefly beat forced rotation (Nielsen 2016) | yes, fits the Light rules |
| Forced camera rotation | outdated | sickness, lower presence (Nielsen 2016; LaViola 2000) | never |
| Subtle gaze direction (brief flicker in the periphery) | current, needs eye tracking | Bailey 2009; Grogorick 2017 | only roughly, from head direction |
| Tunnel vignette while the camera moves | standard | Fernandes & Feiner 2016 | only if the camera ever moves (it doesn't) |

## Perceptual tricks: detection thresholds

| Trick | Unnoticed up to | Use | Risk here |
|---|---|---|---|
| Hand redirection | ±4.5° sideways and vertical; reach gain 0.88-1.07 | reach help for players who can't reach | changes cut scores: opt-in, shown on the score screen |
| Rotation gain | 0.64-1.24 × the real head turn (Steinicke 2010) | 360 maps: turn 73° for 90° seen | playtest for sickness; hands turn with the world |
| Translation / curvature gain | 0.86-1.26; radius > 6.4-22 m (Steinicke 2010; Grechkin 2016) | walking | not relevant (player stands still) |
| Change during blinks or saccades | works (Sun 2018; Langbehn 2018) | hidden world changes | impossible without eye tracking |
| Pseudo-haptics (lag or offset the visual to feel weight or resistance) | works (Lécuyer 2009; Rietzler 2018) | sabers feeling heavy against a wall or each other | never on note cuts: it shifts timing |

Ethics: nudges that help the player (move more, avoid danger) are fine. Pushing payment, extending play beyond
what the player wants or silently changing difficulty is an XR dark pattern (Mhaidli & Schaub 2021).

## Ideas for BoredSaber (untested)

- 90/360 maps: a directional whoosh ~1-1.5 s before notes from outside the view, plus a small arrow at ±45°.
- Walls and bombs: a low directional sound ~1 s before, with pitch telling the lane.
- Short swings (approach median 79°, target 100°): haptic strength scaled by swing angle, like the trail.
- Crouch walls followed closely by top-row notes put them at +48°, at the top edge: flag such maps.
- Recentre at song start with a light that moves to the centre lane instead of text.
- Opt-in "Reach assist": hand redirection ≤ 4.5°, shown on the score screen.

## Still unknown

- Pico 4's real per-eye field of view from the OpenXR runtime (may be asymmetric).
- Sound and haptic latency on Pico 4.
- Frequency and strength range the Pico 4 controller motor actually renders.
- Best lead times for sound cues before walls and off-view notes.

## Sources

Sidenmark & Gellersen 2019, ACM TOCHI 27(1) · Marquardt et al. 2020, IEEE TVCG 26(12) · Gruenefeld et al. 2017,
ACM SUI / IEEE VR · Zenner & Krüger 2019, IEEE VR · Steinicke et al. 2010, IEEE TVCG 16(1) · Grechkin et al. 2016,
ACM SAP · Rothe & Hußmann 2018, AVR · Nielsen et al. 2016, ACM VRST · Bailey et al. 2009, ACM TOG 28(4) ·
Grogorick et al. 2017, ACM SAP · Sitzmann et al. 2018, IEEE TVCG 24(4) · Wolfe 2021, Psychon. Bull. Rev. 28 ·
Fernandes & Feiner 2016, IEEE 3DUI · LaViola 2000, SIGCHI Bulletin · Rebenitsch & Owen 2016, Virtual Reality 20 ·
Ernst & Banks 2002, Nature 415 · Miller 1982, Cognitive Psychology 14 · Repp 2005; Repp & Su 2013, Psychon. Bull.
Rev. · Hove et al. 2013, J. Exp. Psychol. HPP · Mills 1958, JASA 30 · Wightman & Kistler 1999, JASA 105 ·
Verrillo 1966, Psychonomic Science · de Jesus Oliveira et al. 2017, IEEE TVCG 23(4) · Hincapié-Ramos et al. 2014,
ACM CHI · Wolan-Nieroda et al. 2020, BioMed Res. Int. · Chu 2014 (Samsung); Alger 2015 · Lécuyer 2009, Presence 18 ·
Rietzler et al. 2018, ACM CHI · Sun et al. 2018, ACM TOG · Langbehn et al. 2018, ACM TOG · Mhaidli & Schaub 2021,
ACM CHI · Land & McLeod 2000, Nature Neuroscience 3 · Mann et al. 2013, PLoS ONE · Strasburger et al. 2011,
J. Vision · Drillis & Contini 1966 · ITU-R BT.1359.
