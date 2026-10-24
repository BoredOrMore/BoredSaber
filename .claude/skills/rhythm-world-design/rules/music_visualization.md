# Music Visualization Rules

## Purpose
Map musical structure to deliberate, legible audiovisual responses.

## Event Model
Where the project supports it, distinguish:
- Beat and subdivisions.
- Musical phrases.
- Intensity changes.
- Build-ups and drops.
- Section transitions.
- Gameplay events and song endings.

Prefer authored timing/event data when precise synchronization is required. Do not rely exclusively on noisy real-time amplitude analysis for timing-critical events.

## Mapping Rules
Each visual response should have an intentional relationship to an event:
- Beat: restrained pulse or accent.
- Phrase: coordinated lighting or composition change.
- Build-up: gradual increase in intensity or motion.
- Drop: a designed, controlled visual impact.
- Transition: coherent change between visual states.
- Gameplay impact: feedback that is immediate but does not obscure the next cue.

## Avoid
- Uncontrolled random flashing.
- Continuous motion without a musical or design purpose.
- Effects that mask targets or hazards.
- Rapid brightness changes that cause discomfort.
- Multiple systems competing for attention at once.

## Fallbacks
Define safe behavior if beat data, audio analysis, or event metadata is unavailable. Cosmetic visualization must not break gameplay timing.

## Validation
Test synchronization against representative music sections, including quiet passages, dense sections, transitions, and the ending. Check readability and performance while effects are active.
