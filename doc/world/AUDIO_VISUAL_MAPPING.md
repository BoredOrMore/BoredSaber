# Audio-to-visual mapping

How the music drives the lights (`game/event_driver.gd`). Template from the rhythm-world suite. Gameplay timing
never depends on any of this.

## Timing source
- Authored: each map's light events (Beat Saber map format), per light group: diagonal lasers, square bars,
  left and right waving lasers, track lights. Each event turns a group on, off, flashes or fades it in a colour.
- No live audio analysis.
- Fallback when a map has no light events: the stage stays dark (owner, 2026-10-24); notes, sabers and the
  platform light themselves (`BeepSaber_Game.start_map`).

## Mapping
| Event | Visual response | Duration | Limits | Safety |
|---|---|---|---|---|
| Light on / colour | the group's beams, fixture lenses and glows, `env_light` on the scenery | colour changes fade | note colours only | — |
| Flash | overshoot of the base colour (`FLASH_BOOST` 1.6) | short | fewer than 3 a second, no large red flashes (Light rule 8) | WCAG 2.3.1 |
| Light off | beams and glows go dark; fixtures stay | instant | — | fixtures are objects, not light |
| Good cut | a ring of the saber's colour runs out along the lights (`cut_waves`) | 30 m/s, to 80 m | — | — |
| Combo multiplier | air and laser bars brighter, up to +30% / +20% at x8 | rises 1 s, falls 0.3 s | never flashing | — |
| Combo milestone | short haze pulse (`COMBO_PULSE`) | 0.6 s | below map flashes | — |
| Mistake | scene dips (`MISTAKE_DIP` 0.5) | 0.6 s | — | — |
| Quiet stretch (Eerie) | lights dim after 1.5 s without events | fade | — | — |
| Menu | dim house light that slowly breathes (12 s) | — | nothing near 0.2 Hz | comfort |

## Test sections
Record the songs and timestamps used for quiet, dense, transition and ending checks here.
