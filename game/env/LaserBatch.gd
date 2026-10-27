extends MultiMeshInstance3D
class_name LaserBatch
## Draws a group of light bars (one laser holder of EventDriver: the diagonal, square or a side's waving lasers) in one
## draw call: each bar was a MeshInstance3D of its own, 18-36 draw calls a stage (stage_capture --audit, 2026-10-25).
## The bars stay in the scene as they were, aimed, animated, shown and hidden by EventDriver and their AnimationPlayers
## as before; they only lose their mesh, and every frame, after everything else has moved them, this copies each
## bar's transform into one MultiMesh instance (a hidden bar gets none). The bars of a group share one mesh and one
## material (the group's light colour), so the look is the same: NeonRibbon.gdshader reads the instance's transform
## through MODEL_MATRIX as it read the bar's.

## the group's bars
var _bars: Array[MeshInstance3D] = []

## A batch for every bar under `holder`, added to `parent`, the bars' own drawing switched off.
static func make(holder: Node3D, parent: Node3D) -> LaserBatch:
	var batch := LaserBatch.new()
	for node in holder.find_children("*", "MeshInstance3D", true, false):
		batch._bars.append(node as MeshInstance3D)
	var first := batch._bars[0]
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = first.mesh
	batch.multimesh.instance_count = batch._bars.size()
	batch.material_override = first.material_override
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the ribbons are widened and turned in the vertex shader, and run far: never culled by their bounds
	batch.extra_cull_margin = 16384.0
	# runs after the bars have been moved this frame
	batch.process_priority = 1000
	for bar in batch._bars:
		bar.mesh = null
	parent.add_child(batch)
	return batch

func _process(_delta: float) -> void:
	# the bars' layers (LowResGlow puts them on its glow layer too)
	layers = _bars[0].layers
	var to_local := global_transform.affine_inverse()
	var hidden := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)
	var any := false
	for i in _bars.size():
		var bar := _bars[i]
		var shown := bar.is_visible_in_tree()
		any = any or shown
		multimesh.set_instance_transform(i, to_local * bar.global_transform if shown else hidden)
	# with every bar hidden, no draw call at all
	visible = any
