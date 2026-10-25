# Godot Implementation Rules

## Project Discovery
Before changing content, inspect `project.godot`, the actual Godot version, renderer, scene structure, autoloads, resource conventions, and existing test workflow.

## Scene and Resource Design
- Use descriptive node names and logical hierarchies.
- Use reusable PackedScenes for repeated targets, obstacles, environment modules, and effects where appropriate.
- Separate gameplay, spawning, visualization, and validation responsibilities.
- Preserve scene ownership and resource paths.
- Keep transforms, pivots, and local coordinate conventions consistent.
- Avoid monolithic scripts and unnecessary nesting.
- Reuse existing resources and patterns when they fit.

## Scripts
- Follow the project's Godot/GDScript version and conventions.
- Use explicit parameters for dimensions, timing, seeds, and limits.
- Validate externally supplied values and required node/resource references.
- Avoid fragile hard-coded node paths where established alternatives exist.
- Prevent duplicate node creation when generation is rerun.
- Report missing dependencies with actionable errors.
- Keep timing-critical gameplay logic separate from cosmetic animation.

## Meshes and Rendering
- Use authored geometry or reusable assets for final production assets when suitable.
- Validate scale, normals, UVs, materials, and collision shapes where applicable.
- Use instancing or other appropriate techniques for repeated geometry.
- Limit expensive transparent effects and dynamic lights.
- Match material properties to the project's renderer.
- Do not assume a specific renderer or Godot version without inspection.

## Validation
Use available editor/import checks, scene launch checks, logs, and project tests. Do not claim these passed unless the commands were actually run and results inspected.
