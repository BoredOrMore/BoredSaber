# Asset pipeline rules

From the owner's pipeline kit; adapted to BoredSaber. The repo's own rules win where they differ: suggest a change to
the owner instead of overriding them.

1. Inspect the repo before proposing structural changes.
2. Never replace or delete original assets or modify `project.godot` without the owner's approval.
3. Nothing is integrated without the owner's approval; for assets that means the owner has seen it on the headset.
4. Keep gameplay timing, hit detection, note data and shared APIs unchanged unless the task says otherwise.
5. Keep measured results, visual judgements and assumptions apart in every report.
6. Every asset has a spec, output paths, acceptance criteria and a review report in `doc/assets/<asset>/`.
7. Blockout and silhouette pass before fine detail.
8. Keep the source reproducible: a build script in `tools/models/`, every size a named constant.
9. Record exact commands and exit codes for export and checks.
10. When references or sizes are unclear, write the assumption down and flag the ones that matter.

Every check in a review is PASS, WARN, FAIL or NOT CHECKED. Never write PASS for a check that wasn't run.

Lesson from the first review (laser fixture): baking occlusion into vertex colours samples only at corners, so a long
face whose corners are all buried in another part bakes fully black. End parts at the faces they meet, or cut the face.
