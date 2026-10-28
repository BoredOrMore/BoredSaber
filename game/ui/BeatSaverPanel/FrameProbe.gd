extends Node
## Marks where the frame's _process calls end for BeatSaverPanel's slow-frame log (a probe for the stutter dragging
## Get songs, 2026-10-28).

func _process(_delta: float) -> void:
	(get_meta(&"panel") as Object).set(&"_process_ended", Time.get_ticks_usec())
