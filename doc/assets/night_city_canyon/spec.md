# Stage spec: Night City, giant building canyon

- Ticket / owner: Night City rework, concept v2 layout 1 "giant building canyon" (owner, 2026-10-25) / Claude, owner reviews.
- Story: a rooftop concert in a city canyon; the residents in the towers watch, so their windows light up with the show.
- Rules it follows: VISUAL_STYLE "Scale and symmetry" (the player tiny against a wall of towers; left and right differ),
  the Light and Colour rules (AGENTS.md). Metal Factory is not changed by the new rule (owner).
- Confidence: every number below is a first proposal for the blockout, untuned until the owner looks at it.

## Layout (metres; player at z 1 on the rooftop, y 0; -z ahead; WALL_SIDE -1 = left, one constant to swap)
| Part | Where | Size |
|---|---|---|
| Tower wall (wall side) | inner faces 25-28 m out, from z +20 to -170 | three towers, 170 / 200 / 150 m tall, 30 m deep, down to the street (y -45) |
| Low roofs (open side) | inner edges 8-14 m out, z +10 to -120 | four blocks stepping down, roofs 8 / 12 / 15 / 18 m below the player |
| Far city (open side) | beyond the low roofs | the sky's own skyline (boxes out there turned pale in the haze) |
| Landmark tower | right-front, about x 350, z -700 | 400 m tall, 40 m wide |
| Player's rooftop | around the platform | stair house on the wall side (3 m tall), open railing on the other side |
| Street | y -45 under the canyon | the towers and low roofs stand on it |

Depth (owner, 2026-10-25: the towers had none): pilasters every 8 m standing 0.8 m out on whole window cells (no
windows on them), ledges every 4 floors just under a floor line, each tower's top stepped back, faces turned along the
track darker than faces turned to it, and the walls darker toward the street. Familiar-size cue: real windows on the tower wall (about 1.5 m wide, 3.5 m floors, 57 floors on 200 m), drawn in the
shader from the wall's position (no vertex mask: too many vertices), no extra draw call. Not in the blockout.

## Light carriers (the map's five groups, note colours)
- Waving lasers, wall side: searchlights on the tower wall's face at several heights.
- Waving lasers, open side: searchlights on the low roofs.
- Diagonal lasers: kept; from the tower wall's face and the low roofs' edges, crossing over the canyon.
- Square bars: roof trims on the low roofs plus geometric billboards on the tower wall (shapes only, no text or brands).
- Floor: the track's edge strips (shared).
- Windows' colour: the map's light colour on each side with a slight warm room tint (owner approved the tint for Night
  City's windows, 2026-10-25).
- Windows (after the blockout): light floor by floor, bottom to top, near before far on build-up; all lit plus the
  landmark at the peak; dim in quiet parts but never fully dark; maps without lights stay dark.

## Budget (Pico 4)
About Metal Factory or less: under ~10k triangles and ~10 draw calls for the stage, plus the merged lasers (4) and the
sky. Blockout: one MultiMesh of boxes (about 45 boxes, about 540 triangles), one draw call.

## Fallback
Settings > Advanced "Classic Night City" brings back the old rows of buildings.

## Acceptance (owner)
- Looking straight ahead, the tower wall's top is above the view; the player feels tiny.
- Left and right read differently; the skyline ahead stays open on the open side.
- Notes stay the brightest thing; blacks stay black.
