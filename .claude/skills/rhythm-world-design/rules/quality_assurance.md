# Quality Assurance Rules

## Severity
- **Critical:** project/scene cannot load, core gameplay fails, or a required area is inaccessible.
- **Major:** gameplay cues are obscured, layout/navigation breaks, or composition/style is substantially inconsistent.
- **Minor:** localized visual, alignment, or asset defects.
- **Polish:** optional improvement with no material effect on acceptance.

Fix critical and major defects before polish.

## Structural Checks
- Required scenes and resources exist.
- Resource references resolve.
- Nodes have expected ownership and valid transforms.
- No unintended duplicate generated content exists.
- Major structures connect to supporting geometry where expected.
- Critical routes and access points remain clear.

## Gameplay Checks
Where applicable:
- Spawn/travel bounds are correct.
- Targets and hazards are visible and reachable as intended.
- Collision and navigation behavior are correct.
- Player space and interaction zones are unobstructed.
- Lighting and effects do not mask important cues.

## Visual Review
Inspect:
1. Static overview.
2. Intended player camera.
3. Active gameplay.
4. High-intensity musical sections.
5. Transitions and ending.
6. Performance-constrained conditions.

Look for weak composition, arbitrary placement, accidental repetition, inconsistent scale, visual clutter, poor contrast, excessive bloom, distracting motion, and unintended intersections.

## Technical Review
Use available project tools to check:
- Script parse errors.
- Import and resource failures.
- Invalid node paths.
- Runtime errors.
- Duplicate generation.
- Performance regressions against known budgets.

## Completion Gate
Mark a task complete only when required content exists, critical/major known defects are resolved or disclosed, available technical checks are performed, visual review is completed to the extent supported by the tools, and remaining limitations are documented.
