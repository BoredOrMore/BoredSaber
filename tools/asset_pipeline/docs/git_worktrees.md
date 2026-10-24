# Git worktrees
Start from a clean committed base:
```bash
git status --short
git worktree add ../rhythm-asset-agent -b feature/asset-ticket
git worktree add ../rhythm-world-agent -b feature/world-ticket
git worktree add ../rhythm-vfx-agent -b feature/vfx-ticket
git worktree add ../rhythm-integration -b integration/review-ticket
```
A worktree is a separate checkout, not a security sandbox. Set explicit writable paths and use OS/container isolation
if needed. Avoid parallel edits to `project.godot`, shared scripts, common materials, or one scene. Use Git LFS only
according to project policy. Review diff, open previews, run checks, test in gameplay scene, then obtain approval.
