#!/bin/sh
# Renders every environment's pictures for the Environment picker (owner, 2026-10-28: framed tight on the stage's
# main unique element, filling the whole button, each telling the stages apart): game/env/thumbs/<id>.png, the
# picker's card (440x400, shown 220x200 px), and <id>_wide.png, the closed picker button (896x240, shown 448x120).
# Run it again whenever an environment is added or its look changes (root AGENTS.md); add a line to FRAMES for a
# new one. Needs a window (headless can't render): GODOT=/path/to/godot tools/capture/env_thumbnails.sh
set -e
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/../.."
# id  yaw pitch fov  extra: the camera on the signature element (degrees: yaw left +, pitch up +, vertical fov of the card)
FRAMES="classic        0  6 26
neon_grid      0  6 30
night_city   -32 16 44
pulse_void     0  6 44
metal_factory 30 10 50 --beat 0
henge          0 14 60"
echo "$FRAMES" | while read -r id yaw pitch fov extra; do
	# the wide picture: the middle of the card's view, about as wide again as it is tall
	wide_fov=$(python3 -c "print(round($fov * 0.5, 2))")
	"$GODOT" --path . res://tools/capture/stage_capture.tscn -- --out "game/env/thumbs/$id.png" --env "$id" \
		--lights on --size 440x400 --yaw "$yaw" --pitch "$pitch" --fov "$fov" --seconds 3 $extra >/dev/null 2>&1
	"$GODOT" --path . res://tools/capture/stage_capture.tscn -- --out "game/env/thumbs/${id}_wide.png" --env "$id" \
		--lights on --size 896x240 --yaw "$yaw" --pitch "$pitch" --fov "$wide_fov" --seconds 3 $extra >/dev/null 2>&1
	echo "$id: card fov $fov, wide fov $wide_fov"
done
