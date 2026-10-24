# Procedural Generation Rules

## Generation Order
1. Preserve authored landmarks and gameplay-critical geometry.
2. Define valid spatial zones and exclusion zones.
3. Establish major forms and composition.
4. Generate secondary modules.
5. Distribute small details and effects.
6. Apply controlled variation.
7. Validate spatial constraints.
8. Inspect the result visually.
9. Correct defects and record parameters.

## Constraints
Use relevant checks for:
- World bounds and allowed regions.
- Spacing and overlap.
- Orientation and scale.
- Visibility and sightlines.
- Player-space and target clearance.
- Collision and support surfaces.
- Density and repetition.
- Zone-specific asset families.
- Performance budgets.

## Reproducibility and Safety
- Expose a seed when reproducibility is useful.
- With unchanged inputs, seed, and generator version, aim for identical output.
- Keep parameters explicit and documented.
- Separate generated content from authored content.
- Make rerunning the generator idempotent where practical.
- Avoid deleting or overwriting authored nodes.
- Provide a reset/regenerate path appropriate to the project.
- Log invalid inputs and rejected placements clearly.

## Variation
Vary only selected properties within documented ranges. Use curated alternatives for focal elements. Do not randomize every property.

## Acceptance Criteria
Generation respects constraints, can be inspected and repeated where required, does not accumulate duplicates, and produces a visually reviewed result.
