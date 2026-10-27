# Asset spec: Classic, the giant test tunnel (blockout)

- Ticket / owner: Classic's new concept (owner, 2026-10-27: concept 1, the giant test tunnel; replaces the old layout,
  no switch back).
- Story: a lighting crew rehearses inside a test tunnel built for something far bigger than people (a wind tunnel, an
  accelerator): a round bore 120 m across running on past 600 m. The track is the maintenance walkway along its
  bottom. The crew hoists its lighting trusses up as the song builds; on the drop, the tunnel's own test lights run
  along its ribs from far to near.
- Layout (metres, player at the origin, the track toward -z):
  - The tunnel: ribs every 25 m from 25 m behind to 600 m ahead, each a ring of boxes, radius 60, its centre 59 m up
    (the bore's floor just under the track). Between the ribs: nothing but the dark.
  - Six truss bridges across the bore at 20 m, at z -10 to -60 every 10 m (the old frames' places), spanning wall to
    wall; hoisted from 2 m to 20 m as the song builds (the old frames' build-up: far ones first).
  - Two catwalks along the bore's walls, 8 m up, z -8 to -64, with a rail.
  - Props near the track, uneven (left and right differ): flight cases, a cable reel, a scissor lift on one side, a
    ladder against a catwalk.
  - Main elements symmetric (tunnel, trusses, catwalks); asymmetry in the props.
- Light carriers (AGENTS.md "Light", rule 5):
  | Group | Carrier |
  |---|---|
  | Square bars (Beat Saber's ring lights) | strips under the trusses; and the tunnel's test-light strips along its ribs (ClassicRig rib strips, ArchStrip.gdshader) |
  | Diagonal lasers (moving heads) | on the trusses, standing on the top chord (see below) |
  | Waving lasers | follow spots on the wall catwalks |
  | Floor lights | the walkway's edge lights (the track deck) |
  | Sky | the classic sky, seen through the bore's far end |
  The old box plinths are gone. The old rotating rings (calibration gates) are retired: the ribs take their place.
  Moving heads stand on the trusses' top chords rather than hang under them: hung, their beams would aim down into
  the note lane and the player (AGENTS.md "Light", three layers); standing they keep Classic's upward fans. Owner to
  confirm.
- Fill and range: the camera draws to 1024 m, the ribs stop at 600 m; the bore is open (ribs only, no skin), so the
  big interior costs little fill.
- Budget (blockout): tunnel ribs about 650 boxes (7.8k triangles) in the rig's MultiMesh; rib strips one MultiMesh
  (+1 draw call).
