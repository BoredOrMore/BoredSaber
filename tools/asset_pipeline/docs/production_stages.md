# Production stages and gates
0. Discovery: record Godot/Blender versions, renderer, scale, lane/camera conventions, formats, import settings.
1. Brief: specify purpose, genre, references, dimensions, view angles, gameplay role, materials, budget, dependencies.
2. Blockout: silhouette and composition only; compare corresponding views; request approval for major assumptions.
3. Detail: add secondary forms, UVs, materials, bevels, VFX only after blockout acceptance.
4. Automated QA: geometry checks, fixed renders, optional silhouette metrics, export, Godot smoke check.
5. Human review: check fidelity, gameplay-camera readability, genre identity, and visual quality.
6. Integration: integrate approved coherent changes only; keep rollback easy.
7. Final: inspect in the real gameplay scene and test on target hardware when possible.

Automation cannot prove perfection. The final in-engine visual review remains a human gate.
