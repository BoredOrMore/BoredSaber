# Spatial Gameplay Rules

## Purpose
Protect a predictable, readable, and safe gameplay volume.

## Coordinate Contract
Document the project's coordinate convention, including:
- Player/tracking origin.
- Forward direction.
- Playable width and height.
- Target spawn positions and travel direction.
- Object travel speed and interaction timing.
- Player reach and movement boundaries.
- Obstacle/hazard volumes.
- Safe zones, camera/headset visibility, and decorative exclusion zones.

Do not assume a particular axis convention; inspect the existing project and document it.

## Placement Rules
- Gameplay objects must use the canonical coordinate system.
- Decorative geometry must not enter gameplay-critical volumes unless explicitly designed to do so.
- Keep required target silhouettes clear of background objects and effects.
- Avoid visual tangencies, overlapping cues, and confusing depth relationships.
- Ensure obstacle geometry matches its intended gameplay volume.
- Do not use visual effects to conceal collision or timing problems.
- Keep player movement, reach, and tracking assumptions explicit.

## Validation
Where applicable, test:
- Object spawn and travel bounds.
- Collision volumes and overlap.
- Sightline clearance.
- Navigation or movement constraints.
- Player reach and interaction zones.
- Target visibility under peak lighting/effects.

## Acceptance Criteria
All critical gameplay objects remain visible and reachable as designed, and no decorative asset unintentionally blocks player movement or gameplay information.
