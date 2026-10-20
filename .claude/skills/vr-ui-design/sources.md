# Sources behind the VR UI rules

Checked 2026-10-20. Numbers are what each source states; conversions marked "ours" are our arithmetic.

| Topic | Value | Source |
|---|---|---|
| Target size | At least 60 pt of space per interactive element, size plus spacing; 60 pt ≈ 2.5° ≈ 4.4 cm at 1 m | Apple, WWDC23 "Design for spatial input" (10073); WWDC25 "Design hover interactions for visionOS" (303) |
| Target size | At least 48 × 48 dp, 60 × 60 dp for primary controls; add hit slop to smaller icons; neighbouring targets never overlap | Meta Horizon OS design, "Hit targets" (`developers.meta.com/horizon/design/styles_inputs_hit_targets/`) |
| dp to metres | Spatial SDK panels default to 500 dp per metre (1 dp = 2 mm on the panel). Ours: a BoredSaber canvas pixel is 1/1024 m × node scale, so 1 px ≈ 1 dp at scale 2 | Meta Spatial SDK, "2D panel resolution" |
| Text size | 14 px minimum for legibility, 18 px or more for comfortable reading; Medium/Bold read better than Light/Thin; no italics; few sizes and weights; test on hardware | Meta Horizon OS design, "Typography" (`developers.meta.com/horizon/design/styles_typography/`) |
| Text size | Players set short labels at about 30 mrad (≈ 1.7°) and paragraphs at about 17 mrad (≈ 1°); contrast picked 7:1 or more | Kojić et al., "User Experience of Reading in Virtual Reality", QoMEX 2020 (arXiv 2004.01545) |
| Shapes | Rounded shapes (circles, pills, rounded rectangles) lead the eye to the centre; flat, no thick outlines; centre text and glyphs with generous padding | Apple 10073, 303 |
| Placement | Main content in the centre of view, secondary actions toward the edges; interactive content at one depth, subtle depth only for hierarchy; custom windows face the viewer | Apple 10073 |
| Comfort zone | Head turn comfortable ±30° (max 55°), 20° up (max 60°), 12° down (max 40°); eye strain under 0.5 m, Oculus minimum 0.75 m | Alex Chu (Samsung) and Mike Alger, "Visual Design Methods for Virtual Reality" (2015), via the summary at dummies.com |
| Hover | Every interactive element gets a highlight whose shape matches it; no hidden targets without a visible anchor; text stays put while hovered; don't swap the whole view between states; few custom effects, no surprise motion | Apple 303 |
| Testing | Judge on the real headset; video and simulators don't show how it feels | Apple 303, Meta "Typography" |

`SKILL.md` also cites Apple's HIG pages (Spatial layout, Eyes, Buttons, Typography, Motion) and Meta's
Comfort, Hands UI and Eyes best-practice pages; links are in its "Platform guidelines used".
